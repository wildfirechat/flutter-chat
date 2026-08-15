import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:provider/provider.dart';

import 'package:chat/config.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/viewmodel/user_view_model.dart';
import 'package:chat/widget/portrait.dart';

/// 平板两栏形态下,工作台 tab 的**左栏**。
///
/// 工作台的正文是一整个远端网页,挤进 320 宽的左栏没法看,所以左栏让给一块
/// 迎宾面板(问候语 + 日期),真正的工作台放到右栏 —— 与 hm-chat 的 WorkspacePane
/// 同一套形态。手机不走这里(工作台在手机上就是整页网页)。
///
/// 这里刻意只放"不点也不动"的静态信息:左栏一旦出现可点的入口,用户就会预期它
/// 在右栏里打开,而右栏此刻被工作台网页占着,两者会互相打架。
class PadWorkspaceWelcome extends StatelessWidget {
  const PadWorkspaceWelcome({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.primaryBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _greeting(context, l10n),
              const SizedBox(height: 16),
              _dateCard(context, l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _greeting(BuildContext context, AppLocalizations l10n) {
    final colors = context.colors;
    // 头像与昵称走 UserViewModel:本地库先给(可能是占位),服务端刷新后经它通知重建,
    // 见 CLAUDE.md 的取数约定 —— 这里不 refresh,避免和「我」页互相触发刷新。
    return Selector<UserViewModel, (String?, String?)>(
      selector: (_, model) {
        final info = model.getUserInfo(Imclient.currentUserId);
        return (info.displayName, info.portrait);
      },
      builder: (context, rec, _) {
        final (displayName, portrait) = rec;
        return Row(
          children: [
            Portrait(
              portrait ?? Config.defaultUserPortrait,
              Config.defaultUserPortrait,
              width: 44,
              height: 44,
              borderRadius: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greetingText(l10n, displayName),
                    style: AppText.lg.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.workspaceWelcomeSubtitle,
                    style: AppText.xs.copyWith(color: colors.textTertiary),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _greetingText(AppLocalizations l10n, String? displayName) {
    final int hour = DateTime.now().hour;
    final String greeting = hour < 6
        ? l10n.greetingNight
        : hour < 12
            ? l10n.greetingMorning
            : hour < 14
                ? l10n.greetingNoon
                : hour < 18
                    ? l10n.greetingAfternoon
                    : l10n.greetingEvening;
    final name = (displayName ?? '').trim();
    return name.isEmpty ? greeting : '$greeting，$name';
  }

  Widget _dateCard(BuildContext context, AppLocalizations l10n) {
    final colors = context.colors;
    final now = DateTime.now();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.accentSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${now.day}',
              style: AppText.xxl.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.workspaceWelcomeDate(now.year, now.month, now.day),
                  style: AppText.sm.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.workspaceWelcomeHint,
                  style: AppText.xs.copyWith(color: colors.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
