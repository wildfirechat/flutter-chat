import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/config.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/theme/app_colors.dart';

import 'conference_manager.dart';

/// 主持人查看举手成员列表
class ConferenceHandUpListView extends StatefulWidget {
  final ConferenceManager conferenceManager;

  const ConferenceHandUpListView({
    Key? key,
    required this.conferenceManager,
  }) : super(key: key);

  @override
  State<ConferenceHandUpListView> createState() => _ConferenceHandUpListViewState();
}

class _ConferenceHandUpListViewState extends State<ConferenceHandUpListView> {
  final Map<String, UserInfo> _userInfoCache = {};

  @override
  void initState() {
    super.initState();
    _loadUserInfos();
  }

  Future<void> _loadUserInfos() async {
    for (var userId in widget.conferenceManager.handUpMembers) {
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
  void didUpdateWidget(covariant ConferenceHandUpListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.conferenceManager.handUpMembers.length != oldWidget.conferenceManager.handUpMembers.length) {
      _loadUserInfos();
    }
  }

  String _name(UserInfo? info) {
    if (info == null) return '';
    return info.getReadableName();
  }

  @override
  Widget build(BuildContext context) {
    var members = widget.conferenceManager.handUpMembers;

    return Container(
      color: context.colors.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text(
                  '举手成员 (${members.length})',
                  style: AppText.base.copyWith(
                      color: context.colors.textPrimary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Expanded(
            child: members.isEmpty
                ? Center(
                    child: Text('暂无举手成员',
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
                          style: AppText.sm.copyWith(color: context.colors.textPrimary),
                        ),
                        trailing: ElevatedButton(
                          onPressed: () {
                            widget.conferenceManager.putMemberHandDown(userId);
                          },
                          child: const Text('放下'),
                        ),
                      );
                    },
                  ),
          ),
          if (members.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.conferenceManager.putAllHandDown();
                  },
                  child: const Text('全部放下'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
