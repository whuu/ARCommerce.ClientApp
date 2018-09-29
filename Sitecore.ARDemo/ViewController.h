//
//  ViewController.h
//  Sitecore.ARDemo
//
//  Created by Tomek Juranek on 15.09.2018.
//  Copyright © 2018 SmartIn. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <ARKit/ARKit.h>

@interface ViewController : UIViewController<ARSCNViewDelegate>

@property (strong, nonatomic) IBOutlet ARSCNView *sceneView;

- (IBAction)syncProducts:(id)sender;

- (IBAction)openSettings:(id)sender;

@end

