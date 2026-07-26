import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:avenginekit/engine/call_session.dart';
import 'package:avenginekit/engine/call_session_callback.dart';
import 'package:avenginekit/engine/call_state.dart';
import 'package:avenginekit/engine/call_end_reason.dart';
import 'package:avenginekit/engine/participant_profile.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:provider/provider.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/config.dart';
import 'package:chat/call/call_overlay_manager.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/pc_shell_view_model.dart';
import 'package:chat/contact/pick_user_screen.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/theme/app_typography.dart';

class _ParticipantItem {
  final String userId;
  UserInfo? userInfo;
  RTCVideoRenderer renderer;
  bool videoMuted = false;
  bool audioMuted = false;
  bool isScreenSharing = false;
  int volume = 0;

  /// 说话状态(音量>0 且未静音),仅状态翻转时通知,
  /// 供说话绿框/角标局部刷新,避免音量高频上报触发整页重建。
  final ValueNotifier<bool> speakingNotifier = ValueNotifier(false);

  _ParticipantItem({required this.userId, required this.renderer});

  void dispose() {
    speakingNotifier.dispose();
  }
}

class MultiCallScreen extends StatefulWidget {
  final CallSession session;

  const MultiCallScreen({Key? key, required this.session}) : super(key: key);

  @override
  State<MultiCallScreen> createState() => _MultiCallScreenState();
}

class _MultiCallScreenState extends State<MultiCallScreen>
    implements CallSessionCallback {
  late CallSession _session;
  final Map<String, _ParticipantItem> _participants = {};
  _ParticipantItem? _selfItem;
  bool _isMicMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = false;
  bool _callEnded = false;
  Duration _duration = Duration.zero;
  Timer? _timer;

  /// 通话时长秒数,走秒 Timer 仅更新该 notifier,避免每秒重建整页。
  final ValueNotifier<int> _durationSeconds = ValueNotifier(0);

  /// 正在讲话人名字,音量高频上报时仅内容变化才通知,供顶部栏局部刷新。
  final ValueNotifier<String> _speakingUserNameNotifier = ValueNotifier('');

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _session.setCallback(this);
    _isMicMuted = _session.isAudioMuted;
    _isCameraOff = _session.isVideoMuted;
    // 从最小化悬浮窗恢复时，交接悬浮窗期间的通话时长
    if (CallOverlayManager.instance.isMinimized) {
      _duration = CallOverlayManager.instance.currentDuration;
      _durationSeconds.value = _duration.inSeconds;
    }
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
    if (mounted) {
      setState(() {});
    }
    _updateSelfStream();
  }

  Future<void> _initRemoteParticipants() async {
    var ids = _session.getParticipantIds();
    for (var uid in ids) {
      if (uid == Imclient.currentUserId) continue;
      await _addParticipant(uid);
    }
  }

  Future<void> _addParticipant(String userId) async {
    if (_participants.containsKey(userId)) return;
    var renderer = RTCVideoRenderer();
    await renderer.initialize();
    var item = _ParticipantItem(userId: userId, renderer: renderer);
    var info = await Imclient.getUserInfo(userId);
    item.userInfo = info;
    _participants[userId] = item;

    // Try to bind existing stream
    var stream = _session.getParticipantVideoStream(userId);
    if (stream != null) {
      item.renderer.srcObject = stream;
    }

    if (mounted) {
      setState(() {});
    }
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
    _durationSeconds.dispose();
    _speakingUserNameNotifier.dispose();
    _selfItem?.renderer.dispose();
    _selfItem?.dispose();
    for (var item in _participants.values) {
      item.renderer.dispose();
      item.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        // 仅更新时长 notifier,由 ValueListenableBuilder 局部刷新时长文本
        _duration += const Duration(seconds: 1);
        _durationSeconds.value = _duration.inSeconds;
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
    _session.muteAudio(!_isMicMuted);
    setState(() {
      _isMicMuted = !_isMicMuted;
      if (_selfItem != null) {
        _selfItem!.audioMuted = _isMicMuted;
      }
    });
    if (_selfItem != null) _updateSpeaking(_selfItem!);
  }

  void _onToggleCamera() {
    _session.muteVideo(!_isCameraOff);
    setState(() {
      _isCameraOff = !_isCameraOff;
      if (_selfItem != null) {
        _selfItem!.videoMuted = _isCameraOff;
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

  void _onDowngradeToVoice() {
    _session.downgrade2Voice();
  }

  /// 最小化为悬浮窗：只 pop 界面，不挂断通话。
  /// 未接通时把状态文案传给悬浮窗（接通后悬浮窗自动转为走秒）。
  void _onMinimize() {
    CallOverlayManager.instance.minimize(
      screenBuilder: () => MultiCallScreen(session: _session),
      baseDuration: _duration,
      audioOnly: _session.audioOnly,
      statusText: _session.status == CallState.STATUS_CONNECTED
          ? null
          : _statusLabel(AppLocalizations.of(context)!),
    );
    Navigator.of(context).pop();
  }

  Future<void> _onInvite() async {
    if (_session.conversation == null) return;
    List<String> candidates = [];
    if (_session.conversation!.conversationType == ConversationType.Group) {
      var members = await Imclient.getGroupMembers(_session.conversation!.target);
      candidates = members.map((m) => m.memberId).toList();
    }
    candidates.removeWhere((uid) => uid == Imclient.currentUserId || _session.getParticipantIds().contains(uid));

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无可邀请成员')),
      );
      return;
    }

    if (!mounted) return;
    showPickUserScreen(
      context,
      (dialogContext, pickedUsers) {
        if (pickedUsers.isNotEmpty) {
          _session.inviteNewParticipants(pickedUsers);
        }
        Navigator.of(dialogContext).pop();
      },
      title: '邀请成员',
      maxSelected: 9,
      candidates: candidates,
      showOrganizationEntry: false,
    );
  }

  String _statusLabel(AppLocalizations l10n) {
    if (_callEnded) return l10n.callStatusEnded;
    switch (_session.status) {
      case CallState.STATUS_IDLE:
        return l10n.callStatusEnded;
      case CallState.STATUS_OUTGOING:
        return l10n.callStatusCalling;
      case CallState.STATUS_INCOMING:
        return l10n.callIncomingInvite;
      case CallState.STATUS_CONNECTING:
        return l10n.callStatusConnecting;
      case CallState.STATUS_CONNECTED:
        return '';
    }
  }

  // --- CallSessionCallback ---

  @override
  void onInitial(CallSession session, String initiatorId) {}

  @override
  void didCallEndWithReason(CallEndReason reason) {
    // 可能正处于最小化状态（界面已 pop 但 State 仍在），先清理悬浮窗
    CallOverlayManager.instance.onCallEnded();
    if (mounted) {
      setState(() {
        _callEnded = true;
      });
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

  }

  @override
  void didParticipantConnected(String userId, {bool screenSharing = false}) {
    if (userId == Imclient.currentUserId) return;
    _addParticipant(userId);
  }

  @override
  void didParticipantLeft(String userId, CallEndReason reason,
      {bool screenSharing = false}) {
    if (userId == Imclient.currentUserId) return;
    var item = _participants.remove(userId);
    if (item != null) {
      item.renderer.dispose();
      item.dispose();
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeMode(bool audioOnly) {
    if (mounted) {
      setState(() {
        _isCameraOff = _session.isVideoMuted;
      });
    }
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
    // 音量上报频率高(每秒多次),不 setState 重建整页:
    // 音量存到 item 普通字段,说话绿框与"正在讲话"由 ValueNotifier 局部刷新。
    _ParticipantItem? item;
    if (userId == Imclient.currentUserId) {
      item = _selfItem;
    } else {
      item = _participants[userId];
    }
    if (item == null) return;
    item.volume = volume;
    _updateSpeaking(item);
    var speakingName = _speakingUserName;
    if (_speakingUserNameNotifier.value != speakingName) {
      _speakingUserNameNotifier.value = speakingName;
    }
  }

  /// 说话状态(音量>0 且未静音)翻转时才通知,驱动说话绿框/角标局部刷新。
  void _updateSpeaking(_ParticipantItem item) {
    var speaking = item.volume > 0 && !item.audioMuted;
    if (item.speakingNotifier.value != speaking) {
      item.speakingNotifier.value = speaking;
    }
  }

  @override
  void didVideoMuted(String userId, bool muted) {
    if (userId == Imclient.currentUserId) {
      if (_selfItem != null) {
        _selfItem!.videoMuted = muted;
      }
    } else {
      var item = _participants[userId];
      if (item != null) {
        item.videoMuted = muted;
      }
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
        _updateSpeaking(item);
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
      {bool screenSharing = false}) {}

  @override
  void onRequestChangeMode(bool audience) {}

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
    bool isVideoCall = !_session.audioOnly;
    var l10n = AppLocalizations.of(context)!;
    var items = _allItems;

    return Scaffold(
      backgroundColor: const Color(0xFF0F121B),
      body: Stack(
        children: [
          // 语音通话时给整个页面加一个柔和背景
          if (!isVideoCall) _buildAudioBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(l10n, items.length),
                Expanded(
                  child: items.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white))
                      : _buildGrid(items, isVideoCall),
                ),
                _buildActionButtons(isVideoCall, l10n),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 顶部信息栏：未接通时显示状态，接通后显示时长、当前人数、正在讲话人
  Widget _buildHeader(AppLocalizations l10n, int participantCount) {
    final bool isConnected = _session.status == CallState.STATUS_CONNECTED;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 时长走秒,用 ValueNotifier 局部刷新,不重建整页
                ValueListenableBuilder<int>(
                  valueListenable: _durationSeconds,
                  builder: (context, seconds, child) {
                    return Text(
                      isConnected ? _formatDuration(Duration(seconds: seconds)) : _statusLabel(l10n),
                      style: AppText.base.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    );
                  },
                ),
                const SizedBox(height: 4),
                // "正在讲话"随音量上报高频变化,用 ValueNotifier 局部刷新,不重建整页
                ValueListenableBuilder<String>(
                  valueListenable: _speakingUserNameNotifier,
                  builder: (context, speakingName, child) {
                    return Text(
                      '$participantCount 人通话${speakingName.isNotEmpty ? ' · 正在讲话: $speakingName' : ''}',
                      style: AppText.sm.copyWith(color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ],
            ),
          ),
          // 最小化为悬浮窗（仅移动端）
          if (!isDesktopShell)
            IconButton(
              icon: const Icon(Icons.photo_size_select_small_rounded,
                  color: Colors.white70),
              onPressed: _onMinimize,
            ),
        ],
      ),
    );
  }

  /// 语音通话背景（头像高斯模糊 + 渐变遮罩）
  Widget _buildAudioBackground() {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E2638), Color(0xFF0F121B)],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(List<_ParticipantItem> items, bool isVideoCall) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = items.length;
        int crossAxisCount;
        if (count == 1) {
          crossAxisCount = 1;
        } else if (count <= 4) {
          crossAxisCount = 2;
        } else {
          crossAxisCount = 3;
        }
        final rows = (count / crossAxisCount).ceil();
        final hSpacing = 8.0 * (crossAxisCount - 1);
        final vSpacing = 8.0 * (rows - 1);
        final availableW = constraints.maxWidth - hSpacing - 24; // 左右 padding 12
        final availableH = constraints.maxHeight - vSpacing - 24; // 上下 padding 12
        final cellW = availableW / crossAxisCount;
        final cellH = availableH / rows;
        final aspectRatio = cellW / cellH;

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: aspectRatio > 0 ? aspectRatio : 1,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return _buildParticipantCell(items[index], isVideoCall);
          },
        );
      },
    );
  }

  Widget _buildParticipantCell(_ParticipantItem item, bool isVideoCall) {
    bool isSelf = item.userId == Imclient.currentUserId;
    bool showVideo = isVideoCall && !item.videoMuted && item.renderer.srcObject != null;
    String name = isSelf ? '我' : _participantName(item.userInfo);

    // 说话指示(绿框/角标)由 item.speakingNotifier 驱动局部刷新,
    // 音量高频上报时不再随整页 setState 重建 RTCVideoView。
    return ValueListenableBuilder<bool>(
      valueListenable: item.speakingNotifier,
      builder: (context, isSpeaking, child) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E2638),
            borderRadius: BorderRadius.circular(12),
            border: isSpeaking
                ? Border.all(color: const Color(0xFF07C160), width: 2)
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (showVideo)
                  RTCVideoView(
                    item.renderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    mirror: isSelf,
                  )
                else
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF1E2638), Color(0xFF0F121B)],
                      ),
                    ),
                    child: Center(
                      child: Portrait(
                        item.userInfo?.portrait ?? '',
                        Config.defaultUserPortrait,
                        width: 72,
                        height: 72,
                        borderRadius: 36,
                      ),
                    ),
                  ),
                // 摄像头关闭提示
                if (isVideoCall && item.videoMuted)
                  const Center(
                    child: Icon(Icons.videocam_off,
                        color: Colors.white54, size: 36),
                  ),
                // 底部信息条：名字 + 静音状态
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (item.audioMuted)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.mic_off,
                                color: Colors.white70, size: 14),
                          ),
                        Flexible(
                          child: Text(
                            name,
                            style: AppText.sm.copyWith(color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 正在讲话角标
                if (isSpeaking)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF07C160).withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.volume_up,
                          color: Colors.white, size: 14),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(bool isVideoCall, AppLocalizations l10n) {
    if (_session.status == CallState.STATUS_INCOMING) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CallActionButton(
            icon: Icons.call_end,
            backgroundColor: const Color(0xFFFA5151),
            onPressed: _onHangup,
            label: l10n.callDecline,
          ),
          _CallActionButton(
            icon: Icons.call,
            backgroundColor: const Color(0xFF07C160),
            onPressed: _onAccept,
            label: l10n.callAnswer,
          ),
          if (isVideoCall)
            _CallActionButton(
              icon: Icons.phone_in_talk_outlined,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              onPressed: _onDowngradeToVoice,
              label: l10n.callAnswerAudio,
            ),
        ],
      );
    } else if (_session.status == CallState.STATUS_CONNECTED) {
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
                icon: Icons.call_end,
                backgroundColor: const Color(0xFFFA5151),
                onPressed: _onHangup,
                label: l10n.callHangup,
              ),
              if (isVideoCall)
                _CallActionButton(
                  icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                  backgroundColor:
                      _isCameraOff ? Colors.white : Colors.white.withValues(alpha: 0.1),
                  iconColor: _isCameraOff ? Colors.black87 : Colors.white,
                  onPressed: _onToggleCamera,
                  label: _isCameraOff ? l10n.callCameraOn : l10n.callCameraOff,
                )
              else
                _CallActionButton(
                  icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_mute_outlined,
                  backgroundColor:
                      _isSpeakerOn ? Colors.white : Colors.white.withValues(alpha: 0.1),
                  iconColor: _isSpeakerOn ? Colors.black87 : Colors.white,
                  onPressed: _onToggleSpeaker,
                  label: l10n.callSpeaker,
                ),
              if (_participants.length < 8)
                _CallActionButton(
                  icon: Icons.person_add,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  onPressed: _onInvite,
                  label: '邀请',
                ),
            ],
          ),
          if (isVideoCall) ...[
            const SizedBox(height: 16),
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
        ],
      );
    } else {
      // Outgoing / Connecting
      return Row(
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
            icon: Icons.call_end,
            backgroundColor: const Color(0xFFFA5151),
            onPressed: _onHangup,
            label: l10n.cancel,
          ),
          if (isVideoCall)
            _CallActionButton(
              icon: Icons.cameraswitch_outlined,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              onPressed: _onSwitchCamera,
              label: l10n.callSwitchCamera,
            )
          else
            _CallActionButton(
              icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_mute_outlined,
              backgroundColor:
                  _isSpeakerOn ? Colors.white : Colors.white.withValues(alpha: 0.1),
              iconColor: _isSpeakerOn ? Colors.black87 : Colors.white,
              onPressed: _onToggleSpeaker,
              label: l10n.callSpeaker,
            ),
        ],
      );
    }
  }
}

class _CallActionButton extends StatefulWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final String label;
  final VoidCallback onPressed;
  final bool isActive;

  const _CallActionButton({
    required this.icon,
    required this.backgroundColor,
    this.iconColor = Colors.white,
    required this.label,
    required this.onPressed,
    this.isActive = true,
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
              width: 56,
              height: 56,
              transform: Matrix4.identity()..scale(_isHovered ? 1.06 : 1.0),
              transformAlignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isActive ? widget.backgroundColor : Colors.white12,
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
                color: widget.isActive ? widget.iconColor : Colors.white60,
                size: 26,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.label,
          style: AppText.xs.copyWith(
              color: widget.isActive ? Colors.white70 : Colors.white38,
              fontWeight: FontWeight.w400),
        ),
      ],
    );
  }
}
