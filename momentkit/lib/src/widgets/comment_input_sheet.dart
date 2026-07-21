import 'package:flutter/material.dart';

/// 评论输入面板（底部弹出，适配软键盘）。
///
/// 返回输入的评论文本；用户取消返回 null。
class CommentInputSheet extends StatefulWidget {
  final String? hint;

  const CommentInputSheet({super.key, this.hint});

  static Future<String?> show(BuildContext context, {String? hint}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: CommentInputSheet(hint: hint),
      ),
    );
  }

  @override
  State<CommentInputSheet> createState() => _CommentInputSheetState();
}

class _CommentInputSheetState extends State<CommentInputSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: true,
                maxLines: null,
                minLines: 1,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: widget.hint ?? '评论',
                  counterText: '',
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  filled: true,
                  fillColor: const Color(0xFFF3F3F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                final enabled = value.text.trim().isNotEmpty;
                return FilledButton(
                  onPressed: enabled
                      ? () => Navigator.of(context).pop(value.text.trim())
                      : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text('发送'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
