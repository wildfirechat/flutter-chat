import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:chat/widgets/animated_emoji.dart';

class RichTextMessageWidget extends StatefulWidget {
  final String text;
  final TextStyle style;
  final TextStyle linkStyle;
  final Function(String url) onLinkTap;
  final bool isSingleEmoji;
  final bool isLastMessage;

  const RichTextMessageWidget({
    super.key,
    required this.text,
    required this.style,
    required this.linkStyle,
    required this.onLinkTap,
    this.isSingleEmoji = false,
    this.isLastMessage = false,
  });

  @override
  State<RichTextMessageWidget> createState() => _RichTextMessageWidgetState();
}

class _RichTextMessageWidgetState extends State<RichTextMessageWidget> {
  final List<TapGestureRecognizer> _recognizers = [];
  late List<InlineSpan> _spans;

  @override
  void initState() {
    super.initState();
    _parseText();
  }

  @override
  void didUpdateWidget(RichTextMessageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text ||
        widget.style != oldWidget.style ||
        widget.linkStyle != oldWidget.linkStyle ||
        widget.isSingleEmoji != oldWidget.isSingleEmoji ||
        widget.isLastMessage != oldWidget.isLastMessage) {
      _disposeRecognizers();
      _parseText();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  void _parseText() {
    _spans = [];
    final text = widget.text;
    if (text.isEmpty) return;

    // Handle single emoji case
    if (widget.isSingleEmoji) {
      final emojiSize = widget.style.fontSize ?? 16.0;
      _spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: AnimatedEmojiWidget(
          emoji: text.trim(),
          size: emojiSize,
          repeat: false,
          animateOnMount: widget.isLastMessage,
        ),
      ));
      return;
    }

    // Regexp matching links
    final pattern = RegExp(
      r'(https?:\/\/[a-zA-Z0-9][-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b[-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
      caseSensitive: false,
    );

    text.splitMapJoin(
      pattern,
      onMatch: (Match match) {
        final matchedText = match.group(0) ?? '';
        final recognizer = TapGestureRecognizer()
          ..onTap = () => widget.onLinkTap(matchedText);
        _recognizers.add(recognizer);

        _spans.add(TextSpan(
          text: matchedText,
          style: widget.linkStyle,
          recognizer: recognizer,
        ));
        return '';
      },
      onNonMatch: (String nonMatch) {
        if (nonMatch.isNotEmpty) {
          _spans.add(TextSpan(
            text: nonMatch,
          ));
        }
        return '';
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: _spans),
      style: widget.style,
    );
  }
}
