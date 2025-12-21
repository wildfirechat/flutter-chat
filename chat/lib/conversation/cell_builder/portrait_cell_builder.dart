import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/sound_message_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/conversation/conversation_controller.dart';
import 'package:chat/conversation/read_receipt_status_widget.dart';
import 'package:chat/viewmodel/conversation_view_model.dart';
import 'package:chat/viewmodel/user_view_model.dart';

import '../../config.dart';
import '../../ui_model/ui_message.dart';
import '../../widget/portrait.dart';
import 'message_cell_builder.dart';

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

  Widget _portrait(BuildContext context, UserInfo? userInfo) {
    var portrait = userInfo?.portrait ?? Config.defaultUserPortrait;
    return GestureDetector(
      child:
          Container(margin: const EdgeInsets.fromLTRB(8, 0, 8, 0), child: Portrait(portrait, Config.defaultUserPortrait, width: 44.0, height: 44.0, borderRadius: 6.0)),
      onTap: () => conversationController?.onPortraitTaped(context, model),
      onLongPress: () => conversationController?.onPortraitLongTaped(model),
    );
  }

  Widget _padding() {
    return SizedBox.fromSize(
      size: const Size(68, 60),
    );
  }

  Widget _messageContentContainer(BuildContext context, UserInfo? senderUserInfo, bool isHiddenGroupMemberName) {
    return Flexible(
      child: Column(
        crossAxisAlignment: isSendMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          !isHiddenGroupMemberName ? Text(senderUserInfo != null ? senderUserInfo.getReadableName() : '<${model.message.fromUser}>') : Container(),
          Row(
            mainAxisAlignment: isSendMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _sendStatus(),
              Flexible(
                child: GestureDetector(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSendMessage ? Colors.green : Colors.white,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(8),
                        topLeft: Radius.circular(8),
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    child: buildMessageContent(context),
                  ),
                  onTap: () => conversationController?.onTapedCell(context, model),
                  onDoubleTap: () => conversationController?.onDoubleTapedCell(model),
                  onLongPressStart: (details) => conversationController?.onLongPressedCell(context, model, details.globalPosition),
                ),
              ),
              _playStatus(),
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

  Widget _playStatus() {
    if (model.message.content is SoundMessageContent) {
      if (model.message.direction == MessageDirection.MessageDirection_Receive && model.message.status == MessageStatus.Message_Status_Readed) {
        return Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 0, 8),
          width: 8,
          height: 8,
          decoration: const BoxDecoration(color: Colors.red, borderRadius: BorderRadius.all(Radius.circular(8))),
        );
      }
    }
    return Container();
  }

  @override
  Widget buildMessageContent(BuildContext context);
}
