import 'package:flutter/material.dart';

/// 语义化颜色令牌,全端(移动端 + 桌面端)唯一的颜色来源。
///
/// - 浅色值逐一沿用暗黑模式重构前散落在各处的硬编码色值,浅色观感不变。
/// - 暗色值移植自 `vue-pc-chat/src/theme/dark.css`(macOS Sonoma 深色面板),
///   与 vue 端保持同一套配色:主色切系统蓝 #0A84FF,发送气泡实心蓝 #409CFF。
///
/// 取值走 `context.colors`(见文件末尾的 extension),widget 里不要再写死颜色。
/// 需要新色时先在这里加令牌,不要在调用点 `withValues` 出一个新颜色。
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.accent,
    required this.accentPressed,
    required this.onAccent,
    required this.danger,
    required this.badge,
    required this.link,
    required this.surface,
    required this.popupBg,
    required this.sidebarBg,
    required this.middleBg,
    required this.chatBg,
    required this.conversationBg,
    required this.inputBg,
    required this.inputBgHover,
    required this.cellHover,
    required this.cellSelected,
    required this.cellTop,
    required this.sidebarHoverBg,
    required this.hoverOverlay,
    required this.messageHighlight,
    required this.sectionGap,
    required this.bubbleSent,
    required this.bubbleSentDesktop,
    required this.bubbleReceived,
    required this.bubbleSentText,
    required this.bubbleReceivedText,
    required this.bubbleQuoted,
    required this.bubbleQuotedText,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.iconPrimary,
    required this.iconSecondary,
    required this.hairline,
    required this.hairlineSoft,
    required this.resizeHandleHover,
    required this.scrim,
    required this.shadow,
  });

  // ---- 品牌色 ----
  /// 选中 tab、发送按钮、光标/选区。浅色是品牌蓝,暗色跟随 vue 切 macOS 系统蓝。
  final Color accent;
  final Color accentPressed;

  /// accent 实心底上的前景色。
  final Color onAccent;

  /// 危险操作(退出登录、删除)。
  final Color danger;

  /// 未读角标。
  final Color badge;

  /// 正文里的超链接。
  final Color link;

  // ---- 背景层 ----
  /// 卡片 / AppBar / Dialog / Scaffold 的基础面。
  final Color surface;

  /// 浮层(popup menu、@ 面板、气泡卡片)。暗色下比 [surface] 再亮一档,
  /// 才能从面板上浮起来 —— 暗色模式没有阴影可用,只能靠明度差分层。
  final Color popupBg;

  /// 桌面端三段纵深:侧栏 → 中栏 → 右栏。
  /// 浅色是「灰 → 更灰 → 最浅」,暗色反过来「最亮 → 中 → 最深」,层次方向保持一致。
  final Color sidebarBg;
  final Color middleBg;
  final Color chatBg;

  /// 移动端会话页背景(与桌面端右栏不同色,故单列)。
  final Color conversationBg;

  /// 搜索框 / 输入框底色。
  final Color inputBg;
  final Color inputBgHover;

  // ---- 列表项状态 ----
  final Color cellHover;
  final Color cellSelected;

  /// 置顶会话底色。
  final Color cellTop;
  final Color sidebarHoverBg;

  /// 盖在任意底色上的通用 hover 蒙版(半透明)。
  /// 浅色压黑、暗色提白,所以不能用固定实色。
  final Color hoverOverlay;

  /// 搜索/引用跳转定位到某条消息时的整行高亮,半透明盖在气泡上。
  final Color messageHighlight;

  /// 分组列表的段间凹槽(SectionDivider 那条 18px 的横带)。
  /// 必须比它所在的面**更暗**才读作凹槽:浅色下压深一档,暗色下直接落到最深的底色。
  final Color sectionGap;

  // ---- 消息气泡 ----
  /// 移动端发送气泡。桌面端见 [bubbleSentDesktop] —— 两端浅色下取值不同,
  /// 暗色下都收敛到系统蓝。
  final Color bubbleSent;
  final Color bubbleSentDesktop;
  final Color bubbleReceived;

  /// 气泡内文字。暗色发送气泡是实心蓝,必须用纯白而不是正文灰白。
  final Color bubbleSentText;
  final Color bubbleReceivedText;

  /// 气泡内引用块。
  final Color bubbleQuoted;
  final Color bubbleQuotedText;

  // ---- 文字 ----
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  // ---- 图标 ----
  final Color iconPrimary;
  final Color iconSecondary;

  // ---- 描边 ----
  /// 发丝线:栏间分隔、header 下边线。
  final Color hairline;

  /// 比 [hairline] 更淡:浮层轮廓、移动端列表分隔线。
  final Color hairlineSoft;
  final Color resizeHandleHover;

  // ---- 其他 ----
  /// 模态遮罩(Dialog barrier)。暗色下压得更狠,否则深色弹窗和深色背景糊在一起。
  final Color scrim;

  /// 浮层投影。暗色下阴影几乎不可见,靠 [popupBg] 的明度差分层,这里只做轻微加重。
  final Color shadow;

  /// 浅色:重构前的既有色值,不改观感。
  static const AppColors light = AppColors(
    accent: Color(0xFF1F64E4),
    accentPressed: Color(0xFF1A55C2),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFED4C4D),
    badge: Color(0xFFFA5151),
    link: Color(0xFF1F64E4),
    surface: Color(0xFFFFFFFF),
    popupBg: Color(0xFFFFFFFF),
    sidebarBg: Color(0xFFE9E9E9),
    middleBg: Color(0xFFE6E5E5),
    chatBg: Color(0xFFF5F5F5),
    conversationBg: Color(0xFFE8E8E8),
    inputBg: Color(0xFFDBDAD9),
    inputBgHover: Color(0xFFD5D4D3),
    cellHover: Color(0xFFDBDAD9),
    cellSelected: Color(0xFFC8C7C6),
    cellTop: Color(0xFFEFEEED),
    sidebarHoverBg: Color(0xFFDCDCDC),
    hoverOverlay: Color(0x0A000000),
    messageHighlight: Color(0x809E9E9E),
    sectionGap: Color(0xFFEBEBEB),
    bubbleSent: Color(0xF0A8BDFF),
    bubbleSentDesktop: Color(0xFFD6E4FF),
    bubbleReceived: Color(0xFFFFFFFF),
    bubbleSentText: Color(0xFF191919),
    bubbleReceivedText: Color(0xFF191919),
    bubbleQuoted: Color(0xFFF5F5F5),
    bubbleQuotedText: Color(0xFF666666),
    textPrimary: Color(0xFF191919),
    textSecondary: Color(0xFF7F7F7F),
    textTertiary: Color(0xFFB2B2B2),
    iconPrimary: Color(0xFF191919),
    iconSecondary: Color(0xFF555555),
    hairline: Color(0xFFDDDCDB),
    hairlineSoft: Color(0xFFEBEAE9),
    resizeHandleHover: Color(0xFFC2C1C0),
    scrim: Color(0x4D000000),
    shadow: Color(0x40000000),
  );

  /// 暗色:对齐 vue-pc-chat/src/theme/dark.css。
  /// hover/selected 用半透明白而不是实色 —— 三栏底色不同,同一个实色压不住。
  static const AppColors dark = AppColors(
    accent: Color(0xFF0A84FF),
    accentPressed: Color(0xFF40A9FF),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFFF453A),
    badge: Color(0xFFFF453A),
    link: Color(0xFF0A84FF),
    surface: Color(0xFF2C2C2E),
    popupBg: Color(0xFF323232),
    sidebarBg: Color(0xFF2C2C2E),
    middleBg: Color(0xFF252527),
    chatBg: Color(0xFF1C1C1E),
    conversationBg: Color(0xFF1C1C1E),
    inputBg: Color(0xFF3A3A3C),
    inputBgHover: Color(0xFF48484A),
    cellHover: Color(0x0DFFFFFF),
    cellSelected: Color(0x1AFFFFFF),
    cellTop: Color(0x08FFFFFF),
    sidebarHoverBg: Color(0xFF3A3A3C),
    hoverOverlay: Color(0x14FFFFFF),
    messageHighlight: Color(0x1FFFFFFF),
    sectionGap: Color(0xFF1C1C1E),
    bubbleSent: Color(0xFF409CFF),
    bubbleSentDesktop: Color(0xFF409CFF),
    bubbleReceived: Color(0xFF2C2C2E),
    bubbleSentText: Color(0xFFFFFFFF),
    bubbleReceivedText: Color(0xFFE0E0E4),
    bubbleQuoted: Color(0xFF3A3A3C),
    bubbleQuotedText: Color(0xFFAEAEB2),
    textPrimary: Color(0xFFE0E0E4),
    textSecondary: Color(0xFF8E8E93),
    textTertiary: Color(0xFF636366),
    iconPrimary: Color(0xFFE0E0E4),
    iconSecondary: Color(0xFF8E8E93),
    hairline: Color(0xFF3A3A3C),
    hairlineSoft: Color(0xFF2F2F31),
    resizeHandleHover: Color(0xFF48484A),
    scrim: Color(0x99000000),
    shadow: Color(0x99000000),
  );

  @override
  AppColors copyWith({
    Color? accent,
    Color? accentPressed,
    Color? onAccent,
    Color? danger,
    Color? badge,
    Color? link,
    Color? surface,
    Color? popupBg,
    Color? sidebarBg,
    Color? middleBg,
    Color? chatBg,
    Color? conversationBg,
    Color? inputBg,
    Color? inputBgHover,
    Color? cellHover,
    Color? cellSelected,
    Color? cellTop,
    Color? sidebarHoverBg,
    Color? hoverOverlay,
    Color? messageHighlight,
    Color? sectionGap,
    Color? bubbleSent,
    Color? bubbleSentDesktop,
    Color? bubbleReceived,
    Color? bubbleSentText,
    Color? bubbleReceivedText,
    Color? bubbleQuoted,
    Color? bubbleQuotedText,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? iconPrimary,
    Color? iconSecondary,
    Color? hairline,
    Color? hairlineSoft,
    Color? resizeHandleHover,
    Color? scrim,
    Color? shadow,
  }) {
    return AppColors(
      accent: accent ?? this.accent,
      accentPressed: accentPressed ?? this.accentPressed,
      onAccent: onAccent ?? this.onAccent,
      danger: danger ?? this.danger,
      badge: badge ?? this.badge,
      link: link ?? this.link,
      surface: surface ?? this.surface,
      popupBg: popupBg ?? this.popupBg,
      sidebarBg: sidebarBg ?? this.sidebarBg,
      middleBg: middleBg ?? this.middleBg,
      chatBg: chatBg ?? this.chatBg,
      conversationBg: conversationBg ?? this.conversationBg,
      inputBg: inputBg ?? this.inputBg,
      inputBgHover: inputBgHover ?? this.inputBgHover,
      cellHover: cellHover ?? this.cellHover,
      cellSelected: cellSelected ?? this.cellSelected,
      cellTop: cellTop ?? this.cellTop,
      sidebarHoverBg: sidebarHoverBg ?? this.sidebarHoverBg,
      hoverOverlay: hoverOverlay ?? this.hoverOverlay,
      messageHighlight: messageHighlight ?? this.messageHighlight,
      sectionGap: sectionGap ?? this.sectionGap,
      bubbleSent: bubbleSent ?? this.bubbleSent,
      bubbleSentDesktop: bubbleSentDesktop ?? this.bubbleSentDesktop,
      bubbleReceived: bubbleReceived ?? this.bubbleReceived,
      bubbleSentText: bubbleSentText ?? this.bubbleSentText,
      bubbleReceivedText: bubbleReceivedText ?? this.bubbleReceivedText,
      bubbleQuoted: bubbleQuoted ?? this.bubbleQuoted,
      bubbleQuotedText: bubbleQuotedText ?? this.bubbleQuotedText,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      iconPrimary: iconPrimary ?? this.iconPrimary,
      iconSecondary: iconSecondary ?? this.iconSecondary,
      hairline: hairline ?? this.hairline,
      hairlineSoft: hairlineSoft ?? this.hairlineSoft,
      resizeHandleHover: resizeHandleHover ?? this.resizeHandleHover,
      scrim: scrim ?? this.scrim,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) {
      return this;
    }
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      accent: mix(accent, other.accent),
      accentPressed: mix(accentPressed, other.accentPressed),
      onAccent: mix(onAccent, other.onAccent),
      danger: mix(danger, other.danger),
      badge: mix(badge, other.badge),
      link: mix(link, other.link),
      surface: mix(surface, other.surface),
      popupBg: mix(popupBg, other.popupBg),
      sidebarBg: mix(sidebarBg, other.sidebarBg),
      middleBg: mix(middleBg, other.middleBg),
      chatBg: mix(chatBg, other.chatBg),
      conversationBg: mix(conversationBg, other.conversationBg),
      inputBg: mix(inputBg, other.inputBg),
      inputBgHover: mix(inputBgHover, other.inputBgHover),
      cellHover: mix(cellHover, other.cellHover),
      cellSelected: mix(cellSelected, other.cellSelected),
      cellTop: mix(cellTop, other.cellTop),
      sidebarHoverBg: mix(sidebarHoverBg, other.sidebarHoverBg),
      hoverOverlay: mix(hoverOverlay, other.hoverOverlay),
      messageHighlight: mix(messageHighlight, other.messageHighlight),
      sectionGap: mix(sectionGap, other.sectionGap),
      bubbleSent: mix(bubbleSent, other.bubbleSent),
      bubbleSentDesktop: mix(bubbleSentDesktop, other.bubbleSentDesktop),
      bubbleReceived: mix(bubbleReceived, other.bubbleReceived),
      bubbleSentText: mix(bubbleSentText, other.bubbleSentText),
      bubbleReceivedText: mix(bubbleReceivedText, other.bubbleReceivedText),
      bubbleQuoted: mix(bubbleQuoted, other.bubbleQuoted),
      bubbleQuotedText: mix(bubbleQuotedText, other.bubbleQuotedText),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textTertiary: mix(textTertiary, other.textTertiary),
      iconPrimary: mix(iconPrimary, other.iconPrimary),
      iconSecondary: mix(iconSecondary, other.iconSecondary),
      hairline: mix(hairline, other.hairline),
      hairlineSoft: mix(hairlineSoft, other.hairlineSoft),
      resizeHandleHover: mix(resizeHandleHover, other.resizeHandleHover),
      scrim: mix(scrim, other.scrim),
      shadow: mix(shadow, other.shadow),
    );
  }
}

extension AppColorsContext on BuildContext {
  /// 当前主题的语义色令牌。
  ///
  /// 兜底成浅色而不是抛异常:少数子树(第三方组件、独立 `Theme()`)可能没带上
  /// extension,取不到时宁可退化成浅色,也不要在运行时炸掉整个页面。
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
