import 'dart:convert';

import 'package:imclient/model/quote_info.dart';

/// 会话草稿结构化数据，对齐 iOS WFCUChatInputBar 的草稿格式。
///
/// 普通文本草稿直接存字符串；包含 @ 或引用时存 JSON：
/// {
///   "content": "...",
///   "mentions": [
///     {"uid": "userId", "isMentionAll": false, "start": 0, "end": 5}
///   ],
///   "quoteInfo": {"u": 123, "i": "userId", "n": "name", "d": "digest"}
/// }
class DraftData {
  String content;
  List<DraftMention> mentions;
  QuoteInfo? quoteInfo;

  DraftData({this.content = '', this.mentions = const [], this.quoteInfo});

  bool get isStructured => mentions.isNotEmpty || quoteInfo != null;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'content': content};
    if (mentions.isNotEmpty) {
      map['mentions'] = mentions.map((m) => m.toJson()).toList();
    }
    if (quoteInfo != null) {
      final q = <String, dynamic>{'u': quoteInfo!.messageUid};
      if (quoteInfo!.userId != null) q['i'] = quoteInfo!.userId;
      if (quoteInfo!.userDisplayName != null) q['n'] = quoteInfo!.userDisplayName;
      if (quoteInfo!.messageDigest != null) q['d'] = quoteInfo!.messageDigest;
      map['quoteInfo'] = q;
    }
    return map;
  }

  String toDraftString() => json.encode(toJson());

  static DraftData fromDraftString(String draft) {
    final data = DraftData(content: draft);
    try {
      final map = json.decode(draft) as Map<String, dynamic>;
      if (map['content'] is String) {
        data.content = map['content'] as String;
      } else if (map['text'] is String) {
        data.content = map['text'] as String;
      }
      if (map['mentions'] is List) {
        data.mentions = (map['mentions'] as List)
            .whereType<Map<String, dynamic>>()
            .map((m) => DraftMention.fromJson(m))
            .toList();
      }
      final quote = map['quoteInfo'] ?? map['quote'];
      if (quote is Map<String, dynamic>) {
        data.quoteInfo = _parseQuoteInfo(quote);
      }
    } catch (_) {
      // 解析失败时按纯文本草稿处理
    }
    return data;
  }

  static QuoteInfo _parseQuoteInfo(Map<String, dynamic> map) {
    int? messageUid;
    if (map['messageUid'] != null) {
      messageUid = (map['messageUid'] as num).toInt();
    } else if (map['u'] != null) {
      messageUid = (map['u'] as num).toInt();
    }
    final quoteInfo = QuoteInfo(messageUid ?? 0);
    quoteInfo.userId = map['userId'] ?? map['i'] as String?;
    quoteInfo.userDisplayName = map['userDisplayName'] ?? map['n'] as String?;
    quoteInfo.messageDigest = map['messageDigest'] ?? map['d'] as String?;
    return quoteInfo;
  }

  /// 从任意草稿字符串中提取展示文本。
  static String displayText(String draft) {
    if (draft.isEmpty) return '';
    final data = fromDraftString(draft);
    if (data.isStructured) return data.content;
    return draft;
  }
}

class DraftMention {
  String uid;
  bool isMentionAll;
  int start;
  int end;
  String? displayName;

  DraftMention({
    required this.uid,
    this.isMentionAll = false,
    required this.start,
    required this.end,
    this.displayName,
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'isMentionAll': isMentionAll,
      'start': start,
      'end': end,
      if (displayName != null) 'displayName': displayName,
    };
  }

  static DraftMention fromJson(Map<String, dynamic> map) {
    if (map['uid'] != null || map['isMentionAll'] != null) {
      return DraftMention(
        uid: map['uid'] as String? ?? '',
        isMentionAll: map['isMentionAll'] == true,
        start: (map['start'] as num?)?.toInt() ?? 0,
        end: (map['end'] as num?)?.toInt() ?? 0,
        displayName: map['displayName'] as String?,
      );
    }
    // 兼容旧格式
    return DraftMention(
      uid: map['target'] as String? ?? '',
      isMentionAll: (map['type'] as num?)?.toInt() == 2,
      start: (map['loc'] as num?)?.toInt() ?? 0,
      end: ((map['loc'] as num?)?.toInt() ?? 0) + ((map['len'] as num?)?.toInt() ?? 0),
      displayName: map['displayName'] as String?,
    );
  }
}
