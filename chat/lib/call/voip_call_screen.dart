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
    _initRenderers();

    if (_session.status == CallState.STATUS_CONNECTED) {
      _startTimer();
      _setupConnectedState();
    }
  }

  void _initRenderers() async {
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
          Navigator.of(context).pop();
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
      backgroundColor: Colors.grey[900],
      body: Stack(
        children: [
          if (isVideoCall) ...[
             // Remote View (Full Screen)
             Positioned.fill(
               child: RTCVideoView(
                 _isSwapped ? _localRenderer : _remoteRenderer,
                 objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                 mirror: _isSwapped ? true : false, // Mirror local if swapped
                 onRendererUpdated: (data) {
                   var r = _isSwapped ? _localRenderer : _remoteRenderer;
                   r.surfaceId = data;
                 }
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
                     border: Border.all(color: Colors.white, width: 1),
                     borderRadius: BorderRadius.circular(8),
                   ),
                   child: ClipRRect(
                     borderRadius: BorderRadius.circular(8),
                     child: RTCVideoView(
                        _isSwapped ? _remoteRenderer : _localRenderer,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        mirror: !_isSwapped, // Mirror local if not swapped (default)
                        onRendererUpdated: (data) {
                          var r = _isSwapped ? _remoteRenderer : _localRenderer;
                          r.surfaceId = data;
                        }
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
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      color: Colors.black.withOpacity(0.5),
                    ),
                  ),
                ),

              if (_targetUserInfo == null ||
                  _targetUserInfo!.portrait == null ||
                  _targetUserInfo!.portrait!.isEmpty)
                Container(color: Colors.grey[800]),
          ],

          SafeArea(
            child: Column(
              children: [
                if (!isVideoCall || _session.status != CallState.STATUS_CONNECTED) ...[
                    const SizedBox(height: 60),
                    // User Info
                    _buildUserInfo(),

                     // Status / Duration
                    const SizedBox(height: 20),
                    Text(
                      _session.status == CallState.STATUS_CONNECTED
                          ? _formatDuration(_duration)
                          : _statusText,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                ],

                const Spacer(),

                // Buttons
                _buildActionButtons(isVideoCall),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildUserInfo() {
    return Column(
      children: [
        if (_targetUserInfo != null)
          Portrait(
            _targetUserInfo!.portrait ?? '',
            Config.defaultUserPortrait,
            width: 100,
            height: 100,
            borderRadius: 8,
          ),
        const SizedBox(height: 16),
        Text(
          _targetUserInfo?.getReadableName() ?? '',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isVideoCall) {
    if (_session.status == CallState.STATUS_INCOMING) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildCircleButton(
            icon: Icons.call_end,
            color: Colors.red,
            onPressed: _onHangup,
            label: '拒绝',
          ),
          _buildCircleButton(
            icon: isVideoCall ? Icons.videocam : Icons.call,
            color: Colors.green,
            onPressed: _onAccept,
            label: '接听',
          ),
        ],
      );
    } else if (_session.status == CallState.STATUS_CONNECTED) {
      return Column(
        children: [
           if (isVideoCall)
             Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                   children: [
                      _buildCircleButton(
                         icon: Icons.cameraswitch,
                         color: Colors.white24,
                         onPressed: _onSwitchCamera,
                         label: '翻转',
                      ),
                      _buildCircleButton(
                         icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                         color: _isCameraOff ? Colors.white : Colors.white24,
                         iconColor: _isCameraOff ? Colors.black : Colors.white,
                         onPressed: _onToggleCamera,
                         label: '摄像头',
                      ),
                   ],
                ),
             ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCircleButton(
                icon: _isMicMuted ? Icons.mic_off : Icons.mic,
                color: _isMicMuted ? Colors.white : Colors.white24,
                iconColor: _isMicMuted ? Colors.black : Colors.white,
                onPressed: _onToggleMic,
                label: '麦克风',
              ),
              _buildCircleButton(
                icon: Icons.call_end,
                color: Colors.red,
                onPressed: _onHangup,
                label: '挂断',
              ),
              _buildCircleButton(
                icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                color: _isSpeakerOn ? Colors.white : Colors.white24,
                iconColor: _isSpeakerOn ? Colors.black : Colors.white,
                onPressed: _onToggleSpeaker,
                label: '扬声器',
              ),
            ],
          ),
        ],
      );
    } else {
      // Outgoing, Connecting
      return Column(
        children: [
          if (isVideoCall)
             Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _buildCircleButton(
                   icon: Icons.cameraswitch,
                   color: Colors.white24,
                   onPressed: _onSwitchCamera,
                   label: '翻转',
                ),
             ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCircleButton(
                icon: _isMicMuted ? Icons.mic_off : Icons.mic,
                color: _isMicMuted ? Colors.white : Colors.white24,
                iconColor: _isMicMuted ? Colors.black : Colors.white,
                onPressed: _onToggleMic,
                label: '麦克风',
              ),
              _buildCircleButton(
                icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                color: _isSpeakerOn ? Colors.white : Colors.white24,
                iconColor: _isSpeakerOn ? Colors.black : Colors.white,
                onPressed: _onToggleSpeaker,
                label: '扬声器',
              ),
            ],
          ),
          const SizedBox(height: 40),
          _buildCircleButton(
            icon: Icons.call_end,
            color: Colors.red,
            onPressed: _onHangup,
            label: '取消',
          ),
        ],
      );
    }
  }


  Widget _buildCircleButton({
    required IconData icon,
    required Color color,
    Color iconColor = Colors.white,
    required VoidCallback onPressed,
    required String label,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
            child: Icon(icon, color: iconColor, size: 32),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ],
    );
  }
}
