import 'package:flutter/material.dart';
import 'package:imclient/model/conversation.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:chat/channel/channel_list.dart';
import 'package:chat/conversation/conversation_screen.dart';
import 'package:chat/discovery/chatroom_list.dart';
import 'package:chat/pan/pan_home_screen.dart';
import 'package:chat/widget/option_item.dart';

import '../config.dart';
import '../workspace/wf_webview_screen.dart';

class DiscoveryTab extends StatelessWidget {
  const DiscoveryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              OptionItem(
                l10n.chatroom,
                leftImage: Image.asset('assets/images/discover_chatroom.png', width: 20.0, height: 20.0),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ChatroomList()),
                  );
                },
              ),
              OptionItem(
                l10n.robot,
                leftImage: Image.asset('assets/images/discover_robot.png', width: 20.0, height: 20.0),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ConversationScreen(
                            Conversation(conversationType: ConversationType.Single, target: 'FireRobot'))),
                  );
                },
              ),
              OptionItem(
                l10n.channels,
                leftImage: Image.asset('assets/images/discover_channel.png', width: 20.0, height: 20.0),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ChannelList()),
                  );
                },
              ),
              OptionItem(
                l10n.developmentDocumentation,
                leftImage: Image.asset('assets/images/discover_devdocs.png', width: 20.0, height: 20.0),
                onTap: () {
                  var url = 'https://docs.wildfirechat.cn';
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => WFWebViewScreen(url)),
                  );
                },
              ),
              if (Config.panServerAddress != null && Config.panServerAddress!.isNotEmpty)
                OptionItem(
                  '云盘',
                  leftImage: const Icon(Icons.cloud, color: Colors.blue, size: 20),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PanHomeScreen()),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}