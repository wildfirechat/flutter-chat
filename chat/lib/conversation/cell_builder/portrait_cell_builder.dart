import 'package:flutter/material.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/sound_message_content.dart';
import 'package:imclient/message/sticker_message_content.dart';
import 'package:imclient/message/video_message_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/conversation/conversation_controller.dart';
import 'package:chat/conversation/read_receipt_status_widget.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/pc_user_card.dart';
import 'package:chat/viewmodel/conversation_view_model.dart';
import 'package:chat/viewmodel/user_view_model.dart';

import '../../config.dart';
import '../../ui_model/ui_message.dart';
import '../../widget/portrait.dart';
import 'message_cell_builder.dart';
import 'package:chat/theme/app_colors.dart';

abstract class PortraitCellBuilder extends MessageCellBuilder {
  late bool isSendMessage;
  ConversationController? conversationController;

  PortraitCellBuilder(BuildContext context, UIMessage model) : super(context, model) {
    try {
      conversationController = Provider.of<ConversationController>(context, listen: false);
    } catch (e) {}
    isSendMessage = model.message.direction == MessageDirection.MessageDirection_Send;
  }

  @override
  Widget buildContent(BuildContext context) {
    return Selector2<UserViewModel, ConversationViewModel, (UserInfo? senderUserInfo, bool showGroupMemberName)>(
        builder: (_, rec, __) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                isSendMessage ? _padding() : _portrait(context, rec.$1),
                _messageContentContainer(context, rec.$1, rec.$2),
                isSendMessage ? _portrait(context, rec.$1) : _padding()
              ],
            ),
        selector: (context, userViewModel, conversationViewModel) => (
              userViewModel.getUserInfo(model.message.fromUser,
                  groupId: model.message.conversation.conversationType == ConversationType.Group ? model.message.conversation.target : null),
              conversationViewModel.isHiddenConversationMemberName
            ));
  }

  final GlobalKey _portraitKey = GlobalKey();

  Widget _portrait(BuildContext context, UserInfo? userInfo) {
    var portrait = userInfo?.portrait ?? Config.defaultUserPortrait;
    return GestureDetector(
      child: Container(
          key: _portraitKey,
          margin: isDesktopShell
              ? EdgeInsets.fromLTRB(isSendMessage ? 8 : 12, 0, isSendMessage ? 12 : 8, 0)
              : const EdgeInsets.fromLTRB(8, 0, 8, 0),
          child: Portrait(portrait, Config.defaultUserPortrait, width: 44.0, height: 44.0, borderRadius: 6.0)),
      // 桌面端点头像弹用户信息卡片(微信 PC 形态),移动端仍整页打开
      onTap: () => isDesktopShell ? _showUserCard(context) : conversationController?.onPortraitTaped(context, model),
      onLongPress: () => conversationController?.onPortraitLongTaped(context, model),
    );
  }

  void _showUserCard(BuildContext context) {
    final renderBox = _portraitKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return;
    }
    final anchor = renderBox.localToGlobal(Offset.zero) & renderBox.size;
    showPcUserCard(
      context: context,
      anchor: anchor,
      userId: model.message.fromUser,
      groupId: model.message.conversation.conversationType == ConversationType.Group ? model.message.conversation.target : null,
    );
  }

  Widget _padding() {
    return SizedBox.fromSize(
      size: const Size(68, 60),
    );
  }

  final GlobalKey _bubbleKey = GlobalKey();

  Widget _messageContentContainer(BuildContext context, UserInfo? senderUserInfo, bool isHiddenGroupMemberName) {
    return Flexible(
      child: Column(
        crossAxisAlignment: isSendMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          !isSendMessage && !isHiddenGroupMemberName
              ? Text(
                  senderUserInfo != null ? senderUserInfo.getReadableName() : '<${model.message.fromUser}>',
                  style: TextStyle(color: context.colors.messageSenderName, fontSize: 12),
                )
              : Container(),
          Row(
            mainAxisAlignment: isSendMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _sendStatus(),
              Flexible(
                fit: FlexFit.loose,
                child: GestureDetector(
                  child: Container(
                    key: _bubbleKey,
                    padding:
                        (model.message.content is ImageMessageContent || model.message.content is VideoMessageContent || model.message.content is StickerMessageContent)
                            ? const EdgeInsets.all(0)
                            : const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      // 桌面端用品牌蓝浅色调气泡,移动端维持原配色;暗色下两端都是实心系统蓝
                      color: isSendMessage
                          ? (isDesktopShell ? context.colors.bubbleSentDesktop : context.colors.bubbleSent)
                          : context.colors.bubbleReceived,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(8),
                        topLeft: Radius.circular(8),
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    // 气泡内的正文色在这里一次性定死,而不是每个 cell_builder 各写一遍:
                    // 暗色下己方气泡是实心蓝,继承主题的灰白正文色对比度不够,必须走纯白。
                    child: DefaultTextStyle.merge(
                      style: TextStyle(
                        color: isSendMessage ? context.colors.bubbleSentText : context.colors.bubbleReceivedText,
                      ),
                      child: buildMessageContent(context),
                    ),
                  ),
                  onTap: () => conversationController?.onTapedCell(context, model),
                  onDoubleTap: () => conversationController?.onDoubleTapedCell(model),
                  onLongPressStart: (details) {
                    final RenderBox? renderBox = _bubbleKey.currentContext?.findRenderObject() as RenderBox?;
                    Rect? bubbleRect;
                    if (renderBox != null) {
                      final offset = renderBox.localToGlobal(Offset.zero);
                      bubbleRect = offset & renderBox.size;
                    }
                    conversationController?.onLongPressedCell(context, model, bubbleRect);
                  },
                  // 桌面端右键在鼠标位置弹出同一套消息菜单
                  onSecondaryTapUp: (details) {
                    conversationController?.onLongPressedCell(
                        context, model, Rect.fromCenter(center: details.globalPosition, width: 4, height: 4));
                  },
                ),
              ),
              _playStatus(context),
            ],
          ),
          Container(
            padding: const EdgeInsets.only(bottom: 3),
          )
        ],
      ),
    );
  }

  Widget _sendStatus() {
    if (model.message.direction == MessageDirection.MessageDirection_Send) {
      if (model.message.status == MessageStatus.Message_Status_Sending) {
        return Container(
          margin: const EdgeInsets.all(5),
          width: 10,
          height: 10,
          child: const CircularProgressIndicator(),
        );
      } else if (model.message.status == MessageStatus.Message_Status_Send_Failure) {
        return GestureDetector(
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Image.asset(
              'assets/images/message_send_failure.png',
              width: 20,
              height: 20,
            ),
          ),
          onTap: () => conversationController?.onResendTaped(model),
        );
      } else if (model.message.status == MessageStatus.Message_Status_Sent || model.message.status == MessageStatus.Message_Status_Readed) {
        return ReadReceiptStatusWidget(model.message);
      }
    }

    return Container();
  }

  Widget _playStatus(BuildContext context) {
    if (model.message.content is SoundMessageContent) {
      if (model.message.direction == MessageDirection.MessageDirection_Receive && model.message.status == MessageStatus.Message_Status_Readed) {
        return Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 0, 8),
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: context.colors.badge, borderRadius: const BorderRadius.all(Radius.circular(8))),
        );
      }
    }
    return Container();
  }

  @override
  Widget buildMessageContent(BuildContext context);
}
