import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:avenginekit/engine/call_session.dart';
import 'package:avenginekit/engine/call_session_callback.dart';
import 'package:avenginekit/engine/call_state.dart';
import 'package:avenginekit/engine/call_end_reason.dart';
import 'package:avenginekit/engine/participant_profile.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:provider/provider.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/config.dart';
import 'package:chat/call/call_overlay_manager.dart';
import 'package:chat/pc/pc_shell_view_model.dart';
import 'package:chat/utils/media_url_redirector.dart';
import 'package:chat/utils/mesh_user_name.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/app_shell.dart';

class VoipCallScreen extends StatefulWidget {
  final CallSession session;

  const VoipCallScreen({Key? key, required this.session}) : super(key: key);

  @override
  State<VoipCallScreen> createState() => _VoipCallScreenState();
}

class _VoipCallScreenState extends State<VoipCallScreen>
    implements CallSessionCallback {
  late CallSession _session;
  UserInfo? _targetUserInfo;
  bool _isMicMuted = false;
  bool _isSpeakerOn = false;
  bool _isCameraOff = false;
  bool _isSwapped = false;
  bool _remoteVideoMuted = false;
  Duration _duration = Duration.zero;
  Timer? _timer;

  /// 通话时长秒数,走秒 Timer 仅更新该 notifier,避免每秒重建整页。
  final ValueNotifier<int> _durationSeconds = ValueNotifier(0);

  /// 小窗（画中画）位置和尺寸
  Offset _pipPosition = const Offset(20, 100);
  static const double _pipWidth = 120;
  static const double _pipHeight = 180;

  /// 已收到结束回调、等待关闭页面期间,状态文案固定为“通话结束”。
  bool _callEnded = false;

  // Video renderers
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

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
    _loadTargetInfo();

    _initRenderers().then((_) {
      if (mounted) {
        setState(() {
          _refreshRenderers();
          _updateRemoteVideoMuted();
          if (_session.status == CallState.STATUS_CONNECTED) {
            _startTimer();
          }
        });
      }
    });
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  /// 重新绑定当前可用的本地/远端视频流
  void _refreshRenderers() {
    _updateLocalRender();
    _updateRemoteRender();
  }

  String get _remoteUserId {
    var participants = _session.getParticipantIds();
    return participants.firstWhere((uid) => uid != Imclient.currentUserId,
        orElse: () => '');
  }

  void _updateRemoteVideoMuted() {
    final targetId = _remoteUserId;
    if (targetId.isEmpty) return;
    final profile = _session.getParticipantProfiles().firstWhere(
          (p) => p.userId == targetId,
          orElse: () => ParticipantProfile(targetId),
        );
    _remoteVideoMuted = profile.videoMuted;
  }

  void _updateLocalRender() {
    var stream = _session.getParticipantVideoStream(Imclient.currentUserId);
    if (stream != null && _localRenderer.srcObject != stream) {
      _localRenderer.srcObject = stream;
    }
  }

  void _updateRemoteRender() {
    final targetId = _remoteUserId;
    if (targetId.isNotEmpty) {
      var stream = _session.getParticipantVideoStream(targetId);
      if (stream != null && _remoteRenderer.srcObject != stream) {
        _remoteRenderer.srcObject = stream;
      }
    }
  }

  @override
  void dispose() {
    _stopTimer();
    _durationSeconds.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    // Do not end call here, the session might outlive the screen if minimized (not implemented yet)
    // But for now, if screen closes, we probably want to hangup if not connected?
    // Or depends on navigation.
    super.dispose();
  }

  void _loadTargetInfo() async {
    String targetId;
    if (_session.status == CallState.STATUS_INCOMING) {
      targetId = _session.initiatorId;
    } else {
      var participants = _session.getParticipantIds();
      targetId = participants.firstWhere((uid) => uid != Imclient.currentUserId,
          orElse: () => '');
    }

    if (targetId.isNotEmpty) {
      var userInfo = await Imclient.getUserInfo(targetId);
      if (mounted) {
        setState(() {
          _targetUserInfo = userInfo;
        });
      }
    }
  }

  String _statusLabel(AppLocalizations l10n) {
    if (_callEnded) {
      return l10n.callStatusEnded;
    }
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
    // Navigate back will be handled in didCallEndWithReason
  }

  void _onAccept() {
    _session.answerCall(_session.audioOnly);
  }

  void _onToggleMic() {
    _session.muteAudio(!_isMicMuted);
    setState(() {
      _isMicMuted = !_isMicMuted;
    });
  }

  void _onSwitchCamera() {
    _session.switchCamera();
  }

  void _onToggleCamera() {
    _session.muteVideo(!_isCameraOff); // muteVideo means disable video sending
    setState(() {
      _isCameraOff = !_isCameraOff;
    });
  }

  void _onToggleSpeaker() {
    // _session.enableSpeaker(!_isSpeakerOn); // Need to check if this API exists in CallSession
    // In avenginekit/lib/engine/call_session.dart:
    // It doesn't seem to have speaker control. Usually it's handled by FlutterWebRTC Helper.
    // Helper.setSpeakerphoneOn(true);
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
      screenBuilder: () => VoipCallScreen(session: _session),
      baseDuration: _duration,
      audioOnly: _session.audioOnly,
      statusText: _session.status == CallState.STATUS_CONNECTED
          ? null
          : _statusLabel(AppLocalizations.of(context)!),
    );
    Navigator.of(context).pop();
  }

  // --- CallSessionCallback ---

  @override
  void didCallEndWithReason(CallEndReason reason) {
    // 可能正处于最小化状态（界面已 pop 但 State 仍在），先清理悬浮窗
    CallOverlayManager.instance.onCallEnded();
    if (mounted) {
      setState(() {
        _callEnded = true;
      });
      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) {
          return;
        }
        // 桌面端通话在 Shell 浮窗中,收起浮窗;移动端整页 pop
        final shell =
            AppShell.isDesktopStyle ? context.read<PCShellViewModel>() : null;
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
      setState(() {
        // 状态文案由 build 里的 _statusLabel 按最新 status 计算
      });
      if (state == CallState.STATUS_CONNECTED) {
        _startTimer();
        setState(() {
          _refreshRenderers();
          _updateRemoteVideoMuted();
        });
      }
    }
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
    if (mounted) {
      setState(() {
        if (_localRenderer.srcObject != stream) {
          _localRenderer.srcObject = stream;
        }
      });
    }
  }

  @override
  void didGetStats(List<StatsReport> reports) {}

  @override
  void didMediaLostPacket(String media, int lostPacket,
      {bool screenSharing = false}) {}

  @override
  void didMuteStateChanged(List<String> participants) {
    if (!mounted) return;
    final selfId = Imclient.currentUserId;
    final remoteId = _remoteUserId;
    setState(() {
      if (participants.contains(selfId)) {
        _isMicMuted = _session.isAudioMuted;
        _isCameraOff = _session.isVideoMuted;
      }
      if (remoteId.isNotEmpty && participants.contains(remoteId)) {
        final profile = _session.getParticipantProfiles().firstWhere(
              (p) => p.userId == remoteId,
              orElse: () => ParticipantProfile(remoteId),
            );
        _remoteVideoMuted = profile.videoMuted;
      }
    });
  }

  @override
  void didParticipantConnected(String userId, {bool screenSharing = false}) {
    setState(() {
      _refreshRenderers();
    });
  }

  @override
  void didParticipantJoined(String userId, {bool screenSharing = false}) {}

  @override
  void didParticipantLeft(String userId, CallEndReason reason,
      {bool screenSharing = false}) {
    if (_session.conversation?.conversationType == ConversationType.Single) {
      // Peer left, usually ends call automatically, but we can update UI
    }
  }

  @override
  void didReceiveRemoteVideo(String userId, MediaStream stream,
      {bool screenSharing = false}) {
    if (mounted) {
      setState(() {
        if (_remoteRenderer.srcObject != stream) {
          _remoteRenderer.srcObject = stream;
        }
        _remoteVideoMuted = false;
      });
    }
  }

  @override
  void didRemoveRemoteVideo(String userId) {
    if (mounted) {
      setState(() {
        _remoteRenderer.srcObject = null;
        _remoteVideoMuted = true;
      });
    }
  }

  @override
  void didReportAudioVolume(String userId, int volume) {}

  @override
  void didScreenShareEnded() {}

  @override
  void didUserMediaLostPacket(
      String userId, String media, int lostPacket, bool uplink,
      {bool screenSharing = false}) {}

  @override
  void didVideoMuted(String userId, bool muted) {
    if (!mounted) return;
    if (userId == Imclient.currentUserId) {
      setState(() {
        _isCameraOff = muted;
      });
    } else if (userId == _remoteUserId) {
      setState(() {
        _remoteVideoMuted = muted;
      });
    }
  }

  @override
  void didChangeInitiator(String initiator) {}

  @override
  void didChangeType(String userId, bool audience,
      {bool screenSharing = false}) {}

  @override
  void onInitial(CallSession session, String initiatorId) {}

  @override
  void onRequestChangeMode(bool audience) {}

  @override
  void onError(dynamic error) {}

  // --- UI Building ---

  @override
  Widget build(BuildContext context) {
    final bool isVideoMode = !_session.audioOnly;
    final bool isConnected = _session.status == CallState.STATUS_CONNECTED;
    final bool isOutgoingOrConnecting =
        _session.status == CallState.STATUS_OUTGOING ||
            _session.status == CallState.STATUS_CONNECTING;
    final bool showLocalFullscreen = isVideoMode && isOutgoingOrConnecting;
    final bool showPip = isVideoMode && isConnected;
    final bool showRemoteFullscreen = isVideoMode && isConnected;

    return Scaffold(
      backgroundColor: const Color(0xFF0F121B),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // 语音通话背景
              if (!isVideoMode) _buildAudioBackground(),
              // 远端/本地视频层
              if (showRemoteFullscreen) _buildMainVideo(),
              if (showLocalFullscreen) _buildLocalPreviewFullscreen(),
              // 可拖动、可切换的小窗（仅接通后显示）
              if (showPip) _buildPipVideo(constraints),

              SafeArea(
                child: Column(
                  children: [
                    // 未接通或语音通话时显示头像与状态
                    if (!isVideoMode || !isConnected) ...[
                      // 最小化按钮所有状态可用（仅移动端）
                      if (!AppShell.isDesktopStyle)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              const Spacer(),
                              _buildMinimizeButton(),
                            ],
                          ),
                        )
                      else
                        const SizedBox(height: 80),
                      _buildUserInfo(),

                      const SizedBox(height: 24),
                      // 时长走秒,用 ValueNotifier 局部刷新,不重建整页
                      ValueListenableBuilder<int>(
                        valueListenable: _durationSeconds,
                        builder: (context, seconds, child) {
                          return Text(
                            isConnected
                                ? _formatDuration(Duration(seconds: seconds))
                                : _statusLabel(AppLocalizations.of(context)!),
                            style: AppText.lg.copyWith(
                                color: Colors.white70,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.5),
                          );
                        },
                      ),
                    ] else ...[
                      // 视频通话已接通：左上角显示时长
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  color: Colors.black.withValues(alpha: 0.38),
                                  // 时长走秒,用 ValueNotifier 局部刷新,不重建整页
                                  child: ValueListenableBuilder<int>(
                                    valueListenable: _durationSeconds,
                                    builder: (context, seconds, child) {
                                      return Text(
                                        _formatDuration(
                                            Duration(seconds: seconds)),
                                        style: AppText.base.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                            fontFeatures: [
                                              FontFeature.tabularFigures()
                                            ]),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                            // 最小化为悬浮窗（仅移动端）
                            if (!AppShell.isDesktopStyle)
                              _buildMinimizeButton(),
                          ],
                        ),
                      ),
                    ],

                    const Spacer(),

                    _buildActionButtons(isVideoMode),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 接通后的大画面（默认远端，切换后可显示本地）
  Widget _buildMainVideo() {
    final renderer = _isSwapped ? _localRenderer : _remoteRenderer;
    final bool showOverlay =
        !_isSwapped && (_remoteVideoMuted || _remoteRenderer.srcObject == null);
    return Positioned.fill(
      child: Stack(
        children: [
          RTCVideoView(
            renderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            mirror: _isSwapped,
          ),
          if (showOverlay) _buildRemoteOverlay(),
        ],
      ),
    );
  }

  /// 远端无画面时的占位（头像+名字+提示）
  Widget _buildRemoteOverlay() {
    return Container(
      color: const Color(0xFF0F121B),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Portrait(
            _targetUserInfo?.portrait ?? '',
            Config.defaultUserPortrait,
            width: 120,
            height: 120,
            borderRadius: 60,
          ),
          const SizedBox(height: 24),
          if (_targetUserInfo != null)
            MeshUserName(
              _targetUserInfo!,
              style: AppText.xxl.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          const SizedBox(height: 12),
          Text(
            _remoteVideoMuted
                ? AppLocalizations.of(context)!.remoteCameraOff
                : AppLocalizations.of(context)!.waitingForRemoteVideo,
            style: AppText.base.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  /// 最小化按钮：收起为可拖动悬浮窗，不结束通话。
  Widget _buildMinimizeButton() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: Colors.black.withValues(alpha: 0.38),
          child: IconButton(
            icon: const Icon(Icons.photo_size_select_small_rounded,
                color: Colors.white, size: 22),
            onPressed: _onMinimize,
          ),
        ),
      ),
    );
  }

  /// 拨出/接听过程中，本地预览占满全屏
  Widget _buildLocalPreviewFullscreen() {
    return Positioned.fill(
      child: RTCVideoView(
        _localRenderer,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        mirror: true,
      ),
    );
  }

  /// 可拖动、可点击切换的小窗
  Widget _buildPipVideo(BoxConstraints constraints) {
    final maxX = constraints.maxWidth > _pipWidth
        ? constraints.maxWidth - _pipWidth
        : 0.0;
    final maxY = constraints.maxHeight > _pipHeight
        ? constraints.maxHeight - _pipHeight
        : 0.0;

    return Positioned(
      left: _pipPosition.dx.clamp(0.0, maxX),
      top: _pipPosition.dy.clamp(0.0, maxY),
      width: _pipWidth,
      height: _pipHeight,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isSwapped = !_isSwapped;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            _pipPosition = Offset(
              (_pipPosition.dx + details.delta.dx).clamp(0.0, maxX),
              (_pipPosition.dy + details.delta.dy).clamp(0.0, maxY),
            );
          });
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white24, width: 1),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: RTCVideoView(
              _isSwapped ? _remoteRenderer : _localRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              mirror: !_isSwapped,
            ),
          ),
        ),
      ),
    );
  }

  /// 语音通话背景（模糊头像或渐变）
  Widget _buildAudioBackground() {
    if (_targetUserInfo != null &&
        _targetUserInfo!.portrait != null &&
        _targetUserInfo!.portrait!.isNotEmpty) {
      return Positioned.fill(
        child: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: NetworkImage(
                  MediaUrlRedirector.redirect(_targetUserInfo!.portrait!)),
              fit: BoxFit.cover,
            ),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: Colors.black.withValues(alpha: 0.6),
            ),
          ),
        ),
      );
    }
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E2638),
              Color(0xFF0F121B),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfo() {
    final bool isPulsing = _session.status == CallState.STATUS_OUTGOING ||
        _session.status == CallState.STATUS_CONNECTING;
    final nameStyle = AppText.xxl.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      shadows: const [
        Shadow(
          color: Colors.black45,
          offset: Offset(0, 2),
          blurRadius: 8,
        ),
      ],
    );
    return Column(
      children: [
        _PulsingAvatar(
          portraitUrl: _targetUserInfo?.portrait ?? '',
          isPulsing: isPulsing,
        ),
        const SizedBox(height: 24),
        _targetUserInfo != null
            ? MeshUserName(
                _targetUserInfo!,
                style: nameStyle,
              )
            : Text(
                '',
                style: nameStyle,
              ),
      ],
    );
  }

  Widget _buildActionButtons(bool isVideoCall) {
    if (_session.status == CallState.STATUS_INCOMING) {
      if (isVideoCall) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _CallActionButton(
              icon: Icons.call_end,
              backgroundColor: const Color(0xFFFA5151), // WeChat Red
              onPressed: _onHangup,
              label: AppLocalizations.of(context)!.callDecline,
            ),
            _CallActionButton(
              icon: Icons.phone_in_talk_outlined,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              onPressed: () {
                _session.answerCall(true); // Answer as audio only
              },
              label: AppLocalizations.of(context)!.callAnswerAudio,
            ),
            _CallActionButton(
              icon: Icons.videocam,
              backgroundColor: const Color(0xFF07C160), // WeChat Green
              onPressed: _onAccept,
              label: AppLocalizations.of(context)!.callAnswerVideo,
            ),
          ],
        );
      } else {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _CallActionButton(
              icon: Icons.call_end,
              backgroundColor: const Color(0xFFFA5151), // WeChat Red
              onPressed: _onHangup,
              label: AppLocalizations.of(context)!.callDecline,
            ),
            _CallActionButton(
              icon: Icons.call,
              backgroundColor: const Color(0xFF07C160), // WeChat Green
              onPressed: _onAccept,
              label: AppLocalizations.of(context)!.callAnswer,
            ),
          ],
        );
      }
    } else if (_session.status == CallState.STATUS_CONNECTED) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CallActionButton(
                icon: _isMicMuted ? Icons.mic_off : Icons.mic_none,
                backgroundColor: _isMicMuted
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.1),
                iconColor: _isMicMuted ? Colors.black87 : Colors.white,
                onPressed: _onToggleMic,
                label: AppLocalizations.of(context)!.callMute,
              ),
              _CallActionButton(
                icon: Icons.call_end,
                backgroundColor: const Color(0xFFFA5151), // WeChat Red
                onPressed: _onHangup,
                label: AppLocalizations.of(context)!.callHangup,
              ),
              if (isVideoCall)
                _CallActionButton(
                  icon: Icons.cameraswitch_outlined,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  onPressed: _onSwitchCamera,
                  label: AppLocalizations.of(context)!.callSwitchCamera,
                )
              else
                _CallActionButton(
                  icon: _isSpeakerOn
                      ? Icons.volume_up
                      : Icons.volume_mute_outlined,
                  backgroundColor: _isSpeakerOn
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.1),
                  iconColor: _isSpeakerOn ? Colors.black87 : Colors.white,
                  onPressed: _onToggleSpeaker,
                  label: AppLocalizations.of(context)!.callSpeaker,
                ),
              if (isVideoCall)
                _CallActionButton(
                  icon: Icons.phone_in_talk_outlined,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  onPressed: _onDowngradeToVoice,
                  label: AppLocalizations.of(context)!.callSwitchToVoice,
                ),
            ],
          ),
          if (isVideoCall) ...[
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _onToggleCamera,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _isCameraOff
                      ? AppLocalizations.of(context)!.callCameraOn
                      : AppLocalizations.of(context)!.callCameraOff,
                  style: AppText.sm.copyWith(color: Colors.white70),
                ),
              ),
            ),
          ],
        ],
      );
    } else {
      // Outgoing, Connecting
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CallActionButton(
                icon: _isMicMuted ? Icons.mic_off : Icons.mic_none,
                backgroundColor: _isMicMuted
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.1),
                iconColor: _isMicMuted ? Colors.black87 : Colors.white,
                onPressed: _onToggleMic,
                label: AppLocalizations.of(context)!.callMute,
                isActive: _session.status == CallState.STATUS_CONNECTED,
              ),
              _CallActionButton(
                icon: Icons.call_end,
                backgroundColor: const Color(0xFFFA5151), // WeChat Red
                onPressed: _onHangup,
                label: AppLocalizations.of(context)!.cancel,
              ),
              if (isVideoCall)
                _CallActionButton(
                  icon: Icons.cameraswitch_outlined,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  onPressed: _onSwitchCamera,
                  label: AppLocalizations.of(context)!.callSwitchCamera,
                )
              else
                _CallActionButton(
                  icon: _isSpeakerOn
                      ? Icons.volume_up
                      : Icons.volume_mute_outlined,
                  backgroundColor: _isSpeakerOn
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.1),
                  iconColor: _isSpeakerOn ? Colors.black87 : Colors.white,
                  onPressed: _onToggleSpeaker,
                  label: AppLocalizations.of(context)!.callSpeaker,
                ),
            ],
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
        IgnorePointer(
          ignoring: !widget.isActive,
          child: GestureDetector(
            onTap: widget.onPressed,
            child: MouseRegion(
              onEnter: (_) => setState(() => _isHovered = true),
              onExit: (_) => setState(() => _isHovered = false),
              cursor: widget.isActive
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 64,
                height: 64,
                transform: Matrix4.identity()..scale(_isHovered ? 1.06 : 1.0),
                transformAlignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      widget.isActive ? widget.backgroundColor : Colors.white12,
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
                  size: 28,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
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

class _PulsingAvatar extends StatefulWidget {
  final String portraitUrl;
  final bool isPulsing;

  const _PulsingAvatar({
    required this.portraitUrl,
    required this.isPulsing,
  });

  @override
  State<_PulsingAvatar> createState() => _PulsingAvatarState();
}

class _PulsingAvatarState extends State<_PulsingAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.isPulsing) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _PulsingAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPulsing && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPulsing && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (widget.isPulsing)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                width: 100 + 40 * _controller.value,
                height: 100 + 40 * _controller.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white
                      .withValues(alpha: 0.15 * (1 - _controller.value)),
                ),
              );
            },
          ),
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Portrait(
            widget.portraitUrl,
            Config.defaultUserPortrait,
            width: 100,
            height: 100,
            borderRadius: 50, // Circle
          ),
        ),
      ],
    );
  }
}
