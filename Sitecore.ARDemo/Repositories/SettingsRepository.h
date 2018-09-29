//
//  SettingsRepository.h
//  Sitecore.ARDemo
//
//  Created by Tomek Juranek on 15.09.2018.
//  Copyright © 2018 SmartIn. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SettingsRepository : NSObject

extern NSString *const ApiUrl;

extern NSString *const StoreUrl;

extern NSString *const ProductCacheInterval;

extern NSString *const CatalogItemId;

+ (id) settingForKey: (NSString*) key;

+ (void) updateSettings: (id) object ForKey: (NSString*) key;

+ (bool) hasValidSettings;

@end
