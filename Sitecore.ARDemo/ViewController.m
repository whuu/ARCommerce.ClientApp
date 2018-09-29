//
//  ViewController.m
//  Sitecore.ARDemo
//
//  Created by Tomek Juranek on 15.09.2018.
//  Copyright © 2018 SmartIn. All rights reserved.
//

#import "ViewController.h"
#import "ProductRepository.h"
#import "SettingsRepository.h"
#import "SVProgressHUD.h"
#import "SCLAlertView.h"
#import <SceneKit/SceneKit.h>

@interface ViewController ()

@end

@implementation ViewController

NSMutableSet* _productScans;

- (void)viewDidLoad {
    [super viewDidLoad];
    _sceneView.delegate = self;
    [self getProductsFromAPI];
    SCNScene* scene = [SCNScene sceneNamed:@"Scene.scn"];
    _sceneView.scene = scene;
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    ARWorldTrackingConfiguration* configuration = [ARWorldTrackingConfiguration new];
    configuration.detectionObjects = _productScans;
    [_sceneView.session runWithConfiguration: configuration options:ARSessionRunOptionRemoveExistingAnchors|ARSessionRunOptionResetTracking];
}

- (void) viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [_sceneView.session pause];
}

- (SCNNode *)renderer:(id<SCNSceneRenderer>)renderer nodeForAnchor:(ARAnchor *)anchor{
    SCNNode* node = [SCNNode new];
    if ([anchor isKindOfClass:[ARObjectAnchor class]]){
        ARObjectAnchor* objectAnchor = (ARObjectAnchor*)anchor;
        NSLog(@"Detected product %@", objectAnchor.referenceObject.name);
        
        SCNPlane* plane = [SCNPlane new];
        plane.width = 0;
        plane.height = 0;
        SKScene* spriteKitScene = [SKScene nodeWithFileNamed:@"ProductInfo"];
        [[ProductRepository sharedInstance] cachedProductWithId:objectAnchor.referenceObject.name Completion:^(Product *product) {
            float outerMargin = 20.0;
            //align image
            UIImage* image = [[UIImage alloc] initWithData:[NSData dataWithContentsOfURL:product.imageLocalPath]];
            SKSpriteNode* productPhoto =(SKSpriteNode*)[spriteKitScene childNodeWithName:@"Photo"];
            productPhoto.texture = [SKTexture textureWithImage:image];
            productPhoto.position = CGPointMake(-spriteKitScene.size.width*0.5 + outerMargin, spriteKitScene.size.height*0.5 - outerMargin );

            //align name label
            SKLabelNode* nameLabel = (SKLabelNode*)[spriteKitScene childNodeWithName:@"Name"];
            nameLabel.text = product.name;
            float innerMargin = 10;
            nameLabel.preferredMaxLayoutWidth = spriteKitScene.size.width - productPhoto.size.width - 2 * outerMargin + innerMargin;
            nameLabel.position = CGPointMake(productPhoto.position.x + productPhoto.size.width + innerMargin, productPhoto.position.y);
            
            //align description label
            SKLabelNode* descriptionLabel = (SKLabelNode*)[spriteKitScene childNodeWithName:@"Description"];
            descriptionLabel.text = product.detailedDescription;
            descriptionLabel.preferredMaxLayoutWidth = spriteKitScene.size.width - 2 * outerMargin;
            descriptionLabel.position = CGPointMake(productPhoto.position.x, productPhoto.position.y - productPhoto.size.height - innerMargin);

            //align price label
            SKLabelNode* priceLabel = (SKLabelNode*)[spriteKitScene childNodeWithName:@"Price"];
            priceLabel.text = product.priceWithCurrency;
            priceLabel.preferredMaxLayoutWidth = spriteKitScene.size.width/2.0 - 2 * outerMargin;
            priceLabel.position = CGPointMake(productPhoto.position.x, descriptionLabel.position.y - descriptionLabel.frame.size.height - innerMargin*2.0);
            
            //set plane size
            plane.width = spriteKitScene.size.width * 0.00055;
            plane.height = spriteKitScene.size.height * 0.00055;
            plane.cornerRadius = plane.width / 20;
            plane.firstMaterial.diffuse.contents = spriteKitScene;
            plane.firstMaterial.doubleSided = true;
            plane.firstMaterial.diffuse.contentsTransform = SCNMatrix4Translate(SCNMatrix4MakeScale(1, -1, 1), 0, 1, 0);

            SCNNode *planeNode = [SCNNode new];
            planeNode.geometry = plane;
            planeNode.position = SCNVector3Make(objectAnchor.referenceObject.center.x, objectAnchor.referenceObject.center.y + 0.2, objectAnchor.referenceObject.center.z);
        }];
        SCNNode *planeNode = [SCNNode new];
        planeNode.name = objectAnchor.referenceObject.name;
        planeNode.geometry = plane;
        planeNode.position = SCNVector3Make(objectAnchor.referenceObject.center.x, objectAnchor.referenceObject.center.y + 0.2, objectAnchor.referenceObject.center.z);
        [node addChildNode:planeNode];
    }
    return node;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    CGPoint touchLocation = [[[touches allObjects] firstObject] locationInView:_sceneView];
    NSString* productId =  [[_sceneView hitTest:touchLocation options:nil] firstObject].node.name;
    if (productId.length == 0){
        return;
    }
    
    NSLog(@"tap on product: %@", productId);
    [[ProductRepository sharedInstance] cachedProductWithId:productId Completion:^(Product *product) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:product.productUrl] options:@{} completionHandler:nil];
    }];
}

- (IBAction)syncProducts:(id)sender {
    [self getProductsFromAPI];
}

- (IBAction)openSettings:(id)sender {
    [self updateSettings];
}

- (void) updateSettings{
    SCLAlertView *alert = [[SCLAlertView alloc] init];
    alert.backgroundType = SCLAlertViewBackgroundTransparent;
    alert.customViewColor = [UIColor grayColor];
    
    UITextField *urlField = [alert addTextField:@"Shop Hostname"];
    urlField.text = [SettingsRepository settingForKey:StoreUrl];
    UITextField *categoryItemField = [alert addTextField:@"Category Item ID"];
    categoryItemField.text = [SettingsRepository settingForKey:CatalogItemId];
    [alert addButton:@"Save" actionBlock:^(void) {
        [SettingsRepository updateSettings:urlField.text ForKey:StoreUrl];
        [SettingsRepository updateSettings:categoryItemField.text ForKey:CatalogItemId];
    }];
    [alert showEdit:self title:@"Settings" subTitle:nil closeButtonTitle:@"Close" duration:0.0f];
}

- (void) getProductsFromAPI{
    if (![SettingsRepository hasValidSettings]){
        [self updateSettings];
        return;
    }
    [SVProgressHUD showWithStatus:@"Downloading Products..."];
    [[ProductRepository sharedInstance] productsScansCompletion:^(NSMutableArray *productMaps, NSError* error) {
        if (error){
            [SVProgressHUD showErrorWithStatus:[NSString stringWithFormat:@"Error: %@", error.localizedDescription]];
            return;
        }
        _productScans = [NSMutableSet new];
        for (Product* product in productMaps){
            if (!product.arMapLocalPath){
                continue;
            }
            NSError* error;
            ARReferenceObject* scan = [[ARReferenceObject alloc] initWithArchiveURL:product.arMapLocalPath error:&error];
            if (error){
                NSLog(@"Error creating reference object: %@", error);
            }else{
                scan.name = product.productId;
                [_productScans addObject:scan];
            }
        }
        ARWorldTrackingConfiguration* configuration = [ARWorldTrackingConfiguration new];
        configuration.detectionObjects = _productScans;
        [self->_sceneView.session runWithConfiguration: configuration options:ARSessionRunOptionRemoveExistingAnchors|ARSessionRunOptionResetTracking];
        [SVProgressHUD showSuccessWithStatus:[NSString stringWithFormat:@"Synced %lu Product(s)", _productScans.count]];
    }];
}

@end
