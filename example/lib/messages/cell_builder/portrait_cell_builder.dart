
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/user_info.dart';

import '../../config.dart';
import '../message_cell.dart';
import '../message_model.dart';
import 'message_cell_builder.dart';

abstract class PortraitCellBuilder extends MessageCellBuilder {
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
  }

  @override
  Widget getContent(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        isSendMessage ?getPadding():getPortrait(),
        getBodyArea(),
        isSendMessage ?getPortrait():getPadding()
      ],
    );
  }

  Widget getPortrait() {
    return GestureDetector(
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 0),
        child: portrait == null ? Image.asset(Config.defaultUserPortrait, width: 44.0, height: 44.0) : Image.network(portrait!, width: 44.0, height: 44.0),
      ),
      onTap: () => state.onTapedPortrait(model),
      onLongPress: () => state.onLongTapedPortrait(model),
    );
  }

  Widget getPadding() {
    return SizedBox.fromSize(size: const Size(68, 60),);
  }

  Widget getBodyArea() {
    return Flexible(
      child: Column(
        crossAxisAlignment: isSendMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          model.showNameLabel ? Text(userName!) : Container(),
          Container(
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
            child: GestureDetector(
              child: getContentAres(),
              onTap: () => state.onTaped(model),
              onDoubleTap: () => state.onDoubleTaped(model),
            ),
          ),
            Container(padding: const EdgeInsets.only(bottom: 3),)
        ],
      ),
    );
  }

  Widget getContentAres();
}
