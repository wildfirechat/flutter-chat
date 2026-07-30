import 'dart:convert';
import 'dart:typed_data';

import '../model/message_payload.dart';
import 'message.dart';
import 'message_content.dart';

// ignore: non_constant_identifier_names
MessageContent CollectionMessageContentCreator() {
  return CollectionMessageContent();
}

const int MESSAGE_CONTENT_TYPE_COLLECTION = 17;

const collectionContentMeta = MessageContentMeta(
  MESSAGE_CONTENT_TYPE_COLLECTION,
  MessageFlag.PERSIST_AND_COUNT,
  CollectionMessageContentCreator,
);

/// 群接龙参与条目
class CollectionEntry {
  /// 条目ID
  final int entryId;

  /// 接龙ID
  final int collectionId;

  /// 用户ID
  final String userId;

  /// 参与内容
  final String content;

  /// 创建时间（毫秒时间戳）
  final int createdAt;

  /// 更新时间（毫秒时间戳）
  final int updatedAt;

  /// 是否已删除：0=未删除，1=已删除
  final int deleted;

  CollectionEntry({
    this.entryId = 0,
    this.collectionId = 0,
    this.userId = '',
    this.content = '',
    this.createdAt = 0,
    this.updatedAt = 0,
    this.deleted = 0,
  });

  factory CollectionEntry.fromJson(Map<dynamic, dynamic> json) {
    return CollectionEntry(
      entryId: json['id'] ?? json['entryId'] ?? 0,
      collectionId: json['collectionId'] ?? 0,
      userId: json['userId'] ?? '',
      content: json['content'] ?? '',
      createdAt: json['createdAt'] ?? 0,
      updatedAt: json['updatedAt'] ?? 0,
      deleted: json['deleted'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'entryId': entryId,
      'collectionId': collectionId,
      'userId': userId,
      'content': content,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'deleted': deleted,
    };
  }
}

/// 群接龙消息内容
class CollectionMessageContent extends MessageContent {
  /// 接龙ID
  late String collectionId;

  /// 群ID
  late String groupId;

  /// 创建者ID
  late String creatorId;

  /// 接龙标题
  late String title;

  /// 接龙描述
  String desc = '';

  /// 参与模板
  String template = '';

  /// 过期类型：0=无限期，1=有限期
  int expireType = 0;

  /// 过期时间（毫秒时间戳）
  int expireAt = 0;

  /// 最大参与人数（0表示无限制）
  int maxParticipants = 0;

  /// 状态：0=进行中，1=已结束，2=已取消
  int status = 0;

  /// 创建时间（毫秒时间戳）
  int createdAt = 0;

  /// 更新时间（毫秒时间戳）
  int updatedAt = 0;

  /// 参与记录列表
  List<CollectionEntry> entries = [];

  @override
  MessageContentMeta get meta => collectionContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    // 从 searchableContent 解析 title
    title = payload.searchableContent ?? '';

    // 从 binaryContent 解析其他数据
    if (payload.binaryContent != null) {
      try {
        Map<dynamic, dynamic> map =
            json.decode(utf8.decode(payload.binaryContent!));
        collectionId = map['collectionId']?.toString() ?? '';
        groupId = map['groupId'] ?? '';
        creatorId = map['creatorId'] ?? '';
        desc = map['desc'] ?? '';
        template = map['template'] ?? '';
        expireType = map['expireType'] ?? 0;
        expireAt = map['expireAt'] ?? 0;
        maxParticipants = map['maxParticipants'] ?? 0;
        status = map['status'] ?? 0;
        createdAt = map['createdAt'] ?? 0;
        updatedAt = map['updatedAt'] ?? 0;

        // 解析参与记录
        entries = [];
        if (map['entries'] != null) {
          entries = (map['entries'] as List)
              .map((e) => CollectionEntry.fromJson(e))
              .toList();
        }
      } catch (e) {
        // 解析失败时设置默认值
        collectionId = '';
        groupId = '';
        creatorId = '';
        desc = '';
        template = '';
      }
    } else {
      collectionId = '';
      groupId = '';
      creatorId = '';
      desc = '';
      template = '';
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    // title 放入 searchableContent 用于搜索
    payload.searchableContent = title;

    // 其他数据 JSON 编码后放入 binaryContent
    Map<String, dynamic> dataDict = {
      'collectionId': collectionId,
      'groupId': groupId,
      'creatorId': creatorId,
      'desc': desc,
      'template': template,
      'expireType': expireType,
      'expireAt': expireAt,
      'maxParticipants': maxParticipants,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };

    // 编码参与记录
    if (entries.isNotEmpty) {
      dataDict['entries'] = entries.map((e) => e.toJson()).toList();
    }

    payload.binaryContent =
        Uint8List.fromList(utf8.encode(json.encode(dataDict)));
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    return '[群接龙]$title';
  }

  /// 获取参与人数（排除已删除的记录）
  int get participantCount {
    return entries.where((e) => e.deleted == 0).length;
  }

  /// 检查接龙是否已过期
  bool get isExpired {
    if (expireType == 0) return false;
    return DateTime.now().millisecondsSinceEpoch > expireAt;
  }

  /// 检查接龙是否进行中
  bool get isActive => status == 0 && !isExpired;
}
