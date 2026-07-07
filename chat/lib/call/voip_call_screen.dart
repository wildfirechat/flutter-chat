import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:avenginekit/engine/call_session.dart';
import 'package:avenginekit/engine/call_session_callback.dart';
import 'package:avenginekit/engine/call_state.dart';
import 'package:avenginekit/engine/call_end_reason.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/config.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/pc_shell_view_model.dart';

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
  Duration _duration = Duration.zero;
  Timer? _timer;
  String _statusText = '正在呼叫...';

  // Video renderers
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _session.setCallback(this);
    _loadTargetInfo();
    _updateStatusText();
    
    _initRenderers().then((_) {
      if (mounted) {
        if (_session.status == CallState.STATUS_CONNECTED) {
          setState(() {
            _startTimer();
            _setupConnectedState();
          });
        }
      }
    });
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  void _setupConnectedState() {
      if (!_session.audioOnly) {
          _updateLocalRender();
          _updateRemoteRender();
      }
  }

  void _updateLocalRender() {
      var stream = _session.getParticipantVideoStream(Imclient.currentUserId);
      if (stream != null) {
        _localRenderer.srcObject = stream;
      }
  }

  void _updateRemoteRender() {
      // Find remote user
      var participants = _session.getParticipantIds();
      var targetId = participants.firstWhere((uid) => uid != Imclient.currentUserId, orElse: () => '');
      if (targetId.isNotEmpty) {
           var track = _session.getParticipantVideoStream(targetId);
           if (track != null) {
              _remoteRenderer.srcObject =track;
           }
      }
  }

  @override
  void dispose() {
    _stopTimer();
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
      targetId = participants.firstWhere((uid) => uid != Imclient.currentUserId, orElse: () => '');
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

  void _updateStatusText() {
    switch (_session.status) {
      case CallState.STATUS_IDLE:
        _statusText = '通话结束';
        break;
      case CallState.STATUS_OUTGOING:
        _statusText = '正在呼叫...';
        break;
      case CallState.STATUS_INCOMING:
        _statusText = '邀请你进行语音通话';
        break;
      case CallState.STATUS_CONNECTING:
        _statusText = '连接中...';
        break;
      case CallState.STATUS_CONNECTED:
        _statusText = '';
        break;
    }
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

  // --- CallSessionCallback ---

  @override
  void didCallEndWithReason(CallEndReason reason) {
    if (mounted) {
      setState(() {
        // Show reason
        _statusText = '通话结束'; // Could be more specific based on reason
      });
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          if (isDesktopShell && PCShellViewModel.global?.activeCallSession != null) {
            PCShellViewModel.global?.endCallSession();
          } else {
            Navigator.of(context).pop();
          }
        }
      });
    }
  }

  @override
  void didChangeState(CallState state) {
    if (mounted) {
      setState(() {
        _updateStatusText();
      });
      if (state == CallState.STATUS_CONNECTED) {
        _startTimer();
      }
    }
  }

  @override
  void didChangeMode(bool audioOnly) {}

  @override
  void didCreateLocalVideo(MediaStream stream,
      {bool screenSharing = false}) {
    if (mounted) {
      setState(() {
        _localRenderer.srcObject = stream;
      });
    }
  }

  @override
  void didError(dynamic error) {}

  @override
  void didGetStats(List<StatsReport> reports) {}

  @override
  void didMediaLostPacket(String media, int lostPacket,
      {bool screenSharing = false}) {}

  @override
  void didMuteStateChanged(List<String> participants) {}

  @override
  void didParticipantConnected(String userId, {bool screenSharing = false}) {}

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
        _remoteRenderer.srcObject = stream;
      });
    }
  }

  @override
  void didRemoveRemoteVideo(String userId) {}

  @override
  void didReportAudioVolume(String userId, int volume) {}

  @override
  void didScreenShareEnded() {}

  @override
  void didUserMediaLostPacket(
      String userId, String media, int lostPacket, bool uplink,
      {bool screenSharing = false}) {}

  @override
  void didVideoMuted(String userId, bool muted) {}

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
    bool isVideoCall = !_session.audioOnly;
    return Scaffold(
      backgroundColor: const Color(0xFF0F121B),
      body: Stack(
        children: [
          if (isVideoCall) ...[
             // Remote View (Full Screen)
             Positioned.fill(
               child: RTCVideoView(
                 _isSwapped ? _localRenderer : _remoteRenderer,
                 objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                 mirror: _isSwapped ? true : false, // Mirror local if swapped
               ),
             ),
             // Local View (Small Window)
             Positioned(
               right: 20,
               top: 100,
               width: 120,
               height: 180,
               child: GestureDetector(
                 onTap: () {
                   setState(() {
                     _isSwapped = !_isSwapped;
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
                        mirror: !_isSwapped, // Mirror local if not swapped (default)
                     ),
                   ),
                 ),
               ),
             ),
          ] else ...[
             // Audio Call Background
             // Background Image (Blurred)
              if (_targetUserInfo != null &&
                  _targetUserInfo!.portrait != null &&
                  _targetUserInfo!.portrait!.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(_targetUserInfo!.portrait!),
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

              if (_targetUserInfo == null ||
                  _targetUserInfo!.portrait == null ||
                  _targetUserInfo!.portrait!.isEmpty)
                Container(
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
          ],

          SafeArea(
            child: Column(
              children: [
                if (!isVideoCall || _session.status != CallState.STATUS_CONNECTED) ...[
                    const SizedBox(height: 80),
                    // User Info
                    _buildUserInfo(),

                     // Status / Duration
                    const SizedBox(height: 24),
                    Text(
                      _session.status == CallState.STATUS_CONNECTED
                          ? _formatDuration(_duration)
                          : _statusText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.5,
                      ),
                    ),
                ] else ...[
                    // Connected video call: show duration in top left
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                color: Colors.black.withValues(alpha: 0.38),
                                child: Text(
                                  _formatDuration(_duration),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],

                const Spacer(),

                // Buttons
                _buildActionButtons(isVideoCall),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildUserInfo() {
    final bool isPulsing = _session.status == CallState.STATUS_OUTGOING || _session.status == CallState.STATUS_CONNECTING;
    return Column(
      children: [
        _PulsingAvatar(
          portraitUrl: _targetUserInfo?.portrait ?? '',
          isPulsing: isPulsing,
        ),
        const SizedBox(height: 24),
        Text(
          _targetUserInfo?.getReadableName() ?? '',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            shadows: [
              Shadow(
                color: Colors.black45,
                offset: Offset(0, 2),
                blurRadius: 8,
              ),
            ],
          ),
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
              label: '拒绝',
            ),
            _CallActionButton(
              icon: Icons.phone_in_talk_outlined,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              onPressed: () {
                _session.answerCall(true); // Answer as audio only
              },
              label: '语音接听',
            ),
            _CallActionButton(
              icon: Icons.videocam,
              backgroundColor: const Color(0xFF07C160), // WeChat Green
              onPressed: _onAccept,
              label: '视频接听',
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
              label: '拒绝',
            ),
            _CallActionButton(
              icon: Icons.call,
              backgroundColor: const Color(0xFF07C160), // WeChat Green
              onPressed: _onAccept,
              label: '接听',
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
                backgroundColor: _isMicMuted ? Colors.white : Colors.white.withValues(alpha: 0.1),
                iconColor: _isMicMuted ? Colors.black87 : Colors.white,
                onPressed: _onToggleMic,
                label: '静音',
              ),
              _CallActionButton(
                icon: Icons.call_end,
                backgroundColor: const Color(0xFFFA5151), // WeChat Red
                onPressed: _onHangup,
                label: '挂断',
              ),
              if (isVideoCall)
                _CallActionButton(
                  icon: Icons.cameraswitch_outlined,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  onPressed: _onSwitchCamera,
                  label: '翻转',
                )
              else
                _CallActionButton(
                  icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_mute_outlined,
                  backgroundColor: _isSpeakerOn ? Colors.white : Colors.white.withValues(alpha: 0.1),
                  iconColor: _isSpeakerOn ? Colors.black87 : Colors.white,
                  onPressed: _onToggleSpeaker,
                  label: '免提',
                ),
            ],
          ),
          if (isVideoCall) ...[
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _onToggleCamera,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _isCameraOff ? '开启摄像头' : '关闭摄像头',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
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
                backgroundColor: _isMicMuted ? Colors.white : Colors.white.withValues(alpha: 0.1),
                iconColor: _isMicMuted ? Colors.black87 : Colors.white,
                onPressed: _onToggleMic,
                label: '静音',
              ),
              _CallActionButton(
                icon: Icons.call_end,
                backgroundColor: const Color(0xFFFA5151), // WeChat Red
                onPressed: _onHangup,
                label: '取消',
              ),
              if (isVideoCall)
                _CallActionButton(
                  icon: Icons.cameraswitch_outlined,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  onPressed: _onSwitchCamera,
                  label: '翻转',
                )
              else
                _CallActionButton(
                  icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_mute_outlined,
                  backgroundColor: _isSpeakerOn ? Colors.white : Colors.white.withValues(alpha: 0.1),
                  iconColor: _isSpeakerOn ? Colors.black87 : Colors.white,
                  onPressed: _onToggleSpeaker,
                  label: '免提',
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
        GestureDetector(
          onTap: widget.onPressed,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            cursor: SystemMouseCursors.click,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 64,
              height: 64,
              transform: Matrix4.identity()..scale(_isHovered ? 1.06 : 1.0),
              transformAlignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isActive 
                    ? widget.backgroundColor 
                    : Colors.white12,
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
        const SizedBox(height: 8),
        Text(
          widget.label,
          style: TextStyle(
            color: widget.isActive ? Colors.white70 : Colors.white38,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
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
                  color: Colors.white.withValues(alpha: 0.15 * (1 - _controller.value)),
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

