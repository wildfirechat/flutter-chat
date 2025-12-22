import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chat/conversation/input_bar/emoji_board.dart';
import 'package:chat/conversation/input_bar/plugin_board.dart';
import 'package:chat/conversation/input_bar/record_widget.dart';
import 'package:chat/conversation/input_bar/channel_menu_widget.dart';

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
  static const List<String> emojis = [
    '😊', '😨', '😍', '😳', '😎', '😭', '😌', '😵', '😴', '😢',
    '😅', '😡', '😜', '😀', '😲', '😟', '😤', '😞', '😫', '😣',
    '😈', '😉', '😯', '😕', '😰', '😋', '😝', '😓', '😃', '😂',
    '😘', '😒', '😏', '😶', '😱', '😖', '😩', '😔', '😑', '😚',
    '😪', '😇', '🙊', '👊', '👎', '☝', '✌', '😬', '😷', '🙈',
    '👌', '👏', '✊', '💪', '😆', '☺', '🙉', '👍', '🙏', '✋',
    '☀', '☕', '⛄', '📚', '🎁', '🎉', '🍦', '☁', '❄', '⚡',
    '💰', '🎂', '🎓', '🍖', '☔', '⛅', '✏', '💩', '🎄', '🍷',
    '🎤', '🏀', '🀄', '💣', '📢', '🌏', '🍫', '🎲', '🏂', '💡',
    '💤', '🚫', '🌻', '🍻', '🎵', '🏡', '💢', '📞', '🚿', '🍚',
    '👪', '👼', '💊', '🔫', '🌹', '🐶', '💄', '👫', '👽', '💋',
    '🌙', '🍉', '🐷', '💔', '👻', '👿', '💍', '🌲', '🐴', '👑',
    '🔥', '⭐', '⚽', '🕖', '⏰', '😁', '🚀', '⏳', '🏡'
  ];

  /// 上一次显示的面板类型（emoji 或 plugin）
  ChatInputBarStatus? _previousBoardStatus;
  /// 面板→键盘过渡期间保持面板可见
  bool _keepBoardVisible = false;
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
    final keyboardHeight = WidgetsBinding.instance.platformDispatcher.views.first.viewInsets.bottom /
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

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

    final bool isInBoardMode = controller.status == ChatInputBarStatus.emojiStatus ||
        controller.status == ChatInputBarStatus.pluginStatus;

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
        _previousBoardStatus != null &&
        keyboardHeight < targetBoardHeight * 0.5) {
      // 从面板切换到键盘，保持面板可见直到键盘弹出
      _keepBoardVisible = true;
    } else if (controller.status != ChatInputBarStatus.keyboardStatus) {
      // 非面板非键盘状态，清除记录
      _previousBoardStatus = null;
      _keepBoardVisible = false;
    }

    final bool showBoard = isInBoardMode || _keepBoardVisible;

    // 底部高度计算
    final double bottomHeight;
    if (isInBoardMode) {
      bottomHeight = targetBoardHeight;
    } else if (_keepBoardVisible) {
      bottomHeight = max(keyboardHeight, targetBoardHeight);
    } else {
      bottomHeight = keyboardHeight;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildInputBar(controller),
        AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: bottomHeight,
          child: showBoard
              ? _buildBoardsStack(controller, targetBoardHeight)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildInputBar(MessageInputBarController controller) {
    double iconSize = 32;
    bool showMenu = controller.channelInfo?.menus != null && controller.channelInfo!.menus!.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        border: Border(
          top: BorderSide(width: 1, color: Color(0xFFDDDDDD)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              controller.status == ChatInputBarStatus.recordStatus
                  ? IconButton(
                      icon: Image.asset('assets/images/input/chat_input_bar_keyboard.png', width: iconSize, height: iconSize),
                      onPressed: controller.onKeyboardButton)
                  : IconButton(
                      icon: Image.asset('assets/images/input/chat_input_bar_voice.png', width: iconSize, height: iconSize),
                      onPressed: controller.onVoiceButton),
              if (showMenu)
                IconButton(
                    icon: controller.status == ChatInputBarStatus.menuStatus
                        ? Image.asset('assets/images/input/chat_input_bar_keyboard.png', width: iconSize, height: iconSize)
                        : const Icon(Icons.menu, size: 32, color: Color(0xFF7f7f7f)),
                    onPressed: controller.onMenuButton),
              Expanded(
                child: showMenu && controller.status == ChatInputBarStatus.menuStatus
                    ? ChannelMenuWidget(menus: controller.channelInfo!.menus!, conversation: controller.conversation)
                    : (controller.status == ChatInputBarStatus.recordStatus
                        ? RecordWidget(controller.conversation)
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(0, 5, 5, 5),
                            child: CupertinoTextField(
                              maxLines: 3,
                              minLines: 1,
                              controller: controller.textEditingController,
                              focusNode: controller.focusNode,
                              onSubmitted: (_) => controller.onSendButton(),
                              onChanged: controller.onTextChanged,
                            ),
                          )),
              ),
              if (controller.status != ChatInputBarStatus.menuStatus) ...[
                controller.status == ChatInputBarStatus.emojiStatus
                    ? IconButton(
                        icon: Image.asset('assets/images/input/chat_input_bar_keyboard.png', width: iconSize, height: iconSize),
                        onPressed: controller.onKeyboardButton)
                    : IconButton(
                        icon: Image.asset('assets/images/input/chat_input_bar_emoji.png', width: iconSize, height: iconSize),
                        onPressed: controller.onEmojiButton),
                controller.textEditingController.text.isNotEmpty &&
                        controller.status != ChatInputBarStatus.recordStatus &&
                        controller.status != ChatInputBarStatus.pluginStatus
                    ? ElevatedButton(onPressed: controller.onSendButton, child: const Text("发送"))
                    : IconButton(
                        icon: Image.asset('assets/images/input/chat_input_bar_plugin.png', width: iconSize, height: iconSize),
                        onPressed: controller.onPluginButton),
              ]
            ],
          ),
          if (controller.quotedMessage != null)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              color: const Color(0xFFF5F5F5),
              child: Row(
                children: [
                  Expanded(
                    child: FutureBuilder<String>(
                      future: controller.quotedMessage!.content.digest(controller.quotedMessage!),
                      builder: (context, snapshot) {
                        return Text(
                          "引用: ${snapshot.data ?? ''}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF666666), fontSize: 12),
                        );
                      },
                    ),
                  ),
                  GestureDetector(
                    onTap: () => controller.setQuotedMessage(null),
                    child: const Icon(Icons.close, size: 16, color: Color(0xFF999999)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 构建面板
  Widget _buildBoardsStack(MessageInputBarController controller, double height) {
    int index = 0;
    if (controller.status == ChatInputBarStatus.pluginStatus ||
        (_keepBoardVisible && _previousBoardStatus == ChatInputBarStatus.pluginStatus)) {
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
}
