import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:provider/provider.dart';
import 'package:chat/config.dart';
import 'package:chat/conversation/conversation_screen.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/utils/layout_scale.dart';
import 'package:chat/viewmodel/channel_view_model.dart';
import 'package:chat/widget/portrait.dart';

class SubscribedChannelsPage extends StatefulWidget {
  const SubscribedChannelsPage({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => SubscribedChannelsPageState();
}

class SubscribedChannelsPageState extends State<SubscribedChannelsPage> {
  List<String> channelIds = [];

  @override
  void initState() {
    super.initState();
    Imclient.getRemoteListenedChannels((channelIds) {
      if (mounted) {
        setState(() {
          this.channelIds = channelIds;
        });
      }
    }, (errorCode) {
      // Handle error
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('频道'),
      ),
      body: ListView.builder(
        itemCount: channelIds.length,
        itemBuilder: (context, index) {
          return _buildChannelItem(channelIds[index]);
        },
      ),
    );
  }

  Widget _buildChannelItem(String channelId) {
    return Consumer<ChannelViewModel>(
      builder: (context, channelViewModel, child) {
        ChannelInfo? channelInfo = channelViewModel.getChannelInfo(channelId);
        if (channelInfo == null) {
          return Container();
        }
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ConversationScreen(
                  Conversation(conversationType: ConversationType.Channel, target: channelId, line: 0),
                ),
              ),
            );
          },
          hoverColor: context.colors.hoverOverlay,
          child: Container(
            // 行高随字号档位缩放(封顶 rowCap),标题单行省略:
            // 二者配套才能保证最大字号下行与行不重叠。
            height: LayoutScale.watchScale(context, 56.0, cap: LayoutScale.rowCap),
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Portrait(channelInfo.portrait ?? Config.defaultChannelPortrait, Config.defaultChannelPortrait, width: 40, height: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    channelInfo.name ?? 'Channel',
                    style: AppText.lg,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
