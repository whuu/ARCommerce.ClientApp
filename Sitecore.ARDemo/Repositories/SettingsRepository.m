//
//  SettingsRepository.m
//  Sitecore.ARDemo
//
//  Created by Tomek Juranek on 15.09.2018.
//  Copyright © 2018 SmartIn. All rights reserved.
//

#import "SettingsRepository.h"
#import <AFNetworking/AFNetworking.h>

@interface SettingsRepository ()

@property (nonatomic) AFHTTPSessionManager *apiManager;

@property (nonatomic) BOOL requestInProgress;

@end

@implementation SettingsRepository

NSString *const ProductCacheInterval = @"ProductCacheUpdateInterval";

NSString *const StoreUrl = @"BaseUrl";

NSString *const ApiUrl = @"ApiUrl";

NSString *const CatalogItemId = @"CatalogItemId";

+ (id) settingForKey: (NSString*) key
{
    if ([key isEqualToString:ApiUrl]){
        return [NSString stringWithFormat:@"%@/api/cxa/", [SettingsRepository settingForKey:StoreUrl]];
    }
    if ([key isEqualToString:ProductCacheInterval]){
        return [NSNumber numberWithInt:3];
    }
    return [[NSUserDefaults standardUserDefaults] objectForKey:key];
}

+ (void) updateSettings: (id) object ForKey: (NSString*) key{
    [[NSUserDefaults standardUserDefaults] setObject:object forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (bool) hasValidSettings{
    if (((NSString*)[SettingsRepository settingForKey: StoreUrl]).length == 0){
        return  NO;
    }
    if (((NSString*)[SettingsRepository settingForKey: CatalogItemId]).length == 0){
        return  NO;
    }
    return YES;
}

@end
