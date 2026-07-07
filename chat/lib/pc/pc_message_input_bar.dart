import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/video_message_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:chat/conversation/conversation_controller.dart';
import 'package:chat/conversation/input_bar/emoji_board.dart';
import 'package:chat/conversation/input_bar/message_input_bar_controller.dart';
import 'package:chat/pc/pc_av_call.dart';
import 'package:chat/pc/pc_theme.dart';
import 'package:chat/pc/widgets/hover_builder.dart';
import 'package:chat/pc/widgets/pc_popover.dart';
import 'package:chat/pc/widgets/pc_dialog.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// 桌面形态输入栏:工具条(表情/图片/文件/通话)+ 多行输入区 + 发送按钮。
/// Enter 发送、Shift+Enter 换行;中文输入法组合期间的 Enter 交给输入法。
/// 复用 [MessageInputBarController] 的文本/@提醒/引用/草稿逻辑,与手机形态共享一套状态。
class PcMessageInputBar extends StatefulWidget {
  const PcMessageInputBar({super.key});

  @override
  State<PcMessageInputBar> createState() => _PcMessageInputBarState();
}

class _PcMessageInputBarState extends State<PcMessageInputBar> {
  final GlobalKey _emojiButtonKey = GlobalKey();
  bool _isPickingFile = false;
  String _textBeforePaste = '';

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event, MessageInputBarController controller) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    // Ctrl/Cmd+V 粘贴:如果剪贴板里有图片则走确认后发送,否则交给输入框处理文本粘贴
    if (event.logicalKey == LogicalKeyboardKey.keyV &&
        (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed)) {
      _textBeforePaste = controller.textEditingController.text;
      _handlePaste(controller);
      return KeyEventResult.ignored;
    }
    if (event.logicalKey != LogicalKeyboardKey.enter && event.logicalKey != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    // Shift+Enter 换行,交给输入框
    if (HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    // 输入法组合中(如中文候选未上屏),Enter 属于输入法
    if (controller.textEditingController.value.composing.isValid) {
      return KeyEventResult.ignored;
    }
    if (controller.textEditingController.text.trim().isNotEmpty) {
      controller.onSendButton();
    }
    return KeyEventResult.handled;
  }

  Future<void> _handlePaste(MessageInputBarController controller) async {
    try {
      final clipboard = SystemClipboard.instance;
      if (clipboard == null) {
        return;
      }
      final reader = await clipboard.read();
      final format = _findAvailableImageFormat(reader);
      if (format == null) {
        // 剪贴板里没有图片,交给 TextField 处理文本粘贴
        return;
      }
      // 回退 TextField 粘入的图片元数据文本
      if (controller.textEditingController.text != _textBeforePaste) {
        controller.textEditingController.text = _textBeforePaste;
        controller.textEditingController.selection =
            TextSelection.collapsed(offset: _textBeforePaste.length);
      }
      // super_clipboard 的 getFile 使用回调模式
      reader.getFile(format, (file) async {
        try {
          final bytes = await file.readAll();
          if (!mounted || bytes.isEmpty) {
            return;
          }
          final ext = format == Formats.png
              ? 'png'
              : (format == Formats.gif
                  ? 'gif'
                  : 'jpg');
          final tempDir = await getTemporaryDirectory();
          final path = '${tempDir.path}/paste_${DateTime.now().millisecondsSinceEpoch}.$ext';
          await File(path).writeAsBytes(bytes);
          if (!mounted) return;
          // 弹确认对话框
          final fileName = path.split('/').last;
          final confirmed = await _showSendConfirmDialog(fileName);
          if (confirmed == true && mounted) {
            final conversationController = Provider.of<ConversationController>(context, listen: false);
            conversationController.onPickImage(controller.conversation, path);
          }
        } catch (e) {
          debugPrint('paste image read failed: $e');
        }
      });
    } catch (e) {
      debugPrint('paste image failed: $e');
    }
  }

  SimpleFileFormat? _findAvailableImageFormat(ClipboardReader reader) {
    if (reader.canProvide(Formats.png)) return Formats.png;
    if (reader.canProvide(Formats.jpeg)) return Formats.jpeg;
    if (reader.canProvide(Formats.gif)) return Formats.gif;
    return null;
  }

  Future<bool?> _showSendConfirmDialog(String fileName) async {
    return showPcDialog<bool>(
      context: context,
      width: 360,
      barrierDismissible: false,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '发送文件',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: PcTheme.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              '确定要发送 "$fileName" 吗？',
              style: const TextStyle(fontSize: 13, color: PcTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  style: TextButton.styleFrom(foregroundColor: PcTheme.textSecondary),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: PcTheme.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  child: const Text('发送'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEmojiPopover(MessageInputBarController controller) {
    final renderBox = _emojiButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return;
    }
    final anchor = renderBox.localToGlobal(Offset.zero) & renderBox.size;
    showPcPopover(
      context: context,
      anchor: anchor,
      size: const Size(400, 320),
      builder: (popoverContext) => EmojiBoard(
        kChatEmojis,
        pickerEmojiCallback: (emoji) => controller.insertText(emoji),
        delEmojiCallback: () => controller.backspace(kChatEmojis),
        pickerStickerCallback: (stickerPath) {
          Navigator.of(popoverContext).pop();
          controller.sendSticker(stickerPath);
        },
        height: 320,
      ),
    );
  }

  Future<void> _pickImage(ConversationController conversationController, MessageInputBarController controller) async {
    if (_isPickingFile) return;
    _isPickingFile = true;
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      final path = result?.files.firstOrNull?.path;
      if (path != null) {
        conversationController.onPickImage(controller.conversation, path);
      }
    } catch (e) {
      debugPrint('pickImage error: $e');
    } finally {
      _isPickingFile = false;
    }
  }

  Future<void> _pickFile(ConversationController conversationController, MessageInputBarController controller) async {
    if (_isPickingFile) return;
    _isPickingFile = true;
    try {
      final result = await FilePicker.platform.pickFiles();
      final file = result?.files.firstOrNull;
      if (file?.path != null) {
        conversationController.onPickFile(controller.conversation, file!.path!, file.name, file.size);
      }
    } catch (e) {
      debugPrint('pickFile error: $e');
    } finally {
      _isPickingFile = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<MessageInputBarController>(context);
    final conversationController = Provider.of<ConversationController>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;
    final hasText = controller.textEditingController.text.trim().isNotEmpty;

    return Container(
      height: PcTheme.inputBarHeight,
      decoration: const BoxDecoration(
        color: PcTheme.chatBg,
        border: Border(top: BorderSide(width: 0.5, color: PcTheme.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(
              children: [
                _ToolbarButton(
                  key: _emojiButtonKey,
                  icon: Icons.sentiment_satisfied_outlined,
                  tooltip: l10n.emoji,
                  onTap: () => _showEmojiPopover(controller),
                ),
                _ToolbarButton(
                  icon: Icons.image_outlined,
                  tooltip: l10n.image,
                  onTap: () => _pickImage(conversationController, controller),
                ),
                _ToolbarButton(
                  icon: Icons.folder_outlined,
                  tooltip: l10n.filePicker,
                  onTap: () => _pickFile(conversationController, controller),
                ),
                const Spacer(),
                // 通话入口靠右(微信 PC 布局),分语音/视频两个按钮:
                // 单聊直接发起,群聊先弹选人对话框再发起(见 startAvCall)
                if (controller.conversation.conversationType == ConversationType.Single ||
                    controller.conversation.conversationType == ConversationType.Group) ...[
                  _ToolbarButton(
                    icon: Icons.call_outlined,
                    tooltip: l10n.audioCallAction,
                    onTap: () => startAvCall(context, controller.conversation, audioOnly: true),
                  ),
                  _ToolbarButton(
                    icon: Icons.videocam_outlined,
                    tooltip: l10n.videoCallAction,
                    onTap: () => startAvCall(context, controller.conversation, audioOnly: false),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: Focus(
              onKeyEvent: (node, event) => _handleKeyEvent(node, event, controller),
              child: TextField(
                controller: controller.textEditingController,
                focusNode: controller.focusNode,
                onChanged: controller.onTextChanged,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(fontSize: 14, height: 1.5, color: PcTheme.textPrimary),
                decoration: const InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
          ),
          if (controller.quotedMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: _QuoteChip(controller: controller),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                const Spacer(),
                Tooltip(
                  message: l10n.enterToSendHint,
                  child: ElevatedButton(
                    onPressed: hasText ? controller.onSendButton : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PcTheme.accent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE3E2E1),
                      disabledForegroundColor: PcTheme.textTertiary,
                      elevation: 0,
                      minimumSize: const Size(88, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    child: Text(l10n.send),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ToolbarButton({super.key, required this.icon, required this.tooltip, required this.onTap});

  @override
  State<_ToolbarButton> createState() => _ToolbarButtonState();
}

class _ToolbarButtonState extends State<_ToolbarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: _hovered ? Colors.black.withValues(alpha: 0.06) : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(widget.icon, size: 21, color: const Color(0xFF5C5C5C)),
          ),
        ),
      ),
    );
  }
}

/// 引用消息条:摘要 + 缩略图(图片/视频)+ 取消按钮,显示在输入区与发送按钮之间。
class _QuoteChip extends StatelessWidget {
  final MessageInputBarController controller;

  const _QuoteChip({required this.controller});

  @override
  Widget build(BuildContext context) {
    final quoted = controller.quotedMessage!;
    final content = quoted.content;
    Widget? thumbnail;
    if (content is ImageMessageContent && content.thumbnail != null) {
      thumbnail = ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Image.memory(content.thumbnail!, width: 24, height: 24, fit: BoxFit.cover),
      );
    } else if (content is VideoMessageContent && content.thumbnail != null) {
      thumbnail = ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Image.memory(content.thumbnail!, width: 24, height: 24, fit: BoxFit.cover),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFEAE9E8),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (thumbnail != null) ...[
              thumbnail,
              const SizedBox(width: 6),
            ],
            Flexible(
              child: FutureBuilder<String>(
                future: content.digest(quoted),
                builder: (context, snapshot) => Text(
                  snapshot.data ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: PcTheme.textSecondary),
                ),
              ),
            ),
            const SizedBox(width: 6),
            HoverBuilder(
              cursor: SystemMouseCursors.click,
              builder: (context, hovered) => GestureDetector(
                onTap: () => controller.setQuotedMessage(null),
                child: Icon(Icons.close, size: 14, color: hovered ? PcTheme.textPrimary : PcTheme.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
