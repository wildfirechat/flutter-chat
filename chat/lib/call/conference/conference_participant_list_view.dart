import 'package:flutter/material.dart';
import 'package:avenginekit/engine/call_session.dart';
import 'package:avenginekit/engine/participant_profile.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/config.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/l10n/app_localizations.dart';

import 'conference_manager.dart';
import 'conference_hand_up_list_view.dart';
import 'conference_apply_unmute_audio_list_view.dart';
import 'conference_apply_unmute_video_list_view.dart';

enum _PanelType { members, handUp, applyAudio, applyVideo }

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
  State<ConferenceParticipantListView> createState() =>
      _ConferenceParticipantListViewState();
}

class _ConferenceParticipantListViewState
    extends State<ConferenceParticipantListView> {
  final Map<String, UserInfo> _userInfoCache = {};
  _PanelType _currentPanel = _PanelType.members;

  @override
  void initState() {
    super.initState();
    _loadUserInfos();
  }

  Future<void> _loadUserInfos() async {
    var profiles = widget.session.getParticipantProfiles();
    profiles.add(widget.session.getSelfProfile() ??
        ParticipantProfile(Imclient.currentUserId));
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
    final focusUserId = widget.conferenceManager.currentFocusUser;
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.popupBg,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(_name(_userInfoCache[profile.userId]),
                  style:
                      AppText.base.copyWith(color: context.colors.textPrimary)),
              leading: Portrait(
                _userInfoCache[profile.userId]?.portrait ?? '',
                Config.defaultUserPortrait,
                width: 40,
                height: 40,
                borderRadius: 20,
              ),
            ),
            Divider(color: context.colors.hairlineSoft),
            if (isSelf) ...[
              ListTile(
                leading: Icon(Icons.mic, color: context.colors.iconSecondary),
                title: Text(
                    profile.audioMuted
                        ? l10n.conferenceUnmuteSelf
                        : l10n.callMute,
                    style: TextStyle(color: context.colors.textPrimary)),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.session.muteAudio(!profile.audioMuted);
                },
              ),
              ListTile(
                leading:
                    Icon(Icons.videocam, color: context.colors.iconSecondary),
                title: Text(
                    profile.videoMuted ? l10n.callCameraOn : l10n.callCameraOff,
                    style: TextStyle(color: context.colors.textPrimary)),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.session.muteVideo(!profile.videoMuted);
                },
              ),
              ListTile(
                leading:
                    Icon(Icons.swap_horiz, color: context.colors.iconSecondary),
                title: Text(
                    profile.audience
                        ? l10n.conferenceSwitchToStage
                        : l10n.conferenceSwitchToAudience,
                    style: TextStyle(color: context.colors.textPrimary)),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.session.switchAudience(!profile.audience);
                },
              ),
            ],
            if (isOwner && !isSelf) ...[
              ListTile(
                leading: Icon(Icons.record_voice_over,
                    color: context.colors.iconSecondary),
                title: Text(
                    profile.audioMuted
                        ? l10n.conferenceAllowUnmuteAudio
                        : l10n.callMute,
                    style: TextStyle(color: context.colors.textPrimary)),
                onTap: () {
                  Navigator.of(context).pop();
                  if (profile.audioMuted) {
                    widget.conferenceManager
                        .approveUnmute(profile.userId, true, true);
                  } else {
                    widget.conferenceManager
                        .requestMemberMute(profile.userId, true, true);
                  }
                },
              ),
              ListTile(
                leading:
                    Icon(Icons.videocam, color: context.colors.iconSecondary),
                title: Text(
                    profile.videoMuted
                        ? l10n.conferenceAllowUnmuteVideo
                        : l10n.conferenceCloseVideo,
                    style: TextStyle(color: context.colors.textPrimary)),
                onTap: () {
                  Navigator.of(context).pop();
                  if (profile.videoMuted) {
                    widget.conferenceManager
                        .approveUnmute(profile.userId, false, true);
                  } else {
                    widget.conferenceManager
                        .requestMemberMute(profile.userId, false, true);
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.person_outline,
                    color: context.colors.iconSecondary),
                title: Text(
                    profile.audience
                        ? l10n.conferenceInviteStage
                        : l10n.conferenceSetAudience,
                    style: TextStyle(color: context.colors.textPrimary)),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.session
                      .requestChangeMode(profile.userId, !profile.audience);
                },
              ),
              ListTile(
                leading:
                    Icon(Icons.highlight, color: context.colors.iconSecondary),
                title: Text(
                    focusUserId == profile.userId
                        ? l10n.conferenceCancelFocus
                        : l10n.conferenceSetFocus,
                    style: TextStyle(color: context.colors.textPrimary)),
                onTap: () {
                  Navigator.of(context).pop();
                  if (focusUserId == profile.userId) {
                    widget.conferenceManager.requestCancelFocus();
                  } else {
                    widget.conferenceManager.requestFocus(profile.userId);
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.logout, color: context.colors.danger),
                title: Text(l10n.conferenceKick,
                    style: TextStyle(color: context.colors.danger)),
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

  Widget _buildTip(String text, VoidCallback onTap, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color ?? context.colors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            style: AppText.sm.copyWith(color: context.colors.textPrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildMembersPanel() {
    var l10n = AppLocalizations.of(context)!;
    var selfProfile = widget.session.getSelfProfile() ??
        ParticipantProfile(Imclient.currentUserId);
    var profiles = [selfProfile, ...widget.session.getParticipantProfiles()];
    var isOwner = widget.conferenceManager.isOwner;
    var focusUserId = widget.conferenceManager.currentFocusUser;
    var handUpCount = widget.conferenceManager.handUpMembers.length;
    var applyAudioCount =
        widget.conferenceManager.applyingUnmuteAudioMembers.length;
    var applyVideoCount =
        widget.conferenceManager.applyingUnmuteVideoMembers.length;

    return Column(
      children: [
        if (isOwner && handUpCount > 0)
          _buildTip(
            l10n.conferenceHandUpTip(handUpCount),
            () => setState(() => _currentPanel = _PanelType.handUp),
            color: context.colors.successSoft,
          ),
        if (isOwner && applyAudioCount > 0)
          _buildTip(
            l10n.conferenceApplyAudioTip(applyAudioCount),
            () => setState(() => _currentPanel = _PanelType.applyAudio),
          ),
        if (isOwner && applyVideoCount > 0)
          _buildTip(
            l10n.conferenceApplyVideoTip(applyVideoCount),
            () => setState(() => _currentPanel = _PanelType.applyVideo),
          ),
        if (isOwner)
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
                        ? l10n.conferenceUnmuteAll
                        : l10n.conferenceMuteAll),
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
              bool isHandUp = widget.conferenceManager.handUpMembers
                  .contains(profile.userId);

              return ListTile(
                leading: Portrait(
                  info?.portrait ?? '',
                  Config.defaultUserPortrait,
                  width: 40,
                  height: 40,
                  borderRadius: 20,
                ),
                title: Text(
                  isSelf ? l10n.meLabel : _name(info),
                  style: AppText.sm.copyWith(color: context.colors.textPrimary),
                ),
                subtitle: Row(
                  children: [
                    if (profile.audioMuted)
                      Icon(Icons.mic_off,
                          color: context.colors.textSecondary, size: 14)
                    else
                      Icon(Icons.mic,
                          color: context.colors.textSecondary, size: 14),
                    const SizedBox(width: 4),
                    if (profile.videoMuted)
                      Icon(Icons.videocam_off,
                          color: context.colors.textSecondary, size: 14)
                    else
                      Icon(Icons.videocam,
                          color: context.colors.textSecondary, size: 14),
                    if (profile.audience)
                      Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Text(l10n.conferenceAudience,
                            style: TextStyle(
                                color: context.colors.textSecondary,
                                fontSize: 12)),
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (focusUserId == profile.userId)
                      Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(Icons.highlight,
                            color: context.colors.success, size: 18),
                      ),
                    if (isHandUp)
                      Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(Icons.pan_tool,
                            color: context.colors.success, size: 18),
                      ),
                    if (!isSelf)
                      Icon(Icons.more_vert,
                          color: context.colors.textSecondary),
                  ],
                ),
                onTap: () => _showContextMenu(profile),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    var l10n = AppLocalizations.of(context)!;
    var title = l10n.conferenceMemberList;
    Widget body;
    switch (_currentPanel) {
      case _PanelType.handUp:
        title = l10n.conferenceHandUpMembersTitle;
        body = ConferenceHandUpListView(
            conferenceManager: widget.conferenceManager);
        break;
      case _PanelType.applyAudio:
        title = l10n.conferenceApplyAudio;
        body = ConferenceApplyUnmuteAudioListView(
            conferenceManager: widget.conferenceManager);
        break;
      case _PanelType.applyVideo:
        title = l10n.conferenceApplyVideo;
        body = ConferenceApplyUnmuteVideoListView(
            conferenceManager: widget.conferenceManager);
        break;
      case _PanelType.members:
        body = _buildMembersPanel();
        break;
    }

    return Container(
      color: context.colors.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (_currentPanel != _PanelType.members)
                  IconButton(
                    icon: Icon(Icons.arrow_back,
                        color: context.colors.iconSecondary),
                    onPressed: () =>
                        setState(() => _currentPanel = _PanelType.members),
                  ),
                Expanded(
                  child: Text(
                    title,
                    style: AppText.base.copyWith(
                        color: context.colors.textPrimary,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: context.colors.iconSecondary),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
