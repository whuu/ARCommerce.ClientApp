//
//  ProductRepository.h
//  Sitecore.ARDemo
//
//  Created by Tomek Juranek on 15.09.2018.
//  Copyright © 2018 SmartIn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Product.h"

@interface ProductRepository : NSObject

+ (instancetype)sharedInstance;

- (void) cachedProductWithId:(NSString*) productId Completion:(void(^)(Product* product))callback;

- (void) productsScansCompletion:(void(^)(NSMutableArray* productMaps, NSError* error))callback;

@end
