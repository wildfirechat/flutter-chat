import 'package:flutter_test/flutter_test.dart';
import 'package:imclient/imclient_platform.dart';

/// WfcPlatform 平台判断测试。
///
/// `Platform.is*` 在测试中反映的是宿主平台,因此协议平台号与鸿蒙形态
/// 映射通过 clientPlatformCodeFor/parseOhosDeviceType 两个纯函数锁定;
/// 组合逻辑(isOhosPc 等)用 debugOhosDeviceType 验证。
void main() {
  group('parseOhosDeviceType', () {
    test('phone/tablet/2in1/pc/未知', () {
      expect(WfcPlatform.parseOhosDeviceType('phone'), OhosDeviceType.phone);
      expect(WfcPlatform.parseOhosDeviceType('tablet'), OhosDeviceType.tablet);
      expect(WfcPlatform.parseOhosDeviceType('2in1'), OhosDeviceType.pc);
      expect(WfcPlatform.parseOhosDeviceType('pc'), OhosDeviceType.pc);
      expect(WfcPlatform.parseOhosDeviceType('default'), OhosDeviceType.unknown);
      expect(WfcPlatform.parseOhosDeviceType('tv'), OhosDeviceType.unknown);
      expect(WfcPlatform.parseOhosDeviceType(null), OhosDeviceType.unknown);
    });
  });

  group('clientPlatformCodeFor 协议平台号', () {
    test('移动与桌面平台', () {
      expect(WfcPlatform.clientPlatformCodeFor('ios', OhosDeviceType.unknown), 1);
      expect(WfcPlatform.clientPlatformCodeFor('android', OhosDeviceType.unknown), 2);
      expect(WfcPlatform.clientPlatformCodeFor('windows', OhosDeviceType.unknown), 3);
      expect(WfcPlatform.clientPlatformCodeFor('macos', OhosDeviceType.unknown), 4);
      expect(WfcPlatform.clientPlatformCodeFor('linux', OhosDeviceType.unknown), 7);
      expect(WfcPlatform.clientPlatformCodeFor('fuchsia', OhosDeviceType.unknown), 0);
    });

    test('鸿蒙按设备形态区分 10/11/12', () {
      expect(WfcPlatform.clientPlatformCodeFor('ohos', OhosDeviceType.phone), 10);
      expect(WfcPlatform.clientPlatformCodeFor('ohos', OhosDeviceType.unknown), 10);
      expect(WfcPlatform.clientPlatformCodeFor('ohos', OhosDeviceType.tablet), 11);
      expect(WfcPlatform.clientPlatformCodeFor('ohos', OhosDeviceType.pc), 12);
    });
  });

  group('鸿蒙形态组合', () {
    tearDown(() => WfcPlatform.debugOhosDeviceType = OhosDeviceType.unknown);

    test('debugOhosDeviceType 驱动 isOhosPc', () {
      expect(WfcPlatform.ohosDeviceType, OhosDeviceType.unknown);
      expect(WfcPlatform.isOhosPc, isFalse);

      WfcPlatform.debugOhosDeviceType = OhosDeviceType.pc;
      expect(WfcPlatform.ohosDeviceType, OhosDeviceType.pc);
      expect(WfcPlatform.isOhosPc, isTrue);

      WfcPlatform.debugOhosDeviceType = OhosDeviceType.phone;
      expect(WfcPlatform.isOhosPc, isFalse);
    });
  });
}
