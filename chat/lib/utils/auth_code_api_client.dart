import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:imclient/imclient.dart';

/// 使用 IM authCode 鉴权的业务后端（接龙/投票/网盘等）共享 HTTP client。
///
/// 认证方式：每次请求先经 [Imclient.getAuthCode] 获取认证码，
/// 通过 `authCode` header 传递；响应约定 `{code: 0, message, ...}`，
/// `code != 0` 视为业务错误。
///
/// 各服务通过 [exceptionFactory] 保留自己的异常类型，
/// 通过 [baseUrlProvider] 保留自己的地址配置与双网重定向逻辑
/// （每次请求时求值，以便主备网切换即时生效）。
class AuthCodeApiClient {
  final String authCodeId;
  final int authCodeType;
  final String Function() baseUrlProvider;
  final Exception Function(int code, String message) exceptionFactory;

  const AuthCodeApiClient({
    required this.authCodeId,
    this.authCodeType = 2,
    required this.baseUrlProvider,
    required this.exceptionFactory,
  });

  /// 从 URL 中提取 host（getAuthCode 的 target 参数）。
  static String extractHost(String url) {
    String host = url;
    if (host.startsWith('https://')) {
      host = host.substring(8);
    } else if (host.startsWith('http://')) {
      host = host.substring(7);
    }
    final slashIndex = host.indexOf('/');
    if (slashIndex > 0) {
      host = host.substring(0, slashIndex);
    }
    return host;
  }

  Future<String> _getAuthCode(String baseUrl) {
    final completer = Completer<String>();
    Imclient.getAuthCode(
      authCodeId,
      authCodeType,
      extractHost(baseUrl),
      (authCode) => completer.complete(authCode),
      (errorCode) =>
          completer.completeError(exceptionFactory(errorCode, '获取认证码失败')),
    );
    return completer.future;
  }

  /// 带认证的 POST 请求，返回解析后的响应 JSON（已校验 code == 0）。
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> params,
  ) async {
    final baseUrl = baseUrlProvider();
    final authCode = await _getAuthCode(baseUrl);

    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        'authCode': authCode,
      },
      body: json.encode(params),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final code = data['code'] ?? -1;
      if (code != 0) {
        throw exceptionFactory(code, data['message'] ?? '请求失败');
      }
      return data;
    } else {
      throw exceptionFactory(-1, '网络错误: ${response.statusCode}');
    }
  }
}
