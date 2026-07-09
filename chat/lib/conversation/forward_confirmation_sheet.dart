import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/message/video_message_content.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/composite_message_content.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/conversation/forward/widgets/conversation_display.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/utils/media_url_redirector.dart';
import 'package:chat/l10n/app_localizations.dart';

class ForwardConfirmationSheet extends StatefulWidget {
  final List<Conversation> targets;
  final List<Message>? messages; // Original messages for preview
  final bool oneByOne;
  final Function(String? comment) onConfirm;

  const ForwardConfirmationSheet({
    super.key,
    required this.targets,
    required this.onConfirm,
    this.messages,
    this.oneByOne = false,
  });

  @override
  State<ForwardConfirmationSheet> createState() => _ForwardConfirmationSheetState();
}

class _MessagePreviewData {
  final String text;
  final Uint8List? thumbnail;
  final bool isVideo;
  final String? remoteImageUrl;

  const _MessagePreviewData({
    required this.text,
    this.thumbnail,
    this.isVideo = false,
    this.remoteImageUrl,
  });
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
                decoration: BoxDecoration(
                  color: context.colors.popupBg,
                  borderRadius: const BorderRadius.only(
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
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          AppLocalizations.of(context)!.sendTo,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.colors.textPrimary),
                        ),
                      ),
                      _buildTargetsList(),
                      _buildMessagePreview(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: TextField(
                          controller: _commentController,
                          style: TextStyle(color: context.colors.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.leaveMessage,
                            hintStyle: TextStyle(color: context.colors.textSecondary, fontSize: 14),
                            filled: true,
                            fillColor: context.colors.inputBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      Divider(
                        color: context.colors.hairlineSoft,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(AppLocalizations.of(context)!.cancel, style: TextStyle(color: context.colors.textSecondary, fontSize: 16)),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onConfirm(_commentController.text.isEmpty ? null : _commentController.text);
                            },
                            child: Text(AppLocalizations.of(context)!.send, style: TextStyle(color: context.colors.accent, fontSize: 16, fontWeight: FontWeight.bold)),
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
        separatorBuilder: (_, __) => Divider(
          height: 0.4,
          indent: 68,
          color: context.colors.hairlineSoft,
        ),
        itemBuilder: (context, index) {
          return _buildSingleTarget(widget.targets[index]);
        },
      ),
    );
  }

  Widget _buildSingleTarget(Conversation conversation) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ConversationDisplay(
        conversation: conversation,
        builder: (context, info) => Row(
          children: [
            Portrait(info.portrait, info.defaultPortrait, width: 40, height: 40, borderRadius: 4.0),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                info.title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: context.colors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagePreview() {
    if (widget.messages == null || widget.messages!.isEmpty) {
      return const SizedBox.shrink();
    } else {
      return FutureBuilder<_MessagePreviewData>(
        future: _loadPreviewData(),
        builder: (context, snap) {
          final preview = snap.data ?? _MessagePreviewData(text: AppLocalizations.of(context)!.messageTag);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            decoration: BoxDecoration(
              color: context.colors.inputBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (preview.thumbnail != null || preview.remoteImageUrl != null) _buildThumbnailWidget(preview),
                if (preview.thumbnail != null || preview.remoteImageUrl != null) const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    preview.text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.colors.textSecondary, fontSize: 14),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
  }

  Future<_MessagePreviewData> _loadPreviewData() async {
    final messages = widget.messages!;
    if (messages.length == 1) {
      final message = messages.first;
      final text = await message.content.digest(message);
      return _MessagePreviewData(
        text: text,
        thumbnail: _extractThumbnail(message.content),
        isVideo: message.content is VideoMessageContent,
        remoteImageUrl: _resolveRemoteImageUrl(message.content),
      );
    }

    String previewText = '${widget.oneByOne? '[${AppLocalizations.of(context)!.forwardOneByOne}]' : '[${AppLocalizations.of(context)!.forwardCombined}]'} ${AppLocalizations.of(context)!.totalMessages(messages.length.toString())}';
    if (messages.first.content is CompositeMessageContent) {
      previewText = '[${AppLocalizations.of(context)!.chatHistory}]';
    }

    final firstContent = messages.first.content;
    return _MessagePreviewData(
      text: previewText,
      thumbnail: _extractThumbnail(firstContent),
      isVideo: firstContent is VideoMessageContent,
      remoteImageUrl: _resolveRemoteImageUrl(firstContent),
    );
  }

  Uint8List? _extractThumbnail(MessageContent content) {
    if (content is ImageMessageContent) {
      return content.thumbnail;
    }
    if (content is VideoMessageContent) {
      return content.thumbnail;
    }
    return null;
  }

  String? _resolveRemoteImageUrl(MessageContent content) {
    if (content is ImageMessageContent) {
      return content.remoteUrl;
    }
    return null;
  }

  Widget _buildThumbnailWidget(_MessagePreviewData preview) {
    Widget? baseImage;
    if (preview.thumbnail != null) {
      baseImage = Image.memory(
        preview.thumbnail!,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
      );
    } else if (preview.remoteImageUrl != null) {
      baseImage = Image.network(
        MediaUrlRedirector.redirect(preview.remoteImageUrl!),
        width: 64,
        height: 64,
        fit: BoxFit.cover,
      );
    }

    if (baseImage == null) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 64,
        height: 64,
        child: Stack(
          fit: StackFit.expand,
          children: [
            baseImage,
            if (preview.isVideo)
              Container(
                color: Colors.black26,
                child: const Center(
                  child: Icon(Icons.play_circle_outline, color: Colors.white, size: 28),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
