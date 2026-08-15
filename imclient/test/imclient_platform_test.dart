import 'package:flutter_test/flutter_test.dart';
import 'package:imclient/imclient_platform.dart';

/// WfcPlatform 平台判断测试。
///
/// `Platform.is*` 在测试中反映的是宿主平台,因此协议平台号与设备形态
/// 映射通过 clientPlatformCodeFor/parseDeviceType 两个纯函数锁定;
/// 组合逻辑(isTablet 等)用 debugDeviceType 验证。
void main() {
  group('parseDeviceType', () {
    test('phone/tablet/2in1/pc/未知', () {
      expect(WfcPlatform.parseDeviceType('phone'), WfcDeviceType.phone);
      expect(WfcPlatform.parseDeviceType('tablet'), WfcDeviceType.tablet);
      expect(WfcPlatform.parseDeviceType('2in1'), WfcDeviceType.pc);
      expect(WfcPlatform.parseDeviceType('pc'), WfcDeviceType.pc);
      expect(WfcPlatform.parseDeviceType('default'), WfcDeviceType.unknown);
      expect(WfcPlatform.parseDeviceType('tv'), WfcDeviceType.unknown);
      expect(WfcPlatform.parseDeviceType(null), WfcDeviceType.unknown);
    });
  });

  group('clientPlatformCodeFor 协议平台号', () {
    test('桌面平台不受设备形态影响', () {
      for (final type in WfcDeviceType.values) {
        expect(WfcPlatform.clientPlatformCodeFor('windows', type), 3);
        expect(WfcPlatform.clientPlatformCodeFor('macos', type), 4);
        expect(WfcPlatform.clientPlatformCodeFor('linux', type), 7);
      }
      expect(WfcPlatform.clientPlatformCodeFor('fuchsia', WfcDeviceType.unknown),
          0);
    });

    test('iOS/Android 按设备形态区分手机与平板', () {
      expect(WfcPlatform.clientPlatformCodeFor('ios', WfcDeviceType.phone), 1);
      expect(WfcPlatform.clientPlatformCodeFor('ios', WfcDeviceType.tablet), 8);
      expect(
          WfcPlatform.clientPlatformCodeFor('android', WfcDeviceType.phone), 2);
      expect(
          WfcPlatform.clientPlatformCodeFor('android', WfcDeviceType.tablet), 9);
    });

    test('鸿蒙按设备形态区分 10/11/12', () {
      expect(WfcPlatform.clientPlatformCodeFor('ohos', WfcDeviceType.phone), 10);
      expect(
          WfcPlatform.clientPlatformCodeFor('ohos', WfcDeviceType.unknown), 10);
      expect(
          WfcPlatform.clientPlatformCodeFor('ohos', WfcDeviceType.tablet), 11);
      expect(WfcPlatform.clientPlatformCodeFor('ohos', WfcDeviceType.pc), 12);
    });

    // 原生未随 Dart 一起升级时 getDeviceType 抛 MissingPluginException,形态落到
    // unknown。此时平台号必须与引入设备形态判断之前逐位相同,否则会波及服务端的
    // 多端互踢与离线推送。
    test('形态未知时回落到手机号段,与引入本判断之前一致', () {
      expect(WfcPlatform.clientPlatformCodeFor('ios', WfcDeviceType.unknown), 1);
      expect(
          WfcPlatform.clientPlatformCodeFor('android', WfcDeviceType.unknown),
          2);
      expect(
          WfcPlatform.clientPlatformCodeFor('ohos', WfcDeviceType.unknown), 10);
    });
  });

  group('设备形态组合', () {
    tearDown(() => WfcPlatform.debugDeviceType = WfcDeviceType.unknown);

    test('debugDeviceType 驱动 isTablet', () {
      expect(WfcPlatform.deviceType, WfcDeviceType.unknown);
      expect(WfcPlatform.isTablet, isFalse);

      WfcPlatform.debugDeviceType = WfcDeviceType.tablet;
      expect(WfcPlatform.deviceType, WfcDeviceType.tablet);
      expect(WfcPlatform.isTablet, isTrue);

      WfcPlatform.debugDeviceType = WfcDeviceType.phone;
      expect(WfcPlatform.isTablet, isFalse);
    });

    // isOhosPc 只在鸿蒙上成立。宿主(测试机)不是鸿蒙,即便形态被置为 pc
    // 也必须为 false —— 否则桌面三栏 Shell 会在非鸿蒙平台被误判开启。
    test('非鸿蒙宿主上 isOhosPc 恒为 false', () {
      WfcPlatform.debugDeviceType = WfcDeviceType.pc;
      expect(WfcPlatform.isOhos, isFalse);
      expect(WfcPlatform.isOhosPc, isFalse);
    });

    // 平板在"原生能力"这一轴上仍属移动档,isMobile/isDesktop 不受形态影响。
    test('设备形态不影响 isMobile/isDesktop 分流', () {
      final bool mobile = WfcPlatform.isMobile;
      final bool desktop = WfcPlatform.isDesktop;
      for (final type in [WfcDeviceType.phone, WfcDeviceType.tablet]) {
        WfcPlatform.debugDeviceType = type;
        expect(WfcPlatform.isMobile, mobile);
        expect(WfcPlatform.isDesktop, desktop);
      }
    });
  });
}
