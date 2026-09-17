import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chat/conversation/input_bar/emoji_board.dart';
import 'package:chat/conversation/input_bar/plugin_board.dart';
import 'package:chat/conversation/input_bar/channel_menu_widget.dart';
import 'package:chat/conversation/input_bar/voice_record/voice_record_button.dart';
import 'package:chat/utils/show_toast.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/video_message_content.dart';
import 'package:chat/theme/app_colors.dart';
import 'input_bar_icon.dart';
import 'message_input_bar_controller.dart';
import 'voice_input_button.dart';
import 'voice_input_controller.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/app_shell.dart';

/// 持久化的键盘高度 key,横竖屏分开存。
///
/// 同一台设备横屏与竖屏的键盘高度差得很多,共用一个值的话旋转之后表情/插件面板
/// 会先按另一个方向的高度弹出来,再被真实键盘高度纠正 —— 平板上尤其明显。
const String _kKeyboardHeightKeyPortrait = 'saved_keyboard_height_portrait';
const String _kKeyboardHeightKeyLandscape = 'saved_keyboard_height_landscape';

/// 旧版本只存一个值、横竖屏共用。升级后新键还是空的,先按它兜底,
/// 这样升级当次的表现与升级前完全一致;在某个方向存过一次之后就用不到了。
const String _kLegacyKeyboardHeightKey = 'saved_keyboard_height';

/// 有无文字时输入栏的形变(加号 ↔ 发送、语音输入按钮收起/展开)共用一条时间线,
/// 两头同时伸缩,中间输入框的宽度变化才是连贯的一段,而不是先后跳两下
const Duration _kMorphDuration = Duration(milliseconds: 200);
const Curve _kMorphCurve = Curves.easeOutCubic;

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

class _MessageInputBarState extends State<MessageInputBar>
    with WidgetsBindingObserver {
  static const List<String> emojis = kChatEmojis;

  /// 输入栏，按住说话的浮层按它的宽度确定操作区
  final GlobalKey _voiceRecordStageKey = GlobalKey();

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

  /// 当前方向对应的存储 key。用 view 的物理尺寸判断,与本文件读键盘高度是同一个源。
  String get _keyboardHeightKey {
    final size =
        WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
    return size.width > size.height
        ? _kKeyboardHeightKeyLandscape
        : _kKeyboardHeightKeyPortrait;
  }

  /// `_savedKeyboardHeight` 当前对应的是哪个方向,用于旋转后判断要不要重读。
  String? _loadedHeightKey;

  Future<void> _loadSavedKeyboardHeight() async {
    final key = _keyboardHeightKey;
    _loadedHeightKey = key;
    final prefs = await SharedPreferences.getInstance();
    final savedHeight =
        prefs.getDouble(key) ?? prefs.getDouble(_kLegacyKeyboardHeightKey) ?? 0;
    if (savedHeight > 0 && mounted && _loadedHeightKey == key) {
      setState(() {
        _savedKeyboardHeight = savedHeight;
      });
    }
  }

  Future<void> _saveKeyboardHeight(double height) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyboardHeightKey, height);
  }

  @override
  void didChangeMetrics() {
    // 旋转也会走到这里:方向变了就把那个方向存过的高度读回来,
    // 否则面板会一直按上一个方向的高度弹。只在 key 真的变了时才读 prefs。
    if (_loadedHeightKey != null && _loadedHeightKey != _keyboardHeightKey) {
      _loadSavedKeyboardHeight();
    }
    final keyboardHeight = WidgetsBinding
            .instance.platformDispatcher.views.first.viewInsets.bottom /
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

    // 检测键盘高度是否稳定
    if (keyboardHeight == _lastKeyboardHeight && keyboardHeight > 0) {
      _keyboardStableCount++;
    } else {
      _keyboardStableCount = 0;
    }

    // 键盘高度稳定时保存（避免动画过程中的中间值）；IO 放在这里而不是 build 中
    if (keyboardHeight > 0 && keyboardHeight == _lastKeyboardHeight) {
      if ((_savedKeyboardHeight - keyboardHeight).abs() > 1) {
        _savedKeyboardHeight = keyboardHeight;
        _saveKeyboardHeight(keyboardHeight);
      }
    }

    // 键盘弹出到目标高度时，结束面板→键盘的过渡
    if (_keepBoardVisible && keyboardHeight > 0) {
      final targetHeight =
          _savedKeyboardHeight > 0 ? _savedKeyboardHeight : _minBoardHeight;
      // 条件1: 键盘高度达到目标高度
      // 条件2: 键盘高度稳定3帧以上（说明键盘已弹出完成，即使高度不同）
      if (keyboardHeight >= targetHeight || _keyboardStableCount >= 3) {
        // 更新保存的高度为实际键盘高度，确保下次过渡平滑
        if (keyboardHeight > 0 &&
            (_savedKeyboardHeight - keyboardHeight).abs() > 1) {
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
    // 逐键输入会 notifyListeners:整体结构只订阅 面板状态/引用态/频道菜单 三类变化,
    // 发送按钮的文本非空态在 _buildInputBar 内单独订阅,避免每个按键重建整个输入栏(含 emoji/插件面板栈)
    return Selector<MessageInputBarController,
        (ChatInputBarStatus, bool, bool)>(
      selector: (context, controller) => (
        controller.status,
        controller.hasQuote,
        controller.channelInfo?.menus?.isNotEmpty ?? false,
      ),
      builder: (context, _, __) {
        final controller =
            Provider.of<MessageInputBarController>(context, listen: false);
        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

        final bool isInBoardMode =
            controller.status == ChatInputBarStatus.emojiStatus ||
                controller.status == ChatInputBarStatus.pluginStatus;

        _lastKeyboardHeight = keyboardHeight;

        final double targetBoardHeight =
            max(_savedKeyboardHeight, _minBoardHeight);

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
        } else if (controller.status != ChatInputBarStatus.keyboardStatus ||
            !controller.focusNode.hasFocus) {
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
        final bool useAnimation = keyboardHeight == 0 &&
            _lastKeyboardHeight == 0 &&
            !_keepBoardVisible;

        // 记录当前显示的面板类型，用于收起动画
        if (isInBoardMode) {
          _animatingBoardStatus = controller.status;
        }

        return Container(
          color: AppShell.isDesktopStyle
              ? context.colors.chatBgDesktop
              : context.colors.chatBg,
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
                        child: showBoard
                            ? _buildBoardsStack(controller, targetBoardHeight)
                            : null,
                      )
                    : Container(
                        height: bottomHeight,
                        child: showBoard
                            ? _buildBoardsStack(controller, targetBoardHeight)
                            : null,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建引用消息组件
  Widget _buildQuoteWidget(MessageInputBarController controller) {
    final quoteInfo = controller.quoteInfo;
    final quotedMessage = controller.quotedMessage;
    Widget? thumbnail;
    String digest = '';

    if (quotedMessage != null) {
      // digest 在设置引用时已由 QuoteInfo.fromMessage 异步计算好，直接复用，
      // 避免在 build 中直接调用 Future.toString() 出现 "Instance of 'Future<String>'"。
      digest = quoteInfo?.messageDigest ?? '';
      final content = quotedMessage.content;
      // 如果是图片消息，显示缩略图
      if (content is ImageMessageContent) {
        if (content.thumbnail != null) {
          thumbnail = ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.memory(content.thumbnail!,
                width: 40, height: 40, fit: BoxFit.cover),
          );
        }
      }
      // 如果是视频消息，显示缩略图
      else if (content is VideoMessageContent) {
        if (content.thumbnail != null) {
          thumbnail = ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.memory(content.thumbnail!,
                width: 40, height: 40, fit: BoxFit.cover),
          );
        }
      }
    } else if (quoteInfo != null) {
      digest = quoteInfo.messageDigest ?? '';
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
            child: Text(
              digest,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  AppText.sm.copyWith(color: context.colors.bubbleQuotedText),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => controller.setQuotedMessage(null),
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close,
                  size: 18, color: context.colors.iconSecondary),
            ),
          ),
        ],
      ),
    );
  }

  /// 切换到按住说话。和 android-chat 一样先申请麦克风权限，按下按钮时就能立即开始录音
  Future<void> _onVoiceButton(MessageInputBarController controller) async {
    final PermissionStatus status = await Permission.microphone.request();
    if (!mounted) {
      return;
    }
    if (status.isGranted) {
      controller.onVoiceButton();
    } else {
      showToast(msg: AppLocalizations.of(context)!.noMicrophonePermission);
    }
  }

  Widget _buildInputBar(MessageInputBarController controller) {
    const double iconSize = 30;
    bool showMenu = controller.channelInfo?.menus != null &&
        controller.channelInfo!.menus!.isNotEmpty;

    return Container(
      key: _voiceRecordStageKey,
      decoration: BoxDecoration(
        color: AppShell.isDesktopStyle
            ? context.colors.chatBgDesktop
            : context.colors.chatBg,
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
                      icon: const InputBarIcon(InputBarGlyph.keyboard,
                          size: iconSize),
                      onPressed: controller.onKeyboardButton)
                  : IconButton(
                      icon: const InputBarIcon(InputBarGlyph.voice,
                          size: iconSize),
                      onPressed: () => _onVoiceButton(controller)),
              if (showMenu)
                IconButton(
                    icon: controller.status == ChatInputBarStatus.menuStatus
                        ? const InputBarIcon(InputBarGlyph.keyboard,
                            size: iconSize)
                        : const InputBarIcon(InputBarGlyph.menu,
                            size: iconSize),
                    onPressed: controller.onMenuButton),
              Expanded(
                child: showMenu &&
                        controller.status == ChatInputBarStatus.menuStatus
                    ? ChannelMenuWidget(
                        menus: controller.channelInfo!.menus!,
                        conversation: controller.conversation)
                    : (controller.status == ChatInputBarStatus.recordStatus
                        ? VoiceRecordButton(
                            inputBar: controller,
                            stageKey: _voiceRecordStageKey)
                        : Padding(
                            padding: const EdgeInsets.fromLTRB(0, 5, 5, 5),
                            child: Column(
                              children: [
                                CupertinoTextField(
                                  maxLines: 3,
                                  minLines: 1,
                                  // 实时语音输入按钮，放在输入框右下角，多行时不跟着居中（android-chat 交互）
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  suffix: VoiceInputController.isAvailable
                                      ? _VoiceInputSuffix(
                                          voiceInput: controller.voiceInput)
                                      : null,
                                  controller: controller.textEditingController,
                                  focusNode: controller.focusNode,
                                  onSubmitted: (_) => controller.onSendButton(),
                                  onChanged: controller.onTextChanged,
                                  style: TextStyle(
                                      color: context.colors.textPrimary),
                                  placeholderStyle: TextStyle(
                                      color: context.colors.textTertiary),
                                  decoration: BoxDecoration(
                                    color: context.colors.surface,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  cursorColor: context.colors.accent,
                                ),
                                if (controller.hasQuote)
                                  Padding(
                                      padding:
                                          const EdgeInsets.fromLTRB(0, 5, 0, 0),
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
                        icon: const InputBarIcon(InputBarGlyph.keyboard,
                            size: iconSize),
                        onPressed: controller.onKeyboardButton)
                    : IconButton(
                        icon: const InputBarIcon(InputBarGlyph.emoji,
                            size: iconSize),
                        onPressed: controller.onEmojiButton),
                // 发送按钮只订阅"是否显示发送",逐键输入不会触发这里以外的重建
                Selector<MessageInputBarController, bool>(
                  selector: (context, controller) =>
                      controller.textEditingController.text.isNotEmpty &&
                      controller.status != ChatInputBarStatus.recordStatus &&
                      controller.status != ChatInputBarStatus.pluginStatus,
                  builder: (context, showSend, _) {
                    final controller = Provider.of<MessageInputBarController>(
                        context,
                        listen: false);
                    return _SendButtonSwitcher(
                      showSend: showSend,
                      // 比全局按钮小一档(微信尺寸);可点区域仍由 padded tapTargetSize 撑到 48
                      sendButton: FilledButton(
                          onPressed: controller.onSendButton,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(52, 30),
                            fixedSize: const Size.fromHeight(30),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: Text(AppLocalizations.of(context)!.send)),
                      pluginButton: IconButton(
                          icon: const InputBarIcon(InputBarGlyph.plugin,
                              size: iconSize),
                          onPressed: controller.onPluginButton),
                    );
                  },
                ),
              ],
              const SizedBox(width: 8.0),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建面板（用于动画，使用记录的面板类型）
  Widget _buildBoardsStackForAnimation(
      MessageInputBarController controller, double height) {
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
              pickerStickerCallback: (stickerPath) =>
                  controller.sendSticker(stickerPath),
              height: height,
            ),
            PluginBoard(controller.conversation, height: height),
          ],
        ),
      ),
    );
  }

  /// 构建面板
  Widget _buildBoardsStack(
      MessageInputBarController controller, double height) {
    // 优先用 _previousBoardStatus 或 _keepBoardVisible 时的面板类型，保证收起动画期间显示正确面板
    ChatInputBarStatus? statusToShow;
    if (_keepBoardVisible && _previousBoardStatus != null) {
      statusToShow = _previousBoardStatus;
    } else if (controller.status == ChatInputBarStatus.emojiStatus ||
        controller.status == ChatInputBarStatus.pluginStatus) {
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
              pickerStickerCallback: (stickerPath) =>
                  controller.sendSticker(stickerPath),
              height: height,
            ),
            PluginBoard(controller.conversation, height: height),
          ],
        ),
      ),
    );
  }
}

/// 行尾的加号 ↔ 发送按钮(同微信):有文字时发送按钮在自己的位置上,从右边缘开始向左展开显示,
/// 占位同步变宽把输入框往左挤,加号原地淡出;清空后发送按钮向右收起,加号淡入。
class _SendButtonSwitcher extends StatelessWidget {
  const _SendButtonSwitcher({
    required this.showSend,
    required this.sendButton,
    required this.pluginButton,
  });

  final bool showSend;
  final Widget sendButton;
  final Widget pluginButton;

  static const ValueKey<bool> _sendKey = ValueKey<bool>(true);

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: _kMorphDuration,
      curve: _kMorphCurve,
      // 右缘贴住行尾不动,宽度只往左边伸缩
      alignment: Alignment.centerRight,
      child: AnimatedSwitcher(
        duration: _kMorphDuration,
        switchInCurve: _kMorphCurve,
        // 退场是把动画倒着播,用翻转曲线,收起的发送按钮才和收窄的占位逐帧同步;
        // 加号则在时间轴上先快后慢,一开始就迅速淡出
        switchOutCurve: _kMorphCurve.flipped,
        transitionBuilder: _buildTransition,
        layoutBuilder: _buildLayout,
        child: KeyedSubtree(
          key: ValueKey<bool>(showSend),
          child: showSend ? sendButton : pluginButton,
        ),
      ),
    );
  }

  static Widget _buildTransition(Widget child, Animation<double> animation) {
    if (child.key == _sendKey) {
      return ClipRect(
        clipper: _RevealFromRightClipper(animation),
        child: child,
      );
    }
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: animation.drive(Tween<double>(begin: 0.8, end: 1)),
        child: child,
      ),
    );
  }

  /// 默认布局按新旧按钮中较大的那个占位,发送 → 加号时宽度要等退场结束才缩回去,
  /// 输入框会慢半拍再跳一下。这里只按新按钮占位,旧按钮以原尺寸右对齐叠在原位退场,不接收点击
  static Widget _buildLayout(Widget? current, List<Widget> previous) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.centerRight,
      children: [
        for (final Widget child in previous)
          Positioned.fill(
            child: IgnorePointer(
              child: OverflowBox(
                minWidth: 0,
                maxWidth: double.infinity,
                minHeight: 0,
                maxHeight: double.infinity,
                alignment: Alignment.centerRight,
                child: child,
              ),
            ),
          ),
        if (current != null) current,
      ],
    );
  }
}

/// 从右边缘向左展开的裁剪区域:进度 0 时宽度为 0,进度 1 时是整个按钮。按钮本身不动也不缩放
class _RevealFromRightClipper extends CustomClipper<Rect> {
  _RevealFromRightClipper(this.progress) : super(reclip: progress);

  final Animation<double> progress;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(
      size.width * (1 - progress.value), 0, size.width, size.height);

  @override
  bool shouldReclip(_RevealFromRightClipper oldClipper) =>
      !identical(oldClipper.progress, progress);
}

/// 输入框右下角的实时语音输入按钮。输入了文字就收起,把宽度让给输入框,右侧换成发送按钮(同微信);
/// 语音输入进行中例外:这时它是停止按钮,识别结果写进输入框也不能收,识别结束后再收起。
class _VoiceInputSuffix extends StatelessWidget {
  const _VoiceInputSuffix({required this.voiceInput});

  final VoiceInputController voiceInput;

  @override
  Widget build(BuildContext context) {
    // 只订阅"文本是否为空",逐键输入不重建
    return Selector<MessageInputBarController, bool>(
      selector: (context, controller) =>
          controller.textEditingController.text.isEmpty,
      builder: (context, isEmpty, button) => ListenableBuilder(
        listenable: voiceInput,
        child: button,
        builder: (context, button) {
          final bool visible =
              isEmpty || voiceInput.state != VoiceInputState.idle;
          return IgnorePointer(
            ignoring: !visible,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: visible ? 1 : 0),
              duration: _kMorphDuration,
              curve: _kMorphCurve,
              child: button,
              // 按钮始终留在树上(图标的录音动画状态不丢),只把占位宽度收到 0;
              // 右缘贴住输入框边缘原地缩小淡出,不裁剪,否则缩到一半图标会被切掉半边
              builder: (context, t, button) => Align(
                alignment: Alignment.centerRight,
                widthFactor: t,
                heightFactor: 1,
                child: Opacity(
                  opacity: t,
                  child: Transform.scale(scale: 0.6 + 0.4 * t, child: button),
                ),
              ),
            ),
          );
        },
      ),
      child: VoiceInputButton(controller: voiceInput),
    );
  }
}
