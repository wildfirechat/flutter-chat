import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 鸿蒙设备形态。ohos 上 `Platform.operatingSystem` 只会返回 'ohos',
/// 手机/平板/电脑需要通过 `getDeviceType` 通道查询 `deviceInfo.deviceType`
/// 区分,见 [WfcPlatform.init]。
enum OhosDeviceType {
  /// 未查询或查询失败。兜底按手机处理,保持引入本判断之前的行为。
  unknown,
  phone,
  tablet,

  /// 鸿蒙电脑,deviceType 为 '2in1' 或 'pc'。
  pc,
}

/// 全项目唯一的平台判断入口。chat 及各包不要直接使用 `Platform.is*` /
/// `Platform.operatingSystem` 做平台分支,统一走这里。
///
/// 形态语义分三层:
/// - [isMobile]/[isDesktop]:UI 形态分流(单栏 HomeTabBar vs 三栏 Shell),
///   鸿蒙电脑算桌面,鸿蒙手机/平板算移动。
/// - [isNativeDesktop]:有完整桌面原生能力(window_manager、托盘、
///   截图、多窗口、FFI),仅 Windows/macOS/Linux。鸿蒙电脑不具备这些,
///   相关入口必须用 isNativeDesktop 门控而不是 isDesktop。
/// - [useFfiChannel]:IM 底层通道选择。FFI 只有 Windows/macOS/Linux 的
///   libMarsWrapper 构建,鸿蒙(含电脑)走 MethodChannel + ohos HAR。
class WfcPlatform {
  WfcPlatform._();

  static const MethodChannel _channel = MethodChannel('imclient');

  /// 只有 ohos 上的 [init] 会写入(以及测试的 debugOhosDeviceType),
  /// 其他平台恒为 [OhosDeviceType.unknown]。
  static OhosDeviceType _ohosDeviceType = OhosDeviceType.unknown;

  static bool get isAndroid => Platform.isAndroid;
  static bool get isIOS => Platform.isIOS;
  static bool get isWindows => Platform.isWindows;
  static bool get isMacOS => Platform.isMacOS;
  static bool get isLinux => Platform.isLinux;
  static bool get isOhos => Platform.operatingSystem == 'ohos';

  /// 应用启动早期调用(main 中 runApp 之前、首次读取形态判断之前)。
  /// 非鸿蒙平台为 no-op;鸿蒙上查询 deviceType 并缓存,之后所有
  /// 同步 getter 即可用。查询失败保持 [OhosDeviceType.unknown],按手机兜底。
  static Future<void> init() async {
    if (!isOhos) {
      return;
    }
    try {
      final type = await _channel.invokeMethod<String>('getDeviceType');
      _ohosDeviceType = parseOhosDeviceType(type);
    } catch (_) {
      _ohosDeviceType = OhosDeviceType.unknown;
    }
  }

  /// deviceInfo.deviceType 字符串到形态的映射。
  @visibleForTesting
  static OhosDeviceType parseOhosDeviceType(String? type) {
    switch (type) {
      case 'phone':
        return OhosDeviceType.phone;
      case 'tablet':
        return OhosDeviceType.tablet;
      case '2in1':
      case 'pc':
        return OhosDeviceType.pc;
      default:
        return OhosDeviceType.unknown;
    }
  }

  /// 鸿蒙设备形态。非鸿蒙平台为 [OhosDeviceType.unknown]。
  static OhosDeviceType get ohosDeviceType => _ohosDeviceType;

  /// 鸿蒙电脑(2in1/pc)。
  static bool get isOhosPc => ohosDeviceType == OhosDeviceType.pc;

  /// 移动形态:Android/iOS/鸿蒙手机/鸿蒙平板,UI 使用单栏 HomeTabBar。
  static bool get isMobile => isAndroid || isIOS || (isOhos && !isOhosPc);

  /// 桌面形态:Windows/macOS/Linux/鸿蒙电脑,UI 使用三栏 Shell。
  static bool get isDesktop => isWindows || isMacOS || isLinux || isOhosPc;

  /// 有完整桌面原生能力(window_manager/托盘/截图/多窗口/FFI)的平台。
  /// 鸿蒙电脑只有桌面 UI 形态,没有这些原生能力。
  static bool get isNativeDesktop => isWindows || isMacOS || isLinux;

  /// IM 底层是否走 dart:ffi 通道。鸿蒙(含电脑)无 FFI 库构建,
  /// 走 MethodChannel + ohos HAR。
  static bool get useFfiChannel => isNativeDesktop;

  /// 上报服务器的客户端平台号,见 [clientPlatformCodeFor]。
  static int get clientPlatformCode =>
      clientPlatformCodeFor(Platform.operatingSystem, ohosDeviceType);

  /// 客户端平台号映射,对齐 WFCCPlatformType:
  /// iOS=1 Android=2 Windows=3 OSX=4 WEB=5 WX=6 Linux=7 iPad=8 APad=9
  /// Harmony=10 HarmonyPad=11 HarmonyPC=12。未知平台返回 0(UNSET)。
  @visibleForTesting
  static int clientPlatformCodeFor(
      String operatingSystem, OhosDeviceType deviceType) {
    switch (operatingSystem) {
      case 'ios':
        return 1;
      case 'android':
        return 2;
      case 'windows':
        return 3;
      case 'macos':
        return 4;
      case 'linux':
        return 7;
      case 'ohos':
        switch (deviceType) {
          case OhosDeviceType.tablet:
            return 11;
          case OhosDeviceType.pc:
            return 12;
          case OhosDeviceType.phone:
          case OhosDeviceType.unknown:
            return 10;
        }
      default:
        return 0;
    }
  }

  /// 测试用:直接设置鸿蒙设备形态,不走通道。
  @visibleForTesting
  static set debugOhosDeviceType(OhosDeviceType type) {
    _ohosDeviceType = type;
  }
}
