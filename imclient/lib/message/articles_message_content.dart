import 'dart:convert';
import 'dart:typed_data';

import '../model/message_payload.dart';
import 'message.dart';
import 'message_content.dart';

// ignore: non_constant_identifier_names
MessageContent ArticlesMessageContentCreator() {
  return ArticlesMessageContent();
}

const articlesContentMeta = MessageContentMeta(
  MESSAGE_CONTENT_TYPE_ARTICLES,
  MessageFlag.PERSIST_AND_COUNT,
  ArticlesMessageContentCreator,
);

/// 图文/文章消息内容
///
/// 用于展示图文卡片，包含标题、摘要和文章列表
/// 消息类型: 13
class ArticlesMessageContent extends MessageContent {
  /// 文章列表
  List<ArticleItem> articles = [];

  /// 是否置顶
  bool top = false;

  /// 置顶文章索引
  int topIndex = -1;

  @override
  MessageContentMeta get meta => articlesContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    title = payload.searchableContent ?? '';

    if (payload.binaryContent != null) {
      try {
        Map<dynamic, dynamic> json =
            jsonDecode(utf8.decode(payload.binaryContent!));
        top = json['t'] != null ? json['t'] : false;
        topIndex = json['ti'] ?? -1;

        List<dynamic>? as = json['as'];
        if (as != null) {
          articles = (as).map((a) {
            return ArticleItem(
              title: a['t'] ?? '',
              digest: a['d'] ?? '',
              url: a['u'] ?? '',
              thumbnailUrl: a['th'] ?? '',
            );
          }).toList();
        }
      } catch (e) {
        articles = [];
      }
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.searchableContent = title;

    Map<String, dynamic> jsonObject = {
      't': top,
      'ti': topIndex,
      'as': articles.map((a) => a.toJson()).toList(),
    };
    payload.binaryContent =
        Uint8List.fromList(utf8.encode(jsonEncode(jsonObject)));
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    if (articles.isNotEmpty) {
      return '[图文] ${articles.first.title}';
    }
    return '[图文]';
  }

  /// 文章标题
  String title = '';
}

/// 图文中的单篇文章
class ArticleItem {
  ArticleItem({
    this.title = '',
    this.digest = '',
    this.url = '',
    this.thumbnailUrl = '',
  });

  String title;
  String digest;
  String url;
  String thumbnailUrl;

  Map<String, dynamic> toJson() {
    return {
      't': title,
      'd': digest,
      'u': url,
      'th': thumbnailUrl,
    };
  }
}
