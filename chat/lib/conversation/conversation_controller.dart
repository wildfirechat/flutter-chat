import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:imclient/message/call_start_message_content.dart';
import 'package:logger/logger.dart' show Level;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:image/image.dart' as img;
import 'package:imclient/imclient.dart';
import 'package:imclient/message/card_message_content.dart';
import 'package:imclient/message/collection_message_content.dart';
import 'package:imclient/message/poll_message_content.dart';
import 'package:imclient/message/file_message_content.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/message/notification/recall_notificiation_content.dart';
import 'package:imclient/message/sound_message_content.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:imclient/message/video_message_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/user_info.dart';
import 'package:avenginekit/engine/call_state.dart';
import 'package:avenginekit/internal/avenginekit_impl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chat/conversation/media_cell_anchor.dart';
import 'package:chat/conversation/mm_preview_view.dart';
import 'package:chat/call/av_call_launcher.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/utils/mesh_user_display.dart';
import 'package:chat/utils/show_toast.dart';
import 'package:chat/utils/layout_scale.dart';
import 'package:chat/viewmodel/conversation_view_model.dart';
import 'package:chat/app_server.dart';
import 'package:chat/config.dart';
import 'package:chat/model/favorite_item.dart';
import 'package:chat/utils/media_url_redirector.dart';
import 'package:chat/widget/popup_menu_overlay.dart';
import 'package:chat/widget/desktop_popup_menu_item.dart';
import 'package:chat/widget/bottom_action_sheet.dart';
import 'package:http/http.dart' as http;
import 'package:chat/l10n/app_localizations.dart';

import '../collection/collection_service.dart';
import '../collection/collection_detail_screen.dart';
import '../poll/poll_service.dart';
import '../poll/poll_detail_screen.dart';
import '../contact/pick_user_screen.dart';
import '../user_info_widget.dart';
import '../ui_model/ui_message.dart';
import 'forward/show_pick_forward_target.dart';
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
  final FlutterSoundPlayer _soundPlayer =
      FlutterSoundPlayer(logLevel: Level.error);

  void onPickImage(Conversation conversation, String imagePath) {
    ImageMessageContent imgCont = ImageMessageContent();
    imgCont.localPath = imagePath;
    _sendMessage(conversation, imgCont);
  }

  void onPickFile(
      Conversation conversation, String filePath, String name, int size) {
    FileMessageContent fileCnt = FileMessageContent();
    fileCnt.name = name;
    fileCnt.size = size;
    fileCnt.localPath = filePath;
    _sendMessage(conversation, fileCnt);
  }

  void onPressCallBtn(BuildContext context, Conversation conversation) {
    if (conversation.conversationType != ConversationType.Single &&
        conversation.conversationType != ConversationType.Group) {
      return;
    }

    if (avEngineKit.currentSession == null || avEngineKit.currentSession!.status == CallState.STATUS_IDLE) {
      if (conversation.conversationType == ConversationType.Single) {
        showBottomActionSheet(
          context: context,
          items: [
            BottomActionSheetItem(
              label: AppLocalizations.of(context)!.videoCallAction,
              icon: Icons.videocam_rounded,
              onTap: () {
                startAvCallWithParticipants(context, conversation, [conversation.target], audioOnly: false);
              },
            ),
            BottomActionSheetItem(
              label: AppLocalizations.of(context)!.audioCallAction,
              icon: Icons.call_rounded,
              onTap: () {
                startAvCallWithParticipants(context, conversation, [conversation.target], audioOnly: true);
              },
            ),
          ],
        );
      } else if (conversation.conversationType == ConversationType.Group) {
        showBottomActionSheet(
          context: context,
          items: [
            BottomActionSheetItem(
              label: AppLocalizations.of(context)!.videoCallAction,
              icon: Icons.videocam_rounded,
              onTap: () {
                _pickGroupMembersAndStartCall(context, conversation, false);
              },
            ),
            BottomActionSheetItem(
              label: AppLocalizations.of(context)!.audioCallAction,
              icon: Icons.call_rounded,
              onTap: () {
                _pickGroupMembersAndStartCall(context, conversation, true);
              },
            ),
          ],
        );
      }
      } else {
        showToast(
            msg: AppLocalizations.of(context)!.callInProgress);
      }
  }

  void _pickGroupMembersAndStartCall(BuildContext context, Conversation conversation, bool audioOnly) {
    Imclient.getGroupMembers(conversation.target).then((groupMembers) {
      if (!context.mounted) return;
      List<String> members = [];
      for (var gm in groupMembers) {
        members.add(gm.memberId);
      }

      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => PickUserScreen(
                  title: AppLocalizations.of(context)!.pickGroupMember,
                  (pickerContext, selectedMembers) async {
                    final participants = selectedMembers.where((memberId) => memberId != Imclient.currentUserId).toList();
                    if (participants.isEmpty) {
                      showToast(
                          msg: AppLocalizations.of(pickerContext)!
                              .selectMemberToCall);
                    } else {
                      Navigator.pop(pickerContext);
                      startAvCallWithParticipants(context, conversation, participants, audioOnly: audioOnly);
                    }
                  },
                  maxSelected: 9,
                  candidates: members,
                  disabledCheckedUsers: [Imclient.currentUserId],
                  showOrganizationEntry: false,
                )),
      );
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
                    UserInfo? userInfo =
                        await Imclient.getUserInfo(members.first);
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

  void cameraCaptureVideo(Conversation conversation, String videoPath,
      img.Image? thumbnail, int duration) {
    VideoMessageContent videoContent = VideoMessageContent();
    videoContent.duration = duration;
    videoContent.localPath = videoPath;
    if (thumbnail != null) {
      videoContent.thumbnail = img.encodeJpg(thumbnail, quality: 30);
    }
    _sendMessage(conversation, videoContent);
  }

  void onSoundRecorded(
      Conversation conversation, String soundPath, int duration) {
    SoundMessageContent soundMessageContent = SoundMessageContent();
    soundMessageContent.localPath = soundPath;
    soundMessageContent.duration = duration;
    _sendMessage(conversation, soundMessageContent);
  }

  void _sendMessage(Conversation conversation, MessageContent messageContent) {
    Imclient.sendMediaMessage(conversation, messageContent,
        successCallback: (int messageUid, int timestamp) {},
        errorCallback: (int errorCode) {},
        progressCallback: (int uploaded, int total) {
      debugPrint("progressCallback:$uploaded,$total");
    }, uploadedCallback: (String remoteUrl) {
      debugPrint("uploadedCallback:$remoteUrl");
    });
  }

  void onTapedCell(BuildContext context, UIMessage model) {
    var conversation = model.message.conversation;
    if (model.message.content is ImageMessageContent ||
        model.message.content is VideoMessageContent) {
      // 桌面端 video_player 官方无 Windows/Linux 实现，视频消息降级为系统播放器打开
      if (isDesktopShell && model.message.content is VideoMessageContent) {
        final videoContent = model.message.content as VideoMessageContent;
        final videoUrl = videoContent.localPath != null && videoContent.localPath!.isNotEmpty && File(videoContent.localPath!).existsSync()
            ? Uri.file(videoContent.localPath!)
            : (videoContent.remoteUrl != null ? Uri.parse(MediaUrlRedirector.redirect(videoContent.remoteUrl!)) : null);
        if (videoUrl != null) {
          canLaunchUrl(videoUrl).then((canLaunch) {
            if (canLaunch) {
              launchUrl(videoUrl, mode: LaunchMode.externalApplication);
            } else {
              showToast(msg: AppLocalizations.of(context)!.cannotOpen);
            }
          });
        } else {
          showToast(msg: AppLocalizations.of(context)!.cannotOpen);
        }
        return;
      }

      Imclient.getMessages(conversation, model.message.messageId, 10,
          contentTypes: [
            MESSAGE_CONTENT_TYPE_IMAGE,
            MESSAGE_CONTENT_TYPE_VIDEO
          ]).then((eldMsgs) {
        Imclient.getMessages(conversation, model.message.messageId, -10,
            contentTypes: [
              MESSAGE_CONTENT_TYPE_IMAGE,
              MESSAGE_CONTENT_TYPE_VIDEO
            ]).then((newerMsgs) {
          List<Message> list = [];
          list.addAll(eldMsgs.reversed);
          list.add(model.message);
          list.addAll(newerMsgs);
          int index = eldMsgs.length;
          if (isDesktopShell) {
            showDialog(
              context: context,
              barrierColor: Colors.black,
              useSafeArea: false,
              builder: (_) => MMPreviewView(
                list,
                defaultIndex: index,
                pageToEnd: (fromIndex, tail) {
                  if (tail) {
                    Imclient.getMessages(conversation, fromIndex, -10,
                        contentTypes: [
                          MESSAGE_CONTENT_TYPE_IMAGE,
                          MESSAGE_CONTENT_TYPE_VIDEO
                        ]).then((value) {
                      if (value.isNotEmpty) {
                        _mmPreviewKey.currentState!.onLoadMore(value, false);
                      }
                    });
                  } else {
                    Imclient.getMessages(conversation, fromIndex, 10,
                        contentTypes: [
                          MESSAGE_CONTENT_TYPE_IMAGE,
                          MESSAGE_CONTENT_TYPE_VIDEO
                        ]).then((value) {
                      if (value.isNotEmpty) {
                        _mmPreviewKey.currentState!.onLoadMore(value, true);
                      }
                    });
                  }
                },
                key: _mmPreviewKey,
              ),
            );
          } else {
            Navigator.push(
              context,
              PageRouteBuilder(
                opaque: false,
                pageBuilder: (context, animation, secondaryAnimation) =>
                    MMPreviewView(
                  list,
                  defaultIndex: index,
                  // 拖拽退出时缩回对应消息气泡的缩略图(气泡滚出屏幕则下滑退出)
                  sourceRectProvider: (message) =>
                      MediaCellAnchor.rectOf(message.messageId),
                  pageToEnd: (fromIndex, tail) {
                    if (tail) {
                      Imclient.getMessages(conversation, fromIndex, -10,
                          contentTypes: [
                            MESSAGE_CONTENT_TYPE_IMAGE,
                            MESSAGE_CONTENT_TYPE_VIDEO
                          ]).then((value) {
                        if (value.isNotEmpty) {
                          _mmPreviewKey.currentState!.onLoadMore(value, false);
                        }
                      });
                    } else {
                      Imclient.getMessages(conversation, fromIndex, 10,
                          contentTypes: [
                            MESSAGE_CONTENT_TYPE_IMAGE,
                            MESSAGE_CONTENT_TYPE_VIDEO
                          ]).then((value) {
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
          }
        });
      });
    } else if (model.message.content is FileMessageContent) {
      FileMessageContent fileContent =
          model.message.content as FileMessageContent;
      final fileUrl = MediaUrlRedirector.redirect(fileContent.remoteUrl!);
      canLaunchUrl(Uri.parse(fileUrl)).then((value) {
        if (value) {
          launchUrl(Uri.parse(fileUrl));
        } else {
          showToast(msg: AppLocalizations.of(context)!.cannotOpen);
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
    } else if (model.message.content is CollectionMessageContent) {
      if (CollectionService.isAvailable) {
        CollectionDetailScreen.show(context, model.message);
      }
    } else if (model.message.content is PollMessageContent) {
      if (PollService.isAvailable) {
        PollDetailScreen.showFromMessage(context, model.message);
      }
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
    SoundMessageContent soundContent =
        model.message.content as SoundMessageContent;
    if (model.message.direction == MessageDirection.MessageDirection_Receive) {
      Imclient.updateMessageStatus(
          model.message.messageId, MessageStatus.Message_Status_Played);
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

  void onLongPressedCell(
      BuildContext context, UIMessage model, Rect? bubbleRect) {
    _showPopupMenu(context, model, bubbleRect);
  }

  void onPortraitTaped(BuildContext context, UIMessage model) {
    debugPrint("on taped portrait");
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => UserInfoWidget(model.message.fromUser)),
    );
  }

  void onPortraitLongTaped(BuildContext context, UIMessage model) {
    debugPrint("on long taped portrait");
    String userId = model.message.fromUser;
    var conversation = model.message.conversation;
    if (conversation.conversationType == ConversationType.Group) {
      Imclient.getUserInfo(userId, groupId: conversation.target)
          .then((userInfo) {
        if (userInfo != null) {
          final messageInputBarController =
              Provider.of<MessageInputBarController>(context, listen: false);
          messageInputBarController.insertMention(userInfo);
        }
      });
    } else {
      Imclient.getUserInfo(userId).then((userInfo) {
        if (userInfo != null) {
          final messageInputBarController =
              Provider.of<MessageInputBarController>(context, listen: false);
          messageInputBarController.insertText("${MeshUserDisplay.getReadableName(userInfo)} ");
          if (!messageInputBarController.focusNode.hasFocus) {
            messageInputBarController.focusNode.requestFocus();
          }
        }
      });
    }
  }

  void onPortraitSecondaryTaped(BuildContext context, UIMessage model, Offset globalPosition) {
    debugPrint("on portrait secondary taped");
    String userId = model.message.fromUser;
    var conversation = model.message.conversation;
    if (conversation.conversationType == ConversationType.Group) {
      Imclient.getUserInfo(userId, groupId: conversation.target)
          .then((userInfo) {
        if (userInfo != null && context.mounted) {
          final messageInputBarController =
              Provider.of<MessageInputBarController>(context, listen: false);

          final overlayBox = Overlay.of(context).context.findRenderObject() as RenderBox;
          final localAnchor = overlayBox.globalToLocal(globalPosition);

          showMenu<String>(
            context: context,
            position: RelativeRect.fromRect(localAnchor & Size.zero, Offset.zero & overlayBox.size),
            constraints: BoxConstraints(minWidth: LayoutScale.scale(context, 120, cap: LayoutScale.rowCap)),
            items: [
              DesktopPopupMenuItem<String>(
                value: 'mention',
                height: LayoutScale.scale(context, 34, cap: LayoutScale.rowCap),
                child: Row(
                  children: [
                    Icon(
                      Icons.alternate_email,
                      size: LayoutScale.scale(context, 16, cap: LayoutScale.iconCap),
                    ),
                    SizedBox(width: LayoutScale.scale(context, 10, cap: LayoutScale.iconCap)),
                    Text("@${MeshUserDisplay.getReadableName(userInfo)}"),
                  ],
                ),
              )
            ],
          ).then((value) {
            if (value == 'mention' && context.mounted) {
              messageInputBarController.insertMention(userInfo);
            }
          });
        }
      });
    }
  }

  void onResendTaped(UIMessage model) {
    debugPrint("on taped resend");
    Imclient.deleteMessage(model.message.messageId);
    Imclient.sendMessage(model.message.conversation, model.message.content,
        successCallback: (l, ll) {}, errorCallback: (errorCode) {});
  }

  void onReadedTaped(BuildContext context, UIMessage model) {
    debugPrint("on taped readed");
    if (model.message.conversation.conversationType == ConversationType.Group) {
      ReadReceiptDetailScreen.show(context, model.message);
    }
  }

  void _showPopupMenu(BuildContext context, UIMessage model, Rect? bubbleRect) {
    final messageInputBarController =
        Provider.of<MessageInputBarController>(context, listen: false);
    List<Map<String, dynamic>> menuItems = [
      {
        'label': AppLocalizations.of(context)!.delete,
        'value': 'delete',
        'icon': Icons.delete
      },
    ];

    if (model.message.content is TextMessageContent) {
      menuItems.add({
        'label': AppLocalizations.of(context)!.copy,
        'value': 'copy',
        'icon': Icons.copy
      });
    }

    // 为语音消息添加转文字菜单
    if (model.message.content is SoundMessageContent) {
      SoundMessageContent soundContent =
          model.message.content as SoundMessageContent;
      if (soundContent.speechText == null || soundContent.speechText!.isEmpty) {
        menuItems.add({
          'label': AppLocalizations.of(context)!.speechToText,
          'value': 'speech_to_text',
          'icon': Icons.subtitles
        });
      }
    }

    menuItems.add({
      'label': AppLocalizations.of(context)!.forward,
      'value': 'forward',
      'icon': Icons.forward
    });

    if (model.message.direction == MessageDirection.MessageDirection_Send &&
        model.message.status == MessageStatus.Message_Status_Sent &&
        DateTime.now().millisecondsSinceEpoch - model.message.serverTime <
            120 * 1000) {
      menuItems.add({
        'label': AppLocalizations.of(context)!.recall,
        'value': 'recall',
        'icon': Icons.undo
      });
    }

    // 为自己发送的撤回消息添加重新编辑菜单
    if (model.message.content is RecallNotificationContent &&
        model.message.direction == MessageDirection.MessageDirection_Send &&
        model.message.fromUser == Imclient.currentUserId) {
      final recallContent = model.message.content as RecallNotificationContent;
      final hasOriginalText = recallContent.originalContentType == MESSAGE_CONTENT_TYPE_TEXT;
      if (hasOriginalText) {
        menuItems.add({
          'label': AppLocalizations.of(context)!.reedit,
          'value': 'reedit',
          'icon': Icons.edit
        });
      }
    }

    menuItems.addAll([
      {
        'label': AppLocalizations.of(context)!.multiSelect,
        'value': 'multi_select',
        'icon': Icons.checklist
      },
      {
        'label': AppLocalizations.of(context)!.quote,
        'value': 'quote',
        'icon': Icons.format_quote
      },
      {
        'label': AppLocalizations.of(context)!.favoriteAction,
        'value': 'favorite',
        'icon': Icons.favorite
      },
    ]);

    // 桌面端:标准垂直上下文菜单,锚定鼠标/气泡位置,showMenu 自动避让窗口边缘
    if (isDesktopShell) {
      _showDesktopContextMenu(context, model, bubbleRect, menuItems, messageInputBarController);
      return;
    }

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

  void _showDesktopContextMenu(BuildContext context, UIMessage model, Rect? anchorRect, List<Map<String, dynamic>> menuItems,
      MessageInputBarController messageInputBarController) {
    // 会话页位于右栏嵌套 Navigator 中,showMenu 的 position 相对其 overlay 解析;
    // anchorRect 是窗口全局坐标,必须先换算,否则菜单会向右偏移一个侧栏+中栏的宽度。
    final overlayBox = Overlay.of(context).context.findRenderObject() as RenderBox;
    final globalAnchor = anchorRect?.center ?? overlayBox.localToGlobal(overlayBox.size.center(Offset.zero));
    final localAnchor = overlayBox.globalToLocal(globalAnchor);

    // Identify dangerous items and normal items, and put dangerous items at the end
    final dangerousItems = menuItems.where((item) => item['value'] == 'delete').toList();
    final normalItems = menuItems.where((item) => item['value'] != 'delete').toList();
    final sortedItems = [...normalItems, ...dangerousItems];

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(localAnchor & Size.zero, Offset.zero & overlayBox.size),
      constraints: BoxConstraints(minWidth: LayoutScale.scale(context, 140, cap: LayoutScale.rowCap)),
      items: sortedItems
          .map((item) => DesktopPopupMenuItem<String>(
                value: item['value'],
                isDanger: item['value'] == 'delete',
                height: LayoutScale.scale(context, 34, cap: LayoutScale.rowCap),
                child: Row(
                  children: [
                    Icon(
                      item['icon'],
                      size: LayoutScale.scale(context, 16, cap: LayoutScale.iconCap),
                    ),
                    SizedBox(width: LayoutScale.scale(context, 10, cap: LayoutScale.iconCap)),
                    Text(item['label']),
                  ],
                ),
              ))
          .toList(),
    ).then((value) {
      if (value != null && context.mounted) {
        _handleMenuItemTap(context, value, model, messageInputBarController);
      }
    });
  }


  void _handleMenuItemTap(BuildContext context, String value, UIMessage model,
      MessageInputBarController messageInputBarController) async {
    switch (value) {
      case "delete":
        _showDeleteOptions(context, model);
        break;
      case "copy":
        if (model.message.content is TextMessageContent) {
          final content = model.message.content as TextMessageContent;
          await Clipboard.setData(ClipboardData(text: content.text));
          showToast(msg: AppLocalizations.of(context)!.copy);
        }
        break;
      case "speech_to_text":
        _performSpeechToText(model, context);
        break;
      case "forward":
        showPickForwardTarget(
          context,
          messages: [model.message],
          onSelected: (conversations, comment) {
            for (var conversation in conversations) {
              _performForward(conversation, model.message, comment ?? "");
            }
          },
        );
        break;
      case "recall":
        _recallMessage(model.message.messageId, model.message.messageUid!);
        break;
      case "reedit":
        _reeditRecalledMessage(context, model);
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
          showToast(
              msg: AppLocalizations.of(context)!.favoriteSuccess);
        }, (msg) {
          showToast(
              msg: AppLocalizations.of(context)!.favoriteFail(msg));
        });
        break;
    }
  }

  void _performForward(Conversation target, Message message, String extraText) {
    Imclient.sendMessage(target, message.content,
        successCallback: (messageUid, timestamp) {},
        errorCallback: (errorCode) {});
    if (extraText.isNotEmpty) {
      TextMessageContent textContent = TextMessageContent(extraText);
      textContent.text = extraText;
      Imclient.sendMessage(target, textContent,
          successCallback: (messageUid, timestamp) {},
          errorCallback: (errorCode) {});
    }
  }

  void _recallMessage(int messageId, int messageUid) {
    Imclient.recallMessage(messageUid, () {}, (errorCode) {});
  }

  void _reeditRecalledMessage(BuildContext context, UIMessage model) async {
    final content = model.message.content;
    String? text;
    if (content is RecallNotificationContent) {
      if (content.originalContentType == MESSAGE_CONTENT_TYPE_TEXT &&
          content.originalContent != null &&
          content.originalContent!.isNotEmpty) {
        text = content.originalContent;
      } else if (content.originalSearchableContent != null &&
          content.originalSearchableContent!.isNotEmpty) {
        text = content.originalSearchableContent;
      }
    }
    if (text == null || text.isEmpty) {
      showToast(msg: AppLocalizations.of(context)!.recalledMessageNoContent);
      return;
    }
    final messageInputBarController =
        Provider.of<MessageInputBarController>(context, listen: false);
    messageInputBarController.setDraft(text);
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
        showToast(
            msg: AppLocalizations.of(context)!
                .deleteRemoteMessageFail(errorCode.toString()));
      });
    } else {
      _deleteMessage(message.messageId);
    }
  }

  void _deleteMessage(int messageId) {
    conversationViewModel.deleteMessage(messageId);
  }

  Future<void> _performSpeechToText(
      UIMessage model, BuildContext context) async {
    SoundMessageContent audioMessage =
        model.message.content as SoundMessageContent;

    // 检查是否已有转文字结果
    if (audioMessage.speechText != null &&
        audioMessage.speechText!.isNotEmpty) {
      return;
    }

    // 设置转文字进行中的状态
    audioMessage.speechToTextInProgress = true;
    audioMessage.speechText = ''; // 初始化为空字符串
    eventBus.fire(VoiceSpeechToTextUpdatedEvent(model.message.messageId));

    try {
      // 获取音频文件的远程URL
      if (audioMessage.remoteUrl == null || audioMessage.remoteUrl!.isEmpty) {
        showToast(
            msg: AppLocalizations.of(context)!.audioFileNotAvailable);
        audioMessage.speechToTextInProgress = false;
        eventBus.fire(VoiceSpeechToTextUpdatedEvent(model.message.messageId));
        return;
      }

      await _makeAsrRequest(MediaUrlRedirector.redirect(audioMessage.remoteUrl!), (resultChunk) {
        // 回调函数：每接收到结果片段就更新
        audioMessage.speechText = (audioMessage.speechText ?? '') + resultChunk;
        eventBus.fire(VoiceSpeechToTextUpdatedEvent(model.message.messageId));
      });

      audioMessage.speechToTextInProgress = false;
      eventBus.fire(VoiceSpeechToTextUpdatedEvent(model.message.messageId));

      if (audioMessage.speechText == null || audioMessage.speechText!.isEmpty) {
        audioMessage.speechText = AppLocalizations.of(context)!.convertFail;
        showToast(
            msg: AppLocalizations.of(context)!.speechToTextFail);
      } else {
        showToast(
            msg: AppLocalizations.of(context)!.speechToTextSuccess);
      }
    } catch (error) {
      debugPrint('语音转文字异常: $error');
      audioMessage.speechText = AppLocalizations.of(context)!.convertFail;
      audioMessage.speechToTextInProgress = false;
      eventBus.fire(VoiceSpeechToTextUpdatedEvent(model.message.messageId));
      showToast(
          msg: AppLocalizations.of(context)!
              .speechToTextError(error.toString()));
    }
  }

  Future<void> _makeAsrRequest(
      String audioUrl, Function(String) onChunk) async {
    try {
      final request = http.Request(
        'POST',
        Uri.parse(Config.asrServerUrl ?? Config.ASR_SERVER),
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
