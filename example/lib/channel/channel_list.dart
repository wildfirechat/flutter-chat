import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:wfc_example/channel/search_channel.dart';
import 'package:wfc_example/config.dart';

import '../conversation/conversation_screen.dart';

class ChannelList extends StatefulWidget {
  const ChannelList({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ChannelListState();
}

class ChannelListState extends State<ChannelList> {
  List<String>? channelIds;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          GestureDetector(
            onTap: () => _searchChannel(),
            child: Row(
              children: [
                Icon(Icons.add_circle_outline_rounded),
                Padding(padding: EdgeInsets.only(left: 16)),
              ],
            ),
          )
        ],
        title: const Text("订阅的频道"),),
      body: SafeArea(child:
      channelIds == null ? const Center(child: CircularProgressIndicator(),) :
      ListView.builder(
        itemCount: channelIds!.length,
        itemBuilder: (BuildContext context, int index) { return _buildRow(context, index);},)
      ),
    );
  }

  void _searchChannel() {
    showSearch(context: context, delegate: SearchChannelDelegate());
  }

  Widget _buildRow(BuildContext context, int index) {
    String channelId = channelIds![index];
    return GestureDetector(child: ChannelItem(channelId), onTap: () => _toChat(channelId),);
  }

  void _toChat(String channelId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ConversationScreen(Conversation(conversationType: ConversationType.Channel, target: channelId))),
    );
  }

  @override
  void initState() {
    super.initState();
    Imclient.getRemoteListenedChannels((strValues) {
      setState(() {
        channelIds = strValues;
      });
    }, (errorCode) {
      Fluttertoast.showToast(msg: "网络错误");
      Navigator.pop(context);
    });
  }
}

class ChannelItem extends StatefulWidget {
  final String channelId;

  const ChannelItem(this.channelId, {Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ChannelItemState();
}

class ChannelItemState extends State<ChannelItem> {
  ChannelInfo? channelInfo;
  late StreamSubscription<ChannelInfoUpdateEvent> _channelInfoUpdateSubscription;

  @override
  void initState() {
    super.initState();
    _channelInfoUpdateSubscription = Imclient.IMEventBus.on<ChannelInfoUpdateEvent>().listen((event) {
      for (var channel in event.channelInfos) {
        if(channel.channelId == widget.channelId) {
          setState(() {
            channelInfo = channel;
          });
        }
      }
    });

    Imclient.getChannelInfo(widget.channelId).then((ci) {
      setState(() {
        channelInfo = ci;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(8), child: Column(children: [
      Row(children: [
        SizedBox(width: 40, height: 40, child: channelInfo == null || channelInfo!.portrait == null ? Image.asset(Config.defaultChannelPortrait) : Image.network(channelInfo!.portrait!),),
        const Padding(padding: EdgeInsets.all(8)),
        Expanded(child: Text(channelInfo == null || channelInfo!.name == null ? '频道<${widget.channelId}>' : channelInfo!.name!)),
      ],),
      Container(
        margin: const EdgeInsets.fromLTRB(12.0, 4.0, 12.0, 4.0),
        height: 1,
        color: const Color(0xffebebeb),
      )
    ],),);
  }

  @override
  void dispose() {
    super.dispose();
    _channelInfoUpdateSubscription.cancel();
  }
}