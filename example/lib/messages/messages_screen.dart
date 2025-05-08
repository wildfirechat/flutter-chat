import 'dart:async';

import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:imclient/message/call_start_message_content.dart';
import 'package:imclient/message/notification/tip_notificiation_content.dart';
import 'package:logger/logger.dart' show Level, Logger;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image/image.dart' as img;
import 'package:imclient/imclient.dart';
import 'package:imclient/message/card_message_content.dart';
import 'package:imclient/message/file_message_content.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/message/sound_message_content.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:imclient/message/typing_message_content.dart';
import 'package:imclient/message/video_message_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:rtckit/group_video_call.dart';
import 'package:rtckit/rtckit.dart';
import 'package:rtckit/single_voice_call.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wfc_example/messages/cell_builder/voice_cell_builder.dart';
import 'package:wfc_example/messages/conversation_notifier.dart';
import 'package:wfc_example/messages/conversation_settings.dart';
import 'package:wfc_example/messages/input_bar/message_input_bar.dart';
import 'package:wfc_example/messages/conversation_appbar_title.dart';
import 'package:wfc_example/messages/picture_overview.dart';
import 'package:wfc_example/messages/video_player_view.dart';
import 'package:wfc_example/viewmodel/conversation_view_model.dart';

import '../contact/contact_select_page.dart';
import '../user_info_widget.dart';
import 'message_cell.dart';
import '../ui_model/ui_message.dart';

class MessagesScreen extends StatefulWidget {
  final Conversation conversation;

  const MessagesScreen(this.conversation, {Key? key}) : super(key: key);

  @override
  State createState() => _State();
}

class _State extends State<MessagesScreen> {
  List<UIMessage> models = <UIMessage>[];
  final EventBus _eventBus = Imclient.IMEventBus;

  late ConversationViewModel conversationViewModel;

  String title = "消息";

  final GlobalKey<MessageInputBarState> _inputBarGlobalKey = GlobalKey();

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

    Imclient.getConversationInfo(widget.conversation).then((conversationInfo) {
      _inputBarGlobalKey.currentState!.setDrat(conversationInfo.draft ?? "");
    });
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
    super.dispose();
    if (_soundPlayer.isPlaying) {
      _soundPlayer.stopPlayer();
    }
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

  void onDoubleTapedCell(UIMessage model) {
    debugPrint("on double taped cell");
  }

  void onLongPressedCell(UIMessage model, Offset postion) {
    _showPopupMenu(model, postion);
  }

  void onPortraitTaped(UIMessage model) {
    debugPrint("on taped portrait");
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UserInfoWidget(model.message.fromUser)),
    );
  }

  void onPortraitLongTaped(UIMessage model) {
    debugPrint("on long taped portrait");
  }

  void onResendTaped(UIMessage model) {
    debugPrint("on taped resend");
    Imclient.sendSavedMessage(model.message.messageId, successCallback: (l, ll) {}, errorCallback: (errorCode) {});
  }

  void onReadedTaped(UIMessage model) {
    debugPrint("on taped readed");
  }

  void _showPopupMenu(UIMessage model, Offset position) {
    List<PopupMenuItem> items = [
      const PopupMenuItem(
        value: 'delete',
        child: Text('删除'),
      )
    ];

    if (model.message.content is TextMessageContent) {
      items.add(const PopupMenuItem(value: 'copy', child: Text('复制')));
    }

    items.add(const PopupMenuItem(
      value: 'forward',
      child: Text('转发'),
    ));

    if (model.message.direction == MessageDirection.MessageDirection_Send &&
        model.message.status == MessageStatus.Message_Status_Sent &&
        DateTime.now().millisecondsSinceEpoch - model.message.serverTime < 120 * 1000) {
      items.add(const PopupMenuItem(
        value: 'recall',
        child: Text('撤回'),
      ));
    }

    items.addAll([
      const PopupMenuItem(
        value: 'multi_select',
        child: Text('多选'),
      ),
      const PopupMenuItem(
        value: 'quote',
        child: Text('引用'),
      ),
      const PopupMenuItem(
        value: 'favorite',
        child: Text('收藏'),
      )
    ]);

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: items,
    ).then((selected) {
      if (selected != null) {
        switch (selected) {
          case "delete":
            _deleteMessage(model.message.messageId);
            break;
          case "copy":
            break;
          case "forward":
            break;
          case "recall":
            _recallMessage(model.message.messageId, model.message.messageUid!);
            break;
          case "multi_select":
            break;
          case "quote":
            break;
          case "favorite":
            break;
        }
      }
    });
  }

  void _recallMessage(int messageId, int messageUid) {
    Imclient.recallMessage(messageUid, () {}, (errorCode) {});
  }

  void _deleteMessage(int messageId) {
    Imclient.deleteMessage(messageId).then((value) {
      setState(() {
        for (var model in models) {
          if (model.message.messageId == messageId) {
            models.remove(model);
            break;
          }
        }
      });
    });
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
    return ChangeNotifierProvider<ConversationNotifier>(
        create: (_) => ConversationNotifier(),
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
                      _inputBarGlobalKey.currentState!.resetStatus();
                    },
                  ),
                ),
                _getInputBar(),
              ],
            ),
          ),
        ));
  }

  Widget _getInputBar() {
    return MessageInputBar(
      widget.conversation,
      key: _inputBarGlobalKey,
    );
  }

  @override
  void deactivate() {
    String draft = _inputBarGlobalKey.currentState!.getDraft();
    Imclient.setConversationDraft(widget.conversation, draft);
    super.deactivate();
  }
}
