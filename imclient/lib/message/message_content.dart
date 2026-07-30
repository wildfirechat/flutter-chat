/*
 * 说明：1000以下为系统保留类型，自定义消息请使用1000以上数值。
 * 系统消息类型中100以下为常用基本类型消息。100-199位群组消息类型。400-499为VoIP消息类型.
 */
//基本消息类型
//未知类型的消息
import 'package:imclient/message/unknown_message_content.dart';

import '../model/message_payload.dart';
import 'message.dart';

//自定义消息请使用1000以上的值，避免与系统预制的消息类型冲突

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
//富通知消息
const int MESSAGE_CONTENT_TYPE_RICH_NOTIFICATION = 12;
//文章消息
const int MESSAGE_CONTENT_TYPE_ARTICLES = 13;
//流式文本正在生成消息
const int MESSAGE_CONTENT_TYPE_STREAMING_TEXT_GENERATING = 14;
//流式文本消息
const int MESSAGE_CONTENT_TYPE_STREAMING_TEXT_GENERATED = 15;
//消息未能送达消息
const int MESSAGE_CONTENT_TYPE_NOT_DELIVERED = 16;
//投票消息
const int MESSAGE_CONTENT_TYPE_POLL = 18;
//投票结果消息
const int MESSAGE_CONTENT_TYPE_POLL_RESULT = 19;
//Ptt语音消息
const int MESSAGE_CONTENT_TYPE_PTT_VOICE = 23;
//会议纪要消息
const int MESSAGE_CONTENT_TYPE_MEETING_MINUTES = 25;
//转换/透传消息
const int MESSAGE_CONTENT_TYPE_TRANSCRIPTION = 26;
//同步标记未读
const int MESSAGE_CONTENT_TYPE_MARK_UNREAD_SYNC = 31;
//发起密聊
const int MESSAGE_CONTENT_TYPE_CREATE_SECRET_CHAT = 40;
//接收密聊
const int MESSAGE_CONTENT_TYPE_ACCEPT_SECRET_CHAT = 41;
//销毁密聊
const int MESSAGE_CONTENT_TYPE_DESTROY_SECRET_CHAT = 42;
//密聊消息
const int MESSAGE_CONTENT_TYPE_SECRET_CHAT_MESSAGE = 43;
//阅后即焚消息已读
const int MESSAGE_CONTENT_TYPE_BURN_MSG_READED = 46;
//阅后即焚消息已播放
const int MESSAGE_CONTENT_TYPE_BURN_MSG_PLAYED = 47;

//频道进出消息
const int MESSAGE_CONTENT_TYPE_ENTER_CHANNEL_CHAT = 71;
const int MESSAGE_CONTENT_TYPE_LEAVE_CHANNEL_CHAT = 72;
const int MESSAGE_CONTENT_TYPE_CHANNEL_MENU_EVENT = 73;

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
//踢出群成员的可见通知消息
const int MESSAGE_CONTENT_TYPE_KICKOF_GROUP_MEMBER_VISIBLE = 120;
//退群的可见通知消息
const int MESSAGE_CONTENT_TYPE_QUIT_GROUP_VISIBLE = 121;
//修改群组Extra通知消息
const int MESSAGE_CONTENT_TYPE_MODIFY_GROUP_EXTRA = 122;
//修改群组成员Extra通知消息
const int MESSAGE_CONTENT_TYPE_MODIFY_GROUP_MEMBER_EXTRA = 123;
//修改群组设置通知消息
const int MESSAGE_CONTENT_TYPE_MODIFY_GROUP_SETTINGS = 124;
//拒绝加入群组消息
const int MESSAGE_CONTENT_TYPE_REJECT_JOIN_GROUP = 125;

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
const int VOIP_CONTENT_CONFERENCE_CHANGE_MODE = 410;
const int VOIP_CONTENT_CONFERENCE_KICKOFF_MEMBER = 411;
const int VOIP_CONTENT_CONFERENCE_COMMAND = 412;
const int VOIP_CONTENT_MULTI_CALL_ONGOING = 416;
const int VOIP_CONTENT_JOIN_CALL_REQUEST = 417;
const int VOIP_CONTENT_PTT_INVITE = 420;

const int MESSAGE_CONTENT_TYPE_FEED = 501;
const int MESSAGE_CONTENT_TYPE_COMMENT = 502;

// 物联网消息类型
const int THINGS_CONTENT_TYPE_DATA = 601;
const int THINGS_CONTENT_TYPE_LOST_EVENT = 602;

// 备份相关消息类型
const int MESSAGE_CONTENT_TYPE_BACKUP_REQUEST = 613;
const int MESSAGE_CONTENT_TYPE_BACKUP_RESPONSE = 612;

// 恢复相关消息类型
const int MESSAGE_CONTENT_TYPE_RESTORE_REQUEST = 610;
const int MESSAGE_CONTENT_TYPE_RESTORE_RESPONSE = 611;

//自定义消息请使用1000以上的值，避免与系统预制的消息类型冲突

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

typedef MessageContentCreator = MessageContent Function();

class MessageContentMeta {
  const MessageContentMeta(this.type, this.flag, this.creator);

  final int type;
  final MessageFlag flag;
  final MessageContentCreator creator;
}

abstract class MessageContent {
  MessageContent({this.mentionedType = 0});

  ///0 普通消息；1 提醒mentionedTargets用户；2 提醒所有用户。
  int mentionedType;
  List<String>? mentionedTargets;
  String? extra;

  void decode(MessagePayload payload) {
    mentionedType = payload.mentionedType;
    mentionedTargets = payload.mentionedTargets;
    extra = payload.extra;
  }

  MessagePayload encode() {
    MessagePayload payload = MessagePayload();
    payload.mentionedType = mentionedType;
    payload.mentionedTargets = mentionedTargets;
    payload.extra = extra;
    payload.contentType = meta.type;
    payload.mediaType = MediaType.Media_Type_GENERAL;
    return payload;
  }

  Future<String> digest(Message message) async {
    return '未知消息';
  }

  MessageContentMeta get meta;
}
