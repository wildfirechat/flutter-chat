import 'dart:async';
import 'dart:typed_data';

import 'package:event_bus/event_bus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_imclient/message/card_message_content.dart';
import 'package:flutter_imclient/message/composite_message_content.dart';
import 'package:flutter_imclient/message/file_message_content.dart';
import 'package:flutter_imclient/message/image_message_content.dart';
import 'package:flutter_imclient/message/link_message_content.dart';
import 'package:flutter_imclient/message/location_message_content.dart';
import 'package:flutter_imclient/message/message.dart';
import 'package:flutter_imclient/message/message_content.dart';
import 'package:flutter_imclient/message/notification/delete_message_content.dart';
import 'package:flutter_imclient/message/notification/friend_added_message_content.dart';
import 'package:flutter_imclient/message/notification/friend_greeting_message_content.dart';
import 'package:flutter_imclient/message/notification/group/add_group_member_notification_content.dart';
import 'package:flutter_imclient/message/notification/group/change_group_name_notification_content.dart';
import 'package:flutter_imclient/message/notification/group/change_group_portrait_notification_content.dart';
import 'package:flutter_imclient/message/notification/group/create_group_notification_content.dart';
import 'package:flutter_imclient/message/notification/group/dismiss_group_notification_content.dart';
import 'package:flutter_imclient/message/notification/group/group_join_type_notification_content.dart';
import 'package:flutter_imclient/message/notification/group/group_member_allow_notification_content.dart';
import 'package:flutter_imclient/message/notification/group/group_member_mute_notification_content.dart';
import 'package:flutter_imclient/message/notification/group/group_mute_notification_content.dart';
import 'package:flutter_imclient/message/notification/group/group_private_chat_notification_content.dart';
import 'package:flutter_imclient/message/notification/group/group_set_manager_notification_content.dart';
import 'package:flutter_imclient/message/notification/group/kickoff_group_member_notification_content.dart';
import 'package:flutter_imclient/message/notification/group/modify_group_member_alias_notification_content.dart';
import 'package:flutter_imclient/message/notification/group/quit_group_notification_content.dart';
import 'package:flutter_imclient/message/notification/group/transfer_group_owner_notification_content.dart';
import 'package:flutter_imclient/message/notification/recall_notificiation_content.dart';
import 'package:flutter_imclient/message/pclogin_request_message_content.dart';
import 'package:flutter_imclient/message/ptext_message_content.dart';
import 'package:flutter_imclient/message/sound_message_content.dart';
import 'package:flutter_imclient/message/sticker_message_content.dart';
import 'package:flutter_imclient/message/text_message_content.dart';
import 'package:flutter_imclient/message/typing_message_content.dart';
import 'package:flutter_imclient/message/unknown_message_content.dart';
import 'package:flutter_imclient/message/video_message_content.dart';
import 'package:flutter_imclient/model/channel_info.dart';
import 'package:flutter_imclient/model/chatroom_info.dart';
import 'package:flutter_imclient/model/chatroom_member_info.dart';
import 'package:flutter_imclient/model/conversation.dart';
import 'package:flutter_imclient/model/conversation_info.dart';
import 'package:flutter_imclient/model/conversation_search_info.dart';
import 'package:flutter_imclient/model/file_record.dart';
import 'package:flutter_imclient/model/friend_request.dart';
import 'package:flutter_imclient/model/group_info.dart';
import 'package:flutter_imclient/model/group_member.dart';
import 'package:flutter_imclient/model/group_search_info.dart';
import 'package:flutter_imclient/model/im_constant.dart';
import 'package:flutter_imclient/model/message_payload.dart';
import 'package:flutter_imclient/model/online_info.dart';
import 'package:flutter_imclient/model/read_report.dart';
import 'package:flutter_imclient/model/user_info.dart';

import 'message/notification/tip_notificiation_content.dart';
import 'model/unread_count.dart';

typedef void ConnectionStatusChangedCallback(int status);
typedef void ReceiveMessageCallback(List<Message> messages, bool hasMore);

typedef void SendMessageSuccessCallback(int messageUid, int timestamp);
typedef void SendMediaMessageProgressCallback(int uploaded, int total);
typedef void SendMediaMessageUploadedCallback(String remoteUrl);

typedef void RecallMessageCallback(int messageUid);
typedef void DeleteMessageCallback(int messageUid);

typedef void MessageDeliveriedCallback(Map<String, int> deliveryMap);
typedef void MessageReadedCallback(List<ReadReport> readReports);

typedef void GroupInfoUpdatedCallback(List<GroupInfo> groupInfos);
typedef void GroupMemberUpdatedCallback(
    String groupId, List<GroupMember> members);
typedef void UserInfoUpdatedCallback(List<UserInfo> userInfos);

typedef void FriendListUpdatedCallback(List<String> newFriends);
typedef void FriendRequestListUpdatedCallback(List<String> newRequests);

typedef void UserSettingsUpdatedCallback();

typedef void ChannelInfoUpdatedCallback(List<ChannelInfo> channelInfos);

typedef void OperationFailureCallback(int errorCode);
typedef void OperationSuccessVoidCallback();
typedef void OperationSuccessIntCallback(int i);
typedef void OperationSuccessIntPairCallback(int first, int second);
typedef void OperationSuccessStringCallback(String strValue);
typedef void OperationSuccessMessagesCallback(List<Message> messages);
typedef void OperationSuccessUserInfosCallback(List<UserInfo> userInfos);
typedef void OperationSuccessUserInfoCallback(UserInfo userInfo);
typedef void OperationSuccessGroupMembersCallback(List<GroupMember> members);
typedef void OperationSuccessGroupInfoCallback(GroupInfo groupInfo);
typedef void OperationSuccessChannelInfoCallback(ChannelInfo channelInfo);
typedef void OperationSuccessChannelInfosCallback(
    List<ChannelInfo> channelInfos);
typedef void OperationSuccessFilesCallback(List<FileRecord> files);
typedef void OperationSuccessChatroomInfoCallback(ChatroomInfo chatroomInfo);
typedef void OperationSuccessChatroomMemberInfoCallback(
    ChatroomMemberInfo memberInfo);

/// 密钥错误。一般是clientId不对，或者是连接的im跟请求token的im不是同一个环境，或者多端登录被踢出。
/// 出现此错误时需要退出到登录界面。
const int kConnectionStatusSecretKeyMismatch = -6;

/// token错误
/// 出现此错误时需要退出到登录界面。
const int kConnectionStatusTokenIncorrect = -5;

/// IM服务不可达
const int kConnectionStatusServerDown = -4;

/// 用户被封禁， 出现此错误时需要退出到登录界面。
const int kConnectionStatusRejected = -3;

/// 客户端退出登录
const int kConnectionStatusLogout = -2;

/// 未连接成功
const int kConnectionStatusUnconnected = -1;

/// 连接中
const int kConnectionStatusConnecting = 0;

/// 连接成功。连接成功是在同步成功之后。
const int kConnectionStatusConnected = 1;

/// 同步中。同步成功后会转入到连接成功状态。
const int kConnectionStatusReceiving = 2;

class ConnectionStatusChangedEvent {
  int connectionStatus;

  ConnectionStatusChangedEvent(this.connectionStatus);
}

class UserSettingUpdatedEvent {}

class ReceiveMessagesEvent {
  List<Message> messages;
  bool hasMore;

  ReceiveMessagesEvent(this.messages, this.hasMore);
}

class RecallMessageEvent {
  int messageUid;

  RecallMessageEvent(this.messageUid);
}

class DeleteMessageEvent {
  int messageUid;

  DeleteMessageEvent(this.messageUid);
}

class MessageDeliveriedEvent {
  Map<String, int> deliveryMap;

  MessageDeliveriedEvent(this.deliveryMap);
}

class MessageReadedEvent {
  List<ReadReport> readedReports;

  MessageReadedEvent(this.readedReports);
}

class GroupInfoUpdatedEvent {
  List<GroupInfo> groupInfos;

  GroupInfoUpdatedEvent(this.groupInfos);
}

class GroupMembersUpdatedEvent {
  String groupId;
  List<GroupMember> members;

  GroupMembersUpdatedEvent(this.groupId, this.members);
}

class UserInfoUpdatedEvent {
  List<UserInfo> userInfos;

  UserInfoUpdatedEvent(this.userInfos);
}

class FriendUpdateEvent {
  List<String> newUsers;

  FriendUpdateEvent(this.newUsers);
}

class FriendRequestUpdateEvent {
  List<String> newUserRequests;

  FriendRequestUpdateEvent(this.newUserRequests);
}

class ChannelInfoUpdateEvent {
  List<ChannelInfo> channelInfos;

  ChannelInfoUpdateEvent(this.channelInfos);
}

class ClearConversationUnreadEvent {
  Conversation conversation;

  ClearConversationUnreadEvent(this.conversation);
}

class ClearConversationsUnreadEvent {
  List<ConversationType> types;
  List<int> lines;

  ClearConversationsUnreadEvent(this.types, this.lines);
}

class ClearFriendRequestUnreadEvent {}

class FlutterImclient {
  static const MethodChannel _channel = const MethodChannel('flutter_imclient');
  static ConnectionStatusChangedCallback _connectionStatusChangedCallback;
  static ReceiveMessageCallback _receiveMessageCallback;
  static RecallMessageCallback _recallMessageCallback;
  static DeleteMessageCallback _deleteMessageCallback;
  static MessageDeliveriedCallback _messageDeliveriedCallback;
  static MessageReadedCallback _messageReadedCallback;
  static GroupInfoUpdatedCallback _groupInfoUpdatedCallback;
  static GroupMemberUpdatedCallback _groupMemberUpdatedCallback;
  static UserInfoUpdatedCallback _userInfoUpdatedCallback;
  static FriendListUpdatedCallback _friendListUpdatedCallback;
  static FriendRequestListUpdatedCallback _friendRequestListUpdatedCallback;
  static UserSettingsUpdatedCallback _userSettingsUpdatedCallback;
  static ChannelInfoUpdatedCallback _channelInfoUpdatedCallback;

  static EventBus _eventBus = EventBus();

  // ignore: non_constant_identifier_names
  static EventBus get IMEventBus => _eventBus;

  ///客户端ID，客户端的唯一标示。获取IM Token时必须带上正确的客户端ID，否则会无法连接成功。
  static Future<String> get clientId async {
    return await _channel.invokeMethod('getClientId');
  }

  ///客户端是否调用过connect
  static Future<bool> get isLogined async {
    return await _channel.invokeMethod('isLogined');
  }

  ///连接状态
  static Future<int> get connectionStatus async {
    return await _channel.invokeMethod('connectionStatus');
  }

  ///当前用户ID
  static Future<String> get currentUserId async {
    return await _channel.invokeMethod('currentUserId');
  }

  ///当前服务器与客户端时间的差值，单位是毫秒，只能是初略估计，不精确。
  static Future<int> get serverDeltaTime async {
    return await _channel.invokeMethod('serverDeltaTime');
  }

  ///开启协议栈日志
  static void startLog() async {
    _channel.invokeMethod('startLog');
  }

  ///结束协议栈日志
  static void stopLog() async {
    _channel.invokeMethod('stopLog');
  }

  ///获取协议栈日志文件路径
  static Future<List<String>> get logFilesPath async {
    return convertDynamicList(await _channel.invokeMethod('getLogFilesPath'));
  }

  static int _requestId = 0;
  static Map<int, SendMessageSuccessCallback> _sendMessageSuccessCallbackMap =
      {};
  static Map<int, OperationFailureCallback> _errorCallbackMap = {};
  static Map<int, SendMediaMessageProgressCallback>
      _sendMediaMessageProgressCallbackMap = {};
  static Map<int, SendMediaMessageUploadedCallback>
      _sendMediaMessageUploadedCallbackMap = {};

  static Map<int, dynamic> _operationSuccessCallbackMap = {};

  ///初始化SDK。必须在程序启动之后在所有操作之前初始化，之后才可以做其它操作。
  static void init(
      ConnectionStatusChangedCallback connectionStatusChangedCallback,
      ReceiveMessageCallback receiveMessageCallback,
      RecallMessageCallback recallMessageCallback,
      DeleteMessageCallback deleteMessageCallback,
      {MessageDeliveriedCallback messageDeliveriedCallback,
      MessageReadedCallback messageReadedCallback,
      GroupInfoUpdatedCallback groupInfoUpdatedCallback,
      GroupMemberUpdatedCallback groupMemberUpdatedCallback,
      UserInfoUpdatedCallback userInfoUpdatedCallback,
      FriendListUpdatedCallback friendListUpdatedCallback,
      FriendRequestListUpdatedCallback friendRequestListUpdatedCallback,
      UserSettingsUpdatedCallback userSettingsUpdatedCallback,
      ChannelInfoUpdatedCallback channelInfoUpdatedCallback}) async {
    _connectionStatusChangedCallback = connectionStatusChangedCallback;
    _receiveMessageCallback = receiveMessageCallback;
    _recallMessageCallback = recallMessageCallback;
    _deleteMessageCallback = deleteMessageCallback;
    _messageDeliveriedCallback = messageDeliveriedCallback;
    _messageReadedCallback = messageReadedCallback;
    _groupInfoUpdatedCallback = groupInfoUpdatedCallback;
    _groupMemberUpdatedCallback = groupMemberUpdatedCallback;
    _userInfoUpdatedCallback = userInfoUpdatedCallback;
    _friendListUpdatedCallback = friendListUpdatedCallback;
    _friendRequestListUpdatedCallback = friendRequestListUpdatedCallback;
    _userSettingsUpdatedCallback = userSettingsUpdatedCallback;
    _channelInfoUpdatedCallback = channelInfoUpdatedCallback;

    registeMessageContent(addGroupMemberNotificationContentMeta);
    registeMessageContent(changeGroupNameNotificationContentMeta);
    registeMessageContent(changeGroupPortraitNotificationContentMeta);
    registeMessageContent(createGroupNotificationContentMeta);
    registeMessageContent(dismissGroupNotificationContentMeta);
    registeMessageContent(groupJoinTypeNotificationContentMeta);
    registeMessageContent(groupMemberAllowNotificationContentMeta);
    registeMessageContent(groupMemberMuteNotificationContentMeta);
    registeMessageContent(groupMuteNotificationContentMeta);
    registeMessageContent(groupPrivateChatNotificationContentMeta);
    registeMessageContent(groupSetManagerNotificationContentMeta);
    registeMessageContent(kickoffGroupMemberNotificationContentMeta);
    registeMessageContent(modifyGroupMemberAliasNotificationContentMeta);
    registeMessageContent(quitGroupNotificationContentMeta);
    registeMessageContent(transferGroupOwnerNotificationContentMeta);

    registeMessageContent(recallNotificationContentMeta);
    registeMessageContent(tipNotificationContentMeta);

    registeMessageContent(cardContentMeta);
    registeMessageContent(compositeContentMeta);
    registeMessageContent(deleteMessageContentMeta);
    registeMessageContent(fileContentMeta);
    registeMessageContent(friendAddedContentMeta);
    registeMessageContent(friendGreetingContentMeta);
    registeMessageContent(imageContentMeta);
    registeMessageContent(linkContentMeta);
    registeMessageContent(locationMessageContentMeta);
    registeMessageContent(pcLoginContentMeta);
    registeMessageContent(ptextContentMeta);
    registeMessageContent(soundContentMeta);
    registeMessageContent(stickerContentMeta);
    registeMessageContent(textContentMeta);
    registeMessageContent(typingContentMeta);
    registeMessageContent(videoContentMeta);

    _channel.setMethodCallHandler((MethodCall call) {
      switch (call.method) {
        case 'onConnectionStatusChanged':
          int status = call.arguments;
          if (_connectionStatusChangedCallback != null) {
            _connectionStatusChangedCallback(status);
          }
          _eventBus.fire(ConnectionStatusChangedEvent(status));
          break;
        case 'onReceiveMessage':
          Map<dynamic, dynamic> args = call.arguments;
          bool hasMore = args['hasMore'];
          List<dynamic> list = args['messages'];
          _convertProtoMessages(list).then((value) {
            if (_receiveMessageCallback != null) {
              _receiveMessageCallback(value, hasMore);
            }
            _eventBus.fire(ReceiveMessagesEvent(value, hasMore));
          });
          break;
        case 'onRecallMessage':
          Map<dynamic, dynamic> args = call.arguments;
          int messageUid = args['messageUid'];
          if (_recallMessageCallback != null) {
            _recallMessageCallback(messageUid);
          }
          _eventBus.fire(RecallMessageEvent(messageUid));
          break;
        case 'onDeleteMessage':
          Map<dynamic, dynamic> args = call.arguments;
          int messageUid = args['messageUid'];
          if (_deleteMessageCallback != null) {
            _deleteMessageCallback(messageUid);
          }
          _eventBus.fire(DeleteMessageEvent(messageUid));
          break;
        case 'onMessageDelivered':
          Map<dynamic, dynamic> args = call.arguments;
          Map<String, int> data = new Map();
          args.forEach((key, value) {
            data[key] = value;
          });
          if (_messageDeliveriedCallback != null) {
            _messageDeliveriedCallback(data);
          }
          _eventBus.fire(MessageDeliveriedEvent(data));
          break;
        case 'onMessageReaded':
          Map<dynamic, dynamic> args = call.arguments;
          List<dynamic> reads = args['readeds'];
          List<ReadReport> reports = new List();
          reads.forEach((element) {
            reports.add(_convertProtoReadEntry(element));
          });
          if (_messageReadedCallback != null) {
            _messageReadedCallback(reports);
          }
          _eventBus.fire(MessageReadedEvent(reports));
          break;
        case 'onConferenceEvent':
          break;
        case 'onGroupInfoUpdated':
          Map<dynamic, dynamic> args = call.arguments;
          List<dynamic> groups = args['groups'];
          List<GroupInfo> data = new List();
          groups.forEach((element) {
            data.add(_convertProtoGroupInfo(element));
          });
          if (_groupInfoUpdatedCallback != null) {
            _groupInfoUpdatedCallback(data);
          }
          _eventBus.fire(GroupInfoUpdatedEvent(data));
          break;
        case 'onGroupMemberUpdated':
          Map<dynamic, dynamic> args = call.arguments;
          String groupId = args['groupId'];
          List<dynamic> members = args['members'];
          List<GroupMember> data = new List();
          members.forEach((element) {
            data.add(_convertProtoGroupMember(element));
          });
          if (_groupMemberUpdatedCallback != null) {
            _groupMemberUpdatedCallback(groupId, data);
          }
          _eventBus.fire(GroupMembersUpdatedEvent(groupId, data));
          break;
        case 'onUserInfoUpdated':
          Map<dynamic, dynamic> args = call.arguments;
          List<dynamic> users = args['users'];
          List<UserInfo> data = new List();
          users.forEach((element) {
            data.add(_convertProtoUserInfo(element));
          });
          if (_userInfoUpdatedCallback != null) {
            _userInfoUpdatedCallback(data);
          }
          _eventBus.fire(UserInfoUpdatedEvent(data));

          break;
        case 'onFriendListUpdated':
          Map<dynamic, dynamic> args = call.arguments;
          List<dynamic> friendIdList = args['friends'];
          List<String> friends = List(0);
          friendIdList.forEach((element) => friends.add(element));
          if (_friendListUpdatedCallback != null) {
            _friendListUpdatedCallback(friends);
          }
          _eventBus.fire(FriendUpdateEvent(friends));
          break;
        case 'onFriendRequestUpdated':
          Map<dynamic, dynamic> args = call.arguments;
          final friendRequestList = (args['requests'] as List).cast<String>();
          if (_friendRequestListUpdatedCallback != null) {
            _friendRequestListUpdatedCallback(friendRequestList);
          }
          _eventBus.fire(FriendRequestUpdateEvent(friendRequestList));
          break;
        case 'onSettingUpdated':
          if (_userSettingsUpdatedCallback != null) {
            _userSettingsUpdatedCallback();
          }
          _eventBus.fire(UserSettingUpdatedEvent());
          break;
        case 'onChannelInfoUpdated':
          Map<dynamic, dynamic> args = call.arguments;
          List<dynamic> channels = args['channels'];
          List<ChannelInfo> data = new List();
          channels.forEach((element) {
            data.add(_convertProtoChannelInfo(element));
          });
          if (_channelInfoUpdatedCallback != null) {
            _channelInfoUpdatedCallback(data);
          }
          _eventBus.fire(ChannelInfoUpdateEvent(data));
          break;
        case 'onSendMessageSuccess':
          Map<dynamic, dynamic> args = call.arguments;
          int requestId = args['requestId'];
          int messageUid = args['messageUid'];
          int timestamp = args['timestamp'];
          var callback = _sendMessageSuccessCallbackMap[requestId];
          if (callback != null) {
            callback(messageUid, timestamp);
          }
          _removeSendMessageCallback(requestId);
          break;
        case 'onSendMediaMessageProgress':
          Map<dynamic, dynamic> args = call.arguments;
          int requestId = args['requestId'];
          int uploaded = args['uploaded'];
          int total = args['total'];
          var callback = _sendMediaMessageProgressCallbackMap[requestId];
          if (callback != null) {
            callback(uploaded, total);
          }
          break;
        case 'onSendMediaMessageUploaded':
          Map<dynamic, dynamic> args = call.arguments;
          int requestId = args['requestId'];
          String remoteUrl = args['remoteUrl'];
          var callback = _sendMediaMessageUploadedCallbackMap[requestId];
          if (callback != null) {
            callback(remoteUrl);
          }
          break;
        case 'onOperationVoidSuccess':
          Map<dynamic, dynamic> args = call.arguments;
          int requestId = args['requestId'];
          var callback = _operationSuccessCallbackMap[requestId];
          if (callback != null) {
            callback();
          }
          _removeOperationCallback(requestId);
          break;

        case 'onMessagesCallback':
          Map<dynamic, dynamic> args = call.arguments;
          int requestId = args['requestId'];
          List<dynamic> datas = args['messages'];
          var callback = _operationSuccessCallbackMap[requestId];
          if (callback != null) {
            callback(_convertProtoMessages(datas));
          }
          _removeOperationCallback(requestId);
          break;
        case 'onSearchUserResult':
          Map<dynamic, dynamic> args = call.arguments;
          int requestId = args['requestId'];
          List<dynamic> datas = args['users'];
          var callback = _operationSuccessCallbackMap[requestId];
          if (callback != null) {
            callback(_convertProtoUserInfos(datas));
          }
          _removeOperationCallback(requestId);
          break;
        case 'getUserInfoAsyncCallback':
          Map<dynamic, dynamic> args = call.arguments;
          int requestId = args['requestId'];
          Map<dynamic, dynamic> data = args['user'];
          var callback = _operationSuccessCallbackMap[requestId];
          if (callback != null) {
            callback(_convertProtoUserInfo(data));
          }
          _removeOperationCallback(requestId);
          break;
        case 'getGroupMembersAsyncCallback':
          Map<dynamic, dynamic> args = call.arguments;
          int requestId = args['requestId'];
          List<dynamic> datas = args['members'];
          var callback = _operationSuccessCallbackMap[requestId];
          if (callback != null) {
            callback(_convertProtoGroupMembers(datas));
          }
          _removeOperationCallback(requestId);
          break;
        case 'getGroupInfoAsyncCallback':
          Map<dynamic, dynamic> args = call.arguments;
          int requestId = args['requestId'];
          Map<dynamic, dynamic> data = args['groupInfo'];
          var callback = _operationSuccessCallbackMap[requestId];
          if (callback != null) {
            callback(_convertProtoGroupInfo(data));
          }
          _removeOperationCallback(requestId);
          break;
        case 'onOperationStringSuccess':
          Map<dynamic, dynamic> args = call.arguments;
          int requestId = args['requestId'];
          String strValue = args['string'];
          var callback = _operationSuccessCallbackMap[requestId];
          if (callback != null) {
            callback(strValue);
          }
          _removeOperationCallback(requestId);
          break;
        case 'onFilesResult':
          Map<dynamic, dynamic> args = call.arguments;
          int requestId = args['requestId'];
          List<dynamic> datas = args['files'];
          var callback = _operationSuccessCallbackMap[requestId];
          if (callback != null) {
            callback(_convertProtoFileRecords(datas));
          }
          _removeOperationCallback(requestId);
          break;
        case 'onSearchChannelResult':
          Map<dynamic, dynamic> args = call.arguments;
          int requestId = args['requestId'];
          List<dynamic> datas = args['channelInfos'];
          var callback = _operationSuccessCallbackMap[requestId];
          if (callback != null) {
            callback(_convertProtoChannelInfos(datas));
          }
          _removeOperationCallback(requestId);
          break;
        case 'onCreateChannelSuccess':
          Map<dynamic, dynamic> args = call.arguments;
          int requestId = args['requestId'];
          Map<dynamic, dynamic> data = args['channelInfo'];
          var callback = _operationSuccessCallbackMap[requestId];
          if (callback != null) {
            callback(_convertProtoChannelInfo(data));
          }
          _removeOperationCallback(requestId);
          break;
        case 'onOperationIntPairSuccess':
          Map<dynamic, dynamic> args = call.arguments;
          int requestId = args['requestId'];
          int first = args['first'];
          int second = args['second'];
          var callback = _operationSuccessCallbackMap[requestId];
          if (callback != null) {
            callback(first, second);
          }
          _removeOperationCallback(requestId);
          break;
        case 'onGetChatroomInfoResult':
          Map<dynamic, dynamic> args = call.arguments;
          int requestId = args['requestId'];
          Map<dynamic, dynamic> data = args['chatroomInfo'];
          var callback = _operationSuccessCallbackMap[requestId];
          if (callback != null) {
            callback(_convertProtoChatroomInfo(data));
          }
          _removeOperationCallback(requestId);
          break;
        case 'onGetChatroomMemberInfoResult':
          Map<dynamic, dynamic> args = call.arguments;
          int requestId = args['requestId'];
          Map<dynamic, dynamic> data = args['chatroomMemberInfo'];
          var callback = _operationSuccessCallbackMap[requestId];
          if (callback != null) {
            callback(_convertProtoChatroomMemberInfo(data));
          }
          _removeOperationCallback(requestId);
          break;
        case 'onOperationFailure':
          Map<dynamic, dynamic> args = call.arguments;
          int requestId = args['requestId'];
          int errorCode = args['errorCode'];
          var callback = _errorCallbackMap[requestId];
          if (callback != null) {
            callback(errorCode);
          }
          _removeAllOperationCallback(requestId);
          break;
      }

      return Future(null);
    });
  }

  static void _removeSendMessageCallback(int requestId) {
    _sendMessageSuccessCallbackMap.remove(requestId);
    _errorCallbackMap.remove(requestId);
    _sendMediaMessageProgressCallbackMap.remove(requestId);
    _sendMediaMessageUploadedCallbackMap.remove(requestId);
  }

  static void _removeAllOperationCallback(int requestId) {
    _sendMessageSuccessCallbackMap.remove(requestId);
    _errorCallbackMap.remove(requestId);
    _sendMediaMessageProgressCallbackMap.remove(requestId);
    _sendMediaMessageUploadedCallbackMap.remove(requestId);
    _operationSuccessCallbackMap.remove(requestId);
  }

  static void _removeOperationCallback(int requestId) {
    _errorCallbackMap.remove(requestId);
    _operationSuccessCallbackMap.remove(requestId);
  }

  ///注册消息，所有的预制消息和自定义消息都必须先注册才可以使用。
  static void registeMessageContent(MessageContentMeta contentMeta) {
    _contentMetaMap.putIfAbsent(contentMeta.type, () => contentMeta);
    Map<String, dynamic> map = new Map();
    map["type"] = contentMeta.type;
    map["flag"] = contentMeta.flag.index;
    _channel.invokeMethod('registeMessage', map);
  }

  static Future<Message> _convertProtoMessage(Map<dynamic, dynamic> map) async {
    if (map == null) {
      return null;
    }

    Message msg = new Message();
    msg.messageId = map['messageId'];
    msg.messageUid = map['messageUid'];
    msg.conversation = _convertProtoConversation(map['conversation']);
    msg.fromUser = map['fromUser'];
    msg.toUsers = (map['toUsers'] as List)?.cast<String>();
    msg.content =
        decodeMessageContent(_convertProtoMessageContent(map['content']));
    msg.direction = MessageDirection.values[map['direction']];
    msg.status = MessageStatus.values[map['status']];
    msg.serverTime = map['timestamp'];
    return msg;
  }

  static Future<List<Message>> _convertProtoMessages(
      List<dynamic> datas) async {
    if (datas.isEmpty) {
      return new List();
    }
    List<Message> messages = new List();
    for (int i = 0; i < datas.length; ++i) {
      var element = datas[i];
      Message msg = await _convertProtoMessage(element);
      messages.add(msg);
    }
    return messages;
  }

  static Conversation _convertProtoConversation(Map<dynamic, dynamic> map) {
    Conversation conversation = new Conversation();
    conversation.conversationType = ConversationType.values[map['type']];
    conversation.target = map['target'];
    if (map['line'] == null) {
      conversation.line = 0;
    } else {
      conversation.line = map['line'];
    }

    return conversation;
  }

  static Future<List<ConversationInfo>> _convertProtoConversationInfos(
      List<dynamic> maps) async {
    if (maps == null || maps.isEmpty) {
      return new List();
    }
    List<ConversationInfo> infos = new List();
    for (int i = 0; i < maps.length; ++i) {
      var element = maps[i];
      infos.add(await _convertProtoConversationInfo(element));
    }

    return infos;
  }

  static Future<ConversationInfo> _convertProtoConversationInfo(
      Map<dynamic, dynamic> map) async {
    ConversationInfo conversationInfo = new ConversationInfo();
    conversationInfo.conversation =
        _convertProtoConversation(map['conversation']);
    conversationInfo.lastMessage =
        await _convertProtoMessage(map['lastMessage']);
    conversationInfo.draft = map['draft'];
    if (map['timestamp'] != null) conversationInfo.timestamp = map['timestamp'];
    if (map['isTop'] != null) conversationInfo.isTop = map['isTop'];
    if (map['isSilent'] != null) conversationInfo.isSilent = map['isSilent'];
    conversationInfo.unreadCount = _convertProtoUnreadCount(map['unreadCount']);

    return conversationInfo;
  }

  static Future<List<ConversationSearchInfo>>
      _convertProtoConversationSearchInfos(List<dynamic> maps) async {
    if (maps.isEmpty) {
      return new List();
    }

    List<ConversationSearchInfo> infos = new List();
    for (int i = 0; i < maps.length; i++) {
      var element = maps[i];
      infos.add(await _convertProtoConversationSearchInfo(element));
    }

    return infos;
  }

  static Future<ConversationSearchInfo> _convertProtoConversationSearchInfo(
      Map<dynamic, dynamic> map) async {
    ConversationSearchInfo conversationInfo = new ConversationSearchInfo();
    conversationInfo.conversation =
        _convertProtoConversation(map['conversation']);
    conversationInfo.marchedMessage =
        await _convertProtoMessage(map['marchedMessage']);
    if (map['marchedCount'] != null) {
      conversationInfo.marchedCount = map['marchedCount'];
    }
    conversationInfo.timestamp = map['timestamp'];
    return conversationInfo;
  }

  static FriendRequest _convertProtoFriendRequest(Map<dynamic, dynamic> data) {
    FriendRequest friendRequest = new FriendRequest();
    friendRequest.target = data['target'];
    friendRequest.direction = FriendRequestDirection.values[data['direction']];
    friendRequest.reason = data['reason'];
    friendRequest.status = FriendRequestStatus.values[data['status']];
    friendRequest.readStatus =
        FriendRequestReadStatus.values[data['readStatus']];
    friendRequest.timestamp = data['timestamp'];
    return friendRequest;
  }

  static List<FriendRequest> _convertProtoFriendRequests(List<dynamic> datas) {
    if (datas.isEmpty) {
      return new List();
    }

    List<FriendRequest> list = new List();
    datas.forEach((element) {
      list.add(_convertProtoFriendRequest(element));
    });
    return list;
  }

  static List<GroupSearchInfo> _convertProtoGroupSearchInfos(
      List<dynamic> maps) {
    if (maps.isEmpty) {
      return new List();
    }

    List<GroupSearchInfo> infos = new List();
    maps.forEach((element) {
      infos.add(_convertProtoGroupSearchInfo(element));
    });

    return infos;
  }

  static GroupSearchInfo _convertProtoGroupSearchInfo(
      Map<dynamic, dynamic> map) {
    GroupSearchInfo groupSearchInfo = new GroupSearchInfo();
    groupSearchInfo.groupInfo = _convertProtoGroupInfo(map['groupInfo']);
    groupSearchInfo.marchType = GroupSearchResultType.values[map['marchType']];
    groupSearchInfo.marchedMemberNames = map['marchedMemberNames'];

    return groupSearchInfo;
  }

  static UnreadCount _convertProtoUnreadCount(Map<dynamic, dynamic> map) {
    if (map == null) {
      return null;
    }
    UnreadCount unreadCount = new UnreadCount();
    if (map['unread'] != null) unreadCount.unread = map['unread'];
    if (map['unreadMention'] != null)
      unreadCount.unreadMention = map['unreadMention'];
    if (map['unreadMentionAll'] != null)
      unreadCount.unreadMentionAll = map['unreadMentionAll'];
    return unreadCount;
  }

  static MessagePayload _convertProtoMessageContent(Map<dynamic, dynamic> map) {
    MessagePayload payload = new MessagePayload();
    payload.contentType = map['type'];
    payload.searchableContent = map['searchableContent'];
    payload.pushContent = map['pushContent'];
    payload.pushData = map['pushData'];
    payload.content = map['content'];
    payload.binaryContent = map['binaryContent'];
    payload.localContent = map['localContent'];
    if (map['mentionedType'] != null)
      payload.mentionedType = map['mentionedType'];
    payload.mentionedTargets = convertDynamicList(map['mentionedTargets']);

    if (map['mediaType'] != null) {
      payload.mediaType = MediaType.values[map['mediaType']];
    }
    payload.remoteMediaUrl = map['remoteMediaUrl'];
    payload.localMediaPath = map['localMediaPath'];

    payload.extra = map['extra'];
    return payload;
  }

  static Map<String, dynamic> _convertConversation(Conversation conversation) {
    Map<String, dynamic> map = new Map();

    map['type'] = conversation.conversationType.index;
    map['target'] = conversation.target;
    map['line'] = conversation.line;
    return map;
  }

  static Future<Map<String, dynamic>> _convertMessageContent(
      MessageContent content) async {
    if (content == null) return null;

    Map<String, dynamic> map = new Map();
    MessagePayload payload = await content.encode();
    map['type'] = payload.contentType;
    if (payload.searchableContent != null)
      map['searchableContent'] = payload.searchableContent;
    if (payload.pushContent != null) map['pushContent'] = payload.pushContent;
    if (payload.pushData != null) map['pushData'] = payload.pushData;
    if (payload.content != null) map['content'] = payload.content;
    if (payload.binaryContent != null)
      map['binaryContent'] = payload.binaryContent;
    if (payload.localContent != null)
      map['localContent'] = payload.localContent;
    if (payload.mentionedType != null)
      map['mentionedType'] = payload.mentionedType;
    if (payload.mentionedTargets != null)
      map['mentionedTargets'] = payload.mentionedTargets;
    map['mediaType'] = payload.mediaType.index;
    if (payload.remoteMediaUrl != null)
      map['remoteMediaUrl'] = payload.remoteMediaUrl;
    if (payload.localMediaPath != null)
      map['localMediaPath'] = payload.localMediaPath;
    if (payload.extra != null) map['extra'] = payload.extra;
    return map;
  }

  static ReadReport _convertProtoReadEntry(Map<dynamic, dynamic> map) {
    ReadReport report = new ReadReport();
    report.conversation = _convertProtoConversation(map['conversation']);
    report.userId = map['userId'];
    report.readDt = map['readDt'];
    return report;
  }

  static GroupInfo _convertProtoGroupInfo(Map<dynamic, dynamic> map) {
    if (map == null) return null;

    GroupInfo groupInfo = new GroupInfo();
    groupInfo.type = GroupType.values[map['type']];
    groupInfo.target = map['target'];
    groupInfo.name = map['name'];
    groupInfo.extra = map['extra'];
    groupInfo.portrait = map['portrait'];
    groupInfo.owner = map['owner'];
    if (map['memberCount'] != null) groupInfo.memberCount = map['memberCount'];
    if (map['mute'] != null) groupInfo.mute = map['mute'];

    if (map['joinType'] != null) groupInfo.joinType = map['joinType'];
    if (map['privateChat'] != null) groupInfo.privateChat = map['privateChat'];
    if (map['searchable'] != null) groupInfo.searchable = map['searchable'];
    if (map['historyMessage'] != null)
      groupInfo.historyMessage = map['historyMessage'];
    if (map['updateDt'] != null) groupInfo.updateDt = map['updateDt'];
    return groupInfo;
  }

  static GroupMember _convertProtoGroupMember(Map<dynamic, dynamic> map) {
    GroupMember groupMember = new GroupMember();
    if (map['type'] != null)
      groupMember.type = GroupMemberType.values[map['type']];
    else
      groupMember.type = GroupMemberType.Normal;

    groupMember.groupId = map['groupId'];
    groupMember.memberId = map['memberId'];
    groupMember.alias = map['alias'];

    if (map['updateDt'] != null) groupMember.updateDt = map['updateDt'];
    if (map['createDt'] != null) groupMember.createDt = map['createDt'];

    return groupMember;
  }

  static List<GroupMember> _convertProtoGroupMembers(List<dynamic> datas) {
    if (datas.isEmpty) {
      return new List();
    }
    List<GroupMember> list = new List();
    datas.forEach((element) {
      list.add(_convertProtoGroupMember(element));
    });
    return list;
  }

  static UserInfo _convertProtoUserInfo(Map<dynamic, dynamic> map) {
    if (map == null) {
      return null;
    }
    UserInfo userInfo = new UserInfo();
    userInfo.userId = map['userId'];
    userInfo.name = map['name'];
    userInfo.displayName = map['displayName'];
    if (map['gender'] != null) userInfo.gender = map['gender'];
    userInfo.portrait = map['portrait'];
    userInfo.mobile = map['mobile'];
    userInfo.email = map['email'];
    userInfo.address = map['address'];
    userInfo.company = map['company'];
    userInfo.social = map['social'];
    userInfo.extra = map['extra'];
    userInfo.friendAlias = map['friendAlias'];
    userInfo.groupAlias = map['groupAlias'];
    if (map['updateDt'] != null) userInfo.updateDt = map['updateDt'];
    if (map['type'] != null) userInfo.type = map['type'];
    if (map['deleted'] != null) userInfo.deleted = map['deleted'];
    return userInfo;
  }

  static List<UserInfo> _convertProtoUserInfos(List<dynamic> datas) {
    if (datas == null || datas.isEmpty) {
      return new List();
    }
    List<UserInfo> list = new List();
    datas.forEach((element) {
      list.add(_convertProtoUserInfo(element));
    });
    return list;
  }

  static ChannelInfo _convertProtoChannelInfo(Map<dynamic, dynamic> map) {
    ChannelInfo channelInfo = new ChannelInfo();
    channelInfo.channelId = map['channelId'];
    channelInfo.desc = map['desc'];
    channelInfo.extra = map['extra'];
    channelInfo.name = map['name'];
    channelInfo.portrait = map['portrait'];
    channelInfo.owner = map['owner'];
    channelInfo.secret = map['secret'];
    channelInfo.callback = map['callback'];
    if (map['status'] != null)
      channelInfo.status = ChannelStatus.values[map['status']];
    if (map['updateDt'] != null) channelInfo.updateDt = map['updateDt'];

    return channelInfo;
  }

  static List<ChannelInfo> _convertProtoChannelInfos(List<dynamic> datas) {
    if (datas.isEmpty) {
      return new List();
    }
    List<ChannelInfo> list = new List();
    datas.forEach((element) {
      list.add(_convertProtoChannelInfo(element));
    });
    return list;
  }

  static ChatroomInfo _convertProtoChatroomInfo(Map<dynamic, dynamic> map) {
    ChatroomInfo chatroomInfo = new ChatroomInfo();
    chatroomInfo.chatroomId = map['chatroomId'];
    chatroomInfo.desc = map['desc'];
    chatroomInfo.extra = map['extra'];
    chatroomInfo.portrait = map['portrait'];
    chatroomInfo.title = map['title'];
    if (map['status'] != null)
      chatroomInfo.state = ChatroomState.values[map['state']];
    if (map['memberCount'] != null)
      chatroomInfo.memberCount = map['memberCount'];
    if (map['createDt'] != null) chatroomInfo.createDt = map['createDt'];
    if (map['updateDt'] != null) chatroomInfo.updateDt = map['updateDt'];

    return chatroomInfo;
  }

  static FileRecord _convertProtoFileRecord(Map<dynamic, dynamic> map) {
    FileRecord record = new FileRecord();
    Map<dynamic, dynamic> conversation = map['conversation'];
    record.conversation = _convertProtoConversation(conversation);
    record.userId = map['userId'];
    record.messageUid = map['messageUid'];
    record.name = map['name'];
    record.url = map['url'];
    record.size = map['size'];
    record.downloadCount = map['downloadCount'];
    record.timestamp = map['timestamp'];
    return record;
  }

  static List<FileRecord> _convertProtoFileRecords(List<dynamic> datas) {
    if (datas.isEmpty) {
      return new List();
    }
    List<FileRecord> list = new List();
    datas.forEach((element) {
      list.add(_convertProtoFileRecord(element));
    });
    return list;
  }

  static ChatroomMemberInfo _convertProtoChatroomMemberInfo(
      Map<dynamic, dynamic> map) {
    ChatroomMemberInfo chatroomInfo = new ChatroomMemberInfo();
    chatroomInfo.members = map['members'];
    if (map['memberCount'] != null)
      chatroomInfo.memberCount = map['memberCount'];

    return chatroomInfo;
  }

  static OnlineInfo _convertProtoOnlineInfo(Map<dynamic, dynamic> data) {
    OnlineInfo info = new OnlineInfo();
    info.type = data['type'];
    info.isOnline = data['isOnline'];
    info.platform = data['platform'];
    info.clientId = data['clientId'];
    info.clientName = data['clientName'];
    info.timestamp = data['timestamp'];
    return info;
  }

  static List<OnlineInfo> _convertProtoOnlineInfos(List<dynamic> datas) {
    if (datas.isEmpty) {
      return new List();
    }
    List<OnlineInfo> list = new List();
    datas.forEach((element) {
      list.add(_convertProtoOnlineInfo(element));
    });
    return list;
  }

  static List<int> _convertMessageStatusList(List<MessageStatus> status) {
    if (status.isEmpty) {
      return new List();
    }
    List<int> list = new List();
    status.forEach((element) {
      list.add(element.index);
    });
    return list;
  }

  static List<String> convertDynamicList(List<dynamic> datas) {
    if (datas == null || datas.isEmpty) {
      return new List();
    }
    List<String> list = new List();
    datas.forEach((element) {
      list.add(element);
    });
    return list;
  }

  static MessageContent decodeMessageContent(MessagePayload payload) {
    MessageContentMeta meta = _contentMetaMap[payload.contentType];
    MessageContent content;
    if (meta == null) {
      content = new UnknownMessageContent();
    } else {
      content = meta.creator();
    }
    content.decode(payload);
    return content;
  }

  static Map<int, MessageContentMeta> _contentMetaMap = {};

  /// 连接IM服务。调用连接之后才可以调用获取数据接口。连接状态会通过连接状态回调返回。
  /// [host]为IM服务域名或IP，必须im.example.com或114.144.114.144，不带http头和端口。
  static Future<bool> connect(String host, String userId, String token) async {
    Map<String, dynamic> args = <String, dynamic>{};
    args.putIfAbsent('host', () => host);
    args.putIfAbsent('userId', () => userId);
    args.putIfAbsent('token', () => token);
    final bool newDb = await _channel.invokeMethod('connect', args);
    return newDb;
  }

  ///断开IM服务连接。
  /// * disablePush 是否继续接受推送。
  /// * clearSession 是否清除session
  static Future<void> disconnect(
      {bool disablePush = false, bool clearSession = false}) async {
    Map<String, dynamic> args = <String, dynamic>{};
    args.putIfAbsent('disablePush', () => disablePush);
    args.putIfAbsent('clearSession', () => clearSession);
    await _channel.invokeMethod('disconnect', args);
  }

  ///获取会话列表
  static Future<List<ConversationInfo>> getConversationInfos(
      List<ConversationType> types, List<int> lines) async {
    List<int> itypes = new List();
    types.forEach((element) {
      itypes.add(element.index);
    });
    if (lines == null || lines.isEmpty) {
      lines = [0];
    }

    List<dynamic> datas = await _channel.invokeMethod(
        'getConversationInfos', {'types': itypes, 'lines': lines});
    List<ConversationInfo> infos = await _convertProtoConversationInfos(datas);
    return infos;
  }

  ///获取会话信息
  static Future<ConversationInfo> getConversationInfo(
      Conversation conversation) async {
    var args = _convertConversation(conversation);
    Map<dynamic, dynamic> datas =
        await _channel.invokeMethod("getConversationInfo", args);
    ConversationInfo info = await _convertProtoConversationInfo(datas);
    return info;
  }

  ///搜索会话信息
  static Future<List<ConversationSearchInfo>> searchConversation(
      String keyword, List<ConversationType> types, List<int> lines) async {
    List<int> itypes = new List();
    types.forEach((element) {
      itypes.add(element.index);
    });
    if (lines == null || lines.isEmpty) {
      lines = [0];
    }

    List<dynamic> datas = await _channel.invokeMethod('searchConversation',
        {'keyword': keyword, 'types': itypes, 'lines': lines});
    List<ConversationSearchInfo> infos =
        await _convertProtoConversationSearchInfos(datas);
    return infos;
  }

  ///移除会话
  static Future<void> removeConversation(
      Conversation conversation, bool clearMessage) async {
    Map<String, dynamic> args = new Map();
    args['conversation'] = _convertConversation(conversation);
    args['clearMessage'] = clearMessage;
    await _channel.invokeMethod("removeConversation", args);
    return;
  }

  ///设置/取消会话置顶
  static Future<void> setConversationTop(
      Conversation conversation,
      bool isTop,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null) {
      _operationSuccessCallbackMap.putIfAbsent(
          requestId, () => successCallback);
    }
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;

    await _channel.invokeMethod("setConversationTop", {
      "requestId": requestId,
      'conversation': _convertConversation(conversation),
      "isTop": isTop
    });
  }

  ///设置/取消会话免到扰
  static Future<void> setConversationSilent(
      Conversation conversation,
      bool isSilent,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null) {
      _operationSuccessCallbackMap.putIfAbsent(
          requestId, () => successCallback);
    }
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;

    await _channel.invokeMethod("setConversationSilent", {
      "requestId": requestId,
      'conversation': _convertConversation(conversation),
      "isSilent": isSilent
    });
  }

  ///保存草稿
  static Future<void> setConversationDraft(
      Conversation conversation, String draft) async {
    Map<String, dynamic> args = new Map();
    args['conversation'] = _convertConversation(conversation);
    args['draft'] = draft;
    await _channel.invokeMethod("setConversationDraft", args);
  }

  ///设置会话时间戳
  static Future<void> setConversationTimestamp(
      Conversation conversation, int timestamp) async {
    Map<String, dynamic> args = new Map();
    args['conversation'] = _convertConversation(conversation);
    args['timestamp'] = timestamp;
    await _channel.invokeMethod("setConversationTimestamp", args);
  }

  ///设置会话中第一个未读消息ID
  static Future<int> getFirstUnreadMessageId(Conversation conversation) async {
    int msgId = await _channel.invokeMethod("getFirstUnreadMessageId",
        {"conversation": _convertConversation(conversation)});
    return msgId;
  }

  ///设置会话未读状态
  static Future<UnreadCount> getConversationUnreadCount(
      Conversation conversation) async {
    Map<dynamic, dynamic> datas = await _channel.invokeMethod(
        'getConversationUnreadCount',
        {'conversation': _convertConversation(conversation)});
    return _convertProtoUnreadCount(datas);
  }

  ///设置某些类型会话未读状态
  static Future<UnreadCount> getConversationsUnreadCount(
      List<ConversationType> types, List<int> lines) async {
    List<int> itypes = new List();
    types.forEach((element) {
      itypes.add(element.index);
    });
    if (lines == null || lines.isEmpty) {
      lines = [0];
    }

    Map<dynamic, dynamic> datas = await _channel.invokeMethod(
        'getConversationsUnreadCount', {'types': itypes, 'lines': lines});
    return _convertProtoUnreadCount(datas);
  }

  ///清除一个会话的未读状态
  static Future<bool> clearConversationUnreadStatus(
      Conversation conversation) async {
    bool ret = await _channel.invokeMethod('clearConversationUnreadStatus',
        {'conversation': _convertConversation(conversation)});
    if (ret) {
      _eventBus.fire(ClearConversationUnreadEvent(conversation));
    }
    return ret;
  }

  ///清除某些类型会话的未读状态
  static Future<bool> clearConversationsUnreadStatus(
      List<ConversationType> types, List<int> lines) async {
    List<int> itypes = new List();
    types.forEach((element) {
      itypes.add(element.index);
    });
    if (lines == null || lines.isEmpty) {
      lines = [0];
    }

    bool ret = await _channel.invokeMethod(
        'clearConversationsUnreadStatus', {'types': itypes, 'lines': lines});
    if (ret) {
      _eventBus.fire(ClearConversationsUnreadEvent(types, lines));
    }
    return ret;
  }

  ///获取会话的已读状态
  static Future<Map<String, int>> getConversationRead(
      Conversation conversation) async {
    Map<dynamic, dynamic> datas = await _channel.invokeMethod(
        'getConversationRead',
        {'conversation': _convertConversation(conversation)});
    Map<String, int> map = new Map();
    datas.forEach((key, value) {
      map.putIfAbsent(key, () => value);
    });
    return map;
  }

  ///获取会话的消息送达状态
  static Future<Map<String, int>> getMessageDelivery(
      Conversation conversation) async {
    Map<dynamic, dynamic> datas = await _channel.invokeMethod(
        'getMessageDelivery',
        {'conversation': _convertConversation(conversation)});
    Map<String, int> map = new Map();
    datas.forEach((key, value) {
      map.putIfAbsent(key, () => value);
    });
    return map;
  }

  ///获取会话的消息列表
  static Future<List<Message>> getMessages(
      Conversation conversation, int fromIndex, int count,
      {List<int> contentTypes, String withUser}) async {
    Map<String, dynamic> args = {
      "conversation": _convertConversation(conversation),
      "fromIndex": fromIndex.toString(),
      "count": count
    };
    if (contentTypes != null) {
      args["contentTypes"] = contentTypes;
    }
    if (withUser != null) {
      args["withUser"] = withUser;
    }

    List<dynamic> datas = await _channel.invokeMethod("getMessages", args);
    return _convertProtoMessages(datas);
  }

  ///根据消息状态获取会话的消息列表
  static Future<List<Message>> getMessagesByStatus(Conversation conversation,
      int fromIndex, int count, List<MessageStatus> messageStatus,
      {String withUser}) async {
    Map<String, dynamic> args = {
      "conversation": _convertConversation(conversation),
      "fromIndex": fromIndex.toString(),
      "count": count,
      "messageStatus": _convertMessageStatusList(messageStatus)
    };

    if (withUser != null) {
      args["withUser"] = withUser;
    }

    List<dynamic> datas =
        await _channel.invokeMethod("getMessagesByStatus", args);
    return _convertProtoMessages(datas);
  }

  ///获取某些类型会话的消息列表
  static Future<List<Message>> getConversationsMessages(
      List<ConversationType> types, List<int> lines, int fromIndex, int count,
      {List<int> contentTypes, String withUser}) async {
    List<int> itypes = new List();
    types.forEach((element) {
      itypes.add(element.index);
    });
    if (lines == null || lines.isEmpty) {
      lines = [0];
    }

    Map<String, dynamic> args = {
      "types": itypes,
      "lines": lines,
      "fromIndex": fromIndex.toString(),
      "count": count
    };
    if (contentTypes != null) {
      args["contentTypes"] = contentTypes;
    }
    if (withUser != null) {
      args["withUser"] = withUser;
    }

    List<dynamic> datas =
        await _channel.invokeMethod("getConversationsMessages", args);
    return _convertProtoMessages(datas);
  }

  ///根据消息状态获取某些类型会话的消息列表
  static Future<List<Message>> getConversationsMessageByStatus(
      List<ConversationType> types,
      List<int> lines,
      int fromIndex,
      int count,
      List<MessageStatus> messageStatus,
      {String withUser}) async {
    List<int> itypes = new List();
    types.forEach((element) {
      itypes.add(element.index);
    });
    if (lines == null || lines.isEmpty) {
      lines = [0];
    }

    Map<String, dynamic> args = {
      "types": itypes,
      "lines": lines,
      "fromIndex": fromIndex.toString(),
      "count": count,
      "messageStatus": _convertMessageStatusList(messageStatus)
    };

    if (withUser != null) {
      args["withUser"] = withUser;
    }

    List<dynamic> datas =
        await _channel.invokeMethod("getConversationsMessageByStatus", args);
    return _convertProtoMessages(datas);
  }

  ///获取远端历史消息
  static Future<void> getRemoteMessages(
      Conversation conversation,
      int beforeMessageUid,
      int count,
      OperationSuccessMessagesCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;

    await _channel.invokeMethod("getRemoteMessages", {
      "requestId": requestId,
      "conversation": _convertConversation(conversation),
      "beforeMessageUid": beforeMessageUid.toString(),
      "count": count
    });
  }

  ///根据消息Id获取消息
  static Future<Message> getMessage(int messageId) async {
    Map<dynamic, dynamic> datas = await _channel
        .invokeMethod("getMessage", {"messageId": messageId.toString()});
    return _convertProtoMessage(datas);
  }

  ///根据消息Uid获取消息
  static Future<Message> getMessageByUid(int messageUid) async {
    Map<dynamic, dynamic> datas = await _channel
        .invokeMethod("getMessageByUid", {"messageUid": messageUid.toString()});
    return _convertProtoMessage(datas);
  }

  ///搜索某个会话内消息
  static Future<List<Message>> searchMessages(Conversation conversation,
      String keyword, bool order, int limit, int offset) async {
    List<dynamic> datas = await _channel.invokeMethod("searchMessages", {
      "conversation": _convertConversation(conversation),
      "keyword": keyword,
      "order": order,
      "limit": limit,
      "offset": offset
    });
    return _convertProtoMessages(datas);
  }

  ///搜索某些类会话内消息
  static Future<List<Message>> searchConversationsMessages(
    List<ConversationType> types,
    List<int> lines,
    String keyword,
    int fromIndex,
    int count, {
    List<int> contentTypes,
  }) async {
    List<int> itypes = new List();
    types.forEach((element) {
      itypes.add(element.index);
    });
    if (lines == null || lines.isEmpty) {
      lines = [0];
    }

    var args = {
      "types": itypes,
      "lines": lines,
      "keyword": keyword,
      "fromIndex": fromIndex.toString(),
      "count": count
    };
    if (contentTypes != null) {
      args['contentTypes'] = contentTypes;
    }

    List<dynamic> datas =
        await _channel.invokeMethod("searchConversationsMessages", args);
    return _convertProtoMessages(datas);
  }

  ///发送消息
  static Future<Message> sendMessage(
      Conversation conversation, MessageContent content,
      {List<String> toUsers,
      int expireDuration = 0,
      SendMessageSuccessCallback successCallback,
      OperationFailureCallback errorCallback}) async {
    return sendMediaMessage(conversation, content,
        toUsers: toUsers,
        expireDuration: expireDuration,
        successCallback: successCallback,
        errorCallback: errorCallback);
  }

  ///发送媒体类型消息
  static Future<Message> sendMediaMessage(
      Conversation conversation, MessageContent content,
      {List<String> toUsers,
      int expireDuration,
      SendMessageSuccessCallback successCallback,
      OperationFailureCallback errorCallback,
      SendMediaMessageProgressCallback progressCallback,
      SendMediaMessageUploadedCallback uploadedCallback}) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _sendMessageSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    if (progressCallback != null)
      _sendMediaMessageProgressCallbackMap[requestId] = progressCallback;
    if (uploadedCallback != null)
      _sendMediaMessageUploadedCallbackMap[requestId] = uploadedCallback;

    Map<String, dynamic> convMap = _convertConversation(conversation);
    Map<String, dynamic> contMap = await _convertMessageContent(content);
    Map<String, dynamic> args = {
      "requestId": requestId,
      "conversation": convMap,
      "content": contMap
    };

    if (expireDuration > 0) args['expireDuration'] = expireDuration;
    if (toUsers != null && toUsers.isNotEmpty) args['toUsers'] = toUsers;

    Map<dynamic, dynamic> fm = await _channel.invokeMethod('sendMessage', args);

    return _convertProtoMessage(fm);
  }

  ///发送已保存消息
  static Future<bool> sendSavedMessage(int messageId,
      {int expireDuration,
      SendMessageSuccessCallback successCallback,
      OperationFailureCallback errorCallback}) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _sendMessageSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;

    return await _channel.invokeMethod("sendSavedMessage", {
      "requestId": requestId,
      "messageId": messageId.toString(),
      "expireDuration": expireDuration
    });
  }

  ///撤回消息
  static Future<void> recallMessage(
      int messageUid,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod('recallMessage',
        {"requestId": requestId, "messageUid": messageUid.toString()});
  }

  ///上传媒体数据
  static Future<void> uploadMedia(
      String fileName,
      Uint8List mediaData,
      int mediaType,
      OperationSuccessStringCallback successCallback,
      SendMediaMessageProgressCallback progressCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    if (progressCallback != null)
      _sendMediaMessageProgressCallbackMap[requestId] = progressCallback;
    await _channel.invokeMethod("uploadMedia", {
      "requestId": requestId,
      "fileName": fileName,
      "mediaData": mediaData,
      "mediaType": mediaType
    });
  }

  ///删除消息
  static Future<bool> deleteMessage(int messageId) async {
    return await _channel
        .invokeMethod("deleteMessage", {"messageId": messageId.toString()});
  }

  ///清空会话内消息
  static Future<bool> clearMessages(Conversation conversation,
      {int before = 0}) async {
    return await _channel.invokeMethod("clearMessages", {
      "conversation": _convertConversation(conversation),
      "before": before.toString()
    });
  }

  ///设置消息已经播放
  static Future<void> setMediaMessagePlayed(int messageId) async {
    await _channel.invokeMethod(
        "setMediaMessagePlayed", {"messageId": messageId.toString()});
  }

  ///插入消息
  static Future<Message> insertMessage(Conversation conversation, String sender,
      MessageContent content, int status, int serverTime) async {
    Map<dynamic, dynamic> datas = await _channel.invokeMethod("insertMessage", {
      "conversation": _convertConversation(conversation),
      "content": await _convertMessageContent(content),
      "status": status,
      "serverTime": serverTime.toString()
    });
    return _convertProtoMessage(datas);
  }

  ///更新消息内容
  static Future<void> updateMessage(
      int messageId, MessageContent content) async {
    await _channel.invokeMethod("updateMessage", {
      "messageId": messageId.toString(),
      "content": await _convertMessageContent(content)
    });
  }

  ///更新消息状态
  static Future<void> updateMessageStatus(
      int messageId, MessageStatus status) async {
    await _channel.invokeMethod("updateMessageStatus",
        {"messageId": messageId.toString(), "status": status.index});
  }

  ///获取会话内消息数量
  static Future<int> getMessageCount(Conversation conversation) async {
    return await _channel.invokeMethod("getMessageCount",
        {'conversation': _convertConversation(conversation)});
  }

  ///获取用户信息
  static Future<UserInfo> getUserInfo(String userId,
      {String groupId, bool refresh = false}) async {
    var args = {"userId": userId, "refresh": refresh};
    if (groupId != null) {
      args['groupId'] = groupId;
    }

    Map<dynamic, dynamic> datas =
        await _channel.invokeMethod("getUserInfo", args);
    return _convertProtoUserInfo(datas);
  }

  ///批量获取用户信息
  static Future<List<UserInfo>> getUserInfos(List<String> userIds,
      {String groupId}) async {
    var args;
    if (groupId != null) {
      args = {"userIds": userIds, "groupId": groupId};
    } else {
      args = {"userIds": userIds};
    }
    List<dynamic> datas = await _channel.invokeMethod("getUserInfos", args);
    return _convertProtoUserInfos(datas);
  }

  ///搜索用户
  static Future<void> searchUser(
      String keyword,
      int searchType,
      int page,
      OperationSuccessUserInfosCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;

    List<dynamic> datas = await _channel.invokeMethod("searchUser", {
      "requestId": requestId,
      "keyword": keyword,
      "searchType": searchType,
      "page": page
    });
    return _convertProtoUserInfos(datas);
  }

  ///异步获取用户信息
  static Future<void> getUserInfoAsync(
      String userId,
      OperationSuccessUserInfoCallback successCallback,
      OperationFailureCallback errorCallback,
      {bool refresh = false}) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod(
        "getUserInfoAsync", {"requestId": requestId, "userId": userId});
  }

  ///是否是好友
  static Future<bool> isMyFriend(String userId) async {
    return await _channel.invokeMethod("isMyFriend", {"userId": userId});
  }

  ///获取好友列表
  static Future<List<String>> getMyFriendList({bool refresh = false}) async {
    List<dynamic> datas =
        await _channel.invokeMethod("getMyFriendList", {"refresh": refresh});
    return convertDynamicList(datas);
  }

  ///搜索好友
  static Future<List<UserInfo>> searchFriends(String keyword) async {
    List<dynamic> datas =
        await _channel.invokeMethod("searchFriends", {"keyword": keyword});
    return _convertProtoUserInfos(datas);
  }

  ///搜索群组
  static Future<List<GroupSearchInfo>> searchGroups(String keyword) async {
    List<dynamic> datas =
        await _channel.invokeMethod("searchGroups", {"keyword": keyword});
    return _convertProtoGroupSearchInfos(datas);
  }

  ///获取收到的好友请求列表
  static Future<List<FriendRequest>> getIncommingFriendRequest() async {
    List<dynamic> datas =
        await _channel.invokeMethod("getIncommingFriendRequest");
    return _convertProtoFriendRequests(datas);
  }

  ///获取发出去的好友请求列表
  static Future<List<FriendRequest>> getOutgoingFriendRequest() async {
    List<dynamic> datas =
        await _channel.invokeMethod("getOutgoingFriendRequest");
    return _convertProtoFriendRequests(datas);
  }

  ///获取某个用户相关的好友请求
  static Future<FriendRequest> getFriendRequest(
      String userId, FriendRequestDirection direction) async {
    Map<dynamic, dynamic> data = await _channel.invokeMethod(
        "getFriendRequest", {"userId": userId, "direction": direction.index});
    return _convertProtoFriendRequest(data);
  }

  ///同步远程好友请求信息
  static Future<void> loadFriendRequestFromRemote() async {
    await _channel.invokeMethod("loadFriendRequestFromRemote");
  }

  ///获取未读好友请求数
  static Future<int> getUnreadFriendRequestStatus() async {
    return await _channel.invokeMethod("getUnreadFriendRequestStatus");
  }

  ///清除未读好友请求计数
  static Future<bool> clearUnreadFriendRequestStatus() async {
    bool ret = await _channel.invokeMethod("clearUnreadFriendRequestStatus");
    if (ret) {
      _eventBus.fire(ClearFriendRequestUnreadEvent());
    }
    return ret;
  }

  ///删除好友
  static Future<void> deleteFriend(
      String userId,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod(
        "deleteFriend", {"requestId": requestId, "userId": userId});
  }

  ///发送好友请求
  static Future<void> sendFriendRequest(
      String userId,
      String reason,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("sendFriendRequest",
        {"requestId": requestId, "userId": userId, "reason": reason});
  }

  ///处理好友请求
  static Future<void> handleFriendRequest(
      String userId,
      bool accept,
      String extra,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("handleFriendRequest", {
      "requestId": requestId,
      "userId": userId,
      "accept": accept,
      "extra": extra
    });
  }

  ///获取好友备注名
  static Future<String> getFriendAlias(String userId) async {
    String data =
        await _channel.invokeMethod("getFriendAlias", {"userId": userId});
    return data;
  }

  ///设置好友备注名
  static Future<void> setFriendAlias(
      String friendId,
      String alias,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("setFriendAlias",
        {"requestId": requestId, "friendId": friendId, "alias": alias});
  }

  ///获取好友extra信息
  static Future<String> getFriendExtra(String userId) async {
    String data =
        await _channel.invokeMethod("getFriendExtra", {"userId": userId});
    return data;
  }

  ///是否是黑名单用户
  static Future<bool> isBlackListed(String userId) async {
    bool data =
        await _channel.invokeMethod("isBlackListed", {"userId": userId});
    return data;
  }

  ///获取黑名单列表
  static Future<List<String>> getBlackList({bool refresh = false}) async {
    List<dynamic> datas =
        await _channel.invokeMethod("getBlackList", {"refresh": refresh});
    return convertDynamicList(datas);
  }

  ///设置/取消用户黑名单
  static Future<void> setBlackList(
      String userId,
      bool isBlackListed,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("setBlackList", {
      "requestId": requestId,
      "userId": userId,
      "isBlackListed": isBlackListed
    });
  }

  ///获取群成员列表
  static Future<List<GroupMember>> getGroupMembers(String groupId,
      {bool refresh = false}) async {
    List<dynamic> datas = await _channel.invokeMethod(
        "getGroupMembers", {"groupId": groupId, "refresh": refresh});
    return _convertProtoGroupMembers(datas);
  }

  ///根据群成员类型获取群成员列表
  static Future<List<GroupMember>> getGroupMembersByTypes(
      String groupId, GroupMemberType memberType) async {
    List<dynamic> datas = await _channel.invokeMethod("getGroupMembersByTypes",
        {"groupId": groupId, "memberType": memberType.index});
    return _convertProtoGroupMembers(datas);
  }

  ///异步获取群成员列表
  static Future<void> getGroupMembersAsync(String groupId,
      {bool refresh = false,
      OperationSuccessGroupMembersCallback successCallback,
      OperationFailureCallback errorCallback}) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("getGroupMembersAsync",
        {"requestId": requestId, "groupId": groupId, "refresh": refresh});
  }

  ///获取群信息
  static Future<GroupInfo> getGroupInfo(String groupId,
      {bool refresh = false}) async {
    Map<dynamic, dynamic> datas = await _channel
        .invokeMethod("getGroupInfo", {"groupId": groupId, "refresh": refresh});
    return _convertProtoGroupInfo(datas);
  }

  ///异步获取群信息
  static Future<void> getGroupInfoAsync(String groupId,
      {bool refresh = false,
      OperationSuccessGroupInfoCallback successCallback,
      OperationFailureCallback errorCallback}) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("getGroupInfoAsync",
        {"requestId": requestId, "groupId": groupId, "refresh": refresh});
  }

  ///获取单个群成员信息
  static Future<GroupMember> getGroupMember(
      String groupId, String memberId) async {
    Map<dynamic, dynamic> datas = await _channel.invokeMethod(
        "getGroupMember", {"groupId": groupId, "memberId": memberId});
    return _convertProtoGroupMember(datas);
  }

  ///创建群组，groupId可以为空。
  static Future<void> createGroup(
      String groupId,
      String groupName,
      String groupPortrait,
      int type,
      List<String> members,
      OperationSuccessStringCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int> notifyLines = const [],
      MessageContent notifyContent}) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;

    Map<String, dynamic> args = new Map();
    args['requestId'] = requestId;
    if (groupId != null) {
      args['groupId'] = groupId;
    }
    if (groupName != null) {
      args['groupName'] = groupName;
    }
    if (groupPortrait != null) {
      args['groupPortrait'] = groupPortrait;
    }
    args['type'] = type;
    args['groupMembers'] = members;
    if (notifyLines != null) {
      args['notifyLines'] = notifyLines;
    }
    if (notifyContent != null) {
      args['notifyContent'] = await _convertMessageContent(notifyContent);
    }

    await _channel.invokeMethod("createGroup", args);
  }

  ///添加群成员
  static Future<void> addGroupMembers(
      String groupId,
      List<String> members,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int> notifyLines = const [],
      MessageContent notifyContent}) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("addGroupMembers", {
      "requestId": requestId,
      "groupId": groupId,
      "groupMembers": members,
      "notifyLines": notifyLines,
      "notifyContent": await _convertMessageContent(notifyContent)
    });
  }

  ///移除群成员
  static Future<void> kickoffGroupMembers(
      String groupId,
      List<String> members,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int> notifyLines = const [],
      MessageContent notifyContent}) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("kickoffGroupMembers", {
      "requestId": requestId,
      "groupId": groupId,
      "groupMembers": members,
      "notifyLines": notifyLines,
      "notifyContent": await _convertMessageContent(notifyContent)
    });
  }

  ///退出群组
  static Future<void> quitGroup(
      String groupId,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int> notifyLines = const [],
      MessageContent notifyContent}) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("quitGroup", {
      "requestId": requestId,
      "groupId": groupId,
      "notifyLines": notifyLines,
      "notifyContent": await _convertMessageContent(notifyContent)
    });
  }

  ///解散群组
  static Future<void> dismissGroup(
      String groupId,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int> notifyLines = const [],
      MessageContent notifyContent}) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("dismissGroup", {
      "requestId": requestId,
      "groupId": groupId,
      "notifyLines": notifyLines,
      "notifyContent": await _convertMessageContent(notifyContent)
    });
  }

  ///修改群组信息
  static Future<void> modifyGroupInfo(
      String groupId,
      ModifyGroupInfoType modifyType,
      String newValue,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int> notifyLines = const [],
      MessageContent notifyContent}) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("modifyGroupInfo", {
      "requestId": requestId,
      "groupId": groupId,
      "modifyType": modifyType.index,
      "value": newValue,
      "notifyLines": notifyLines,
      "notifyContent": await _convertMessageContent(notifyContent)
    });
  }

  ///修改自己的群名片
  static Future<void> modifyGroupAlias(
      String groupId,
      String newAlias,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int> notifyLines = const [],
      MessageContent notifyContent}) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("modifyGroupAlias", {
      "requestId": requestId,
      "groupId": groupId,
      "newAlias": newAlias,
      "notifyLines": notifyLines,
      "notifyContent": await _convertMessageContent(notifyContent)
    });
  }

  ///修改群成员的群名片
  static Future<void> modifyGroupMemberAlias(
      String groupId,
      String memberId,
      String newAlias,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int> notifyLines = const [],
      MessageContent notifyContent}) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("modifyGroupMemberAlias", {
      "requestId": requestId,
      "groupId": groupId,
      "newAlias": newAlias,
      "notifyLines": notifyLines,
      "notifyContent": await _convertMessageContent(notifyContent)
    });
  }

  ///转移群组
  static Future<void> transferGroup(
      String groupId,
      String newOwner,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int> notifyLines = const [],
      MessageContent notifyContent}) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("transferGroup", {
      "requestId": requestId,
      "groupId": groupId,
      "newOwner": newOwner,
      "notifyLines": notifyLines,
      "notifyContent": await _convertMessageContent(notifyContent)
    });
  }

  ///设置/取消群管理员
  static Future<void> setGroupManager(
      String groupId,
      bool isSet,
      List<String> memberIds,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int> notifyLines = const [],
      MessageContent notifyContent}) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("setGroupManager", {
      "requestId": requestId,
      "groupId": groupId,
      "isSet": isSet,
      "memberIds": memberIds,
      "notifyLines": notifyLines,
      "notifyContent": await _convertMessageContent(notifyContent)
    });
  }

  ///禁言/取消禁言群成员
  static Future<void> muteGroupMember(
      String groupId,
      bool isSet,
      List<String> memberIds,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int> notifyLines = const [],
      MessageContent notifyContent}) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("muteGroupMember", {
      "requestId": requestId,
      "groupId": groupId,
      "isSet": isSet,
      "memberIds": memberIds,
      "notifyLines": notifyLines,
      "notifyContent": await _convertMessageContent(notifyContent)
    });
  }

  ///设置/取消群白名单
  static Future<void> allowGroupMember(
      String groupId,
      bool isSet,
      List<String> memberIds,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int> notifyLines = const [],
      MessageContent notifyContent}) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("allowGroupMember", {
      "requestId": requestId,
      "groupId": groupId,
      "isSet": isSet,
      "memberIds": memberIds,
      "notifyLines": notifyLines,
      "notifyContent": await _convertMessageContent(notifyContent)
    });
  }

  ///获取收藏群组列表
  static Future<List<String>> getFavGroups() async {
    return convertDynamicList(await _channel.invokeMethod("getFavGroups"));
  }

  ///是否收藏群组
  static Future<bool> isFavGroup(String groupId) async {
    return await _channel.invokeMethod("isFavGroup", {"groupId": groupId});
  }

  ///设置/取消收藏群组
  static Future<void> setFavGroup(
      String groupId,
      bool isFav,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("setFavGroup",
        {"requestId": requestId, "groupId": groupId, "isFav": isFav});
  }

  ///获取用户设置
  static Future<String> getUserSetting(int scope, String value) async {
    return await _channel
        .invokeMethod("getUserSetting", {"scope": scope, "value": value});
  }

  ///获取某类用户设置
  static Future<Map<String, String>> getUserSettings(int scope) async {
    return await _channel.invokeMethod("getUserSettings", {"scope": scope});
  }

  ///设置用户设置
  static Future<void> setUserSetting(
      int scope,
      String key,
      String value,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("setUserSetting",
        {"requestId": requestId, "scope": scope, "key": key, "value": value});
  }

  ///修改当前用户信息
  static Future<void> modifyMyInfo(
      Map<ModifyMyInfoType, String> values,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;

    Map<int, String> v = new Map();
    values.forEach((key, value) {
      v.putIfAbsent(key.index, () => value);
    });

    await _channel
        .invokeMethod("modifyMyInfo", {"requestId": requestId, "values": v});
  }

  ///是否全局静音
  static Future<bool> isGlobalSlient() async {
    return await _channel.invokeMethod("isGlobalSlient");
  }

  ///设置/取消全局静音
  static Future<void> setGlobalSlient(
      bool isSilent,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod(
        "setGlobalSlient", {"requestId": requestId, "isSilent": isSilent});
  }

  ///获取免打扰时间段
  static Future<void> getNoDisturbingTimes(
      OperationSuccessIntPairCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel
        .invokeMethod("getNoDisturbingTimes", {"requestId": requestId});
  }

  ///设置免打扰时间段
  static Future<void> setNoDisturbingTimes(
      int startMins,
      int endMins,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("setNoDisturbingTimes",
        {"requestId": requestId, "startMins": startMins, "endMins": endMins});
  }

  ///取消免打扰时间段
  static Future<void> clearNoDisturbingTimes(
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel
        .invokeMethod("clearNoDisturbingTimes", {"requestId": requestId});
  }

  ///是否推送隐藏详情
  static Future<bool> isHiddenNotificationDetail() async {
    return await _channel.invokeMethod("isHiddenNotificationDetail");
  }

  ///设置推送隐藏详情
  static Future<void> setHiddenNotificationDetail(
      bool isHidden,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("setHiddenNotificationDetail",
        {"requestId": requestId, "isHidden": isHidden});
  }

  ///是否群组隐藏用户名
  static Future<bool> isHiddenGroupMemberName(String groupId) async {
    return await _channel
        .invokeMethod("isHiddenGroupMemberName", {"groupId": groupId});
  }

  ///设置是否群组隐藏用户名
  static Future<void> setHiddenGroupMemberName(
      bool isHidden,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("setHiddenGroupMemberName",
        {"requestId": requestId, "isHidden": isHidden});
  }

  ///当前用户是否启用回执功能
  static Future<bool> isUserEnableReceipt() async {
    return await _channel.invokeMethod("isUserEnableReceipt");
  }

  ///设置当前用户是否启用回执功能，仅当服务支持回执功能有效
  static Future<void> setUserEnableReceipt(
      bool isEnable,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod(
        "setUserEnableReceipt", {"requestId": requestId, "isEnable": isEnable});
  }

  ///获取收藏好友列表
  static Future<List<String>> getFavUsers() async {
    return convertDynamicList(await _channel.invokeMethod("getFavUsers"));
  }

  ///是否是收藏用户
  static Future<bool> isFavUser(String userId) async {
    return await _channel.invokeMethod("isFavUser", {"userId": userId});
  }

  ///设置收藏用户
  static Future<void> setFavUser(
      String userId,
      bool isFav,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("setFavUser",
        {"requestId": requestId, "userId": userId, "isFav": isFav});
  }

  ///加入聊天室
  static Future<void> joinChatroom(
      String chatroomId,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod(
        "joinChatroom", {"requestId": requestId, "chatroomId": chatroomId});
  }

  ///退出聊天室
  static Future<void> quitChatroom(
      String chatroomId,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod(
        "quitChatroom", {"requestId": requestId, "chatroomId": chatroomId});
  }

  ///获取聊天室信息
  static Future<void> getChatroomInfo(
      String chatroomId,
      int updateDt,
      OperationSuccessChatroomInfoCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("getChatroomInfo", {
      "requestId": requestId,
      "chatroomId": chatroomId,
      "updateDt": updateDt.toString()
    });
  }

  ///获取聊天室成员信息
  static Future<void> getChatroomMemberInfo(
      String chatroomId,
      OperationSuccessChatroomMemberInfoCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("getChatroomMemberInfo",
        {"requestId": requestId, "chatroomId": chatroomId});
  }

  ///创建频道
  static Future<void> createChannel(
      String channelName,
      String channelPortrait,
      int status,
      String desc,
      String extra,
      OperationSuccessChannelInfoCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("createChannel", {
      "requestId": requestId,
      "name": channelName,
      "portrait": channelPortrait,
      "status": status,
      "desc": desc,
      "extra": extra
    });
  }

  ///获取频道信息
  static Future<ChannelInfo> getChannelInfo(String channelId,
      {bool refresh = false}) async {
    Map<dynamic, dynamic> data = await _channel.invokeMethod(
        "getChannelInfo", {"channelId": channelId, "refresh": refresh});
    return _convertProtoChannelInfo(data);
  }

  ///修改频道信息
  static Future<void> modifyChannelInfo(
      String channelId,
      ModifyChannelInfoType modifyType,
      String newValue,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("modifyChannelInfo", {
      "requestId": requestId,
      "channelId": channelId,
      "modifyType": modifyType.index,
      "newValue": newValue
    });
  }

  ///搜索频道
  static Future<void> searchChannel(
      String keyword,
      OperationSuccessChannelInfosCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod(
        "searchChannel", {"requestId": requestId, "keyword": keyword});
  }

  ///是否是已订阅频道
  static Future<bool> isListenedChannel(String channelId) async {
    return await _channel
        .invokeMethod("isListenedChannel", {"channelId": channelId});
  }

  ///订阅/取消订阅频道
  static Future<void> listenChannel(
      String channelId,
      bool isListen,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("listenChannel",
        {"requestId": requestId, "channelId": channelId, "isListen": isListen});
  }

  ///获取我的频道
  static Future<List<String>> getMyChannels() async {
    return convertDynamicList(await _channel.invokeMethod("getMyChannels"));
  }

  ///获取我订阅的频道
  static Future<List<String>> getListenedChannels() async {
    return convertDynamicList(
        await _channel.invokeMethod("getListenedChannels"));
  }

  ///销毁频道
  static Future<void> destoryChannel(
      String channelId,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod(
        "destoryChannel", {"requestId": requestId, "channelId": channelId});
  }

  ///获取PC端在线状态
  static Future<List<OnlineInfo>> getOnlineInfos() async {
    List<dynamic> datas = await _channel.invokeMethod("getOnlineInfos");
    return _convertProtoOnlineInfos(datas);
  }

  ///踢掉PC客户端
  static Future<void> kickoffPCClient(
      String clientId,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod(
        "kickoffPCClient", {"requestId": requestId, "clientId": clientId});
  }

  ///是否设置当PC在线时停止手机通知
  static Future<bool> isMuteNotificationWhenPcOnline() async {
    return await _channel.invokeMethod("isMuteNotificationWhenPcOnline");
  }

  ///设置/取消设置当PC在线时停止手机通知
  static Future<void> muteNotificationWhenPcOnline(
      bool isMute,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("muteNotificationWhenPcOnline",
        {"requestId": requestId, "isMute": isMute});
  }

  ///获取会话文件记录
  static Future<void> getConversationFiles(
      int beforeMessageUid,
      int count,
      OperationSuccessFilesCallback successCallback,
      OperationFailureCallback errorCallback,
      {Conversation conversation,
      String fromUser}) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("getConversationFiles", {
      "requestId": requestId,
      "conversation": _convertConversation(conversation),
      "fromUser": fromUser,
      "beforeMessageUid": beforeMessageUid.toString(),
      "count": count
    });
  }

  ///获取我的文件记录
  static Future<void> getMyFiles(
      int beforeMessageUid,
      int count,
      OperationSuccessFilesCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("getMyFiles", {
      "requestId": requestId,
      "beforeMessageUid": beforeMessageUid.toString(),
      "count": count
    });
  }

  ///删除文件记录
  static Future<void> deleteFileRecord(
      int messageUid,
      int count,
      OperationSuccessFilesCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("deleteFileRecord",
        {"requestId": requestId, "messageUid": messageUid.toString()});
  }

  ///搜索文件记录
  static Future<void> searchFiles(
      String keyword,
      int beforeMessageUid,
      int count,
      OperationSuccessFilesCallback successCallback,
      OperationFailureCallback errorCallback,
      {Conversation conversation,
      String fromUser}) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("searchFiles", {
      "requestId": requestId,
      "keyword": keyword,
      "beforeMessageUid": beforeMessageUid.toString(),
      "count": count,
      "conversation": _convertConversation(conversation),
      "fromUser": fromUser
    });
  }

  ///搜索我的文件记录
  static Future<void> searchMyFiles(
      String keyword,
      int beforeMessageUid,
      int count,
      OperationSuccessFilesCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("searchMyFiles", {
      "requestId": requestId,
      "keyword": keyword,
      "beforeMessageUid": beforeMessageUid.toString(),
      "count": count
    });
  }

  ///获取经过授权的媒体路径
  static Future<void> getAuthorizedMediaUrl(
      String mediaPath,
      int messageUid,
      int mediaType,
      OperationSuccessStringCallback successCallback,
      OperationFailureCallback errorCallback) async {
    int requestId = _requestId++;
    if (successCallback != null)
      _operationSuccessCallbackMap[requestId] = successCallback;
    if (errorCallback != null) _errorCallbackMap[requestId] = errorCallback;
    await _channel.invokeMethod("getAuthorizedMediaUrl", {
      "requestId": requestId,
      "mediaPath": mediaPath,
      "messageUid": messageUid.toString(),
      "mediaType": mediaType
    });
  }

  ///转换amr数据为wav数据，仅在iOS平台有效
  static Future<Uint8List> getWavData(String amrPath) async {
    return await _channel.invokeMethod("getWavData", {"amrPath": amrPath});
  }

  ///开启协议栈数据库事物，仅当数据迁移功能使用
  static Future<bool> beginTransaction() async {
    return await _channel.invokeMethod("beginTransaction");
  }

  ///提交协议栈数据库事物，仅当数据迁移功能使用
  static Future<void> commitTransaction() async {
    await _channel.invokeMethod("commitTransaction");
  }

  ///是否是专业版
  static Future<bool> isCommercialServer() async {
    return await _channel.invokeMethod("isCommercialServer");
  }

  ///服务是否支持消息回执
  static Future<bool> isReceiptEnabled() async {
    return await _channel.invokeMethod("isReceiptEnabled");
  }
}
