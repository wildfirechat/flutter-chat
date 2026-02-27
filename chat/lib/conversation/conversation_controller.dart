import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:imclient/message/call_start_message_content.dart';
import 'package:logger/logger.dart' show Level, Logger;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image/image.dart' as img;
import 'package:imclient/imclient.dart';
import 'package:imclient/message/card_message_content.dart';
import 'package:imclient/message/collection_message_content.dart';
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
import 'package:chat/conversation/mm_preview_view.dart';
import 'package:chat/viewmodel/conversation_view_model.dart';
import 'package:chat/app_server.dart';
import 'package:chat/config.dart';
import 'package:chat/model/favorite_item.dart';
import 'package:chat/widget/popup_menu_overlay.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../collection/collection_detail_screen.dart';
import '../contact/pick_user_screen.dart';
import '../user_info_widget.dart';
import '../ui_model/ui_message.dart';
import 'pick_forward_target_page.dart';
import 'package:provider/provider.dart';
import 'input_bar/message_input_bar_controller.dart';
import 'package:chat/event_bus.dart';
import 'package:chat/conversation/cell_builder/voice_cell_builder.dart';

import 'package:chat/conversation/read_receipt_detail_screen.dart';

class ConversationController extends ChangeNotifier {
  late ConversationViewModel conversationViewModel;

  ConversationController(this.conversationViewModel);

  final GlobalKey<MMPreviewViewState> _mmPreviewKey = GlobalKey();

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
              PopupMenuItem<String>(
                value: 'voice',
                child: SizedBox(
                  width: menuWidth,
                  child: Text(AppLocalizations.of(context)!.audioCallAction),
                ),
              ),
              PopupMenuItem<String>(
                value: 'video',
                child: SizedBox(
                  width: menuWidth,
                  child: Text(AppLocalizations.of(context)!.videoCallAction),
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
                        title: AppLocalizations.of(context)!.pickGroupMember,
                        (context, members) async {
                          if (members.isEmpty) {
                            Fluttertoast.showToast(msg: AppLocalizations.of(context)!.selectMemberToCall);
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
        Fluttertoast.showToast(msg: AppLocalizations.of(context)!.callInProgress);
      }
    });
  }

  void onPressCardBtn(BuildContext context, Conversation conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => PickUserScreen(
                title: AppLocalizations.of(context)!.pickContact,
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
    if(thumbnail != null){
      videoContent.thumbnail = img.encodeJpg(thumbnail, quality: 30);
    }
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
    if (model.message.content is ImageMessageContent || model.message.content is VideoMessageContent) {
      Imclient.getMessages(conversation, model.message.messageId, 10, contentTypes: [MESSAGE_CONTENT_TYPE_IMAGE, MESSAGE_CONTENT_TYPE_VIDEO]).then((eldMsgs) {
        Imclient.getMessages(conversation, model.message.messageId, -10, contentTypes: [MESSAGE_CONTENT_TYPE_IMAGE, MESSAGE_CONTENT_TYPE_VIDEO]).then((newerMsgs) {
          List<Message> list = [];
          list.addAll(eldMsgs.reversed);
          list.add(model.message);
          list.addAll(newerMsgs);
          int index = eldMsgs.length;
          Navigator.push(
            context,
            PageRouteBuilder(
              opaque: false,
              pageBuilder: (context, animation, secondaryAnimation) => MMPreviewView(
                list,
                defaultIndex: index,
                pageToEnd: (fromIndex, tail) {
                  if (tail) {
                    Imclient.getMessages(conversation, fromIndex, -10, contentTypes: [MESSAGE_CONTENT_TYPE_IMAGE, MESSAGE_CONTENT_TYPE_VIDEO]).then((value) {
                      if (value.isNotEmpty) {
                        _mmPreviewKey.currentState!.onLoadMore(value, false);
                      }
                    });
                  } else {
                    Imclient.getMessages(conversation, fromIndex, 10, contentTypes: [MESSAGE_CONTENT_TYPE_IMAGE, MESSAGE_CONTENT_TYPE_VIDEO]).then((value) {
                      if (value.isNotEmpty) {
                        _mmPreviewKey.currentState!.onLoadMore(value, true);
                      }
                    });
                  }
                },
                key: _mmPreviewKey,
              ),
            ),
          );
        });
      });
    } else if (model.message.content is FileMessageContent) {
      FileMessageContent fileContent = model.message.content as FileMessageContent;
      canLaunchUrl(Uri.parse(fileContent.remoteUrl!)).then((value) {
        if (value) {
          launchUrl(Uri.parse(fileContent.remoteUrl!));
        } else {
          Fluttertoast.showToast(msg: AppLocalizations.of(context)!.cannotOpen);
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
    } else if (model.message.content is CollectionMessageContent) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CollectionDetailScreen(message: model.message),
        ),
      );
    }
  }

  void stopPlayVoiceMessage(UIMessage model) {
    if (_soundPlayer.isPlaying) {
      _soundPlayer.stopPlayer();
    }
    eventBus.fire(VoicePlayStatusChangedEvent(model.message.messageId, false));
    _playingMessageId = 0;
  }

  void startPlayVoiceMessage(UIMessage model) async {
    SoundMessageContent soundContent = model.message.content as SoundMessageContent;
    if (model.message.direction == MessageDirection.MessageDirection_Receive) {
      Imclient.updateMessageStatus(model.message.messageId, MessageStatus.Message_Status_Played);
      model.message.status = MessageStatus.Message_Status_Played;
    }
    await _soundPlayer.openPlayer();
    await _soundPlayer.startPlayer(
        fromURI: soundContent.remoteUrl!,
        whenFinished: () {
          stopPlayVoiceMessage(model);
        });
    eventBus.fire(VoicePlayStatusChangedEvent(model.message.messageId, true));
    _playingMessageId = model.message.messageId;
  }

  void onDoubleTapedCell(UIMessage model) {
    debugPrint("on double taped cell");
  }

  void onLongPressedCell(BuildContext context, UIMessage model, Rect? bubbleRect) {
    _showPopupMenu(context, model, bubbleRect);
  }

  void onPortraitTaped(BuildContext context, UIMessage model) {
    debugPrint("on taped portrait");
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UserInfoWidget(model.message.fromUser)),
    );
  }

  void onPortraitLongTaped(BuildContext context, UIMessage model) {
    debugPrint("on long taped portrait");
    String userId = model.message.fromUser;
    var conversation = model.message.conversation;
    if (conversation.conversationType == ConversationType.Group) {
      Imclient.getUserInfo(userId, groupId: conversation.target).then((userInfo) {
        if (userInfo != null) {
          final messageInputBarController = Provider.of<MessageInputBarController>(context, listen: false);
          messageInputBarController.insertMention(userInfo);
        }
      });
    } else {
      Imclient.getUserInfo(userId).then((userInfo) {
        if (userInfo != null) {
          final messageInputBarController = Provider.of<MessageInputBarController>(context, listen: false);
          messageInputBarController.insertText("${userInfo.displayName} ");
        }
      });
    }
  }

  void onResendTaped(UIMessage model) {
    debugPrint("on taped resend");
    Imclient.deleteMessage(model.message.messageId);
    Imclient.sendMessage(model.message.conversation, model.message.content, successCallback: (l, ll) {}, errorCallback: (errorCode) {});
  }

  void onReadedTaped(BuildContext context, UIMessage model) {
    debugPrint("on taped readed");
    if (model.message.conversation.conversationType == ConversationType.Group) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReadReceiptDetailScreen(model.message),
        ),
      );
    }
  }

  void _showPopupMenu(BuildContext context, UIMessage model, Rect? bubbleRect) {
    final messageInputBarController = Provider.of<MessageInputBarController>(context, listen: false);
    List<Map<String, dynamic>> menuItems = [
      {'label': AppLocalizations.of(context)!.delete, 'value': 'delete', 'icon': Icons.delete},
    ];

    if (model.message.content is TextMessageContent) {
      menuItems.add({'label': AppLocalizations.of(context)!.copy, 'value': 'copy', 'icon': Icons.copy});
    }

    // 为语音消息添加转文字菜单
    if (model.message.content is SoundMessageContent) {
      SoundMessageContent soundContent = model.message.content as SoundMessageContent;
      if (soundContent.speechText == null || soundContent.speechText!.isEmpty) {
        menuItems.add({'label': AppLocalizations.of(context)!.speechToText, 'value': 'speech_to_text', 'icon': Icons.subtitles});
      }
    }

    menuItems.add({'label': AppLocalizations.of(context)!.forward, 'value': 'forward', 'icon': Icons.forward});

    if (model.message.direction == MessageDirection.MessageDirection_Send &&
        model.message.status == MessageStatus.Message_Status_Sent &&
        DateTime.now().millisecondsSinceEpoch - model.message.serverTime < 120 * 1000) {
      menuItems.add({'label': AppLocalizations.of(context)!.recall, 'value': 'recall', 'icon': Icons.undo});
    }

    menuItems.addAll([
      {'label': AppLocalizations.of(context)!.multiSelect, 'value': 'multi_select', 'icon': Icons.checklist},
      {'label': AppLocalizations.of(context)!.quote, 'value': 'quote', 'icon': Icons.format_quote},
      {'label': AppLocalizations.of(context)!.favoriteAction, 'value': 'favorite', 'icon': Icons.favorite},
    ]);

    // 如果没有bubbleRect，使用屏幕中心
    final screenSize = MediaQuery.of(context).size;
    final targetRect = bubbleRect ??
        Rect.fromCenter(
          center: Offset(screenSize.width / 2, screenSize.height / 2),
          width: 100,
          height: 50,
        );

    PopupMenuOverlay.show(
      context: context,
      targetRect: targetRect,
      menuItems: menuItems,
      onItemTap: (value) {
        _handleMenuItemTap(context, value, model, messageInputBarController);
      },
    );
  }

  void _handleMenuItemTap(BuildContext context, String value, UIMessage model, MessageInputBarController messageInputBarController) async {
    switch (value) {
      case "delete":
        _showDeleteOptions(context, model);
        break;
      case "copy":
        break;
      case "speech_to_text":
        _performSpeechToText(model, context);
        break;
      case "forward":
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PickForwardTargetPage(
              messages: [model.message],
              onSelected: (conversations) {
                for (var conversation in conversations) {
                  _performForward(conversation, model.message, "");
                }
                Navigator.pop(context); // Close PickForwardTargetPage
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
          Fluttertoast.showToast(msg: AppLocalizations.of(context)!.favoriteSuccess);
        }, (msg) {
          Fluttertoast.showToast(msg: AppLocalizations.of(context)!.favoriteFail(msg));
        });
        break;
    }
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
          title: Text(AppLocalizations.of(context)!.deleteMessage),
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                _deleteMessage(model.message.messageId);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(AppLocalizations.of(context)!.deleteLocalMessage),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                _deleteRemoteMessage(model.message, context);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(AppLocalizations.of(context)!.deleteRemoteMessage),
              ),
            ),
          ],
        );
      },
    );
  }

  void _deleteRemoteMessage(Message message, BuildContext context) {
    if (message.messageUid != null && message.messageUid! > 0) {
      Imclient.deleteRemoteMessage(message.messageUid!, () {}, (errorCode) {
        Fluttertoast.showToast(msg: AppLocalizations.of(context)!.deleteRemoteMessageFail(errorCode.toString()));
      });
    } else {
      _deleteMessage(message.messageId);
    }
  }

  void _deleteMessage(int messageId) {
    conversationViewModel.deleteMessage(messageId);
  }

  Future<void> _performSpeechToText(UIMessage model, BuildContext context) async {
    SoundMessageContent audioMessage = model.message.content as SoundMessageContent;

    // 检查是否已有转文字结果
    if (audioMessage.speechText != null && audioMessage.speechText!.isNotEmpty) {
      return;
    }

    // 设置转文字进行中的状态
    audioMessage.speechToTextInProgress = true;
    audioMessage.speechText = ''; // 初始化为空字符串
    eventBus.fire(VoiceSpeechToTextUpdatedEvent(model.message.messageId));

    try {
      // 获取音频文件的远程URL
      if (audioMessage.remoteUrl == null || audioMessage.remoteUrl!.isEmpty) {
        Fluttertoast.showToast(msg: AppLocalizations.of(context)!.audioFileNotAvailable);
        audioMessage.speechToTextInProgress = false;
        eventBus.fire(VoiceSpeechToTextUpdatedEvent(model.message.messageId));
        return;
      }

      await _makeAsrRequest(audioMessage.remoteUrl!, (resultChunk) {
        // 回调函数：每接收到结果片段就更新
        audioMessage.speechText = (audioMessage.speechText ?? '') + resultChunk;
        eventBus.fire(VoiceSpeechToTextUpdatedEvent(model.message.messageId));
      });

      audioMessage.speechToTextInProgress = false;
      eventBus.fire(VoiceSpeechToTextUpdatedEvent(model.message.messageId));

      if (audioMessage.speechText == null || audioMessage.speechText!.isEmpty) {
        audioMessage.speechText = AppLocalizations.of(context)!.convertFail;
        Fluttertoast.showToast(msg: AppLocalizations.of(context)!.speechToTextFail);
      } else {
        Fluttertoast.showToast(msg: AppLocalizations.of(context)!.speechToTextSuccess);
      }
    } catch (error) {
      debugPrint('语音转文字异常: $error');
      audioMessage.speechText = AppLocalizations.of(context)!.convertFail;
      audioMessage.speechToTextInProgress = false;
      eventBus.fire(VoiceSpeechToTextUpdatedEvent(model.message.messageId));
      Fluttertoast.showToast(msg: AppLocalizations.of(context)!.speechToTextError(error.toString()));
    }
  }


  Future<void> _makeAsrRequest(String audioUrl, Function(String) onChunk) async {
    try {
      final request = http.Request(
        'POST',
        Uri.parse(Config.ASR_SERVER),
      );
      
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Accept': '*/*',
      });
      
      request.body = jsonEncode({
        'url': audioUrl,
        'noReuse': false,
        'noLlm': false,
      });

      final streamResponse = await request.send();

      if (!streamResponse.statusCode.toString().startsWith('2')) {
        debugPrint('ASR API 错误: ${streamResponse.statusCode}');
        return;
      }

      // 处理流式响应
      await streamResponse.stream.transform(utf8.decoder).listen(
        (chunk) {
          // 处理接收到的数据块
          List<String> lines = chunk.split('\n');
          for (String line in lines) {
            line = line.replaceAll('\r', '').trim();
            if (line.isNotEmpty) {
              String text = line.replaceAll('data:', '').trim();
              if (text.isNotEmpty) {
                // 实时回调返回文本片段
                onChunk(text);
              }
            }
          }
        },
        onError: (error) {
          debugPrint('流处理错误: $error');
        },
        cancelOnError: false,
      ).asFuture();
    } catch (e) {
      debugPrint('ASR 请求异常: $e');
    }
  }

  @override
  void dispose() {
    super.dispose();
    // 关闭任何打开的弹出菜单
    PopupMenuOverlay.dismiss();
    if (_soundPlayer.isPlaying) {
      _soundPlayer.stopPlayer();
    }
  }
}
