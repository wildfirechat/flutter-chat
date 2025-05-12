import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:imclient/message/call_start_message_content.dart';
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
import 'package:imclient/message/video_message_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/user_info.dart';
import 'package:rtckit/group_video_call.dart';
import 'package:rtckit/rtckit.dart';
import 'package:rtckit/single_voice_call.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wfc_example/messages/picture_overview.dart';
import 'package:wfc_example/messages/video_player_view.dart';
import 'package:wfc_example/viewmodel/conversation_view_model.dart';

import '../contact/pick_user_screen.dart';
import '../user_info_widget.dart';
import '../ui_model/ui_message.dart';

class ConversationController extends ChangeNotifier {

  late ConversationViewModel conversationViewModel;

  ConversationController(this.conversationViewModel);

  final GlobalKey<PictureOverviewState> _pictureOverviewKey = GlobalKey();


  int _playingMessageId = 0;
  final FlutterSoundPlayer _soundPlayer = FlutterSoundPlayer(logLevel: Level.error);

  void onPickImage(Conversation conversation, String imagePath) {
    ImageMessageContent imgCont = ImageMessageContent();
    imgCont.localPath = imagePath;
    _sendMessage(conversation, imgCont);
  }

  void onPickFile(Conversation conversation, String filePath, String name, int size) {
    FileMessageContent fileCnt = FileMessageContent();
    fileCnt.name = name;
    fileCnt.size = size;
    fileCnt.localPath = filePath;
    _sendMessage(conversation, fileCnt);
  }

  void onPressCallBtn(BuildContext context, Conversation conversation) {
    if (conversation.conversationType != ConversationType.Single && conversation.conversationType != ConversationType.Group) {
      return;
    }

    Rtckit.currentCallSession().then((currentSession) {
      if (currentSession == null || currentSession.state == kWFAVEngineStateIdle) {
        if (conversation.conversationType == ConversationType.Single) {
          final double centerX = MediaQuery.of(context).size.width / 2;
          final double centerY = MediaQuery.of(context).size.height / 2;

          // 计算菜单位置
          const double menuWidth = 150.0; // 菜单的宽度
          const double menuHeight = 100.0; // 菜单的高度
          final double left = centerX - (menuWidth / 2) - 36;
          final double top = centerY - (menuHeight / 2) - 24;

          showMenu(
            context: context,
            position: RelativeRect.fromLTRB(left, top, left + menuWidth, top + menuHeight),
            items: <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'voice',
                child: SizedBox(
                  width: menuWidth,
                  child: Text('音频通话'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'video',
                child: SizedBox(
                  width: menuWidth,
                  child: Text('视频通话'),
                ),
              ),
            ],
          ).then((value) {
            if (value == null) {
              return;
            }

            bool isAudioOnly = value == 'voice';
            SingleVideoCallView callView = SingleVideoCallView(userId: conversation.target, audioOnly: isAudioOnly);
            Navigator.push(context, MaterialPageRoute(builder: (context) => callView));
          });
        } else if (conversation.conversationType == ConversationType.Group) {
          Imclient.getGroupMembers(conversation.target).then((groupMembers) {
            List<String> members = [];
            for (var gm in groupMembers) {
              members.add(gm.memberId);
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => PickUserScreen(
                        (context, members) async {
                          if (members.isEmpty) {
                            Fluttertoast.showToast(msg: "请选择一位或者多位成员发起通话");
                          } else {
                            GroupVideoCallView callView = GroupVideoCallView(groupId: conversation.target, participants: members);
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => callView),
                            );
                          }
                        },
                        maxSelected: Rtckit.maxAudioCallCount,
                        candidates: members,
                        disabledCheckedUsers: [Imclient.currentUserId],
                      )),
            );
          });
        }
      } else {
        Fluttertoast.showToast(msg: "正在通话中，无法再次发起！");
      }
    });
  }

  void onPressCardBtn(BuildContext context, Conversation conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => PickUserScreen(
                (context, members) async {
                  if (members.isNotEmpty) {
                    UserInfo? userInfo = await Imclient.getUserInfo(members.first);
                    CardMessageContent cardCnt = CardMessageContent();
                    cardCnt.type = CardType.CardType_User;
                    cardCnt.targetId = members.first;
                    if (userInfo != null) {
                      cardCnt.name = userInfo.name;
                      cardCnt.displayName = userInfo.displayName;
                      cardCnt.portrait = userInfo.portrait;
                    }
                    _sendMessage(conversation, cardCnt);
                  }
                  Navigator.pop(context);
                },
                maxSelected: 1,
              )),
    );
  }

  void cameraCaptureImage(Conversation conversation, String imagePath) {
    ImageMessageContent imgContent = ImageMessageContent();
    imgContent.localPath = imagePath;
    _sendMessage(conversation, imgContent);
  }

  void cameraCaptureVideo(Conversation conversation, String videoPath, img.Image? thumbnail, int duration) {
    VideoMessageContent videoContent = VideoMessageContent();
    videoContent.duration = duration;
    videoContent.localPath = videoPath;
    videoContent.thumbnail = thumbnail;
    _sendMessage(conversation, videoContent);
  }

  void onSoundRecorded(Conversation conversation, String soundPath, int duration) {
    SoundMessageContent soundMessageContent = SoundMessageContent();
    soundMessageContent.localPath = soundPath;
    soundMessageContent.duration = duration;
    _sendMessage(conversation, soundMessageContent);
  }

  void _sendMessage(Conversation conversation, MessageContent messageContent) {
    Imclient.sendMediaMessage(conversation, messageContent, successCallback: (int messageUid, int timestamp) {}, errorCallback: (int errorCode) {},
        progressCallback: (int uploaded, int total) {
      debugPrint("progressCallback:$uploaded,$total");
    }, uploadedCallback: (String remoteUrl) {
      debugPrint("uploadedCallback:$remoteUrl");
    });
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

  void onTapedCell(BuildContext context, UIMessage model) {
    var conversation = model.message.conversation;
    if (model.message.content is ImageMessageContent) {
      Imclient.getMessages(conversation, model.message.messageId, 10, contentTypes: [MESSAGE_CONTENT_TYPE_IMAGE]).then((value1) {
        Imclient.getMessages(conversation, model.message.messageId, -10, contentTypes: [MESSAGE_CONTENT_TYPE_IMAGE]).then((value2) {
          List<Message> list = [];
          list.addAll(value2);
          list.add(model.message);
          list.addAll(value1);
          int index = 0;
          for (int i = 0; i < list.length; i++) {
            if (list[i].messageId == model.message.messageId) {
              index = i;
              break;
            }
          }
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => PictureOverview(
                      list,
                      defaultIndex: index,
                      pageToEnd: (fromIndex, tail) {
                        if (tail) {
                          Imclient.getMessages(conversation, fromIndex, 10, contentTypes: [MESSAGE_CONTENT_TYPE_IMAGE]).then((value) {
                            if (value.isNotEmpty) {
                              _pictureOverviewKey.currentState!.onLoadMore(value, false);
                            }
                          });
                        } else {
                          Imclient.getMessages(conversation, fromIndex, -10, contentTypes: [MESSAGE_CONTENT_TYPE_IMAGE]).then((value) {
                            if (value.isNotEmpty) {
                              _pictureOverviewKey.currentState!.onLoadMore(value, true);
                            }
                          });
                        }
                      },
                      key: _pictureOverviewKey,
                    )),
          );
        });
      });
    } else if (model.message.content is VideoMessageContent) {
      VideoMessageContent videoContent = model.message.content as VideoMessageContent;
      Navigator.push(context, MaterialPageRoute(builder: (context) => VideoPlayerView(videoContent.remoteUrl!)));
    } else if (model.message.content is FileMessageContent) {
      FileMessageContent fileContent = model.message.content as FileMessageContent;
      canLaunchUrl(Uri.parse(fileContent.remoteUrl!)).then((value) {
        if (value) {
          launchUrl(Uri.parse(fileContent.remoteUrl!));
        } else {
          Fluttertoast.showToast(msg: '无法打开');
        }
      });
    } else if (model.message.content is SoundMessageContent) {
      if (_playingMessageId == model.message.messageId) {
        stopPlayVoiceMessage(model);
      } else {
        // TODO
        // if (_playingMessageId > 0) {
        //   for (var value in models) {
        //     if (value.message.messageId == _playingMessageId) {
        //       stopPlayVoiceMessage(model);
        //       break;
        //     }
        //   }
        // }

        startPlayVoiceMessage(model);
      }
    } else if (model.message.content is CallStartMessageContent) {
      CallStartMessageContent callContent = model.message.content as CallStartMessageContent;
      if (model.message.conversation.conversationType == ConversationType.Single) {
        SingleVideoCallView callView = SingleVideoCallView(userId: conversation.target, audioOnly: callContent.audioOnly);
        Navigator.push(context, MaterialPageRoute(builder: (context) => callView));
      } else if (model.message.conversation.conversationType == ConversationType.Group) {
        onPressCallBtn(context, model.message.conversation);
      }
    }
  }

  void stopPlayVoiceMessage(UIMessage model) {
    if (_soundPlayer.isPlaying) {
      _soundPlayer.stopPlayer();
    }
    // TODO
    //_eventBus.fire(VoicePlayStatusChangedEvent(model.message.messageId, false));
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
    // TODO
    //_eventBus.fire(VoicePlayStatusChangedEvent(model.message.messageId, true));
    _playingMessageId = model.message.messageId;
  }

  void onDoubleTapedCell(UIMessage model) {
    debugPrint("on double taped cell");
  }

  void onLongPressedCell(BuildContext context, UIMessage model, Offset postion) {
    _showPopupMenu(context, model, postion);
  }

  void onPortraitTaped(BuildContext context, UIMessage model) {
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

  void _showPopupMenu(BuildContext context, UIMessage model, Offset position) {
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
    conversationViewModel.deleteMessage(messageId);
  }

  @override
  void dispose() {
    super.dispose();
    if (_soundPlayer.isPlaying) {
      _soundPlayer.stopPlayer();
    }
  }

}
