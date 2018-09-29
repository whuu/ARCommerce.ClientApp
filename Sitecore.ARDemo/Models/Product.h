//
//  Product.h
//  Sitecore.ARDemo
//
//  Created by Tomek Juranek on 15.09.2018.
//  Copyright © 2018 SmartIn. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Product : NSObject

@property (strong, nonatomic) NSString *productId;

@property (strong, nonatomic) NSString *name;

@property (strong, nonatomic) NSString *priceWithCurrency;

@property (strong, nonatomic) NSString *availability;

@property (strong, nonatomic) NSString *detailedDescription;

@property (strong, nonatomic) NSString *productUrl;

@property (strong, nonatomic) NSString *imageUrl;

@property (strong, nonatomic) NSString *arMapUrl;

@property (strong, nonatomic) NSURL *imageLocalPath;

@property (strong, nonatomic) NSURL *arMapLocalPath;

@end
