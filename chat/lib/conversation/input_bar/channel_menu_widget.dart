import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/channel_menu_event_message_content.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';

import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/utils/show_toast.dart';
import 'package:chat/utilities.dart';

/// 频道菜单栏(公众号底部菜单)。移动端与桌面端共用一套:
/// 占满输入栏宽度,一级菜单等分排列,带子菜单的项点开后在上方弹出子菜单。
///
/// 菜单行为对齐 Android/iOS/Web 端:
/// - view:打开菜单配置的链接(移动端内嵌 WebView、桌面端外部浏览器)
/// - click:向频道发一条 [ChannelMenuEventMessageContent] 透传消息,由频道后台响应
/// - 其它类型(如 miniprogram)暂不支持,给出提示而不是静默无反应
///
/// [onToggleInput] 非空时在最右侧显示"切回输入框"按钮(桌面端用;
/// 移动端的切换按钮在输入栏左侧,由 MessageInputBar 自己画)。
class ChannelMenuWidget extends StatelessWidget {
  final List<ChannelMenu> menus;
  final Conversation conversation;
  final VoidCallback? onToggleInput;

  const ChannelMenuWidget({
    super.key,
    required this.menus,
    required this.conversation,
    this.onToggleInput,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.colors.hairline)),
      ),
      child: Row(
        children: [
          for (int i = 0; i < menus.length; i++)
            Expanded(
                child: _MenuItem(
                    menu: menus[i],
                    isLast: i == menus.length - 1,
                    onSelected: (m) => _handleMenuSelected(context, m))),
          if (onToggleInput != null)
            IconButton(
              icon: Icon(Icons.keyboard_alt_outlined,
                  size: 22, color: context.colors.iconSecondary),
              tooltip: AppLocalizations.of(context)!.switchToTextInput,
              onPressed: onToggleInput,
            ),
        ],
      ),
    );
  }

  void _handleMenuSelected(BuildContext context, ChannelMenu menu) {
    switch (menu.type) {
      case 'view':
        if (menu.url != null && menu.url!.isNotEmpty) {
          Utilities.openLink(context, menu.url!);
        }
        break;
      case 'click':
        // 透传消息:频道后台收到后自行响应,本地不落库、不计数
        Imclient.sendMessage(
          conversation,
          ChannelMenuEventMessageContent(menu),
          successCallback: (messageUid, timestamp) {},
          errorCallback: (err) {},
        );
        break;
      default:
        showToast(msg: AppLocalizations.of(context)!.notSupported);
        break;
    }
  }
}

/// 一级菜单项。有子菜单时点击在上方弹出子菜单(菜单栏贴着窗口底部,只能向上展开),
/// 没有子菜单时直接执行。
class _MenuItem extends StatelessWidget {
  final ChannelMenu menu;
  final bool isLast;
  final ValueChanged<ChannelMenu> onSelected;

  const _MenuItem(
      {required this.menu, required this.isLast, required this.onSelected});

  /// 子菜单项高度,同时用于计算向上弹出的偏移量
  static const double _subMenuItemHeight = 40;

  bool get _hasSubMenus => menu.subMenus != null && menu.subMenus!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final label = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(right: BorderSide(color: context.colors.hairline)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_hasSubMenus) ...[
            Icon(Icons.menu, size: 14, color: context.colors.iconSecondary),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              menu.name ?? '',
              style: AppText.base.copyWith(color: context.colors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    if (!_hasSubMenus) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelected(menu),
        child: label,
      );
    }

    final subMenus = menu.subMenus!;
    return PopupMenuButton<ChannelMenu>(
      tooltip: menu.name ?? '',
      // 子菜单整体抬到菜单栏上方:项高固定,行数已知,偏移可以算准
      offset: Offset(0, -(subMenus.length * _subMenuItemHeight + 12)),
      itemBuilder: (context) => subMenus
          .map((subMenu) => PopupMenuItem<ChannelMenu>(
                value: subMenu,
                height: _subMenuItemHeight,
                child: Text(subMenu.name ?? '', style: AppText.base),
              ))
          .toList(),
      onSelected: onSelected,
      child: label,
    );
  }
}
