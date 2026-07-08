import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:imclient/imclient.dart';

import '../config.dart';
import '../utils/media_url_redirector.dart';
import 'collection_model.dart';

/// 接龙服务工具类
/// 
/// 使用方式：
/// ```dart
/// if (CollectionService.isAvailable) {
///   final collection = await CollectionService.getCollection(id, groupId);
/// }
/// ```
/// 
/// 认证方式：使用 getAuthCode 获取认证码，通过 HTTP Header 传递
/// authCodeId = "collection", authCodeType = 2
class CollectionService {
  static const String _authCodeId = 'collection';
  static const int _authCodeType = 2;

  /// 检查接龙服务是否可用
  static bool get isAvailable {
    final url = Config.collectionServerAddress;
    return url != null && url.isNotEmpty;
  }

  /// 获取服务基础地址
  static String get _baseUrl {
    final url = Config.collectionServerAddress;
    if (url == null || url.isEmpty) {
      throw CollectionException(-1, '接龙服务未配置');
    }
    return MediaUrlRedirector.redirect(url);
  }

  /// 从 URL 中提取 host
  static String _extractHost(String url) {
    String host = url;
    // 去除协议前缀
    if (host.startsWith('https://')) {
      host = host.substring(8);
    } else if (host.startsWith('http://')) {
      host = host.substring(7);
    }
    // 去除路径部分
    int slashIndex = host.indexOf('/');
    if (slashIndex > 0) {
      host = host.substring(0, slashIndex);
    }
    return host;
  }

  /// 获取认证码
  static Future<String> _getAuthCode() async {
    final completer = Completer<String>();
    final host = _extractHost(_baseUrl);
    
    Imclient.getAuthCode(
      _authCodeId,
      _authCodeType,
      host,
      (authCode) {
        completer.complete(authCode);
      },
      (errorCode) {
        completer.completeError(
          CollectionException(errorCode, '获取认证码失败'),
        );
      },
    );
    
    return completer.future;
  }

  /// 带认证的 POST 请求
  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> params,
  ) async {
    final authCode = await _getAuthCode();
    final url = Uri.parse('$_baseUrl$path');
    
    final response = await http.post(
      url,
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
        throw CollectionException(code, data['message'] ?? '请求失败');
      }
      return data;
    } else {
      throw CollectionException(-1, '网络错误: ${response.statusCode}');
    }
  }

  /// 创建接龙
  /// POST /api/collections
  static Future<Collection> create({
    required String groupId,
    required String title,
    String? desc,
    String? template,
    int expireType = 0,
    int expireAt = 0,
    int maxParticipants = 0,
  }) async {
    final params = <String, dynamic>{
      'groupId': groupId,
      'title': title,
      if (desc != null && desc.isNotEmpty) 'description': desc,
      if (template != null && template.isNotEmpty) 'template': template,
      'expireType': expireType,
      if (expireType == 1) 'expireAt': expireAt,
      'maxParticipants': maxParticipants,
    };

    final data = await _post('/api/collections', params);
    final result = data['data'] as Map<String, dynamic>?;
    if (result == null) {
      throw CollectionException(-1, '返回数据为空');
    }
    return Collection.fromJson(result);
  }

  /// 获取接龙详情
  /// POST /api/collections/{collectionId}/detail
  static Future<Collection> getCollection(int collectionId, String groupId) async {
    final params = <String, dynamic>{
      'groupId': groupId,
    };

    final data = await _post('/api/collections/$collectionId/detail', params);
    final result = data['data'] as Map<String, dynamic>?;
    if (result == null) {
      throw CollectionException(-1, '返回数据为空');
    }
    return Collection.fromJson(result);
  }

  /// 参与接龙或更新参与内容
  /// POST /api/collections/{collectionId}/join
  static Future<void> join(int collectionId, String groupId, String content) async {
    final params = <String, dynamic>{
      'groupId': groupId,
      'content': content,
    };

    await _post('/api/collections/$collectionId/join', params);
  }

  /// 删除自己的参与记录
  /// POST /api/collections/{collectionId}/delete
  static Future<void> deleteEntry(int collectionId, String groupId) async {
    final params = <String, dynamic>{
      'groupId': groupId,
    };

    await _post('/api/collections/$collectionId/delete', params);
  }

  /// 关闭接龙（仅创建者可操作）
  /// POST /api/collections/{collectionId}/close
  static Future<void> close(int collectionId, String groupId) async {
    final params = <String, dynamic>{
      'groupId': groupId,
    };

    await _post('/api/collections/$collectionId/close', params);
  }
}

/// 接龙异常
class CollectionException implements Exception {
  final int code;
  final String message;

  CollectionException(this.code, this.message);

  @override
  String toString() => 'CollectionException($code): $message';
}
