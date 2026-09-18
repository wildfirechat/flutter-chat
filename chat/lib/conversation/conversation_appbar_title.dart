import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/utilities.dart';
import 'package:chat/utils/external_target_utils.dart';
import 'package:chat/utils/mesh_user_display.dart';
import 'package:chat/utils/online_state_builder.dart';
import 'package:chat/utils/online_state_formatter.dart';
import 'package:chat/conversation/voice_message_player.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/viewmodel/channel_view_model.dart';
import 'package:chat/viewmodel/conversation_view_model.dart';
import 'package:chat/viewmodel/group_view_model.dart';
import 'package:chat/viewmodel/user_view_model.dart';
import 'package:chat/widget/middle_ellipsis_text.dart';

/// 两行之间的间距。副标题自带这份上边距,没有副标题时两行退化成一行,
/// 间距也跟着消失(与 Android Toolbar 的 subtitle 行为一致)。
const double _lineGap = 1;

/// 行高估算系数,只用于给 AppBar 预留高度 —— 字体实际行高由字体本身决定,
/// 这里取一个偏保守的值,宁可多留一点也别让标题溢出。
const double _lineHeightFactor = 1.4;

/// 两行标题上下各留的呼吸空间。
const double _verticalPadding = 4;

/// 会话标题,两行结构(参考 android-chat 的 toolbar title + subtitle):
///
/// - 第一行:会话名(群名后缀人数、外部域用户的域后缀、听筒模式图标都在这一行)
/// - 第二行:会话状态 —— 正在输入 / 对方在线状态 / 机器人 / 官方群
///
/// 第二行没内容时不占位,标题自动退化成单行居中,与 Android 一致。
class ConversationAppbarTitle extends StatelessWidget {
  final Conversation conversation;

  /// 标题是否居中。null 表示按 AppBar 自己的规则推断(iOS/macOS 居中、
  /// Android 等左对齐);桌面右栏的标题栏是自绘的 Row,固定传 false。
  final bool? centered;

  const ConversationAppbarTitle(this.conversation, {super.key, this.centered});

  /// 两行标题需要的 AppBar 高度。
  ///
  /// 高度必须与「当前有没有副标题」无关:副标题会随「正在输入」出现又消失,
  /// 跟着内容变高会让整条栏上下抖动,所以这里恒按两行预留。默认字号档位下算出来
  /// 小于 [kToolbarHeight],AppBar 维持原高度;只有放大字号档位才会长高。
  static double toolbarHeight(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final lines = scaler.scale(AppText.lg.fontSize!) * _lineHeightFactor +
        scaler.scale(AppText.xs.fontSize!) * _lineHeightFactor +
        _lineGap;
    return math.max(kToolbarHeight, lines + _verticalPadding * 2);
  }

  @override
  Widget build(BuildContext context) {
    final Widget child = Selector4<
        ConversationViewModel,
        UserViewModel,
        GroupViewModel,
        ChannelViewModel,
        (
          int typingKind,
          int typingCount,
          String? typingUserName,
          String typingDots,
          UserInfo? targetUserInfo,
          GroupInfo? targetGroupInfo,
          ChannelInfo? targetChannelInfo
        )>(
      builder: (context, rec, __) {
        final userInfo = rec.$5;
        final groupInfo = rec.$6;
        var title = Utilities.conversationTitle(
            context, conversation, userInfo, groupInfo, rec.$7);
        // 群组标题后追加当前群人数，对齐 iOS："群名称(人数)"
        if (conversation.conversationType == ConversationType.Group &&
            groupInfo != null) {
          title = '$title(${groupInfo.memberCount})';
        }
        final isExternal =
            conversation.conversationType == ConversationType.Single &&
                ExternalTargetUtils.isExternalTarget(conversation.target);

        Widget titleLine;
        if (isExternal && userInfo != null) {
          // 外部域用户的标题需要使用带黄色、小字号域后缀的富文本样式。
          titleLine = Text.rich(
            MeshUserDisplay.getReadableNameSpan(
              userInfo,
              style: DefaultTextStyle.of(context).style,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        } else {
          titleLine = MiddleEllipsisText(title);
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: (centered ?? _appBarCentersTitle(context))
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            _EarpieceModeIndicator(child: titleLine),
            _buildSubtitle(
              context,
              typingKind: rec.$1,
              typingCount: rec.$2,
              typingUserName: rec.$3,
              typingDots: rec.$4,
              userInfo: userInfo,
              groupInfo: groupInfo,
              isExternal: isExternal,
            ),
          ],
        );
      },
      selector: (context, conversationViewModel, userViewModel, groupViewModel,
              channelViewModel) =>
          (
        conversationViewModel.typingKind,
        conversationViewModel.typingCount,
        conversationViewModel.typingUserName,
        conversationViewModel.typingDots,
        conversation.conversationType == ConversationType.Single
            ? userViewModel.getUserInfo(conversation.target)
            : null,
        conversation.conversationType == ConversationType.Group
            ? groupViewModel.getGroupInfo(conversation.target)
            : null,
        conversation.conversationType == ConversationType.Channel
            ? channelViewModel.getChannelInfo(conversation.target)
            : null
      ),
    );

    // 正标题的字号在这里钉死(颜色仍随壳/主题继承):两行之后不再用 AppBar 默认的
    // 大字号,和桌面 PcTheme.paneTitle 落在同一档,[toolbarHeight] 也是按这一档算的。
    return DefaultTextStyle.merge(
      style: AppText.lg.copyWith(fontWeight: FontWeight.w500),
      child: child,
    );
  }

  /// 第二行。优先级参考 android-chat:正在输入 > 在线状态 / 机器人 / 官方群;
  /// 都没有则返回零高度占位,标题退回单行。
  Widget _buildSubtitle(
    BuildContext context, {
    required int typingKind,
    required int typingCount,
    required String? typingUserName,
    required String typingDots,
    required UserInfo? userInfo,
    required GroupInfo? groupInfo,
    required bool isExternal,
  }) {
    final l10n = AppLocalizations.of(context)!;
    if (typingKind != 0) {
      final typing = switch (typingKind) {
        1 => l10n.peerTyping,
        2 => l10n.groupMembersTyping(typingCount),
        _ => l10n.namedUserTyping(typingUserName ?? ''),
      };
      return _SubtitleLine('$typing$typingDots');
    }

    switch (conversation.conversationType) {
      case ConversationType.Single:
        if (userInfo?.type == 1) {
          return _SubtitleLine(l10n.robot);
        }
        // 外部域用户拿不到在线状态，不占第二行。
        if (isExternal) {
          return const SizedBox.shrink();
        }
        return OnlineStateBuilder(
          userId: conversation.target,
          builder: (context, state) {
            final status =
                OnlineStateFormatter.conversationStatusText(state, l10n);
            if (status == null || status.isEmpty) {
              return const SizedBox.shrink();
            }
            return _SubtitleLine(status);
          },
        );
      case ConversationType.Group:
        if (groupInfo?.type == GroupType.Organization) {
          return _SubtitleLine(l10n.official);
        }
        return const SizedBox.shrink();
      case _:
        return const SizedBox.shrink();
    }
  }
}

/// AppBar 在 iOS/macOS 上默认把标题居中(会话页的 actions 不足 2 个),两行标题的
/// Column 必须跟着同一规则,否则副标题会歪到一边。
bool _appBarCentersTitle(BuildContext context) {
  final theme = Theme.of(context);
  final centerTitle = theme.appBarTheme.centerTitle;
  if (centerTitle != null) {
    return centerTitle;
  }
  return switch (theme.platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => true,
    _ => false,
  };
}

/// 标题第二行的样式:小一档、次要色,且不继承正标题的字重。
class _SubtitleLine extends StatelessWidget {
  final String text;

  const _SubtitleLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: _lineGap),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.xs.copyWith(
          color: context.colors.textSecondary,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

/// 听筒播放模式下，在标题后缀一个听筒图标(参考 android-chat)：这是个全局设置，
/// 用户可能是很久以前在别的会话里开的，会话页得有个常驻提示。
class _EarpieceModeIndicator extends StatelessWidget {
  final Widget child;

  const _EarpieceModeIndicator({required this.child});

  @override
  Widget build(BuildContext context) {
    if (!VoicePlayMode.isSupported) {
      return child;
    }
    return ValueListenableBuilder<bool>(
      valueListenable: VoicePlayMode.listenable,
      builder: (context, earpiece, child) {
        if (!earpiece) {
          return child!;
        }
        final fontSize = DefaultTextStyle.of(context).style.fontSize ?? 16;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题自身仍可省略，图标不被挤掉
            Flexible(child: child!),
            const SizedBox(width: 6),
            Icon(
              Icons.hearing,
              size: fontSize,
              color: DefaultTextStyle.of(context)
                  .style
                  .color
                  ?.withValues(alpha: 0.5),
            ),
          ],
        );
      },
      child: child,
    );
  }
}
