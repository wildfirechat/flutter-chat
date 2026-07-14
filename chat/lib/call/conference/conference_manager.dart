import 'dart:async';
import 'dart:convert';

import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/model/conversation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chat/app_server.dart';
import 'package:avenginekit/messages/conference_command_message_content.dart' as av_command;

/// 会议管理命令类型，与 Vue / web SDK 保持一致
class ConferenceCommandType {
  static const int MUTE_ALL_AUDIO = 0;
  static const int CANCEL_MUTE_ALL_AUDIO = 1;
  static const int REQUEST_MUTE_AUDIO = 2;
  static const int REJECT_UNMUTE_REQUEST_AUDIO = 3;
  static const int APPLY_UNMUTE_AUDIO = 4;
  static const int APPROVE_UNMUTE_AUDIO = 5;
  static const int APPROVE_ALL_UNMUTE_AUDIO = 6;
  static const int HANDUP = 7;
  static const int PUT_HAND_DOWN = 8;
  static const int PUT_ALL_HAND_DOWN = 9;
  static const int RECORDING = 10;
  static const int FOCUS = 11;
  static const int CANCEL_FOCUS = 12;
  static const int MUTE_ALL_VIDEO = 13;
  static const int CANCEL_MUTE_ALL_VIDEO = 14;
  static const int REQUEST_MUTE_VIDEO = 15;
  static const int REJECT_UNMUTE_REQUEST_VIDEO = 16;
  static const int APPLY_UNMUTE_VIDEO = 17;
  static const int APPROVE_UNMUTE_VIDEO = 18;
  static const int APPROVE_ALL_UNMUTE_VIDEO = 19;
}

/// 会议状态管理器
/// 负责会议元数据、举手/申请开麦列表、主持人命令发送与接收
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
  Function(bool audio, bool mute)? onLocalMuteRequest;

  StreamSubscription? _messageSubscription;

  void setup(String conferenceId, String password, {Function? onStateChanged}) {
    destroy();
    _conferenceId = conferenceId;
    _password = password;
    _onStateChanged = onStateChanged;
    _registerMessageListener();
    queryConferenceInfo();
  }

  void destroy() {
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _conferenceId = null;
    _password = null;
    _onStateChanged = null;
    onLocalMuteRequest = null;
    conferenceInfo = {};
    applyingUnmuteAudioMembers.clear();
    applyingUnmuteVideoMembers.clear();
    handUpMembers.clear();
    isHandUp = false;
    isMuteAll = false;
    currentFocusUser = null;
    localFocusUser = null;
  }

  void _registerMessageListener() {
    _messageSubscription = Imclient.IMEventBus.on<ReceiveMessagesEvent>().listen((event) {
      for (var msg in event.messages) {
        _handleMessage(msg);
      }
    });
  }

  void _handleMessage(Message msg) {
    if (_conferenceId == null) return;
    if (msg.conversation.conversationType != ConversationType.Chatroom) return;
    if (msg.conversation.target != _conferenceId) return;
    if (msg.content is! av_command.ConferenceCommandMessageContent) return;

    var content = msg.content as av_command.ConferenceCommandMessageContent;
    var command = content.command;
    var target = content.targetUserId;
    var boolValue = content.boolValue;
    var from = msg.fromUser;
    var selfId = Imclient.currentUserId;

    switch (command) {
      case ConferenceCommandType.HANDUP:
        if (boolValue) {
          if (!handUpMembers.contains(from)) {
            handUpMembers.add(from);
          }
        } else {
          handUpMembers.remove(from);
        }
        if (from == selfId) {
          isHandUp = boolValue;
        }
        break;
      case ConferenceCommandType.PUT_HAND_DOWN:
        handUpMembers.remove(target);
        if (target == selfId) {
          isHandUp = false;
        }
        break;
      case ConferenceCommandType.PUT_ALL_HAND_DOWN:
        handUpMembers.clear();
        isHandUp = false;
        break;
      case ConferenceCommandType.APPLY_UNMUTE_AUDIO:
        if (boolValue) {
          applyingUnmuteAudioMembers.remove(from);
          if (from == selfId) isApplyingUnmuteAudio = false;
        } else {
          if (!applyingUnmuteAudioMembers.contains(from)) {
            applyingUnmuteAudioMembers.add(from);
          }
          if (from == selfId) isApplyingUnmuteAudio = true;
        }
        break;
      case ConferenceCommandType.APPLY_UNMUTE_VIDEO:
        if (boolValue) {
          applyingUnmuteVideoMembers.remove(from);
          if (from == selfId) isApplyingUnmuteVideo = false;
        } else {
          if (!applyingUnmuteVideoMembers.contains(from)) {
            applyingUnmuteVideoMembers.add(from);
          }
          if (from == selfId) isApplyingUnmuteVideo = true;
        }
        break;
      case ConferenceCommandType.APPROVE_UNMUTE_AUDIO:
        applyingUnmuteAudioMembers.remove(target);
        if (target == selfId || target.isEmpty) {
          onLocalMuteRequest?.call(true, false);
        }
        break;
      case ConferenceCommandType.APPROVE_UNMUTE_VIDEO:
        applyingUnmuteVideoMembers.remove(target);
        if (target == selfId || target.isEmpty) {
          onLocalMuteRequest?.call(false, false);
        }
        break;
      case ConferenceCommandType.APPROVE_ALL_UNMUTE_AUDIO:
        applyingUnmuteAudioMembers.clear();
        onLocalMuteRequest?.call(true, false);
        break;
      case ConferenceCommandType.APPROVE_ALL_UNMUTE_VIDEO:
        applyingUnmuteVideoMembers.clear();
        onLocalMuteRequest?.call(false, false);
        break;
      case ConferenceCommandType.REJECT_UNMUTE_REQUEST_AUDIO:
        applyingUnmuteAudioMembers.remove(target);
        if (target == selfId || target.isEmpty) {
          isApplyingUnmuteAudio = false;
        }
        break;
      case ConferenceCommandType.REJECT_UNMUTE_REQUEST_VIDEO:
        applyingUnmuteVideoMembers.remove(target);
        if (target == selfId || target.isEmpty) {
          isApplyingUnmuteVideo = false;
        }
        break;
      case ConferenceCommandType.REQUEST_MUTE_AUDIO:
        if (target == selfId || target.isEmpty) {
          onLocalMuteRequest?.call(true, true);
        }
        break;
      case ConferenceCommandType.REQUEST_MUTE_VIDEO:
        if (target == selfId || target.isEmpty) {
          onLocalMuteRequest?.call(false, true);
        }
        break;
      case ConferenceCommandType.MUTE_ALL_AUDIO:
        isMuteAll = true;
        allowUnmuteAudio = boolValue;
        conferenceInfo['muteAllAudio'] = true;
        conferenceInfo['allowMemberUnmuteAudio'] = boolValue;
        onLocalMuteRequest?.call(true, true);
        break;
      case ConferenceCommandType.CANCEL_MUTE_ALL_AUDIO:
        isMuteAll = false;
        allowUnmuteAudio = true;
        conferenceInfo['muteAllAudio'] = false;
        conferenceInfo['allowMemberUnmuteAudio'] = true;
        break;
      case ConferenceCommandType.MUTE_ALL_VIDEO:
        allowUnmuteVideo = boolValue;
        conferenceInfo['muteAllVideo'] = true;
        conferenceInfo['allowMemberUnmuteVideo'] = boolValue;
        onLocalMuteRequest?.call(false, true);
        break;
      case ConferenceCommandType.CANCEL_MUTE_ALL_VIDEO:
        allowUnmuteVideo = true;
        conferenceInfo['muteAllVideo'] = false;
        conferenceInfo['allowMemberUnmuteVideo'] = true;
        break;
      case ConferenceCommandType.FOCUS:
        conferenceInfo['focus'] = target;
        currentFocusUser = target;
        break;
      case ConferenceCommandType.CANCEL_FOCUS:
        conferenceInfo['focus'] = null;
        currentFocusUser = null;
        break;
      case ConferenceCommandType.RECORDING:
        conferenceInfo['recording'] = boolValue;
        break;
    }
    _notifyStateChanged();
  }

  void queryConferenceInfo() {
    if (_conferenceId == null) return;
    AppServer.queryConferenceInfo(_conferenceId!, _password ?? '', (info) {
      conferenceInfo = info;
      currentFocusUser = info['focus'];
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
      if (audio) {
        allowUnmuteAudio = allowMemberUnmute;
      } else {
        allowUnmuteVideo = allowMemberUnmute;
      }
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
      info['allowMemberUnmuteAudio'] = true;
    } else {
      info['muteAllVideo'] = false;
      info['allowMemberUnmuteVideo'] = true;
    }
    AppServer.updateConference(info, () {
      isMuteAll = false;
      if (audio) {
        allowUnmuteAudio = true;
      } else {
        allowUnmuteVideo = true;
      }
      _notifyStateChanged();
    }, (error) {
      print('requestUnmuteAll error: $error');
    });
  }

  /// 请求成员静音/取消静音
  void requestMemberMute(String userId, bool audio, bool mute) {
    if (!isOwner) return;
    if (mute) {
      _sendCommand(
        audio ? ConferenceCommandType.REQUEST_MUTE_AUDIO : ConferenceCommandType.REQUEST_MUTE_VIDEO,
        targetUserId: userId,
      );
    } else {
      _sendCommand(
        audio ? ConferenceCommandType.APPROVE_UNMUTE_AUDIO : ConferenceCommandType.APPROVE_UNMUTE_VIDEO,
        targetUserId: userId,
      );
    }
  }

  /// 成员申请开麦/开视频
  void applyUnmute(bool audio, bool isCancel) {
    _sendCommand(
      audio ? ConferenceCommandType.APPLY_UNMUTE_AUDIO : ConferenceCommandType.APPLY_UNMUTE_VIDEO,
      boolValue: isCancel,
    );
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
    if (isAllow) {
      _sendCommand(
        audio ? ConferenceCommandType.APPROVE_UNMUTE_AUDIO : ConferenceCommandType.APPROVE_UNMUTE_VIDEO,
        targetUserId: userId,
      );
      if (audio) {
        applyingUnmuteAudioMembers.remove(userId);
      } else {
        applyingUnmuteVideoMembers.remove(userId);
      }
    } else {
      _sendCommand(
        audio ? ConferenceCommandType.REJECT_UNMUTE_REQUEST_AUDIO : ConferenceCommandType.REJECT_UNMUTE_REQUEST_VIDEO,
        targetUserId: userId,
      );
    }
    _notifyStateChanged();
  }

  /// 主持人批准/拒绝全部开麦申请
  void approveAllUnmute(bool audio, bool isAllow) {
    if (!isOwner) return;
    if (isAllow) {
      _sendCommand(
        audio ? ConferenceCommandType.APPROVE_ALL_UNMUTE_AUDIO : ConferenceCommandType.APPROVE_ALL_UNMUTE_VIDEO,
      );
      if (audio) {
        applyingUnmuteAudioMembers.clear();
      } else {
        applyingUnmuteVideoMembers.clear();
      }
    } else {
      var list = audio ? applyingUnmuteAudioMembers : applyingUnmuteVideoMembers;
      for (var userId in list) {
        _sendCommand(
          audio ? ConferenceCommandType.REJECT_UNMUTE_REQUEST_AUDIO : ConferenceCommandType.REJECT_UNMUTE_REQUEST_VIDEO,
          targetUserId: userId,
        );
      }
      list.clear();
    }
    _notifyStateChanged();
  }

  /// 举手
  void handUp(bool handUp) {
    _sendCommand(ConferenceCommandType.HANDUP, boolValue: handUp);
    isHandUp = handUp;
    _notifyStateChanged();
  }

  /// 主持人放下成员手
  void putMemberHandDown(String memberId) {
    if (!isOwner) return;
    _sendCommand(ConferenceCommandType.PUT_HAND_DOWN, targetUserId: memberId);
    handUpMembers.remove(memberId);
    _notifyStateChanged();
  }

  /// 主持人放下所有手
  void putAllHandDown() {
    if (!isOwner) return;
    _sendCommand(ConferenceCommandType.PUT_ALL_HAND_DOWN);
    handUpMembers.clear();
    isHandUp = false;
    _notifyStateChanged();
  }

  /// 设置焦点用户
  void requestFocus(String? userId) {
    if (!isOwner || _conferenceId == null) return;
    if (userId == null || userId.isEmpty) {
      requestCancelFocus();
      return;
    }
    AppServer.setConferenceFocusUserId(_conferenceId!, userId, () {
      conferenceInfo['focus'] = userId;
      currentFocusUser = userId;
      _sendCommand(ConferenceCommandType.FOCUS, targetUserId: userId);
      _notifyStateChanged();
    }, (error) {
      print('requestFocus error: $error');
    });
  }

  void requestCancelFocus() {
    if (!isOwner || _conferenceId == null) return;
    AppServer.setConferenceFocusUserId(_conferenceId!, '', () {
      conferenceInfo['focus'] = null;
      currentFocusUser = null;
      _sendCommand(ConferenceCommandType.CANCEL_FOCUS);
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
        print('favConference error: $error');
      });
    }
  }

  /// 销毁会议
  void destroyConference(Function successCallback, Function(String) errorCallback) {
    if (_conferenceId == null) return;
    AppServer.destroyConference(_conferenceId!, successCallback, errorCallback);
  }

  //region 会议历史记录（本地持久化）

  static const String _historyKey = 'historyConfList';
  static const int _maxHistoryCount = 50;

  static Future<void> addHistory(Map<String, dynamic> info, int durationMs) async {
    var list = await getHistoryConferences();
    var conferenceId = info['conferenceId'] as String?;
    if (conferenceId == null || conferenceId.isEmpty) return;

    var copy = Map<String, dynamic>.from(info);
    var startTime = copy['startTime'] ?? 0;
    if (startTime is num) {
      copy['endTime'] = (startTime + durationMs / 1000).toInt();
    }

    var index = list.indexWhere((e) => e['conferenceId'] == conferenceId);
    if (index >= 0) {
      list[index] = copy;
    } else {
      list.add(copy);
    }

    while (list.length > _maxHistoryCount) {
      list.removeAt(0);
    }

    var prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(list));
  }

  static Future<void> removeHistory(String conferenceId) async {
    var list = await getHistoryConferences();
    list.removeWhere((e) => e['conferenceId'] == conferenceId);
    var prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(list));
  }

  static Future<List<Map<String, dynamic>>> getHistoryConferences() async {
    var prefs = await SharedPreferences.getInstance();
    var jsonStr = prefs.getString(_historyKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      var decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      print('getHistoryConferences error: $e');
    }
    return [];
  }

  //endregion
}
