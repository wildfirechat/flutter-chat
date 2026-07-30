import 'package:flutter/material.dart';
import 'package:avenginekit/engine/avenginekit.dart';
import 'package:imclient/model/conversation.dart';
import 'package:moment/moment.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/call/conference/conference_home_screen.dart';
import 'package:chat/channel/channel_list.dart';
import 'package:chat/conversation/conversation_screen.dart';
import 'package:chat/discovery/chatroom_list.dart';
import 'package:chat/pan/pan_home_screen.dart';
import 'package:chat/widget/option_item.dart';
import 'package:chat/theme/app_colors.dart';

import '../config.dart';
import '../workspace/wf_webview_screen.dart';

class DiscoveryTab extends StatelessWidget {
  const DiscoveryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.colors.primaryBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                color: context.colors.surface,
                child: Column(
                  children: [
                    if (Config.ENABLE_MOMENTS)
                      OptionItem(
                        l10n.momentWindowTitle,
                        leftImage: Image.asset(
                            'assets/images/discover_moments.png',
                            width: 20.0,
                            height: 20.0),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const FeedListPage()),
                          );
                        },
                      ),
                    OptionItem(
                      l10n.chatroom,
                      leftImage: Image.asset(
                          'assets/images/discover_chatroom.png',
                          width: 20.0,
                          height: 20.0),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => ChatroomList()),
                        );
                      },
                    ),
                    OptionItem(
                      l10n.robot,
                      leftImage: Image.asset('assets/images/discover_robot.png',
                          width: 20.0, height: 20.0),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => ConversationScreen(
                                  Conversation(
                                      conversationType: ConversationType.Single,
                                      target: 'FireRobot'))),
                        );
                      },
                    ),
                    if (avEngineKit.isSupportConference())
                      OptionItem(
                        l10n.conferenceTitle,
                        leftImage: Image.asset(
                            'assets/images/discover_channel.png',
                            width: 20.0,
                            height: 20.0),
                        showBottomDivider: false,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const ConferenceHomeScreen()),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                color: context.colors.surface,
                child: Column(
                  children: [
                    OptionItem(
                      l10n.developmentDocumentation,
                      leftImage: Image.asset(
                          'assets/images/discover_devdocs.png',
                          width: 20.0,
                          height: 20.0),
                      showBottomDivider: Config.panServerAddress != null &&
                          Config.panServerAddress!.isNotEmpty,
                      onTap: () {
                        var url = 'https://docs.wildfirechat.cn';
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => WFWebViewScreen(url)),
                        );
                      },
                    ),
                    if (Config.panServerAddress != null &&
                        Config.panServerAddress!.isNotEmpty)
                      OptionItem(
                        l10n.cloudDrive,
                        leftImage: Image.asset('assets/images/net_disk.png',
                            width: 20.0, height: 20.0),
                        showBottomDivider: false,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const PanHomeScreen()),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
