//
//  FLNativeView.h
//  rtckit
//
//  Created by Rain on 2023/11/1.
//

#import <Foundation/Foundation.h>
#import <Flutter/Flutter.h>


NS_ASSUME_NONNULL_BEGIN
@class FLNativeView;
@interface FLNativeViewFactory : NSObject <FlutterPlatformViewFactory>
- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger>*)messenger maps:(NSMutableDictionary<NSNumber*, FLNativeView*>*)videoViews;
@end

@interface FLNativeView : NSObject <FlutterPlatformView>

- (instancetype)initWithFrame:(CGRect)frame
               viewIdentifier:(int64_t)viewId
                    arguments:(id _Nullable)args
              binaryMessenger:(NSObject<FlutterBinaryMessenger>*)messenger;

- (UIView*)view;
@end

NS_ASSUME_NONNULL_END
