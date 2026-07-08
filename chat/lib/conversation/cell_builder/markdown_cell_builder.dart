import 'package:flutter/material.dart';

import '../../ui_model/ui_message.dart';
import 'portrait_cell_builder.dart';

/// Markdown 消息 Cell Builder
///
/// 渲染 Markdown 格式的消息，支持基本的标题、加粗、斜体、代码、列表等语法
class MarkdownCellBuilder extends PortraitCellBuilder {
  late String text;

  MarkdownCellBuilder(super.context, super.model) {
    text = '';
  }

  @override
  Widget buildMessageContent(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      constraints: BoxConstraints(maxWidth: (screenWidth * 0.8).clamp(200.0, 500.0)),
      padding: const EdgeInsets.all(12),
      child: _SimpleMarkdownRenderer(
        text: text,
        baseStyle: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
      ),
    );
  }
}

/// 简易 Markdown 渲染器
///
/// 支持: **加粗**、*斜体*、`代码`、# 标题、- 列表、> 引用
class _SimpleMarkdownRenderer extends StatelessWidget {
  final String text;
  final TextStyle baseStyle;

  const _SimpleMarkdownRenderer({
    required this.text,
    required this.baseStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    final lines = text.split('\n');
    final List<Widget> widgets = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      // 标题
      if (line.startsWith('### ')) {
        widgets.add(_buildHeading(line.substring(4), 16));
      } else if (line.startsWith('## ')) {
        widgets.add(_buildHeading(line.substring(3), 18));
      } else if (line.startsWith('# ')) {
        widgets.add(_buildHeading(line.substring(2), 20));
      }
      // 引用
      else if (line.startsWith('> ')) {
        widgets.add(_buildQuote(line.substring(2)));
      }
      // 无序列表
      else if (line.startsWith('- ') || line.startsWith('* ')) {
        widgets.add(_buildListItem(line.substring(2)));
      }
      // 有序列表
      else if (RegExp(r'^\d+\. ').hasMatch(line)) {
        final idx = line.indexOf('. ');
        widgets.add(_buildListItem(line.substring(idx + 2)));
      }
      // 代码块开始/结束
      else if (line.startsWith('```')) {
        widgets.add(const SizedBox(height: 4));
      }
      // 普通文本
      else {
        widgets.add(_buildRichText(line));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  Widget _buildHeading(String text, double fontSize) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: _buildRichText(text, style: baseStyle.copyWith(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
      )),
    );
  }

  Widget _buildQuote(String text) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.only(left: 8),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFF576b95), width: 3)),
      ),
      child: _buildRichText(text, style: baseStyle.copyWith(
        color: const Color(0xFF666666),
        fontStyle: FontStyle.italic,
      )),
    );
  }

  Widget _buildListItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Color(0xFF999999))),
          Expanded(child: _buildRichText(text)),
        ],
      ),
    );
  }

  Widget _buildRichText(String text, {TextStyle? style}) {
    final spans = <InlineSpan>[];
    final effectiveStyle = style ?? baseStyle;
    final buffer = StringBuffer();
    int i = 0;

    while (i < text.length) {
      // 加粗 **text**
      if (i + 1 < text.length && text[i] == '*' && text[i + 1] == '*') {
        final end = text.indexOf('**', i + 2);
        if (end > i + 2) {
          if (buffer.isNotEmpty) {
            spans.add(TextSpan(text: buffer.toString()));
            buffer.clear();
          }
          spans.add(TextSpan(
            text: text.substring(i + 2, end),
            style: effectiveStyle.copyWith(fontWeight: FontWeight.bold),
          ));
          i = end + 2;
          continue;
        }
      }
      // 斜体 *text*
      if (i > 0 && text[i] == '*' && text[i - 1] != '*' && (i + 1 < text.length && text[i + 1] != '*')) {
        final end = text.indexOf('*', i + 1);
        if (end > i + 1) {
          if (buffer.isNotEmpty) {
            spans.add(TextSpan(text: buffer.toString()));
            buffer.clear();
          }
          spans.add(TextSpan(
            text: text.substring(i + 1, end),
            style: effectiveStyle.copyWith(fontStyle: FontStyle.italic),
          ));
          i = end + 1;
          continue;
        }
      }
      // 内联代码 `code`
      if (text[i] == '`') {
        final end = text.indexOf('`', i + 1);
        if (end > i + 1) {
          if (buffer.isNotEmpty) {
            spans.add(TextSpan(text: buffer.toString()));
            buffer.clear();
          }
          spans.add(TextSpan(
            text: text.substring(i + 1, end),
            style: effectiveStyle.copyWith(
              fontFamily: 'monospace',
              backgroundColor: const Color(0x20000000),
              fontSize: (effectiveStyle.fontSize ?? 14) - 1,
            ),
          ));
          i = end + 1;
          continue;
        }
      }
      buffer.write(text[i]);
      i++;
    }

    if (spans.isEmpty) {
      return Text(text, style: effectiveStyle);
    }

    if (buffer.isNotEmpty) {
      spans.add(TextSpan(text: buffer.toString()));
    }

    return RichText(
      text: TextSpan(style: effectiveStyle, children: spans),
    );
  }
}
