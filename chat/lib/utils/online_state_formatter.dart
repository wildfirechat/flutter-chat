import 'package:imclient/model/user_online_state.dart';
import 'package:chat/l10n/app_localizations.dart';

/// 在线状态平台常量，与 iOS 保持一致。
class _OnlinePlatform {
  static const int unset = 0;
  static const int iOS = 1;
  static const int android = 2;
  static const int windows = 3;
  static const int osx = 4;
  static const int web = 5;
  static const int wx = 6;
  static const int linux = 7;
  static const int iPad = 8;
  static const int aPad = 9;
  static const int harmony = 10;
  static const int harmonyPad = 11;
  static const int harmonyPC = 12;
}

/// 在线状态格式化工具。
class OnlineStateFormatter {
  OnlineStateFormatter._();

  /// 判断是否有设备在线（customState 不是隐身 4）。
  static bool isOnline(UserOnlineState? state) {
    if (state == null ||
        state.clientStates == null ||
        state.clientStates!.isEmpty) {
      return false;
    }
    if (state.customState != null && state.customState!.state == 4) {
      return false;
    }
    return state.clientStates!.any((cs) => cs.state == 0);
  }

  /// 获取手机端最后可见时间（ms）。
  static int _mobileLastSeen(UserOnlineState? state) {
    if (state?.clientStates == null) return 0;
    var lastSeen = 0;
    for (final cs in state!.clientStates!) {
      if ((cs.platform == _OnlinePlatform.iOS ||
              cs.platform == _OnlinePlatform.android ||
              cs.platform == _OnlinePlatform.harmony) &&
          cs.state == 1 &&
          cs.lastSeen > lastSeen) {
        lastSeen = cs.lastSeen;
      }
    }
    return lastSeen;
  }

  /// 在线状态文案，会话标题第二行与联系人行第二行共用。
  /// 在线时给出「手机在线 / 电脑在线 / 忙碌…」，离线则退到「手机 5 分钟前在线」，
  /// null 表示这个人没有任何可展示的状态(未登录过、或对方隐身)。
  static String? statusText(UserOnlineState? state, AppLocalizations l10n) {
    if (state?.clientStates == null || state!.clientStates!.isEmpty) {
      return null;
    }
    if (state.customState != null && state.customState!.state == 4) return null;

    var pcState = -1;
    var mobileState = -1;
    var webState = -1;
    var wxState = -1;
    var padState = -1;
    var hasOnline = false;

    for (final cs in state.clientStates!) {
      if (cs.platform >= _OnlinePlatform.unset &&
          cs.platform <= _OnlinePlatform.harmonyPC &&
          cs.state == 0) {
        hasOnline = true;
      }
      if (cs.platform == _OnlinePlatform.iOS ||
          cs.platform == _OnlinePlatform.android ||
          cs.platform == _OnlinePlatform.harmony) {
        mobileState = cs.state;
      } else if (cs.platform == _OnlinePlatform.windows ||
          cs.platform == _OnlinePlatform.osx ||
          cs.platform == _OnlinePlatform.linux ||
          cs.platform == _OnlinePlatform.harmonyPC) {
        pcState = cs.state;
      } else if (cs.platform == _OnlinePlatform.web) {
        webState = cs.state;
      } else if (cs.platform == _OnlinePlatform.wx) {
        wxState = cs.state;
      } else if (cs.platform == _OnlinePlatform.iPad ||
          cs.platform == _OnlinePlatform.aPad ||
          cs.platform == _OnlinePlatform.harmonyPad) {
        padState = cs.state;
      }
    }

    if (!hasOnline) {
      return _lastSeenText(state, l10n);
    }

    final customState = state.customState?.state ?? 0;
    if (customState == 0) {
      if (pcState == 0) return l10n.pcOnline;
      if (padState == 0) return l10n.padOnline;
      if (webState == 0) return l10n.webOnline;
      if (wxState == 0) return l10n.microAppOnline;
      if (mobileState == 0) return l10n.mobileOnline;
      return null;
    } else if (customState == 1) {
      return l10n.busy;
    } else if (customState == 2 || customState == 3) {
      return l10n.away;
    }
    return null;
  }

  static String? _lastSeenText(UserOnlineState? state, AppLocalizations l10n) {
    final lastSeen = _mobileLastSeen(state);
    if (lastSeen <= 0) return null;
    final duration = DateTime.now().millisecondsSinceEpoch - lastSeen;
    if (duration < 0) return null;

    final days = duration ~/ 86400000;
    if (days > 0) return l10n.mobileOnlineDaysAgo(days);
    final hours = duration ~/ 3600000;
    if (hours > 0) return l10n.mobileOnlineHoursAgo(hours);
    final mins = duration ~/ 60000;
    if (mins > 0) return l10n.mobileOnlineMinutesAgo(mins);
    return l10n.mobileOnlineJustNow;
  }
}
