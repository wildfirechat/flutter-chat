import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 设备形态。`Platform.operatingSystem` 只能区分操作系统,同一个 'ios'/'android'/
/// 'ohos' 下手机与平板的 UI 形态和协议平台号都不同,需要通过 `getDeviceType`
/// 通道向原生查询,见 [WfcPlatform.init]。各端的判定口径:
/// - iOS:`UIUserInterfaceIdiomPad` → tablet,否则 phone
/// - Android:设备全局最小宽度 ≥ 600dp → tablet,否则 phone
/// - 鸿蒙:`deviceInfo.deviceType`('phone'/'tablet'/'2in1'/'pc')
/// - Windows/macOS/Linux:不查询,恒为 [unknown](桌面形态由 `Platform.is*` 直接定)
enum WfcDeviceType {
  /// 未查询、查询失败,或桌面平台不适用。
  ///
  /// **兜底一律按手机处理**:原生未随 Dart 一起升级时通道会抛
  /// MissingPluginException,落到这里,此时所有形态判断与协议平台号都必须与
  /// 引入本判断之前逐位相同。
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
///
/// [isTablet] 是**设备形态**,不参与上面三层的分流 —— pad 在原生能力上仍属移动
/// 档([isMobile] 为 true),它影响的是协议平台号,以及后续 UI 层的多栏布局
/// (见 PAD_ADAPTATION_PLAN.md)。UI 该用单栏还是多栏取决于**窗口宽度**而不是
/// 这个 getter,pad 分屏到 1/3 宽时同样要回落单栏。
class WfcPlatform {
  WfcPlatform._();

  static const MethodChannel _channel = MethodChannel('imclient');

  /// 由 [init] 写入(以及测试的 debugDeviceType)。桌面三端不查询,恒为
  /// [WfcDeviceType.unknown]。
  static WfcDeviceType _deviceType = WfcDeviceType.unknown;

  static bool get isAndroid => Platform.isAndroid;
  static bool get isIOS => Platform.isIOS;
  static bool get isWindows => Platform.isWindows;
  static bool get isMacOS => Platform.isMacOS;
  static bool get isLinux => Platform.isLinux;
  static bool get isOhos => Platform.operatingSystem == 'ohos';

  /// 应用启动早期调用(main 中 runApp 之前、首次读取形态判断之前)。
  /// 桌面三端为 no-op;iOS/Android/鸿蒙查询设备形态并缓存,之后所有
  /// 同步 getter 即可用。查询失败保持 [WfcDeviceType.unknown],按手机兜底。
  static Future<void> init() async {
    if (isNativeDesktop) {
      // 桌面三端形态由 Platform.is* 直接判定,不必付一次启动期通道往返
      return;
    }
    try {
      final type = await _channel.invokeMethod<String>('getDeviceType');
      _deviceType = parseDeviceType(type);
    } catch (_) {
      _deviceType = WfcDeviceType.unknown;
    }
  }

  /// 原生返回的形态字符串到 [WfcDeviceType] 的映射。三端共用同一套取值:
  /// iOS/Android 只会返回 'phone'/'tablet','2in1'/'pc' 仅鸿蒙会出现。
  @visibleForTesting
  static WfcDeviceType parseDeviceType(String? type) {
    switch (type) {
      case 'phone':
        return WfcDeviceType.phone;
      case 'tablet':
        return WfcDeviceType.tablet;
      case '2in1':
      case 'pc':
        return WfcDeviceType.pc;
      default:
        return WfcDeviceType.unknown;
    }
  }

  /// 设备形态。桌面三端为 [WfcDeviceType.unknown]。
  static WfcDeviceType get deviceType => _deviceType;

  /// 平板(iPad / Android 平板 / 鸿蒙平板)。查询失败时为 false(按手机兜底)。
  static bool get isTablet => _deviceType == WfcDeviceType.tablet;

  /// 鸿蒙电脑(2in1/pc)。
  static bool get isOhosPc => isOhos && _deviceType == WfcDeviceType.pc;

  /// 移动形态:Android/iOS/鸿蒙手机/鸿蒙平板,UI 使用单栏 HomeTabBar。
  /// 平板也在此列 —— 它没有桌面原生能力,布局分流不看这个 getter。
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
      clientPlatformCodeFor(Platform.operatingSystem, deviceType);

  /// 客户端平台号映射,对齐 WFCCPlatformType:
  /// iOS=1 Android=2 Windows=3 OSX=4 WEB=5 WX=6 Linux=7 iPad=8 APad=9
  /// Harmony=10 HarmonyPad=11 HarmonyPC=12。未知平台返回 0(UNSET)。
  ///
  /// 平台号参与服务端的多端在线互踢/静音判定与离线推送目标选择,
  /// [WfcDeviceType.unknown] 必须回落到手机号段(1/2/10),不能返回 0 ——
  /// 原生未随 Dart 升级时走的就是这条路径。
  @visibleForTesting
  static int clientPlatformCodeFor(
      String operatingSystem, WfcDeviceType deviceType) {
    final bool isTablet = deviceType == WfcDeviceType.tablet;
    switch (operatingSystem) {
      case 'ios':
        return isTablet ? 8 : 1;
      case 'android':
        return isTablet ? 9 : 2;
      case 'windows':
        return 3;
      case 'macos':
        return 4;
      case 'linux':
        return 7;
      case 'ohos':
        switch (deviceType) {
          case WfcDeviceType.tablet:
            return 11;
          case WfcDeviceType.pc:
            return 12;
          case WfcDeviceType.phone:
          case WfcDeviceType.unknown:
            return 10;
        }
      default:
        return 0;
    }
  }

  /// 测试用:直接设置设备形态,不走通道。
  @visibleForTesting
  static set debugDeviceType(WfcDeviceType type) {
    _deviceType = type;
  }
}
