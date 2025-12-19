import 'package:flutter/material.dart';
import 'package:imclient/model/conversation.dart';
import 'package:wfc_example/channel/channel_list.dart';
import 'package:wfc_example/conversation/conversation_screen.dart';
import 'package:wfc_example/discovery/chatroom_list.dart';
import 'package:wfc_example/widget/option_item.dart';

import '../workspace/wf_webview_screen.dart';

class DiscoveryTab extends StatelessWidget {
  const DiscoveryTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              OptionItem(
                '聊天室',
                leftImage: Image.asset('assets/images/discover_chatroom.png', width: 20.0, height: 20.0),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ChatroomList()),
                  );
                },
              ),
              OptionItem(
                '机器人',
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
                '频道',
                leftImage: Image.asset('assets/images/discover_channel.png', width: 20.0, height: 20.0),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ChannelList()),
                  );
                },
              ),
              OptionItem(
                '开发文档',
                leftImage: Image.asset('assets/images/discover_devdocs.png', width: 20.0, height: 20.0),
                onTap: () {
                  var url = 'https://docs.wildfirechat.cn';
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => WFWebViewScreen(url)),
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