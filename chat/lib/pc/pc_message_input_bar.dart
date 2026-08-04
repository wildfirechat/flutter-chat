import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/video_message_content.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:provider/provider.dart';
import 'package:chat/collection/create_collection_screen.dart';
import 'package:chat/collection/collection_icon.dart';
import 'package:chat/config.dart';
import 'package:chat/poll/poll_home_screen.dart';
import 'package:chat/conversation/conversation_controller.dart';
import 'package:chat/conversation/input_bar/channel_menu_widget.dart';
import 'package:chat/conversation/input_bar/emoji_board.dart';
import 'package:chat/conversation/input_bar/message_input_bar_controller.dart';
import 'package:chat/call/av_call_launcher.dart';
import 'package:chat/pc/pc_layout_view_model.dart';
import 'package:chat/pc/pc_clipboard_paste_handler.dart';
import 'package:chat/pc/pc_mention_popup.dart';
import 'package:chat/pc/pc_theme.dart';
import 'package:chat/pc/widgets/hover_builder.dart';
import 'package:chat/pc/widgets/pc_popover.dart';
import 'package:chat/pc/widgets/pc_resize_handle.dart';
import 'package:chat/utils/screenshot_service.dart';
import 'package:chat/utils/show_toast.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';

/// 桌面形态输入栏:顶部拖拽条 + 工具条(表情/图片/文件/通话)+ 多行输入区。
/// Enter 发送、Shift+Enter 换行;中文输入法组合期间的 Enter 交给输入法。
/// 粘贴的图片/文件内联显示在输入框里(微信 PC 交互),发送时先逐个发附件再发文本。
/// 键入 '@' 弹出 [PcMentionOverlay] 就地选人(微信 PC 交互),浮层优先消费导航按键。
/// 复用 [MessageInputBarController] 的文本/@提醒/引用/草稿逻辑,与手机形态共享一套状态。
///
/// 高度由 [PcLayoutViewModel] 统一持有(所有会话共用一个高度、跨启动保留),
/// 拖顶部的分隔条调整;[maxHeight] 是会话区留给输入栏的上限,由外层按窗口高度算出。
class PcMessageInputBar extends StatefulWidget {
  const PcMessageInputBar({super.key, required this.maxHeight});

  final double maxHeight;

  @override
  State<PcMessageInputBar> createState() => _PcMessageInputBarState();
}

class _PcMessageInputBarState extends State<PcMessageInputBar> {
  final GlobalKey _emojiButtonKey = GlobalKey();
  final PcClipboardPasteHandler _clipboardPasteHandler =
      const PcClipboardPasteHandler();

  /// @ 浮层靠它反查 '@' 的光标位置,把浮层贴到 '@' 上方
  final GlobalKey _textFieldKey = GlobalKey();
  bool _isPickingFile = false;

  /// 拖拽起点的高度与累计位移。用累计量而非逐帧增量,
  /// 这样拖到边界后继续拖不会“攒”出位移,回拖时立刻跟手。
  double _dragStartHeight = 0;
  double _dragOffset = 0;

  MessageInputBarController? _boundController;
  PcMentionOverlay? _mentionOverlay;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 会话切换会重建 controller,@ 浮层跟随重新绑定
    final controller = Provider.of<MessageInputBarController>(context);
    if (!identical(controller, _boundController)) {
      _mentionOverlay?.dispose();
      _boundController = controller;
      _mentionOverlay = PcMentionOverlay(
          inputBarController: controller, textFieldKey: _textFieldKey)
        ..attach(context);
    }
  }

  @override
  void dispose() {
    _mentionOverlay?.dispose();
    super.dispose();
  }

  /// 引用条占掉的固定高度(chip 34 + 与发送行的间距 4)。挂着引用时输入栏要相应加高,
  /// 否则拖到最矮会把输入框挤到 0 高。
  static const double _quoteChipRowHeight = 38;

  double get _minHeight =>
      PcTheme.inputBarMinHeight +
      (_boundController?.hasQuote == true ? _quoteChipRowHeight : 0);

  /// 会话区太矮时压缩输入栏,保证消息列表还剩得下内容。
  double get _maxHeight => math.max(_minHeight, widget.maxHeight);

  /// 渲染高度。只夹取不回写:窗口重新拉大后,用户存下的期望高度原样恢复。
  double _effectiveHeight(double height) =>
      height.clamp(_minHeight, _maxHeight).toDouble();

  void _onResizeStart(PcLayoutViewModel layout) {
    _dragStartHeight = _effectiveHeight(layout.inputBarHeight);
    _dragOffset = 0;
  }

  /// 分隔条在输入栏顶部:向上拖(dy 为负)变高。
  void _onResizeDelta(PcLayoutViewModel layout, double delta) {
    _dragOffset += delta;
    layout.setInputBarHeight((_dragStartHeight - _dragOffset)
        .clamp(_minHeight, _maxHeight)
        .toDouble());
  }

  KeyEventResult _handleKeyEvent(
      FocusNode node, KeyEvent event, MessageInputBarController controller) {
    // @ 浮层可见时优先消费 上下键/Enter/Tab/Esc
    final KeyEventResult mentionResult =
        _mentionOverlay?.handleKeyEvent(event) ?? KeyEventResult.ignored;
    if (mentionResult != KeyEventResult.ignored) {
      return mentionResult;
    }
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    // Ctrl/Cmd+V 粘贴全量接管:剪贴板有文件/图片则内联插入输入框(微信 PC 交互),
    // 否则手动粘贴纯文本。不走 TextField 默认粘贴,避免文件/图片剪贴板附带的
    // 元数据文本(如文件名)被贴进来。
    if (event.logicalKey == LogicalKeyboardKey.keyV &&
        (HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed)) {
      _handlePaste(controller);
      return KeyEventResult.handled;
    }
    if (event.logicalKey != LogicalKeyboardKey.enter &&
        event.logicalKey != LogicalKeyboardKey.numpadEnter) {
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

  /// 粘贴逻辑下沉到 [PcClipboardPasteHandler],输入栏只负责按键路由。
  Future<void> _handlePaste(MessageInputBarController controller) {
    return _clipboardPasteHandler.handlePaste(controller,
        isMounted: () => mounted);
  }

  void _showEmojiPopover(MessageInputBarController controller) {
    final renderBox =
        _emojiButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return;
    }
    final anchor = renderBox.localToGlobal(Offset.zero) & renderBox.size;
    showPcPopover(
      context: context,
      anchor: anchor,
      width: 400,
      // 面板居中于表情按钮,左半边压在会话列表上方(微信 PC 的位置感)。
      align: PcPopoverAlign.center,
      // 输入栏贴着窗口底,面板只可能落在上方,尾巴固定朝下指向表情按钮。
      placement: PcPopoverPlacement.above,
      tail: true,
      // 尾巴是卡片外形的一部分,底色要跟面板一致,否则暗色下会露出一块浅色三角。
      backgroundColor: emojiBoardBackgroundColor(context),
      builder: (popoverContext) => EmojiBoard(
        kChatEmojis,
        pickerEmojiCallback: (emoji) {
          controller.insertText(emoji);
          Navigator.of(popoverContext).pop();
        },
        delEmojiCallback: () => controller.backspace(kChatEmojis),
        pickerStickerCallback: (stickerPath) {
          Navigator.of(popoverContext).pop();
          controller.sendSticker(stickerPath);
        },
        height: 320,
      ),
    );
  }

  Future<void> _pickImage(ConversationController conversationController,
      MessageInputBarController controller) async {
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

  Future<void> _pickFile(ConversationController conversationController,
      MessageInputBarController controller) async {
    if (_isPickingFile) return;
    _isPickingFile = true;
    try {
      final result = await FilePicker.platform.pickFiles();
      final file = result?.files.firstOrNull;
      if (file?.path != null) {
        conversationController.onPickFile(
            controller.conversation, file!.path!, file.name, file.size);
      }
    } catch (e) {
      debugPrint('pickFile error: $e');
    } finally {
      _isPickingFile = false;
    }
  }

  Future<void> _captureScreenshot(MessageInputBarController controller,
      {bool hideWindow = false}) async {
    final l10n = AppLocalizations.of(context)!;
    final available = await ScreenshotService.isAvailable;
    if (!available) {
      if (mounted) {
        showToast(msg: l10n.screenshotToolNotAvailable);
      }
      return;
    }
    final result =
        await ScreenshotService.captureToFile(l10n, hideWindow: hideWindow);
    if (result.success) {
      controller.insertInlineImage(result.path!);
    } else if (result.error != null && mounted) {
      showToast(msg: result.error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<MessageInputBarController>(context);
    final conversationController =
        Provider.of<ConversationController>(context, listen: false);
    final layout = Provider.of<PcLayoutViewModel>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;

    // 频道(公众号)配了菜单时,输入栏可整体切换成菜单栏。菜单栏高度固定,
    // 不参与输入栏的拖拽调高,所以在这里直接返回,不进下面的可调高结构。
    final List<ChannelMenu> channelMenus =
        controller.conversation.conversationType == ConversationType.Channel
            ? (controller.channelInfo?.menus ?? const [])
            : const [];
    if (channelMenus.isNotEmpty &&
        controller.status == ChatInputBarStatus.menuStatus) {
      return Container(
        color: context.colors.chatBgDesktop,
        child: ChannelMenuWidget(
          menus: channelMenus,
          conversation: controller.conversation,
          onToggleInput: controller.onMenuButton,
        ),
      );
    }

    // 高度单独用 Selector 订阅:拖拽期间只重建外层 Container,
    // 输入框/工具条整棵子树作为 child 复用,不逐帧重建。
    return Selector<PcLayoutViewModel, double>(
      selector: (_, model) => model.inputBarHeight,
      builder: (context, height, child) => Container(
        height: _effectiveHeight(height),
        color: context.colors.chatBgDesktop,
        child: child,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部发丝线即分隔条本身,上下拖动调整输入栏高度
          PcResizeHandle(
            axis: PcResizeAxis.vertical,
            lineAlignment: Alignment.topCenter,
            onDragStart: () => _onResizeStart(layout),
            onDragDelta: (delta) => _onResizeDelta(layout, delta),
            onDragEnd: layout.persist,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Container(
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  border: Border.all(color: context.colors.hairline),
                  borderRadius: BorderRadius.circular(6),
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
                            onTap: () =>
                                _pickImage(conversationController, controller),
                          ),
                          // 截图按钮 + 紧贴的下拉箭头(对齐微信 PC):主按钮普通截图
                          // (窗口入镜),箭头菜单里另有「隐藏窗口截图」。
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _ToolbarButton(
                                icon: Icons.cut,
                                tooltip: l10n.screenshotTool,
                                onTap: () => _captureScreenshot(controller),
                              ),
                              _ScreenshotMenuArrow(
                                onSelected: (hideWindow) => _captureScreenshot(
                                    controller,
                                    hideWindow: hideWindow),
                              ),
                            ],
                          ),
                          _ToolbarButton(
                            icon: Icons.folder_outlined,
                            tooltip: l10n.filePicker,
                            onTap: () =>
                                _pickFile(conversationController, controller),
                          ),
                          if (controller.conversation.conversationType ==
                                  ConversationType.Group &&
                              Config.collectionServerAddress != null &&
                              Config.collectionServerAddress!.isNotEmpty)
                            _ToolbarButton(
                              iconWidget: CollectionIcon(
                                  size: 21,
                                  color: context.colors.iconSecondary),
                              tooltip: l10n.collection,
                              onTap: () => CreateCollectionScreen.show(
                                  context, controller.conversation),
                            ),
                          if (controller.conversation.conversationType ==
                                  ConversationType.Group &&
                              Config.pollServerAddress != null &&
                              Config.pollServerAddress!.isNotEmpty)
                            _ToolbarButton(
                              iconWidget: Icon(Icons.poll,
                                  size: 21,
                                  color: context.colors.iconSecondary),
                              tooltip: l10n.poll,
                              onTap: () => PollHomeScreen.show(
                                  context, controller.conversation.target),
                            ),
                          // 频道菜单入口:切回菜单栏(切换按钮在菜单栏自己右侧)
                          if (channelMenus.isNotEmpty)
                            _ToolbarButton(
                              icon: Icons.menu,
                              tooltip: l10n.channelMenu,
                              onTap: controller.onMenuButton,
                            ),
                          const Spacer(),
                          // 通话入口靠右(微信 PC 布局),分语音/视频两个按钮:
                          // 单聊直接发起,群聊先弹选人对话框再发起(见 startAvCall)
                          if (controller.conversation.conversationType ==
                                  ConversationType.Single ||
                              controller.conversation.conversationType ==
                                  ConversationType.Group) ...[
                            _ToolbarButton(
                              icon: Icons.call_outlined,
                              tooltip: l10n.audioCallAction,
                              onTap: () => startAvCall(
                                  context, controller.conversation,
                                  audioOnly: true),
                            ),
                            _ToolbarButton(
                              icon: Icons.videocam_outlined,
                              tooltip: l10n.videoCallAction,
                              onTap: () => startAvCall(
                                  context, controller.conversation,
                                  audioOnly: false),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        // 内联图片行可能超出输入区视口(如粘贴后拖矮输入栏),
                        // 裁掉溢出绘制,防止盖住上方工具条
                        child: ClipRect(
                          child: LayoutBuilder(
                            // 微信交互:粘贴的图片按原始尺寸内联显示,最大不超过可见输入区,
                            // 粘贴后不出现滚动条。拖拽输入栏改变视口约束时 LayoutBuilder
                            // 重跑,TextField 随之重建 span,图片高度上限实时跟随。
                            builder: (context, constraints) {
                              // 48 = 图片行超出图片本身的部分(WidgetSpan 内边距 + 基线下
                              // 行距,随字体约 15~20)+ 视觉余量,保证整行落在视口内
                              controller.textEditingController
                                      .inlineImageMaxHeight =
                                  (constraints.maxHeight - 48)
                                      .clamp(40.0, 456.0)
                                      .toDouble();
                              return Focus(
                                onKeyEvent: (node, event) =>
                                    _handleKeyEvent(node, event, controller),
                                child: TextField(
                                  key: _textFieldKey,
                                  controller: controller.textEditingController,
                                  focusNode: controller.focusNode,
                                  onChanged: controller.onTextChanged,
                                  maxLines: null,
                                  expands: true,
                                  // 本引擎的默认 strut 会强制行高:内联图片/大字号都撑不开
                                  // 行框,超高部分溢出绘制盖住其他行,必须禁用。
                                  // 回归用例见 test/inline_image_input_test.dart
                                  strutStyle: StrutStyle.disabled,
                                  textAlignVertical: TextAlignVertical.top,
                                  keyboardType: TextInputType.multiline,
                                  style: AppText.base.copyWith(
                                      height: 1.5,
                                      color: context.colors.textPrimary),
                                  decoration: InputDecoration(
                                    isCollapsed: true,
                                    border: InputBorder.none,
                                    hintText: l10n.enterToSendHint,
                                    hintStyle: AppText.base.copyWith(
                                        color: context.colors.textTertiary),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    if (controller.hasQuote)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: _QuoteChip(controller: controller),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatefulWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final String tooltip;
  final VoidCallback onTap;

  const _ToolbarButton({
    super.key,
    this.icon,
    this.iconWidget,
    required this.tooltip,
    required this.onTap,
  }) : assert(icon != null || iconWidget != null);

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
              color:
                  _hovered ? context.colors.hoverOverlay : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: widget.iconWidget ??
                Icon(widget.icon!,
                    size: 21, color: context.colors.iconSecondary),
          ),
        ),
      ),
    );
  }
}

/// 截图按钮的紧贴下拉箭头(对齐微信 PC:剪刀图标右侧的小箭头)。
/// 宽度只有 16,比工具栏按钮(30)窄,视觉上属于截图按钮的一部分。
class _ScreenshotMenuArrow extends StatefulWidget {
  /// true = 隐藏窗口截图;false = 普通截图。
  final ValueChanged<bool> onSelected;

  const _ScreenshotMenuArrow({required this.onSelected});

  @override
  State<_ScreenshotMenuArrow> createState() => _ScreenshotMenuArrowState();
}

class _ScreenshotMenuArrowState extends State<_ScreenshotMenuArrow> {
  bool _hovered = false;

  void _showMenu(BuildContext context, Offset globalPosition) {
    final l10n = AppLocalizations.of(context)!;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final localPosition = overlayBox.globalToLocal(globalPosition);
    showMenu<bool>(
      context: context,
      position: RelativeRect.fromLTRB(localPosition.dx, localPosition.dy,
          localPosition.dx, localPosition.dy),
      items: [
        PopupMenuItem(
            value: false, height: 34, child: Text(l10n.screenshotTool)),
        PopupMenuItem(
            value: true, height: 34, child: Text(l10n.screenshotHideWindow)),
      ],
    ).then((value) {
      if (value != null) {
        widget.onSelected(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => _showMenu(context, details.globalPosition),
        child: Container(
          width: 16,
          height: 30,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: _hovered ? context.colors.hoverOverlay : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(Icons.arrow_drop_down,
              size: 14, color: context.colors.iconSecondary),
        ),
      ),
    );
  }
}

/// 引用消息条:摘要 + 缩略图(图片/视频)+ 取消按钮,显示在输入区上方。
class _QuoteChip extends StatelessWidget {
  final MessageInputBarController controller;

  const _QuoteChip({required this.controller});

  @override
  Widget build(BuildContext context) {
    final quoteInfo = controller.quoteInfo;
    final quotedMessage = controller.quotedMessage;
    Widget? thumbnail;
    String digest = '';
    if (quotedMessage != null) {
      // digest 在设置引用时已由 QuoteInfo.fromMessage 异步计算好，直接复用。
      digest = quoteInfo?.messageDigest ?? '';
      final content = quotedMessage.content;
      if (content is ImageMessageContent && content.thumbnail != null) {
        thumbnail = ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Image.memory(content.thumbnail!,
              width: 24, height: 24, fit: BoxFit.cover),
        );
      } else if (content is VideoMessageContent && content.thumbnail != null) {
        thumbnail = ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Image.memory(content.thumbnail!,
              width: 24, height: 24, fit: BoxFit.cover),
        );
      }
    } else if (quoteInfo != null) {
      digest = quoteInfo.messageDigest ?? '';
    }

    final colors = context.colors;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: colors.inputBg,
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
              // 摘要统一使用 QuoteInfo.fromMessage 预算好的 messageDigest,
              // 避免输入框 controller 每次键入重建时重复执行 digest。
              child: Text(
                digest,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.xs.copyWith(color: colors.textSecondary),
              ),
            ),
            const SizedBox(width: 6),
            HoverBuilder(
              cursor: SystemMouseCursors.click,
              builder: (context, hovered) => GestureDetector(
                onTap: () => controller.setQuotedMessage(null),
                child: Icon(Icons.close,
                    size: 14,
                    color: hovered ? colors.textPrimary : colors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
