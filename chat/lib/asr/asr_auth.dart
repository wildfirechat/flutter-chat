import 'dart:async';

import 'package:imclient/imclient.dart';

import 'package:chat/config.dart';
import 'asr_error.dart';

/// asr-api 鉴权
///
/// 请求 asr-api 时，需要在 HTTP header `authCode` 中带上从 IM 服务获取的认证码，
/// asr-api 向 IM 服务校验认证码后得到用户 ID，缺少或校验失败时返回 401。
/// 认证码 1 分钟内有效，每次请求前重新获取。
class AsrAuth {
  AsrAuth._();

  static const String headerAuthCode = 'authCode';

  // 和组织通讯录服务一样，使用管理后台类型（ApplicationType_Admin）的认证码
  static const String _authCodeAppId = 'admin';
  static const int _authCodeType = 2;

  /// 是否是 asr-api 的地址。asr-api 的接口都在 /api/ 路径下，直连 wf-voice 的地址没有路径
  static bool isAsrApiUrl(String url) =>
      Uri.tryParse(url)?.path.contains('/api/') ?? false;

  /// 获取认证码，失败时抛出 [AsrErrorKind.authCodeFailed]
  static Future<String> getAuthCode() {
    final Completer<String> completer = Completer<String>();
    Imclient.getAuthCode(
      _authCodeAppId,
      _authCodeType,
      Config.IM_Host,
      (authCode) => completer.complete(authCode),
      (errorCode) => completer.completeError(
          AsrError(AsrErrorKind.authCodeFailed, '$errorCode')),
    );
    return completer.future;
  }
}
