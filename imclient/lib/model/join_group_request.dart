import '../message/message.dart';

/// 入群申请状态
enum JoinGroupRequestStatus {
  /// 待处理
  pending,

  /// 已通过
  accepted,

  /// 已拒绝
  rejected,
}

/// 入群申请模型
///
/// 对应原生层返回的 JSON:
/// {
///   "groupId": "...",
///   "memberId": "...",
///   "requestUserId": "...",
///   "acceptUserId": "...",
///   "reason": "...",
///   "extra": "...",
///   "status": 0,
///   "readStatus": 0,
///   "timestamp": 1234567890
/// }
class JoinGroupRequest {
  final String groupId;
  final String memberId;

  /// 发起请求/邀请的用户ID
  final String? requestUserId;

  /// 处理请求的管理员ID
  final String? acceptUserId;
  final String? reason;
  final String? extra;
  final JoinGroupRequestStatus status;
  final int readStatus;
  final int timestamp;

  JoinGroupRequest({
    required this.groupId,
    required this.memberId,
    this.requestUserId,
    this.acceptUserId,
    this.reason,
    this.extra,
    this.status = JoinGroupRequestStatus.pending,
    this.readStatus = 0,
    this.timestamp = 0,
  });

  factory JoinGroupRequest.fromJson(Map<dynamic, dynamic> json) {
    int statusValue = 0;
    if (json['status'] is int) {
      statusValue = json['status'];
    }
    JoinGroupRequestStatus status;
    switch (statusValue) {
      case 1:
        status = JoinGroupRequestStatus.accepted;
        break;
      case 2:
        status = JoinGroupRequestStatus.rejected;
        break;
      case 0:
      default:
        status = JoinGroupRequestStatus.pending;
        break;
    }

    return JoinGroupRequest(
      groupId: json['groupId'] ?? json['gid'] ?? '',
      memberId: json['memberId'] ?? json['mid'] ?? '',
      requestUserId: json['requestUserId'] ?? json['inviterId'] ?? json['rid'],
      acceptUserId: json['acceptUserId'] ?? json['acceptUid'],
      reason: json['reason'],
      extra: json['extra'],
      status: status,
      readStatus: json['readStatus'] ?? json['read'] ?? 0,
      timestamp: json['timestamp'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    int statusValue;
    switch (status) {
      case JoinGroupRequestStatus.accepted:
        statusValue = 1;
        break;
      case JoinGroupRequestStatus.rejected:
        statusValue = 2;
        break;
      case JoinGroupRequestStatus.pending:
      default:
        statusValue = 0;
        break;
    }
    return {
      'groupId': groupId,
      'memberId': memberId,
      'requestUserId': requestUserId,
      'acceptUserId': acceptUserId,
      'reason': reason,
      'extra': extra,
      'status': statusValue,
      'readStatus': readStatus,
      'timestamp': timestamp,
    };
  }
}
