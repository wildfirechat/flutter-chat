import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:imclient/message/notification/tip_notificiation_content.dart';
import 'package:logger/logger.dart' show Level, Logger;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/message/sound_message_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:provider/provider.dart';
import 'package:wfc_example/messages/cell_builder/voice_cell_builder.dart';
import 'package:wfc_example/messages/conversation_controller.dart';
import 'package:wfc_example/messages/conversation_settings.dart';
import 'package:wfc_example/messages/input_bar/message_input_bar.dart';
import 'package:wfc_example/messages/conversation_appbar_title.dart';
import 'package:wfc_example/viewmodel/conversation_view_model.dart';

import 'input_bar/message_input_bar_controller.dart';
import 'message_cell.dart';
import '../ui_model/ui_message.dart';

class Messages extends StatefulWidget {
  final Conversation conversation;

  const Messages(this.conversation, {Key? key}) : super(key: key);

  @override
  State createState() => _State();
}

class _State extends State<Messages> {
  final EventBus _eventBus = Imclient.IMEventBus;

  late ConversationViewModel conversationViewModel;
  late MessageInputBarController _inputBarController;

  int _playingMessageId = 0;
  final FlutterSoundPlayer _soundPlayer = FlutterSoundPlayer(logLevel: Level.error);

  @override
  void initState() {
    super.initState();

    conversationViewModel = Provider.of<ConversationViewModel>(context, listen: false);
    conversationViewModel.setConversation(widget.conversation, (err) {
      Fluttertoast.showToast(msg: "网络错误！加入聊天室失败!");
      Navigator.pop(context);
    });

    Imclient.clearConversationUnreadStatus(widget.conversation);

  }

  void _sendMessage(MessageContent messageContent) {
    Imclient.sendMediaMessage(widget.conversation, messageContent, successCallback: (int messageUid, int timestamp) {}, errorCallback: (int errorCode) {},
        progressCallback: (int uploaded, int total) {
      debugPrint("progressCallback:$uploaded,$total");
    }, uploadedCallback: (String remoteUrl) {
      debugPrint("uploadedCallback:$remoteUrl");
    });
  }

  @override
  void dispose() {
    // 释放controller资源
    _inputBarController.dispose();
    super.dispose();
    if (_soundPlayer.isPlaying) {
      _soundPlayer.stopPlayer();
    }
    conversationViewModel.setConversation(null);
    if (widget.conversation.conversationType == ConversationType.Chatroom) {
      Imclient.quitChatroom(widget.conversation.target, () {
        Imclient.getUserInfo(Imclient.currentUserId).then((userInfo) {
          if (userInfo != null) {
            TipNotificationContent tip = TipNotificationContent();
            tip.tip = '${userInfo.displayName} 离开了聊天室';
            _sendMessage(tip);
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
          conversationViewModel.loadHistoryMessage();
        }
        break;
    }
    return true;
  }

  void stopPlayVoiceMessage(UIMessage model) {
    if (_soundPlayer.isPlaying) {
      _soundPlayer.stopPlayer();
    }
    _eventBus.fire(VoicePlayStatusChangedEvent(model.message.messageId, false));
    _playingMessageId = 0;
  }

  void startPlayVoiceMessage(UIMessage model) {
    SoundMessageContent soundContent = model.message.content as SoundMessageContent;
    if (model.message.direction == MessageDirection.MessageDirection_Receive && model.message.status == MessageStatus.Message_Status_Readed) {
      Imclient.updateMessageStatus(model.message.messageId, MessageStatus.Message_Status_Played);
      model.message.status = MessageStatus.Message_Status_Played;
    }
    _soundPlayer.openPlayer();
    _soundPlayer.startPlayer(
        fromURI: soundContent.remoteUrl!,
        whenFinished: () {
          stopPlayVoiceMessage(model);
        });
    _eventBus.fire(VoicePlayStatusChangedEvent(model.message.messageId, true));
    _playingMessageId = model.message.messageId;
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
              MaterialPageRoute(builder: (context) => ConversationSettingPage(widget.conversation)),
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
            title: const ConversationAppbarTitle(),
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
                        itemBuilder: (BuildContext context, int index) => MessageCell(context, conversationMessageList[index]),
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
