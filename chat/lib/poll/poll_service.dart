import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:imclient/imclient.dart';

import '../config.dart';
import '../utils/media_url_redirector.dart';
import 'poll_model.dart';

/// 投票服务工具类
///
/// 使用方式：
/// ```dart
/// if (PollService.isAvailable) {
///   final poll = await PollService.getPoll(pollId);
/// }
/// ```
///
/// 认证方式：使用 getAuthCode 获取认证码，通过 HTTP Header 传递
/// authCodeId = "poll", authCodeType = 2
class PollService {
  static const String _authCodeId = 'poll';
  static const int _authCodeType = 2;

  /// 检查投票服务是否可用
  static bool get isAvailable {
    return Config.pollServerAddress != null &&
        Config.pollServerAddress!.isNotEmpty;
  }

  /// 获取服务基础地址
  static String get _baseUrl {
    final url = Config.pollServerAddress;
    if (url == null || url.isEmpty) {
      throw PollException(-1, '投票服务未配置');
    }
    return MediaUrlRedirector.redirect(url);
  }

  /// 从 URL 中提取 host
  static String _extractHost(String url) {
    String host = url;
    if (host.startsWith('https://')) {
      host = host.substring(8);
    } else if (host.startsWith('http://')) {
      host = host.substring(7);
    }
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
          PollException(errorCode, '获取认证码失败'),
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
        throw PollException(code, data['message'] ?? '请求失败');
      }
      return data;
    } else {
      throw PollException(-1, '网络错误: ${response.statusCode}');
    }
  }

  /// 创建投票
  /// POST /api/polls
  static Future<Poll> create({
    required String groupId,
    required String title,
    String? desc,
    required List<String> options,
    int visibility = 1,
    int type = 1,
    int maxSelect = 1,
    int anonymous = 0,
    int endTime = 0,
    int showResult = 0,
  }) async {
    final params = <String, dynamic>{
      'groupId': groupId,
      'title': title,
      'options': options,
      'visibility': visibility,
      'type': type,
      'maxSelect': maxSelect,
      'anonymous': anonymous,
      'endTime': endTime,
      'showResult': showResult,
    };

    if (desc != null && desc.isNotEmpty) {
      params['description'] = desc;
    }

    final data = await _post('/api/polls', params);
    final result = data['data'] as Map<String, dynamic>?;
    if (result == null) {
      throw PollException(-1, '返回数据为空');
    }
    return Poll.fromJson(result);
  }

  /// 获取投票详情
  /// GET /api/polls/{pollId}
  static Future<Poll> getPoll(int pollId) async {
    final data = await _post('/api/polls/$pollId', {});
    final result = data['data'] as Map<String, dynamic>?;
    if (result == null) {
      throw PollException(-1, '返回数据为空');
    }
    return Poll.fromJson(result);
  }

  /// 参与投票
  /// POST /api/polls/{pollId}/vote
  static Future<void> vote(int pollId, List<int> optionIds) async {
    final params = <String, dynamic>{
      'optionIds': optionIds,
    };
    await _post('/api/polls/$pollId/vote', params);
  }

  /// 结束投票（仅创建者）
  /// POST /api/polls/{pollId}/close
  static Future<void> close(int pollId) async {
    await _post('/api/polls/$pollId/close', {});
  }

  /// 删除投票（仅创建者）
  /// POST /api/polls/{pollId}/delete
  static Future<void> delete(int pollId) async {
    await _post('/api/polls/$pollId/delete', {});
  }

  /// 导出投票明细（仅实名投票创建者）
  /// GET /api/polls/{pollId}/export
  static Future<List<PollVoterDetail>> exportDetails(int pollId) async {
    final data = await _post('/api/polls/$pollId/export', {});
    final result = data['data'] as List?;
    if (result == null) {
      return [];
    }
    return result
        .map((e) => PollVoterDetail.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 获取我的投票列表
  /// GET /api/polls/my
  static Future<List<Poll>> getMyPolls() async {
    final data = await _post('/api/polls/my', {});
    final result = data['data'] as List?;
    if (result == null) {
      return [];
    }
    return result
        .map((e) => Poll.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// 投票异常
class PollException implements Exception {
  final int code;
  final String message;

  PollException(this.code, this.message);

  @override
  String toString() => 'PollException($code): $message';
}
