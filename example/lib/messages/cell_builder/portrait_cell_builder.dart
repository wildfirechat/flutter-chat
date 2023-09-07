
import 'dart:async';

import 'package:event_bus/event_bus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/sound_message_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/user_info.dart';

import '../../config.dart';
import '../message_cell.dart';
import '../message_model.dart';
import 'message_cell_builder.dart';

abstract class PortraitCellBuilder extends MessageCellBuilder {
  final EventBus _eventBus = Imclient.IMEventBus;
  late StreamSubscription<SendMessageSuccessEvent> _sendSuccessSubscription;
  late StreamSubscription<SendMessageProgressEvent> _sendProgressSubscription;
  late StreamSubscription<SendMessageMediaUploadedEvent> _sendUploadedSubscription;
  late StreamSubscription<SendMessageFailureEvent> _sendFailureSubscription;

  UserInfo? userInfo;
  String? portrait;
  String? userName;
  late bool isSendMessage;

  PortraitCellBuilder(MessageState state, MessageModel model) : super(state, model) {
    String groupId = "";
    isSendMessage = model.message.direction == MessageDirection.MessageDirection_Send;
    if(model.message.conversation.conversationType == ConversationType.Group) {
      groupId = model.message.conversation.target;
    }

    Imclient.getUserInfo(model.message.fromUser, groupId: groupId).then((value) {
      if(value != null) {
        setState(() {
          userInfo = value;
          if(userInfo!.portrait != null && userInfo!.portrait!.isNotEmpty) {
            portrait = userInfo!.portrait;
          }
          userName = userInfo!.friendAlias ?? (userInfo?.groupAlias != null ? userInfo!.groupAlias : userInfo!.displayName);
        });
      }
    });

    _sendSuccessSubscription = _eventBus.on<SendMessageSuccessEvent>().listen((event) {
      if(event.messageId > 0 && event.messageId == model.message.messageId) {
        if(model.message.status == MessageStatus.Message_Status_Sending) {
          model.message.status = MessageStatus.Message_Status_Sent;
        }
        setState(() { });
      }
    });
    _sendProgressSubscription = _eventBus.on<SendMessageProgressEvent>().listen((event) {
      if(event.messageId > 0 && event.messageId == model.message.messageId) {
        setState(() { });
      }
    });
    _sendFailureSubscription = _eventBus.on<SendMessageFailureEvent>().listen((event) {
      if(event.messageId > 0 && event.messageId == model.message.messageId) {
        if(model.message.status != MessageStatus.Message_Status_Send_Failure) {
          model.message.status == MessageStatus.Message_Status_Send_Failure;
        }
        setState(() { });
      }
    });
    _sendUploadedSubscription = _eventBus.on<SendMessageMediaUploadedEvent>().listen((event) {
      if(event.messageId > 0 && event.messageId == model.message.messageId) {
        setState(() { });
      }
    });
  }

  @override
  Widget getContent(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        isSendMessage ?getPadding():getPortrait(),
        getBodyArea(context),
        isSendMessage ?getPortrait():getPadding()
      ],
    );
  }

  @override
  void dispose() {
    _sendSuccessSubscription.cancel();
    _sendProgressSubscription.cancel();
    _sendUploadedSubscription.cancel();
    _sendFailureSubscription.cancel();
  }

  Widget getPortrait() {
    return GestureDetector(
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 0),
        child: SizedBox(width: 40, height: 40, child: portrait == null ? Image.asset(Config.defaultUserPortrait, width: 44.0, height: 44.0) : Image.network(portrait!, width: 44.0, height: 44.0),),
      ),
      onTap: () => state.onTapedPortrait(model),
      onLongPress: () => state.onLongTapedPortrait(model),
    );
  }

  Widget getPadding() {
    return SizedBox.fromSize(size: const Size(68, 60),);
  }

  Widget getBodyArea(BuildContext context) {
    return Flexible(
      child: Column(
        crossAxisAlignment: isSendMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          model.showNameLabel ? Text(userName!) : Container(),
          Row(
            mainAxisAlignment: isSendMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              getSendStatus(),
              Flexible(
                  child: GestureDetector(
                    child:Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSendMessage ? Colors.green :  Colors.white,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(8),
                          topLeft: Radius.circular(8),
                          bottomLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      child: getContentAres(context),
                    ),
                    onTap: () => state.onTaped(model),
                    onDoubleTap: () => state.onDoubleTaped(model),
                    onLongPressStart: (details) => state.onLongPress(details, model),
                  ),
              ),
              getUnplayed(),
            ],
          ),
          Container(padding: const EdgeInsets.only(bottom: 3),)
        ],
      ),
    );
  }

  Widget getSendStatus() {
    if(model.message.direction == MessageDirection.MessageDirection_Send) {
      if(model.message.status == MessageStatus.Message_Status_Sending) {
        return Container(
          margin: const EdgeInsets.all(5),
          width: 10,
          height: 10,
          child: const CircularProgressIndicator(),
        );
      } else if(model.message.status == MessageStatus.Message_Status_Send_Failure) {
        return GestureDetector(
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Image.asset('assets/images/message_send_failure.png', width: 20, height: 20,),
          ),
          onTap: ()=>state.onResendTaped(model),
        );
      }
    }

    return Container();
  }

  Widget getUnplayed() {
    if(model.message.direction == MessageDirection.MessageDirection_Receive && model.message.status == MessageStatus.Message_Status_Readed && model.message.content is SoundMessageContent) {
      return Container(
        margin: const EdgeInsets.only(left: 8),
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.all(Radius.circular(8))
        ),
      );
    }
    return Container();
  }

  Widget getContentAres(BuildContext context);
}
