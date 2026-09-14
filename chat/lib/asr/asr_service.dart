import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:chat/config.dart';
import 'asr_auth.dart';

/// 语音识别服务 API，对应 asr-api 项目（https://gitee.com/wfchat/asr-api）
class AsrService {
  AsrService._();

  /// 语音消息转文字，识别结果以 SSE 流式返回
  ///
  /// [onChunk] 每收到一段识别文本回调一次，参数是这一段的增量文本。
  /// 请求失败（含获取认证码失败、鉴权失败）时只打日志、不抛出，调用方按"没有收到任何文本"判定失败。
  static Future<void> recognize(
      String audioUrl, void Function(String chunk) onChunk) async {
    try {
      final String authCode = await AsrAuth.getAuthCode();
      final http.Request request = http.Request(
        'POST',
        Uri.parse(Config.asrServerUrl ?? Config.ASR_SERVER),
      );
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Accept': '*/*',
        AsrAuth.headerAuthCode: authCode,
      });
      request.body = jsonEncode({
        'url': audioUrl,
        'noReuse': false,
        'noLlm': false,
      });

      final http.StreamedResponse response = await request.send();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('ASR API 错误: ${response.statusCode}');
        return;
      }

      // 按行解析，一行可能被拆在两个数据块里
      await for (final String line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        final String text = line.replaceAll('data:', '').trim();
        if (text.isNotEmpty) {
          onChunk(text);
        }
      }
    } catch (e) {
      debugPrint('ASR 请求异常: $e');
    }
  }
}
