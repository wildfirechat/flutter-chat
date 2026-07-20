import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:avenginekit/engine/call_session.dart';
import 'package:avenginekit/engine/call_session_callback.dart';
import 'package:avenginekit/engine/call_state.dart';
import 'package:avenginekit/engine/call_end_reason.dart';
import 'package:avenginekit/engine/participant_profile.dart';
import 'package:avenginekit/engine/video_type.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/pc_shell_view_model.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/theme/app_colors.dart';

import 'conference_grid_layout.dart';
import 'conference_manager.dart';
import 'conference_mobile_layout.dart';
import 'conference_participant_item.dart';
import 'conference_participant_list_view.dart';
import 'conference_speaker_layout.dart';

extension _FirstWhereOrNullExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

/// 会议通话界面。
///
/// 视频区布局按平台分流(见 PC_UI_ADAPTATION 设计):
/// - 移动端:单一布局——第 0 页焦点大画面(叠加可拖动预览小窗),
///   第 1..n 页 2x2 网格分页,见 [ConferenceMobileLayout]。
/// - PC:两种布局可切换——宫格(9 人/页,箭头翻页)与演讲者
///   (大画面+右侧缩略图条),见 [ConferenceGridLayout]/[ConferenceSpeakerLayout];
///   主持人设置服务器焦点时强制演讲者视图。
/// 大小流订阅由 [_syncSubscriptions] 按布局/页码/焦点统一调度。
class ConferenceCallScreen extends StatefulWidget {
  final CallSession session;

  const ConferenceCallScreen({Key? key, required this.session}) : super(key: key);

  @override
  State<ConferenceCallScreen> createState() => _ConferenceCallScreenState();
}

class _ConferenceCallScreenState extends State<ConferenceCallScreen>
    implements CallSessionCallback {
  late CallSession _session;
  final Map<String, ConferenceParticipantItem> _participants = {};
  ConferenceParticipantItem? _selfItem;
  bool _isMicMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = false;
  bool _showMemberList = false;
  int _currentLayout = 0; // PC 用户自选布局:0 宫格, 1 演讲者
  String? _localFocusUserId;
  Duration _duration = Duration.zero;
  Timer? _timer;
  late ConferenceManager _conferenceManager;

  /// 移动端当前页码 / PC 宫格当前页码,驱动大小流订阅调度。
  int _mobilePage = 0;
  int _pcGridPage = 0;

  /// 移动端成员弹层是否打开,通话结束时需先关弹层再退界面。
  bool _memberSheetOpen = false;

  /// 各参与者当前订阅的流类型,仅变化时才下发 setParticipantVideoType。
  final Map<String, int> _subscriptionState = {};

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _session.setCallback(this);
    _isMicMuted = _session.isAudioMuted;
    _isCameraOff = _session.isVideoMuted;
    _conferenceManager = ConferenceManager();
    _conferenceManager.setup(_session.callId, _session.pin, onStateChanged: () {
      if (mounted) setState(() {});
    });
    _conferenceManager.onLocalMuteRequest = (audio, mute) {
      if (audio) {
        if (_isMicMuted != mute) {
          _session.muteAudio(mute);
          setState(() {
            _isMicMuted = mute;
            if (_selfItem != null) _selfItem!.audioMuted = mute;
          });
        }
      } else {
        if (_isCameraOff != mute) {
          _session.muteVideo(mute);
          setState(() {
            _isCameraOff = mute;
            if (_selfItem != null) _selfItem!.videoMuted = mute;
          });
        }
      }
    };
    _initSelf();
    _initRemoteParticipants();
  }

  Future<void> _initSelf() async {
    var renderer = RTCVideoRenderer();
    await renderer.initialize();
    _selfItem = ConferenceParticipantItem(userId: Imclient.currentUserId, renderer: renderer);
    var info = await Imclient.getUserInfo(Imclient.currentUserId);
    _selfItem!.userInfo = info;
    _selfItem!.videoMuted = _session.isVideoMuted;
    _selfItem!.audioMuted = _session.isAudioMuted;
    _selfItem!.isAudience = _session.audience;
    if (mounted) setState(() {});
    _updateSelfStream();
  }

  Future<void> _initRemoteParticipants() async {
    var profiles = _session.getParticipantProfiles();
    for (var profile in profiles) {
      await _addParticipant(profile.userId);
    }
  }

  Future<void> _addParticipant(String userId) async {
    if (_participants.containsKey(userId)) return;
    var renderer = RTCVideoRenderer();
    await renderer.initialize();
    var item = ConferenceParticipantItem(userId: userId, renderer: renderer);
    var info = await Imclient.getUserInfo(userId);
    item.userInfo = info;
    var stream = _session.getParticipantVideoStream(userId);
    if (stream != null) {
      item.renderer.srcObject = stream;
    }
    var profile = _session.getParticipantProfiles().firstWhere(
        (p) => p.userId == userId,
        orElse: () => ParticipantProfile(userId));
    item.audioMuted = profile.audioMuted;
    item.videoMuted = profile.videoMuted;
    item.isAudience = profile.audience;
    _participants[userId] = item;
    if (mounted) setState(() {});
  }

  void _updateSelfStream() {
    if (_selfItem == null) return;
    var stream = _session.getParticipantVideoStream(Imclient.currentUserId);
    if (stream != null && _selfItem!.renderer.srcObject == null) {
      _selfItem!.renderer.srcObject = stream;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _stopTimer();
    _selfItem?.renderer.dispose();
    for (var item in _participants.values) {
      item.renderer.dispose();
    }
    _conferenceManager.destroy();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _duration += const Duration(seconds: 1);
        });
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    } else {
      return "$twoDigitMinutes:$twoDigitSeconds";
    }
  }

  // --- Actions ---

  void _onHangup() {
    _session.hangup();
  }

  void _onAccept() {
    _session.answerCall(_session.audioOnly);
  }

  void _onToggleMic() {
    bool nextMute = !_isMicMuted;
    if (!nextMute && _session.audience && !_conferenceManager.isOwner) {
      var allowSwitch = _conferenceManager.conferenceInfo['allowSwitchMode'] == true;
      if (!allowSwitch) {
        _requestUnmute(true);
        return;
      }
    }
    _setMicMuted(nextMute);
  }

  void _setMicMuted(bool mute) {
    _session.muteAudio(mute);
    setState(() {
      _isMicMuted = mute;
      if (_selfItem != null) {
        _selfItem!.audioMuted = mute;
      }
    });
  }

  void _requestUnmute(bool audio) {
    var allow = audio ? _conferenceManager.allowUnmuteAudio : _conferenceManager.allowUnmuteVideo;
    if (allow) {
      if (audio) {
        _setMicMuted(false);
      } else {
        _setCameraOff(false);
      }
      return;
    }
    var loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(audio ? loc.conferenceRequestUnmuteAudio : loc.conferenceRequestUnmuteVideo),
        content: Text(audio
            ? loc.conferenceRequestUnmuteAudioDesc
            : loc.conferenceRequestUnmuteVideoDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(loc.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _conferenceManager.applyUnmute(audio, false);
            },
            child: Text(loc.confirm),
          ),
        ],
      ),
    );
  }

  void _onToggleCamera() {
    bool nextOff = !_isCameraOff;
    if (!nextOff && _session.audience && !_conferenceManager.isOwner) {
      var allowSwitch = _conferenceManager.conferenceInfo['allowSwitchMode'] == true;
      if (!allowSwitch) {
        _requestUnmute(false);
        return;
      }
    }
    _setCameraOff(nextOff);
  }

  void _setCameraOff(bool off) {
    _session.muteVideo(off);
    setState(() {
      _isCameraOff = off;
      if (_selfItem != null) {
        _selfItem!.videoMuted = off;
      }
    });
  }

  void _onSwitchCamera() {
    _session.switchCamera();
  }

  void _onToggleSpeaker() {
    Helper.setSpeakerphoneOn(!_isSpeakerOn);
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
  }

  Future<void> _onScreenShare() async {
    // TODO: Implement screen share
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('屏幕分享功能待实现')),
    );
  }

  void _onToggleMemberList() {
    if (isDesktopShell) {
      setState(() {
        _showMemberList = !_showMemberList;
      });
    } else {
      _showMemberListSheet();
    }
  }

  /// 移动端成员面板:底部弹层,不再挤压视频区。
  void _showMemberListSheet() {
    _memberSheetOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.7,
        child: ConferenceParticipantListView(
          session: _session,
          conferenceManager: _conferenceManager,
          onClose: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    ).whenComplete(() => _memberSheetOpen = false);
  }

  void _onLayoutChanged(int layout) {
    setState(() {
      _currentLayout = layout;
    });
  }

  void _onSwitchAudience() async {
    await _session.switchAudience(!_session.audience);
    if (_selfItem != null) {
      _selfItem!.isAudience = _session.audience;
    }
    setState(() {});
  }

  void _onToggleHandUp() {
    _conferenceManager.handUp(!_conferenceManager.isHandUp);
  }

  // --- Callbacks ---

  @override
  void onInitial(CallSession session, String initiatorId) {}

  @override
  void didCallEndWithReason(CallEndReason reason) {
    var durationMs = _duration.inMilliseconds;
    var info = Map<String, dynamic>.from(_conferenceManager.conferenceInfo);
    if (info.isNotEmpty) {
      ConferenceManager.addHistory(info, durationMs);
    }
    if (mounted) {
      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;
        final shell = isDesktopShell ? context.read<PCShellViewModel>() : null;
        if (shell != null && shell.activeCallSession != null) {
          shell.endCallSession();
        } else {
          final navigator = Navigator.of(context);
          // 成员弹层还开着时先关弹层,否则只能关掉弹层而退不出界面
          if (_memberSheetOpen) {
            _memberSheetOpen = false;
            navigator.pop();
          }
          navigator.pop();
        }
      });
    }
  }

  @override
  void didChangeState(CallState state) {
    if (mounted) {
      setState(() {});
      if (state == CallState.STATUS_CONNECTED) {
        _startTimer();
      }
    }
  }

  @override
  void didParticipantJoined(String userId, {bool screenSharing = false}) async {
    if (userId == Imclient.currentUserId) return;
    await _addParticipant(userId);
  }

  @override
  void didParticipantConnected(String userId, {bool screenSharing = false}) {}

  @override
  void didParticipantLeft(String userId, CallEndReason reason,
      {bool screenSharing = false}) {
    if (userId == Imclient.currentUserId) return;
    var item = _participants.remove(userId);
    if (item != null) item.renderer.dispose();
    if (mounted) setState(() {});
  }

  @override
  void didChangeMode(bool audioOnly) {
    if (mounted) setState(() {});
  }

  @override
  void didCreateLocalVideo(MediaStream stream, {bool screenSharing = false}) {
    if (_selfItem != null) {
      _selfItem!.renderer.srcObject = stream;
      if (mounted) setState(() {});
    }
  }

  @override
  void didScreenShareEnded() {}

  @override
  void didReceiveRemoteVideo(String userId, MediaStream stream,
      {bool screenSharing = false}) {
    var item = _participants[userId];
    if (item != null) {
      item.renderer.srcObject = stream;
      item.isScreenSharing = screenSharing;
      if (mounted) setState(() {});
    }
  }

  @override
  void didRemoveRemoteVideo(String userId) {
    var item = _participants[userId];
    if (item != null) {
      item.renderer.srcObject = null;
      if (mounted) setState(() {});
    }
  }

  @override
  void didReportAudioVolume(String userId, int volume) {
    if (userId == Imclient.currentUserId) {
      if (_selfItem != null) _selfItem!.volume = volume;
    } else {
      var item = _participants[userId];
      if (item != null) item.volume = volume;
    }
    if (mounted) setState(() {});
  }

  @override
  void didVideoMuted(String userId, bool muted) {
    if (userId == Imclient.currentUserId) {
      if (_selfItem != null) _selfItem!.videoMuted = muted;
    } else {
      var item = _participants[userId];
      if (item != null) item.videoMuted = muted;
    }
    if (mounted) setState(() {});
  }

  @override
  void didMuteStateChanged(List<String> participants) {
    for (var userId in participants) {
      if (userId == Imclient.currentUserId) continue;
      var profile = _session.getParticipantProfiles().firstWhere(
          (p) => p.userId == userId,
          orElse: () => ParticipantProfile(userId));
      var item = _participants[userId];
      if (item != null) {
        item.audioMuted = profile.audioMuted;
        item.videoMuted = profile.videoMuted;
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void didMediaLostPacket(String media, int lostPacket,
      {bool screenSharing = false}) {}

  @override
  void didUserMediaLostPacket(
      String userId, String media, int lostPacket, bool uplink,
      {bool screenSharing = false}) {}

  @override
  void didChangeInitiator(String initiator) {}

  @override
  void didChangeType(String userId, bool audience,
      {bool screenSharing = false}) {
    if (userId == Imclient.currentUserId) {
      if (_selfItem != null) _selfItem!.isAudience = audience;
    } else {
      var item = _participants[userId];
      if (item != null) item.isAudience = audience;
    }
    if (mounted) setState(() {});
  }

  @override
  void onRequestChangeMode(bool audience) {
    // Host requested audience/interactive switch
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(audience ? '主持人邀请您成为观众' : '主持人邀请您上麦'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('忽略'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _session.switchAudience(audience);
            },
            child: const Text('同意'),
          ),
        ],
      ),
    );
  }

  @override
  void onError(dynamic error) {}

  @override
  void didGetStats(List<StatsReport> reports) {}

  // --- 布局/焦点/订阅 ---

  List<ConferenceParticipantItem> get _allItems {
    List<ConferenceParticipantItem> items = [];
    if (_selfItem != null) items.add(_selfItem!);
    items.addAll(_participants.values);
    return items;
  }

  List<ConferenceParticipantItem> get _visibleItems => _allItems;

  /// PC 实际生效的布局:主持人设置了服务器焦点时强制演讲者视图(对齐 Electron)。
  int get _effectiveLayout {
    final hostFocus = _conferenceManager.currentFocusUser;
    if (hostFocus != null && hostFocus.isNotEmpty) return 1;
    return _currentLayout;
  }

  /// 排序:焦点 > 非观众 > 屏幕共享 > 开视频 > userId;
  /// 移动端最后把自己固定到第一位(网格第一格)。
  List<ConferenceParticipantItem> _sortItems(List<ConferenceParticipantItem> items) {
    final focusId = _conferenceManager.currentFocusUser;
    var sorted = List<ConferenceParticipantItem>.from(items);
    sorted.sort((a, b) {
      if (focusId != null && focusId.isNotEmpty) {
        if (a.userId == focusId) return -1;
        if (b.userId == focusId) return 1;
      }
      if (a.isAudience != b.isAudience) return a.isAudience ? 1 : -1;
      if (a.isScreenSharing != b.isScreenSharing) return a.isScreenSharing ? -1 : 1;
      if (a.videoMuted != b.videoMuted) return a.videoMuted ? 1 : -1;
      return a.userId.compareTo(b.userId);
    });
    if (!isDesktopShell) {
      var selfIndex = sorted.indexWhere((i) => i.userId == Imclient.currentUserId);
      if (selfIndex > 0) {
        var self = sorted.removeAt(selfIndex);
        sorted.insert(0, self);
      }
    }
    return sorted;
  }

  ConferenceParticipantItem? _resolveFocusItem(List<ConferenceParticipantItem> items) {
    // 1. 主持人设置的焦点
    var focusId = _conferenceManager.currentFocusUser;
    var focusItem = items.firstWhereOrNull((i) => i.userId == focusId && focusId != null && focusId.isNotEmpty);
    if (focusItem != null) return focusItem;

    // 2. 本地个人焦点
    var localFocusId = _localFocusUserId ?? _conferenceManager.localFocusUser;
    var localItem = items.firstWhereOrNull((i) => i.userId == localFocusId && localFocusId != null && localFocusId.isNotEmpty);
    if (localItem != null) return localItem;

    // 3. 正在屏幕共享者
    var screenSharer = items.firstWhereOrNull((i) => i.isScreenSharing);
    if (screenSharer != null) return screenSharer;

    // 4. 第一个未静音且有视频的用户
    var videoUser = items.firstWhereOrNull((i) => !i.isAudience && !i.videoMuted && i.renderer.srcObject != null);
    if (videoUser != null) return videoUser;

    return items.firstOrNull;
  }

  bool _isFocusUser(ConferenceParticipantItem item) {
    return _conferenceManager.currentFocusUser == item.userId ||
        (_localFocusUserId ?? _conferenceManager.localFocusUser) == item.userId;
  }

  /// 移动端焦点页预览小窗内容:通常是自己;双人且焦点是自己时显示对方;
  /// 多人且焦点是自己时不显示。
  ConferenceParticipantItem? _resolvePreviewItem(
      List<ConferenceParticipantItem> items, ConferenceParticipantItem? focus) {
    final self = _selfItem;
    if (self == null) return null;
    if (focus != null && focus.userId == self.userId) {
      if (items.length == 2) {
        return items.firstWhereOrNull((i) => i.userId != self.userId);
      }
      return null;
    }
    return self;
  }

  /// 双人时点击预览小窗交换大小画面(切换本地焦点)。主持人已设焦点时不交换。
  void _onSwapPreview() {
    final items = _visibleItems;
    if (items.length != 2) return;
    final hostFocus = _conferenceManager.currentFocusUser;
    if (hostFocus != null && hostFocus.isNotEmpty) return;
    final focus = _resolveFocusItem(items);
    final other = items.firstWhereOrNull((i) => i.userId != focus?.userId);
    if (other == null) return;
    setState(() {
      _localFocusUserId = other.userId;
      _conferenceManager.localFocusUser = other.userId;
    });
  }

  /// 统一大小流订阅调度:按平台/布局/页码/焦点计算每个参与者的目标订阅,
  /// 仅与缓存不一致时才下发 setParticipantVideoType。
  /// - 移动端:焦点 BIG;焦点页预览 SMALL;当前网格页 SMALL;其余 NONE。
  /// - PC 宫格:当前页全员 BIG,其余 NONE。
  /// - PC 演讲者:焦点 BIG,其余 SMALL。
  /// - 屏幕共享者恒 BIG;跳过自己(本地流无需订阅)。
  void _syncSubscriptions(
    List<ConferenceParticipantItem> sortedItems,
    ConferenceParticipantItem? focus,
    ConferenceParticipantItem? previewItem,
  ) {
    final desired = <String, int>{};
    for (var i = 0; i < sortedItems.length; i++) {
      final item = sortedItems[i];
      if (item.userId == Imclient.currentUserId) continue;

      int type;
      if (isDesktopShell) {
        if (_effectiveLayout == 0) {
          final start = _pcGridPage * ConferenceGridLayout.pageSize;
          type = (i >= start && i < start + ConferenceGridLayout.pageSize)
              ? VideoType.BIG_STREAM
              : VideoType.NONE;
        } else {
          type = item == focus ? VideoType.BIG_STREAM : VideoType.SMALL_STREAM;
        }
      } else {
        if (item == focus) {
          type = VideoType.BIG_STREAM;
        } else if (item == previewItem) {
          type = VideoType.SMALL_STREAM;
        } else if (_mobilePage > 0) {
          final start = (_mobilePage - 1) * 4;
          type = (i >= start && i < start + 4)
              ? VideoType.SMALL_STREAM
              : VideoType.NONE;
        } else {
          type = VideoType.NONE;
        }
      }
      if (item.isScreenSharing) type = VideoType.BIG_STREAM;
      desired[item.userId] = type;
    }

    desired.forEach((userId, type) {
      if (_subscriptionState[userId] != type) {
        final item = sortedItems.firstWhereOrNull((e) => e.userId == userId);
        _session.setParticipantVideoType(userId, item?.isScreenSharing ?? false, type);
        _subscriptionState[userId] = type;
      }
    });
    _subscriptionState.removeWhere((userId, _) => !desired.containsKey(userId));
  }

  String _participantName(UserInfo? info) {
    if (info == null) return '';
    return info.getReadableName();
  }

  String get _speakingUserName {
    int maxVolume = _selfItem?.volume ?? 0;
    ConferenceParticipantItem? speaking = _selfItem;
    for (var item in _participants.values) {
      if (item.volume > maxVolume) {
        maxVolume = item.volume;
        speaking = item;
      }
    }
    if (maxVolume <= 0 || speaking == null) return '';
    return speaking.userId == Imclient.currentUserId
        ? '我'
        : _participantName(speaking.userInfo);
  }

  // --- UI Building ---

  @override
  Widget build(BuildContext context) {
    var l10n = AppLocalizations.of(context)!;
    var items = _visibleItems;
    var sortedItems = _sortItems(items);
    var focus = _resolveFocusItem(items);
    var previewItem = isDesktopShell ? null : _resolvePreviewItem(items, focus);
    var speakingName = _speakingUserName;

    // 布局/页码/焦点变化统一反映到大小流订阅(内部有缓存,未变化时不发信令)
    _syncSubscriptions(sortedItems, focus, previewItem);

    return Scaffold(
      backgroundColor: context.colors.primaryBackground,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(l10n, speakingName),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: items.isEmpty
                            ? Center(
                                child: CircularProgressIndicator(
                                    color: context.colors.textPrimary))
                            : isDesktopShell
                                ? (_effectiveLayout == 0
                                    ? ConferenceGridLayout(
                                        items: sortedItems,
                                        audioOnly: _session.audioOnly,
                                        isFocusUser: _isFocusUser,
                                        onDoubleTapTile: _onDoubleTapVideo,
                                        onPageChanged: (page) =>
                                            setState(() => _pcGridPage = page),
                                      )
                                    : ConferenceSpeakerLayout(
                                        focusItem: focus,
                                        others: sortedItems
                                            .where((i) => i != focus)
                                            .toList(),
                                        audioOnly: _session.audioOnly,
                                        isFocusUser: _isFocusUser,
                                        onDoubleTapTile: _onDoubleTapVideo,
                                      ))
                                : ConferenceMobileLayout(
                                    items: sortedItems,
                                    focusItem: focus,
                                    previewItem: previewItem,
                                    audioOnly: _session.audioOnly,
                                    focusKey: focus?.userId,
                                    isFocusUser: _isFocusUser,
                                    onDoubleTapTile: _onDoubleTapVideo,
                                    onSwapPreview: _onSwapPreview,
                                    onPageChanged: (page) =>
                                        setState(() => _mobilePage = page),
                                  ),
                      ),
                      if (isDesktopShell && _showMemberList)
                        SizedBox(
                          width: 260,
                          child: ConferenceParticipantListView(
                            session: _session,
                            conferenceManager: _conferenceManager,
                            onClose: _onToggleMemberList,
                          ),
                        ),
                    ],
                  ),
                ),
                _buildActionButtons(l10n),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n, String speakingName) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _session.title.isNotEmpty ? _session.title : l10n.conferenceTitle,
                  style: AppText.base.copyWith(
                      color: context.colors.textPrimary, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _session.status == CallState.STATUS_CONNECTED
                      ? _formatDuration(_duration)
                      : _session.status == CallState.STATUS_INCOMING
                          ? '邀请您加入会议'
                          : '连接中...',
                  style: AppText.sm.copyWith(color: context.colors.textSecondary),
                ),
                if (speakingName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '正在讲话: $speakingName',
                    style: AppText.sm.copyWith(
                        color: context.colors.success,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.people_outline, color: context.colors.textSecondary),
            onPressed: _onToggleMemberList,
            tooltip: l10n.conferenceMemberList,
          ),
          // 布局切换仅 PC 提供;移动端只有"焦点页+网格分页"一种布局
          if (isDesktopShell)
            PopupMenuButton<int>(
              icon: Icon(Icons.view_comfy_outlined, color: context.colors.textSecondary),
              tooltip: l10n.conferenceLayout,
              onSelected: _onLayoutChanged,
              itemBuilder: (context) => [
                PopupMenuItem(value: 0, child: Text(l10n.conferenceGridView)),
                PopupMenuItem(value: 1, child: Text(l10n.conferenceSpeakerView)),
              ],
            ),
        ],
      ),
    );
  }

  void _onDoubleTapVideo(ConferenceParticipantItem item) {
    if (_conferenceManager.isOwner) {
      if (_conferenceManager.currentFocusUser == item.userId) {
        _conferenceManager.requestCancelFocus();
      } else {
        _conferenceManager.requestFocus(item.userId);
      }
    } else {
      if (_conferenceManager.currentFocusUser != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.conferenceHostFocusSet)),
        );
      } else {
        setState(() {
          _localFocusUserId = item.userId;
          _conferenceManager.localFocusUser = item.userId;
        });
      }
    }
  }

  Widget _buildActionButtons(AppLocalizations l10n) {
    if (_session.status == CallState.STATUS_INCOMING) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CallActionButton(
            icon: Icons.call_end,
            backgroundColor: context.colors.danger,
            onPressed: _onHangup,
            label: l10n.callDecline,
          ),
          _CallActionButton(
            icon: Icons.call,
            backgroundColor: context.colors.success,
            onPressed: _onAccept,
            label: l10n.callAnswer,
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _CallActionButton(
              icon: _isMicMuted ? Icons.mic_off : Icons.mic_none,
              backgroundColor:
                  _isMicMuted ? Colors.white : Colors.white.withValues(alpha: 0.1),
              iconColor: _isMicMuted ? Colors.black87 : Colors.white,
              onPressed: _onToggleMic,
              label: l10n.callMute,
            ),
            _CallActionButton(
              icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
              backgroundColor:
                  _isCameraOff ? Colors.white : Colors.white.withValues(alpha: 0.1),
              iconColor: _isCameraOff ? Colors.black87 : Colors.white,
              onPressed: _onToggleCamera,
              label: _isCameraOff ? l10n.callCameraOn : l10n.callCameraOff,
            ),
            _CallActionButton(
              icon: Icons.call_end,
              backgroundColor: context.colors.danger,
              onPressed: _onHangup,
              label: l10n.callHangup,
            ),
            _CallActionButton(
              icon: Icons.screen_share_outlined,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              onPressed: _onScreenShare,
              label: l10n.conferenceScreenShare,
            ),
            _CallActionButton(
              icon: Icons.people_outline,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              onPressed: _onToggleMemberList,
              label: l10n.conferenceMemberList,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _CallActionButton(
              icon: Icons.cameraswitch_outlined,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              onPressed: _onSwitchCamera,
              label: l10n.callSwitchCamera,
            ),
            _CallActionButton(
              icon: _session.audience ? Icons.person_outline : Icons.record_voice_over,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              onPressed: _onSwitchAudience,
              label: _session.audience ? '上麦' : '下麦',
            ),
            if (!_conferenceManager.isOwner)
              _CallActionButton(
                icon: _conferenceManager.isHandUp ? Icons.pan_tool : Icons.pan_tool_outlined,
                backgroundColor: _conferenceManager.isHandUp
                    ? context.colors.success
                    : Colors.white.withValues(alpha: 0.1),
                onPressed: _onToggleHandUp,
                label: _conferenceManager.isHandUp ? l10n.conferenceHandUpDone : l10n.conferenceHandUp,
              ),
            _CallActionButton(
              icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_mute_outlined,
              backgroundColor:
                  _isSpeakerOn ? Colors.white : Colors.white.withValues(alpha: 0.1),
              iconColor: _isSpeakerOn ? Colors.black87 : Colors.white,
              onPressed: _onToggleSpeaker,
              label: l10n.callSpeaker,
            ),
          ],
        ),
      ],
    );
  }
}

class _CallActionButton extends StatefulWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final String label;
  final VoidCallback onPressed;

  const _CallActionButton({
    required this.icon,
    required this.backgroundColor,
    this.iconColor = Colors.white,
    required this.label,
    required this.onPressed,
  });

  @override
  State<_CallActionButton> createState() => _CallActionButtonState();
}

class _CallActionButtonState extends State<_CallActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: widget.onPressed,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            cursor: SystemMouseCursors.click,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 52,
              height: 52,
              transform: Matrix4.identity()..scale(_isHovered ? 1.06 : 1.0),
              transformAlignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.backgroundColor,
                boxShadow: [
                  if (_isHovered)
                    BoxShadow(
                      color: widget.backgroundColor.withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    )
                ],
              ),
              child: Icon(
                widget.icon,
                color: widget.iconColor,
                size: 24,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.label,
          style: AppText.xs.copyWith(
              color: context.colors.textSecondary,
              fontWeight: FontWeight.w400),
        ),
      ],
    );
  }
}
