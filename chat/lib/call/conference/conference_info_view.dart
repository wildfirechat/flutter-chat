import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:avenginekit/engine/avenginekit.dart';
import 'package:chat/app_server.dart';
import 'package:chat/pc/call_window/main_avengine_kit_proxy.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/config.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';

import 'conference_manager.dart';

/// 会议详情弹窗：查看信息、收藏、销毁、加入
class ConferenceInfoView extends StatefulWidget {
  final Map<String, dynamic> conferenceInfo;
  final ScrollController? scrollController;
  final VoidCallback? onChanged;

  const ConferenceInfoView({
    Key? key,
    required this.conferenceInfo,
    this.scrollController,
    this.onChanged,
  }) : super(key: key);

  @override
  State<ConferenceInfoView> createState() => _ConferenceInfoViewState();
}

class _ConferenceInfoViewState extends State<ConferenceInfoView> {
  bool _enableAudio = false;
  bool _enableVideo = false;
  bool _isFav = false;
  UserInfo? _ownerInfo;
  bool _loading = false;

  Map<String, dynamic> get info => widget.conferenceInfo;

  @override
  void initState() {
    super.initState();
    _loadOwnerInfo();
    _checkFav();
  }

  Future<void> _loadOwnerInfo() async {
    var owner = info['owner'] as String?;
    if (owner != null && owner.isNotEmpty) {
      _ownerInfo = await Imclient.getUserInfo(owner);
      if (mounted) setState(() {});
    }
  }

  void _checkFav() {
    var conferenceId = info['conferenceId'] as String?;
    if (conferenceId == null || conferenceId.isEmpty) return;
    AppServer.isFavConference(conferenceId, (isFav) {
      if (mounted) setState(() => _isFav = isFav);
    }, (error) {
      print('isFavConference error: $error');
    });
  }

  void _toggleFav() {
    var conferenceId = info['conferenceId'] as String?;
    if (conferenceId == null || conferenceId.isEmpty) return;
    setState(() => _isFav = !_isFav);
    AppServer.favConference(conferenceId, () {
      widget.onChanged?.call();
    }, (error) {
      print('favConference error: $error');
      if (mounted) setState(() => _isFav = !_isFav);
    });
  }

  void _copyConferenceId() {
    var conferenceId = info['conferenceId'] as String? ?? '';
    Clipboard.setData(ClipboardData(text: conferenceId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('会议号已复制')),
    );
  }

  void _destroyConference() {
    var conferenceId = info['conferenceId'] as String?;
    if (conferenceId == null || conferenceId.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('销毁会议'),
        content: const Text('销毁后其他成员将无法加入，确认销毁？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              AppServer.destroyConference(conferenceId, () async {
                await ConferenceManager.removeHistory(conferenceId);
                if (mounted) {
                  Navigator.of(context).pop();
                  widget.onChanged?.call();
                }
              }, (error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('销毁失败: $error')),
                );
              });
            },
            child: Text('销毁', style: TextStyle(color: context.colors.danger)),
          ),
        ],
      ),
    );
  }

  void _joinConference() async {
    setState(() => _loading = true);
    var conferenceId = info['conferenceId'] as String? ?? '';
    var audioOnly = info['audioOnly'] ?? false;
    var pin = info['pin'] as String? ?? '';
    var title = info['conferenceTitle'] ?? info['title'] ?? '';
    var desc = info['desc'] as String? ?? '';
    var audience = info['audience'] ?? false;
    var advance = info['advance'] ?? false;
    var host = info['owner'] as String? ?? '';

    var joinAudioMuted = !_enableAudio;
    var joinVideoMuted = !_enableVideo;
    var joinAudience = audience || (joinAudioMuted && joinVideoMuted);

    if (isDesktopShell) {
      await MainAvEngineKitProxy.instance.joinConference(
        callId: conferenceId,
        audioOnly: audioOnly,
        pin: pin,
        host: host,
        title: title,
        desc: desc,
        audience: joinAudience,
        advance: advance,
        muteAudio: joinAudioMuted,
        muteVideo: joinVideoMuted,
      );
    } else {
      // ignore: await_only_futures
      await avEngineKit.joinConference(
        conferenceId,
        audioOnly,
        pin,
        host,
        title,
        desc,
        joinAudience,
        advance,
        joinAudioMuted,
        joinVideoMuted,
        '',
        '',
      );
    }
    setState(() => _loading = false);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  bool get _canJoin {
    var now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    var endTime = info['endTime'] ?? 0;
    return endTime == 0 || now < endTime;
  }

  bool get _enableDestroy {
    var owner = info['owner'] as String? ?? '';
    return owner == Imclient.currentUserId;
  }

  String _formatTime(int seconds) {
    var date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    var title = info['conferenceTitle'] ?? info['title'] ?? '无标题会议';
    var conferenceId = info['conferenceId'] as String? ?? '';
    var startTime = info['startTime'] ?? 0;
    var endTime = info['endTime'] ?? 0;
    var now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    return Container(
      color: context.colors.popupBg,
      child: SingleChildScrollView(
        controller: widget.scrollController,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Portrait(
                  _ownerInfo?.portrait ?? '',
                  Config.defaultUserPortrait,
                  width: 48,
                  height: 48,
                  borderRadius: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppText.base.copyWith(
                            color: context.colors.textPrimary, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '发起人：${_ownerInfo?.getReadableName() ?? info['owner'] ?? ''}',
                        style: AppText.sm.copyWith(color: context.colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('会议号', style: AppText.sm.copyWith(color: context.colors.textSecondary)),
              subtitle: Text(conferenceId,
                  style: AppText.base.copyWith(color: context.colors.textPrimary)),
              trailing: IconButton(
                icon: Icon(Icons.copy, color: context.colors.iconSecondary),
                onPressed: _copyConferenceId,
              ),
            ),
            if (startTime > 0) ...[
              Divider(color: context.colors.hairlineSoft),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('开始时间', style: AppText.sm.copyWith(color: context.colors.textSecondary)),
                subtitle: Text(_formatTime(startTime),
                    style: AppText.base.copyWith(color: context.colors.textPrimary)),
              ),
            ],
            if (endTime > 0) ...[
              Divider(color: context.colors.hairlineSoft),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('结束时间', style: AppText.sm.copyWith(color: context.colors.textSecondary)),
                subtitle: Text(_formatTime(endTime),
                    style: AppText.base.copyWith(color: context.colors.textPrimary)),
              ),
            ],
            const SizedBox(height: 20),
            if (_canJoin) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('开启麦克风', style: AppText.sm.copyWith(color: context.colors.textPrimary)),
                value: _enableAudio,
                activeColor: context.colors.success,
                onChanged: (v) => setState(() => _enableAudio = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('开启摄像头', style: AppText.sm.copyWith(color: context.colors.textPrimary)),
                value: _enableVideo,
                activeColor: context.colors.success,
                onChanged: (v) => setState(() => _enableVideo = v),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canJoin && !_loading ? _joinConference : null,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_canJoin ? '加入会议' : '会议已结束'),
              ),
            ),
            const SizedBox(height: 12),
            if (now < startTime && !_isFav)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _toggleFav,
                  child: const Text('收藏会议'),
                ),
              ),
            if (_enableDestroy) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.danger,
                  ),
                  onPressed: _destroyConference,
                  child: const Text('销毁会议'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
