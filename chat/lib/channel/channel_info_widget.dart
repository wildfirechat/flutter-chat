import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:chat/app_navigator.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/utils/media_url_redirector.dart';
import 'package:chat/pc/widgets/pc_icon_action.dart';
import 'package:chat/pc/widgets/pc_page_header.dart';
import 'package:chat/pc/widgets/pc_pane_content.dart';
import 'package:chat/pc/widgets/pc_profile.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';

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
    final l10n = AppLocalizations.of(context)!;
    // 桌面端:频道名字就写在正文里,标题栏再写一遍「频道详情」是多余的 —— 走无标题栏形态。
    final appBar = isDesktopShell
        ? const PcPageHeader(bare: true)
        : AppBar(title: Text(l10n.channelDetails));

    Widget body;
    if (isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (channelInfo == null) {
      body = Center(child: Text(l10n.channelNotExist));
    } else if (isDesktopShell) {
      body = _buildPcBody(context, channelInfo!);
    } else {
      body = ListView.builder(
        itemCount: 7, //头像，名字，拥有者，描述，清空消息，操作（订阅/取消订阅），进入会话
        itemBuilder: (BuildContext context, int index) { return _buildRow(context, index);},
      );
    }

    return Scaffold(
      backgroundColor: isDesktopShell ? context.colors.surface : null,
      appBar: appBar,
      body: SafeArea(child: body),
    );
  }

  /// 桌面端右栏:与用户资料页同一套形态(限宽居中 + 弱分隔线 + 底部图标动作),
  /// 见 pc_profile.dart。
  Widget _buildPcBody(BuildContext context, ChannelInfo info) {
    final l10n = AppLocalizations.of(context)!;
    final accent = context.colors.accent;
    final hasPortrait = info.portrait != null && info.portrait!.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: PcPaneContent(
        maxWidth: kPcProfileWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PcProfileHeader(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: hasPortrait
                    ? Image.network(
                        MediaUrlRedirector.redirect(info.portrait!),
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 64,
                        height: 64,
                        color: context.colors.hoverOverlay,
                        child: Icon(Icons.rss_feed, color: context.colors.textTertiary, size: 32),
                      ),
              ),
              title: Text(
                info.name ?? '',
                style: PcProfileHeader.titleStyle(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const PcProfileDivider(),
            PcProfileRow(label: l10n.channelIntro, value: info.desc, placeholder: l10n.noIntro),
            PcProfileRow(label: l10n.channelOwner, value: info.owner),
            const PcProfileDivider(),
            PcProfileActions(children: [
              if (isListened) ...[
                PcIconAction(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: l10n.enterConversation,
                  labelColor: accent,
                  onTap: () => openConversation(context, Conversation(conversationType: ConversationType.Channel, target: info.channelId)),
                ),
                PcIconAction(
                  icon: Icons.notifications_off_outlined,
                  label: l10n.unsubscribeChannel,
                  labelColor: accent,
                  onTap: () => _toggleSubscription(info),
                ),
              ] else
                PcIconAction(
                  icon: Icons.add_circle_outline,
                  label: l10n.subscribeChannel,
                  labelColor: accent,
                  onTap: () => _toggleSubscription(info),
                ),
            ]),
          ],
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
          Text("名称:  ", style: AppText.lg.copyWith(fontWeight: FontWeight.bold),),
          Text(info.name ?? '', style: AppText.lg,),
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
          Text("拥有者:  ", style: AppText.lg.copyWith(fontWeight: FontWeight.bold),),
          Text(info.owner ?? '', style: AppText.lg,),
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
          Text("描述:  ", style: AppText.lg.copyWith(fontWeight: FontWeight.bold),),
          Expanded(child: Text(info.desc ?? '', style: AppText.lg,)),
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
          SizedBox(
            height: 48,
            child: Center(child: Text("清空历史消息", style: AppText.lg.copyWith(color: Colors.red),)),
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
            child: Center(child: Text(isListened?"取消订阅":"订阅频道", style: AppText.lg.copyWith(color: Colors.red),)),
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
          SizedBox(
            height: 48,
            child: Center(child: Text("进入会话", style: AppText.lg.copyWith(color: Colors.blue),)),
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