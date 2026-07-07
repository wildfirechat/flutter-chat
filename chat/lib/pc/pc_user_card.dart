import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:provider/provider.dart';
import 'package:chat/config.dart';
import 'package:chat/conversation/av_single_call.dart';
import 'package:chat/pc/pc_shell_view_model.dart';
import 'package:chat/pc/pc_theme.dart';
import 'package:chat/pc/widgets/hover_builder.dart';
import 'package:chat/pc/widgets/pc_popover.dart';
import 'package:chat/user_info_widget.dart';
import 'package:chat/viewmodel/user_view_model.dart';
import 'package:chat/widget/portrait.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// 会话内点击头像弹出的用户信息卡片(参照微信 PC),代替整页 push。
/// [shell] 由调用方在 PCHome 子树内取好传入(popover 位于根 Navigator,取不到该 Provider)。
Future<void> showPcUserCard({
  required BuildContext context,
  required Rect anchor,
  required String userId,
  String? groupId,
  PCShellViewModel? shell,
}) {
  final bool isSelf = userId == Imclient.currentUserId;
  return showPcPopover(
    context: context,
    anchor: anchor,
    size: Size(288, isSelf ? 116 : 178),
    builder: (_) => _PcUserCard(userId: userId, groupId: groupId, shell: shell, isSelf: isSelf),
  );
}

class _PcUserCard extends StatelessWidget {
  final String userId;
  final String? groupId;
  final PCShellViewModel? shell;
  final bool isSelf;

  const _PcUserCard({required this.userId, this.groupId, this.shell, required this.isSelf});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserViewModel>(
      builder: (context, userViewModel, _) {
        final userInfo = userViewModel.getUserInfo(userId, groupId: groupId);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => _openProfile(context),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Text(
                              userInfo.displayName ?? '<$userId>',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: PcTheme.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${AppLocalizations.of(context)!.accountLabel}${userInfo.name}',
                          style: const TextStyle(fontSize: 12, color: PcTheme.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _openProfile(context),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Portrait(
                        userInfo.portrait ?? Config.defaultUserPortrait,
                        Config.defaultUserPortrait,
                        width: 52,
                        height: 52,
                        borderRadius: 6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!isSelf) ...[
              const Divider(),
              Expanded(
                child: Row(
                  children: [
                    _CardAction(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: AppLocalizations.of(context)!.sendMsg,
                      onTap: () {
                        Navigator.of(context).pop();
                        shell?.openConversation(Conversation(conversationType: ConversationType.Single, target: userId));
                      },
                    ),
                    _CardAction(
                      icon: Icons.call_outlined,
                      label: AppLocalizations.of(context)!.audioCallAction,
                      onTap: () {
                        startSingleAvCall(context, userId, audioOnly: true);
                        Navigator.of(context).pop();
                      },
                    ),
                    _CardAction(
                      icon: Icons.videocam_outlined,
                      label: AppLocalizations.of(context)!.videoCallAction,
                      onTap: () {
                        startSingleAvCall(context, userId, audioOnly: false);
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// 点击名字/头像查看完整资料:关卡片,右栏打开用户详情页。
  void _openProfile(BuildContext context) {
    Navigator.of(context).pop();
    final s = shell;
    if (s != null) {
      s.openPage(UserInfoWidget(
        userId,
        key: ValueKey('pc-user-$userId'),
        onOpenPage: s.openPage,
      ));
    }
  }
}

/// 卡片底部操作项:图标 + 小字标签,等宽排列。
class _CardAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CardAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: HoverBuilder(
        cursor: SystemMouseCursors.click,
        builder: (context, hovered) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            color: hovered ? Colors.black.withValues(alpha: 0.04) : Colors.transparent,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: PcTheme.accent),
                const SizedBox(height: 5),
                Text(label, style: const TextStyle(fontSize: 11, color: PcTheme.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
