import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/notification/notification_message_content.dart';

import '../message_cell.dart';
import 'message_cell_builder.dart';

class NotificationCellBuilder extends MessageCellBuilder {
  String notificaitonMsgDigest = '';

  NotificationCellBuilder(super.context, super.model);

  late StreamSubscription<UserInfoUpdatedEvent> _userInfoUpdatedSubscription;

  @override
  void initState(State<MessageCell> s) {
    super.initState(s);
    // FIXME
    // optimization
    // TODO 更细致的判断，仅包含用户信息的消息，比如加群等消息，需要重新加载 lastMessage
    if (model.message.content is NotificationMessageContent) {
      _userInfoUpdatedSubscription = Imclient.IMEventBus.on<UserInfoUpdatedEvent>().listen((event) {
        _loadLastMessageDigest();
      });
    }
    _loadLastMessageDigest();
  }

  @override
  void dispose() {
    _userInfoUpdatedSubscription?.cancel();
  }

  @override
  Widget buildContent(BuildContext context) {
    return Container(
        padding: const EdgeInsets.fromLTRB(60, 0, 60, 0),
        child: notificaitonMsgDigest.isEmpty
            ? Container(
                width: 200,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              )
            : Text(
                notificaitonMsgDigest,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ));
  }

  // 未使用 futureBuilder
  Future<void> _loadLastMessageDigest() async {
    try {
      var digest = '';
      digest = await model.message.content.digest(model.message);
      if (state.mounted) {
        setState(() {
          notificaitonMsgDigest = digest;
        });
      }
    } catch (error) {
      debugPrint("Error fetching conversation data: $error");
      if (state.mounted) {
        setState(() {
          // 设置默认值以避免UI错误
          notificaitonMsgDigest = "";
        });
      }
    }
  }
}
