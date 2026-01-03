import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_popup/flutter_popup.dart';
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
import 'package:avenginekit/engine/call_state.dart';
import 'package:avenginekit/internal/avenginekit_impl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chat/conversation/picture_overview.dart';
import 'package:chat/conversation/video_player_view.dart';
import 'package:chat/viewmodel/conversation_view_model.dart';
import 'package:chat/app_server.dart';
import 'package:chat/model/favorite_item.dart';

import '../contact/pick_user_screen.dart';
import '../user_info_widget.dart';
import '../ui_model/ui_message.dart';
import 'pick_conversation_screen.dart';
import 'package:provider/provider.dart';
import 'input_bar/message_input_bar_controller.dart';

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

    if (avEngineKit.currentSession == null || avEngineKit.currentSession!.status == CallState.STATUS_IDLE) {
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
            avEngineKit.startCall(conversation, [conversation.target], isAudioOnly);
            // Navigation will be handled by AVEngineCallback.onStartCall
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
                        title: '选择群成员',
                        (context, members) async {
                          if (members.isEmpty) {
                            Fluttertoast.showToast(msg: "请选择一位或者多位成员发起通话");
                          } else {
                            // Group call not implemented yet in this session
                            Fluttertoast.showToast(msg: "群通话暂未实现");
                          }
                        },
                        maxSelected: 9,
                        candidates: members,
                        disabledCheckedUsers: [Imclient.currentUserId],
                      )),
            );
          });
        }
      } else {
        Fluttertoast.showToast(msg: "正在通话中，无法再次发起！");
      }
  }

  void onPressCardBtn(BuildContext context, Conversation conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => PickUserScreen(
                title: '选择联系人',
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
      // if (model.message.conversation.conversationType == ConversationType.Single) {
      //   SingleVideoCallView callView = SingleVideoCallView(userId: conversation.target, audioOnly: callContent.audioOnly);
      //   Navigator.push(context, MaterialPageRoute(builder: (context) => callView));
      // } else if (model.message.conversation.conversationType == ConversationType.Group) {
      //   onPressCallBtn(context, model.message.conversation);
      // }
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
    final messageInputBarController = Provider.of<MessageInputBarController>(context, listen: false);
    List<Map<String, dynamic>> menuItems = [
      {'label': '删除', 'value': 'delete', 'icon': Icons.delete},
    ];

    if (model.message.content is TextMessageContent) {
      menuItems.add({'label': '复制', 'value': 'copy', 'icon': Icons.copy});
    }

    menuItems.add({'label': '转发', 'value': 'forward', 'icon': Icons.forward});

    if (model.message.direction == MessageDirection.MessageDirection_Send &&
        model.message.status == MessageStatus.Message_Status_Sent &&
        DateTime.now().millisecondsSinceEpoch - model.message.serverTime < 120 * 1000) {
      menuItems.add({'label': '撤回', 'value': 'recall', 'icon': Icons.undo});
    }

    menuItems.addAll([
      {'label': '多选', 'value': 'multi_select', 'icon': Icons.checklist},
      {'label': '引用', 'value': 'quote', 'icon': Icons.format_quote},
      {'label': '收藏', 'value': 'favorite', 'icon': Icons.favorite},
    ]);

    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (context, animation, secondaryAnimation) {
          return Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  Navigator.pop(context);
                },
                child: Container(
                  color: Colors.transparent,
                ),
              ),
              Positioned(
                left: position.dx,
                top: position.dy,
                child: _buildPopup(context, menuItems, model, messageInputBarController),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPopup(BuildContext context, List<Map<String, dynamic>> items, UIMessage model, MessageInputBarController messageInputBarController) {
    final GlobalKey<CustomPopupState> popupKey = GlobalKey<CustomPopupState>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      popupKey.currentState?.show();
    });

    const double popupWidth = 250;
    const double padding = 10;
    const int crossAxisCount = 4;
    const double itemWidth = (popupWidth - padding * 2) / crossAxisCount;

    return CustomPopup(
      key: popupKey,
      backgroundColor: const Color(0xFF4C4C4C),
      arrowColor: const Color(0xFF4C4C4C),
      barrierColor: Colors.transparent,
      showArrow: true,
      content: Container(
        width: popupWidth,
        padding: const EdgeInsets.all(padding),
        child: Wrap(
          alignment: WrapAlignment.start,
          children: items.map((item) {
            return _PopupMenuItem(
              item: item,
              width: itemWidth,
              onTap: () {
                Navigator.pop(context);
                _handleMenuItemTap(context, item['value'], model, messageInputBarController);
              },
            );
          }).toList(),
        ),
      ),
      child: const SizedBox(width: 1, height: 1),
    );
  }

  void _handleMenuItemTap(BuildContext context, String value, UIMessage model, MessageInputBarController messageInputBarController) async {
    switch (value) {
      case "delete":
        _showDeleteOptions(context, model);
        break;
      case "copy":
        break;
      case "forward":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PickConversationScreen(
              onConversationSelected: (ctx, conversation) {
                _showForwardDialog(ctx, conversation, model.message);
              },
            ),
          ),
        );
        break;
      case "recall":
        _recallMessage(model.message.messageId, model.message.messageUid!);
        break;
      case "multi_select":
        conversationViewModel.toggleMultiSelectMode();
        conversationViewModel.toggleMessageSelection(model.message.messageId);
        break;
      case "quote":
        messageInputBarController.setQuotedMessage(model.message);
        break;
      case "favorite":
        var item = await FavoriteItem.fromMessage(model.message);
        AppServer.addFavoriteItem(item, () {
          Fluttertoast.showToast(msg: "收藏成功");
        }, (msg) {
          Fluttertoast.showToast(msg: "收藏失败: $msg");
        });
        break;
    }
  }

  void _showForwardDialog(BuildContext context, Conversation target, Message message) async {
    String targetName = target.target;
    if (target.conversationType == ConversationType.Single) {
      var userInfo = await Imclient.getUserInfo(target.target);
      if (userInfo != null) {
        targetName = userInfo.displayName??'<${target.target}';
      }
    } else if (target.conversationType == ConversationType.Group) {
      var groupInfo = await Imclient.getGroupInfo(target.target);
      if (groupInfo != null) {
        targetName = groupInfo.name??'群聊<${groupInfo.target}>';
      }
    }

    if (!context.mounted) return;

    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("发送给：$targetName"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("确定转发这条消息吗？"),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: "给朋友留言"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close Dialog
                Navigator.pop(context); // Close PickConversationScreen
              },
              child: const Text("取消"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close Dialog
                _performForward(target, message, controller.text);
                Navigator.pop(context); // Close PickConversationScreen
              },
              child: const Text("发送"),
            ),
          ],
        );
      },
    );
  }

  void _performForward(Conversation target, Message message, String extraText) {
    Imclient.sendMessage(target, message.content, successCallback: (messageUid, timestamp) {}, errorCallback: (errorCode) {});
    if (extraText.isNotEmpty) {
      TextMessageContent textContent = TextMessageContent(extraText);
      textContent.text = extraText;
      Imclient.sendMessage(target, textContent, successCallback: (messageUid, timestamp) {}, errorCallback: (errorCode) {});
    }
  }

  void _recallMessage(int messageId, int messageUid) {
    Imclient.recallMessage(messageUid, () {}, (errorCode) {});
  }

  void _showDeleteOptions(BuildContext context, UIMessage model) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('删除消息'),
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                _deleteMessage(model.message.messageId);
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('删除本地消息'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                _deleteRemoteMessage(model.message);
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('删除远程消息'),
              ),
            ),
          ],
        );
      },
    );
  }

  void _deleteRemoteMessage(Message message) {
    if (message.messageUid != null && message.messageUid! > 0) {
      Imclient.deleteRemoteMessage(message.messageUid!, () {}, (errorCode) {
        Fluttertoast.showToast(msg: "删除远程消息失败: $errorCode");
      });
    } else {
      _deleteMessage(message.messageId);
    }
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

class _PopupMenuItem extends StatefulWidget {
  final Map<String, dynamic> item;
  final double width;
  final VoidCallback onTap;

  const _PopupMenuItem({
    Key? key,
    required this.item,
    required this.width,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_PopupMenuItem> createState() => _PopupMenuItemState();
}

class _PopupMenuItemState extends State<_PopupMenuItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: Container(
        width: widget.width,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: _isPressed ? Colors.black26 : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.item['icon'], color: Colors.white, size: 24),
            const SizedBox(height: 5),
            Text(
              widget.item['label'],
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

