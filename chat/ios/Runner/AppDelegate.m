#import "AppDelegate.h"
#import "GeneratedPluginRegistrant.h"
#if USE_CALL_KIT
#import "WFCCallKitManager.h"
#endif
#import <UserNotifications/UserNotifications.h>
#include <WFChatClient/WFCChatClient.h>

static NSString * const kShareAppGroupId = @"group.cn.wildfirechat.messangerEx";
static NSString * const kShareItemsKey = @"wfc_share_items";
static NSString * const kSharedConversationsKey = @"wfc_share_conversation_list";
static NSString * const kSharedAuthTokenKey = @"wfc_share_appservice_auth_token";
static NSString * const kSharedAppServerAddressKey = @"wfc_share_appserver_address";

@interface AppDelegate () <UNUserNotificationCenterDelegate>
#if USE_CALL_KIT
@property(nonatomic, strong) WFCCallKitManager *callKitManager;
#endif
@property(nonatomic, strong) FlutterMethodChannel *shareChannel;
@property(nonatomic, strong) NSArray<NSDictionary *> *pendingShareItems;
@end

@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [GeneratedPluginRegistrant registerWithRegistry:self];

    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    center.delegate = self;

    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge)
                          completionHandler:^(BOOL granted, NSError * _Nullable error) {
                              if (granted) {
                                  dispatch_async(dispatch_get_main_queue(), ^{
                                      [[UIApplication sharedApplication] registerForRemoteNotifications];
                                  });
                                  
                              } else {
                              }
                          }];

    BOOL result = [super application:application didFinishLaunchingWithOptions:launchOptions];
    
    if (result) {
        FlutterViewController *controller = (FlutterViewController *)self.window.rootViewController;
#if USE_CALL_KIT
        FlutterMethodChannel *callKitChannel = [FlutterMethodChannel
            methodChannelWithName:@"chat.wildfire/callkit"
                  binaryMessenger:controller.binaryMessenger];
        self.callKitManager = [[WFCCallKitManager alloc] initWithMethodChannel:callKitChannel];
        [self.callKitManager registerVoipPush];
#endif
        
        self.shareChannel = [FlutterMethodChannel
            methodChannelWithName:@"chat.wildfire/share"
                  binaryMessenger:controller.binaryMessenger];
        [self.shareChannel setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
            if ([call.method isEqualToString:@"getPendingShareItems"]) {
                result(self.pendingShareItems ?: @[]);
                self.pendingShareItems = nil;
            } else if ([call.method isEqualToString:@"saveSharedConversations"]) {
                [self saveSharedConversations:call.arguments];
                result(@"OK");
            } else {
                result(FlutterMethodNotImplemented);
            }
        }];
    }

    return result;
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    if ([url.scheme isEqualToString:@"wfcchat"] && [url.host isEqualToString:@"share"]) {
        [self loadSharedItems];
        return YES;
    }
    return NO;
}

- (void)saveSharedConversations:(NSDictionary *)arguments {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kShareAppGroupId];
    NSArray *conversations = arguments[@"conversations"];
    NSString *authToken = arguments[@"authToken"];
    NSString *appServerAddress = arguments[@"appServerAddress"];
    if (conversations) {
        [defaults setObject:conversations forKey:kSharedConversationsKey];
    }
    if (authToken.length) {
        [defaults setObject:authToken forKey:kSharedAuthTokenKey];
    }
    if (appServerAddress.length) {
        [defaults setObject:appServerAddress forKey:kSharedAppServerAddressKey];
    }
    [defaults synchronize];
}

- (void)loadSharedItems {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kShareAppGroupId];
    NSArray<NSDictionary *> *items = [defaults objectForKey:kShareItemsKey];
    if (items.count) {
        self.pendingShareItems = items;
        [defaults removeObjectForKey:kShareItemsKey];
    }
    if (self.pendingShareItems.count) {
        [self.shareChannel invokeMethod:@"onShareItemsReceived" arguments:self.pendingShareItems];
    }
}

- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:
(UIUserNotificationSettings *)notificationSettings {
    // register to receive notifications
    [application registerForRemoteNotifications];
}


- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    if ([deviceToken isKindOfClass:[NSData class]]) {
        const unsigned *tokenBytes = [deviceToken bytes];
        NSString *hexToken = [NSString stringWithFormat:@"%08x%08x%08x%08x%08x%08x%08x%08x",
                              ntohl(tokenBytes[0]), ntohl(tokenBytes[1]), ntohl(tokenBytes[2]),
                              ntohl(tokenBytes[3]), ntohl(tokenBytes[4]), ntohl(tokenBytes[5]),
                              ntohl(tokenBytes[6]), ntohl(tokenBytes[7])];
        [[WFCCNetworkService sharedInstance] setDeviceToken:hexToken];
    } else {
        NSString *token = [[[[deviceToken description] stringByReplacingOccurrencesOfString:@"<"
                                                                                 withString:@""]
                            stringByReplacingOccurrencesOfString:@">"
                            withString:@""]
                           stringByReplacingOccurrencesOfString:@" "
                           withString:@""];
        
        [[WFCCNetworkService sharedInstance] setDeviceToken:token];
    }
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    
}

@end
