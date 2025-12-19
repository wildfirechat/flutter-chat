import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';

import '../../workspace/wf_webview_screen.dart';

class ChannelMenuWidget extends StatelessWidget {
  final List<ChannelMenu> menus;
  final Conversation conversation;

  const ChannelMenuWidget({Key? key, required this.menus, required this.conversation}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFDDDDDD))),
      ),
      child: Row(
        children: menus.map((menu) {
          if (menu.subMenus != null && menu.subMenus!.isNotEmpty) {
            return Expanded(
              child: PopupMenuButton<ChannelMenu>(
                itemBuilder: (context) => menu.subMenus!.map((subMenu) {
                  return PopupMenuItem(
                    value: subMenu,
                    child: Text(subMenu.name ?? ''),
                  );
                }).toList(),
                onSelected: (menu) => _handleMenuSelected(context, menu),
                offset: Offset(0, -(menu.subMenus!.length * 48.0) - 10),
                child: Container(
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: Color(0xFFDDDDDD))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.menu, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        menu.name ?? '',
                        style: const TextStyle(fontSize: 16, color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          } else {
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _handleMenuSelected(context, menu),
                child: Container(
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: Color(0xFFDDDDDD))),
                  ),
                  child: Text(
                    menu.name ?? '',
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            );
          }
        }).toList(),
      ),
    );
  }

  void _handleMenuSelected(BuildContext context, ChannelMenu menu) {
    if (menu.type == 'view' && menu.url != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => WFWebViewScreen(menu.url!)),
      );
    } else if (menu.type == 'click') {
      if (menu.name != null) {
        // TODO
        // ChannelMenuEventMessageContent
        Imclient.sendMessage(conversation, TextMessageContent(menu.name!), successCallback: (messageUid, timestamp) {}, errorCallback: (err) {});
      }
    }
  }
}
