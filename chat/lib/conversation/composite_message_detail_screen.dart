import 'package:flutter/material.dart';
import 'package:imclient/message/call_start_message_content.dart';
import 'package:imclient/message/card_message_content.dart';
import 'package:imclient/message/composite_message_content.dart';
import 'package:imclient/message/file_message_content.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/notification/notification_message_content.dart';
import 'package:imclient/message/rich_notification_message_content.dart';
import 'package:imclient/message/sound_message_content.dart';
import 'package:imclient/message/streaming_text_generated_message_content.dart';
import 'package:imclient/message/streaming_text_generating_message_content.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:imclient/message/video_message_content.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/config.dart';
import 'package:chat/utils/mesh_user_name.dart';
import 'package:chat/conversation/cell_builder/call_start_cell_builder.dart';
import 'package:chat/conversation/cell_builder/card_cell_builder.dart';
import 'package:chat/conversation/cell_builder/composite_cell_builder.dart';
import 'package:chat/conversation/cell_builder/file_cell_builder.dart';
import 'package:chat/conversation/cell_builder/image_cell_builder.dart';
import 'package:chat/conversation/cell_builder/message_cell_builder.dart';
import 'package:chat/conversation/cell_builder/notification_cell_builder.dart';
import 'package:chat/conversation/cell_builder/rich_notification_cell_builder.dart';
import 'package:chat/conversation/cell_builder/streaming_text_cell_builder.dart';
import 'package:chat/conversation/cell_builder/text_cell_builder.dart';
import 'package:chat/conversation/cell_builder/unknown_cell_builder.dart';
import 'package:chat/conversation/cell_builder/video_cell_builder.dart';
import 'package:chat/conversation/cell_builder/voice_cell_builder.dart';
import 'package:chat/ui_model/ui_message.dart';
import 'package:chat/viewmodel/user_view_model.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/widgets/pc_page_header.dart';
import 'package:chat/theme/app_typography.dart';

class CompositeMessageDetailScreen extends StatefulWidget {
  final CompositeMessageContent content;

  const CompositeMessageDetailScreen(this.content, {Key? key})
      : super(key: key);

  @override
  State<CompositeMessageDetailScreen> createState() =>
      _CompositeMessageDetailScreenState();
}

class _CompositeMessageDetailScreenState
    extends State<CompositeMessageDetailScreen> {
  // cell builder 按消息位置缓存，每条消息只创建一次；
  // 否则 VoiceCellBuilder 等每次 build 都会重复注册 eventBus 订阅且无人释放
  final Map<int, MessageCellBuilder> _cellBuilders = {};

  @override
  void dispose() {
    for (var cellBuilder in _cellBuilders.values) {
      cellBuilder.dispose();
    }
    _cellBuilders.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isDesktopShell
          ? PcPageHeader(
              title: widget.content.title,
              onBack: () => Navigator.of(context).maybePop(),
            )
          : AppBar(title: Text(widget.content.title)),
      body: ListView.builder(
        itemCount: widget.content.messages.length,
        itemBuilder: (context, index) {
          Message message = widget.content.messages[index];
          bool showAvatar = true;
          if (index > 0) {
            Message prev = widget.content.messages[index - 1];
            if (prev.fromUser == message.fromUser) {
              showAvatar = false;
            }
          }

          // Force direction to receive so it looks like left aligned
          message.direction = MessageDirection.MessageDirection_Receive;
          UIMessage uiMessage = UIMessage(message);
          uiMessage.showTimeLabel = true;

          return _buildMessageRow(context, uiMessage, showAvatar, index);
        },
      ),
    );
  }

  Widget _buildMessageRow(
      BuildContext context, UIMessage uiMessage, bool showAvatar, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          showAvatar
              ? Selector<UserViewModel, UserInfo?>(
                  selector: (context, userViewModel) =>
                      userViewModel.getUserInfo(uiMessage.message.fromUser),
                  builder: (context, userInfo, child) {
                    return Portrait(
                      userInfo?.portrait ?? Config.defaultUserPortrait,
                      Config.defaultUserPortrait,
                      width: 44.0,
                      height: 44.0,
                      borderRadius: 6.0,
                    );
                  },
                )
              : const SizedBox(width: 44),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showAvatar)
                  Selector<UserViewModel, UserInfo?>(
                    selector: (context, userViewModel) =>
                        userViewModel.getUserInfo(uiMessage.message.fromUser),
                    builder: (context, userInfo, child) {
                      return userInfo != null
                          ? MeshUserName(
                              userInfo,
                              style: AppText.xs.copyWith(color: Colors.grey),
                            )
                          : Text(
                              "<${uiMessage.message.fromUser}>",
                              style: AppText.xs.copyWith(color: Colors.grey),
                            );
                    },
                  ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(8),
                      topLeft: Radius.circular(8),
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: _buildContent(context, uiMessage, index),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, UIMessage model, int index) {
    // 命中缓存直接复用，避免重复构建 cell builder
    MessageCellBuilder? cellBuilder = _cellBuilders[index];
    if (cellBuilder == null) {
      cellBuilder = _createCellBuilder(context, model);
      _cellBuilders[index] = cellBuilder;
    }
    return cellBuilder.buildMessageContent(context);
  }

  MessageCellBuilder _createCellBuilder(BuildContext context, UIMessage model) {
    MessageCellBuilder cellBuilder;
    // RichNotificationMessageContent 也是 NotificationMessageContent 的子类,
    // 走自己的卡片样式,必须排在通用通知分支前面
    if (model.message.content is RichNotificationMessageContent) {
      cellBuilder = RichNotificationCellBuilder(context, model);
    } else if (model.message.content is NotificationMessageContent) {
      cellBuilder = NotificationCellBuilder(context, model);
    } else if (model.message.content is TextMessageContent) {
      cellBuilder = TextCellBuilder(context, model);
    } else if (model.message.content is ImageMessageContent) {
      cellBuilder = ImageCellBuilder(context, model);
    } else if (model.message.content is CallStartMessageContent) {
      cellBuilder = CallStartCellBuilder(context, model);
    } else if (model.message.content is SoundMessageContent) {
      cellBuilder = VoiceCellBuilder(context, model);
    } else if (model.message.content is FileMessageContent) {
      cellBuilder = FileCellBuilder(context, model);
    } else if (model.message.content is CardMessageContent) {
      cellBuilder = CardCellBuilder(context, model);
    } else if (model.message.content is VideoMessageContent) {
      cellBuilder = VideoCellBuilder(context, model);
    } else if (model.message.content is StreamingTextGeneratingMessageContent ||
        model.message.content is StreamingTextGeneratedMessageContent) {
      cellBuilder = StreamingTextCellBuilder(context, model);
    } else if (model.message.content is CompositeMessageContent) {
      cellBuilder = CompositeCellBuilder(context, model);
    } else {
      cellBuilder = UnknownCellBuilder(context, model);
    }
    return cellBuilder;
  }
}
