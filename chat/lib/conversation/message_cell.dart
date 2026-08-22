import 'package:flutter/material.dart';
import 'package:imclient/message/call_start_message_content.dart';
import 'package:imclient/message/card_message_content.dart';
import 'package:imclient/message/file_message_content.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/notification/notification_message_content.dart';
import 'package:imclient/message/rich_notification_message_content.dart';
import 'package:imclient/message/sound_message_content.dart';
import 'package:imclient/message/streaming_text_generated_message_content.dart';
import 'package:imclient/message/streaming_text_generating_message_content.dart';
import 'package:imclient/message/streaming_text_cancelled_message_content.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:imclient/message/video_message_content.dart';
import 'package:imclient/message/sticker_message_content.dart';
import 'package:imclient/message/collection_message_content.dart';
import 'package:imclient/message/poll_message_content.dart';
import 'package:imclient/message/composite_message_content.dart';
import 'package:imclient/message/articles_message_content.dart';
import 'package:imclient/message/link_message_content.dart';
import 'package:imclient/message/message_content.dart';
import 'package:chat/pc/call_window/raw_voip_message_content.dart';
import 'cell_builder/raw_call_start_cell_builder.dart';
import 'cell_builder/call_start_cell_builder.dart';
import 'cell_builder/card_cell_builder.dart';
import 'cell_builder/file_cell_builder.dart';
import 'cell_builder/image_cell_builder.dart';
import 'cell_builder/link_cell_builder.dart';
import 'cell_builder/message_cell_builder.dart';
import 'cell_builder/notification_cell_builder.dart';
import 'cell_builder/rich_notification_cell_builder.dart';
import 'cell_builder/streaming_text_cell_builder.dart';
import 'cell_builder/streaming_text_cancelled_cell_builder.dart';
import 'cell_builder/text_cell_builder.dart';
import 'cell_builder/unknown_cell_builder.dart';
import 'cell_builder/video_cell_builder.dart';
import 'cell_builder/voice_cell_builder.dart';
import 'cell_builder/sticker_cell_builder.dart';
import 'cell_builder/collection_cell_builder.dart';
import 'cell_builder/poll_cell_builder.dart';
import 'cell_builder/composite_cell_builder.dart';
import 'cell_builder/articles_cell_builder.dart';
import '../ui_model/ui_message.dart';

class MessageCell extends StatefulWidget {
  final UIMessage model;

  MessageCell(this.model) : super(key: cellKeyOf(model));

  /// cell 的身份要按消息本身算,不能用 UIMessage 实例:消息一有更新(送达/已读回执、
  /// 撤回、流式续写)view model 就把列表里那条换成新的 UIMessage 对象。若按实例做 key,
  /// 整棵 cell 会被销毁重建——气泡里正选着的文本选区也跟着没了,表现为"选中保持不住"。
  static Key cellKeyOf(UIMessage model) {
    final content = model.message.content;
    // 流式消息生成期间还没落库,messageId 恒为 0,用 streamId 区分
    if (content is StreamingTextGeneratingMessageContent &&
        content.streamId.isNotEmpty) {
      return ValueKey('stream-${content.streamId}');
    }
    if (model.message.messageId != 0) {
      return ValueKey('msg-${model.message.messageId}');
    }
    // 没有稳定标识时退回实例身份,至少不会和别的 cell 撞 key
    return ObjectKey(model);
  }

  @override
  State<MessageCell> createState() => _MessageCellState();
}

class _MessageCellState extends State<MessageCell>
    with AutomaticKeepAliveClientMixin {
  late MessageCellBuilder _cellBuilder;

  @override
  void initState() {
    super.initState();
    _initCellBuilder();
  }

  @override
  void didUpdateWidget(covariant MessageCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 同一条消息换了 UIMessage 实例:只把 cell builder 换掉(它在构造时抓了 model
    // 和 content 的快照),子树保持原样,选区、播放状态这些 State 才不会被清掉
    if (!identical(oldWidget.model, widget.model)) {
      _cellBuilder.dispose();
      _initCellBuilder();
    }
  }

  void _initCellBuilder() {
    // RichNotificationMessageContent 也是 NotificationMessageContent 的子类,
    // 走自己的卡片样式,必须排在通用通知分支前面
    if (widget.model.message.content is RichNotificationMessageContent) {
      _cellBuilder = RichNotificationCellBuilder(context, widget.model);
    } else if (widget.model.message.content is NotificationMessageContent) {
      _cellBuilder = NotificationCellBuilder(context, widget.model);
    } else if (widget.model.message.content is LinkMessageContent) {
      _cellBuilder = LinkCellBuilder(context, widget.model);
    } else if (widget.model.message.content is TextMessageContent) {
      _cellBuilder = TextCellBuilder(context, widget.model);
    } else if (widget.model.message.content is ImageMessageContent) {
      _cellBuilder = ImageCellBuilder(context, widget.model);
    } else if (widget.model.message.content is StickerMessageContent) {
      _cellBuilder = StickerCellBuilder(context, widget.model);
    } else if (widget.model.message.content is CallStartMessageContent) {
      _cellBuilder = CallStartCellBuilder(context, widget.model);
    } else if (widget.model.message.content is RawVoipMessageContent &&
        (widget.model.message.content as RawVoipMessageContent).meta.type ==
            VOIP_CONTENT_TYPE_START) {
      _cellBuilder = RawCallStartCellBuilder(context, widget.model);
    } else if (widget.model.message.content is SoundMessageContent) {
      _cellBuilder = VoiceCellBuilder(context, widget.model);
    } else if (widget.model.message.content is FileMessageContent) {
      _cellBuilder = FileCellBuilder(context, widget.model);
    } else if (widget.model.message.content is CardMessageContent) {
      _cellBuilder = CardCellBuilder(context, widget.model);
    } else if (widget.model.message.content is VideoMessageContent) {
      _cellBuilder = VideoCellBuilder(context, widget.model);
    } else if (widget.model.message.content
            is StreamingTextGeneratingMessageContent ||
        widget.model.message.content is StreamingTextGeneratedMessageContent) {
      _cellBuilder = StreamingTextCellBuilder(context, widget.model);
    } else if (widget.model.message.content
        is StreamingTextCancelledMessageContent) {
      // 取消消息(20)：不创建气泡，渲染为空（兜底，正常流程下不会进入列表）
      _cellBuilder =
          StreamingTextCancelledCellBuilder(context, widget.model);
    } else if (widget.model.message.content is CompositeMessageContent) {
      _cellBuilder = CompositeCellBuilder(context, widget.model);
    } else if (widget.model.message.content is CollectionMessageContent) {
      _cellBuilder = CollectionCellBuilder(context, widget.model);
    } else if (widget.model.message.content is PollMessageContent) {
      _cellBuilder = PollCellBuilder(context, widget.model);
    } else if (widget.model.message.content is ArticlesMessageContent) {
      _cellBuilder = ArticlesCellBuilder(context, widget.model);
    } else {
      _cellBuilder = UnknownCellBuilder(context, widget.model);
    }
    _cellBuilder.initState(this);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _cellBuilder.build(context);
  }

  @override
  void dispose() {
    super.dispose();
    _cellBuilder.dispose();
  }

  @override
  bool get wantKeepAlive => true;
}
