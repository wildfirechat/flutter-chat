import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:chat/app_navigator.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/utils/media_url_redirector.dart';
import 'package:chat/pc/widgets/pc_page_header.dart';
import 'package:chat/theme/app_colors.dart';

class ChannelInfoWidget extends StatefulWidget {
  final ChannelInfo? channelInfo;
  final String? channelId;

  const ChannelInfoWidget({this.channelInfo, this.channelId, Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ChannelInfoWidgetState();
}

class ChannelInfoWidgetState extends State<ChannelInfoWidget> {
  bool isLoading = true;
  bool isListened = false;
  ChannelInfo? channelInfo;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    channelInfo = widget.channelInfo;
    if (channelInfo == null && widget.channelId != null) {
      channelInfo = await Imclient.getChannelInfo(widget.channelId!);
    }
    if (channelInfo == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }
    isListened = await Imclient.isListenedChannel(channelInfo!.channelId);
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = "频道信息";
    final appBar = isDesktopShell
        ? PcPageHeader(title: title)
        : AppBar(title: Text(title));

    Widget body;
    if (isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (channelInfo == null) {
      body = const Center(child: Text("频道不存在"));
    } else if (isDesktopShell) {
      body = _buildPcBody(context, channelInfo!);
    } else {
      body = ListView.builder(
        itemCount: 7, //头像，名字，拥有者，描述，清空消息，操作（订阅/取消订阅），进入会话
        itemBuilder: (BuildContext context, int index) { return _buildRow(context, index);},
      );
    }

    return Scaffold(
      appBar: appBar,
      body: SafeArea(child: body),
    );
  }

  Widget _buildPcBody(BuildContext context, ChannelInfo info) {
    return Container(
      color: Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6.0),
                    child: info.portrait != null && info.portrait!.isNotEmpty
                        ? Image.network(
                            MediaUrlRedirector.redirect(info.portrait!),
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 72,
                            height: 72,
                            color: Colors.grey[200],
                            child: const Icon(Icons.rss_feed, color: Colors.grey, size: 36),
                          ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.name ?? '',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textPrimary,
                            decoration: TextDecoration.none,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Divider(height: 1, thickness: 0.5, color: context.colors.hairline),
              const SizedBox(height: 20),
              // Meta info
              _buildPcMetaRow("功能介绍", info.desc ?? "暂无介绍"),
              const SizedBox(height: 12),
              _buildPcMetaRow("拥有者", info.owner ?? "无"),
              const SizedBox(height: 20),
              Divider(height: 1, thickness: 0.5, color: context.colors.hairline),
              const SizedBox(height: 36),
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isListened) ...[
                    _buildPcButton("进入会话", context.colors.accent, Colors.white, () {
                      openConversation(context, Conversation(conversationType: ConversationType.Channel, target: info.channelId));
                    }),
                    const SizedBox(width: 16),
                    _buildPcButton("取消订阅", Colors.grey[200]!, context.colors.textPrimary, () {
                      _toggleSubscription(info);
                    }),
                  ] else ...[
                    _buildPcButton("订阅频道", context.colors.accent, Colors.white, () {
                      _toggleSubscription(info);
                    }),
                  ],
                ],
              ),
              const SizedBox(height: 60), // Push content slightly up
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPcMetaRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: context.colors.textSecondary,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: context.colors.textPrimary,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPcButton(String text, Color bgColor, Color textColor, VoidCallback onPressed) {
    return SizedBox(
      width: 120,
      height: 36,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
        ),
      ),
    );
  }

  void _toggleSubscription(ChannelInfo info) {
    Imclient.listenChannel(info.channelId, !isListened, () {
      setState(() {
        isListened = !isListened;
      });
    }, (errorCode) {
      Fluttertoast.showToast(msg: "网络错误！");
    });
  }

  Widget _buildRow(BuildContext context, int index) {
    final info = channelInfo!;
    if(index == 0) {
      return Column(children: [
        const SizedBox(height: 20),
        SizedBox(width: 80, height: 80, child: info.portrait != null && info.portrait!.isNotEmpty ? Image.network(MediaUrlRedirector.redirect(info.portrait!)) : Container(color: Colors.grey),),
        const SizedBox(height: 20),
        Container(
          margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 0.0),
          height: 0.5,
          color: const Color(0xdbdbdbdb),
        )
      ],);
    } else if(index == 1) {
      return Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          const Text("名称:  ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),),
          Text(info.name ?? '', style: const TextStyle(fontSize: 16),),
        ],),),
        Container(
          margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 0.0),
          height: 0.5,
          color: const Color(0xdbdbdbdb),
        ),
      ],);
    } else if(index == 2) {
      return Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          const Text("拥有者:  ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),),
          Text(info.owner ?? '', style: const TextStyle(fontSize: 16),),
        ],),),
        Container(
          margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 0.0),
          height: 0.5,
          color: const Color(0xdbdbdbdb),
        ),
      ],);
    } else if(index == 3) {
      return Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          const Text("描述:  ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),),
          Expanded(child: Text(info.desc ?? '', style: const TextStyle(fontSize: 16),)),
        ],),),
        Container(
          margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 0.0),
          height: 0.5,
          color: const Color(0xdbdbdbdb),
        ),
      ],);
    } else if(index == 4) {
      return GestureDetector(
        child: Column(children: [
          const SizedBox(
            height: 48,
            child: Center(child: Text("清空历史消息", style: TextStyle(color: Colors.red, fontSize: 16),)),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 0.0),
            height: 0.5,
            color: const Color(0xdbdbdbdb),
          ),
        ],),
        onTap: () {},
      );
    } else if(index == 5) {
      return GestureDetector(
        child: Column(children: [
          SizedBox(
            height: 48,
            child: Center(child: Text(isListened?"取消订阅":"订阅频道", style: const TextStyle(color: Colors.red, fontSize: 16),)),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 0.0),
            height: 0.5,
            color: const Color(0xdbdbdbdb),
          ),
        ],),
        onTap: () {
            Imclient.listenChannel(info.channelId, !isListened, () {
              setState(() {
                isListened = !isListened;
              });
            }, (errorCode) {
              Fluttertoast.showToast(msg: "网络错误！");
            });
        },
      );
    } else if(index == 6) {
      if (!isListened) return Container();
      return GestureDetector(
        child: Column(children: [
          const SizedBox(
            height: 48,
            child: Center(child: Text("进入会话", style: TextStyle(color: Colors.blue, fontSize: 16),)),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 0.0),
            height: 0.5,
            color: const Color(0xdbdbdbdb),
          ),
        ],),
        onTap: () {
          openConversation(context, Conversation(conversationType: ConversationType.Channel, target: info.channelId));
        },
      );
    }
    return Container();
  }
}