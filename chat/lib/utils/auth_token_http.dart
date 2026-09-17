import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 业务服务（应用服务、组织通讯录服务等）的 authToken，和 android-chat 的 OKHttpHelper 保持一致。
///
/// 服务在响应 header authToken 里下发 token，之后的请求在 header 里带上。
/// authToken 按服务地址的 host-port 分别保存，不同的服务有不同的 authToken；
/// 双网环境下，同一个服务的主备地址对应的是同一个服务，authToken 通用，主备地址都保存，切换网络后不用重新登录。
class AuthTokenHttp {
  const AuthTokenHttp._();

  static const String _requestHeader = 'authToken';

  // http 包的响应 header 名都是小写
  static const String _responseHeader = 'authtoken';

  static const String _keyPrefix = 'authToken:';

  // 双网环境下，同一个服务主备地址的 host-port，互相指向对方
  static final Map<String, String> _dualNetworkHostPorts = {};

  /// 双网环境下，登记同一个服务的主备地址，[backupAddress] 为空时忽略。
  ///
  /// 主窗口和 PC 子窗口是不同的 isolate，各自都要登记。
  static void addDualNetworkAddress(String? address, String? backupAddress) {
    final hostPort = _hostPortOfAddress(address);
    final backupHostPort = _hostPortOfAddress(backupAddress);
    if (hostPort == null ||
        backupHostPort == null ||
        hostPort == backupHostPort) {
      return;
    }
    _dualNetworkHostPorts[hostPort] = backupHostPort;
    _dualNetworkHostPorts[backupHostPort] = hostPort;
  }

  /// 发 POST 请求，带上 [url] 对应服务的 authToken，并保存响应里下发的 authToken。
  static Future<http.Response> post(Uri url,
      {Map<String, String>? headers, Object? body}) async {
    final token = await authToken(url);
    final response = await http.post(url,
        headers: token == null ? headers : {...?headers, _requestHeader: token},
        body: body);
    final responseToken = response.headers[_responseHeader];
    if (responseToken != null && responseToken.isNotEmpty) {
      await _save(url, responseToken);
    }
    return response;
  }

  /// [url] 对应服务的 authToken，没有时返回 null。
  static Future<String?> authToken(Uri url) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_key(_hostPort(url)));
    return token == null || token.isEmpty ? null : token;
  }

  /// 清除 [url] 对应服务的 authToken，双网环境下主备地址的都清除。
  static Future<void> remove(Uri url) async {
    final prefs = await SharedPreferences.getInstance();
    for (final hostPort in _hostPortsOf(url)) {
      await prefs.remove(_key(hostPort));
    }
  }

  /// 清除所有服务的 authToken，退出登录时调用。
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final keys =
        prefs.getKeys().where((key) => key.startsWith(_keyPrefix)).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  static Future<void> _save(Uri url, String token) async {
    final prefs = await SharedPreferences.getInstance();
    for (final hostPort in _hostPortsOf(url)) {
      await prefs.setString(_key(hostPort), token);
    }
  }

  static List<String> _hostPortsOf(Uri url) {
    final hostPort = _hostPort(url);
    final otherHostPort = _dualNetworkHostPorts[hostPort];
    return [hostPort, if (otherHostPort != null) otherHostPort];
  }

  static String? _hostPortOfAddress(String? address) {
    if (address == null || address.isEmpty) {
      return null;
    }
    final url = Uri.tryParse(address);
    return url == null || url.host.isEmpty ? null : _hostPort(url);
  }

  static String _hostPort(Uri url) => '${url.host}-${url.port}';

  static String _key(String hostPort) => '$_keyPrefix$hostPort';
}
