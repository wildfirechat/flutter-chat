import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/config.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/l10n/app_localizations.dart';

import 'conference_manager.dart';

/// 主持人查看申请开麦成员列表
class ConferenceApplyUnmuteAudioListView extends StatefulWidget {
  final ConferenceManager conferenceManager;

  const ConferenceApplyUnmuteAudioListView({
    Key? key,
    required this.conferenceManager,
  }) : super(key: key);

  @override
  State<ConferenceApplyUnmuteAudioListView> createState() =>
      _ConferenceApplyUnmuteAudioListViewState();
}

class _ConferenceApplyUnmuteAudioListViewState
    extends State<ConferenceApplyUnmuteAudioListView> {
  final Map<String, UserInfo> _userInfoCache = {};

  @override
  void initState() {
    super.initState();
    _loadUserInfos();
  }

  Future<void> _loadUserInfos() async {
    for (var userId in widget.conferenceManager.applyingUnmuteAudioMembers) {
      if (!_userInfoCache.containsKey(userId)) {
        var info = await Imclient.getUserInfo(userId);
        if (info != null) {
          _userInfoCache[userId] = info;
        }
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant ConferenceApplyUnmuteAudioListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.conferenceManager.applyingUnmuteAudioMembers.length !=
        oldWidget.conferenceManager.applyingUnmuteAudioMembers.length) {
      _loadUserInfos();
    }
  }

  String _name(UserInfo? info) {
    if (info == null) return '';
    return info.getReadableName();
  }

  @override
  Widget build(BuildContext context) {
    var members = widget.conferenceManager.applyingUnmuteAudioMembers;
    var l10n = AppLocalizations.of(context)!;

    return Container(
      color: context.colors.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text(
                  l10n.conferenceApplyAudioCount(members.length),
                  style: AppText.base.copyWith(
                      color: context.colors.textPrimary,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Expanded(
            child: members.isEmpty
                ? Center(
                    child: Text(l10n.conferenceNoApplications,
                        style: TextStyle(color: context.colors.textSecondary)),
                  )
                : ListView.builder(
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      var userId = members[index];
                      var info = _userInfoCache[userId];
                      return ListTile(
                        leading: Portrait(
                          info?.portrait ?? '',
                          Config.defaultUserPortrait,
                          width: 40,
                          height: 40,
                          borderRadius: 20,
                        ),
                        title: Text(
                          _name(info),
                          style: AppText.sm
                              .copyWith(color: context.colors.textPrimary),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () {
                                widget.conferenceManager
                                    .approveUnmute(userId, true, false);
                              },
                              child: Text(l10n.conferenceReject),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                widget.conferenceManager
                                    .approveUnmute(userId, true, true);
                              },
                              child: Text(l10n.conferenceApprove),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          if (members.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        widget.conferenceManager.approveAllUnmute(true, false);
                      },
                      child: Text(l10n.conferenceRejectAll),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        widget.conferenceManager.approveAllUnmute(true, true);
                      },
                      child: Text(l10n.conferenceApproveAll),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
