import 'package:flutter/material.dart';
import 'package:chat/pc/widgets/hover_builder.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';

/// 桌面端右栏「资料页」(用户 / 群组 / 频道 / 外部单位)的共用件。
///
/// 形态(参照微信 PC):正文限宽居中,整页一张白底 —— 不套卡片、不画边框、不画右箭头;
/// 头像名字一组、label-value 资料行一组、底部动作一组,组与组之间只用一条弱分隔线。
/// 配 [PcPageHeader.bare] 使用:标题栏只是一个恒定名词(「用户详情」「频道信息」)时,
/// 名字已经在正文里写着了,标题栏不必再说一遍。
///
/// 这条契约只管「内容有限」的详情页。列表/浏览器类页面(组织架构、收藏、文件记录)
/// 条目数没有上限,该铺满面板,不要套这一层。

/// 资料页正文栏宽。比设置页(`PcPaneContent.defaultMaxWidth` = 680)再窄一档 ——
/// 资料页的内容就这么点,跟着面板拉宽只会把标签和值扯到两端。
const double kPcProfileWidth = 520;

/// 资料行左侧标签列宽:标签列定宽,各行的值才能对齐成一列。
const double _kLabelWidth = 88;

/// 头部、资料行、动作区共用的横向内边距,保证左边界落在同一条线上。
const double _kRowInset = 8;

/// 头像 + 名字 + 副标题(野火号 / 群号)。[trailing] 放星标一类的小标记。
class PcProfileHeader extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final String? subtitle;
  final Widget? trailing;

  const PcProfileHeader({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  /// 名字的字号/字重。各资料页共用,避免每处再抄一遍。
  static TextStyle titleStyle(BuildContext context) =>
      AppText.xl.copyWith(fontWeight: FontWeight.w600, color: context.colors.textPrimary);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _kRowInset),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: title),
                    if (trailing != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: trailing!,
                      ),
                  ],
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle!,
                    style: AppText.sm.copyWith(color: colors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 资料行:左列标签(弱色、定宽),右列值。
/// 值为空时退化成占位文案(如「设置备注」),点它就是去设置它。
/// 不画右箭头 —— 可点性由 hover 反白和鼠标指针交代。
class PcProfileRow extends StatelessWidget {
  final String label;
  final String? value;
  final String? placeholder;
  final VoidCallback? onTap;

  const PcProfileRow({super.key, required this.label, this.value, this.placeholder, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasValue = value != null && value!.isNotEmpty;
    final text = hasValue ? value! : (placeholder ?? '');

    return HoverBuilder(
      cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: _kRowInset, vertical: 10),
          decoration: BoxDecoration(
            color: hovered && onTap != null ? colors.hoverOverlay : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _kLabelWidth,
                child: Text(label, style: AppText.base.copyWith(color: colors.textSecondary)),
              ),
              Expanded(
                child: Text(
                  text,
                  // 占位文案(还没设置)压到弱色,与真实值区分开。
                  style: AppText.base.copyWith(color: hasValue ? colors.textPrimary : colors.textTertiary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 组与组之间的弱分隔线。左右不缩进:正文本身已经限宽,再缩进就没有边界可言了。
class PcProfileDivider extends StatelessWidget {
  const PcProfileDivider({super.key});

  @override
  Widget build(BuildContext context) {
    // height 24.5 = 上下各 12 的组间留白 + 0.5 的线。
    return const Divider(height: 24.5);
  }
}

/// 底部动作区:居中排布,译文过长时换行而非溢出。
class PcProfileActions extends StatelessWidget {
  final List<Widget> children;

  const PcProfileActions({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 24,
        runSpacing: 8,
        children: children,
      ),
    );
  }
}
