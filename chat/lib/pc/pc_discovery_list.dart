import 'package:flutter/material.dart';
import 'package:avenginekit/engine/avenginekit.dart';
import 'package:imclient/model/conversation.dart';
import 'package:chat/app_navigator.dart';
import 'package:chat/call/conference/conference_home_screen.dart';
import 'package:chat/channel/channel_list.dart';
import 'package:chat/config.dart';
import 'package:chat/discovery/chatroom_list.dart';
import 'package:chat/pan/pan_home_screen.dart';
import 'package:chat/pc/pc_theme.dart';
import 'package:chat/pc/widgets/hover_builder.dart';
import 'package:chat/workspace/wf_webview_screen.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/utils/layout_scale.dart';

/// 桌面端“发现”中栏:与移动端 DiscoveryTab 同一组入口,
/// 但列表页/网页在右栏打开,机器人直接打开会话(经 app_navigator 统一跳转)。
class PcDiscoveryList extends StatelessWidget {
  const PcDiscoveryList({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      children: [
        _DiscoveryRow(
          iconAsset: 'assets/images/discover_chatroom.png',
          title: l10n.chatroom,
          onTap: () => openPage(context, ChatroomList()),
        ),
        _DiscoveryRow(
          iconAsset: 'assets/images/discover_robot.png',
          title: l10n.robot,
          onTap: () => openConversation(context, Conversation(conversationType: ConversationType.Single, target: 'FireRobot')),
        ),
        _DiscoveryRow(
          iconAsset: 'assets/images/discover_channel.png',
          title: l10n.channels,
          onTap: () => openPage(context, const ChannelList()),
        ),
        if (avEngineKit.isSupportConference())
          _DiscoveryRow(
            iconAsset: 'assets/images/discover_channel.png',
            title: l10n.conferenceTitle,
            onTap: () => openPage(context, const ConferenceHomeScreen()),
          ),
        _DiscoveryRow(
          iconAsset: 'assets/images/discover_devdocs.png',
          title: l10n.developmentDocumentation,
          onTap: () => openPage(context, const WFWebViewScreen('https://docs.wildfirechat.cn')),
        ),
        if (Config.panServerAddress != null && Config.panServerAddress!.isNotEmpty)
          _DiscoveryRow(
            iconAsset: 'assets/images/net_disk.png',
            title: l10n.cloudDrive,
            onTap: () => openPage(context, const PanHomeScreen()),
          ),
      ],
    );
  }
}

class _DiscoveryRow extends StatelessWidget {
  final String iconAsset;
  final String title;
  final VoidCallback onTap;

  const _DiscoveryRow({required this.iconAsset, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: LayoutScale.watchScale(context, 48, cap: LayoutScale.rowCap),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: hovered ? context.colors.cellHover : Colors.transparent,
          child: Row(
            children: [
              Image.asset(
                iconAsset,
                width: LayoutScale.watchScale(context, 22, cap: LayoutScale.iconCap),
                height: LayoutScale.watchScale(context, 22, cap: LayoutScale.iconCap),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: PcTheme.cellTitle(context))),
              Icon(
                Icons.chevron_right_rounded,
                size: LayoutScale.watchScale(context, 18, cap: LayoutScale.iconCap),
                color: context.colors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
