import 'package:flutter/material.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/notification/tip_notificiation_content.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:wfc_example/conversation/conversation_controller.dart';
import 'package:wfc_example/conversation/group_conversation_info_screen.dart';
import 'package:wfc_example/conversation/input_bar/message_input_bar.dart';
import 'package:wfc_example/conversation/conversation_appbar_title.dart';
import 'package:wfc_example/conversation/single_conversation_info_screen.dart';
import 'package:wfc_example/viewmodel/conversation_view_model.dart';

import 'package:wfc_example/conversation/pick_conversation_screen.dart';
import 'package:imclient/message/composite_message_content.dart';
import 'package:wfc_example/contact/pick_user_screen.dart';
import 'package:wfc_example/config.dart';
import 'channel_conversation_info_screen.dart';
import 'input_bar/message_input_bar_controller.dart';
import 'message_cell.dart';

class ConversationScreen extends StatefulWidget {
  final Conversation conversation;

  const ConversationScreen(this.conversation, {super.key});

  @override
  State createState() => _State();
}

class _State extends State<ConversationScreen> {
  late ConversationViewModel _conversationViewModel;
  late MessageInputBarController _inputBarController;

  @override
  void initState() {
    super.initState();

    _conversationViewModel = Provider.of<ConversationViewModel>(context, listen: false);
    _conversationViewModel.setConversation(widget.conversation, joinChatroomErrorCallback: (err) {
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
            _inputBarController.onMentionTriggered = _onMentionTriggered;
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
                        itemBuilder: (BuildContext context, int index) {
                          var msg = conversationMessageList[index];
                          var cell = MessageCell(msg);
                          if (conversationViewModel.isMultiSelectMode) {
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                conversationViewModel.toggleMessageSelection(msg.message.messageId);
                              },
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: conversationViewModel.isMessageSelected(msg.message.messageId),
                                    onChanged: (bool? value) {
                                      conversationViewModel.toggleMessageSelection(msg.message.messageId);
                                    },
                                  ),
                                  Expanded(
                                    child: AbsorbPointer(
                                      child: cell,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            return cell;
                          }
                        },
                        itemCount: conversationMessageList.length,
                      ),
                    ),
                    onTap: () {
                      // 使用controller重置状态
                      _inputBarController.resetStatus();
                    },
                  ),
                ),
                conversationViewModel.isMultiSelectMode ? _buildMultiSelectToolBar(context, conversationViewModel) : MessageInputBar()
              ],
            ),
          ),
        ));
  }

  Widget _buildMultiSelectToolBar(BuildContext context, ConversationViewModel viewModel) {
    return Container(
      height: 50,
      color: const Color(0xFFF5F5F5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: const Icon(Icons.forward),
            onPressed: () {
              // Forward
              _handleForward(context, viewModel);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              // Delete
              _handleDeleteSelected(context, viewModel);
            },
          ),
        ],
      ),
    );
  }

  void _handleDeleteSelected(BuildContext context, ConversationViewModel viewModel) {
    if (viewModel.getSelectedMessages().isEmpty) {
      Fluttertoast.showToast(msg: "请选择消息");
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('删除消息'),
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                _deleteMessages(context, viewModel, false);
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('删除本地消息'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                _deleteMessages(context, viewModel, true);
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

  void _deleteMessages(BuildContext context, ConversationViewModel viewModel, bool isRemote) {
    var selected = viewModel.getSelectedMessages();
    for (var msg in selected) {
      if (isRemote) {
        if (msg.messageUid != null && msg.messageUid! > 0) {
          Imclient.deleteRemoteMessage(msg.messageUid!, () {}, (errorCode) {
            Fluttertoast.showToast(msg: "删除远程消息失败: $errorCode");
          });
        } else {
          viewModel.deleteMessage(msg.messageId);
        }
      } else {
        viewModel.deleteMessage(msg.messageId);
      }
    }
    viewModel.toggleMultiSelectMode();
  }

  void _handleForward(BuildContext context, ConversationViewModel viewModel) {
    var selected = viewModel.getSelectedMessages();
    if (selected.isEmpty) {
      Fluttertoast.showToast(msg: "请选择消息");
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.send),
                title: const Text('逐条转发'),
                onTap: () {
                  Navigator.pop(context);
                  _forwardMessages(context, viewModel, selected, false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.merge_type),
                title: const Text('合并转发'),
                onTap: () {
                  Navigator.pop(context);
                  _forwardMessages(context, viewModel, selected, true);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _forwardMessages(BuildContext context, ConversationViewModel viewModel, List<Message> messages, bool isMerge) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PickConversationScreen(
          onConversationSelected: (ctx, conversation) {
            if (isMerge && messages.length > 1) {
              _sendCompositeMessage(ctx, conversation, messages, viewModel);
            } else {
              _sendOneByOneMessage(ctx, conversation, messages, viewModel);
            }
          },
        ),
      ),
    );
  }

  void _sendOneByOneMessage(BuildContext context, Conversation target, List<Message> messages, ConversationViewModel viewModel) {
    messages.sort((a, b) => a.serverTime.compareTo(b.serverTime));
    for (var msg in messages) {
      Imclient.sendMessage(target, msg.content, successCallback: (messageUid, timestamp) {}, errorCallback: (errorCode) {
        Fluttertoast.showToast(msg: "发送失败！");
      });
    }
    viewModel.toggleMultiSelectMode();
    Navigator.pop(context);
    Fluttertoast.showToast(msg: "已发送");
  }

  void _sendCompositeMessage(BuildContext context, Conversation target, List<Message> messages, ConversationViewModel viewModel) {
    CompositeMessageContent content = CompositeMessageContent();
    content.title = "聊天记录";
    messages.sort((a, b) => a.serverTime.compareTo(b.serverTime));
    content.messages = messages;

    Imclient.sendMessage(target, content, successCallback: (messageUid, timestamp) {}, errorCallback: (errorCode) {
      Fluttertoast.showToast(msg: "发送失败！");
    });

    viewModel.toggleMultiSelectMode();
    Navigator.pop(context);
    Fluttertoast.showToast(msg: "已发送");
  }

  void _onMentionTriggered(Conversation conversation) async {
    List<String> candidates = [];
    bool showAll = false;
    if (conversation.conversationType == ConversationType.Group) {
      var members = await Imclient.getGroupMembers(conversation.target);
      if (members != null) {
        candidates.addAll(members.map((e) => e.memberId).toList());
        var me = members.firstWhere((element) => element.memberId == Imclient.currentUserId, orElse: () => GroupMember());
        if(me.type == GroupMemberType.Owner || me.type == GroupMemberType.Manager) {
          showAll = true;
        }
      }
    }
    if (Config.AI_ROBOTS.isNotEmpty) {
      candidates.addAll(Config.AI_ROBOTS);
    }

    if (candidates.isEmpty) {
      return;
    }

    // Remove self
    candidates.remove(Imclient.currentUserId);

    if (candidates.isEmpty) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PickUserScreen(
          (context, pickedUsers) {
            if (pickedUsers.isNotEmpty) {
              if(pickedUsers[0] == 'All') {
                UserInfo all = UserInfo();
                all.userId = 'All';
                all.displayName = '所有人';
                _inputBarController.addMention(all);
              } else {
                Imclient.getUserInfo(pickedUsers[0]).then((userInfo) {
                  if (userInfo != null) {
                    _inputBarController.addMention(userInfo);
                  }
                });
              }
            }
            Navigator.pop(context);
          },
          title: '选择提醒的人',
          maxSelected: 1,
          candidates: candidates,
          showMentionAll: showAll,
        ),
      ),
    );
  }

  @override
  void deactivate() {
    // 使用controller获取草稿
    String draft = _inputBarController.getDraft();
    Imclient.setConversationDraft(widget.conversation, draft);
    super.deactivate();
  }
}
