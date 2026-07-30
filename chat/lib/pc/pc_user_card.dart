import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:provider/provider.dart';
import 'package:chat/app_navigator.dart';
import 'package:chat/config.dart';
import 'package:chat/call/av_call_launcher.dart';
import 'package:chat/pc/widgets/pc_icon_action.dart';
import 'package:chat/pc/widgets/pc_popover.dart';
import 'package:chat/user_info_widget.dart';
import 'package:chat/viewmodel/user_view_model.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/utils/mesh_user_name.dart';
import 'package:chat/theme/app_typography.dart';

/// 会话内点击头像弹出的用户信息卡片(参照微信 PC),代替整页 push。
/// 跳转经 app_navigator 统一入口(Shell 状态注册在应用根部,浮层内也能取到)。
Future<void> showPcUserCard({
  required BuildContext context,
  required Rect anchor,
  required String userId,
  String? groupId,
}) {
  final bool isSelf = userId == Imclient.currentUserId;
  return showPcPopover(
    context: context,
    anchor: anchor,
    width: 288,
    builder: (_) =>
        _PcUserCard(userId: userId, groupId: groupId, isSelf: isSelf),
  );
}

class _PcUserCard extends StatelessWidget {
  final String userId;
  final String? groupId;
  final bool isSelf;

  const _PcUserCard({required this.userId, this.groupId, required this.isSelf});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserViewModel>(
      builder: (context, userViewModel, _) {
        final userInfo = userViewModel.getUserInfo(userId, groupId: groupId);
        return Column(
          mainAxisSize: MainAxisSize.min,
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
                            child: MeshUserName(
                              userInfo,
                              style: AppText.lg.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: context.colors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${AppLocalizations.of(context)!.accountLabel}${userInfo.name}',
                          style: AppText.xs
                              .copyWith(color: context.colors.textSecondary),
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
            // height 16:信息区与操作区之间要留呼吸空间,不只是画线。
            const Divider(height: 16, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
              // 按钮宽度包住文字即可,不平分整行;译文过长时换行而非溢出。
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                runSpacing: 2,
                children: [
                  PcIconAction(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: AppLocalizations.of(context)!.sendMsg,
                    onTap: () {
                      // 先经当前 context 完成查找与跳转,再关卡片
                      openConversation(
                          context,
                          Conversation(
                              conversationType: ConversationType.Single,
                              target: userId));
                      Navigator.of(context).pop();
                    },
                  ),
                  // 给自己发消息(当作文件传输助手)可用,但音视频通话对自己无意义。
                  if (!isSelf) ...[
                    PcIconAction(
                      icon: Icons.call_outlined,
                      label: AppLocalizations.of(context)!.audioCallAction,
                      onTap: () {
                        startSingleAvCall(context, userId, audioOnly: true);
                        Navigator.of(context).pop();
                      },
                    ),
                    PcIconAction(
                      icon: Icons.videocam_outlined,
                      label: AppLocalizations.of(context)!.videoCallAction,
                      onTap: () {
                        startSingleAvCall(context, userId, audioOnly: false);
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// 点击名字/头像查看完整资料:右栏打开用户详情页,再关卡片。
  void _openProfile(BuildContext context) {
    pushPage(context, UserInfoWidget(userId, key: ValueKey('pc-user-$userId')));
    Navigator.of(context).pop();
  }
}
