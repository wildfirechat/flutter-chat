//
//  FLNativeView.m
//  rtckit
//
//  Created by Rain on 2023/11/1.
//

#import "FLNativeView.h"

@implementation FLNativeViewFactory {
  NSObject<FlutterBinaryMessenger>* _messenger;
  NSMutableDictionary<NSNumber*, FLNativeView*>* _videoViews;
}

- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger>*)messenger maps:(NSMutableDictionary<NSNumber*, FLNativeView*>*)videoViews {
  self = [super init];
  if (self) {
    _messenger = messenger;
    _videoViews = videoViews;
  }
  return self;
}

- (NSObject<FlutterPlatformView>*)createWithFrame:(CGRect)frame
                                   viewIdentifier:(int64_t)viewId
                                        arguments:(id _Nullable)args {
    FLNativeView* view = [[FLNativeView alloc] initWithFrame:frame
                              viewIdentifier:viewId
                                   arguments:args
                             binaryMessenger:_messenger];
    [_videoViews setValue:view forKey:@(viewId)];
    return view;
}

/// Implementing this method is only necessary when the `arguments` in `createWithFrame` is not `nil`.
- (NSObject<FlutterMessageCodec>*)createArgsCodec {
    return [FlutterStandardMessageCodec sharedInstance];
}

@end

@implementation FLNativeView {
   UIView *_view;
}

- (instancetype)initWithFrame:(CGRect)frame
               viewIdentifier:(int64_t)viewId
                    arguments:(id _Nullable)args
              binaryMessenger:(NSObject<FlutterBinaryMessenger>*)messenger {
  if (self = [super init]) {
    _view = [[UIView alloc] init];
  }
  return self;
}

- (UIView*)view {
  return _view;
}

@end
