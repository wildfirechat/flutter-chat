import 'package:flutter/material.dart';
import 'package:chat/call/conference/create_conference_view.dart';
import 'package:chat/call/conference/join_conference_view.dart';
import 'package:chat/call/conference/order_conference_view.dart';
import 'package:chat/call/conference/conference_info_view.dart';
import 'package:chat/call/conference/conference_manager.dart';
import 'package:chat/app_server.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/app_navigator.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/config.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';

/// 会议入口页：加入/发起/预定 + 收藏/历史列表
/// [isEmbedded] 为 true 时用于 PC 中栏嵌入,不显示 Scaffold/AppBar/左侧操作面板。
class ConferenceHomeScreen extends StatefulWidget {
  final bool isEmbedded;

  const ConferenceHomeScreen({Key? key, this.isEmbedded = false}) : super(key: key);

  @override
  State<ConferenceHomeScreen> createState() => _ConferenceHomeScreenState();
}

class _ConferenceHomeScreenState extends State<ConferenceHomeScreen> {
  List<Map<String, dynamic>> _favConferences = [];
  List<Map<String, dynamic>> _historyConferences = [];
  bool _loadingFav = false;
  final Map<String, UserInfo> _userInfoCache = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loadingFav = true);
    _loadFavConferences();
    _historyConferences = await ConferenceManager.getHistoryConferences();
    await _loadOwnerNames();
    if (mounted) setState(() => _loadingFav = false);
  }

  void _loadFavConferences() {
    AppServer.getFavConferences((list) {
      if (!mounted) return;
      setState(() {
        _favConferences = list.where((e) {
          var startTime = e['startTime'] ?? 0;
          return startTime > 0;
        }).toList();
      });
      _loadOwnerNames();
    }, (error) {
      print('getFavConferences error: $error');
      if (mounted) setState(() => _loadingFav = false);
    });
  }

  Future<void> _loadOwnerNames() async {
    var all = [
      ..._favConferences,
      ..._historyConferences,
    ];
    for (var info in all) {
      var owner = info['owner'] as String?;
      if (owner != null && owner.isNotEmpty && !_userInfoCache.containsKey(owner)) {
        var userInfo = await Imclient.getUserInfo(owner);
        if (userInfo != null) {
          _userInfoCache[owner] = userInfo;
        }
      }
    }
    if (mounted) setState(() {});
  }

  void _openCreate(BuildContext context) async {
    if (isDesktopShell) {
      openPage(context, const CreateConferenceView());
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CreateConferenceView()),
      );
    }
    _reload();
  }

  void _openJoin(BuildContext context) {
    if (isDesktopShell) {
      openPage(context, const JoinConferenceView());
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const JoinConferenceView()),
      );
    }
  }

  void _openOrder(BuildContext context) {
    if (isDesktopShell) {
      openPage(context, const OrderConferenceView());
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const OrderConferenceView()),
      );
    }
  }

  void _showConferenceInfo(Map<String, dynamic> info) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.popupBg,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => ConferenceInfoView(
          conferenceInfo: info,
          scrollController: scrollController,
          onChanged: _reload,
        ),
      ),
    );
  }

  String _favDesc(Map<String, dynamic> info) {
    var l10n = AppLocalizations.of(context)!;
    var now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    var startTime = info['startTime'] ?? 0;
    var endTime = info['endTime'] ?? 0;
    if (now < startTime) {
      var diff = startTime - now;
      if (diff < 3600) return l10n.conferenceFavorites;
      return l10n.conferenceStatusNotStarted;
    }
    if (endTime == 0 || now < endTime) {
      return l10n.conferenceStatusOngoing;
    }
    return l10n.conferenceStatusEnded;
  }

  String _historyDesc(Map<String, dynamic> info) {
    var l10n = AppLocalizations.of(context)!;
    var startTime = info['startTime'] ?? 0;
    var endTime = info['endTime'] ?? 0;
    var start = DateTime.fromMillisecondsSinceEpoch(startTime * 1000);
    var owner = info['owner'] as String?;
    var ownerName = _userInfoCache[owner]?.getReadableName() ?? owner ?? '';
    var duration = '';
    if (endTime > startTime) {
      var seconds = endTime - startTime;
      var h = seconds ~/ 3600;
      var m = (seconds % 3600) ~/ 60;
      var s = seconds % 60;
      if (h > 0) {
        duration = l10n.conferenceDurationHours(h, m.toString().padLeft(2, '0'));
      } else if (m > 0) {
        duration = l10n.conferenceDurationMinutes(m, s.toString().padLeft(2, '0'));
      } else {
        duration = l10n.conferenceDurationSeconds(s);
      }
    }
    return '${start.month}/${start.day} ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} · $ownerName · $duration';
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      color: context.colors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title,
            style: AppText.base.copyWith(
                color: context.colors.textPrimary, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: AppText.sm.copyWith(color: context.colors.textSecondary)),
        trailing: Icon(Icons.chevron_right, color: context.colors.textSecondary),
        onTap: onTap,
      ),
    );
  }

  Widget _buildConferenceTile(Map<String, dynamic> info, {bool isHistory = false}) {
    var title = info['conferenceTitle'] ?? info['title'] ?? '';
    var owner = info['owner'] as String?;
    var ownerInfo = _userInfoCache[owner];

    return ListTile(
      leading: Portrait(
        ownerInfo?.portrait ?? '',
        Config.defaultUserPortrait,
        width: 44,
        height: 44,
        borderRadius: 22,
      ),
      title: Text(
        title.isNotEmpty ? title : AppLocalizations.of(context)!.conferenceUntitled,
        style: AppText.sm.copyWith(color: context.colors.textPrimary),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        isHistory ? _historyDesc(info) : _favDesc(info),
        style: AppText.xs.copyWith(color: context.colors.textSecondary),
      ),
      trailing: Icon(Icons.chevron_right, color: context.colors.textSecondary),
      onTap: () => _showConferenceInfo(info),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEmbedded) {
      return _buildBodyContent(context);
    }
    var l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.colors.primaryBackground,
      appBar: AppBar(
        title: Text(l10n.conferenceTitle),
        backgroundColor: context.colors.surface,
      ),
      body: Row(
        children: [
          Container(
            width: 260,
            color: context.colors.middleBg,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.conferenceVideoConferenceTitle,
                    style: AppText.lg.copyWith(
                        color: context.colors.textPrimary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 20),
                _buildActionCard(
                  icon: Icons.login,
                  color: Colors.blue,
                  title: l10n.conferenceJoinMeeting,
                  subtitle: l10n.conferenceJoinHint,
                  onTap: () => _openJoin(context),
                ),
                _buildActionCard(
                  icon: Icons.video_call,
                  color: Colors.green,
                  title: l10n.conferenceCreateTitle,
                  subtitle: l10n.conferenceCreateHint,
                  onTap: () => _openCreate(context),
                ),
                _buildActionCard(
                  icon: Icons.calendar_today,
                  color: Colors.orange,
                  title: l10n.conferenceOrder,
                  subtitle: l10n.conferenceOrderHint,
                  onTap: () => _openOrder(context),
                ),
              ],
            ),
          ),
          VerticalDivider(color: context.colors.hairlineSoft, width: 1),
          Expanded(child: _buildBodyContent(context)),
        ],
      ),
    );
  }

  Widget _buildBodyContent(BuildContext context) {
    var l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.isEmbedded) ...[
            _buildActionCard(
              icon: Icons.login,
              color: Colors.blue,
              title: l10n.conferenceJoinMeeting,
              subtitle: l10n.conferenceJoinHint,
              onTap: () => _openJoin(context),
            ),
            _buildActionCard(
              icon: Icons.video_call,
              color: Colors.green,
              title: l10n.conferenceCreateTitle,
              subtitle: l10n.conferenceCreateHint,
              onTap: () => _openCreate(context),
            ),
            _buildActionCard(
              icon: Icons.calendar_today,
              color: Colors.orange,
              title: l10n.conferenceOrder,
              subtitle: l10n.conferenceOrderHint,
              onTap: () => _openOrder(context),
            ),
            const SizedBox(height: 24),
          ],
          Text(l10n.conferenceFavorites,
              style: AppText.base.copyWith(
                  color: context.colors.textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (_loadingFav && _favConferences.isEmpty)
            Center(
                child: CircularProgressIndicator(color: context.colors.iconSecondary)),
          if (!_loadingFav && _favConferences.isEmpty)
            Text(l10n.conferenceNoFavorites,
                style: TextStyle(color: context.colors.textSecondary)),
          ..._favConferences.map((e) => _buildConferenceTile(e)),
          const SizedBox(height: 24),
          Text(l10n.conferenceHistory,
              style: AppText.base.copyWith(
                  color: context.colors.textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (_historyConferences.isEmpty)
            Text(l10n.conferenceNoHistory,
                style: TextStyle(color: context.colors.textSecondary)),
          ..._historyConferences
              .map((e) => _buildConferenceTile(e, isHistory: true)),
        ],
      ),
    );
  }
}
