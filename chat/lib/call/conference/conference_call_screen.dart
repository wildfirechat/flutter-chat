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
import 'package:chat/widget/portrait.dart';
import 'package:chat/config.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/pc_shell_view_model.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/theme/app_colors.dart';

import 'conference_manager.dart';
import 'conference_participant_list_view.dart';

class _ParticipantItem {
  final String userId;
  UserInfo? userInfo;
  RTCVideoRenderer renderer;
  bool videoMuted = false;
  bool audioMuted = false;
  bool isScreenSharing = false;
  bool isAudience = false;
  int volume = 0;

  _ParticipantItem({required this.userId, required this.renderer});
}

extension _FirstWhereOrNullExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

class ConferenceCallScreen extends StatefulWidget {
  final CallSession session;

  const ConferenceCallScreen({Key? key, required this.session}) : super(key: key);

  @override
  State<ConferenceCallScreen> createState() => _ConferenceCallScreenState();
}

class _ConferenceCallScreenState extends State<ConferenceCallScreen>
    implements CallSessionCallback {
  late CallSession _session;
  final Map<String, _ParticipantItem> _participants = {};
  _ParticipantItem? _selfItem;
  bool _isMicMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = false;
  bool _showMemberList = false;
  int _currentLayout = 0; // 0 grid, 1 speaker
  String? _localFocusUserId;
  Duration _duration = Duration.zero;
  Timer? _timer;
  late ConferenceManager _conferenceManager;

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
    _selfItem = _ParticipantItem(userId: Imclient.currentUserId, renderer: renderer);
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
    var item = _ParticipantItem(userId: userId, renderer: renderer);
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
    setState(() {
      _showMemberList = !_showMemberList;
    });
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
          Navigator.of(context).pop();
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

  // --- UI Building ---

  List<_ParticipantItem> get _allItems {
    List<_ParticipantItem> items = [];
    if (_selfItem != null) items.add(_selfItem!);
    items.addAll(_participants.values);
    return items;
  }

  List<_ParticipantItem> get _visibleItems {
    var items = _allItems;
    // Filter audience without video in speaker mode? Keep simple for now
    return items;
  }

  String _participantName(UserInfo? info) {
    if (info == null) return '';
    return info.getReadableName();
  }

  String get _speakingUserName {
    int maxVolume = _selfItem?.volume ?? 0;
    _ParticipantItem? speaking = _selfItem;
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

  @override
  Widget build(BuildContext context) {
    var l10n = AppLocalizations.of(context)!;
    var items = _visibleItems;
    var speakingName = _speakingUserName;

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
                            : _currentLayout == 0
                                ? _buildGrid(items)
                                : _buildSpeakerLayout(items),
                      ),
                      if (_showMemberList)
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
          PopupMenuButton<int>(
            icon: Icon(Icons.view_comfy_outlined, color: context.colors.textSecondary),
            tooltip: '布局',
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

  Widget _buildGrid(List<_ParticipantItem> items) {
    var focusId = _conferenceManager.currentFocusUser;
    var sortedItems = List<_ParticipantItem>.from(items);
    sortedItems.sort((a, b) {
      if (a.userId == focusId) return -1;
      if (b.userId == focusId) return 1;
      if (a.isScreenSharing && !b.isScreenSharing) return -1;
      if (!a.isScreenSharing && b.isScreenSharing) return 1;
      if (!a.videoMuted && b.videoMuted) return -1;
      if (a.videoMuted && !b.videoMuted) return 1;
      return a.userId.compareTo(b.userId);
    });

    int crossAxisCount = sortedItems.length <= 2
        ? 1
        : sortedItems.length <= 4
            ? 2
            : 3;
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.2,
      ),
      itemCount: sortedItems.length,
      itemBuilder: (context, index) => _buildParticipantCell(sortedItems[index]),
    );
  }

  _ParticipantItem? _resolveFocusItem(List<_ParticipantItem> items) {
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

  void _applyFocusVideoType(_ParticipantItem? newFocus, _ParticipantItem? oldFocus) {
    if (oldFocus != null && oldFocus.userId != Imclient.currentUserId && oldFocus.userId.isNotEmpty) {
      _session.setParticipantVideoType(oldFocus.userId, oldFocus.isScreenSharing, VideoType.SMALL_STREAM);
    }
    if (newFocus != null && newFocus.userId != Imclient.currentUserId && newFocus.userId.isNotEmpty) {
      _session.setParticipantVideoType(newFocus.userId, newFocus.isScreenSharing, VideoType.BIG_STREAM);
    }
  }

  Widget _buildSpeakerLayout(List<_ParticipantItem> items) {
    var focus = _resolveFocusItem(items);
    var previousFocus = _previousFocusItem;
    if (focus?.userId != previousFocus?.userId) {
      _applyFocusVideoType(focus, previousFocus);
      _previousFocusItem = focus;
    }

    return Column(
      children: [
        if (focus != null)
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _buildParticipantCell(focus, isFocus: true),
            ),
          ),
        if (items.length > 1)
          Expanded(
            flex: 1,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                var item = items[index];
                if (item == focus) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 140,
                    child: _buildParticipantCell(item),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  _ParticipantItem? _previousFocusItem;

  Widget _buildParticipantCell(_ParticipantItem item, {bool isFocus = false}) {
    bool isSelf = item.userId == Imclient.currentUserId;
    bool showVideo = !_session.audioOnly &&
        !item.videoMuted &&
        item.renderer.srcObject != null;
    bool isSpeaking = item.volume > 0 && !item.audioMuted;
    bool isFocusUser = _conferenceManager.currentFocusUser == item.userId ||
        (_localFocusUserId ?? _conferenceManager.localFocusUser) == item.userId;

    return GestureDetector(
      onDoubleTap: () => _onDoubleTapVideo(item),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: isSpeaking || isFocusUser
              ? Border.all(
                  color: isFocusUser ? context.colors.warning : context.colors.success,
                  width: 2)
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              if (showVideo)
                RTCVideoView(
                  item.renderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  mirror: isSelf,
                )
              else
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [context.colors.surface, context.colors.primaryBackground],
                    ),
                  ),
                  child: Center(
                    child: Portrait(
                      item.userInfo?.portrait ?? '',
                      Config.defaultUserPortrait,
                      width: isFocus ? 96 : 64,
                      height: isFocus ? 96 : 64,
                      borderRadius: isFocus ? 48 : 32,
                    ),
                  ),
                ),
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (item.audioMuted)
                      Icon(Icons.mic_off, color: context.colors.textSecondary, size: 16),
                    if (item.isAudience)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(AppLocalizations.of(context)!.conferenceAudience,
                            style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
                      ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        isSelf ? '我' : _participantName(item.userInfo),
                        style: AppText.sm.copyWith(color: context.colors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (isFocusUser)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Icon(Icons.highlight, color: context.colors.warning, size: 20),
                ),
              if (item.volume > 0 && !item.audioMuted)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: context.colors.success.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.volume_up, color: context.colors.textPrimary, size: 14),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _onDoubleTapVideo(_ParticipantItem item) {
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
