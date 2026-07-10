import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chat/conversation/input_bar/emoji_board.dart';
import 'package:chat/conversation/input_bar/plugin_board.dart';
import 'package:chat/conversation/input_bar/record_widget.dart';
import 'package:chat/conversation/input_bar/channel_menu_widget.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/video_message_content.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/pc/pc_platform.dart';
import 'message_input_bar_controller.dart';

/// 持久化的键盘高度key
const String _kKeyboardHeightKey = 'saved_keyboard_height';

/// 微信风格的输入栏
/// 实现原理：
/// 1. 底部区域高度 = max(键盘高度, 面板高度)
/// 2. 切换时保持底部高度稳定，输入栏位置不变
/// 3. 使用动画平滑过渡
class MessageInputBar extends StatefulWidget {
  const MessageInputBar({super.key});

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar> with WidgetsBindingObserver {
  static const List<String> emojis = kChatEmojis;

  /// 上一次显示的面板类型（emoji 或 plugin）
  ChatInputBarStatus? _previousBoardStatus;
  /// 面板→键盘过渡期间保持面板可见
  bool _keepBoardVisible = false;
  /// 收起动画时显示的面板类型
  ChatInputBarStatus? _animatingBoardStatus;
  /// 持久化的键盘高度
  double _savedKeyboardHeight = 0;
  /// 上一次的键盘高度（用于检测稳定）
  double _lastKeyboardHeight = 0;
  /// 键盘高度连续稳定的次数
  int _keyboardStableCount = 0;

  static const double _minBoardHeight = 280.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSavedKeyboardHeight();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadSavedKeyboardHeight() async {
    final prefs = await SharedPreferences.getInstance();
    final savedHeight = prefs.getDouble(_kKeyboardHeightKey) ?? 0;
    if (savedHeight > 0 && mounted) {
      setState(() {
        _savedKeyboardHeight = savedHeight;
      });
    }
  }

  Future<void> _saveKeyboardHeight(double height) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kKeyboardHeightKey, height);
  }

  @override
  void didChangeMetrics() {
    final keyboardHeight =
        WidgetsBinding.instance.platformDispatcher.views.first.viewInsets.bottom / WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

    // 检测键盘高度是否稳定
    if (keyboardHeight == _lastKeyboardHeight && keyboardHeight > 0) {
      _keyboardStableCount++;
    } else {
      _keyboardStableCount = 0;
    }

    // 键盘弹出到目标高度时，结束面板→键盘的过渡
    if (_keepBoardVisible && keyboardHeight > 0) {
      final targetHeight = _savedKeyboardHeight > 0 ? _savedKeyboardHeight : _minBoardHeight;
      // 条件1: 键盘高度达到目标高度
      // 条件2: 键盘高度稳定3帧以上（说明键盘已弹出完成，即使高度不同）
      if (keyboardHeight >= targetHeight || _keyboardStableCount >= 3) {
        // 更新保存的高度为实际键盘高度，确保下次过渡平滑
        if (keyboardHeight > 0 && (_savedKeyboardHeight - keyboardHeight).abs() > 1) {
          _savedKeyboardHeight = keyboardHeight;
          _saveKeyboardHeight(keyboardHeight);
        }
        setState(() {
          _keepBoardVisible = false;
          _previousBoardStatus = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<MessageInputBarController>(context);
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    final bool isInBoardMode = controller.status == ChatInputBarStatus.emojiStatus || controller.status == ChatInputBarStatus.pluginStatus;

    // 键盘高度稳定时保存（避免动画过程中的中间值）
    if (keyboardHeight > 0 && keyboardHeight == _lastKeyboardHeight) {
      if ((_savedKeyboardHeight - keyboardHeight).abs() > 1) {
        _savedKeyboardHeight = keyboardHeight;
        _saveKeyboardHeight(keyboardHeight);
      }
    }
    _lastKeyboardHeight = keyboardHeight;

    final double targetBoardHeight = max(_savedKeyboardHeight, _minBoardHeight);

    // 状态变化处理
    if (isInBoardMode) {
      _previousBoardStatus = controller.status;
      _keepBoardVisible = false;
    } else if (controller.status == ChatInputBarStatus.keyboardStatus &&
        controller.focusNode.hasFocus &&
        _previousBoardStatus != null &&
        keyboardHeight < targetBoardHeight * 0.5) {
      // 从面板切换到键盘，保持面板可见直到键盘弹出
      _keepBoardVisible = true;
    } else if (controller.status != ChatInputBarStatus.keyboardStatus || !controller.focusNode.hasFocus) {
      // 非面板非键盘状态，或键盘失去焦点（收起全部），清除记录
      _previousBoardStatus = null;
      _keepBoardVisible = false;
    }

    final bool showBoard = isInBoardMode || _keepBoardVisible;

    // 底部高度计算
    // 当没有键盘和面板时，需要添加安全区高度（因为SafeArea bottom: false）
    final double bottomHeight;
    if (isInBoardMode) {
      bottomHeight = targetBoardHeight;
    } else if (_keepBoardVisible) {
      bottomHeight = max(keyboardHeight, targetBoardHeight);
    } else if (keyboardHeight > 0) {
      bottomHeight = keyboardHeight;
    } else {
      // 无键盘无面板时，添加安全区高度
      bottomHeight = bottomPadding;
    }

    // 判断是否使用动画：
    // 只有"纯面板显示/隐藏"才用动画（即：当前无键盘、上一帧也无键盘、且不在过渡中）
    // 所有涉及键盘的场景都不用动画
    final bool useAnimation = keyboardHeight == 0 && _lastKeyboardHeight == 0 && !_keepBoardVisible;

    // 记录当前显示的面板类型，用于收起动画
    if (isInBoardMode) {
      _animatingBoardStatus = controller.status;
    }

    return Container(
      color: isDesktopShell ? context.colors.chatBgDesktop : context.colors.chatBg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildInputBar(controller),
          ClipRect(
            child: useAnimation
                ? AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    height: bottomHeight,
                    child: showBoard ? _buildBoardsStack(controller, targetBoardHeight) : null,
                  )
                : Container(
                    height: bottomHeight,
                    child: showBoard ? _buildBoardsStack(controller, targetBoardHeight) : null,
                  ),
          ),
        ],
      ),
    );
  }

  /// 构建引用消息组件
  Widget _buildQuoteWidget(MessageInputBarController controller) {
    final content = controller.quotedMessage!.content;
    Widget? thumbnail;

    // 如果是图片消息，显示缩略图
    if (content is ImageMessageContent) {
      if (content.thumbnail != null) {
        thumbnail = ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.memory(content.thumbnail!, width: 40, height: 40, fit: BoxFit.cover),
        );
      }
    }
    // 如果是视频消息，显示缩略图
    else if (content is VideoMessageContent) {
      if (content.thumbnail != null) {
        thumbnail = ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.memory(content.thumbnail!, width: 40, height: 40, fit: BoxFit.cover),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: context.colors.bubbleQuoted,
        border: Border(
          top: BorderSide(width: 0.5, color: context.colors.hairline),
        ),
      ),
      child: Row(
        children: [
          if (thumbnail != null) ...[
            thumbnail,
            const SizedBox(width: 8),
          ],
          Expanded(
            child: FutureBuilder<String>(
              future: content.digest(controller.quotedMessage!),
              builder: (context, snapshot) {
                return Text(
                  snapshot.data ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.colors.bubbleQuotedText, fontSize: 13),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => controller.setQuotedMessage(null),
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close, size: 18, color: context.colors.iconSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(MessageInputBarController controller) {
    const double iconSize = 32;
    bool showMenu = controller.channelInfo?.menus != null && controller.channelInfo!.menus!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: isDesktopShell ? context.colors.chatBgDesktop : context.colors.chatBg,
        border: Border(
          top: BorderSide(width: 1, color: context.colors.hairline),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              controller.status == ChatInputBarStatus.recordStatus
                  ? IconButton(
                      icon: Image.asset('assets/images/input/chat_input_bar_keyboard.png', width: iconSize, height: iconSize), onPressed: controller.onKeyboardButton)
                  : IconButton(icon: Image.asset('assets/images/input/chat_input_bar_voice.png', width: iconSize, height: iconSize), onPressed: controller.onVoiceButton),
              if (showMenu)
                IconButton(
                    icon: controller.status == ChatInputBarStatus.menuStatus
                        ? Image.asset('assets/images/input/chat_input_bar_keyboard.png', width: iconSize, height: iconSize)
                        : const Icon(Icons.menu, size: iconSize, color: Color(0xFF7f7f7f)),
                    onPressed: controller.onMenuButton),
              Expanded(
                child: showMenu && controller.status == ChatInputBarStatus.menuStatus
                    ? ChannelMenuWidget(menus: controller.channelInfo!.menus!, conversation: controller.conversation)
                    : (controller.status == ChatInputBarStatus.recordStatus
                        ? RecordWidget(controller.conversation)
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(0, 5, 5, 5),
                            child: Column(
                              children: [
                                CupertinoTextField(
                                  maxLines: 3,
                                  minLines: 1,
                                  controller: controller.textEditingController,
                                  focusNode: controller.focusNode,
                                  onSubmitted: (_) => controller.onSendButton(),
                                  onChanged: controller.onTextChanged,
                                  style: TextStyle(color: context.colors.textPrimary),
                                  placeholderStyle: TextStyle(color: context.colors.textTertiary),
                                  decoration: BoxDecoration(
                                    color: context.colors.surface,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: context.colors.hairline),
                                  ),
                                  cursorColor: context.colors.accent,
                                ),
                                if (controller.quotedMessage != null)
                                  Padding(
                                      padding: const EdgeInsets.fromLTRB(0, 5, 0, 0),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: _buildQuoteWidget(controller),
                                      ))
                              ],
                            ))),
              ),
              if (controller.status != ChatInputBarStatus.menuStatus) ...[
                controller.status == ChatInputBarStatus.emojiStatus
                    ? IconButton(
                        icon: Image.asset('assets/images/input/chat_input_bar_keyboard.png', width: iconSize, height: iconSize), onPressed: controller.onKeyboardButton)
                    : IconButton(
                        icon: Image.asset('assets/images/input/chat_input_bar_emoji.png', width: iconSize, height: iconSize), onPressed: controller.onEmojiButton),
                controller.textEditingController.text.isNotEmpty &&
                        controller.status != ChatInputBarStatus.recordStatus &&
                        controller.status != ChatInputBarStatus.pluginStatus
                    ? ElevatedButton(onPressed: controller.onSendButton, child: const Text("发送"))
                    : IconButton(
                        icon: Image.asset('assets/images/input/chat_input_bar_plugin.png', width: iconSize, height: iconSize), onPressed: controller.onPluginButton),
              ]
            ],
          ),
        ],
      ),
    );
  }

  /// 构建面板（用于动画，使用记录的面板类型）
  Widget _buildBoardsStackForAnimation(MessageInputBarController controller, double height) {
    // 使用记录的面板类型，确保收起动画显示正确的面板
    int index = 0;
    final statusToUse = _animatingBoardStatus ?? controller.status;
    if (statusToUse == ChatInputBarStatus.pluginStatus) {
      index = 1;
    }

    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        height: height,
        child: IndexedStack(
          index: index,
          children: [
            EmojiBoard(
              emojis,
              pickerEmojiCallback: (emoji) => controller.insertText(emoji),
              delEmojiCallback: () => controller.backspace(emojis),
              pickerStickerCallback: (stickerPath) => controller.sendSticker(stickerPath),
              height: height,
            ),
            PluginBoard(controller.conversation, height: height),
          ],
        ),
      ),
    );
  }

  /// 构建面板
  Widget _buildBoardsStack(MessageInputBarController controller, double height) {
    // 优先用 _previousBoardStatus 或 _keepBoardVisible 时的面板类型，保证收起动画期间显示正确面板
    ChatInputBarStatus? statusToShow;
    if (_keepBoardVisible && _previousBoardStatus != null) {
      statusToShow = _previousBoardStatus;
    } else if (controller.status == ChatInputBarStatus.emojiStatus || controller.status == ChatInputBarStatus.pluginStatus) {
      statusToShow = controller.status;
    }
    int index = (statusToShow == ChatInputBarStatus.pluginStatus) ? 1 : 0;

    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        height: height,
        child: IndexedStack(
          index: index,
          children: [
            EmojiBoard(
              emojis,
              pickerEmojiCallback: (emoji) => controller.insertText(emoji),
              delEmojiCallback: () => controller.backspace(emojis),
              pickerStickerCallback: (stickerPath) => controller.sendSticker(stickerPath),
              height: height,
            ),
            PluginBoard(controller.conversation, height: height),
          ],
        ),
      ),
    );
  }
}
