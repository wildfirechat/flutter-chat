//
//  ShareNavigationController.m
//  ShareExtension
//

#import "ShareNavigationController.h"
#import "ShareViewController.h"

@implementation ShareNavigationController

- (instancetype)init {
    ShareViewController *shareVC = [[ShareViewController alloc] init];
    self = [super initWithRootViewController:shareVC];
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    ShareViewController *shareVC = [[ShareViewController alloc] init];
    self = [super initWithRootViewController:shareVC];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    ShareViewController *shareVC = [[ShareViewController alloc] init];
    self = [super initWithRootViewController:shareVC];
    return self;
}

@end
