import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/file_record.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/message_payload.dart';
import 'package:imclient/model/unread_count.dart';
import 'package:imclient/model/user_info.dart';

/// 主/子窗口 IPC 的纯数据编解码,是跨窗口线格式的**唯一**定义处。
///
/// 线格式与 imclient 的 proto map 保持一致:payload 用 'type' key、
/// binaryContent 编码为 base64、conversation 用 'type' key、UserInfo 主键用
/// 'uid'。这样子窗口把主窗口返回的 map 直接交给 ImclientPlatform 的
/// _convertProtoXxx 即可解析,SDK 层无需感知 IPC 的存在;也因此这里多数
/// encode 没有对应的 decode。
///
/// **不要在各 proxy 里另写 encodeXxx**:线格式与 `_convertProtoXxx` 读取的
/// 键名是隐式契约,重复实现一旦漏字段就是静默失败。历史上出过两次:
/// - UserInfo 主键写成 'userId'(应为 'uid'),`_convertProtoUserInfo` 直接
///   返回 null,子窗口拿不到任何用户信息;
/// - GroupMember 漏了 'groupId',`_convertProtoGroupMember` 把 null 赋给
///   `late String groupId`,群通话邀请成员时抛 TypeError。
///
/// binaryContent 解码兼容三种形态:Uint8List(同 isolate)、List<int>
/// (MethodChannel 透传后 Uint8List 常被重建为 List<dynamic>)、base64 字符串
/// (本 codec 编码产物)。
class IpcCodec {
  static Map<String, dynamic> encodeConversation(Conversation conversation) {
    return {
      'type': conversation.conversationType.index,
      'target': conversation.target,
      'line': conversation.line,
    };
  }

  static Conversation decodeConversation(Map<dynamic, dynamic> map) {
    return Conversation(
      conversationType: ConversationType.values[map['type'] as int? ?? 0],
      target: map['target'] as String? ?? '',
      line: map['line'] as int? ?? 0,
    );
  }

  static Map<String, dynamic> encodeMessage(Message message) {
    return {
      'messageId': message.messageId,
      'messageUid': message.messageUid,
      'conversation': encodeConversation(message.conversation),
      'fromUser': message.fromUser,
      'toUsers': message.toUsers,
      'direction': message.direction.index,
      'status': message.status.index,
      'serverTime': message.serverTime,
      'localExtra': message.localExtra,
      'content': encodePayload(message.content.encode()),
    };
  }

  static Map<String, dynamic> encodePayload(MessagePayload payload) {
    return {
      'type': payload.contentType,
      'searchableContent': payload.searchableContent,
      'pushContent': payload.pushContent,
      'pushData': payload.pushData,
      'content': payload.content,
      'binaryContent': payload.binaryContent != null
          ? base64Encode(payload.binaryContent!)
          : null,
      'localContent': payload.localContent,
      'mentionedType': payload.mentionedType,
      'mentionedTargets': payload.mentionedTargets,
      'mediaType': payload.mediaType.index,
      'remoteMediaUrl': payload.remoteMediaUrl,
      'localMediaPath': payload.localMediaPath,
      'extra': payload.extra,
    };
  }

  static MessagePayload decodePayload(Map<dynamic, dynamic> map) {
    final payload = MessagePayload();
    payload.contentType = map['type'] as int? ?? 0;
    payload.searchableContent = map['searchableContent'] as String?;
    payload.pushContent = map['pushContent'] as String?;
    payload.pushData = map['pushData'] as String?;
    payload.content = map['content'] as String?;
    final binary = map['binaryContent'];
    if (binary is Uint8List) {
      payload.binaryContent = binary;
    } else if (binary is List) {
      payload.binaryContent = Uint8List.fromList(List<int>.from(binary));
    } else if (binary is String && binary.isNotEmpty) {
      payload.binaryContent = base64Decode(binary);
    } else if (binary != null) {
      log('IpcCodec unexpected binaryContent type: ${binary.runtimeType}');
    }
    payload.localContent = map['localContent'] as String?;
    payload.mentionedType = map['mentionedType'] as int? ?? 0;
    payload.mentionedTargets =
        (map['mentionedTargets'] as List?)?.cast<String>();
    payload.mediaType = MediaType.values[map['mediaType'] as int? ?? 0];
    payload.remoteMediaUrl = map['remoteMediaUrl'] as String?;
    payload.localMediaPath = map['localMediaPath'] as String?;
    payload.extra = map['extra'] as String?;
    return payload;
  }

  // ------------------------------------------------------------------ 用户/群成员

  /// 主键必须是 'uid':`_convertProtoUserInfo` 见到 map['uid'] == null 会
  /// 直接返回 null。
  static Map<String, dynamic> encodeUserInfo(UserInfo user) {
    return {
      'uid': user.userId,
      'name': user.name,
      'displayName': user.displayName,
      'gender': user.gender,
      'portrait': user.portrait,
      'mobile': user.mobile,
      'email': user.email,
      'address': user.address,
      'company': user.company,
      'social': user.social,
      'extra': user.extra,
      'friendAlias': user.friendAlias,
      'groupAlias': user.groupAlias,
      'updateDt': user.updateDt,
      'type': user.type,
      'deleted': user.deleted,
    };
  }

  /// 'groupId' 不可省:`GroupMember.groupId` 是 `late String`,
  /// `_convertProtoGroupMember` 无条件赋值,缺键会以 TypeError 形式抛出。
  static Map<String, dynamic> encodeGroupMember(GroupMember member) {
    return {
      'groupId': member.groupId,
      'memberId': member.memberId,
      'alias': member.alias,
      'extra': member.extra,
      'type': member.type.index,
      'createDt': member.createDt,
      'updateDt': member.updateDt,
    };
  }

  // ------------------------------------------------------------------ 其它模型

  /// [FileRecord.url] 是 late 字段,个别记录可能未赋值,读取前需兜住。
  static Map<String, dynamic> encodeFileRecord(FileRecord record) {
    String url = '';
    try {
      url = record.url;
    } catch (_) {
      // url 未赋值,按空串处理
    }
    return {
      'conversation': record.conversation != null
          ? encodeConversation(record.conversation!)
          : null,
      'userId': record.userId,
      'messageUid': record.messageUid,
      'name': record.name,
      'url': url,
      'size': record.size,
      'downloadCount': record.downloadCount,
      'timestamp': record.timestamp,
    };
  }

  static Map<String, dynamic> encodeUnreadCount(UnreadCount unread) {
    return {
      'unread': unread.unread,
      'unreadMention': unread.unreadMention,
      'unreadMentionAll': unread.unreadMentionAll,
    };
  }
}
