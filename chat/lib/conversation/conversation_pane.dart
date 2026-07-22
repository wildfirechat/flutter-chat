import 'dart:async';
import 'dart:io';

import 'package:chat/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import 'package:imclient/message/composite_message_content.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/notification/notification_message_content.dart';
import 'package:imclient/message/notification/tip_notificiation_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/config.dart';
import 'package:chat/contact/pick_user_screen.dart';
import 'package:chat/conversation/conversation_controller.dart';
import 'package:chat/conversation/input_bar/message_input_bar.dart';
import 'package:chat/conversation/input_bar/message_input_bar_controller.dart';
import 'package:chat/conversation/message_cell.dart';
import 'package:chat/conversation/forward/show_pick_forward_target.dart';
import 'package:chat/group/join_group_request_screen.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/widgets/pc_dialog.dart';
import 'package:chat/utils/external_target_utils.dart';
import 'package:chat/utils/online_state_cache.dart';
import 'package:chat/utils/show_toast.dart';
import 'package:chat/ui_model/ui_message.dart';
import 'package:chat/utilities.dart';
import 'package:chat/viewmodel/conversation_view_model.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/utils/mesh_user_display.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';

/// 会话消息面板:消息列表 + 输入栏 + 多选工具栏,并承载进入/退出会话的完整生命周期
/// (setConversation、清未读、聊天室加退、草稿保存)。
///
/// 移动端 [ConversationScreen] 与桌面右栏 PcConversationPane 共用本组件,
/// 输入栏形态由壳注入:手机传 [MessageInputBar](默认),桌面传 PcMessageInputBar。
class ConversationPane extends StatefulWidget {
  final Conversation conversation;
  final int? toFocusMessageId;
  final Widget inputBar;

  const ConversationPane(
    this.conversation, {
    super.key,
    this.toFocusMessageId,
    this.inputBar = const MessageInputBar(),
  });

  @override
  State<ConversationPane> createState() => _ConversationPaneState();
}

class _ConversationPaneState extends State<ConversationPane> {
  late ConversationViewModel _conversationViewModel;
  late MessageInputBarController _inputBarController;
  final ScrollController _scrollController = ScrollController();
  double _pullDistance = 0.0;
  bool _isDragging = false;
  bool _isLoading = false;
  bool _isLoadingNewer = false;
  final Key _centerKey = UniqueKey();
  int _joinRequestCount = 0;
  StreamSubscription<JoinGroupRequestUpdatedEvent>? _joinGroupRequestSubscription;

  /// initState 中 setConversation 后的会话代际号，dispose 时据此判断
  /// viewModel 是否已被更新的 pane 接管（包括同会话定位消息的场景）。
  int _myConversationSession = 0;

  @override
  void initState() {
    super.initState();

    _conversationViewModel = Provider.of<ConversationViewModel>(context, listen: false);
    _conversationViewModel.setConversation(widget.conversation, toFocusMessageId: widget.toFocusMessageId, joinChatroomErrorCallback: (err) {
      showToast(msg: AppLocalizations.of(context)!.joinChatroomFail);
      Navigator.of(context).maybePop();
    });
    _myConversationSession = _conversationViewModel.conversationSession;

    Imclient.clearConversationUnreadStatus(widget.conversation);
    _loadJoinRequestCount();
    _joinGroupRequestSubscription = Imclient.IMEventBus.on<JoinGroupRequestUpdatedEvent>().listen((_) {
      _loadJoinRequestCount();
    });
    _watchOnlineState(widget.conversation);

    if (isDesktopShell) {
      // 桌面端没有触摸下拉手势,滚动接近历史侧末端时自动加载更早的消息;
      // 首帧后主动触发一次,覆盖首屏消息不足一屏、无法产生滚动的情况。
      _scrollController.addListener(_autoLoadHistoryIfNeeded);
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoLoadHistoryIfNeeded());
    }
  }

  Future<void> _watchOnlineState(Conversation conversation) async {
    if (conversation.conversationType != ConversationType.Single) return;
    if (ExternalTargetUtils.isExternalTarget(conversation.target)) return;
    try {
      final enabled = await OnlineStateCache.instance.isEnabled;
      if (!enabled) return;
      OnlineStateCache.instance.loadState(conversation.target);
      Imclient.watchOnlineState(
        conversation.conversationType,
        [conversation.target],
        3600,
        (states) {},
        (errorCode) {},
      );
    } catch (_) {
      // ignore
    }
  }

  void _unwatchOnlineState(Conversation conversation) {
    if (conversation.conversationType != ConversationType.Single) return;
    if (ExternalTargetUtils.isExternalTarget(conversation.target)) return;
    Imclient.unwatchOnlineState(
      conversation.conversationType,
      [conversation.target],
      () {},
      (errorCode) {},
    );
  }

  Future<void> _loadJoinRequestCount() async {
    if (widget.conversation.conversationType != ConversationType.Group) {
      if (_joinRequestCount != 0 && mounted) {
        setState(() => _joinRequestCount = 0);
      }
      return;
    }
    try {
      final count = await Imclient.getJoinGroupRequestUnread(groupId: widget.conversation.target);
      if (mounted && count != _joinRequestCount) {
        setState(() => _joinRequestCount = count);
      }
    } catch (e) {
      // ignore
    }
  }

  void _openJoinGroupRequests() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => JoinGroupRequestScreen(groupId: widget.conversation.target),
    ));
  }

  Widget _buildJoinRequestBanner(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: _openJoinGroupRequests,
      child: Container(
        margin: const EdgeInsets.fromLTRB(48, 8, 48, 8),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          l10n.newJoinGroupRequestCount(_joinRequestCount),
          style: AppText.base.copyWith(color: Colors.red),
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant ConversationPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversation != widget.conversation) {
      _unwatchOnlineState(oldWidget.conversation);
      _watchOnlineState(widget.conversation);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _joinGroupRequestSubscription?.cancel();
    // 桌面端右栏切换会话时,新会话页 initState 先于旧页 dispose 执行,
    // 此时 viewModel 已指向新会话,不能清空;仅当自己仍是当前会话的持有者
    // (代际号未变)时才清。同一会话内"定位消息"会以新 key 重建 pane,
    // 会话相等但代际号已递增,靠代际号区分,避免把进行中的定位加载打断。
    if (_conversationViewModel.currentConversation == widget.conversation &&
        _conversationViewModel.conversationSession == _myConversationSession) {
      _conversationViewModel.setConversation(null);
    }
    if (widget.conversation.conversationType == ConversationType.Chatroom) {
      Imclient.quitChatroom(widget.conversation.target, () {
        Imclient.getUserInfo(Imclient.currentUserId).then((userInfo) {
          if (userInfo != null) {
            TipNotificationContent tip = TipNotificationContent();
            tip.tip = AppLocalizations.of(context)!.userLeftChatroom(MeshUserDisplay.getReadableName(userInfo));
            _conversationViewModel.sendMessage(tip);
          }
        });
      }, (errorCode) {});
    }
    _unwatchOnlineState(widget.conversation);
    super.dispose();
  }

  @override
  void deactivate() {
    String draft = _inputBarController.getDraft();
    // 只有草稿内容发生变化时才落库；空草稿也需要保存以清空之前的草稿，对齐 iOS 行为。
    if (draft != _inputBarController.conversationDraft) {
      Imclient.setConversationDraft(widget.conversation, draft);
    }
    super.deactivate();
  }

  /// 桌面端:reverse 列表的 maxScrollExtent 一侧是更早的消息,接近时触发加载。
  /// loadHistoryMessage 内部有 loading 防重入,noMoreHistoryMsg 兜底终止。
  /// 加载完成后下一帧再补判一次:若仍未填满一屏则继续加载。
  void _autoLoadHistoryIfNeeded() {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }
    if (_isLoading || _conversationViewModel.noMoreHistoryMsg) {
      return;
    }
    final position = _scrollController.position;
    if (position.maxScrollExtent - position.pixels < 200) {
      setState(() {
        _isLoading = true;
      });
      _conversationViewModel.loadHistoryMessage().then((_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) => _autoLoadHistoryIfNeeded());
        }
      });
    }
  }

  bool notificationFunction(Notification notification) {
    if (notification is ScrollStartNotification) {
      if (notification.dragDetails != null) {
        _isDragging = true;
        _inputBarController.resetStatus();
      }
    } else if (notification is ScrollUpdateNotification) {
      if (notification.metrics.pixels > notification.metrics.maxScrollExtent) {
        setState(() {
          _pullDistance = (notification.metrics.pixels - notification.metrics.maxScrollExtent);
        });
      } else {
        if (_pullDistance > 0) {
          setState(() {
            _pullDistance = 0.0;
          });
        }
      }
      if (notification.dragDetails == null && _isDragging) {
        _isDragging = false;
        if (_pullDistance > 50) {
          setState(() {
            _isLoading = true;
          });
          _conversationViewModel.loadHistoryMessage().then((value) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          });
        }
      }
    } else if (notification is OverscrollNotification) {
      if (notification.overscroll > 0) {
        setState(() {
          _pullDistance += notification.overscroll;
        });
      } else if (notification.overscroll < 0) {
        setState(() {
          _pullDistance += notification.overscroll;
          if (_pullDistance < 0) _pullDistance = 0;
        });
      }
    } else if (notification is ScrollEndNotification) {
      _isDragging = false;
      setState(() {
        _pullDistance = 0.0;
      });
    }
    return false;
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// 「回到最新」悬浮按钮：定位到历史消息后出现；角标显示这期间的新消息数。
  Widget _buildBackToLatestButton(BuildContext context, ConversationViewModel conversationViewModel) {
    final l10n = AppLocalizations.of(context)!;
    final pending = conversationViewModel.pendingNewMessageCount;
    return Material(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(18),
      elevation: 2,
      shadowColor: context.colors.shadow,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          conversationViewModel.backToLatest();
          // 列表重建后滚到最新一条（reverse 列表的 0 位置）
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(0);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.keyboard_double_arrow_down_rounded,
                  size: 18, color: context.colors.accent),
              const SizedBox(width: 4),
              Text(
                pending > 0
                    ? l10n.backToLatestWithCount(pending > 99 ? '99+' : '$pending')
                    : l10n.backToLatest,
                style: AppText.sm.copyWith(color: context.colors.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var conversationViewModel = Provider.of<ConversationViewModel>(context);
    var conversationMessageList = conversationViewModel.conversationMessageList;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ConversationController>(create: (_) => ConversationController(conversationViewModel)),
        ChangeNotifierProvider<MessageInputBarController>(create: (_) {
          _inputBarController = MessageInputBarController(conversation: widget.conversation, conversationViewModel: conversationViewModel);
          if (!isDesktopShell) {
            // 移动端:键入 '@' 跳选人页(微信手机端交互);
            // 桌面端不设置回调,由 PcMessageInputBar 的 @ 浮层就地选人(微信 PC 交互)
            _inputBarController.onMentionTriggered = _onMentionTriggered;
          }
          _inputBarController.onSend = _scrollToBottom;
          return _inputBarController;
        }),
      ],
      child: Builder(
        builder: (innerContext) {
          Widget content = Stack(
            children: [
              Column(
                children: [
                  if (_joinRequestCount > 0)
                    _buildJoinRequestBanner(context),
                  Expanded(
                    child: Stack(
                      children: [
                        GestureDetector(
                          child: NotificationListener(
                        onNotification: notificationFunction,
                        child: CustomScrollView(
                          controller: _scrollController,
                          center: _centerKey,
                          anchor: conversationViewModel.focusMessageIndex > 0 ? 0.5 : 0.0,
                          reverse: true,
                          // 桌面端滚轮/触控板没有回弹语义,用 clamping;历史加载走 _autoLoadHistoryIfNeeded
                          physics: isDesktopShell
                              ? const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics())
                              : const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                          slivers: [
                            if (conversationViewModel.focusMessageIndex > 0)
                              SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    int focusIndex = conversationViewModel.focusMessageIndex;
                                    int newerCount = focusIndex;
                                    if (!conversationViewModel.noMoreNewerMsg) {
                                      if (index == newerCount) {
                                        if (!_isLoadingNewer) {
                                          _isLoadingNewer = true;
                                          _conversationViewModel.loadNewerMessage().then((value) {
                                            if (mounted) {
                                              setState(() {
                                                _isLoadingNewer = false;
                                              });
                                            }
                                          });
                                        }
                                        return Container(
                                          padding: const EdgeInsets.all(10),
                                          alignment: Alignment.center,
                                          child: const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                        );
                                      }
                                    }
                                    int listIndex = focusIndex - 1 - index;
                                    if (listIndex < 0) return null;
                                    return _buildMessageItem(context, listIndex, conversationViewModel);
                                  },
                                  childCount: conversationViewModel.focusMessageIndex + (!conversationViewModel.noMoreNewerMsg ? 1 : 0),
                                ),
                              ),
                            SliverList(
                              key: _centerKey,
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  int listIndex = conversationViewModel.focusMessageIndex + index;
                                  if (listIndex >= conversationMessageList.length) return null;
                                  return _buildMessageItem(context, listIndex, conversationViewModel);
                                },
                                childCount: conversationMessageList.length - conversationViewModel.focusMessageIndex,
                              ),
                            ),
                          ],
                        ),
                      ),
                      onTap: () {
                        _inputBarController.resetStatus();
                      },
                        ),
                        // 定位到历史消息后显示「回到最新」悬浮按钮（对齐微信），
                        // 角标为这期间新收到的消息数；位于消息区右下角
                        if (!conversationViewModel.noMoreNewerMsg)
                          Positioned(
                            right: 16,
                            bottom: 16,
                            child: _buildBackToLatestButton(context, conversationViewModel),
                          ),
                      ],
                    ),
                  ),
                  conversationViewModel.isMultiSelectMode ? _buildMultiSelectToolBar(context, conversationViewModel) : widget.inputBar,
                ],
              ),
              if (_pullDistance > 0 || _isLoading)
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 35,
                      height: 35,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.shadow,
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: _isLoading ? null : (_pullDistance / 50).clamp(0.0, 1.0),
                      ),
                    ),
                  ),
                ),
            ],
          );

          if (isDesktopShell) {
            return DropTarget(
              onDragDone: (detail) => _handleDroppedFiles(innerContext, detail.files),
              child: content,
            );
          }
          return content;
        },
      ),
    );
  }

  void _handleDroppedFiles(BuildContext context, List<XFile> files) {
    if (files.isEmpty) {
      return;
    }
    final fileNames = files.map((f) => f.name).toList();
    final nameStr = fileNames.length == 1 ? fileNames.first : '${fileNames.length} 个文件';
    showPcDialog<bool>(
      context: context,
      width: 360,
      barrierDismissible: false,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '发送文件',
              style: AppText.lg.copyWith(fontWeight: FontWeight.w600, color: context.colors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              '确定要发送 $nameStr 吗？',
              style: AppText.sm.copyWith(color: context.colors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  style: AppTheme.mutedTextButtonStyle(context.colors),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('发送'),
                ),
              ],
            ),
          ],
        ),
      ),
    ).then((confirmed) {
      if (confirmed != true) return;
      final controller = Provider.of<ConversationController>(context, listen: false);
      final conversation = _inputBarController.conversation;
      final imageExts = {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'};
      for (final file in files) {
        final path = file.path;
        final ext = path.toLowerCase().substring(path.lastIndexOf('.') >= 0 ? path.lastIndexOf('.') : 0);
        if (imageExts.contains(ext)) {
          controller.onPickImage(conversation, path);
        } else {
          final size = File(path).lengthSync();
          controller.onPickFile(conversation, path, file.name, size);
        }
      }
    });
  }

  Widget _buildMultiSelectToolBar(BuildContext context, ConversationViewModel viewModel) {
    return Container(
      height: 60,
      color: isDesktopShell ? context.colors.chatBgDesktop : context.colors.chatBg,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: const Icon(Icons.forward),
            onPressed: () {
              _handleForward(context, viewModel);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              _handleDeleteSelected(context, viewModel);
            },
          ),
        ],
      ),
    );
  }

  void _handleDeleteSelected(BuildContext context, ConversationViewModel viewModel) {
    if (viewModel.getSelectedMessages().isEmpty) {
      showToast(msg: AppLocalizations.of(context)!.selectMessage);
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(AppLocalizations.of(context)!.deleteMessage),
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                _deleteMessages(context, viewModel, false);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(AppLocalizations.of(context)!.deleteLocalMessage),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                _deleteMessages(context, viewModel, true);
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

  void _deleteMessages(BuildContext context, ConversationViewModel viewModel, bool isRemote) {
    var selected = viewModel.getSelectedMessages();
    for (var msg in selected) {
      if (isRemote) {
        if (msg.messageUid != null && msg.messageUid! > 0) {
          Imclient.deleteRemoteMessage(msg.messageUid!, () {}, (errorCode) {
            showToast(msg: AppLocalizations.of(context)!.deleteRemoteMessageFail(errorCode.toString()));
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
      showToast(msg: AppLocalizations.of(context)!.selectMessage);
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(AppLocalizations.of(context)!.forward),
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                _forwardMessages(context, viewModel, selected, false);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(AppLocalizations.of(context)!.forwardOneByOne),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                _forwardMessages(context, viewModel, selected, true);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(AppLocalizations.of(context)!.forwardCombined),
              ),
            ),
          ],
        );
      },
    );
  }

  void _forwardMessages(BuildContext context, ConversationViewModel viewModel, List<Message> messages, bool isMerge) {
    showPickForwardTarget(
      context,
      messages: messages,
      onSelected: (conversations, comment) {
        viewModel.toggleMultiSelectMode();

        for (var target in conversations) {
          if (isMerge && messages.length > 1) {
            _sendCompositeMessage(context, target, messages);
          } else {
            _sendOneByOneMessage(context, target, messages);
          }
          if (comment != null && comment.isNotEmpty) {
            Imclient.sendMessage(target, TextMessageContent(comment), successCallback: (uid, ts) {}, errorCallback: (err) {});
          }
        }
        showToast(msg: AppLocalizations.of(context)!.sent);
      },
    );
  }

  void _sendOneByOneMessage(BuildContext context, Conversation target, List<Message> messages) {
    messages.sort((a, b) => a.serverTime.compareTo(b.serverTime));
    for (var msg in messages) {
      Imclient.sendMessage(target, msg.content, successCallback: (messageUid, timestamp) {}, errorCallback: (errorCode) {
        showToast(msg: AppLocalizations.of(context)!.sendFail);
      });
    }
  }

  void _sendCompositeMessage(BuildContext context, Conversation target, List<Message> messages) {
    CompositeMessageContent content = CompositeMessageContent();
    content.title = AppLocalizations.of(context)!.chatHistory;
    messages.sort((a, b) => a.serverTime.compareTo(b.serverTime));
    content.messages = messages;

    Imclient.sendMessage(target, content, successCallback: (messageUid, timestamp) {}, errorCallback: (errorCode) {
      showToast(msg: AppLocalizations.of(context)!.sendFail);
    });
  }

  void _onMentionTriggered(Conversation conversation) async {
    List<String> candidates = [];
    bool showAll = false;
    if (conversation.conversationType == ConversationType.Group) {
      var members = await Imclient.getGroupMembers(conversation.target);
      candidates.addAll(members.map((e) => e.memberId).toList());
      var me = members.firstWhere((element) => element.memberId == Imclient.currentUserId, orElse: () => GroupMember());
      if (me.type == GroupMemberType.Owner || me.type == GroupMemberType.Manager) {
        showAll = true;
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

    if (!mounted) {
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PickUserScreen(
          (context, pickedUsers) {
            if (pickedUsers.isNotEmpty) {
              if (pickedUsers[0] == '@all') {
                UserInfo all = UserInfo('@all');
                all.displayName = AppLocalizations.of(context)!.allMembers;
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
          title: AppLocalizations.of(context)!.pickRemindUser,
          maxSelected: 1,
          candidates: candidates,
          showMentionAll: showAll,
        ),
      ),
    );
  }

  /// 消息时间分隔（对齐微信）：会话第一条（最旧）必显示；与上一条（更旧的
  /// 一条，反序列表中是 index+1）时间间隔小于 2 分钟则不显示。
  bool _shouldShowTimeDivider(List<UIMessage> list, int index) {
    if (index == list.length - 1) return true;
    final current = list[index].message.serverTime;
    final previous = list[index + 1].message.serverTime;
    return current - previous >= 2 * 60 * 1000;
  }

  Widget _buildTimeDivider(BuildContext context, UIMessage msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(
          Utilities.formatMessageTime(context, msg.message.serverTime),
          style: AppText.xs.copyWith(color: context.colors.textTertiary),
        ),
      ),
    );
  }

  Widget _buildMessageItem(BuildContext context, int index, ConversationViewModel conversationViewModel) {
    var conversationMessageList = conversationViewModel.conversationMessageList;
    var msg = conversationMessageList[index];
    var cell = MessageCell(msg);
    Widget content;
    if (conversationViewModel.isMultiSelectMode) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          conversationViewModel.toggleMessageSelection(msg.message.messageId);
        },
        child: Row(
          children: [
            if (msg.message.content is! NotificationMessageContent)
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
      content = cell;
    }
    if (!_shouldShowTimeDivider(conversationMessageList, index)) {
      return content;
    }
    return Column(
      children: [
        _buildTimeDivider(context, msg),
        content,
      ],
    );
  }
}
