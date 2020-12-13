import 'package:flutter_imclient/message/message.dart';
import 'package:flutter_imclient/model/message_payload.dart';

/*
 * 说明：1000以下为系统保留类型，自定义消息请使用1000以上数值。
 * 系统消息类型中100以下为常用基本类型消息。100-199位群组消息类型。400-499为VoIP消息类型.
 */
//基本消息类型
//未知类型的消息
const int MESSAGE_CONTENT_TYPE_UNKNOWN = 0;
//文本消息
const int MESSAGE_CONTENT_TYPE_TEXT = 1;
//语音消息
const int MESSAGE_CONTENT_TYPE_SOUND = 2;
//图片消息
const int MESSAGE_CONTENT_TYPE_IMAGE = 3;
//位置消息
const int MESSAGE_CONTENT_TYPE_LOCATION = 4;
//文件消息
const int MESSAGE_CONTENT_TYPE_FILE = 5;
//视频消息
const int MESSAGE_CONTENT_TYPE_VIDEO = 6;
//动态表情消息
const int MESSAGE_CONTENT_TYPE_STICKER = 7;
//链接消息
const int MESSAGE_CONTENT_TYPE_LINK = 8;
//存储不计数文本消息
const int MESSAGE_CONTENT_TYPE_P_TEXT = 9;
//名片消息
const int MESSAGE_CONTENT_TYPE_CARD = 10;
//组合消息
const int MESSAGE_CONTENT_TYPE_COMPOSITE_MESSAGE = 11;

//撤回消息
const int MESSAGE_CONTENT_TYPE_RECALL = 80;
//删除消息，请勿直接发送此消息，此消息是服务器端删除时的同步消息
const int MESSAGE_CONTENT_TYPE_DELETE = 81;

//提醒消息
const int MESSAGE_CONTENT_TYPE_TIP = 90;

//正在输入消息
const int MESSAGE_CONTENT_TYPE_TYPING = 91;

//以上是打招呼的内容
const int MESSAGE_FRIEND_GREETING = 92;
//您已经添加XXX为好友了，可以愉快地聊天了
const int MESSAGE_FRIEND_ADDED_NOTIFICATION = 93;

//PC 端请求登录
const int MESSAGE_PC_LOGIN_REQUSET = 94;

//通知消息类型
//创建群的通知消息
const int MESSAGE_CONTENT_TYPE_CREATE_GROUP = 104;
//加群的通知消息
const int MESSAGE_CONTENT_TYPE_ADD_GROUP_MEMBER = 105;
//踢出群成员的通知消息
const int MESSAGE_CONTENT_TYPE_KICKOF_GROUP_MEMBER = 106;
//退群的通知消息
const int MESSAGE_CONTENT_TYPE_QUIT_GROUP = 107;
//解散群的通知消息
const int MESSAGE_CONTENT_TYPE_DISMISS_GROUP = 108;
//转让群主的通知消息
const int MESSAGE_CONTENT_TYPE_TRANSFER_GROUP_OWNER = 109;
//修改群名称的通知消息
const int MESSAGE_CONTENT_TYPE_CHANGE_GROUP_NAME = 110;
//修改群昵称的通知消息
const int MESSAGE_CONTENT_TYPE_MODIFY_GROUP_ALIAS = 111;
//修改群头像的通知消息
const int MESSAGE_CONTENT_TYPE_CHANGE_GROUP_PORTRAIT = 112;
//修改群全局禁言的通知消息
const int MESSAGE_CONTENT_TYPE_CHANGE_MUTE = 113;
//修改群加入权限的通知消息
const int MESSAGE_CONTENT_TYPE_CHANGE_JOINTYPE = 114;
//修改群群成员私聊的通知消息
const int MESSAGE_CONTENT_TYPE_CHANGE_PRIVATECHAT = 115;
//修改群是否可搜索的通知消息
const int MESSAGE_CONTENT_TYPE_CHANGE_SEARCHABLE = 116;
//修改群管理的通知消息
const int MESSAGE_CONTENT_TYPE_SET_MANAGER = 117;
//禁言/取消禁言群成员的通知消息
const int MESSAGE_CONTENT_TYPE_MUTE_MEMBER = 118;
//允许/取消允许群成员发言的通知消息
const int MESSAGE_CONTENT_TYPE_ALLOW_MEMBER = 119;

//VoIP开始消息
const int VOIP_CONTENT_TYPE_START = 400;
//VoIP结束消息
const int VOIP_CONTENT_TYPE_END = 402;

const int VOIP_CONTENT_TYPE_ACCEPT = 401;
const int VOIP_CONTENT_TYPE_SIGNAL = 403;
const int VOIP_CONTENT_TYPE_MODIFY = 404;
const int VOIP_CONTENT_TYPE_ACCEPT_T = 405;
const int VOIP_CONTENT_TYPE_ADD_PARTICIPANT = 406;
const int VOIP_CONTENT_MUTE_VIDEO = 407;
const int VOIP_CONTENT_CONFERENCE_INVITE = 408;

const int THINGS_CONTENT_TYPE_DATA = 501;
const int THINGS_CONTENT_TYPE_LOST_EVENT = 502;

enum MessageFlag {
  //不存储，不计数
  NOT_PERSIST,
  //存储，不计数
  PERSIST,
  //保留类型，勿用
  RESERVE,
  //存储，计数
  PERSIST_AND_COUNT,
  //透传，客户端不在线会丢弃，不存储不计数
  TRANSPARENT
}

enum MediaType {
  Media_Type_GENERAL,
  Media_Type_IMAGE,
  Media_Type_VOICE,
  Media_Type_VIDEO,
  Media_Type_FILE,
  Media_Type_PORTRAIT,
  Media_Type_FAVORITE,
  Media_Type_STICKER,
  Media_Type_MOMENTS
}

typedef MessageContent MessageContentCreator();

class MessageContentMeta {
  const MessageContentMeta(this.type, this.flag, this.creator);

  final int type;
  final MessageFlag flag;
  final MessageContentCreator creator;
}

class MessageContent {
  ///0 普通消息；1 提醒mentionedTargets用户；2 提醒所有用户。
  int mentionedType;
  List<String> mentionedTargets;
  String extra;

  void decode(MessagePayload payload) {
    mentionedType = payload.mentionedType;
    mentionedTargets = payload.mentionedTargets;
    extra = payload.extra;
  }

  Future<MessagePayload> encode() async {
    MessagePayload payload = new MessagePayload();
    payload.mentionedType = mentionedType;
    payload.mentionedTargets = mentionedTargets;
    payload.extra = extra;
    if (meta != null) {
      payload.contentType = meta.type;
    }
    payload.mentionedType = 0;
    payload.mediaType = MediaType.Media_Type_GENERAL;
    return payload;
  }

   Future<String> digest(Message message) async {
    return '未知消息';
  }

  MessageContentMeta get meta => null;
}
