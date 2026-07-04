#import "ImclientPlugin.h"

// imclient 的 macOS 实现已迁移到 Dart FFI（imclient/lib/src/ffi/，直接驱动
// libMarsWrapper），原 ~3000 行的 method channel 分发实现已删除。
//
// 本插件类仅保留两个职责：
// 1. 满足 GeneratedPluginRegistrant 的注册调用（imclient 在 macOS 仍以
//    普通插件形式参与构建，以便 CocoaPods 编译 wfc_dart_bridge 垫片并
//    嵌入 libMarsWrapper.dylib）；
// 2. 为没有 macOS 实现的 fluttertoast 注册 no-op 通道，避免桌面端
//    MissingPluginException。
@implementation ImclientPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  FlutterMethodChannel *toastChannel =
      [FlutterMethodChannel methodChannelWithName:@"PonnamKarthik/fluttertoast"
                                  binaryMessenger:[registrar messenger]];
  [toastChannel setMethodCallHandler:^(FlutterMethodCall *call,
                                       FlutterResult result) {
    result(nil);
  }];
}

@end
