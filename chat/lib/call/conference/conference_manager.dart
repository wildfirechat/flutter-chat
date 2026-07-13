import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:chat/app_server.dart';
import 'package:avenginekit/messages/conference_command_message_content.dart' as av_command;

/// 会议管理命令类型
class ConferenceCommandType {
  static const int MUTE_ALL_AUDIO = 1;
  static const int CANCEL_MUTE_ALL_AUDIO = 2;
  static const int MUTE_ALL_VIDEO = 3;
  static const int CANCEL_MUTE_ALL_VIDEO = 4;
  static const int REQUEST_MUTE_AUDIO = 5;
  static const int REQUEST_MUTE_VIDEO = 6;
  static const int APPLY_UNMUTE_AUDIO = 7;
  static const int APPLY_UNMUTE_VIDEO = 8;
  static const int APPROVE_UNMUTE_AUDIO = 9;
  static const int APPROVE_UNMUTE_VIDEO = 10;
  static const int APPROVE_ALL_UNMUTE_AUDIO = 11;
  static const int APPROVE_ALL_UNMUTE_VIDEO = 12;
  static const int HANDUP = 13;
  static const int CANCEL_HANDUP = 14;
  static const int PUT_MEMBER_HAND_DOWN = 15;
  static const int PUT_ALL_HAND_DOWN = 16;
}

/// 会议状态管理器
/// 负责会议元数据、举手/申请开麦列表、主持人命令发送
class ConferenceManager {
  static final ConferenceManager _instance = ConferenceManager._internal();
  factory ConferenceManager() => _instance;
  ConferenceManager._internal();

  Map<String, dynamic> conferenceInfo = {};
  List<String> applyingUnmuteAudioMembers = [];
  List<String> applyingUnmuteVideoMembers = [];
  bool isApplyingUnmuteAudio = false;
  bool isApplyingUnmuteVideo = false;
  List<String> handUpMembers = [];
  bool isHandUp = false;
  bool isMuteAll = false;
  bool allowUnmuteAudio = false;
  bool allowUnmuteVideo = false;
  String? currentFocusUser;
  String? localFocusUser;

  String? _conferenceId;
  String? _password;
  Function? _onStateChanged;

  void setup(String conferenceId, String password, {Function? onStateChanged}) {
    _conferenceId = conferenceId;
    _password = password;
    _onStateChanged = onStateChanged;
    queryConferenceInfo();
  }

  void destroy() {
    _conferenceId = null;
    _password = null;
    _onStateChanged = null;
    conferenceInfo = {};
    applyingUnmuteAudioMembers.clear();
    applyingUnmuteVideoMembers.clear();
    handUpMembers.clear();
    isHandUp = false;
    isMuteAll = false;
  }

  void queryConferenceInfo() {
    if (_conferenceId == null) return;
    AppServer.queryConferenceInfo(_conferenceId!, _password ?? '', (info) {
      conferenceInfo = info;
      _notifyStateChanged();
    }, (error) {
      print('queryConferenceInfo error: $error');
    });
  }

  bool get isOwner {
    var owner = conferenceInfo['owner'] ?? conferenceInfo['host'] ?? '';
    return owner == Imclient.currentUserId;
  }

  void _notifyStateChanged() {
    if (_onStateChanged != null) {
      _onStateChanged!();
    }
  }

  /// 发送会议命令消息（会议聊天室广播）
  void _sendCommand(int command, {String targetUserId = '', bool boolValue = false, Function? successCallback, Function(String)? errorCallback}) {
    if (_conferenceId == null) return;
    var content = av_command.ConferenceCommandMessageContent();
    content.callId = _conferenceId!;
    content.command = command;
    content.targetUserId = targetUserId;
    content.boolValue = boolValue;

    var conversation = Conversation(
      conversationType: ConversationType.Chatroom,
      target: _conferenceId!,
      line: 0,
    );
    Imclient.sendMessage(
      conversation,
      content,
      successCallback: (messageUid, timestamp) {
        if (successCallback != null) successCallback();
      },
      errorCallback: (errorCode) {
        if (errorCallback != null) errorCallback('send command error $errorCode');
      },
    );
  }

  /// 全体静音/取消全体静音
  void requestMuteAll(bool audio, bool allowMemberUnmute) {
    if (!isOwner) return;
    Map<String, dynamic> info = Map.from(conferenceInfo);
    if (audio) {
      info['muteAllAudio'] = true;
      info['allowMemberUnmuteAudio'] = allowMemberUnmute;
    } else {
      info['muteAllVideo'] = true;
      info['allowMemberUnmuteVideo'] = allowMemberUnmute;
    }
    AppServer.updateConference(info, () {
      isMuteAll = true;
      allowUnmuteAudio = allowMemberUnmute;
      _notifyStateChanged();
    }, (error) {
      print('requestMuteAll error: $error');
    });
  }

  void requestUnmuteAll(bool audio, bool unmute) {
    if (!isOwner) return;
    Map<String, dynamic> info = Map.from(conferenceInfo);
    if (audio) {
      info['muteAllAudio'] = false;
    } else {
      info['muteAllVideo'] = false;
    }
    AppServer.updateConference(info, () {
      isMuteAll = false;
      _notifyStateChanged();
    }, (error) {
      print('requestUnmuteAll error: $error');
    });
  }

  /// 请求成员静音/取消静音
  void requestMemberMute(String userId, bool audio, bool mute) {
    if (!isOwner) return;
    _sendCommand(audio ? ConferenceCommandType.REQUEST_MUTE_AUDIO : ConferenceCommandType.REQUEST_MUTE_VIDEO,
        targetUserId: userId);
  }

  /// 成员申请开麦/开视频
  void applyUnmute(bool audio, bool isCancel) {
    int command = audio
        ? (isCancel ? ConferenceCommandType.APPLY_UNMUTE_AUDIO : ConferenceCommandType.APPLY_UNMUTE_AUDIO)
        : (isCancel ? ConferenceCommandType.APPLY_UNMUTE_VIDEO : ConferenceCommandType.APPLY_UNMUTE_VIDEO);
    _sendCommand(command);
    if (audio) {
      isApplyingUnmuteAudio = !isCancel;
    } else {
      isApplyingUnmuteVideo = !isCancel;
    }
    _notifyStateChanged();
  }

  /// 主持人批准/拒绝开麦
  void approveUnmute(String userId, bool audio, bool isAllow) {
    if (!isOwner) return;
    int command = audio
        ? (isAllow ? ConferenceCommandType.APPROVE_UNMUTE_AUDIO : ConferenceCommandType.REQUEST_MUTE_AUDIO)
        : (isAllow ? ConferenceCommandType.APPROVE_UNMUTE_VIDEO : ConferenceCommandType.REQUEST_MUTE_VIDEO);
    _sendCommand(command, targetUserId: userId);
    if (isAllow) {
      if (audio) {
        applyingUnmuteAudioMembers.remove(userId);
      } else {
        applyingUnmuteVideoMembers.remove(userId);
      }
      _notifyStateChanged();
    }
  }

  /// 举手
  void handUp(bool handUp) {
    _sendCommand(handUp ? ConferenceCommandType.HANDUP : ConferenceCommandType.CANCEL_HANDUP);
    isHandUp = handUp;
    _notifyStateChanged();
  }

  /// 主持人放下成员手
  void putMemberHandDown(String memberId) {
    if (!isOwner) return;
    _sendCommand(ConferenceCommandType.PUT_MEMBER_HAND_DOWN, targetUserId: memberId);
    handUpMembers.remove(memberId);
    _notifyStateChanged();
  }

  /// 主持人放下所有手
  void putAllHandDown() {
    if (!isOwner) return;
    _sendCommand(ConferenceCommandType.PUT_ALL_HAND_DOWN);
    handUpMembers.clear();
    _notifyStateChanged();
  }

  /// 设置焦点用户
  void requestFocus(String? userId) {
    if (!isOwner || _conferenceId == null) return;
    if (userId == null) {
      requestCancelFocus();
      return;
    }
    AppServer.setConferenceFocusUserId(_conferenceId!, userId, () {
      currentFocusUser = userId;
      _notifyStateChanged();
    }, (error) {
      print('requestFocus error: $error');
    });
  }

  void requestCancelFocus() {
    if (!isOwner || _conferenceId == null) return;
    AppServer.setConferenceFocusUserId(_conferenceId!, '', () {
      currentFocusUser = null;
      _notifyStateChanged();
    }, (error) {
      print('requestCancelFocus error: $error');
    });
  }

  /// 收藏/取消收藏
  void favConference(bool fav) {
    if (_conferenceId == null) return;
    if (fav) {
      AppServer.favConference(_conferenceId!, () {}, (error) {
        print('favConference error: $error');
      });
    } else {
      AppServer.unfavConference(_conferenceId!, () {}, (error) {
        print('unfavConference error: $error');
      });
    }
  }

  /// 销毁会议
  void destroyConference(Function successCallback, Function(String) errorCallback) {
    if (_conferenceId == null) return;
    AppServer.destroyConference(_conferenceId!, successCallback, errorCallback);
  }
}
