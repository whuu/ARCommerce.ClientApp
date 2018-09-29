//
//  ProductRepository.m
//  Sitecore.ARDemo
//
//  Created by Tomek Juranek on 15.09.2018.
//  Copyright © 2018 SmartIn. All rights reserved.
//

#import "ProductRepository.h"
#import "SettingsRepository.h"
#import <AFNetworking/AFNetworking.h>

@interface ProductRepository ()

@property (nonatomic) NSMutableArray* products;

@property (nonatomic) AFHTTPSessionManager *apiManager;

@property (nonatomic) BOOL requestInProgress;

@end

@implementation ProductRepository

+ (instancetype)sharedInstance
{
    static ProductRepository *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[ProductRepository alloc] init];
    });
    return sharedInstance;
}

- (id)init
{
    if (self = [super init]) {
        _products = [NSMutableArray new];
        NSURL *serverUrl = [NSURL URLWithString:[SettingsRepository settingForKey:ApiUrl]];
        _apiManager = [[AFHTTPSessionManager alloc] initWithBaseURL: serverUrl];
        _apiManager.requestSerializer = [AFJSONRequestSerializer serializer];
        [_apiManager.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        
        //allow self-signed certificate on server:
        //for dev server with self-signed certificate, check also: https://stackoverflow.com/questions/31254725/transport-security-has-blocked-a-cleartext-http
        AFSecurityPolicy *securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
        securityPolicy.allowInvalidCertificates = YES;
        [securityPolicy setValidatesDomainName:NO];
        _apiManager.securityPolicy = securityPolicy;
    }
    return self;
}

- (void) productsScansCompletion:(void(^)(NSMutableArray* productMaps, NSError* error))callback{
    NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:[SettingsRepository settingForKey:CatalogItemId], @"cci", nil];
    _apiManager.responseSerializer = [AFJSONResponseSerializer serializer];
    [_apiManager GET: @"ARCatalog/GetProductScans" parameters:params progress:nil success:^(NSURLSessionTask *task, id responseObject) {
        NSLog(@"get product scans form server success");
        NSMutableArray* scans = [NSMutableArray new];
        if ([responseObject isKindOfClass:[NSArray class]]) {
            NSArray *responseArray = responseObject;
            for (NSDictionary* dict in responseArray){
                NSString* filePath = [dict objectForKey:@"ScanFilePath"];
                NSString* productId = [dict objectForKey:@"ProductId"];
                if (filePath.length > 0 && productId.length > 0){
                    Product* product = [Product new];
                    product.productId = productId;
                    NSCharacterSet *allowedCharacters = [NSCharacterSet URLFragmentAllowedCharacterSet];
                    product.arMapUrl = [[NSString stringWithFormat:@"%@%@", [SettingsRepository settingForKey:StoreUrl], filePath] stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters];
                    [scans addObject: product];
                }else{
                    NSLog(@"Missing scan for product %@", productId);
                }
            }
            
            if (scans.count == 0){
                NSLog(@"get product scans, no product scans");
                callback(nil, nil);
            }
            __block int downloaded = 0;
            for (Product* product in scans){
                [self downloadFileFromUrl:product.arMapUrl Completion:^(NSURL *localPath) {
                    product.arMapLocalPath = localPath;
                    downloaded++;
                    if (downloaded == scans.count){
                        callback(scans, nil);
                    }
                }];
            }
        }else{
            NSLog(@"get product scans, empty results from server");
            callback(nil, nil);
        }
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        NSLog(@"get product scans from server error: %@", error);
        callback(nil, error);
    }];
}

- (void) cachedProductWithId:(NSString*) productId Completion:(void(^)(Product* product))callback
{
    NSString* key =  [NSString stringWithFormat:@"product-%@", productId];
    NSNumber* interval = [SettingsRepository settingForKey:ProductCacheInterval];
    NSDate* lastUpdate = [SettingsRepository settingForKey:key];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"productId == %@", productId];
    NSArray *filteredProductCache = [_products filteredArrayUsingPredicate:predicate];
    
    NSTimeInterval secondsBetween = [[NSDate date] timeIntervalSinceDate:lastUpdate];
    if (!_requestInProgress && (lastUpdate == nil || secondsBetween > interval.intValue*60 || filteredProductCache.count == 0)){
        [self apiProductForID:productId Completion:^(Product *product) {
            NSLog(@"Load product from api with id: %@", product.productId);
            if (product){
                [self downloadFileFromUrl:product.imageUrl Completion:^(NSURL *localPath) {
                    product.imageLocalPath = localPath;
                    [self->_products addObject:product];
                    [SettingsRepository updateSettings:[NSDate date] ForKey:key];
                    callback(product);
                }];
            }else{
                callback(nil);
            }
        }];
    }else{
        callback(filteredProductCache.firstObject);
    }
}

- (void) apiProductForID:(NSString* )productId Completion:(void(^)(Product* product))callback
{
    NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:productId, @"id" ,nil];
    _requestInProgress = YES;
    _apiManager.responseSerializer = [AFJSONResponseSerializer serializer];
    [_apiManager GET: @"ARCatalog/ProductInformation" parameters:params progress:nil success:^(NSURLSessionTask *task, id responseObject) {
        NSLog(@"get product form server success");
        self->_requestInProgress = NO;
        Product * product = [Product new];
        product.productId = productId;
        product.name = [responseObject objectForKey:@"DisplayName"];
        product.priceWithCurrency = [responseObject objectForKey:@"AdjustedPriceWithCurrency"];
        product.availability = [responseObject objectForKey:@"StockStatusLabel"];
        product.detailedDescription = [responseObject objectForKey:@"Description"];
        product.productUrl = [NSString stringWithFormat:@"%@%@", [SettingsRepository settingForKey:StoreUrl], [responseObject objectForKey:@"Link"]];
        product.imageUrl = [NSString stringWithFormat:@"%@%@", [SettingsRepository settingForKey:StoreUrl], [responseObject objectForKey:@"SummaryImageUrl"]];
        callback(product);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        NSLog(@"Get product from server error: %@", error);
        self->_requestInProgress = NO;
        callback(nil);
    }];
}

- (void) downloadFileFromUrl: (NSString*) fileUrl Completion:(void(^)(NSURL* localPath))callback{
    NSURL *url = [NSURL URLWithString: fileUrl];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSURLSessionDownloadTask *downloadTask = [_apiManager downloadTaskWithRequest:request progress:nil destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
        NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
        return [documentsDirectoryURL URLByAppendingPathComponent:[response suggestedFilename]];
    } completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
        if (error){
            NSLog(@"Error while downloading %@", error);
            callback(nil);
        }
        NSLog(@"File downloaded to: %@", filePath);
        callback(filePath);
    }];
    [downloadTask resume];
}

@end
