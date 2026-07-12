import 'package:flutter/material.dart';
import 'package:imclient/model/conversation.dart';
import 'package:chat/l10n/app_localizations.dart';

import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/widgets/pc_dialog.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'create_poll_screen.dart';
import 'poll_list_screen.dart';

/// 投票入口:发起投票 / 我的投票。
///
/// 桌面端是一个矮弹窗,选完即关,再打开下一个弹窗 —— 不做弹窗套弹窗。
class PollHomeScreen extends StatelessWidget {
  final String groupId;
  final bool asDialog;

  const PollHomeScreen({super.key, required this.groupId, this.asDialog = false});

  static Future<void> show(BuildContext context, String groupId) {
    if (isDesktopShell) {
      return showPcDialog(
        context: context,
        width: 400,
        height: 240,
        builder: (_) => PollHomeScreen(groupId: groupId, asDialog: true),
      );
    }
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PollHomeScreen(groupId: groupId)),
    );
  }

  Conversation get _conversation => Conversation(
        conversationType: ConversationType.Group,
        target: groupId,
        line: 0,
      );

  /// 桌面端先关掉本弹窗再开下一个;移动端就是普通的页面前进。
  void _openCreate(BuildContext context) {
    if (asDialog) Navigator.pop(context);
    CreatePollScreen.show(context, _conversation);
  }

  void _openList(BuildContext context) {
    if (asDialog) Navigator.pop(context);
    PollListScreen.show(context, groupId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final menu = ListView(
      padding: EdgeInsets.zero,
      children: [
        _MenuItem(
          icon: Icons.add_circle_outline,
          title: l10n.createPoll,
          subtitle: l10n.createPollSubtitle,
          onTap: () => _openCreate(context),
        ),
        _MenuItem(
          icon: Icons.format_list_bulleted,
          title: l10n.myPolls,
          subtitle: l10n.myPollsSubtitle,
          onTap: () => _openList(context),
        ),
      ],
    );

    if (asDialog) {
      return PcDialogFrame(title: l10n.poll, child: menu);
    }

    return Scaffold(
      backgroundColor: context.colors.primaryBackground,
      appBar: AppBar(title: Text(l10n.poll)),
      body: menu,
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(bottom: BorderSide(width: 0.5, color: colors.hairlineSoft)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.accentSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: colors.accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.base.copyWith(fontWeight: FontWeight.w500, color: colors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppText.xs.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }
}
