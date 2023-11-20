#import <Flutter/Flutter.h>

@class WFAVCallSession;
@interface RtckitPlugin : NSObject<FlutterPlugin>
+ (NSDictionary *)callSession2Dict:(WFAVCallSession *)session;
@end
