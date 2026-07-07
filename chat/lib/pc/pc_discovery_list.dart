import 'package:flutter/material.dart';
import 'package:imclient/model/conversation.dart';
import 'package:chat/app_navigator.dart';
import 'package:chat/channel/channel_list.dart';
import 'package:chat/discovery/chatroom_list.dart';
import 'package:chat/pc/pc_theme.dart';
import 'package:chat/pc/widgets/hover_builder.dart';
import 'package:chat/workspace/wf_webview_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
        _DiscoveryRow(
          iconAsset: 'assets/images/discover_devdocs.png',
          title: l10n.developmentDocumentation,
          onTap: () => openPage(context, const WFWebViewScreen('https://docs.wildfirechat.cn')),
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
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: hovered ? PcTheme.cellHover : Colors.transparent,
          child: Row(
            children: [
              Image.asset(iconAsset, width: 22, height: 22),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: PcTheme.cellTitle)),
              const Icon(Icons.chevron_right_rounded, size: 18, color: PcTheme.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
