import 'package:chat/l10n/app_localizations.dart';

/// 投票选项
class PollOption {
  /// 选项ID
  final int optionId;

  /// 选项文本
  final String optionText;

  /// 排序
  final int sortOrder;

  /// 票数
  final int voteCount;

  /// 投票百分比
  final int votePercent;

  PollOption({
    this.optionId = 0,
    this.optionText = '',
    this.sortOrder = 0,
    this.voteCount = 0,
    this.votePercent = 0,
  });

  factory PollOption.fromJson(Map<String, dynamic> json) {
    return PollOption(
      optionId: json['id'] ?? json['optionId'] ?? 0,
      optionText: json['optionText'] ?? '',
      sortOrder: json['sortOrder'] ?? 0,
      voteCount: json['voteCount'] ?? 0,
      votePercent: json['votePercent'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'optionId': optionId,
      'optionText': optionText,
      'sortOrder': sortOrder,
      'voteCount': voteCount,
      'votePercent': votePercent,
    };
  }
}

/// 投票人详情
class PollVoterDetail {
  /// 用户ID
  final String userId;

  /// 用户名
  final String userName;

  /// 选项ID
  final int optionId;

  /// 选项文本
  final String optionText;

  /// 投票时间
  final int voteTime;

  PollVoterDetail({
    this.userId = '',
    this.userName = '',
    this.optionId = 0,
    this.optionText = '',
    this.voteTime = 0,
  });

  factory PollVoterDetail.fromJson(Map<String, dynamic> json) {
    return PollVoterDetail(
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      optionId: json['optionId'] ?? 0,
      optionText: json['optionText'] ?? '',
      voteTime: json['voteTime'] ?? json['createdAt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'optionId': optionId,
      'optionText': optionText,
      'voteTime': voteTime,
    };
  }
}

/// 投票数据模型
class Poll {
  /// 投票ID
  final int pollId;

  /// 群ID
  final String groupId;

  /// 创建者ID
  final String creatorId;

  /// 标题
  final String title;

  /// 描述
  final String desc;

  /// 可见性: 1=仅群内, 2=公开
  final int visibility;

  /// 类型: 1=单选, 2=多选
  final int type;

  /// 多选时最多选几项
  final int maxSelect;

  /// 是否匿名: 0=实名, 1=匿名
  final int anonymous;

  /// 状态: 0=进行中, 1=已结束
  final int status;

  /// 截止时间
  final int endTime;

  /// 是否显示结果: 0=投票前隐藏, 1=始终显示
  final int showResult;

  /// 创建时间
  final int createdAt;

  /// 更新时间
  final int updatedAt;

  /// 是否已投票
  final bool hasVoted;

  /// 是否是创建者
  final bool isCreator;

  /// 我选择的选项ID列表
  final List<int> myOptionIds;

  /// 是否已删除
  final bool deleted;

  /// 总票数
  final int totalVotes;

  /// 投票人数
  final int voterCount;

  /// 选项列表
  final List<PollOption> options;

  /// 投票人详情
  final List<PollVoterDetail> voterDetails;

  Poll({
    this.pollId = 0,
    this.groupId = '',
    this.creatorId = '',
    this.title = '',
    this.desc = '',
    this.visibility = 1,
    this.type = 1,
    this.maxSelect = 1,
    this.anonymous = 0,
    this.status = 0,
    this.endTime = 0,
    this.showResult = 0,
    this.createdAt = 0,
    this.updatedAt = 0,
    this.hasVoted = false,
    this.isCreator = false,
    this.myOptionIds = const [],
    this.deleted = false,
    this.totalVotes = 0,
    this.voterCount = 0,
    this.options = const [],
    this.voterDetails = const [],
  });

  factory Poll.fromJson(Map<String, dynamic> json) {
    List<PollOption> options = [];
    if (json['options'] != null) {
      options = (json['options'] as List)
          .map((e) => PollOption.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    List<int> myOptionIds = [];
    if (json['myOptionIds'] != null) {
      myOptionIds = (json['myOptionIds'] as List).map((e) => e as int).toList();
    }

    List<PollVoterDetail> voterDetails = [];
    if (json['voterDetails'] != null) {
      voterDetails = (json['voterDetails'] as List)
          .map((e) => PollVoterDetail.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return Poll(
      pollId: json['id'] ?? json['pollId'] ?? 0,
      groupId: json['groupId'] ?? '',
      creatorId: json['creatorId'] ?? '',
      title: json['title'] ?? '',
      desc: json['description'] ?? json['desc'] ?? '',
      visibility: json['visibility'] ?? 1,
      type: json['type'] ?? 1,
      maxSelect: json['maxSelect'] ?? 1,
      anonymous: json['anonymous'] ?? 0,
      status: json['status'] ?? 0,
      endTime: json['endTime'] ?? 0,
      showResult: json['showResult'] ?? 0,
      createdAt: json['createdAt'] ?? 0,
      updatedAt: json['updatedAt'] ?? 0,
      hasVoted: json['hasVoted'] ?? false,
      isCreator: json['isCreator'] ?? false,
      myOptionIds: myOptionIds,
      deleted: json['deleted'] ?? false,
      totalVotes: json['totalVotes'] ?? 0,
      voterCount: json['voterCount'] ?? 0,
      options: options,
      voterDetails: voterDetails,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pollId': pollId,
      'groupId': groupId,
      'creatorId': creatorId,
      'title': title,
      'desc': desc,
      'visibility': visibility,
      'type': type,
      'maxSelect': maxSelect,
      'anonymous': anonymous,
      'status': status,
      'endTime': endTime,
      'showResult': showResult,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'hasVoted': hasVoted,
      'isCreator': isCreator,
      'myOptionIds': myOptionIds,
      'deleted': deleted,
      'totalVotes': totalVotes,
      'voterCount': voterCount,
      'options': options.map((e) => e.toJson()).toList(),
      'voterDetails': voterDetails.map((e) => e.toJson()).toList(),
    };
  }

  /// 是否显示结果
  /// 投票已结束或已投票者可见
  bool get shouldShowResult {
    if (status == 1) return true;
    if (hasVoted) return true;
    return false;
  }

  /// 是否已过期
  bool get isExpired {
    if (endTime > 0) {
      return endTime < DateTime.now().millisecondsSinceEpoch;
    }
    return false;
  }

  /// 是否已结束
  bool get isEnded => status == 1 || isExpired;

  /// 是否进行中
  bool get isActive => status == 0 && !isExpired;

  /// 获取剩余时间文本
  String? getRemainingTimeText(AppLocalizations l10n) {
    if (status == 1) return l10n.pollStatusEnded;
    if (endTime <= 0) return null;

    int now = DateTime.now().millisecondsSinceEpoch;
    int remaining = endTime - now;

    if (remaining <= 0) return l10n.expired;

    int minutes = remaining ~/ 60000;
    int hours = minutes ~/ 60;
    int days = hours ~/ 24;

    if (days > 0) return l10n.pollDaysLeft(days);
    if (hours > 0) return l10n.pollHoursLeft(hours);
    return l10n.pollMinutesLeft(minutes);
  }

  /// 是否单选
  bool get isSingleChoice => type == 1;

  /// 是否多选
  bool get isMultiChoice => type == 2;
}
