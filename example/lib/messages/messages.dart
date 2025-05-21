import 'package:flutter/material.dart';
import 'package:imclient/message/notification/tip_notificiation_content.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:provider/provider.dart';
import 'package:wfc_example/messages/conversation_controller.dart';
import 'package:wfc_example/messages/group_conversation_info_screen.dart';
import 'package:wfc_example/messages/input_bar/message_input_bar.dart';
import 'package:wfc_example/messages/conversation_appbar_title.dart';
import 'package:wfc_example/messages/single_conversation_info_screen.dart';
import 'package:wfc_example/viewmodel/conversation_view_model.dart';

import 'channel_conversation_info.dart';
import 'input_bar/message_input_bar_controller.dart';
import 'message_cell.dart';

class Messages extends StatefulWidget {
  final Conversation conversation;

  const Messages(this.conversation, {super.key});

  @override
  State createState() => _State();
}

class _State extends State<Messages> {
  late ConversationViewModel _conversationViewModel;
  late MessageInputBarController _inputBarController;

  @override
  void initState() {
    super.initState();

    _conversationViewModel = Provider.of<ConversationViewModel>(context, listen: false);
    _conversationViewModel.setConversation(widget.conversation, (err) {
      Fluttertoast.showToast(msg: "网络错误！加入聊天室失败!");
      Navigator.pop(context);
    });

    Imclient.clearConversationUnreadStatus(widget.conversation);
  }

  @override
  void dispose() {
    super.dispose();

    _conversationViewModel.setConversation(null);
    if (widget.conversation.conversationType == ConversationType.Chatroom) {
      Imclient.quitChatroom(widget.conversation.target, () {
        Imclient.getUserInfo(Imclient.currentUserId).then((userInfo) {
          if (userInfo != null) {
            TipNotificationContent tip = TipNotificationContent();
            tip.tip = '${userInfo.displayName} 离开了聊天室';
            _conversationViewModel.sendMessage(tip);
          }
        });
      }, (errorCode) {});
    }
  }

  bool notificationFunction(Notification notification) {
    switch (notification.runtimeType) {
      case ScrollEndNotification:
        var noti = notification as ScrollEndNotification;
        if (noti.metrics.pixels >= noti.metrics.maxScrollExtent) {
          _conversationViewModel.loadHistoryMessage();
        }
        break;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> actions = [];
    if (widget.conversation.conversationType != ConversationType.Chatroom) {
      actions = [
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => widget.conversation.conversationType == ConversationType.Single
                      ? SingleConversationInfoScreen(widget.conversation)
                      : widget.conversation.conversationType == ConversationType.Channel
                          ? ChannelConversationInfoScreen(widget.conversation)
                          : GroupConversationInfoScreen(widget.conversation)),
            );
          },
          icon: const Icon(Icons.more_horiz_rounded),
        )
      ];
    }
    var conversationViewModel = Provider.of<ConversationViewModel>(context);
    var conversationMessageList = conversationViewModel.conversationMessageList;

    return MultiProvider(
        providers: [
          ChangeNotifierProvider<ConversationController>(create: (_) => ConversationController(conversationViewModel)),
          ChangeNotifierProvider<MessageInputBarController>(create: (_) {
            _inputBarController = MessageInputBarController(conversation: widget.conversation, conversationViewModel: conversationViewModel);
            return _inputBarController;
          }),
        ],
        child: Scaffold(
          backgroundColor: const Color.fromARGB(255, 232, 232, 232),
          appBar: AppBar(
            title: ConversationAppbarTitle(widget.conversation),
            actions: actions,
          ),
          body: SafeArea(
            child: Column(
              children: [
                Flexible(
                  child: GestureDetector(
                    child: NotificationListener(
                      onNotification: notificationFunction,
                      child: ListView.builder(
                        reverse: true,
                        itemBuilder: (BuildContext context, int index) => MessageCell(conversationMessageList[index]),
                        itemCount: conversationMessageList.length,
                      ),
                    ),
                    onTap: () {
                      // 使用controller重置状态
                      _inputBarController.resetStatus();
                    },
                  ),
                ),
                MessageInputBar()
              ],
            ),
          ),
        ));
  }

  @override
  void deactivate() {
    // 使用controller获取草稿
    String draft = _inputBarController.getDraft();
    Imclient.setConversationDraft(widget.conversation, draft);
    super.deactivate();
  }
}
