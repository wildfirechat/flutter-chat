import 'package:flutter/material.dart';
import 'package:imclient/model/pc_online_info.dart';
import 'package:chat/l10n/app_localizations.dart';

/// PC/多端在线信息展示辅助:平台图标与设备名称。
/// 多端登录条(会话列表)与「已登录的设备」页共用,保证图标/命名一致。
///
/// 对齐 HarmonyOS `uikit/src/main/ets/common/utils/pcOnlineUtil.ets`:
/// [PCOnlineInfo.type](PC/Web/WX/Pad/Wearable/TV 在线类型)由服务端权威下发,
/// `platform` 是各端上报的具体平台号(见 imclient_platform.dart 的
/// `clientPlatformCodeFor`,对齐 WFCCPlatformType),老客户端可能上报 0(UNSET),
/// 因此图标/命名以 type 为主、platform 为辅,避免 platform 缺失时全部显示成手机。
class PcOnlineUtil {
  PcOnlineUtil._();

  // ---- 客户端平台号,对齐 WFCCPlatformType(HarmonyOS Platform 同值) ----
  static const int platformUnset = 0;
  static const int platformIOS = 1;
  static const int platformAndroid = 2;
  static const int platformWindows = 3;
  static const int platformOSX = 4;
  static const int platformWeb = 5;
  static const int platformWX = 6;
  static const int platformLinux = 7;
  static const int platformIPad = 8;
  static const int platformAPad = 9;
  static const int platformHarmony = 10;
  static const int platformHarmonyPad = 11;
  static const int platformHarmonyPC = 12;
  static const int platformAndroidWearable = 13;
  static const int platformHarmonyWearable = 14;
  static const int platformAndroidTV = 15;
  static const int platformAppleTV = 16;
  static const int platformHarmonyTV = 17;

  /// 平台灰色图标。多台设备合并展示时用 [Icons.computer],见调用点。
  static IconData icon(PCOnlineInfo info) {
    switch (info.type) {
      case PCOnlineInfo.pcOnline:
        return Icons.computer;
      case PCOnlineInfo.webOnline:
        return Icons.web;
      case PCOnlineInfo.padOnline:
        return Icons.tablet;
      case PCOnlineInfo.wxOnline:
        return Icons.smartphone;
      case PCOnlineInfo.wearableOnline:
        return Icons.watch;
      case PCOnlineInfo.tvOnline:
        return Icons.tv;
      default:
        break;
    }
    // type 未知时按具体平台兜底
    switch (info.platform) {
      case platformWindows:
      case platformOSX:
      case platformLinux:
      case platformHarmonyPC:
        return Icons.computer;
      case platformWeb:
        return Icons.web;
      case platformWX:
        return Icons.smartphone;
      case platformIPad:
      case platformAPad:
      case platformHarmonyPad:
        return Icons.tablet;
      case platformAndroidWearable:
      case platformHarmonyWearable:
        return Icons.watch;
      case platformAndroidTV:
      case platformAppleTV:
      case platformHarmonyTV:
        return Icons.tv;
      default:
        return Icons.smartphone;
    }
  }

  /// 设备名称(微信风格):Windows / Mac / Web / 微信小程序 / iPad / 手表 / 电视 等。
  static String deviceName(BuildContext context, PCOnlineInfo info) {
    final l10n = AppLocalizations.of(context)!;
    switch (info.type) {
      case PCOnlineInfo.wxOnline:
        return l10n.deviceWeChatMiniProgram;
      case PCOnlineInfo.wearableOnline:
        return l10n.deviceWatch;
      case PCOnlineInfo.tvOnline:
        return l10n.deviceTV;
      default:
        break;
    }
    final String? name = _platformName(info.platform, l10n);
    if (name == null) {
      // platform 未上报(UNSET)或未知时按在线类型回退,与 HarmonyOS 一致:
      // Web 在线回 Web,Pad 在线回平板,其余回电脑。
      switch (info.type) {
        case PCOnlineInfo.webOnline:
          return l10n.deviceWeb;
        case PCOnlineInfo.padOnline:
          return l10n.devicePad;
        default:
          return l10n.devicePC;
      }
    }
    return name;
  }

  static String? _platformName(int platform, AppLocalizations l10n) {
    switch (platform) {
      case platformUnset:
        return null;
      case platformIOS:
        return l10n.deviceIOS;
      case platformAndroid:
        return l10n.deviceAndroid;
      case platformWindows:
        return l10n.deviceWindows;
      case platformOSX:
        return l10n.deviceMac;
      case platformLinux:
        return l10n.deviceLinux;
      case platformWeb:
        return l10n.deviceWeb;
      case platformWX:
        return l10n.deviceMiniProgram;
      case platformIPad:
        return l10n.deviceIPad;
      case platformAPad:
        return l10n.deviceAndroidPad;
      case platformHarmony:
        return l10n.deviceHarmonyPhone;
      case platformHarmonyPad:
        return l10n.deviceHarmonyPad;
      case platformHarmonyPC:
        return l10n.deviceHarmonyPC;
      case platformAndroidWearable:
        return l10n.deviceAndroidWatch;
      case platformHarmonyWearable:
        return l10n.deviceHarmonyWatch;
      case platformAndroidTV:
        return l10n.deviceAndroidTV;
      case platformAppleTV:
        return l10n.deviceAppleTV;
      case platformHarmonyTV:
        return l10n.deviceHarmonyTV;
      default:
        // 未知平台按 PC 兜底(HarmonyOS getPlatFormName 默认 'PC' 同一语义)
        return null;
    }
  }

  /// 是否为桌面电脑类设备(支持「锁定电脑」等操作)。
  static bool isDesktopDevice(PCOnlineInfo info) {
    if (info.type == PCOnlineInfo.pcOnline) {
      return true;
    }
    switch (info.platform) {
      case platformWindows:
      case platformOSX:
      case platformLinux:
      case platformHarmonyPC:
        return true;
      default:
        return false;
    }
  }
}
