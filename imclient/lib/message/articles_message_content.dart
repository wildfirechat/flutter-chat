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

/// 图文消息内容
///
/// 频道(公众号)推送的图文卡片:一篇主文章 + 若干子文章。
/// 消息类型: 13
///
/// binaryContent 的格式与 Android/iOS/Web 端一致:
/// `{"top": {文章}, "subArticles": [{文章}, ...]}`,
/// 单篇文章为 `{"id","cover","title","digest","url","rr"}`。
class ArticlesMessageContent extends MessageContent {
  /// 主文章。正常消息一定有主文章,解析失败时为 null,UI 需容错。
  Article? topArticle;

  /// 子文章列表,可能为 null
  List<Article>? subArticles;

  @override
  MessageContentMeta get meta => articlesContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    if (payload.binaryContent == null) {
      return;
    }
    try {
      Map<dynamic, dynamic> json =
          jsonDecode(utf8.decode(payload.binaryContent!));
      if (json['top'] != null) {
        topArticle = Article.fromJson(json['top']);
      }
      List<dynamic>? subs = json['subArticles'];
      if (subs != null && subs.isNotEmpty) {
        subArticles = subs.map((a) => Article.fromJson(a)).toList();
      }
    } catch (e) {
      topArticle = null;
      subArticles = null;
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.searchableContent = topArticle?.title;

    Map<String, dynamic> json = {
      'top': topArticle?.toJson() ?? {},
    };
    if (subArticles != null && subArticles!.isNotEmpty) {
      json['subArticles'] = subArticles!.map((a) => a.toJson()).toList();
    }
    payload.binaryContent = Uint8List.fromList(utf8.encode(jsonEncode(json)));
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    String? title = topArticle?.title;
    if (title != null && title.isNotEmpty) {
      return title;
    }
    return '[图文]';
  }
}

/// 图文中的单篇文章
class Article {
  Article({
    this.articleId = '',
    this.cover = '',
    this.title = '',
    this.digest = '',
    this.url = '',
    this.readReport = false,
  });

  String articleId;

  /// 封面图 url
  String cover;
  String title;

  /// 摘要
  String digest;

  /// 文章链接
  String url;

  /// 是否需要阅读回执
  bool readReport;

  Map<String, dynamic> toJson() {
    return {
      'id': articleId,
      'cover': cover,
      'title': title,
      'digest': digest,
      'url': url,
      'rr': readReport,
    };
  }

  static Article fromJson(Map<dynamic, dynamic> json) {
    return Article(
      articleId: json['id'] ?? '',
      cover: json['cover'] ?? '',
      title: json['title'] ?? '',
      digest: json['digest'] ?? '',
      url: json['url'] ?? '',
      readReport: json['rr'] ?? false,
    );
  }
}
