import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:provider/provider.dart';
import 'package:wfc_example/config.dart';
import 'package:wfc_example/conversation/conversation_screen.dart';
import 'package:wfc_example/viewmodel/channel_view_model.dart';
import 'package:wfc_example/widget/portrait.dart';

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
        return ListTile(
          leading: Portrait(channelInfo.portrait ?? Config.defaultChannelPortrait, Config.defaultChannelPortrait),
          title: Text(channelInfo.name ?? 'Channel'),
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
        );
      },
    );
  }
}
