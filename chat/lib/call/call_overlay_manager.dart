import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:avenginekit/engine/avenginekit.dart';
import 'package:avenginekit/engine/call_end_reason.dart';
import 'package:avenginekit/engine/call_session.dart';
import 'package:avenginekit/engine/call_session_callback.dart';
import 'package:avenginekit/engine/call_state.dart';
import 'package:avenginekit/engine/participant_profile.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';
import 'package:chat/config.dart';
import 'package:chat/pc/pc_window_manager.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/utilities.dart';
import 'package:chat/widget/portrait.dart';

/// 移动端通话最小化悬浮窗管理器（单例）。
///
/// 最小化时把可拖动的悬浮小窗插入全局 navigator 的 Overlay，
/// 期间由自己的 1s Timer 从 [baseDuration] 继续计时；
/// 点按悬浮窗 [restore] 重新 push 全屏通话界面，
/// 通话结束时由通话界面的 didCallEndWithReason 调 [onCallEnded] 清理。
class CallOverlayManager {
  CallOverlayManager._internal();

  static final CallOverlayManager instance = CallOverlayManager._internal();

  OverlayEntry? _overlayEntry;
  Widget Function()? _screenBuilder;
  Timer? _timer;
  Duration _duration = Duration.zero;

  /// 悬浮窗的 key，回调里驱动媒体刷新（接通/远端开关摄像头）。
  final GlobalKey<_CallFloatingWindowState> _floatingWindowKey = GlobalKey();

  /// 最小化期间接管 session 回调的对象。
  late final CallSessionCallback _sessionCallback =
      _MinimizedSessionCallback(this);

  /// 未接通就最小化时的状态文案（如"呼叫中"/"等待接听"），非 null 时
  /// 悬浮窗显示文案而不走秒；接通回调到达后清零开始计时。
  String? _statusText;

  /// restore 时暂存的通话时长，供恢复后的全屏界面 initState 交接；
  /// 经 [currentDuration] 读取一次后即清除。
  Duration? _restoredDuration;

  /// 悬浮窗展示中，或刚 restore 完、时长尚未被新界面交接时视为最小化状态。
  bool get isMinimized => _overlayEntry != null || _restoredDuration != null;

  /// 悬浮窗内的当前通话时长，供恢复全屏时交接给通话界面。
  /// restore 后首次读取会带走交接的时长（读取即清除）。
  Duration get currentDuration {
    final d = _restoredDuration ?? _duration;
    _restoredDuration = null;
    return d;
  }

  /// 弹出悬浮窗并从 [baseDuration] 继续计时。
  /// 未接通时调用方传 [statusText]（如"呼叫中"），悬浮窗显示文案，
  /// 最小化期间由悬浮窗接管 session 回调（原界面 pop 后其 State 已销毁，
  /// 不能再接收回调），接通后自动转为走秒计时。
  void minimize({
    required Widget Function() screenBuilder,
    required Duration baseDuration,
    required bool audioOnly,
    String? statusText,
  }) {
    if (_overlayEntry != null) return;
    final overlay = pcWindowNavKey?.currentState?.overlay;
    if (overlay == null) return;

    _screenBuilder = screenBuilder;
    _duration = baseDuration;
    _statusText = statusText;
    _restoredDuration = null;
    // 接管 session 回调：原界面即将 pop，其 State 销毁后不能再收回调
    // （否则引擎回调打进 defunct State，setState 崩溃）。
    avEngineKit.currentSession?.setCallback(_sessionCallback);
    _startTimer();
    _overlayEntry = OverlayEntry(
      builder: (_) => _CallFloatingWindow(
        key: _floatingWindowKey,
        audioOnly: audioOnly,
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  /// 隐藏悬浮窗并恢复全屏通话界面。
  Future<void> restore() async {
    final builder = _screenBuilder;
    // 时长先暂存，等恢复界面 initState 通过 currentDuration 交接
    final duration = _duration;
    _hide();
    _restoredDuration = duration;
    final nav = pcWindowNavKey?.currentState;
    if (nav != null && builder != null) {
      await nav.push(MaterialPageRoute(builder: (_) => builder()));
    }
  }

  /// 通话结束：隐藏悬浮窗并清理计时器。
  void onCallEnded() {
    _hide();
  }

  void _hide() {
    _stopTimer();
    // remove 会触发悬浮窗 State.dispose，内部视频 renderer 随之释放
    _overlayEntry?.remove();
    _overlayEntry = null;
    _screenBuilder = null;
    _duration = Duration.zero;
    _statusText = null;
    _restoredDuration = null;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      // 接通后（_statusText 被接通回调清零）走秒
      if (_statusText == null) {
        _duration += const Duration(seconds: 1);
      }
      // 驱动悬浮窗重绘走秒
      _overlayEntry?.markNeedsBuild();
    });
  }

  /// 接通回调：清状态文案、开始走秒、刷新媒体画面。
  void _handleConnected() {
    if (_statusText == null) return;
    _statusText = null;
    _duration = Duration.zero;
    _overlayEntry?.markNeedsBuild();
    _floatingWindowKey.currentState?._refreshMedia();
  }

  /// 远端视频流变化（新到流/关摄像头）：刷新悬浮窗媒体画面。
  void _handleRemoteVideoChanged() {
    _floatingWindowKey.currentState?._refreshMedia();
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }
}

/// 悬浮小窗：初始右上角，可自由拖动，点按恢复全屏。
/// 语音通话为深色 pill（电话图标 + 走秒时长）；
/// 视频通话为卡片：有远端视频显示远端视频，远端关摄像头显示对方头像。
class _CallFloatingWindow extends StatefulWidget {
  final bool audioOnly;

  const _CallFloatingWindow({super.key, required this.audioOnly});

  @override
  State<_CallFloatingWindow> createState() => _CallFloatingWindowState();
}

class _CallFloatingWindowState extends State<_CallFloatingWindow> {
  static const double _audioWidth = 130;
  static const double _audioHeight = 48;
  static const double _videoWidth = 110;
  static const double _videoHeight = 150;

  Offset? _offset;
  RTCVideoRenderer? _renderer;
  UserInfo? _targetUserInfo;

  @override
  void initState() {
    super.initState();
    if (!widget.audioOnly) {
      _prepareVideo();
    }
  }

  /// 选一路远端视频并绑定自建 renderer。
  /// 单人取第一个非本人参与者；多人/会议取第一个开着摄像头且有流的远端，
  /// 找不到就取第一个远端。
  Future<void> _prepareVideo() async {
    final session = avEngineKit.currentSession;
    if (session == null) return;
    final remoteIds = session
        .getParticipantIds()
        .where((id) => id != Imclient.currentUserId)
        .toList();
    if (remoteIds.isEmpty) return;
    final profiles = session.getParticipantProfiles();

    ParticipantProfile profileOf(String userId) =>
        profiles.firstWhere((p) => p.userId == userId,
            orElse: () => ParticipantProfile(userId));

    String targetId;
    if (remoteIds.length == 1) {
      targetId = remoteIds.first;
    } else {
      targetId = remoteIds.firstWhere(
        (id) =>
            !profileOf(id).videoMuted &&
            session.getParticipantVideoStream(id) != null,
        orElse: () => remoteIds.first,
      );
    }
    final stream = session.getParticipantVideoStream(targetId);
    if (!profileOf(targetId).videoMuted && stream != null) {
      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      if (!mounted) {
        renderer.dispose();
        return;
      }
      renderer.srcObject = stream;
      _renderer = renderer;
    } else {
      _targetUserInfo = await Imclient.getUserInfo(targetId);
    }
    if (mounted) {
      setState(() {});
    }
  }

  /// 媒体状态变化（接通/远端开关摄像头）后重新评估显示内容：
  /// 释放旧 renderer，重新选流绑定或回退头像。
  Future<void> _refreshMedia() async {
    if (widget.audioOnly || !mounted) return;
    final old = _renderer;
    _renderer = null;
    _targetUserInfo = null;
    old?.srcObject = null;
    await old?.dispose();
    await _prepareVideo();
  }

  @override
  void dispose() {
    _renderer?.srcObject = null;
    _renderer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final width = widget.audioOnly ? _audioWidth : _videoWidth;
    final height = widget.audioOnly ? _audioHeight : _videoHeight;
    final maxX = size.width > width ? size.width - width : 0.0;
    final maxY = size.height > height ? size.height - height : 0.0;
    // 初始位置：右上角
    final offset = _offset ?? Offset(maxX - 16, topPadding + 40);

    return Positioned(
      left: offset.dx.clamp(0.0, maxX),
      top: offset.dy.clamp(0.0, maxY),
      width: width,
      height: height,
      child: GestureDetector(
        onTap: () => CallOverlayManager.instance.restore(),
        onPanUpdate: (details) {
          setState(() {
            final current = _offset ?? offset;
            _offset = Offset(
              (current.dx + details.delta.dx).clamp(0.0, maxX),
              (current.dy + details.delta.dy).clamp(0.0, maxY),
            );
          });
        },
        child: Material(
          color: Colors.transparent,
          child: widget.audioOnly ? _buildAudioPill() : _buildVideoCard(),
        ),
      ),
    );
  }

  /// 语音通话悬浮窗：深色半透明 pill，电话图标 + 走秒时长。
  Widget _buildAudioPill() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.phone_in_talk, color: Color(0xFF07C160), size: 18),
          const SizedBox(width: 6),
          Text(
            // 未接通显示状态文案；接通后走秒。
            // 直接读 _duration：currentDuration 是交接用的消费型 getter，不能用于走秒
            CallOverlayManager.instance._statusText ??
                Utilities.formatCallTime(
                    CallOverlayManager.instance._duration.inSeconds),
            style: AppText.base.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 视频通话悬浮窗：远端视频或对方头像（远端关摄像头/无流时）。
  Widget _buildVideoCard() {
    final renderer = _renderer;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2638),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: renderer != null && renderer.srcObject != null
            ? RTCVideoView(
                renderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            : Center(
                child: Portrait(
                  _targetUserInfo?.portrait ?? '',
                  Config.defaultUserPortrait,
                  width: 56,
                  height: 56,
                  borderRadius: 28,
                ),
              ),
      ),
    );
  }
}

/// 最小化期间接管 session 回调的对象：原通话界面 pop 后其 State 已销毁，
/// 由它把接通/挂断/远端视频变化转发给悬浮窗，其余事件无需处理。
class _MinimizedSessionCallback implements CallSessionCallback {
  final CallOverlayManager _manager;

  _MinimizedSessionCallback(this._manager);

  @override
  void didChangeState(CallState state) {
    if (state == CallState.STATUS_CONNECTED) {
      _manager._handleConnected();
    }
  }

  @override
  void didCallEndWithReason(CallEndReason reason) {
    _manager.onCallEnded();
  }

  @override
  void didReceiveRemoteVideo(String userId, MediaStream stream,
      {bool screenSharing = false}) {
    _manager._handleRemoteVideoChanged();
  }

  @override
  void didRemoveRemoteVideo(String userId) {
    _manager._handleRemoteVideoChanged();
  }

  @override
  void didVideoMuted(String userId, bool muted) {
    _manager._handleRemoteVideoChanged();
  }

  // ---- 以下回调在最小化期间无需处理 ----

  @override
  void onInitial(CallSession zc, String initiatorId) {}

  @override
  void didParticipantJoined(String userId, {bool screenSharing = false}) {}

  @override
  void didParticipantConnected(String userId, {bool screenSharing = false}) {}

  @override
  void didParticipantLeft(String userId, CallEndReason reason,
      {bool screenSharing = false}) {}

  @override
  void didChangeMode(bool audioOnly) {}

  @override
  void didCreateLocalVideo(MediaStream stream, {bool screenSharing = false}) {}

  @override
  void didScreenShareEnded() {}

  @override
  void didReportAudioVolume(String userId, int volume) {}

  @override
  void didMuteStateChanged(List<String> participants) {}

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
}
