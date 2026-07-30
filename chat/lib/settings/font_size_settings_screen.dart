import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chat/l10n/app_localizations.dart';

import '../viewmodel/font_size_view_model.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/widget/app_bar_actions.dart';

/// 字号设置。上半部分是随字号实时变化的会话预览,下半部分是档位滑块。
///
/// 滑块区域刻意用 [TextScaler.noScaling]:它是调节字号的控件本身,跟着字号一起
/// 放大会让 5 个档位标签在英文下横向溢出,而且用户会失去参照系。
class FontSizeSettingsScreen extends StatelessWidget {
  const FontSizeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.fontSize),
        elevation: 0,
        backgroundColor: colors.conversationBg,
        foregroundColor: colors.textPrimary,
        actions: [
          AppBarTextAction(
            label: l10n.done,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      backgroundColor: colors.conversationBg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                children: [
                  _buildChatTime(context, '10:00'),
                  const SizedBox(height: 16),
                  _buildLeftMessage(
                    context,
                    avatarColor: colors.inputBg,
                    avatarText: 'W',
                    text: l10n.fontSizePreviewIncoming,
                  ),
                  const SizedBox(height: 16),
                  _buildRightMessage(
                    context,
                    avatarColor: colors.accent,
                    avatarText: 'M',
                    text: l10n.fontSizePreviewOutgoing,
                  ),
                  const SizedBox(height: 16),
                  _buildLeftMessage(
                    context,
                    avatarColor: colors.inputBg,
                    avatarText: 'W',
                    text: l10n.fontSizePreviewHint,
                  ),
                ],
              ),
            ),
            MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.noScaling),
              child: const _FontSizeSlider(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatTime(BuildContext context, String time) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: context.colors.hoverOverlay,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          time,
          style: AppText.xs.copyWith(color: context.colors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, Color color, String text) {
    return Container(
      width: 40,
      height: 40,
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      alignment: Alignment.center,
      child: Text(
        text,
        style: AppText.lg.copyWith(
            color: context.colors.onAccent, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildBubble(BuildContext context, String text, {required bool sent}) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: sent ? colors.bubbleSent : colors.bubbleReceived,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(sent ? 8 : 2),
          topRight: Radius.circular(sent ? 2 : 8),
          bottomLeft: const Radius.circular(8),
          bottomRight: const Radius.circular(8),
        ),
      ),
      child: Text(
        text,
        style: AppText.lg.copyWith(
            color: sent ? colors.bubbleSentText : colors.bubbleReceivedText),
      ),
    );
  }

  Widget _buildLeftMessage(BuildContext context,
      {required Color avatarColor,
      required String avatarText,
      required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAvatar(context, avatarColor, avatarText),
        const SizedBox(width: 12),
        Flexible(child: _buildBubble(context, text, sent: false)),
        const SizedBox(width: 40), // 留白,避免气泡顶到对侧边缘
      ],
    );
  }

  Widget _buildRightMessage(BuildContext context,
      {required Color avatarColor,
      required String avatarText,
      required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const SizedBox(width: 40),
        Flexible(child: _buildBubble(context, text, sent: true)),
        const SizedBox(width: 12),
        _buildAvatar(context, avatarColor, avatarText),
      ],
    );
  }
}

class _FontSizeSlider extends StatelessWidget {
  const _FontSizeSlider();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final labels = [
      l10n.fontSizeSmall,
      l10n.fontSizeNormal,
      l10n.fontSizeMedium,
      l10n.fontSizeLarge,
      l10n.fontSizeExtraLarge,
    ];

    return Consumer<FontSizeViewModel>(
      builder: (context, fontSizeViewModel, child) {
        assert(labels.length == fontSizeViewModel.itemCount,
            '档位标签数量必须与 FontSizeViewModel 的档位数一致');
        return Container(
          color: colors.surface,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text('A',
                      style:
                          AppText.base.copyWith(color: colors.textSecondary)),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        activeTrackColor: colors.accent,
                        inactiveTrackColor: colors.inputBg,
                        thumbColor: colors.surface,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 10.0, elevation: 3.0),
                        overlayColor: colors.accent.withValues(alpha: 0.12),
                        activeTickMarkColor: colors.accent,
                        inactiveTickMarkColor: colors.textTertiary,
                        tickMarkShape:
                            const RoundSliderTickMarkShape(tickMarkRadius: 2.5),
                      ),
                      child: Slider(
                        value: fontSizeViewModel.index.toDouble(),
                        min: 0,
                        max: (fontSizeViewModel.itemCount - 1).toDouble(),
                        divisions: fontSizeViewModel.itemCount - 1,
                        onChanged: (value) =>
                            fontSizeViewModel.setFontSizeIndex(value.round()),
                      ),
                    ),
                  ),
                  Text('A',
                      style: AppText.xxl.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary)),
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
                          style:
                              AppText.xs.copyWith(color: colors.textSecondary),
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
