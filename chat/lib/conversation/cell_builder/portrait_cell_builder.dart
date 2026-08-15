import 'package:flutter/material.dart';
import 'package:imclient/message/articles_message_content.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/sound_message_content.dart';
import 'package:imclient/message/sticker_message_content.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:imclient/message/video_message_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/conversation/conversation_controller.dart';
import 'package:chat/conversation/read_receipt_status_widget.dart';
import 'package:chat/pc/pc_user_card.dart';
import 'package:chat/viewmodel/conversation_view_model.dart';
import 'package:chat/viewmodel/user_view_model.dart';
import 'package:chat/widgets/selectable_message_text.dart';

import '../../config.dart';
import '../../ui_model/ui_message.dart';
import '../../utils/mesh_user_name.dart';
import '../../widget/portrait.dart';
import '../quoted_message_line.dart';
import 'bubble_tail_border.dart';
import 'message_cell_builder.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/app_shell.dart';

abstract class PortraitCellBuilder extends MessageCellBuilder {
  late bool isSendMessage;
  ConversationController? conversationController;

  PortraitCellBuilder(BuildContext context, UIMessage model)
      : super(context, model) {
    try {
      conversationController =
          Provider.of<ConversationController>(context, listen: false);
    } catch (e) {}
    isSendMessage =
        model.message.direction == MessageDirection.MessageDirection_Send;
  }

  @override
  Widget buildContent(BuildContext context) {
    return Selector2<UserViewModel, ConversationViewModel,
            (UserInfo? senderUserInfo, bool showGroupMemberName)>(
        builder: (_, rec, __) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                isSendMessage ? _padding() : _portrait(context, rec.$1),
                _messageContentContainer(context, rec.$1, rec.$2),
                isSendMessage ? _portrait(context, rec.$1) : _padding()
              ],
            ),
        selector: (context, userViewModel, conversationViewModel) => (
              userViewModel.getUserInfo(model.message.fromUser,
                  groupId: model.message.conversation.conversationType ==
                          ConversationType.Group
                      ? model.message.conversation.target
                      : null),
              conversationViewModel.isHiddenConversationMemberName
            ));
  }

  final GlobalKey _portraitKey = GlobalKey();

  Widget _portrait(BuildContext context, UserInfo? userInfo) {
    var portrait = userInfo?.portrait ?? Config.defaultUserPortrait;
    return GestureDetector(
      child: Container(
          key: _portraitKey,
          margin: AppShell.isDesktopStyle
              ? EdgeInsets.fromLTRB(
                  isSendMessage ? 8 : 12, 0, isSendMessage ? 12 : 8, 0)
              : const EdgeInsets.fromLTRB(8, 0, 8, 0),
          child: Portrait(portrait, Config.defaultUserPortrait,
              width: 44.0, height: 44.0, borderRadius: 6.0)),
      // 桌面端点头像弹用户信息卡片(微信 PC 形态),移动端仍整页打开
      onTap: () => AppShell.isDesktopStyle
          ? _showUserCard(context)
          : conversationController?.onPortraitTaped(context, model),
      onLongPress: () =>
          conversationController?.onPortraitLongTaped(context, model),
      onSecondaryTapUp: (details) {
        if (!isSendMessage &&
            AppShell.isPointerInput &&
            model.message.conversation.conversationType ==
                ConversationType.Group) {
          conversationController?.onPortraitSecondaryTaped(
              context, model, details.globalPosition);
        }
      },
    );
  }

  void _showUserCard(BuildContext context) {
    final renderBox =
        _portraitKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return;
    }
    final anchor = renderBox.localToGlobal(Offset.zero) & renderBox.size;
    showPcUserCard(
      context: context,
      anchor: anchor,
      userId: model.message.fromUser,
      groupId:
          model.message.conversation.conversationType == ConversationType.Group
              ? model.message.conversation.target
              : null,
    );
  }

  Widget _padding() {
    return SizedBox.fromSize(
      size: const Size(68, 60),
    );
  }

  /// 气泡是否画指向头像的小尾巴。
  ///
  /// 只有正文直接铺在气泡底色上的消息适合带尾巴(文本、流式文本);
  /// 图片/视频/表情/图文这类整块卡片自带底色和圆角,带尾巴会显得突兀,
  /// 所以默认关闭,由子类按需打开。
  @protected
  bool get hasBubbleTail => false;

  final GlobalKey _bubbleKey = GlobalKey();

  /// 气泡在窗口中的全局矩形,供子类(如文本 cell 内层手势)弹消息菜单时定位
  Rect? get bubbleRect {
    final renderBox =
        _bubbleKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return null;
    }
    return renderBox.localToGlobal(Offset.zero) & renderBox.size;
  }

  /// 桌面端气泡最宽只到内容区宽度减去这一档,给对侧留白,长文本不顶到另一边。
  /// 正文类气泡(文本、流式文本)共用一个数,免得各自漂移出不同的行宽。
  static const double desktopBubbleInset = 120;

  /// 给正文类气泡套上桌面端的最大宽度;移动端由外层 Flexible 收着,原样返回。
  @protected
  Widget constrainBubbleWidth(Widget child) {
    if (!AppShell.isDesktopStyle) {
      return child;
    }
    return LayoutBuilder(
      builder: (context, constraints) => ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: constraints.maxWidth - desktopBubbleInset),
        child: child,
      ),
    );
  }

  /// 让正文支持部分选择:桌面端鼠标拖选,移动端长按全选后拖手柄调整范围。
  /// 选区实时上报给 controller,菜单里的"复制"据此只复制选中部分。
  /// 文本消息和流式消息共用,包装内的长按/右键仍是本条消息的菜单。
  @protected
  Widget selectableText(BuildContext context, Widget textChild) {
    final controller = conversationController;
    return SelectableMessageText(
      selectionKey: ConversationController.selectionKeyOf(model.message),
      controller: controller,
      onLongPressStart: (details) =>
          controller?.onLongPressedCell(context, model, bubbleRect),
      onSecondaryTapUp: (details) => controller?.onLongPressedCell(
          context,
          model,
          Rect.fromCenter(center: details.globalPosition, width: 4, height: 4)),
      menuItemsBuilder: controller == null
          ? null
          : (partialSelection) => controller.buildMessageMenuItems(
              context, model,
              partialSelection: partialSelection),
      onMenuItemTap: controller == null
          ? null
          : (value, selectedText) => controller.handleMessageMenuAction(
              context, value, model,
              selectedText: selectedText),
      child: textChild,
    );
  }

  Widget _messageContentContainer(BuildContext context,
      UserInfo? senderUserInfo, bool isHiddenGroupMemberName) {
    return Flexible(
      child: Column(
        crossAxisAlignment:
            isSendMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          (AppShell.isDesktopStyle
                  ? !isSendMessage && !isHiddenGroupMemberName
                  : !isHiddenGroupMemberName)
              ? senderUserInfo != null
                  ? MeshUserName(
                      senderUserInfo,
                      style: AppShell.isDesktopStyle
                          ? AppText.xs
                              .copyWith(color: context.colors.messageSenderName)
                          : null,
                    )
                  : Text(
                      '<${model.message.fromUser}>',
                      style: AppShell.isDesktopStyle
                          ? AppText.xs
                              .copyWith(color: context.colors.messageSenderName)
                          : null,
                    )
              : Container(),
          Row(
            mainAxisAlignment:
                isSendMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _sendStatus(),
              Flexible(
                fit: FlexFit.loose,
                child: GestureDetector(
                  onTap: () =>
                      conversationController?.onTapedCell(context, model),
                  // 不注册 onDoubleTap(原实现是空操作):注册了会参与手势竞技场,
                  // 干扰文本消息 SelectionArea 的双击选词,还会给单击引入等待延迟。
                  // 桌面端同样不注册长按:鼠标按住不动超过 500ms 再拖时长按会抢赢竞技场,
                  // 连带把 SelectableRegion 的鼠标识别器判负(其 onCancel 会清空选区),
                  // 正文就选不中了。PC 端菜单走右键(下面的 onSecondaryTapUp)。
                  onLongPressStart: AppShell.isPointerInput
                      ? null
                      : (details) {
                          conversationController?.onLongPressedCell(
                              context, model, bubbleRect);
                        },
                  // 桌面端右键在鼠标位置弹出同一套消息菜单
                  onSecondaryTapUp: (details) {
                    conversationController?.onLongPressedCell(
                        context,
                        model,
                        Rect.fromCenter(
                            center: details.globalPosition,
                            width: 4,
                            height: 4));
                  },
                  child: Container(
                    key: _bubbleKey,
                    constraints: const BoxConstraints(minHeight: 44.0),
                    // 图片/视频/表情/图文都是整块卡片,自带底色和圆角,气泡不再加内边距
                    padding: (model.message.content is ImageMessageContent ||
                            model.message.content is VideoMessageContent ||
                            model.message.content is StickerMessageContent ||
                            model.message.content is ArticlesMessageContent)
                        ? const EdgeInsets.all(0)
                        : const EdgeInsets.all(8),
                    decoration: ShapeDecoration(
                      // 高亮时直接改消息内容 view 的背景色(原气泡色 + 高亮色叠加),而不是染外层。
                      color: () {
                        final baseColor = isSendMessage
                            ? (AppShell.isDesktopStyle
                                ? context.colors.bubbleSentDesktop
                                : context.colors.bubbleSent)
                            : (AppShell.isDesktopStyle
                                ? context.colors.bubbleReceivedDesktop
                                : context.colors.bubbleReceived);
                        return model.highlighted
                            ? Color.alphaBlend(
                                context.colors.messageHighlight, baseColor)
                            : baseColor;
                      }(),
                      // 带尾巴的气泡靠 shape 的 dimensions 自动给正文让出尾巴宽度,
                      // 上面的 padding 不用区分有没有尾巴。
                      shape: hasBubbleTail
                          ? BubbleTailBorder(tailOnRight: isSendMessage)
                          : const RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                            ),
                    ),
                    // 气泡内的正文色在这里一次性定死,而不是每个 cell_builder 各写一遍:
                    // 暗色下己方气泡是实心蓝,继承主题的灰白正文色对比度不够,必须走纯白。
                    child: Align(
                      alignment: isSendMessage
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      widthFactor: 1.0,
                      heightFactor: 1.0,
                      child: DefaultTextStyle.merge(
                        style: TextStyle(
                          color: isSendMessage
                              ? context.colors.bubbleSentText
                              : context.colors.bubbleReceivedText,
                        ),
                        child: buildMessageContent(context),
                      ),
                    ),
                  ),
                ),
              ),
              _playStatus(context),
            ],
          ),
          _quotedMessage(context),
          Container(
            padding: const EdgeInsets.only(bottom: 3),
          )
        ],
      ),
    );
  }

  /// 被引用的消息挂在气泡下面(参考微信),不进气泡:引用是这条消息的附注,
  /// 不该跟着气泡底色走,也不该把气泡撑宽。目前只有文本消息能带引用。
  Widget _quotedMessage(BuildContext context) {
    final content = model.message.content;
    final quoteInfo = content is TextMessageContent ? content.quoteInfo : null;
    if (quoteInfo == null) {
      return const SizedBox.shrink();
    }
    // 带尾巴的气泡在靠头像那一侧多占了尾巴的宽度,引用行要跟气泡本体对齐
    final double tailInset =
        hasBubbleTail ? BubbleTailBorder.defaultTailWidth : 0;
    return LayoutBuilder(builder: (context, constraints) {
      return Padding(
        padding: EdgeInsets.only(
          top: 4,
          left: isSendMessage ? 0 : tailInset,
          right: isSendMessage ? tailInset : 0,
        ),
        child: ConstrainedBox(
          // 行宽和气泡同一个上限,再长的摘要按两行省略
          constraints: BoxConstraints(
            maxWidth: (AppShell.isDesktopStyle
                    ? constraints.maxWidth - desktopBubbleInset
                    : constraints.maxWidth) -
                tailInset,
          ),
          child: QuotedMessageLine(
            quoteInfo: quoteInfo,
            isSendMessage: isSendMessage,
            // 单聊里被引用的必然是这两个人之一,不必再显示发送者
            showSender: model.message.conversation.conversationType !=
                ConversationType.Single,
            onLongPress: AppShell.isPointerInput
                ? null
                : (details) => conversationController?.onLongPressedCell(
                    context, model, bubbleRect),
            onSecondaryTapUp: (details) =>
                conversationController?.onLongPressedCell(
                    context,
                    model,
                    Rect.fromCenter(
                        center: details.globalPosition, width: 4, height: 4)),
          ),
        ),
      );
    });
  }

  Widget _sendStatus() {
    if (model.message.direction == MessageDirection.MessageDirection_Send) {
      if (model.message.status == MessageStatus.Message_Status_Sending) {
        return Container(
          margin: const EdgeInsets.all(5),
          width: 10,
          height: 10,
          child: const CircularProgressIndicator(),
        );
      } else if (model.message.status ==
          MessageStatus.Message_Status_Send_Failure) {
        return GestureDetector(
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Image.asset(
              'assets/images/message_send_failure.png',
              width: 20,
              height: 20,
            ),
          ),
          onTap: () => conversationController?.onResendTaped(model),
        );
      } else if (model.message.status == MessageStatus.Message_Status_Sent ||
          model.message.status == MessageStatus.Message_Status_Readed) {
        return ReadReceiptStatusWidget(model.message);
      }
    }

    return Container();
  }

  Widget _playStatus(BuildContext context) {
    if (model.message.content is SoundMessageContent) {
      if (model.message.direction ==
              MessageDirection.MessageDirection_Receive &&
          model.message.status == MessageStatus.Message_Status_Readed) {
        return Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 0, 8),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
              color: context.colors.badge,
              borderRadius: const BorderRadius.all(Radius.circular(8))),
        );
      }
    }
    return Container();
  }

  @override
  Widget buildMessageContent(BuildContext context);
}
