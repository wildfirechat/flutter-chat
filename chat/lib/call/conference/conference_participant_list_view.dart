import 'package:flutter/material.dart';
import 'package:avenginekit/engine/call_session.dart';
import 'package:avenginekit/engine/participant_profile.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/config.dart';
import 'package:chat/theme/app_typography.dart';

import 'conference_manager.dart';

class ConferenceParticipantListView extends StatefulWidget {
  final CallSession session;
  final ConferenceManager conferenceManager;
  final VoidCallback onClose;

  const ConferenceParticipantListView({
    Key? key,
    required this.session,
    required this.conferenceManager,
    required this.onClose,
  }) : super(key: key);

  @override
  State<ConferenceParticipantListView> createState() => _ConferenceParticipantListViewState();
}

class _ConferenceParticipantListViewState extends State<ConferenceParticipantListView> {
  final Map<String, UserInfo> _userInfoCache = {};

  @override
  void initState() {
    super.initState();
    _loadUserInfos();
  }

  Future<void> _loadUserInfos() async {
    var profiles = widget.session.getParticipantProfiles();
    profiles.add(widget.session.getSelfProfile() ?? ParticipantProfile(Imclient.currentUserId));
    for (var profile in profiles) {
      if (!_userInfoCache.containsKey(profile.userId)) {
        var info = await Imclient.getUserInfo(profile.userId);
        if (info != null) {
          _userInfoCache[profile.userId] = info;
        }
      }
    }
    if (mounted) setState(() {});
  }

  String _name(UserInfo? info) {
    if (info == null) return '';
    return info.getReadableName();
  }

  void _showContextMenu(ParticipantProfile profile) {
    final isSelf = profile.userId == Imclient.currentUserId;
    final isOwner = widget.conferenceManager.isOwner;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2638),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(_name(_userInfoCache[profile.userId]),
                  style: AppText.base.copyWith(color: Colors.white)),
              leading: Portrait(
                _userInfoCache[profile.userId]?.portrait ?? '',
                Config.defaultUserPortrait,
                width: 40,
                height: 40,
                borderRadius: 20,
              ),
            ),
            const Divider(color: Colors.white24),
            if (isSelf) ...[
              ListTile(
                leading: const Icon(Icons.mic, color: Colors.white70),
                title: Text(profile.audioMuted ? '取消静音' : '静音',
                    style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.session.muteAudio(!profile.audioMuted);
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam, color: Colors.white70),
                title: Text(profile.videoMuted ? '开启摄像头' : '关闭摄像头',
                    style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.session.muteVideo(!profile.videoMuted);
                },
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz, color: Colors.white70),
                title: Text(profile.audience ? '上麦' : '下麦',
                    style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.session.switchAudience(!profile.audience);
                },
              ),
            ],
            if (isOwner && !isSelf) ...[
              ListTile(
                leading: const Icon(Icons.record_voice_over, color: Colors.white70),
                title: Text(profile.audioMuted ? '允许开麦' : '静音',
                    style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.of(context).pop();
                  if (profile.audioMuted) {
                    widget.conferenceManager.approveUnmute(profile.userId, true, true);
                  } else {
                    widget.conferenceManager.requestMemberMute(profile.userId, true, true);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam, color: Colors.white70),
                title: Text(profile.videoMuted ? '允许开视频' : '关闭视频',
                    style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.of(context).pop();
                  if (profile.videoMuted) {
                    widget.conferenceManager.approveUnmute(profile.userId, false, true);
                  } else {
                    widget.conferenceManager.requestMemberMute(profile.userId, false, true);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline, color: Colors.white70),
                title: Text(profile.audience ? '邀请上麦' : '设为观众',
                    style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.session.requestChangeMode(profile.userId, !profile.audience);
                },
              ),
              ListTile(
                leading: const Icon(Icons.highlight, color: Colors.white70),
                title: const Text('设为焦点', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.conferenceManager.requestFocus(profile.userId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text('踢出会议', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.session.kickoffParticipant(profile.userId);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var selfProfile = widget.session.getSelfProfile() ?? ParticipantProfile(Imclient.currentUserId);
    var profiles = [selfProfile, ...widget.session.getParticipantProfiles()];

    return Container(
      color: const Color(0xFF1A1F2E),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text(
                  '参会成员 (${profiles.length})',
                  style: AppText.base.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          if (widget.conferenceManager.isOwner)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        widget.conferenceManager.requestMuteAll(
                            true, !widget.conferenceManager.allowUnmuteAudio);
                      },
                      child: Text(widget.conferenceManager.isMuteAll
                          ? '取消全体静音'
                          : '全体静音'),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: profiles.length,
              itemBuilder: (context, index) {
                var profile = profiles[index];
                var info = _userInfoCache[profile.userId];
                bool isSelf = profile.userId == Imclient.currentUserId;

                return ListTile(
                  leading: Portrait(
                    info?.portrait ?? '',
                    Config.defaultUserPortrait,
                    width: 40,
                    height: 40,
                    borderRadius: 20,
                  ),
                  title: Text(
                    isSelf ? '我' : _name(info),
                    style: AppText.sm.copyWith(color: Colors.white),
                  ),
                  subtitle: Row(
                    children: [
                      if (profile.audioMuted)
                        const Icon(Icons.mic_off, color: Colors.white54, size: 14)
                      else
                        const Icon(Icons.mic, color: Colors.white54, size: 14),
                      const SizedBox(width: 4),
                      if (profile.videoMuted)
                        const Icon(Icons.videocam_off, color: Colors.white54, size: 14)
                      else
                        const Icon(Icons.videocam, color: Colors.white54, size: 14),
                      if (profile.audience)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Text('观众', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        ),
                    ],
                  ),
                  trailing: isSelf
                      ? null
                      : const Icon(Icons.more_vert, color: Colors.white54),
                  onTap: () => _showContextMenu(profile),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
