import 'dart:convert';
import 'dart:ffi';

import 'package:event_bus/event_bus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:imclient/message/media_message_content.dart';
import 'package:imclient/model/user_online_state.dart';
import 'package:imclient/tools.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'imclient.dart';
import 'message/message.dart';
import 'message/message_content.dart';
import 'message/unknown_message_content.dart';
import 'model/channel_info.dart';
import 'model/chatroom_info.dart';
import 'model/chatroom_member_info.dart';
import 'model/conversation.dart';
import 'model/conversation_info.dart';
import 'model/conversation_search_info.dart';
import 'model/file_record.dart';
import 'model/friend.dart';
import 'model/friend_request.dart';
import 'model/group_info.dart';
import 'model/group_member.dart';
import 'model/group_search_info.dart';
import 'model/im_constant.dart';
import 'model/message_payload.dart';
import 'model/pc_online_info.dart';
import 'model/read_report.dart';
import 'model/unread_count.dart';
import 'model/user_info.dart';

/// An implementation of [ImclientPlatform] that uses method channels.
class ImclientPlatform extends PlatformInterface {
  /// Constructs a ImclientPlatform.
  ImclientPlatform() : super(token: _token);

  static final Object _token = Object();

  static ImclientPlatform _instance = ImclientPlatform();

  /// The default instance of [ImclientPlatform] to use.
  ///
  /// Defaults to [ImclientPlatform].
  static ImclientPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [ImclientPlatform] when
  /// they register themselves.
  static set instance(ImclientPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }
  
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('imclient');

  static late ConnectionStatusChangedCallback _connectionStatusChangedCallback;
  static late ReceiveMessageCallback _receiveMessageCallback;
  static late RecallMessageCallback _recallMessageCallback;
  static late DeleteMessageCallback _deleteMessageCallback;
  static MessageDeliveriedCallback? _messageDeliveriedCallback;
  static MessageReadedCallback? _messageReadedCallback;
  static GroupInfoUpdatedCallback? _groupInfoUpdatedCallback;
  static GroupMemberUpdatedCallback? _groupMemberUpdatedCallback;
  static UserInfoUpdatedCallback? _userInfoUpdatedCallback;
  static FriendListUpdatedCallback? _friendListUpdatedCallback;
  static FriendRequestListUpdatedCallback? _friendRequestListUpdatedCallback;
  static UserSettingsUpdatedCallback? _userSettingsUpdatedCallback;
  static ChannelInfoUpdatedCallback? _channelInfoUpdatedCallback;
  static OnlineEventCallback? _onlineEventCallback;


  static int _requestId = 0;
  static final Map<int, SendMessageSuccessCallback> _sendMessageSuccessCallbackMap =
  {};
  static final Map<int, OperationFailureCallback> _errorCallbackMap = {};
  static final Map<int, SendMediaMessageProgressCallback>
  _sendMediaMessageProgressCallbackMap = {};
  static final Map<int, SendMediaMessageUploadedCallback>
  _sendMediaMessageUploadedCallbackMap = {};

  static final Map<int, dynamic> _operationSuccessCallbackMap = {};

  static final Map<int, Message> _sendingMessages = {};

  static final EventBus _eventBus = EventBus();

  late String userId;

  // ignore: non_constant_identifier_names
  @override
  EventBus get IMEventBus {
    return _eventBus;
  }

  ///客户端ID，客户端的唯一标示。获取IM Token时必须带上正确的客户端ID，否则会无法连接成功。
  @override
  Future<String> get clientId async {
    return await methodChannel.invokeMethod('getClientId');
  }

  ///客户端是否调用过connect
  @override
  Future<bool> get isLogined async {
    return await methodChannel.invokeMethod('isLogined');
  }

  ///连接状态
  @override
  Future<int> get connectionStatus async {
    return await methodChannel.invokeMethod('connectionStatus');
  }

  ///当前用户ID
  @override
  String get currentUserId {
    return userId;
  }

  ///当前服务器与客户端时间的差值，单位是毫秒，只能是初略估计，不精确。
  @override
  Future<int> get serverDeltaTime async {
    return await methodChannel.invokeMethod('serverDeltaTime');
  }

  ///开启协议栈日志
  @override
  Future<void> startLog() async {
    await methodChannel.invokeMethod('startLog');
  }

  ///结束协议栈日志
  @override
  Future<void> stopLog() async {
    await methodChannel.invokeMethod('stopLog');
  }

  @override
  Future<void> setSendLogCommand(String sendLogCmd) async {
    await methodChannel.invokeMethod('setSendLogCommand', {"cmd":sendLogCmd});
  }

  @override
  Future<void> useSM4() async {
    await methodChannel.invokeMethod('useSM4');
  }

  @override
  Future<void> setLiteMode(bool liteMode) async {
    return methodChannel.invokeMethod('setLiteMode', {"liteMode":liteMode});
  }

  @override
  Future<void> setDeviceToken(int pushType, String deviceToken) async {
    return methodChannel.invokeMethod('setDeviceToken', {"pushType":pushType, "deviceToken":deviceToken});
  }

  @override
  Future<void> setVoipDeviceToken(String voipToken) async {
    return methodChannel.invokeMethod('setVoipDeviceToken', {"voipToken":voipToken});
  }

  @override
  Future<void> setBackupAddressStrategy(int strategy) async {
    return methodChannel.invokeMethod('setBackupAddressStrategy', {"strategy":strategy});
  }

  @override
  Future<void> setBackupAddress(String host, int port) async {
    return methodChannel.invokeMethod('setBackupAddress', {"host":host, "port":port});
  }

  @override
  Future<void> setProtoUserAgent(String agent) async {
    return methodChannel.invokeMethod('setProtoUserAgent', {"agent":agent});
  }

  @override
  Future<void> addHttpHeader(String header, String value) async {
    return methodChannel.invokeMethod('addHttpHeader', {"header":header, "value":value});
  }

  @override
  Future<void> setProxyInfo(String host, String ip, int port, {String? userName, String? password}) async {
    Map<String, dynamic> args = {"host":host, "ip":ip, "port":port, "userName":userName, "password":password};

    if(userName != null) {
      args['userName'] = userName;
    }
    if(password != null) {
      args['password'] = password;
    }

    return methodChannel.invokeMethod('setProxyInfo', args);
  }

  @override
  Future<String> get protoRevision async {
    return await methodChannel.invokeMethod('getProtoRevision');
  }

  ///获取协议栈日志文件路径
  @override
  Future<List<String>> get logFilesPath async {
    return Tools.convertDynamicList(await methodChannel.invokeMethod('getLogFilesPath'));
  }

  static setDefaultPortraitProvider(DefaultPortraitProvider provider) {
    defaultPortraitProvider = provider;
  }

  static DefaultPortraitProvider? defaultPortraitProvider;

  @override
  void init(
      ConnectionStatusChangedCallback connectionStatusChangedCallback,
      ReceiveMessageCallback receiveMessageCallback,
      RecallMessageCallback recallMessageCallback,
      DeleteMessageCallback deleteMessageCallback,
      {MessageDeliveriedCallback? messageDeliveriedCallback,
        MessageReadedCallback? messageReadedCallback,
        GroupInfoUpdatedCallback? groupInfoUpdatedCallback,
        GroupMemberUpdatedCallback? groupMemberUpdatedCallback,
        UserInfoUpdatedCallback? userInfoUpdatedCallback,
        FriendListUpdatedCallback? friendListUpdatedCallback,
        FriendRequestListUpdatedCallback? friendRequestListUpdatedCallback,
        UserSettingsUpdatedCallback? userSettingsUpdatedCallback,
        ChannelInfoUpdatedCallback? channelInfoUpdatedCallback,
        OnlineEventCallback? onlineEventCallback}) async {
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
    _onlineEventCallback = onlineEventCallback;


    methodChannel.invokeMethod<Void>('initProto');

    methodChannel.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'onConnectionStatusChanged':
          int status = call.arguments;
          _connectionStatusChangedCallback(status);
          _eventBus.fire(ConnectionStatusChangedEvent(status));
          break;
        case 'onReceiveMessage':
          Map<dynamic, dynamic> args = call.arguments;
          bool hasMore = args['hasMore'];
          List<dynamic> list = args['messages'];
          List<Message> messages = _convertProtoMessages(list);
          if(messages.isNotEmpty) {
            _receiveMessageCallback(messages, hasMore);
            _eventBus.fire(ReceiveMessagesEvent(messages, hasMore));
          }
          break;
        case 'onRecallMessage':
          Map<dynamic, dynamic> args = call.arguments;
          int messageUid = args['messageUid'];
          _recallMessageCallback(messageUid);
          _eventBus.fire(RecallMessageEvent(messageUid));
          break;
        case 'onDeleteMessage':
          Map<dynamic, dynamic> args = call.arguments;
          int messageUid = args['messageUid'];
          _deleteMessageCallback(messageUid);
          _eventBus.fire(DeleteMessageEvent(messageUid));
          break;
        case 'onMessageDelivered':
          Map<dynamic, dynamic> args = call.arguments;
          Map<String, int> data = {};
          args.forEach((key, value) {
            data[key] = value;
          });
          if (_messageDeliveriedCallback != null) {
            _messageDeliveriedCallback!(data);
          }
          _eventBus.fire(MessageDeliveriedEvent(data));
          break;
        case 'onMessageReaded':
          Map<dynamic, dynamic> args = call.arguments;
          List<dynamic> reads = args['readeds'];
          List<ReadReport> reports = [];
          for (var element in reads) {
            ReadReport? readReport = _convertProtoReadEntry(element);
            if(readReport != null) {
              reports.add(readReport);
            }
          }
          if (_messageReadedCallback != null) {
            _messageReadedCallback!(reports);
          }
          _eventBus.fire(MessageReadedEvent(reports));
          break;
        case 'onConferenceEvent':
          break;
        case 'onGroupInfoUpdated':
          Map<dynamic, dynamic> args = call.arguments;
          List<dynamic> groups = args['groups'];
          List<GroupInfo> data = [];
          for (var element in groups) {
            GroupInfo? groupInfo = await _convertProtoGroupInfo(element);
            if(groupInfo != null) {
              data.add(groupInfo);
            }
          }
          if (_groupInfoUpdatedCallback != null) {
            _groupInfoUpdatedCallback!(data);
          }
          _eventBus.fire(GroupInfoUpdatedEvent(data));
          break;
        case 'onGroupMemberUpdated':
          Map<dynamic, dynamic> args = call.arguments;
          String groupId = args['groupId'];
          List<dynamic> members = args['members'];
          List<GroupMember> data = [];
          for (var element in members) {
            data.add(_convertProtoGroupMember(element)!);
          }
          if (_groupMemberUpdatedCallback != null) {
            _groupMemberUpdatedCallback!(groupId, data);
          }
          _eventBus.fire(GroupMembersUpdatedEvent(groupId, data));
          break;
        case 'onUserInfoUpdated':
          Map<dynamic, dynamic> args = call.arguments;
          List<dynamic> users = args['users'];
          List<UserInfo> data = [];
          for (var element in users) {
            UserInfo? userInfo = _convertProtoUserInfo(element);
            if(userInfo != null) {
              data.add(userInfo);
            }
          }
          if (_userInfoUpdatedCallback != null) {
            _userInfoUpdatedCallback!(data);
          }
          _eventBus.fire(UserInfoUpdatedEvent(data));

          break;
        case 'onFriendListUpdated':
          Map<dynamic, dynamic> args = call.arguments;
          List<dynamic> friendIdList = args['friends'];
          List<String> friends = [];
          for (var element in friendIdList) {
            friends.add(element);
          }
          if (_friendListUpdatedCallback != null) {
            _friendListUpdatedCallback!(friends);
          }
          _eventBus.fire(FriendUpdateEvent(friends));
          break;
        case 'onFriendRequestUpdated':
          Map<dynamic, dynamic> args = call.arguments;
          final friendRequestList = (args['requests'] as List).cast<String>();
          if (_friendRequestListUpdatedCallback != null) {
            _friendRequestListUpdatedCallback!(friendRequestList);
          }
          _eventBus.fire(FriendRequestUpdateEvent(friendRequestList));
          break;
        case 'onSettingUpdated':
          if (_userSettingsUpdatedCallback != null) {
            _userSettingsUpdatedCallback!();
          }
          _eventBus.fire(UserSettingUpdatedEvent());
          break;
        case 'onChannelInfoUpdated':
          Map<dynamic, dynamic> args = call.arguments;
          List<dynamic> channels = args['channels'];
          List<ChannelInfo> data = [];
          for (var element in channels) {
            ChannelInfo? channelInfo = _convertProtoChannelInfo(element);
            if(channelInfo != null) {
              data.add(channelInfo);
            }
          }
          if (_channelInfoUpdatedCallback != null) {
            _channelInfoUpdatedCallback!(data);
          }
          _eventBus.fire(ChannelInfoUpdateEvent(data));
          break;
        case 'onUserOnlineEvent':
          Map<dynamic, dynamic> args = call.arguments;
          List<dynamic> states = args['states'];
          List<UserOnlineState> data = [];
          for (var state in states) {
            UserOnlineState info = _convertProtoUserOnlineState(state);
            data.add(info);
          }
          if(_onlineEventCallback != null) {
            _onlineEventCallback!(data);
          }
          _eventBus.fire(UserOnlineStateUpdatedEvent(data));
          break;
        case 'onSendMessageSuccess':
          Map<dynamic, dynamic> args = call.arguments;
          int requestId = args['requestId'];
          int messageId = args['messageId'];
          int messageUid = args['messageUid'];
          int timestamp = args['timestamp'];
          if(messageId > 0) {
            Message? message = _sendingMessages[messageId];
            if(message != null) {
              message.messageUid = messageUid;
              message.serverTime = timestamp;
              message.status = MessageStatus.Message_Status_Sent;
              _sendingMessages.remove(messageId);
            }
          }

          var callback = _sendMessageSuccessCallbackMap[requestId];
          if (callback != null) {
            callback(messageUid, timestamp);
          }
          _removeSendMessageCallback(requestId);
          _eventBus.fire(SendMessageSuccessEvent(messageId, messageUid, timestamp));
          break;
        case 'onSendMediaMessageProgress':
          Map<dynamic, dynamic> args = call.arguments;
          int requestId = args['requestId'];
          int messageId = args['messageId'];
          int uploaded = args['uploaded'];
          int total = args['total'];
          var callback = _sendMediaMessageProgressCallbackMap[requestId];
          if (callback != null) {
            callback(uploaded, total);
          }
          _eventBus.fire(SendMessageProgressEvent(messageId, total, uploaded));
          break;
        case 'onSendMediaMessageUploaded':
          Map<dynamic, dynamic> args = call.arguments;
          int requestId = args['requestId'];
          int messageId = args['messageId'];
          String remoteUrl = args['remoteUrl'];
          if(messageId > 0) {
            Message? message = _sendingMessages[messageId];
            if(message != null && message.content is MediaMessageContent) {
              MediaMessageContent mediaCnt = message.content as MediaMessageContent;
              mediaCnt.remoteUrl = remoteUrl;
            }
          }

          var callback = _sendMediaMessageUploadedCallbackMap[requestId];
          if (callback != null) {
            callback(remoteUrl);
          }
          _eventBus.fire(SendMessageMediaUploadedEvent(messageId, remoteUrl));
          break;
        case 'onSendMessageFailure':
          Map<dynamic, dynamic> args = call.arguments;
          int requestId = args['requestId'];
          int messageId = args['messageId'];
          int errorCode = args['errorCode'];

          if(messageId > 0) {
            Message? message = _sendingMessages[messageId];
            if(message != null) {
              message.status = MessageStatus.Message_Status_Send_Failure;
              _sendingMessages.remove(messageId);
            }
          }

          var callback = _errorCallbackMap[requestId];
          if (callback != null) {
            callback(errorCode);
          }
          _removeAllOperationCallback(requestId);
          _eventBus.fire(SendMessageFailureEvent(messageId, errorCode));
          break;
        case 'onUploadMediaUploaded':
          Map<dynamic, dynamic> args = call.arguments;
          int requestId = args['requestId'];
          String remoteUrl = args['remoteUrl'];
          var callback = _operationSuccessCallbackMap[requestId];
          if (callback != null) {
            callback(remoteUrl);
          }
          break;
        case 'onUploadMediaProgress':
          Map<dynamic, dynamic> args = call.arguments;
          int requestId = args['requestId'];
          int uploaded = args['uploaded'];
          int total = args['total'];
          var callback = _sendMediaMessageProgressCallbackMap[requestId];
          if (callback != null) {
            callback(uploaded, total);
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
        case 'onMessageCallback':
          Map<dynamic, dynamic> args = call.arguments;
          int requestId = args['requestId'];
          Map datas = args['message'];
          var callback = _operationSuccessCallbackMap[requestId];
          if (callback != null) {
            callback(_convertProtoMessage(datas));
          }
          _removeOperationCallback(requestId);
          break;
        case 'onGetUploadUrl':
          Map<dynamic, dynamic> args = call.arguments;
          int requestId = args['requestId'];
          String uploadUrl = args['uploadUrl'];
          String downloadUrl = args['downloadUrl'];
          String backupUploadUrl = args['backupUploadUrl'];
          int type = args['type'];
          var callback = _operationSuccessCallbackMap[requestId];
          if (callback != null) {
            callback(uploadUrl, downloadUrl, backupUploadUrl, type);
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
        case 'onWatchOnlineStateSuccess':
          Map<dynamic, dynamic> args = call.arguments;
          int requestId = args['requestId'];
          List<dynamic> states = args['states'];
          List<UserOnlineState> data = [];
          for (var state in states) {
            UserOnlineState info = _convertProtoUserOnlineState(state);
            data.add(info);
          }
          var callback = _operationSuccessCallbackMap[requestId];
          if (callback != null) {
            callback(data);
          }
          _removeOperationCallback(requestId);
          break;
        case 'onOperationStringListSuccess':
          Map<dynamic, dynamic> args = call.arguments;
          int requestId = args['requestId'];
          List<String> strList = Tools.convertDynamicList(args['strings']);
          var callback = _operationSuccessCallbackMap[requestId];
          if (callback != null) {
            callback(strList);
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
        default:
          print("Unknown event:${call.method}");
          //should not be here!
          break;
      }
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

  @override
  void registerMessage(MessageContentMeta contentMeta) {
    _contentMetaMap[contentMeta.type] = contentMeta;
    Map<String, dynamic> map = {};
    map["type"] = contentMeta.type;
    map["flag"] = contentMeta.flag.index;
    methodChannel.invokeMethod('registerMessage', map);
  }

  Message? _convertProtoMessage(Map<dynamic, dynamic>? map) {
    if(map == null) {
      return null;
    }

    Message msg = Message();
    msg.messageId = map['messageId'];
    if(map['messageUid'] is String) {
      String str = map['messageUid'];
      str = str.replaceAll("L", "");
      msg.messageUid = int.tryParse(str);
    } else {
      msg.messageUid = map['messageUid'];
    }

    msg.conversation = _convertProtoConversation(map['conversation']);
    msg.fromUser = map['sender'];
    if(map['toUsers'] != null) {
      msg.toUsers = (map['toUsers'] as List).cast<String>();
    }
    msg.content =
        decodeMessageContent(_convertProtoMessageContent(map['content']));
    msg.direction = MessageDirection.values[map['direction']];
    msg.status = MessageStatus.values[map['status']];
    msg.serverTime = map['serverTime'];
    msg.localExtra = map['localExtra'];
    return msg;
  }

  List<Message> _convertProtoMessages(List<dynamic> datas) {
    if (datas.isEmpty) {
      return [];
    }
    List<Message> messages = [];
    for (int i = 0; i < datas.length; ++i) {
      var element = datas[i];
      Message? msg = _convertProtoMessage(element);
      if(msg != null) {
        messages.add(msg);
      }
    }
    return messages;
  }

  static Conversation _convertProtoConversation(Map<dynamic, dynamic> map) {
    Conversation conversation = Conversation();
    conversation.conversationType = ConversationType.values[map['type']];
    conversation.target = map['target'];
    if (map['line'] == null) {
      conversation.line = 0;
    } else {
      conversation.line = map['line'];
    }

    return conversation;
  }

  List<ConversationInfo> _convertProtoConversationInfos(
      List<dynamic>? maps) {
    if (maps == null || maps.isEmpty) {
      return [];
    }
    List<ConversationInfo> infos = [];
    for (int i = 0; i < maps.length; ++i) {
      var element = maps[i];
      infos.add(_convertProtoConversationInfo(element));
    }

    return infos;
  }

  ConversationInfo _convertProtoConversationInfo(
      Map<dynamic, dynamic> map) {
    ConversationInfo conversationInfo = ConversationInfo();
    conversationInfo.conversation =
        _convertProtoConversation(map['conversation']);
    conversationInfo.lastMessage = _convertProtoMessage(map['lastMessage']);
    conversationInfo.draft = map['draft'];
    if (map['timestamp'] != null) conversationInfo.timestamp = map['timestamp'];
    if (map['isTop'] != null) conversationInfo.isTop = map['isTop'];
    if (map['isSilent'] != null) conversationInfo.isSilent = map['isSilent'];
    conversationInfo.unreadCount = _convertProtoUnreadCount(map['unreadCount']);

    return conversationInfo;
  }

  List<ConversationSearchInfo> _convertProtoConversationSearchInfos(List<dynamic> maps, String? keyword) {
    if (maps.isEmpty) {
      return [];
    }

    List<ConversationSearchInfo> infos = [];
    for (int i = 0; i < maps.length; i++) {
      var element = maps[i];
      var info = _convertProtoConversationSearchInfo(element);
      info.keyword = keyword;
      infos.add(info);
    }

    return infos;
  }

  ConversationSearchInfo _convertProtoConversationSearchInfo(
      Map<dynamic, dynamic> map) {
    ConversationSearchInfo conversationInfo = ConversationSearchInfo();
    conversationInfo.conversation =
        _convertProtoConversation(map['conversation']);
    conversationInfo.marchedMessage =
    _convertProtoMessage(map['marchedMessage']);
    if (map['marchedCount'] != null) {
      conversationInfo.marchedCount = map['marchedCount'];
    }
    conversationInfo.timestamp = map['timestamp'];
    return conversationInfo;
  }

  static FriendRequest? _convertProtoFriendRequest(Map<dynamic, dynamic>? data) {
    if(data == null || data['target'] == null) {
      return null;
    }

    FriendRequest friendRequest = FriendRequest();
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
      return [];
    }

    List<FriendRequest> list = [];
    for (var element in datas) {
      FriendRequest? request = _convertProtoFriendRequest(element);
      if(request != null) {
        list.add(request);
      }
    }
    return list;
  }

  static Friend _convertProtoFriend(Map<dynamic, dynamic> data) {
    Friend friend = Friend();
    friend.userId = data['userId'];
    friend.alias = data['alias'];
    friend.extra = data['extra'];
    friend.timestamp = data['timestamp'];
    return friend;
  }

  static List<Friend> _convertProtoFriends(List<dynamic> datas) {
    if (datas.isEmpty) {
      return [];
    }

    List<Friend> list = [];
    for (var element in datas) {
      list.add(_convertProtoFriend(element));
    }
    return list;
  }

  static Future<List<GroupSearchInfo>> _convertProtoGroupSearchInfos(
      List<dynamic> maps) async {
    if (maps.isEmpty) {
      return [];
    }

    List<GroupSearchInfo> infos = [];
    for (var element in maps) {
      infos.add(await _convertProtoGroupSearchInfo(element));
    }

    return infos;
  }

  static Future<GroupSearchInfo> _convertProtoGroupSearchInfo (
      Map<dynamic, dynamic> map) async {
    GroupSearchInfo groupSearchInfo = GroupSearchInfo();
    groupSearchInfo.groupInfo = await _convertProtoGroupInfo(map['groupInfo']);
    groupSearchInfo.marchType = GroupSearchResultType.values[map['marchType']];
    groupSearchInfo.marchedMemberNames = map['marchedMemberNames'];

    return groupSearchInfo;
  }

  static UnreadCount _convertProtoUnreadCount(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return UnreadCount();
    }
    UnreadCount unreadCount = UnreadCount();
    if (map['unread'] != null) unreadCount.unread = map['unread'];
    if (map['unreadMention'] != null) unreadCount.unreadMention = map['unreadMention'];
    if (map['unreadMentionAll'] != null) unreadCount.unreadMentionAll = map['unreadMentionAll'];
    return unreadCount;
  }

  static MessagePayload _convertProtoMessageContent(Map<dynamic, dynamic> map) {
    MessagePayload payload = MessagePayload();
    payload.contentType = map['type'];
    payload.searchableContent = map['searchableContent'];
    payload.pushContent = map['pushContent'];
    payload.pushData = map['pushData'];
    payload.content = map['content'];
    if(map['binaryContent'] != null) {
      payload.binaryContent = base64Decode(map['binaryContent']);
    }
    payload.localContent = map['localContent'];
    if (map['mentionedType'] != null) {
      payload.mentionedType = map['mentionedType'];
    }
    if(map['mentionedTargets'] != null) {
      payload.mentionedTargets = Tools.convertDynamicList(map['mentionedTargets']);
    }

    if (map['mediaType'] != null) {
      payload.mediaType = MediaType.values[map['mediaType']];
    }
    payload.remoteMediaUrl = map['remoteMediaUrl'];
    payload.localMediaPath = map['localMediaPath'];

    payload.extra = map['extra'];
    return payload;
  }

  static Map<String, dynamic> _convertConversation(Conversation conversation) {
    Map<String, dynamic> map = {};

    map['type'] = conversation.conversationType.index;
    map['target'] = conversation.target;
    map['line'] = conversation.line;
    return map;
  }

  static Map<String, dynamic> _convertMessageContent(
      MessageContent content) {
    Map<String, dynamic> map = {};
    MessagePayload payload = content.encode();
    map['type'] = payload.contentType;
    if (payload.searchableContent != null) {
      map['searchableContent'] = payload.searchableContent;
    }
    if (payload.pushContent != null) map['pushContent'] = payload.pushContent;
    if (payload.pushData != null) map['pushData'] = payload.pushData;
    if (payload.content != null) map['content'] = payload.content;
    if (payload.binaryContent != null) {
      map['binaryContent'] = payload.binaryContent;
    }
    if (payload.localContent != null) {
      map['localContent'] = payload.localContent;
    }
    map['mentionedType'] = payload.mentionedType;
    if (payload.mentionedTargets != null) {
      map['mentionedTargets'] = payload.mentionedTargets;
    }
    map['mediaType'] = payload.mediaType.index;
    if (payload.remoteMediaUrl != null) {
      map['remoteMediaUrl'] = payload.remoteMediaUrl;
    }
    if (payload.localMediaPath != null) {
      map['localMediaPath'] = payload.localMediaPath;
    }
    if (payload.extra != null) map['extra'] = payload.extra;
    return map;
  }

  static ReadReport? _convertProtoReadEntry(Map<dynamic, dynamic>? map) {
    if(map == null) {
      return null;
    }

    ReadReport report = ReadReport();
    report.conversation = _convertProtoConversation(map['conversation']);
    report.userId = map['userId'];
    report.readDt = map['readDt'];
    return report;
  }

  static Future<GroupInfo?> _convertProtoGroupInfo(Map<dynamic, dynamic>? map) async {
    if (map == null || map['target'] == null) return null;

    GroupInfo groupInfo = GroupInfo();
    groupInfo.type = GroupType.values[map['type']];
    groupInfo.target = map['target'];
    groupInfo.name = map['name'];
    groupInfo.extra = map['extra'];
    groupInfo.remark = map['remark'];
    groupInfo.portrait = map['portrait'];
    groupInfo.owner = map['owner'];
    if (map['memberCount'] != null) groupInfo.memberCount = map['memberCount'];
    if (map['mute'] != null) groupInfo.mute = map['mute'];

    if (map['joinType'] != null) groupInfo.joinType = map['joinType'];
    if (map['privateChat'] != null) groupInfo.privateChat = map['privateChat'];
    if (map['searchable'] != null) groupInfo.searchable = map['searchable'];
    if (map['historyMessage'] != null) {
      groupInfo.historyMessage = map['historyMessage'];
    }
    if (map['updateDt'] != null) groupInfo.updateDt = map['updateDt'];

    if(defaultPortraitProvider != null && (groupInfo.portrait == null || groupInfo.portrait!.isEmpty)) {
      List<GroupMember> members = await Imclient.getGroupMembersByCount(groupInfo.target, 9);
      List<String> userIds = [];
      for(var gm in members) {
        userIds.add(gm.memberId);
      }
      List<UserInfo> useInfos = await Imclient.getUserInfos(userIds, groupId: groupInfo.target);
      if(useInfos.length == members.length) {
        groupInfo.portrait = defaultPortraitProvider!.groupDefaultPortrait(groupInfo, useInfos);
      }
    }

    return groupInfo;
  }

  static GroupMember? _convertProtoGroupMember(Map<dynamic, dynamic>? map) {
    if(map == null || map['memberId'] == null) {
      return null;
    }
    GroupMember groupMember = GroupMember();
    if (map['type'] != null) {
      groupMember.type = GroupMemberType.values[map['type']];
    } else {
      groupMember.type = GroupMemberType.Normal;
    }

    groupMember.groupId = map['groupId'];
    groupMember.memberId = map['memberId'];
    groupMember.alias = map['alias'];
    groupMember.extra = map['extra'];

    if (map['updateDt'] != null) groupMember.updateDt = map['updateDt'];
    if (map['createDt'] != null) groupMember.createDt = map['createDt'];

    return groupMember;
  }

  static List<GroupMember> _convertProtoGroupMembers(List<dynamic> datas) {
    if (datas.isEmpty) {
      return [];
    }
    List<GroupMember> list = [];
    for (var element in datas) {
      GroupMember? member = _convertProtoGroupMember(element);
      if(member != null) {
        list.add(member);
      }
    }
    return list;
  }

  static UserInfo? _convertProtoUserInfo(Map<dynamic, dynamic>? map) {
    if (map == null || map['uid'] == null) {
      return null;
    }
    UserInfo userInfo = UserInfo();
    userInfo.userId = map['uid'];
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
    if(defaultPortraitProvider != null && (userInfo.portrait == null || userInfo.portrait!.isEmpty)) {
      userInfo.portrait = defaultPortraitProvider!.userDefaultPortrait(userInfo);
    }

    return userInfo;
  }

  static List<UserInfo> _convertProtoUserInfos(List<dynamic>? datas) {
    if (datas == null || datas.isEmpty) {
      return [];
    }
    List<UserInfo> list = [];
    for (var element in datas) {
      UserInfo? userInfo = _convertProtoUserInfo(element);
      if(userInfo != null) {
        list.add(userInfo);
      }
    }
    return list;
  }

  static ChannelInfo? _convertProtoChannelInfo(Map<dynamic, dynamic>? map) {
    if(map == null || map['channelId'] == null) {
      return null;
    }
    ChannelInfo channelInfo = ChannelInfo();
    channelInfo.channelId = map['channelId'];
    channelInfo.desc = map['desc'];
    channelInfo.extra = map['extra'];
    channelInfo.name = map['name'];
    channelInfo.portrait = map['portrait'];
    channelInfo.owner = map['owner'];
    channelInfo.secret = map['secret'];
    channelInfo.callback = map['callback'];
    if (map['status'] != null) {
      channelInfo.status = map['status'];
    }
    if (map['updateDt'] != null) channelInfo.updateDt = map['updateDt'];

    return channelInfo;
  }

  static List<ChannelInfo> _convertProtoChannelInfos(List<dynamic> datas) {
    if (datas.isEmpty) {
      return [];
    }
    List<ChannelInfo> list = [];
    for (var element in datas) {
      ChannelInfo? channelInfo = _convertProtoChannelInfo(element);
      if(channelInfo != null) {
        list.add(channelInfo);
      }
    }
    return list;
  }

  static ChatroomInfo? _convertProtoChatroomInfo(Map<dynamic, dynamic>? map) {
    if(map == null) {
      return null;
    }
    ChatroomInfo chatroomInfo = ChatroomInfo();
    chatroomInfo.chatroomId = map['chatroomId'];
    chatroomInfo.desc = map['desc'];
    chatroomInfo.extra = map['extra'];
    chatroomInfo.portrait = map['portrait'];
    chatroomInfo.title = map['title'];
    if (map['status'] != null) {
      chatroomInfo.state = ChatroomState.values[map['state']];
    }
    if (map['memberCount'] != null) {
      chatroomInfo.memberCount = map['memberCount'];
    }
    if (map['createDt'] != null) chatroomInfo.createDt = map['createDt'];
    if (map['updateDt'] != null) chatroomInfo.updateDt = map['updateDt'];

    return chatroomInfo;
  }

  static FileRecord _convertProtoFileRecord(Map<dynamic, dynamic> map) {
    FileRecord record = FileRecord();
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
      return [];
    }
    List<FileRecord> list = [];
    for (var element in datas) {
      list.add(_convertProtoFileRecord(element));
    }
    return list;
  }

  static ChatroomMemberInfo _convertProtoChatroomMemberInfo(
      Map<dynamic, dynamic> map) {
    ChatroomMemberInfo chatroomInfo = ChatroomMemberInfo();
    chatroomInfo.members = map['members'];
    if (map['memberCount'] != null) {
      chatroomInfo.memberCount = map['memberCount'];
    }

    return chatroomInfo;
  }

  static UserOnlineState _convertProtoUserOnlineState(Map<dynamic, dynamic> data) {
    String userId = data['userId'];
    UserOnlineState info = UserOnlineState(userId);
    Map<dynamic, dynamic>? customState = data['customState'];
    if(customState != null) {
      info.customState = CustomState(customState['state']);
      if(customState['text'] != null) {
        info.customState!.text = customState['text'];
      }
    }
    List? clientStates = data['clientStates'];
    if(clientStates != null && clientStates.isNotEmpty) {
      info.clientStates = [];
      for (Map<dynamic, dynamic> clientState in clientStates) {
        ClientState state = ClientState(clientState['platform'], clientState['state'], clientState['lastSeen']);
        info.clientStates!.add(state);
      }
    }
    return info;
  }

  static PCOnlineInfo _convertProtoPcOnlineInfo(Map<dynamic, dynamic> data) {
    PCOnlineInfo info = PCOnlineInfo();
    info.type = data['type'];
    info.isOnline = data['isOnline'];
    info.platform = data['platform'];
    info.clientId = data['clientId'];
    info.clientName = data['clientName'];
    info.timestamp = data['timestamp'];
    return info;
  }

  static List<PCOnlineInfo> _convertProtoOnlineInfos(List<dynamic> datas) {
    List<PCOnlineInfo> list = [];
    for (var element in datas) {
      list.add(_convertProtoPcOnlineInfo(element));
    }
    return list;
  }

  static List<int> _convertMessageStatusList(List<MessageStatus> status) {
    List<int> list = [];
    for (var element in status) {
      list.add(element.index);
    }
    return list;
  }

  @override
  MessageContent decodeMessageContent(MessagePayload payload) {
    MessageContentMeta? meta = _contentMetaMap[payload.contentType];
    MessageContent content;
    if (meta == null) {
      content = UnknownMessageContent();
    } else {
      content = meta.creator();
    }

    try {
      content.decode(payload);
    } catch (e) {
      print(e);
      content = UnknownMessageContent();
      content.decode(payload);
    }
    
    return content;
  }

  static final Map<int, MessageContentMeta> _contentMetaMap = {};

  /// 连接IM服务。调用连接之后才可以调用获取数据接口。连接状态会通过连接状态回调返回。
  /// [host]为IM服务域名或IP，必须im.example.com或114.144.114.144，不带http头和端口。
  @override
  Future<int> connect(String host, String userId, String token) async {
    this.userId = userId;
    int lastConnectTime = await methodChannel.invokeMethod('connect', {'host':host, 'userId':userId, 'token':token});
    return lastConnectTime;
  }

  ///断开IM服务连接。
  /// * disablePush 是否继续接受推送。
  /// * clearSession 是否清除session
  @override
  Future<void> disconnect(
      {bool disablePush = false, bool clearSession = false}) async {
    await methodChannel.invokeMethod('disconnect', {'disablePush':disablePush, 'clearSession':clearSession});
  }

  ///获取会话列表
  @override
  Future<List<ConversationInfo>> getConversationInfos(
      List<ConversationType> types, List<int> lines) async {
    List<int> itypes = [];
    for (var element in types) {
      itypes.add(element.index);
    }
    if (lines.isEmpty) {
      lines = [0];
    }

    List<dynamic>? datas = await methodChannel.invokeMethod(
        'getConversationInfos', {'types': itypes, 'lines': lines});
    List<ConversationInfo> infos = _convertProtoConversationInfos(datas);
    return infos;
  }

  ///获取会话信息
  @override
  Future<ConversationInfo> getConversationInfo(
      Conversation conversation) async {
    var args = _convertConversation(conversation);
    Map<dynamic, dynamic> datas =
    await methodChannel.invokeMethod("getConversationInfo", args);
    ConversationInfo info = _convertProtoConversationInfo(datas);
    return info;
  }

  ///搜索会话信息
  @override
  Future<List<ConversationSearchInfo>> searchConversation(
      String keyword, List<ConversationType> types, List<int> lines) async {
    List<int> itypes = [];
    for (var element in types) {
      itypes.add(element.index);
    }
    if (lines.isEmpty) {
      lines = [0];
    }

    List<dynamic> datas = await methodChannel.invokeMethod('searchConversation',
        {'keyword': keyword, 'types': itypes, 'lines': lines});
    List<ConversationSearchInfo> infos = _convertProtoConversationSearchInfos(datas, keyword);
    return infos;
  }

  ///移除会话
  @override
  Future<void> removeConversation(
      Conversation conversation, bool clearMessage) async {
    Map<String, dynamic> args = {};
    args['conversation'] = _convertConversation(conversation);
    args['clearMessage'] = clearMessage;
    await methodChannel.invokeMethod("removeConversation", args);
  }

  ///设置/取消会话置顶
  @override
  void setConversationTop(
      Conversation conversation,
      int isTop,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = () {
      successCallback();
      _eventBus.fire(ConversationTopUpdatedEvent(conversation, isTop));
    };
    _errorCallbackMap[requestId] = errorCallback;

    methodChannel.invokeMethod("setConversationTop", {
      "requestId": requestId,
      'conversation': _convertConversation(conversation),
      "isTop": isTop
    });
  }

  ///设置/取消会话免到扰
  @override
  void setConversationSilent(
      Conversation conversation,
      bool isSilent,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = () {
      successCallback();
      _eventBus.fire(ConversationSilentUpdatedEvent(conversation, isSilent));
    };
    _errorCallbackMap[requestId] = errorCallback;

    methodChannel.invokeMethod("setConversationSilent", {
      "requestId": requestId,
      'conversation': _convertConversation(conversation),
      "isSilent": isSilent
    });
  }

  ///保存草稿
  @override
  Future<void> setConversationDraft(
      Conversation conversation, String draft) async {
    Map<String, dynamic> args = {};
    args['conversation'] = _convertConversation(conversation);
    args['draft'] = draft;
    await methodChannel.invokeMethod("setConversationDraft", args);
    _eventBus.fire(ConversationDraftUpdatedEvent(conversation, draft));
  }

  ///设置会话时间戳
  @override
  Future<void> setConversationTimestamp(
      Conversation conversation, int timestamp) async {
    Map<String, dynamic> args = {};
    args['conversation'] = _convertConversation(conversation);
    args['timestamp'] = timestamp;
    await methodChannel.invokeMethod("setConversationTimestamp", args);
  }

  ///设置会话中第一个未读消息ID
  @override
  Future<int> getFirstUnreadMessageId(Conversation conversation) async {
    int msgId = await methodChannel.invokeMethod("getFirstUnreadMessageId",
        {"conversation": _convertConversation(conversation)});
    return msgId;
  }

  ///设置会话未读状态
  @override
  Future<UnreadCount> getConversationUnreadCount(
      Conversation conversation) async {
    Map<dynamic, dynamic> datas = await methodChannel.invokeMethod(
        'getConversationUnreadCount',
        {'conversation': _convertConversation(conversation)});
    return _convertProtoUnreadCount(datas);
  }

  ///设置某些类型会话未读状态
  @override
  Future<UnreadCount> getConversationsUnreadCount(
      List<ConversationType> types, List<int> lines) async {
    List<int> itypes = [];
    for (var element in types) {
      itypes.add(element.index);
    }
    if (lines.isEmpty) {
      lines = [0];
    }

    Map<dynamic, dynamic> datas = await methodChannel.invokeMethod(
        'getConversationsUnreadCount', {'types': itypes, 'lines': lines});
    return _convertProtoUnreadCount(datas);
  }

  ///清除一个会话的未读状态
  @override
  Future<bool> clearConversationUnreadStatus(
      Conversation conversation) async {
    bool ret = await methodChannel.invokeMethod('clearConversationUnreadStatus',
        {'conversation': _convertConversation(conversation)});
    if (ret) {
      _eventBus.fire(ClearConversationUnreadEvent(conversation));
    }
    return ret;
  }

  ///清除某些类型会话的未读状态
  @override
  Future<bool> clearConversationsUnreadStatus(
      List<ConversationType> types, List<int> lines) async {
    List<int> itypes = [];
    for (var element in types) {
      itypes.add(element.index);
    }
    if (lines.isEmpty) {
      lines = [0];
    }

    bool ret = await methodChannel.invokeMethod(
        'clearConversationsUnreadStatus', {'types': itypes, 'lines': lines});
    if (ret) {
      _eventBus.fire(ClearConversationsUnreadEvent(types, lines));
    }
    return ret;
  }

  ///清除一个会话的未读状态
  @override
  Future<bool> clearConversationUnreadStatusBeforeMessage(
      Conversation conversation, int messageId) async {
    bool ret = await methodChannel.invokeMethod('clearConversationUnreadStatus',
        {'conversation': _convertConversation(conversation), 'messageId':messageId});
    if (ret) {
      _eventBus.fire(ClearConversationUnreadEvent(conversation));
    }
    return ret;
  }


  @override
  Future<bool> clearMessageUnreadStatus(int messageId) async {
    return await methodChannel.invokeMethod('clearMessageUnreadStatus', {"messageId":messageId});
  }

  @override
  Future<bool> markAsUnRead(Conversation conversation, bool sync) async {
    return await methodChannel.invokeMethod('markAsUnRead', {'conversation': _convertConversation(conversation), "sync":sync});
  }
  
  ///获取会话的已读状态
  @override
  Future<Map<String, int>> getConversationRead(
      Conversation conversation) async {
    Map<dynamic, dynamic> datas = await methodChannel.invokeMethod(
        'getConversationRead',
        {'conversation': _convertConversation(conversation)});
    Map<String, int> map = {};
    datas.forEach((key, value) {
      map.putIfAbsent(key, () => value);
    });
    return map;
  }

  ///获取会话的消息送达状态
  @override
  Future<Map<String, int>> getMessageDelivery(
      Conversation conversation) async {
    Map<dynamic, dynamic> datas = await methodChannel.invokeMethod(
        'getMessageDelivery',
        {'conversation': _convertConversation(conversation)});
    Map<String, int> map = {};
    datas.forEach((key, value) {
      map.putIfAbsent(key, () => value);
    });
    return map;
  }

  ///获取会话的消息列表
  @override
  Future<List<Message>> getMessages(
      Conversation conversation, int fromIndex, int count,
      {List<int>? contentTypes, String? withUser}) async {
    Map<String, dynamic> args = {
      "conversation": _convertConversation(conversation),
      "fromIndex": fromIndex,
      "count": count
    };
    if (contentTypes != null) {
      args["contentTypes"] = contentTypes;
    }
    if (withUser != null) {
      args["withUser"] = withUser;
    }

    List<dynamic> datas = await methodChannel.invokeMethod("getMessages", args);
    return _convertProtoMessages(datas);
  }

  ///根据消息状态获取会话的消息列表
  @override
  Future<List<Message>> getMessagesByStatus(Conversation conversation,
      int fromIndex, int count, List<MessageStatus>? messageStatus,
      {String? withUser}) async {
    Map<String, dynamic> args = {
      "conversation": _convertConversation(conversation),
      "fromIndex": fromIndex,
      "count": count
    };

    if(messageStatus != null) {
      args["messageStatus"] = _convertMessageStatusList(messageStatus);
    }

    if (withUser != null) {
      args["withUser"] = withUser;
    }

    List<dynamic> datas =
    await methodChannel.invokeMethod("getMessagesByStatus", args);
    return _convertProtoMessages(datas);
  }

  ///获取某些类型会话的消息列表
  @override
  Future<List<Message>> getConversationsMessages(
      List<ConversationType> types, List<int> lines, int fromIndex, int count,
      {List<int>? contentTypes, String? withUser}) async {
    List<int> itypes = [];
    for (var element in types) {
      itypes.add(element.index);
    }
    if (lines.isEmpty) {
      lines = [0];
    }

    Map<String, dynamic> args = {
      "types": itypes,
      "lines": lines,
      "fromIndex": fromIndex,
      "count": count
    };
    if (contentTypes != null) {
      args["contentTypes"] = contentTypes;
    }
    if (withUser != null) {
      args["withUser"] = withUser;
    }

    List<dynamic> datas =
    await methodChannel.invokeMethod("getConversationsMessages", args);
    return _convertProtoMessages(datas);
  }

  ///根据消息状态获取某些类型会话的消息列表
  @override
  Future<List<Message>> getConversationsMessageByStatus(
      List<ConversationType> types,
      List<int> lines,
      int fromIndex,
      int count,
      List<MessageStatus> messageStatus,
      {String? withUser}) async {
    List<int> itypes = [];
    for (var element in types) {
      itypes.add(element.index);
    }
    if (lines.isEmpty) {
      lines = [0];
    }

    Map<String, dynamic> args = {
      "types": itypes,
      "lines": lines,
      "fromIndex": fromIndex,
      "count": count,
      "messageStatus": _convertMessageStatusList(messageStatus)
    };

    if (withUser != null) {
      args["withUser"] = withUser;
    }

    List<dynamic> datas =
    await methodChannel.invokeMethod("getConversationsMessageByStatus", args);
    return _convertProtoMessages(datas);
  }

  ///获取远端历史消息
  @override
  void getRemoteMessages(
      Conversation conversation,
      int beforeMessageUid,
      int count,
      OperationSuccessMessagesCallback successCallback,
          OperationFailureCallback errorCallback, {List<int>? contentTypes}) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;

    Map<String, dynamic> args = {
      "requestId": requestId,
      "conversation": _convertConversation(conversation),
      "beforeMessageUid": beforeMessageUid,
      "count": count
    };

    if(contentTypes != null && contentTypes.isNotEmpty) {
      args["contentTypes"] = contentTypes;
    }

    methodChannel.invokeMethod("getRemoteMessages", args);
  }

  @override
  void getRemoteMessage(
      int messageUid,
      OperationSuccessMessageCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;

    methodChannel.invokeMethod("getRemoteMessage", {"messageUid":messageUid});
  }

  ///根据消息Id获取消息
  @override
  Future<Message?> getMessage(int messageId) async {
    Map<dynamic, dynamic> datas = await methodChannel
        .invokeMethod("getMessage", {"messageId": messageId});
    return _convertProtoMessage(datas);
  }

  ///根据消息Uid获取消息
  @override
  Future<Message?> getMessageByUid(int messageUid) async {
    Map<dynamic, dynamic> datas = await methodChannel
        .invokeMethod("getMessageByUid", {"messageUid": messageUid});
    return _convertProtoMessage(datas);
  }

  ///搜索某个会话内消息
  @override
  Future<List<Message>> searchMessages(Conversation conversation,
      String keyword, bool order, int limit, int offset) async {
    List<dynamic> datas = await methodChannel.invokeMethod("searchMessages", {
      "conversation": _convertConversation(conversation),
      "keyword": keyword,
      "order": order,
      "limit": limit,
      "offset": offset
    });
    return _convertProtoMessages(datas);
  }

  ///搜索某些类会话内消息
  @override
  Future<List<Message>> searchConversationsMessages(
      List<ConversationType> types,
      List<int> lines,
      String keyword,
      int fromIndex,
      int count, {
        List<int>? contentTypes,
      }) async {
    List<int> itypes = [];
    for (var element in types) {
      itypes.add(element.index);
    }
    if (lines.isEmpty) {
      lines = [0];
    }

    var args = {
      "types": itypes,
      "lines": lines,
      "keyword": keyword,
      "fromIndex": fromIndex,
      "count": count
    };
    if (contentTypes != null) {
      args['contentTypes'] = contentTypes;
    }

    List<dynamic> datas =
    await methodChannel.invokeMethod("searchConversationsMessages", args);
    return _convertProtoMessages(datas);
  }

  ///发送消息
  Future<Message> sendMessage(
      Conversation conversation, MessageContent content,
      {List<String>? toUsers,
        int expireDuration = 0,
        required SendMessageSuccessCallback successCallback,
        required OperationFailureCallback errorCallback}) async {
    return sendMediaMessage(conversation, content,
        toUsers: toUsers,
        expireDuration: expireDuration,
        successCallback: successCallback,
        errorCallback: errorCallback);
  }

  ///发送媒体类型消息
  @override
  Future<Message> sendMediaMessage(
      Conversation conversation, MessageContent content,
      {List<String>? toUsers,
        int expireDuration = 0,
        required SendMessageSuccessCallback successCallback,
        required OperationFailureCallback errorCallback,
        SendMediaMessageProgressCallback? progressCallback,
        SendMediaMessageUploadedCallback? uploadedCallback}) async {
    int requestId = _requestId++;
    _sendMessageSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    if (progressCallback != null) {
      _sendMediaMessageProgressCallbackMap[requestId] = progressCallback;
    }
    if (uploadedCallback != null) {
      _sendMediaMessageUploadedCallbackMap[requestId] = uploadedCallback;
    }

    Map<String, dynamic> convMap = _convertConversation(conversation);
    Map<String, dynamic> contMap = _convertMessageContent(content);
    Map<String, dynamic> args = {
      "requestId": requestId,
      "conversation": convMap,
      "content": contMap
    };

    if (expireDuration > 0) args['expireDuration'] = expireDuration;
    if (toUsers != null && toUsers.isNotEmpty) args['toUsers'] = toUsers;

    Map<dynamic, dynamic> fm = await methodChannel.invokeMethod('sendMessage', args);

    Message message = _convertProtoMessage(fm)!;
    if(message.messageId == null || message.messageId! > 0) {
      _sendingMessages[message.messageId!] = message;
      _eventBus.fire(SendMessageStartEvent(message.messageId!));
    }

    return message;
  }

  ///发送已保存消息
  @override
  Future<bool> sendSavedMessage(int messageId,
      {int expireDuration = 0,
        required SendMessageSuccessCallback successCallback,
        required OperationFailureCallback errorCallback}) async {
    int requestId = _requestId++;
    _sendMessageSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;

    return await methodChannel.invokeMethod("sendSavedMessage", {
      "requestId": requestId,
      "messageId": messageId,
      "expireDuration": expireDuration
    });
  }

  @override
  Future<bool> cancelSendingMessage(int messageId) async {
    return await methodChannel.invokeMethod("cancelSendingMessage", {"messageId": messageId});
  }

  ///撤回消息
  @override
  void recallMessage(
      int messageUid,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod('recallMessage',
        {"requestId": requestId, "messageUid": messageUid});
  }

  ///上传媒体数据
  @override
  void uploadMedia(
      String fileName,
      Uint8List mediaData,
      int mediaType,
      OperationSuccessStringCallback successCallback,
      SendMediaMessageProgressCallback progressCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    _sendMediaMessageProgressCallbackMap[requestId] = progressCallback;
    methodChannel.invokeMethod("uploadMedia", {
      "requestId": requestId,
      "fileName": fileName,
      "mediaData": mediaData,
      "mediaType": mediaType
    });
  }

  @override
  void getMediaUploadUrl(
      String fileName,
      int mediaType,
      String contentType,
      GetUploadUrlSuccessCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;

    methodChannel.invokeMethod("getUploadUrl", {
      "requestId": requestId,
      "fileName": fileName,
      "contentType": contentType,
      "mediaType": mediaType
    });
  }

  @override
  Future<bool> isSupportBigFilesUpload() async {
    return await methodChannel.invokeMethod("isSupportBigFilesUpload");
  }

  ///删除消息
  @override
  Future<bool> deleteMessage(int messageId) async {
    Message? message = await getMessage(messageId);
    if(message != null) {
      await methodChannel
          .invokeMethod("deleteMessage", {"messageId": messageId});
      _eventBus.fire(DeleteMessageEvent(message!.messageUid!));
    }
    return message != null;
  }

  @override
  Future<bool> batchDeleteMessages(List<int> messageUids) async {
    return await methodChannel.invokeMethod("batchDeleteMessages", {"messageUids":messageUids});
  }

  @override
  void deleteRemoteMessage(
      int messageUid,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod('deleteRemoteMessage',
        {"requestId": requestId, "messageUid": messageUid});
  }

  ///清空会话内消息
  @override
  Future<bool> clearMessages(Conversation conversation,
      {int before = 0}) async {
    bool ret = await methodChannel.invokeMethod("clearMessages", {
      "conversation": _convertConversation(conversation),
      "before": before
    });

    _eventBus.fire(ClearMessagesEvent(conversation));
    return ret;
  }

  @override
  void clearRemoteConversationMessage(Conversation conversation,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;

    methodChannel.invokeMethod("clearRemoteConversationMessage", {
      "requestId": requestId,
      "conversation": _convertConversation(conversation)
    });
  }

  ///设置消息已经播放
  @override
  Future<void> setMediaMessagePlayed(int messageId) async {
    await methodChannel.invokeMethod(
        "setMediaMessagePlayed", {"messageId": messageId});
  }

  @override
  Future<bool> setMessageLocalExtra(int messageId, String localExtra) async {
    return await methodChannel.invokeMethod(
        "setMessageLocalExtra", {"messageId": messageId, "localExtra":localExtra});
  }

  ///插入消息
  @override
  Future<Message> insertMessage(Conversation conversation, String sender,
      MessageContent content, int status, int serverTime, {List<String>? toUsers}) async {
    Map<dynamic, dynamic> datas = await methodChannel.invokeMethod("insertMessage", {
      "conversation": _convertConversation(conversation),
      "content": _convertMessageContent(content),
      "status": status,
      "serverTime": serverTime
    });
    if (toUsers != null && toUsers.isNotEmpty) datas['toUsers'] = toUsers;
    return _convertProtoMessage(datas)!;
  }

  ///更新消息内容
  @override
  Future<void> updateMessage(
      int messageId, MessageContent content) async {
    await methodChannel.invokeMethod("updateMessage", {
      "messageId": messageId,
      "content": _convertMessageContent(content)
    });
  }

  @override
  void updateRemoteMessageContent(
      int messageUid, MessageContent content, bool distribute, bool updateLocal,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;

    methodChannel.invokeMethod("updateRemoteMessageContent", {
      "requestId": requestId,
      "messageUid": messageUid,
      "content": _convertMessageContent(content),
      "distribute": distribute,
      "updateLocal":updateLocal
    });
  }

  ///更新消息状态
  @override
  Future<void> updateMessageStatus(
      int messageId, MessageStatus status) async {
    await methodChannel.invokeMethod("updateMessageStatus",
        {"messageId": messageId, "status": status.index});
  }

  ///获取会话内消息数量
  @override
  Future<int> getMessageCount(Conversation conversation) async {
    return await methodChannel.invokeMethod("getMessageCount",
        {'conversation': _convertConversation(conversation)});
  }

  ///获取用户信息
  @override
  Future<UserInfo?> getUserInfo(String userId,
      {String? groupId, bool refresh = false}) async {
    var args = {"userId": userId, "refresh": refresh};
    if (groupId != null) {
      args['groupId'] = groupId;
    }

    Map<dynamic, dynamic>? datas =
    await methodChannel.invokeMethod("getUserInfo", args);
    return _convertProtoUserInfo(datas);
  }

  ///批量获取用户信息
  @override
  Future<List<UserInfo>> getUserInfos(List<String> userIds,
      {String? groupId}) async {
    var args = {};
    if (groupId != null) {
      args = {"userIds": userIds, "groupId": groupId};
    } else {
      args = {"userIds": userIds};
    }
    List<dynamic>? datas = await methodChannel.invokeMethod("getUserInfos", args);
    return _convertProtoUserInfos(datas);
  }

  ///搜索用户
  @override
  void searchUser(
      String keyword,
      int searchType,
      int page,
      OperationSuccessUserInfosCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;

    methodChannel.invokeMethod("searchUser", {
      "requestId": requestId,
      "keyword": keyword,
      "searchType": searchType,
      "page": page
    });
  }

  ///异步获取用户信息
  @override
  void getUserInfoAsync(
      String userId,
      OperationSuccessUserInfoCallback successCallback,
      OperationFailureCallback errorCallback,
      {bool refresh = false}) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod(
        "getUserInfoAsync", {"requestId": requestId, "userId": userId});
  }

  ///是否是好友
  @override
  Future<bool> isMyFriend(String userId) async {
    return await methodChannel.invokeMethod("isMyFriend", {"userId": userId});
  }

  ///获取好友列表
  @override
  Future<List<String>> getMyFriendList({bool refresh = false}) async {
    List<dynamic>? datas =
    await methodChannel.invokeMethod("getMyFriendList", {"refresh": refresh});
    return Tools.convertDynamicList(datas);
  }

  ///搜索好友
  @override
  Future<List<UserInfo>> searchFriends(String keyword) async {
    List<dynamic> datas =
    await methodChannel.invokeMethod("searchFriends", {"keyword": keyword});
    return _convertProtoUserInfos(datas);
  }

  @override
  Future<List<Friend>> getFriends(bool refresh) async {
    List<dynamic> datas =
    await methodChannel.invokeMethod("getFriends", {"refresh": refresh});
    return _convertProtoFriends(datas);
  }

  ///搜索群组
  @override
  Future<List<GroupSearchInfo>> searchGroups(String keyword) async {
    List<dynamic> datas =
    await methodChannel.invokeMethod("searchGroups", {"keyword": keyword});
    return _convertProtoGroupSearchInfos(datas);
  }

  ///获取收到的好友请求列表
  @override
  Future<List<FriendRequest>> getIncommingFriendRequest() async {
    List<dynamic> datas =
    await methodChannel.invokeMethod("getIncommingFriendRequest");
    return _convertProtoFriendRequests(datas);
  }

  ///获取发出去的好友请求列表
  @override
  Future<List<FriendRequest>> getOutgoingFriendRequest() async {
    List<dynamic> datas =
    await methodChannel.invokeMethod("getOutgoingFriendRequest");
    return _convertProtoFriendRequests(datas);
  }

  ///获取某个用户相关的好友请求
  @override
  Future<FriendRequest?> getFriendRequest(
      String userId, FriendRequestDirection direction) async {
    Map<dynamic, dynamic>? data = await methodChannel.invokeMethod(
        "getFriendRequest", {"userId": userId, "direction": direction.index});
    return _convertProtoFriendRequest(data);
  }

  ///同步远程好友请求信息
  @override
  Future<void> loadFriendRequestFromRemote() async {
    await methodChannel.invokeMethod("loadFriendRequestFromRemote");
  }

  ///获取未读好友请求数
  @override
  Future<int> getUnreadFriendRequestStatus() async {
    return await methodChannel.invokeMethod("getUnreadFriendRequestStatus");
  }

  ///清除未读好友请求计数
  @override
  Future<bool> clearUnreadFriendRequestStatus() async {
    bool ret = await methodChannel.invokeMethod("clearUnreadFriendRequestStatus");
    if (ret) {
      _eventBus.fire(ClearFriendRequestUnreadEvent());
    }
    return ret;
  }

  @override
  Future<bool> clearFriendRequest(int direction, beforeTime) async {
    return await methodChannel.invokeMethod("clearFriendRequest", {"direction":direction, "beforeTime":beforeTime});
  }

  ///删除好友
  @override
  void deleteFriend(
      String userId,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod(
        "deleteFriend", {"requestId": requestId, "userId": userId});
  }

  ///发送好友请求
  @override
  void sendFriendRequest(
      String userId,
      String reason,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod("sendFriendRequest",
        {"requestId": requestId, "userId": userId, "reason": reason});
  }

  ///处理好友请求
  @override
  void handleFriendRequest(
      String userId,
      bool accept,
      String extra,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod("handleFriendRequest", {
      "requestId": requestId,
      "userId": userId,
      "accept": accept,
      "extra": extra
    });
  }

  ///获取好友备注名
  @override
  Future<String?> getFriendAlias(String userId) async {
    return await methodChannel.invokeMethod("getFriendAlias", {"userId": userId});
  }

  ///设置好友备注名
  @override
  void setFriendAlias(
      String friendId,
      String? alias,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod("setFriendAlias",
        {"requestId": requestId, "friendId": friendId, "alias": alias??""});
  }

  ///获取好友extra信息
  @override
  Future<String> getFriendExtra(String userId) async {
    String data =
    await methodChannel.invokeMethod("getFriendExtra", {"userId": userId});
    return data;
  }

  ///是否是黑名单用户
  @override
  Future<bool> isBlackListed(String userId) async {
    bool data =
    await methodChannel.invokeMethod("isBlackListed", {"userId": userId});
    return data;
  }

  ///获取黑名单列表
  @override
  Future<List<String>> getBlackList({bool refresh = false}) async {
    List<dynamic>? datas =
    await methodChannel.invokeMethod("getBlackList", {"refresh": refresh});
    return Tools.convertDynamicList(datas);
  }

  ///设置/取消用户黑名单
  @override
  void setBlackList(
      String userId,
      bool isBlackListed,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod("setBlackList", {
      "requestId": requestId,
      "userId": userId,
      "isBlackListed": isBlackListed
    });
  }

  ///获取群成员列表
  @override
  Future<List<GroupMember>> getGroupMembers(String groupId,
      {bool refresh = false}) async {
    List<dynamic> datas = await methodChannel.invokeMethod(
        "getGroupMembers", {"groupId": groupId, "refresh": refresh});
    return _convertProtoGroupMembers(datas);
  }

  @override
  Future<List<GroupMember>> getGroupMembersByCount(String groupId, int count) async {
    List<dynamic> datas = await methodChannel.invokeMethod(
        "getGroupMembersByCount", {"groupId": groupId, "count": count});
    return _convertProtoGroupMembers(datas);
  }

  ///根据群成员类型获取群成员列表
  @override
  Future<List<GroupMember>> getGroupMembersByTypes(
      String groupId, GroupMemberType memberType) async {
    List<dynamic> datas = await methodChannel.invokeMethod("getGroupMembersByTypes",
        {"groupId": groupId, "memberType": memberType.index});
    return _convertProtoGroupMembers(datas);
  }

  ///异步获取群成员列表
  @override
  void getGroupMembersAsync(String groupId,
      {bool refresh = false,
        required OperationSuccessGroupMembersCallback successCallback,
        required OperationFailureCallback errorCallback}) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod("getGroupMembersAsync",
        {"requestId": requestId, "groupId": groupId, "refresh": refresh});
  }

  ///获取群信息
  @override
  Future<GroupInfo?> getGroupInfo(String groupId,
      {bool refresh = false}) async {
    Map<dynamic, dynamic>? datas = await methodChannel
        .invokeMethod("getGroupInfo", {"groupId": groupId, "refresh": refresh});
    return _convertProtoGroupInfo(datas);
  }

  ///异步获取群信息
  @override
  void getGroupInfoAsync(String groupId,
      {bool refresh = false,
        required OperationSuccessGroupInfoCallback successCallback,
        required OperationFailureCallback errorCallback}) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod("getGroupInfoAsync",
        {"requestId": requestId, "groupId": groupId, "refresh": refresh});
  }

  ///获取单个群成员信息
  @override
  Future<GroupMember?> getGroupMember(
      String groupId, String memberId) async {
    Map<dynamic, dynamic> datas = await methodChannel.invokeMethod(
        "getGroupMember", {"groupId": groupId, "memberId": memberId});
    return _convertProtoGroupMember(datas);
  }

  ///创建群组，groupId可以为空。
  @override
  void createGroup(
      String? groupId,
      String? groupName,
      String? groupPortrait,
      int type,
      List<String> members,
      OperationSuccessStringCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;

    Map<String, dynamic> args = {};
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
      args['notifyContent'] = _convertMessageContent(notifyContent);
    }

    methodChannel.invokeMethod("createGroup", args);
  }

  ///添加群成员
  @override
  void addGroupMembers(
      String groupId,
      List<String> members,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;

    Map<String, dynamic> args = {
      "requestId": requestId,
      "groupId": groupId,
      "groupMembers": members
    };

    args['notifyLines'] = notifyLines??[0];
    if (notifyContent != null) {
      args['notifyContent'] = _convertMessageContent(notifyContent);
    }

    methodChannel.invokeMethod("addGroupMembers", args);
  }

  ///移除群成员
  @override
  void kickoffGroupMembers(
      String groupId,
      List<String> members,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    Map<String, dynamic> args = {
      "requestId": requestId,
      "groupId": groupId,
      "groupMembers": members
    };

    args['notifyLines'] = notifyLines??[0];
    if (notifyContent != null) {
      args['notifyContent'] = _convertMessageContent(notifyContent);
    }

    methodChannel.invokeMethod("kickoffGroupMembers", args);
  }

  ///退出群组
  @override
  void quitGroup(
      String groupId,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    Map<String, dynamic> args = {
      "requestId": requestId,
      "groupId": groupId
    };

    args['notifyLines'] = notifyLines??[0];
    if (notifyContent != null) {
      args['notifyContent'] = _convertMessageContent(notifyContent);
    }

    methodChannel.invokeMethod("quitGroup", args);
  }

  ///解散群组
  @override
  void dismissGroup(
      String groupId,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    Map<String, dynamic> args = {
      "requestId": requestId,
      "groupId": groupId
    };

    args['notifyLines'] = notifyLines??[0];
    if (notifyContent != null) {
      args['notifyContent'] = _convertMessageContent(notifyContent);
    }

    methodChannel.invokeMethod("dismissGroup", args);
  }

  ///修改群组信息
  @override
  void modifyGroupInfo(
      String groupId,
      ModifyGroupInfoType modifyType,
      String newValue,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;

    Map<String, dynamic> args = {
      "requestId": requestId,
      "groupId": groupId,
      "modifyType": modifyType.index,
      "value": newValue
    };
    
    args['notifyLines'] = notifyLines??[0];
    
    if (notifyContent != null) {
      args['notifyContent'] = _convertMessageContent(notifyContent);
    }

    methodChannel.invokeMethod("modifyGroupInfo", args);
  }

  ///修改自己的群名片
  @override
  void modifyGroupAlias(
      String groupId,
      String newAlias,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    Map<String, dynamic> args = {
      "requestId": requestId,
      "groupId": groupId,
      "newAlias": newAlias
    };

    args['notifyLines'] = notifyLines??[0];
    if (notifyContent != null) {
      args['notifyContent'] = _convertMessageContent(notifyContent);
    }

    methodChannel.invokeMethod("modifyGroupAlias", args);
  }

  ///修改群成员的群名片
  @override
  void modifyGroupMemberAlias(
      String groupId,
      String memberId,
      String newAlias,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    Map<String, dynamic> args = {
      "requestId": requestId,
      "groupId": groupId,
      "newAlias": newAlias
    };

    args['notifyLines'] = notifyLines??[0];
    if (notifyContent != null) {
      args['notifyContent'] = _convertMessageContent(notifyContent);
    }

    methodChannel.invokeMethod("modifyGroupMemberAlias", args);
  }

  ///转移群组
  @override
  void transferGroup(
      String groupId,
      String newOwner,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    Map<String, dynamic> args = {
      "requestId": requestId,
      "groupId": groupId,
      "newOwner": newOwner
    };

    args['notifyLines'] = notifyLines??[0];
    if (notifyContent != null) {
      args['notifyContent'] = _convertMessageContent(notifyContent);
    }
    methodChannel.invokeMethod("transferGroup", args);
  }

  ///设置/取消群管理员
  @override
  void setGroupManager(
      String groupId,
      bool isSet,
      List<String> memberIds,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    Map<String, dynamic> args = {
      "requestId": requestId,
      "groupId": groupId,
      "isSet": isSet,
      "memberIds": memberIds
    };

    args['notifyLines'] = notifyLines??[0];
    if (notifyContent != null) {
      args['notifyContent'] = _convertMessageContent(notifyContent);
    }

    methodChannel.invokeMethod("setGroupManager", args);
  }

  ///禁言/取消禁言群成员
  @override
  void muteGroupMember(
      String groupId,
      bool isSet,
      List<String> memberIds,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    Map<String, dynamic> args = {
      "requestId": requestId,
      "groupId": groupId,
      "isSet": isSet,
      "memberIds": memberIds
    };

    args['notifyLines'] = notifyLines??[0];
    if (notifyContent != null) {
      args['notifyContent'] = _convertMessageContent(notifyContent);
    }

    methodChannel.invokeMethod("muteGroupMember", args);
  }

  ///设置/取消群白名单
  @override
  void allowGroupMember(
      String groupId,
      bool isSet,
      List<String> memberIds,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback,
      {List<int>? notifyLines,
        MessageContent? notifyContent}) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    Map<String, dynamic> args = {
      "requestId": requestId,
      "groupId": groupId,
      "isSet": isSet,
      "memberIds": memberIds
    };

    args['notifyLines'] = notifyLines??[0];
    if (notifyContent != null) {
      args['notifyContent'] = _convertMessageContent(notifyContent);
    }

    methodChannel.invokeMethod("allowGroupMember", args);
  }

  @override
  Future<String> getGroupRemark(String groupId) async {
    return await methodChannel.invokeMethod("getGroupRemark", {"groupId":groupId});
  }

  @override
  void setGroupRemark(String groupId, String remark,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod("setGroupRemark", {
      "requestId": requestId,
      "groupId": groupId,
      "remark": remark
    });
  }

  ///获取收藏群组列表
  @override
  Future<List<String>?> getFavGroups() async {
    return Tools.convertDynamicList(await methodChannel.invokeMethod("getFavGroups"));
  }

  ///是否收藏群组
  @override
  Future<bool> isFavGroup(String groupId) async {
    return await methodChannel.invokeMethod("isFavGroup", {"groupId": groupId});
  }

  ///设置/取消收藏群组
  @override
  void setFavGroup(
      String groupId,
      bool isFav,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod("setFavGroup",
        {"requestId": requestId, "groupId": groupId, "isFav": isFav});
  }

  ///获取用户设置
  @override
  Future<String> getUserSetting(int scope, String key) async {
    return await methodChannel
        .invokeMethod("getUserSetting", {"scope": scope, "key": key});
  }

  ///获取某类用户设置
  @override
  Future<Map<String, String>> getUserSettings(int scope) async {
    return await methodChannel.invokeMethod("getUserSettings", {"scope": scope});
  }

  ///设置用户设置
  @override
  void setUserSetting(
      int scope,
      String key,
      String value,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod("setUserSetting",
        {"requestId": requestId, "scope": scope, "key": key, "value": value});
  }

  ///修改当前用户信息
  @override
  void modifyMyInfo(
      Map<ModifyMyInfoType, String> values,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;

    Map<int, String> v = {};
    values.forEach((key, value) {
      v.putIfAbsent(key.index, () => value);
    });

    methodChannel
        .invokeMethod("modifyMyInfo", {"requestId": requestId, "values": v});
  }

  ///是否全局静音
  @override
  Future<bool> isGlobalSilent() async {
    return await methodChannel.invokeMethod("isGlobalSilent");
  }

  ///设置/取消全局静音
  @override
  void setGlobalSilent(
      bool isSilent,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod(
        "setGlobalSilent", {"requestId": requestId, "isSilent": isSilent});
  }

  @override
  Future<bool> isVoipNotificationSilent() async {
    return await methodChannel.invokeMethod("isVoipNotificationSilent");
  }

  @override
  void setVoipNotificationSilent(
      bool isSilent,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod(
        "setVoipNotificationSilent", {"requestId": requestId, "isSilent": isSilent});
  }

  @override
  Future<bool> isEnableSyncDraft() async {
    return await methodChannel.invokeMethod("isEnableSyncDraft");
  }

  @override
  void setEnableSyncDraft(
      bool enable,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod(
        "setEnableSyncDraft", {"requestId": requestId, "enable": enable});
  }

  ///获取免打扰时间段
  @override
  void getNoDisturbingTimes(
      OperationSuccessIntPairCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel
        .invokeMethod("getNoDisturbingTimes", {"requestId": requestId});
  }

  ///设置免打扰时间段
  @override
  void setNoDisturbingTimes(
      int startMins,
      int endMins,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod("setNoDisturbingTimes",
        {"requestId": requestId, "startMins": startMins, "endMins": endMins});
  }

  ///取消免打扰时间段
  @override
  void clearNoDisturbingTimes(
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel
        .invokeMethod("clearNoDisturbingTimes", {"requestId": requestId});
  }

  @override
  Future<bool> isNoDisturbing() async {
    return await methodChannel.invokeMethod("isNoDisturbing");
  }

  ///是否推送隐藏详情
  @override
  Future<bool> isHiddenNotificationDetail() async {
    return await methodChannel.invokeMethod("isHiddenNotificationDetail");
  }

  ///设置推送隐藏详情
  @override
  void setHiddenNotificationDetail(
      bool isHidden,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod("setHiddenNotificationDetail",
        {"requestId": requestId, "isHidden": isHidden});
  }

  ///是否群组隐藏用户名
  @override
  Future<bool> isHiddenGroupMemberName(String groupId) async {
    return await methodChannel
        .invokeMethod("isHiddenGroupMemberName", {"groupId": groupId});
  }

  ///设置是否群组隐藏用户名
  @override
  void setHiddenGroupMemberName(
      String groupId,
      bool isHidden,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod("setHiddenGroupMemberName",
        {"requestId": requestId, "groupId":groupId, "isHidden": isHidden});
  }


  @override
  void getMyGroups(
      OperationSuccessStringListCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod("getMyGroups",
        {"requestId": requestId});
  }

  @override
  void getCommonGroups(String userId,
      OperationSuccessStringListCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod("getCommonGroups",
        {"requestId": requestId, "userId": userId});
  }

  ///当前用户是否启用回执功能
  @override
  Future<bool> isUserEnableReceipt() async {
    return await methodChannel.invokeMethod("isUserEnableReceipt");
  }

  ///设置当前用户是否启用回执功能，仅当服务支持回执功能有效
  @override
  void setUserEnableReceipt(
      bool isEnable,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod(
        "setUserEnableReceipt", {"requestId": requestId, "isEnable": isEnable});
  }

  ///获取收藏好友列表
  @override
  Future<List<String>?> getFavUsers() async {
    return Tools.convertDynamicList(await methodChannel.invokeMethod("getFavUsers"));
  }

  ///是否是收藏用户
  @override
  Future<bool> isFavUser(String userId) async {
    return await methodChannel.invokeMethod("isFavUser", {"userId": userId});
  }

  ///设置收藏用户
  @override
  void setFavUser(
      String userId,
      bool isFav,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod("setFavUser",
        {"requestId": requestId, "userId": userId, "isFav": isFav});
  }

  ///加入聊天室
  @override
  void joinChatroom(
      String chatroomId,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod(
        "joinChatroom", {"requestId": requestId, "chatroomId": chatroomId});
  }

  ///退出聊天室
  @override
  void quitChatroom(
      String chatroomId,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod(
        "quitChatroom", {"requestId": requestId, "chatroomId": chatroomId});
  }

  ///获取聊天室信息
  @override
  void getChatroomInfo(
      String chatroomId,
      int updateDt,
      OperationSuccessChatroomInfoCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod("getChatroomInfo", {
      "requestId": requestId,
      "chatroomId": chatroomId,
      "updateDt": updateDt
    });
  }

  ///获取聊天室成员信息
  @override
  void getChatroomMemberInfo(
      String chatroomId,
      OperationSuccessChatroomMemberInfoCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod("getChatroomMemberInfo",
        {"requestId": requestId, "chatroomId": chatroomId});
  }

  ///创建频道
  @override
  void createChannel(
      String channelName,
      String channelPortrait,
      int status,
      String desc,
      String extra,
      OperationSuccessChannelInfoCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod("createChannel", {
      "requestId": requestId,
      "name": channelName,
      "portrait": channelPortrait,
      "status": status,
      "desc": desc,
      "extra": extra
    });
  }

  ///获取频道信息
  @override
  Future<ChannelInfo?> getChannelInfo(String channelId,
      {bool refresh = false}) async {
    Map<dynamic, dynamic>? data = await methodChannel.invokeMethod(
        "getChannelInfo", {"channelId": channelId, "refresh": refresh});
    return _convertProtoChannelInfo(data);
  }

  ///修改频道信息
  @override
  void modifyChannelInfo(
      String channelId,
      ModifyChannelInfoType modifyType,
      String newValue,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod("modifyChannelInfo", {
      "requestId": requestId,
      "channelId": channelId,
      "modifyType": modifyType.index,
      "newValue": newValue
    });
  }

  ///搜索频道
  @override
  void searchChannel(
      String keyword,
      OperationSuccessChannelInfosCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod(
        "searchChannel", {"requestId": requestId, "keyword": keyword});
  }

  ///是否是已订阅频道
  @override
  Future<bool> isListenedChannel(String channelId) async {
    return await methodChannel
        .invokeMethod("isListenedChannel", {"channelId": channelId});
  }

  ///订阅/取消订阅频道
  @override
  void listenChannel(
      String channelId,
      bool isListen,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod("listenChannel",
        {"requestId": requestId, "channelId": channelId, "isListen": isListen});
  }

  ///获取我的频道
  @override
  Future<List<String>?> getMyChannels() async {
    return Tools.convertDynamicList(await methodChannel.invokeMethod("getMyChannels"));
  }

  ///获取我订阅的频道
  @override
  Future<List<String>?> getListenedChannels() async {
    return Tools.convertDynamicList(
        await methodChannel.invokeMethod("getListenedChannels"));
  }

  ///销毁频道
  @override
  void destroyChannel(
      String channelId,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod(
        "destoryChannel", {"requestId": requestId, "channelId": channelId});
  }

  ///获取PC端在线状态
  @override
  Future<List<PCOnlineInfo>> getOnlineInfos() async {
    List<dynamic> datas = await methodChannel.invokeMethod("getOnlineInfos");
    return _convertProtoOnlineInfos(datas);
  }

  ///踢掉PC客户端
  @override
  void kickoffPCClient(
      String clientId,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod(
        "kickoffPCClient", {"requestId": requestId, "clientId": clientId});
  }

  ///是否设置当PC在线时停止手机通知
  @override
  Future<bool> isMuteNotificationWhenPcOnline() async {
    return await methodChannel.invokeMethod("isMuteNotificationWhenPcOnline");
  }

  ///设置/取消设置当PC在线时停止手机通知
  @override
  void muteNotificationWhenPcOnline(
      bool isMute,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod("muteNotificationWhenPcOnline",
        {"requestId": requestId, "isMute": isMute});
  }

  @override
  Future<UserOnlineState?> getUserOnlineState(String userId) async {
    Map<dynamic, dynamic>? map = await methodChannel.invokeMethod("getUserOnlineState", {"userId": userId});
    if(map == null) {
      return null;
    } else {
      return _convertProtoUserOnlineState(map);
    }
  }

  @override
  Future<CustomState> getMyCustomState() async {
    Map<dynamic, dynamic> map =  await methodChannel.invokeMethod("getMyCustomState");
    CustomState cs = CustomState(map['state']);
    cs.text = map['text'];
    return cs;
  }

  @override
  void setMyCustomState(
      int customState, String? customText,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    Map<dynamic, dynamic> args = {"requestId": requestId, "customState": customState};
    if(customText != null) {
      args["customText"] = customText;
    }
    methodChannel.invokeMethod("setMyCustomState", args);
  }

  @override
  void watchOnlineState(
      ConversationType conversationType, List<String> targets, int watchDuration,
      OperationSuccessWatchUserOnlineCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod("watchOnlineState",
        {"requestId": requestId, "conversationType": conversationType.index, "targets":targets, "watchDuration":watchDuration});
  }

  @override
  void unwatchOnlineState(
      ConversationType conversationType, List<String> targets,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod("unwatchOnlineState",
        {"requestId": requestId, "conversationType": conversationType.index, "targets":targets});
  }

  @override
  Future<bool> isEnableUserOnlineState() async {
    return await methodChannel.invokeMethod("isEnableUserOnlineState");
  }

  ///获取会话文件记录
  @override
  void getConversationFiles(
      int beforeMessageUid,
      int count,
      OperationSuccessFilesCallback successCallback,
      OperationFailureCallback errorCallback,
      {Conversation? conversation,
        String? fromUser}) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;

    Map<String, dynamic> args = {
      "requestId": requestId,
      "beforeMessageUid": beforeMessageUid,
      "count": count
    };

    if (conversation != null) {
      args['conversation'] = _convertConversation(conversation);
    }

    if(fromUser != null) {
      args['fromUser'] = fromUser;
    }

    methodChannel.invokeMethod("getConversationFiles", args);
  }

  ///获取我的文件记录
  @override
  void getMyFiles(
      int beforeMessageUid,
      int count,
      OperationSuccessFilesCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod("getMyFiles", {
      "requestId": requestId,
      "beforeMessageUid": beforeMessageUid,
      "count": count
    });
  }

  ///删除文件记录
  @override
  void deleteFileRecord(
      int messageUid,
      int count,
      OperationSuccessFilesCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod("deleteFileRecord",
        {"requestId": requestId, "messageUid": messageUid});
  }

  ///搜索文件记录
  @override
  void searchFiles(
      String keyword,
      int beforeMessageUid,
      int count,
      OperationSuccessFilesCallback successCallback,
      OperationFailureCallback errorCallback,
      {Conversation? conversation,
        String? fromUser}) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    Map<String, dynamic> args = {
      "requestId": requestId,
      "keyword": keyword,
      "beforeMessageUid": beforeMessageUid,
      "count": count,
    };

    if (conversation != null) {
      args['conversation'] = _convertConversation(conversation);
    }

    if(fromUser != null) {
      args['fromUser'] = fromUser;
    }

    methodChannel.invokeMethod("searchFiles", args);
  }

  int addCallback(dynamic successCallback, OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    return requestId;
  }

  ///搜索我的文件记录
  @override
  void searchMyFiles(
      String keyword,
      int beforeMessageUid,
      int count,
      OperationSuccessFilesCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = addCallback(successCallback, errorCallback);
    methodChannel.invokeMethod("searchMyFiles", {
      "requestId": requestId,
      "keyword": keyword,
      "beforeMessageUid": beforeMessageUid,
      "count": count
    });
  }

  ///获取经过授权的媒体路径
  @override
  void getAuthorizedMediaUrl(
      String mediaPath,
      int messageUid,
      int mediaType,
      OperationSuccessStringCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod("getAuthorizedMediaUrl", {
      "requestId": requestId,
      "mediaPath": mediaPath,
      "messageUid": messageUid,
      "mediaType": mediaType
    });
  }

  @override
  void getAuthCode(
      String applicationId,
      int type,
      String host,
      OperationSuccessStringCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod("getAuthCode", {
      "requestId": requestId,
      "applicationId": applicationId,
      "type": type,
      "host": host
    });
  }

  @override
  void configApplication(
      String applicationId,
      int type,
      int timestamp,
      String nonce,
      String signature,
      OperationSuccessVoidCallback successCallback,
      OperationFailureCallback errorCallback) {
    int requestId = _requestId++;
    _operationSuccessCallbackMap[requestId] = successCallback;
    _errorCallbackMap[requestId] = errorCallback;
    methodChannel.invokeMethod("configApplication", {
      "requestId": requestId,
      "applicationId": applicationId,
      "type": type,
      "timestamp": timestamp,
      "nonce":nonce,
      "signature":signature
    });
  }

  ///转换amr数据为wav数据，仅在iOS平台有效
  @override
  Future<Uint8List> getWavData(String amrPath) async {
    return await methodChannel.invokeMethod("getWavData", {"amrPath": amrPath});
  }

  ///开启协议栈数据库事物，仅当数据迁移功能使用
  @override
  Future<bool> beginTransaction() async {
    return await methodChannel.invokeMethod("beginTransaction");
  }

  ///提交协议栈数据库事物，仅当数据迁移功能使用
  @override
  Future<bool> commitTransaction() async {
    return await methodChannel.invokeMethod("commitTransaction");
  }

  @override
  Future<bool> rollbackTransaction() async {
    return await methodChannel.invokeMethod("rollbackTransaction");
  }

  ///是否是专业版
  @override
  Future<bool> isCommercialServer() async {
    return await methodChannel.invokeMethod("isCommercialServer");
  }

  ///服务是否支持消息回执
  @override
  Future<bool> isReceiptEnabled() async {
    return await methodChannel.invokeMethod("isReceiptEnabled");
  }

  @override
  Future<bool> isGlobalDisableSyncDraft() async {
    return await methodChannel.invokeMethod("isGlobalDisableSyncDraft");
  }
}
