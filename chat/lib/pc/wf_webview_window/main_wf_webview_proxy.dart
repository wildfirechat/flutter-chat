import 'dart:async';

import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';

import '../multi_window/proxy_completer.dart';
import '../multi_window/window_event_channel.dart';
import 'wf_webview_window_ipc.dart';

/// 主窗口中的 WebView 子窗口代理。
///
/// 负责把子窗口侧的 IM 调用转发到主窗口执行，供 WebView JS API 依赖的
/// getAuthCode / configApplication / getUserInfo / getUserInfos 等接口使用。
class MainWFWebViewProxy {
  static final MainWFWebViewProxy instance = MainWFWebViewProxy._internal();

  MainWFWebViewProxy._internal();

  bool _installed = false;

  void install() {
    if (_installed) return;
    _installed = true;

    final channel = WindowEventChannel();
    channel.listen();
    _registerMainWindowHandlers(channel);
  }

  void _registerMainWindowHandlers(WindowEventChannel channel) {
    channel.register('${kWFWebViewWindowKind}.imclient.getAuthCode',
        _handleGetAuthCode);
    channel.register('${kWFWebViewWindowKind}.imclient.configApplication',
        _handleConfigApplication);
    channel.register('${kWFWebViewWindowKind}.imclient.getUserInfo',
        _handleGetUserInfo);
    channel.register('${kWFWebViewWindowKind}.imclient.getUserInfos',
        _handleGetUserInfos);
  }

  Future<dynamic> _handleGetAuthCode(dynamic args) async {
    final appId = args['appId'] as String? ?? '';
    final appType = args['appType'] as int? ?? 0;
    final host = args['host'] as String? ?? '';
    return ProxyCompleter.stringResult((onSuccess, onFailure) {
      Imclient.getAuthCode(appId, appType, host, onSuccess, onFailure);
    });
  }

  Future<dynamic> _handleConfigApplication(dynamic args) async {
    final appId = args['appId'] as String? ?? '';
    final appType = args['appType'] as int? ?? 0;
    final timestamp = args['timestamp'] as int? ?? 0;
    final nonce = args['nonce'] as String? ?? '';
    final signature = args['signature'] as String? ?? '';
    return ProxyCompleter.voidResult((onSuccess, onFailure) {
      Imclient.configApplication(
        appId,
        appType,
        timestamp,
        nonce,
        signature,
        onSuccess,
        onFailure,
      );
    });
  }

  Future<dynamic> _handleGetUserInfo(dynamic args) async {
    final userId = args['userId'] as String? ?? '';
    final refresh = args['refresh'] as bool? ?? false;
    final userInfo = await Imclient.getUserInfo(userId, refresh: refresh);
    return userInfo != null ? _encodeUserInfo(userInfo) : null;
  }

  Future<dynamic> _handleGetUserInfos(dynamic args) async {
    final userIds = (args['userIds'] as List?)?.cast<String>() ?? <String>[];
    final groupId = args['groupId'] as String?;
    final userInfos = await Imclient.getUserInfos(userIds, groupId: groupId);
    return userInfos.map(_encodeUserInfo).toList();
  }

  Map<String, dynamic> _encodeUserInfo(UserInfo userInfo) {
    return {
      'userId': userInfo.userId,
      'name': userInfo.name,
      'displayName': userInfo.displayName,
      'portrait': userInfo.portrait,
      'gender': userInfo.gender,
      'mobile': userInfo.mobile,
      'email': userInfo.email,
      'address': userInfo.address,
      'company': userInfo.company,
      'social': userInfo.social,
      'extra': userInfo.extra,
      'friendAlias': userInfo.friendAlias,
      'groupAlias': userInfo.groupAlias,
    };
  }
}
