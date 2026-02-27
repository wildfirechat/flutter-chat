import 'package:imclient/message/collection_message_content.dart' show CollectionEntry;

export 'package:imclient/message/collection_message_content.dart' show CollectionEntry;

/// 群接龙模型
class Collection {
  /// 接龙ID
  final int collectionId;

  /// 群ID
  final String groupId;

  /// 创建者ID
  final String creatorId;

  /// 接龙标题
  final String title;

  /// 接龙描述
  final String desc;

  /// 参与模板
  final String template;

  /// 过期类型：0=无限期，1=有限期
  final int expireType;

  /// 过期时间（毫秒时间戳）
  final int expireAt;

  /// 最大参与人数（0表示无限制）
  final int maxParticipants;

  /// 状态：0=进行中，1=已结束，2=已取消
  final int status;

  /// 创建时间（毫秒时间戳）
  final int createdAt;

  /// 更新时间（毫秒时间戳）
  final int updatedAt;

  /// 参与记录列表
  final List<CollectionEntry> entries;

  /// 参与人数（服务器返回的统计值）
  final int participantCount;

  Collection({
    required this.collectionId,
    required this.groupId,
    required this.creatorId,
    required this.title,
    required this.desc,
    required this.template,
    required this.expireType,
    required this.expireAt,
    required this.maxParticipants,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.entries,
    required this.participantCount,
  });

  factory Collection.fromJson(Map<String, dynamic> json) {
    List<CollectionEntry> entries = [];
    if (json['entries'] != null) {
      entries = (json['entries'] as List)
          .map((e) => CollectionEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return Collection(
      collectionId: json['id'] ?? json['collectionId'] ?? 0,
      groupId: json['groupId'] ?? '',
      creatorId: json['creatorId'] ?? '',
      title: json['title'] ?? '',
      desc: json['description'] ?? json['desc'] ?? '',
      template: json['template'] ?? '',
      expireType: json['expireType'] ?? 0,
      expireAt: json['expireAt'] ?? 0,
      maxParticipants: json['maxParticipants'] ?? 0,
      status: json['status'] ?? 0,
      createdAt: json['createdAt'] ?? 0,
      updatedAt: json['updatedAt'] ?? 0,
      entries: entries,
      participantCount: json['participantCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'collectionId': collectionId,
      'groupId': groupId,
      'creatorId': creatorId,
      'title': title,
      'desc': desc,
      'template': template,
      'expireType': expireType,
      'expireAt': expireAt,
      'maxParticipants': maxParticipants,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'participantCount': participantCount,
      'entries': entries.map((e) => e.toJson()).toList(),
    };
  }

  /// 计算实际的参与人数（排除已删除的记录）
  int calculateParticipantCount() {
    return entries.where((e) => e.deleted == 0).length;
  }

  /// 获取当前用户的参与记录
  CollectionEntry? getEntryForUser(String userId) {
    try {
      return entries.firstWhere(
        (e) => e.userId == userId && e.deleted == 0,
      );
    } catch (_) {
      return null;
    }
  }

  /// 检查用户是否已参与
  bool hasUserJoined(String userId) {
    return getEntryForUser(userId) != null;
  }

  /// 检查接龙是否已过期
  bool get isExpired {
    if (expireType == 0) return false;
    return DateTime.now().millisecondsSinceEpoch > expireAt;
  }

  /// 检查接龙是否已达到最大参与人数
  bool get isFull {
    if (maxParticipants <= 0) return false;
    return calculateParticipantCount() >= maxParticipants;
  }

  /// 检查接龙是否可参与
  bool get isJoinable => status == 0 && !isExpired && !isFull;

  /// 获取有效的参与记录（排除已删除的）
  List<CollectionEntry> get validEntries {
    return entries.where((e) => e.deleted == 0).toList();
  }
}
