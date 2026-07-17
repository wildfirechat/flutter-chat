import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:chat/conversation/conversation_controller.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:imclient/message/video_message_content.dart';
import 'package:chat/conversation/cell_builder/portrait_cell_builder.dart';
import 'package:chat/widgets/rich_text_message.dart';
import 'package:chat/pc/media_preview_window/media_preview_window_manager.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/utilities.dart';
import 'package:characters/characters.dart';
import 'package:chat/widgets/animated_emoji.dart';
import 'package:chat/conversation/input_bar/emoji_board.dart';
import 'package:provider/provider.dart';
import 'package:chat/viewmodel/conversation_view_model.dart';

import '../../ui_model/ui_message.dart';
import '../mm_preview_view.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';

class TextCellBuilder extends PortraitCellBuilder {
  late TextMessageContent textMessageContent;

  TextCellBuilder(BuildContext context, UIMessage model) : super(context, model) {
    textMessageContent = model.message.content as TextMessageContent;
  }

  /// 让正文支持部分选择:桌面端鼠标拖选,移动端双击选词/双击拖动扩选。
  /// 选区实时上报给 controller,长按菜单里的"复制"据此只复制选中部分。
  Widget _selectableText(BuildContext context, Widget textChild) {
    return _SelectableMessageText(
      messageId: model.message.messageId,
      controller: conversationController,
      onLongPressStart: (details) => conversationController?.onLongPressedCell(context, model, bubbleRect),
      onSecondaryTapUp: (details) =>
          conversationController?.onLongPressedCell(context, model, Rect.fromCenter(center: details.globalPosition, width: 4, height: 4)),
      child: textChild,
    );
  }

  @override
  Widget buildMessageContent(BuildContext context) {
    final Widget child;
    if (textMessageContent.quoteInfo != null) {
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
         _selectableText(context, Text(
            textMessageContent.text,
            overflow: TextOverflow.ellipsis,
            maxLines: 3,
          )),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              var messageUid = textMessageContent.quoteInfo!.messageUid;
              var message = await Imclient.getMessageByUid(messageUid);
              if (message != null) {
                if (message.content is ImageMessageContent || message.content is VideoMessageContent) {
                  if (context.mounted) {
                    if (isDesktopShell) {
                      // 参考微信:引用的图片/视频在独立窗口中预览(单条,不翻页)
                      MediaPreviewWindowManager.instance.show(
                        mediaItems: [message],
                        defaultIndex: 0,
                      );
                    } else {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          opaque: false,
                          pageBuilder: (context, animation, secondaryAnimation) => MMPreviewView(
                            [message],
                            defaultIndex: 0,
                            pageToEnd: (fromIndex, tail) {},
                          ),
                        ),
                      );
                    }
                  }
                } else {
                  var digest = await message.content.digest(message);
                  Fluttertoast.showToast(msg: digest);
                }
              } else {
                Fluttertoast.showToast(msg: "消息不存在");
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.colors.bubbleQuoted,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "${textMessageContent.quoteInfo!.userDisplayName ?? ''}: ${textMessageContent.quoteInfo!.messageDigest ?? ''}",
                style: AppText.xs.copyWith(color: context.colors.bubbleQuotedText),
              ),
            ),
          )
        ],
      );
    } else {
      final text = textMessageContent.text.trim();
      final charList = text.characters;
      final bool isSingleEmoji = charList.length == 1 && kChatEmojis.contains(charList.first);

      final conversationViewModel = Provider.of<ConversationViewModel>(context, listen: false);
      final messageList = conversationViewModel.conversationMessageList;
      final bool isLastMessage = messageList.isNotEmpty && messageList.first.message.messageId == model.message.messageId;

      final onSolidAccent = isSendMessage && Theme.of(context).brightness == Brightness.dark;
      child = _selectableText(
        context,
        RichTextMessageWidget(
          text: textMessageContent.text,
          style: AppText.lg,
          linkStyle: AppText.lg.copyWith(color: onSolidAccent ? context.colors.bubbleSentText : context.colors.link, decoration: TextDecoration.underline),
          onLinkTap: (url) => Utilities.openLink(context, url),
          isSingleEmoji: isSingleEmoji && !isDesktopShell,
          isLastMessage: isLastMessage,
        ),
      );
    }

    if (isDesktopShell) {
      return LayoutBuilder(
        builder: (context, constraints) => ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth - 60),
          child: child,
        ),
      );
    }
    return child;
  }

}

/// 正文的可选择包装:
/// - SelectionArea 提供选择能力,选区实时上报 controller;
/// - 焦点节点不参与焦点(canRequestFocus:false),这样弹菜单(showMenu 会抢焦点)时
///   SelectableRegion 不会因失焦清空选区,菜单显示期间保持选中高亮。
///   代价是气泡选区不响应 Cmd/Ctrl+C(复制走消息菜单),且跨消息的高亮清理
///   不再有失焦兜底,由 controller 通过 clearHighlight 回调协调;
/// - 内层手势比 SelectionArea 的识别器更深,在手势竞技场中优先胜出,
///   长按/右键仍弹消息菜单,而不是被 SelectionArea 拿去选词/弹系统菜单。
class _SelectableMessageText extends StatefulWidget {
  const _SelectableMessageText({
    required this.messageId,
    required this.controller,
    required this.onLongPressStart,
    required this.onSecondaryTapUp,
    required this.child,
  });

  final int messageId;
  final ConversationController? controller;
  final GestureLongPressStartCallback onLongPressStart;
  final GestureTapUpCallback onSecondaryTapUp;
  final Widget child;

  @override
  State<_SelectableMessageText> createState() => _SelectableMessageTextState();
}

class _SelectableMessageTextState extends State<_SelectableMessageText> {
  final GlobalKey<SelectionAreaState> _selectionAreaKey = GlobalKey<SelectionAreaState>();
  late final FocusNode _focusNode = FocusNode(canRequestFocus: false, skipTraversal: true);

  void _clearHighlight() {
    _selectionAreaKey.currentState?.selectableRegion.clearSelection();
  }

  @override
  void dispose() {
    // cell 滚出列表被回收时选区随 State 一起消失,同步解除 controller 的登记,
    // 避免 clearHighlight 回调指向已销毁的 State
    widget.controller?.detachTextSelection(widget.messageId);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      key: _selectionAreaKey,
      focusNode: _focusNode,
      onSelectionChanged: (content) =>
          widget.controller?.setTextSelection(widget.messageId, content?.plainText, clearHighlight: _clearHighlight),
      child: RawGestureDetector(
        gestures: {
          LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
            () => LongPressGestureRecognizer(debugOwner: this),
            (instance) => instance.onLongPressStart = widget.onLongPressStart,
          ),
          _EagerSecondaryTapRecognizer: GestureRecognizerFactoryWithHandlers<_EagerSecondaryTapRecognizer>(
            () => _EagerSecondaryTapRecognizer(debugOwner: this),
            (instance) => instance.onSecondaryTapUp = widget.onSecondaryTapUp,
          ),
        },
        child: widget.child,
      ),
    );
  }
}

/// 右键按下即宣告胜出的识别器。
/// SelectableRegion 的右键识别器(TapGestureRecognizer.onSecondaryTapDown)会在
/// 100ms deadline 时提前回调——即使它最终输掉竞技场,"选中点击处单词"的副作用
/// 也已经发生。在 pointer down 时立即 resolve,让它在 deadline 前出局,
/// 右键就不会再改动选区。
class _EagerSecondaryTapRecognizer extends OneSequenceGestureRecognizer {
  _EagerSecondaryTapRecognizer({super.debugOwner});

  GestureTapUpCallback? onSecondaryTapUp;

  @override
  bool isPointerAllowed(PointerDownEvent event) => event.buttons == kSecondaryButton && onSecondaryTapUp != null;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent) {
      onSecondaryTapUp?.call(TapUpDetails(
        kind: event.kind,
        globalPosition: event.position,
        localPosition: event.localPosition,
      ));
      stopTrackingPointer(event.pointer);
    } else if (event is PointerCancelEvent) {
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'eager secondary tap';
}
