import 'dart:async';

import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/sound_message_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/user_info.dart';

import '../../config.dart';
import '../../user_info_widget.dart';
import '../message_cell.dart';
import '../../ui_model/ui_message.dart';
import 'message_cell_builder.dart';

abstract class PortraitCellBuilder extends MessageCellBuilder {

  UserInfo? userInfo;
  String? portrait;
  String? userName;
  late bool isSendMessage;
  late MessageCell messageCell;

  PortraitCellBuilder(MessageCell messageCell, UIMessage model) : super(model) {
    String groupId = "";
    isSendMessage = model.message.direction == MessageDirection.MessageDirection_Send;
    this.messageCell = messageCell;
    if (model.message.conversation.conversationType == ConversationType.Group) {
      groupId = model.message.conversation.target;
    }
  }

  @override
  Widget buildContent(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [isSendMessage ? _padding() : _portrait(context), _messageContentContainer(context), isSendMessage ? _portrait(context) : _padding()],
    );
  }

  Widget _portrait(BuildContext context) {
    return GestureDetector(
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 0),
        child: SizedBox(
          width: 40,
          height: 40,
          child: portrait == null ? Image.asset(Config.defaultUserPortrait, width: 44.0, height: 44.0) : Image.network(portrait!, width: 44.0, height: 44.0),
        ),
      ),
      onTap: () => messageCell.onTapedPortrait(model),
      onLongPress: () => messageCell.onLongTapedPortrait(model),
    );
  }

  Widget _padding() {
    return SizedBox.fromSize(
      size: const Size(68, 60),
    );
  }

  Widget _messageContentContainer(BuildContext context) {
    return Flexible(
      child: Column(
        crossAxisAlignment: isSendMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          model.showNameLabel ? Text(userName!) : Container(),
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
                  onTap: () => messageCell.onTaped(model),
                  onDoubleTap: () => messageCell.onDoubleTaped(model),
                  onLongPressStart: (details) => messageCell.onLongPress(details, model),
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
          onTap: () => messageCell.onResendTaped(model),
        );
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

  Widget buildMessageContent(BuildContext context);
}
