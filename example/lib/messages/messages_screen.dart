import 'dart:async';

import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_imclient/flutter_imclient.dart';
import 'package:flutter_imclient/message/message.dart';
import 'package:flutter_imclient/message/text_message_content.dart';
import 'package:flutter_imclient/model/conversation.dart';
import 'package:flutter_imclient_example/messages/message_cell.dart';
import 'package:flutter_imclient_example/messages/message_model.dart';

class MessagesScreen extends StatefulWidget {
  final Conversation conversation;

  MessagesScreen(this.conversation);

  @override
  _State createState() => _State();
}

class _State extends State<MessagesScreen> {
  List<MessageModel> models = List<MessageModel>();
  EventBus _eventBus = FlutterImclient.IMEventBus;
  StreamSubscription<ReceiveMessagesEvent> _receiveMessageSubscription;

  bool isLoading = false;

  bool noMoreLocalHistoryMsg = false;
  bool noMoreRemoteHistoryMsg = false;

  TextEditingController textEditingController = TextEditingController();

  @override
  void initState() {
    FlutterImclient.getMessages(widget.conversation, 0, 10).then((value) {
      if(value != null && value.isNotEmpty) {
        _appendMessage(value);
      }
    });


    _receiveMessageSubscription = _eventBus.on<ReceiveMessagesEvent>().listen((event) {
      if(!event.hasMore) {
        _appendMessage(event.messages, front: true);
      }
    });

    FlutterImclient.clearConversationUnreadStatus(widget.conversation);
  }

  @override
  void dispose() {
    super.dispose();
    _receiveMessageSubscription?.cancel();
  }

  void _appendMessage(List<Message> messages, {bool front = false}) {
    setState(() {
      bool haveNewMsg = false;
      messages.forEach((element) {
        if(element.conversation != widget.conversation) {
          return;
        }
        if(element.content.meta.flag.index & 0x2 == 0) {
          return;
        }
        haveNewMsg = true;
        MessageModel model = MessageModel(element, showTimeLabel: true);
        if(front)
          models.insert(0, model);
        else
          models.add(model);
      });
      if(haveNewMsg)
        FlutterImclient.clearConversationUnreadStatus(widget.conversation);
    });
  }

  void loadHistoryMessage() {
    if(isLoading)
      return;

    isLoading = true;
    int fromIndex = 0;
    if(models.isNotEmpty) {
      fromIndex = models.last.message.messageId;
    } else {
      isLoading = false;
      return;
    }
    bool noMoreLocalHistoryMsg = false;
    bool noMoreRemoteHistoryMsg = false;

    if(noMoreLocalHistoryMsg) {
      if(noMoreRemoteHistoryMsg) {
        isLoading = false;
        return;
      } else {
        fromIndex = models.last.message.messageUid;
        FlutterImclient.getRemoteMessages(widget.conversation, fromIndex, 20, (messages) {
          if(messages == null || messages.isEmpty) {
            noMoreRemoteHistoryMsg = true;
          }
          isLoading = false;
          _appendMessage(messages);
        }, (errorCode) {
          isLoading = false;
          noMoreRemoteHistoryMsg = true;
        });
      }
    } else {
      FlutterImclient.getMessages(widget.conversation, fromIndex, 20).then((
          value) {
        _appendMessage(value);
        isLoading = false;
        if(value == null || value.isEmpty)
          noMoreLocalHistoryMsg = true;
      });
    }
  }

  bool notificationFunction(Notification notification) {
    switch (notification.runtimeType) {
      case ScrollEndNotification:
        var noti = notification as ScrollEndNotification;
        if(noti.metrics.pixels >= noti.metrics.maxScrollExtent) {
          loadHistoryMessage();
        }
        break;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Message'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: NotificationListener(
              child: ListView.builder(
                reverse: true,
                itemBuilder: (BuildContext context, int index) => MessageCell(models[index]),
                itemCount: models.length,),
              onNotification: notificationFunction,
            )),
            Container(
              height: 100,
              child: Row(
                children: [
                  IconButton(icon: Icon(Icons.record_voice_over), onPressed: null),
                  Expanded(child: TextField(controller: textEditingController,onSubmitted: (text){
                    TextMessageContent txt = TextMessageContent(text:text);
                    FlutterImclient.sendMessage(widget.conversation, txt).then((value) {
                      _appendMessage([value], front: true);
                      textEditingController.clear();
                    });
                  }, onChanged: (text) {
                    print(text);
                  },), ),
                  IconButton(icon: Icon(Icons.emoji_emotions), onPressed: null),
                  IconButton(icon: Icon(Icons.add_circle_outline_rounded), onPressed: null),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
