import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/video_message_content.dart';
import 'package:imclient/message/file_message_content.dart';
import 'package:imclient/message/sound_message_content.dart';
import 'package:imclient/message/composite_message_content.dart';
import 'package:imclient/message/link_message_content.dart';
import 'package:imclient/message/unknown_message_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/message_payload.dart';

class FavoriteItem {
  int favId;
  int messageUid;
  int favType;
  int timestamp;
  Conversation conversation;
  String origin;
  String sender;
  String title;
  String url;
  String thumbUrl;
  String data;

  FavoriteItem({
    required this.favId,
    required this.messageUid,
    required this.favType,
    required this.timestamp,
    required this.conversation,
    required this.origin,
    required this.sender,
    required this.title,
    required this.url,
    required this.thumbUrl,
    required this.data,
  });

  static Future<FavoriteItem> fromMessage(Message message) async {
    FavoriteItem item = FavoriteItem(
      favId: 0,
      messageUid: message.messageUid ?? 0,
      favType: message.content.meta.type,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      conversation: message.conversation,
      origin: '',
      sender: message.fromUser,
      title: '',
      url: '',
      thumbUrl: '',
      data: '',
    );

    if (message.conversation.conversationType == ConversationType.Group) {
      var groupInfo = await Imclient.getGroupInfo(message.conversation.target);
      if (groupInfo != null) {
        item.origin = (groupInfo.remark != null && groupInfo.remark!.isNotEmpty) ? groupInfo.remark! : (groupInfo.name ?? '');
      }
    } else if (message.conversation.conversationType == ConversationType.Single) {
      var userInfo = await Imclient.getUserInfo(message.fromUser);
      if (userInfo != null) {
        item.origin = userInfo.displayName ?? '';
      }
    } else if (message.conversation.conversationType == ConversationType.Channel) {
      var channelInfo = await Imclient.getChannelInfo(message.conversation.target);
      if (channelInfo != null) {
        item.origin = channelInfo.name ?? '';
      }
    }

    Map<String, dynamic> dataMap = {};
    MessageContent content = message.content;

    if (content is TextMessageContent) {
      item.title = content.text;
    } else if (content is ImageMessageContent) {
      item.url = content.remoteUrl ?? '';
      if (content.thumbnail != null) {
        Uint8List thumbBytes = img.encodePng(content.thumbnail!);
        String thumb = base64Encode(thumbBytes);
        dataMap['thumb'] = thumb;
        item.data = json.encode(dataMap);
      }
    } else if (content is VideoMessageContent) {
      item.url = content.remoteUrl ?? '';
      if (content.thumbnail != null) {
        Uint8List thumbBytes = img.encodePng(content.thumbnail!);
        String thumb = base64Encode(thumbBytes);
        dataMap['thumb'] = thumb;
        dataMap['duration'] = content.duration;
        item.data = json.encode(dataMap);
      }
    } else if (content is FileMessageContent) {
      item.url = content.remoteUrl ?? '';
      item.title = content.name;
      dataMap['size'] = content.size;
      item.data = json.encode(dataMap);
    } else if (content is CompositeMessageContent) {
      item.title = content.title;
      var payload = content.encode();
      if (content.remoteUrl != null && content.remoteUrl!.isNotEmpty) {
        try {
          if (payload.binaryContent != null) {
            String jsonStr = utf8.decode(payload.binaryContent!);
            Map<String, dynamic> obj = json.decode(jsonStr);
            obj['remote_url'] = content.remoteUrl;
            payload.binaryContent = Uint8List.fromList(utf8.encode(json.encode(obj)));
          }
        } catch (e) {
          print(e);
        }
      }
      if (payload.binaryContent != null) {
        item.data = base64Encode(payload.binaryContent!);
      }
    } else if (content is SoundMessageContent) {
      item.url = content.remoteUrl ?? '';
      dataMap['duration'] = content.duration;
      item.data = json.encode(dataMap);
    } else if (content is LinkMessageContent) {
      item.title = content.title;
      item.thumbUrl = content.thumbnailUrl ?? '';
      item.url = content.url;
    }

    return item;
  }

  factory FavoriteItem.fromJson(Map<String, dynamic> json) {
    return FavoriteItem(
      favId: json['id'] ?? 0,
      messageUid: int.tryParse(json['messageUid']?.toString() ?? '0') ?? 0,
      favType: json['type'] ?? 0,
      timestamp: json['timestamp'] ?? 0,
      conversation: Conversation(conversationType: ConversationType.values[json['convType'] ?? 0], target: json['convTarget'] ?? '', line: json['convLine'] ?? 0),
      origin: json['origin'] ?? '',
      sender: json['sender'] ?? '',
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      thumbUrl: json['thumbUrl'] ?? '',
      data: json['data'] ?? '',
    );
  }

  Message toMessage() {
    Message message = Message();
    message.messageUid = messageUid;
    message.conversation = conversation;
    message.fromUser = sender;
    message.serverTime = timestamp;

    switch (favType) {
      case MESSAGE_CONTENT_TYPE_TEXT:
        message.content = TextMessageContent(title);
        break;
      case MESSAGE_CONTENT_TYPE_IMAGE:
        ImageMessageContent content = ImageMessageContent();
        content.remoteUrl = url;
        if (data.isNotEmpty) {
          try {
            var map = json.decode(data);
            var thumb = map['thumb'];
            if (thumb != null) {
              content.thumbnail = img.decodeImage(base64Decode(thumb));
            }
          } catch (e) {}
        }
        message.content = content;
        break;
      case MESSAGE_CONTENT_TYPE_VIDEO:
        VideoMessageContent content = VideoMessageContent();
        content.remoteUrl = url;
        if (data.isNotEmpty) {
          try {
            var map = json.decode(data);
            var thumb = map['thumb'];
            if (thumb != null) {
              content.thumbnail = img.decodeImage(base64Decode(thumb));
            }
            content.duration = map['duration'] ?? 0;
          } catch (e) {}
        }
        message.content = content;
        break;
      case MESSAGE_CONTENT_TYPE_FILE:
        FileMessageContent content = FileMessageContent();
        content.remoteUrl = url;
        content.name = title;
        if (data.isNotEmpty) {
          try {
            var map = json.decode(data);
            content.size = map['size'] ?? 0;
          } catch (e) {}
        }
        message.content = content;
        break;
      case MESSAGE_CONTENT_TYPE_SOUND:
        SoundMessageContent content = SoundMessageContent();
        content.remoteUrl = url;
        if (data.isNotEmpty) {
          try {
            var map = json.decode(data);
            content.duration = map['duration'] ?? 0;
          } catch (e) {}
        }
        message.content = content;
        break;
      case MESSAGE_CONTENT_TYPE_COMPOSITE_MESSAGE:
        CompositeMessageContent content = CompositeMessageContent();
        content.title = title;
        if (data.isNotEmpty) {
          try {
            Uint8List payloadBytes = base64Decode(data);
            MessagePayload payload = MessagePayload();
            payload.content = title;
            payload.binaryContent = payloadBytes;

            String jsonStr = utf8.decode(payloadBytes);
            var obj = json.decode(jsonStr);
            payload.remoteMediaUrl = obj['remote_url'];

            content.decode(payload);
          } catch (e) {}
        }
        message.content = content;
        break;
      case MESSAGE_CONTENT_TYPE_LINK:
        LinkMessageContent content = LinkMessageContent();
        content.title = title;
        content.url = url;
        content.thumbnailUrl = thumbUrl;
        message.content = content;
        break;
      default:
        message.content = UnknownMessageContent();
        break;
    }
    return message;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': favId,
      'messageUid': messageUid,
      'type': favType,
      'timestamp': timestamp,
      'convType': conversation.conversationType.index,
      'convTarget': conversation.target,
      'convLine': conversation.line,
      'origin': origin,
      'sender': sender,
      'title': title,
      'url': url,
      'thumbUrl': thumbUrl,
      'data': data,
    };
  }
}
