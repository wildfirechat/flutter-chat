import 'dart:async';

import 'package:event_bus/event_bus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/file_message_content.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/user_info.dart';
import 'package:rtckit/rtckit.dart';

import 'message_cell.dart';
import 'message_model.dart';


class MessagesScreen extends StatefulWidget {
  final Conversation conversation;

  MessagesScreen(this.conversation, {Key? key}) : super(key: key);

  @override
  State createState() => _State();
}

class _State extends State<MessagesScreen> {
  List<MessageModel> models = <MessageModel>[];
  final EventBus _eventBus = Imclient.IMEventBus;
  late StreamSubscription<ReceiveMessagesEvent> _receiveMessageSubscription;

  bool isLoading = false;

  bool noMoreLocalHistoryMsg = false;
  bool noMoreRemoteHistoryMsg = false;

  String title = "消息";

  UserInfo? userInfo;
  GroupInfo? groupInfo;
  ChannelInfo? channelInfo;
  List<GroupMember>? groupMembers;

  TextEditingController textEditingController = TextEditingController();

  @override
  void initState() {
    Imclient.getMessages(widget.conversation, 0, 10).then((value) {
      if(value != null && value.isNotEmpty) {
        _appendMessage(value);
      }
    });


    _receiveMessageSubscription = _eventBus.on<ReceiveMessagesEvent>().listen((event) {
      if(!event.hasMore) {
        _appendMessage(event.messages, front: true);
      }
    });

    Imclient.clearConversationUnreadStatus(widget.conversation);

    if(widget.conversation.conversationType == ConversationType.Single) {
      Imclient.getUserInfo(widget.conversation.target, refresh: true).then((value){
        setState(() {
          userInfo = value;
          if(userInfo != null) {
            if (userInfo!.friendAlias != null && userInfo!.friendAlias!.isNotEmpty) {
              title = userInfo!.friendAlias!;
            } else if(userInfo!.displayName != null) {
              title = userInfo!.displayName!;
            }
          }
        });
      });
    } else if(widget.conversation.conversationType == ConversationType.Group) {
      Imclient.getGroupInfo(widget.conversation.target, refresh: true).then((value) {
        setState(() {
          groupInfo = value;
          if(groupInfo != null) {
            if(groupInfo!.remark != null && groupInfo!.remark!.isNotEmpty) {
              title = groupInfo!.remark!;
            } else if(groupInfo!.name != null) {
              title = groupInfo!.name!;
            }
          }
        });
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    _receiveMessageSubscription?.cancel();
  }

  void _appendMessage(List<Message> messages, {bool front = false}) {
    setState(() {
      bool haveNewMsg = false;
      for (var element in messages) {
        if(element.conversation != widget.conversation) {
          continue;
        }
        if(element.messageId == 0) {
          continue;
        }

        if(element.status == MessageStatus.Message_Status_AllMentioned || element.status == MessageStatus.Message_Status_Mentioned || element.status == MessageStatus.Message_Status_Unread) {
          haveNewMsg = true;
        }

        MessageModel model = MessageModel(element, showTimeLabel: false);
        if(front) {
          models.insert(0, model);
        } else {
          models.add(model);
        }
      }

      for(int i = 0; i < models.length; ++i) {
        MessageModel model = models[i];
        if(i < models.length - 1) {
          MessageModel nextModel = models[i+1];
          if(model.message.serverTime - nextModel.message.serverTime > 60 * 1000) {
            model.showTimeLabel = true;
          } else {
            model.showTimeLabel = false;
          }
        } else {
          model.showTimeLabel = true;
        }
      }

      if(haveNewMsg) {
        Imclient.clearConversationUnreadStatus(widget.conversation);
      }
    });
  }

  void loadHistoryMessage() {
    if(isLoading) {
      return;
    }

    isLoading = true;
    int? fromIndex = 0;
    if(models.isNotEmpty) {
      fromIndex = models.last.message.messageId;
    } else {
      isLoading = false;
      return;
    }

    if(noMoreLocalHistoryMsg) {
      if(noMoreRemoteHistoryMsg) {
        isLoading = false;
        return;
      } else {
        fromIndex = models.last.message.messageUid;
        Imclient.getRemoteMessages(widget.conversation, fromIndex!, 20, (messages) {
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
      Imclient.getMessages(widget.conversation, fromIndex!, 20).then((
          value) {
        _appendMessage(value);
        isLoading = false;
        if(value == null || value.isEmpty) {
          noMoreLocalHistoryMsg = true;
        }
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

  void onTapedCell(MessageModel model) {
    debugPrint("on taped cell");
  }

  void onDoubleTapedCell(MessageModel model) {
    debugPrint("on double taped cell");
  }

  void onPortraitTaped(MessageModel model) {
    debugPrint("on taped portrait");
  }

  void onPortraitLongTaped(MessageModel model) {
    debugPrint("on long taped portrait");
  }

  void onResendTaped(MessageModel model) {
    debugPrint("on taped resend");
  }

  void onReadedTaped(MessageModel model) {
    debugPrint("on taped readed");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 232, 232, 232),
      appBar: AppBar(
        title: Text(title),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Flexible(
                child: NotificationListener(
                  onNotification: notificationFunction,
                  child: ListView.builder(
                  reverse: true,
                  itemBuilder: (BuildContext context, int index) => MessageCell(
                          models[index],
                          (model)=> onTapedCell(model),
                          (model)=>onDoubleTapedCell(model),
                          (model)=>onPortraitTaped(model),
                          (model)=>onPortraitLongTaped(model),
                          (model)=>onResendTaped(model),
                          (model)=>onReadedTaped(model),
                  ),
                  itemCount: models.length,),
              ),
            ),
            _getInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _getInputBar() {
    return SizedBox(
      height: 100,
      child: Row(
        children: [
          IconButton(icon: Icon(Icons.record_voice_over), onPressed: null),
          Expanded(child: TextField(controller: textEditingController,onSubmitted: (text){
            TextMessageContent txt = TextMessageContent(text);
            Imclient.sendMessage(widget.conversation, txt, successCallback: (int messageUid, int timestamp){
              print("scuccess");
            }, errorCallback: (int errorCode) {
              print("send failure!");
            }).then((value) {
              if(value != null) {
                _appendMessage([value], front: true);
              }
              textEditingController.clear();
            });
          }, onChanged: (text) {
            print(text);
          },), ),
          IconButton(icon: Icon(Icons.emoji_emotions), onPressed: null),
          IconButton(icon: Icon(Icons.file_copy_rounded), onPressed: () {
            FilePicker.platform.pickFiles().then((value) {
              if(value != null && value.files.isNotEmpty) {
                String path = value.files.first.name;
                int size = value.files.first.size;

                FileMessageContent fileCnt = FileMessageContent();
                fileCnt.name = path;
                fileCnt.size = size;
                Imclient.sendMediaMessage(widget.conversation, fileCnt, successCallback: (int messageUid, int timestamp) {

                }, errorCallback: (int errorCode) {

                }, progressCallback: (int uploaded, int total) {

                }, uploadedCallback: (String remoteUrl) {

                }).then((message) {
                  if(message.messageId! > 0) {
                    _appendMessage([message], front: true);
                  }
                });
              }
            });
          }),
          IconButton(icon: Icon(Icons.add_circle_outline_rounded), onPressed: () {
              var picker = ImagePicker();
              picker.pickImage(source: ImageSource.gallery).then((value) {
                ImageMessageContent imgCont = ImageMessageContent();
                imgCont.localPath = value?.path;
                Imclient.sendMediaMessage(widget.conversation, imgCont,
                    successCallback: (int messageUid, int timestamp){
                      debugPrint("send success $messageUid");
                    }, errorCallback: (int errorCode) {
                      debugPrint("send failure $errorCode");
                    }, progressCallback: (int uploaded, int total) {
                      debugPrint("send progress $uploaded/$total");
                    }, uploadedCallback: (String remoteUrl) {
                      debugPrint("send uploaded $remoteUrl");
                    }).then((message) {
                      if(message.messageId! > 0) {
                        _appendMessage([message], front: true);
                      }
                });
              });
              }
            ),
          IconButton(icon: Icon(Icons.camera_enhance_rounded), onPressed: (){
            if(widget.conversation.conversationType == ConversationType.Single) {
              Rtckit.startSingleCall(widget.conversation.target, true);
            } else if(widget.conversation.conversationType == ConversationType.Group) {
              //Select participants first;
              // List<String> participants = List();
              // Future<List<GroupMember>> members = Imclient.getGroupMembers(widget.conversation.target);
              Rtckit.startMultiCall(widget.conversation.target, ["nl0qmws2k"], true);
            }
          }),
        ],
      ),
    );
  }
}
