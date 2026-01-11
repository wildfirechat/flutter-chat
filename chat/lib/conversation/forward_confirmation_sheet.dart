import 'package:flutter/material.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/conversation_info.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/user_info.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/composite_message_content.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/config.dart';
import 'package:provider/provider.dart';
import 'package:chat/viewmodel/user_view_model.dart';
import 'package:chat/viewmodel/group_view_model.dart';
import 'package:chat/viewmodel/channel_view_model.dart';
import 'package:chat/utilities.dart';

class ForwardConfirmationSheet extends StatefulWidget {
  final List<Conversation> targets;
  final List<Message>? messages; // Original messages for preview
  final Function(String? comment) onConfirm;

  const ForwardConfirmationSheet({
    super.key,
    required this.targets,
    required this.onConfirm,
    this.messages,
  });

  @override
  State<ForwardConfirmationSheet> createState() => _ForwardConfirmationSheetState();
}

class _ForwardConfirmationSheetState extends State<ForwardConfirmationSheet> {
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use Scaffold to handle keyboard resize animation smoothly
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(context),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: () {}, // Prevent tap from closing sheet
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                padding: const EdgeInsets.only(bottom: 20),
                child: SafeArea(
                  top: false, // Don't need top safe area here
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          '发送给：',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      _buildTargetsList(),
                      _buildMessagePreview(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: TextField(
                          controller: _commentController,
                          decoration: InputDecoration(
                            hintText: '给朋友留言',
                            filled: true,
                            fillColor: const Color(0xFFF5F5F5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      const Divider(color: Color(0xFFEBEBEB),),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('取消', style: TextStyle(color: Colors.black, fontSize: 16)),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onConfirm(_commentController.text.isEmpty ? null : _commentController.text);
                            },
                            child: const Text('发送', style: TextStyle(color: Color(0xFF3B62E0), fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetsList() {
    if (widget.targets.length == 1) {
      return _buildSingleTarget(widget.targets.first);
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: widget.targets.length,
        separatorBuilder: (_, __) => const Divider(height: 0.4, indent: 68, color: Colors.white70,),
        itemBuilder: (context, index) {
          return _buildSingleTarget(widget.targets[index]);
        },
      ),
    );
  }

  Widget _buildSingleTarget(Conversation conversation) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildTargetAvatar(conversation),
          const SizedBox(width: 12),
          Expanded(
            child: Selector3<UserViewModel, GroupViewModel, ChannelViewModel, (UserInfo? targetUserInfo, GroupInfo? targetGroupInfo, ChannelInfo? channelInfo)>(
              selector: (context, userViewModel, groupViewModel, channelViewModel) => (
                conversation.conversationType == ConversationType.Single ? userViewModel.getUserInfo(conversation.target) : null,
                conversation.conversationType == ConversationType.Group ? groupViewModel.getGroupInfo(conversation.target) : null,
                conversation.conversationType == ConversationType.Channel ? channelViewModel.getChannelInfo(conversation.target) : null,
              ),
              builder: (context, rec, child) {
                return Text(
                  Utilities.conversationTitle(conversation, rec.$1, rec.$2, rec.$3),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetAvatar(Conversation conversation) {
    return Selector3<UserViewModel, GroupViewModel, ChannelViewModel, (UserInfo? targetUserInfo, GroupInfo? targetGroupInfo, ChannelInfo? channelInfo)>(
      selector: (context, userViewModel, groupViewModel, channelViewModel) => (
        conversation.conversationType == ConversationType.Single ? userViewModel.getUserInfo(conversation.target) : null,
        conversation.conversationType == ConversationType.Group ? groupViewModel.getGroupInfo(conversation.target) : null,
        conversation.conversationType == ConversationType.Channel ? channelViewModel.getChannelInfo(conversation.target) : null,
      ),
      builder: (context, rec, child) {
         String portrait = switch (conversation.conversationType) {
          ConversationType.Single => rec.$1?.portrait ?? Config.defaultUserPortrait,
          ConversationType.Group => rec.$2?.portrait ?? Config.defaultGroupPortrait,
          ConversationType.Channel => rec.$3?.portrait ?? Config.defaultChannelPortrait,
          _ => ''
        };
        var defaultPortrait = conversation.conversationType == ConversationType.Single
            ? Config.defaultUserPortrait
            : conversation.conversationType == ConversationType.Group
                ? Config.defaultGroupPortrait
                : Config.defaultChannelPortrait;
        return Portrait(portrait, defaultPortrait, width: 40, height: 40, borderRadius: 4.0);
      },
    );
  }

  Widget _buildMessagePreview() {
    if (widget.messages == null || widget.messages!.isEmpty) {
      return const SizedBox.shrink();
    }

    String previewText = '';
    if (widget.messages!.length == 1) {
      var msg = widget.messages!.first;
      if (msg.content is TextMessageContent) {
        previewText = (msg.content as TextMessageContent).text ?? '';
      } else if (msg.content is ImageMessageContent) {
        previewText = '[图片]';
      } else {
        previewText = '[消息]';
      }
    } else {
      previewText = '[逐条转发] 共${widget.messages!.length}条消息';
      // Or composite
      if (widget.messages!.first.content is CompositeMessageContent) {
        previewText = '[聊天记录]';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        previewText,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.grey, fontSize: 14),
      ),
    );
  }
}
