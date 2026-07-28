import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:chat/channel/search_channel.dart';
import 'package:chat/config.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/widgets/pc_page_header.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/utils/layout_scale.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
    final actions = [
      IconButton(
        icon: const Icon(Icons.add_circle_outline_rounded),
        onPressed: () => _searchChannel(),
      ),
      const SizedBox(width: 8),
    ];

    return Scaffold(
      appBar: isDesktopShell
          ? PcPageHeader(
              title: l10n.subscribedChannelsTitle,
              actions: actions,
            )
          : AppBar(
              title: Text(l10n.subscribedChannelsTitle),
              actions: actions,
            ),
      body: SafeArea(child:
      channelIds == null ? const Center(child: CircularProgressIndicator(),) :
      ListView.separated(
        itemCount: channelIds!.length,
        separatorBuilder: (context, __) => Divider(
          indent: 16.0 + LayoutScale.watchScale(context, 40.0, cap: LayoutScale.iconCap) + 12.0,
        ),
        itemBuilder: (BuildContext context, int index) { return _buildRow(context, index);},)
      ),
    );
  }

  void _searchChannel() {
    showSearch(context: context, delegate: SearchChannelDelegate(searchFieldHint: AppLocalizations.of(context)!.searchChannelHint));
  }

  Widget _buildRow(BuildContext context, int index) {
    String channelId = channelIds![index];
    return ChannelItem(channelId, onTap: () => _toChat(channelId));
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
      Fluttertoast.showToast(msg: AppLocalizations.of(context)!.networkError);
      Navigator.pop(context);
    });
  }
}

class ChannelItem extends StatefulWidget {
  final String channelId;
  final VoidCallback? onTap;

  const ChannelItem(this.channelId, {Key? key, this.onTap}) : super(key: key);

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
    return InkWell(
      onTap: widget.onTap,
      hoverColor: context.colors.hoverOverlay,
      child: Container(
        // 行高随字号档位缩放(封顶 rowCap),标题单行省略:
        // 二者配套才能保证最大字号下行与行不重叠。
        height: LayoutScale.watchScale(context, 56.0, cap: LayoutScale.rowCap),
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            Portrait(channelInfo?.portrait ?? Config.defaultChannelPortrait, Config.defaultChannelPortrait, width: 40, height: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                channelInfo?.name ?? AppLocalizations.of(context)!.channelWithTarget(widget.channelId),
                style: AppText.lg,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _channelInfoUpdateSubscription.cancel();
  }
}