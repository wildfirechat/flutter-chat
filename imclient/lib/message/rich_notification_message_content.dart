import 'dart:convert';
import 'dart:typed_data';

import '../model/message_payload.dart';
import 'message.dart';
import 'message_content.dart';
import 'notification/notification_message_content.dart';

// ignore: non_constant_identifier_names
MessageContent RichNotificationContentCreator() {
  return RichNotificationMessageContent();
}

const richNotificationContentMeta = MessageContentMeta(
  MESSAGE_CONTENT_TYPE_RICH_NOTIFICATION,
  MessageFlag.PERSIST,
  RichNotificationContentCreator,
);

/// 富通知消息里的一条键值数据(如"登陆账户: 野火IM"),对应线协议 datas 数组里的一项。
class RichNotificationData {
  RichNotificationData(this.key, this.value, [this.color]);

  final String key;
  final String value;

  /// 值的显示颜色,形如 "#173155"；为空则跟随默认文字颜色
  final String? color;

  factory RichNotificationData.fromJson(Map<dynamic, dynamic> json) {
    return RichNotificationData(
      json['key'] ?? '',
      json['value'] ?? '',
      json['color'],
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'value': value,
        if (color != null) 'color': color,
      };
}

/// 富通知消息内容
///
/// 富文本类型的系统通知消息,可包含标题、描述、键值数据列表、附加身份信息等。
/// 线协议与 Android/iOS/Web 各端保持一致:
/// title 走 pushContent,desc 走 content,其余字段打包进 binaryContent 的 JSON。
/// 消息类型: 12
class RichNotificationMessageContent extends NotificationMessageContent {
  /// 通知标题
  String title = '';

  /// 通知描述
  String desc = '';

  /// 备注信息
  String? remark;

  /// 键值数据列表,如登陆账户、登陆地点等
  List<RichNotificationData>? datas;

  /// 附加名称
  String? exName;

  /// 附加头像地址
  String? exPortrait;

  /// 点击通知后的跳转链接
  String? exUrl;

  /// 应用 ID
  String? appId;

  @override
  MessageContentMeta get meta => richNotificationContentMeta;

  @override
  void decode(MessagePayload payload) {
    super.decode(payload);
    title = payload.pushContent ?? '';
    desc = payload.content ?? '';

    if (payload.binaryContent != null) {
      try {
        Map<dynamic, dynamic> json = jsonDecode(utf8.decode(payload.binaryContent!));
        remark = json['remark'];
        exName = json['exName'];
        exPortrait = json['exPortrait'];
        exUrl = json['exUrl'];
        appId = json['appId'];
        List<dynamic>? rawDatas = json['datas'];
        if (rawDatas != null && rawDatas.isNotEmpty) {
          datas = rawDatas.map((e) => RichNotificationData.fromJson(e)).toList();
        }
      } catch (e) {
        // binaryContent 解析失败时保留 title/desc,忽略附加信息
      }
    }
  }

  @override
  MessagePayload encode() {
    MessagePayload payload = super.encode();
    payload.pushContent = title;
    payload.content = desc;

    Map<String, dynamic> jsonObject = {
      'remark': remark,
      'exName': exName,
      'exPortrait': exPortrait,
      'exUrl': exUrl,
      'appId': appId,
      'datas': datas?.map((e) => e.toJson()).toList(),
    };
    payload.binaryContent = Uint8List.fromList(utf8.encode(jsonEncode(jsonObject)));
    return payload;
  }

  @override
  Future<String> digest(Message message) async {
    return title.isNotEmpty ? title : '[富通知]';
  }

  @override
  Future<String> formatNotification(Message message) async {
    return title.isNotEmpty ? title : desc;
  }
}
