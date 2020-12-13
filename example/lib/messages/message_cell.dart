import 'package:flutter/material.dart';
import 'package:flutter_imclient/flutter_imclient.dart';
import 'package:flutter_imclient/message/image_message_content.dart';
import 'package:flutter_imclient/message/message.dart';
import 'package:flutter_imclient/message/notification/notification_message_content.dart';
import 'package:flutter_imclient/message/text_message_content.dart';
import 'package:flutter_imclient/model/conversation.dart';
import 'package:flutter_imclient/model/user_info.dart';
import 'package:flutter_imclient_example/messages/message_model.dart';


class MessageCell extends StatefulWidget {
  MessageModel model;

  MessageCell(this.model):super(key: ObjectKey(model));

  @override
  _MessageBaseCellState createState() {
    if(model.message.content is NotificationMessageContent) {
      return _NotificaitonCellState();
    } else if(model.message.content is TextMessageContent) {
      return _TextMessageCell();
    } else if(model.message.content is ImageMessageContent) {
      return _ImageMessageCell();
    }

    return _MessageBaseCellState();
  }
}

class _MessageBaseCellState extends State<MessageCell> {
  @override
  Widget build(BuildContext context) {
    return Padding(padding: EdgeInsets.all(5), child: Column(
      children: [
        widget.model.showTimeLabel ? Padding(padding: EdgeInsets.all(3), child: Text('15:40', style: TextStyle(backgroundColor: Colors.grey[300]),),) : SizedBox(),
        Container(child: getContent(context),),
      ],),
    );
  }

  Widget getContent(BuildContext context) {
    return Text('该消息暂未实现，请升级版本!', textAlign: TextAlign.center,);
  }
}

class _NotificaitonCellState extends _MessageBaseCellState {
  String digest = "";


  @override
  void initState() {
    widget.model.message.content.digest(widget.model.message).then((value) {
      setState(() {
        digest = value;
      });
    });
  }

  @override
  Widget getContent(BuildContext context) {
    return Text(digest, textAlign: TextAlign.center,);
  }
}

class _PortraitCellState extends _MessageBaseCellState {
  UserInfo userInfo;
  final localPortrait = 'assets/images/user_avatar_default.png';
  String portrait;
  String userName;

  @override
  void initState() {
    super.initState();
    String groupId;
    if(widget.model.message.conversation.conversationType == ConversationType.Group) {
      groupId = widget.model.message.conversation.target;
    }

    FlutterImclient.getUserInfo(widget.model.message.fromUser, groupId: groupId).then((value) {
      if(value != null)
      setState(() {
        userInfo = value;
        portrait = userInfo.portrait;
        userName = userInfo.friendAlias != null ? userInfo.friendAlias : userInfo.groupAlias != null ? userInfo.groupAlias : userInfo.displayName;
      });
    });
  }

  @override
  Widget getContent(BuildContext context) {
    return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        widget.model.message.direction == MessageDirection.MessageDirection_Receive ? getPortrait() : getBodyArea(),
        widget.model.message.direction == MessageDirection.MessageDirection_Receive ? getBodyArea() : getPortrait(),
    ],);
  }

  Widget getPortrait() {
    return Container(
      child: portrait == null ? new Image.asset(localPortrait, width: 44.0, height: 44.0) : Image.network(portrait, width: 44.0, height: 44.0),
    );
  }
  Widget getBodyArea() {
    return Expanded(
      child: Column(
        crossAxisAlignment: widget.model.message.direction == MessageDirection.MessageDirection_Receive ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          widget.model.showNameLabel ? Text(userName) : SizedBox(),
          Container(color: Colors.grey,
          child: getContentAres(),),
        ],
      ),
    );
  }

  Widget getContentAres() {
    return Text('内容区没有定义');
  }
}

class _TextMessageCell extends _PortraitCellState {
  TextMessageContent textMessageContent;
  @override
  void initState() {
    super.initState();
    textMessageContent = widget.model.message.content;
  }
  Widget getContentAres() {
    return Text(textMessageContent.text, overflow: TextOverflow.ellipsis, maxLines: 10,);
  }
}

class _ImageMessageCell extends _PortraitCellState {
  ImageMessageContent imageMessageContent;
  @override
  void initState() {
    super.initState();
    imageMessageContent = widget.model.message.content;
  }
  Widget getContentAres() {
    return Image.network(imageMessageContent.remoteUrl, width: 240.0, height: 240.0);
  }
}
