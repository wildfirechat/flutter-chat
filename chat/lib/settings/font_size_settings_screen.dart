import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/app_theme.dart';

import '../viewmodel/font_size_view_model.dart';

/// 字号设置。上半部分是随字号实时变化的会话预览,下半部分是档位滑块。
///
/// 滑块区域刻意用 [TextScaler.noScaling]:它是调节字号的控件本身,跟着字号一起
/// 放大会让 5 个档位标签在英文下横向溢出,而且用户会失去参照系。
class FontSizeSettingsScreen extends StatelessWidget {
  const FontSizeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.fontSize),
        elevation: 0,
        backgroundColor: AppTheme.chatBackground,
        foregroundColor: Colors.black87,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.done,
              style: const TextStyle(
                color: AppTheme.accent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: AppTheme.chatBackground,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                children: [
                  _buildChatTime('10:00'),
                  const SizedBox(height: 16),
                  _buildLeftMessage(
                    avatarColor: const Color(0xFFE0E0E0),
                    avatarText: 'W',
                    text: l10n.fontSizePreviewIncoming,
                  ),
                  const SizedBox(height: 16),
                  _buildRightMessage(
                    avatarColor: AppTheme.accent,
                    avatarText: 'M',
                    text: l10n.fontSizePreviewOutgoing,
                  ),
                  const SizedBox(height: 16),
                  _buildLeftMessage(
                    avatarColor: const Color(0xFFE0E0E0),
                    avatarText: 'W',
                    text: l10n.fontSizePreviewHint,
                  ),
                ],
              ),
            ),
            MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
              child: const _FontSizeSlider(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatTime(String time) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          time,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildAvatar(Color color, String text) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  Widget _buildBubble(String text, {required bool sent}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: sent ? AppTheme.bubbleSent : AppTheme.bubbleReceived,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(sent ? 8 : 2),
          topRight: Radius.circular(sent ? 2 : 8),
          bottomLeft: const Radius.circular(8),
          bottomRight: const Radius.circular(8),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, color: Colors.black87),
      ),
    );
  }

  Widget _buildLeftMessage({required Color avatarColor, required String avatarText, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAvatar(avatarColor, avatarText),
        const SizedBox(width: 12),
        Flexible(child: _buildBubble(text, sent: false)),
        const SizedBox(width: 40), // 留白,避免气泡顶到对侧边缘
      ],
    );
  }

  Widget _buildRightMessage({required Color avatarColor, required String avatarText, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const SizedBox(width: 40),
        Flexible(child: _buildBubble(text, sent: true)),
        const SizedBox(width: 12),
        _buildAvatar(avatarColor, avatarText),
      ],
    );
  }
}

class _FontSizeSlider extends StatelessWidget {
  const _FontSizeSlider();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labels = [
      l10n.fontSizeSmall,
      l10n.fontSizeNormal,
      l10n.fontSizeMedium,
      l10n.fontSizeLarge,
      l10n.fontSizeExtraLarge,
    ];

    return Consumer<FontSizeViewModel>(
      builder: (context, fontSizeViewModel, child) {
        assert(labels.length == fontSizeViewModel.itemCount, '档位标签数量必须与 FontSizeViewModel 的档位数一致');
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('A', style: TextStyle(fontSize: 14, color: Colors.black54)),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        activeTrackColor: AppTheme.accent,
                        inactiveTrackColor: const Color(0xFFE5E5E5),
                        thumbColor: Colors.white,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0, elevation: 3.0),
                        overlayColor: AppTheme.accent.withValues(alpha: 0.12),
                        activeTickMarkColor: AppTheme.accent,
                        inactiveTickMarkColor: const Color(0xFFCCCCCC),
                        tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2.5),
                      ),
                      child: Slider(
                        value: fontSizeViewModel.index.toDouble(),
                        min: 0,
                        max: (fontSizeViewModel.itemCount - 1).toDouble(),
                        divisions: fontSizeViewModel.itemCount - 1,
                        onChanged: (value) => fontSizeViewModel.setFontSizeIndex(value.round()),
                      ),
                    ),
                  ),
                  const Text('A', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    for (final label in labels)
                      Expanded(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
