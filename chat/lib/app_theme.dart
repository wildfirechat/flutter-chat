import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/theme/page_transitions.dart';
import 'package:chat/app_shell.dart';

/// 全端共享的 ThemeData(移动端 + 桌面端通用)。
/// 颜色一律从 [AppColors] 取,桌面端布局/密度的专属覆盖在 pc/pc_theme.dart。
class AppTheme {
  AppTheme._();

  /// ThemeData 不可变,且 `ColorScheme.fromSeed` 每次都要跑一遍 HCT 色彩推导,
  /// 各建一次缓存起来,不要在 build 里反复构造。
  static final ThemeData _light = _build(AppColors.light, Brightness.light);
  static final ThemeData _dark = _build(AppColors.dark, Brightness.dark);

  static ThemeData light() => _light;

  static ThemeData dark() => _dark;

  /// 明暗两套主题只有取哪套 [AppColors] 的区别,共用这一条装配线。
  static ThemeData _build(AppColors colors, Brightness brightness) {
    final base = ThemeData(
      brightness: brightness,
      colorScheme: colorScheme(colors, brightness),
    );
    return _withColors(base, colors).copyWith(
      scaffoldBackgroundColor: colors.surface,
      canvasColor: colors.surface,
      // 页面转场:移动端(含平板)走微信那套"从右侧推入、向右侧退出",
      // 见 theme/page_transitions.dart。桌面端传 null 即保持 SDK 默认 ——
      // PC 的页面切换语义是"右栏换内容",走 app_navigator / pc_home 里的
      // 零时长路由,本来就不该有转场。
      pageTransitionsTheme:
          AppShell.isDesktopStyle ? null : AppPageTransitions.mobile,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: colors.cellTop,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colors.textPrimary,
        systemOverlayStyle: systemOverlayStyle(brightness),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.accent,
        selectionColor: colors.accent.withValues(alpha: 0.35),
        selectionHandleColor: colors.accent,
      ),
    );
  }

  // ---- 配色槽位 ----
  //
  // `ColorScheme.fromSeed` 是按种子色的 **HCT 色相**推出整套中性色的,而品牌蓝的
  // 色相落在 270°(暗色主色 263°)—— 紫色区。于是所有没被钉住的槽位都带紫:
  //
  // | 槽位                    | 浅色    | 暗色    | 谁在用               |
  // |-------------------------|---------|---------|----------------------|
  // | `surfaceContainerHigh`  | #E8E7EF | #282A2F | AlertDialog          |
  // | `surfaceContainer`      | #EEEDF4 | #1D2024 | PopupMenu(右键菜单) |
  // | `surfaceContainerLow`   | #F4F3FA | #191C20 | BottomSheet / Card   |
  // | `secondaryContainer`    | #DCE2F9 | #3E4759 | FilledButton.tonal   |
  // | `primaryContainer`      | #DAE2FF | #274777 | FAB                  |
  // | `outlineVariant`        | #C5C6D0 | #44474E | 描边、DatePicker     |
  // | `tertiary`              | #735471 | #DCBCE0 | TimePicker           |
  //
  // 这就是「到处是 flutter 紫」的来源。挨个给组件配主题只会补一处漏一处,所以在
  // [colorScheme] 里**逐槽位**钉死中性灰:组件主题只负责表达「谁该用哪一层」,
  // 没单独配主题的 M3 组件也不会再漏紫。

  /// 全端共用的 [ColorScheme]:种子推导只留主色一族,其余槽位全部钉到 [AppColors]。
  ///
  /// 桌面子树的 `PcTheme.themeData`(pc/pc_theme.dart)也走这里 —— 它此前自己
  /// `fromSeed` 了一遍,把这些钉好的槽位又丢了回去。
  static ColorScheme colorScheme(AppColors colors, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // M3 的「容器阶梯」:Lowest → Highest,浅色逐级变深、暗色逐级变亮。
    // 逐级映到 app 自己的中性灰,层级方向与 M3 一致,取值全部来自既有令牌。
    final Color lowest, low, container, high, highest;
    if (isDark) {
      lowest = colors.primaryBackground; // #1C1C1E
      low = colors.middleBg; // #252527
      container = colors.surface; // #2C2C2E
      high = colors.popupBg; // #323232
      highest = colors.inputBg; // #3A3A3C
    } else {
      lowest = colors.surface; // #FFFFFF
      low = colors.searchBg; // #FAFAFA
      container = colors.chatBg; // #F5F5F5
      high = colors.buttonSecondaryBg; // #F2F2F2
      highest = colors.primaryBackground; // #EBEBEB
    }
    // surfaceDim / surfaceBright 就是阶梯的两端,谁暗谁亮随明暗主题对调。
    final Color dim = isDark ? lowest : highest;
    final Color bright = isDark ? highest : lowest;

    return ColorScheme.fromSeed(
      seedColor: colors.accent,
      brightness: brightness,
    ).copyWith(
      primary: colors.accent,
      onPrimary: colors.onAccent,
      primaryContainer: colors.accentSoft,
      onPrimaryContainer: colors.accent,
      // 单品牌色 app,secondary / tertiary 没有独立语义,一并收到主色 ——
      // 留给 M3 自己推,推出来的就是上表那支紫。
      secondary: colors.accent,
      onSecondary: colors.onAccent,
      tertiary: colors.accent,
      onTertiary: colors.onAccent,
      tertiaryContainer: colors.accentSoft,
      onTertiaryContainer: colors.accent,
      // secondaryContainer 例外:它是 FilledButton.tonal(次要按钮)的灰底,
      // 不跟 secondary 同族,见下面的「按钮基线」。
      secondaryContainer: colors.buttonSecondaryBg,
      onSecondaryContainer: colors.textPrimary,
      error: colors.danger,
      // error 被换成了饱和红,M3 自己推的 onError(暗色 #690005)压在上面糊成
      // 一团,跟 accent 一样用白字。
      onError: colors.onAccent,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      onSurfaceVariant: colors.textSecondary,
      surfaceDim: dim,
      surfaceBright: bright,
      surfaceContainerLowest: lowest,
      surfaceContainerLow: low,
      surfaceContainer: container,
      surfaceContainerHigh: high,
      surfaceContainerHighest: highest,
      outline: colors.hairline,
      outlineVariant: colors.hairlineSoft,
      // Material 海拔投影必须用不透明色,见 [AppColors.elevationShadow]
      shadow: colors.elevationShadow,
      scrim: colors.scrim,
      // 反色面(SnackBar 底、滑块数值气泡)= 正文色与基础面对调,天生就是
      // 「浅色近黑 / 暗色近白」的一对。
      inverseSurface: colors.textPrimary,
      onInverseSurface: colors.surface,
      inversePrimary: colors.accent,
      // M3 的「海拔染色」:Material 会按 elevation 把主色按不同浓度混进底色 ——
      // 既是另一条漏紫的路,也会让同一张白面在不同层级上颜色对不齐。整体关掉,
      // 层次交给 [AppColors] 自己的明度阶梯 + 阴影。
      surfaceTint: Colors.transparent,
    );
  }

  static ThemeData _withColors(ThemeData base, AppColors colors) =>
      base.copyWith(
        extensions: <ThemeExtension<dynamic>>[colors],
        // ---- 分割线基线 ----
        // 列表行间线全端统一:hairlineSoft、0.5 粗、0.5 占位,裸 `const Divider()`
        // 即标准形态,调用点不要再传 color/thickness;内容对齐传 indent,
        // 需要留白的场景显式传 height(例如气泡内 Divider(height: 16))。
        // hairline 留给结构边界(header 下边线、栏间分隔),用 Border/VerticalDivider 画。
        dividerTheme: DividerThemeData(
            color: colors.hairlineSoft, thickness: 0.5, space: 0.5),
        // ---- 按压反馈 ----
        // 裸 InkWell / ListTile 的水波与按住高亮。M2 默认值两层叠起来能把白色
        // 会话行压到 ~#D9D9D9,偏深;统一走 [AppColors.pressOverlay]。按钮不受
        // 影响,M3 的 ButtonStyle.overlayColor 另有来源。
        //
        // ⚠️ 它撑不起「上下文菜单弹出中」的高亮:长按被识别的那一刻 InkWell 的
        // TapGestureRecognizer 就被挤出竞技场、收到 onTapCancel,高亮随即淡出
        // —— 恰好是菜单刚弹出、用户正看着的时候。那个状态得由调用方自己维持,
        // 见 home/conversation_list_widget.dart 的 `_menuOpen`。
        highlightColor: colors.pressOverlay,
        splashColor: colors.pressOverlay,
        // ---- 次要图标基线 ----
        // 裸 IconButton、ListTile 的 leading/trailing:M3 默认取 onSurfaceVariant,
        // 而那一档在这里是**文字**灰 [AppColors.textSecondary],压到图标上偏淡。
        // 图标有自己的令牌,走 [AppColors.iconSecondary]。
        // AppBar 里的图标不受影响 —— 它自套一层 IconTheme,优先级高于本主题。
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(foregroundColor: colors.iconSecondary),
        ),
        listTileTheme: ListTileThemeData(iconColor: colors.iconSecondary),
        // ---- 弹窗 / 浮层基线 ----
        //
        // 容器阶梯已在 [colorScheme] 里钉成中性灰,这三支再按 app 的语义分层
        // (M3 默认挑的那一级对本 app 不成立):
        // - 对话框 / 底部弹窗 → 基础面 [AppColors.surface]
        // - 弹出菜单 → 浮层面 [AppColors.popupBg](暗色下比 surface 亮一档,
        //   暗色模式没有阴影可用,只能靠明度差浮起来)
        //
        // 全端基线,桌面端不要再在 pc_theme.dart 里配一遍:形态差异走
        // [AppShell.isDesktopStyle] 分叉,PcTheme 是 base.copyWith,自动继承。
        dialogTheme: DialogThemeData(
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
          shadowColor: colors.elevationShadow,
          barrierColor: colors.scrim,
          iconColor: colors.accent,
          // 桌面端对齐 showPcDialog 的 8 圆角;移动端留 M3 默认(28)。
          shape: AppShell.isDesktopStyle
              ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
              : null,
          // 正文不跟 onSurfaceVariant 走:那一档是 textSecondary,给副标题/提示
          // 用的,压在对话框正文上太弱。只换色,字号仍是 M3 的 bodyMedium。
          contentTextStyle:
              base.textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: colors.popupBg,
          surfaceTintColor: Colors.transparent,
          shadowColor: colors.elevationShadow,
          elevation: AppShell.isDesktopStyle ? 6 : 12,
          // ⚠️ 白底菜单压在白底会话列表上时,光靠 elevation 分不出**顶边**:
          // Material 的海拔投影是有方向的(引擎按上方光源算),浓度大头的 spot
          // 落在下沿与两侧,顶边只剩 ambient 的 3.9%。四边均匀的软投影是 CSS
          // box-shadow 的形态,PopupMenuThemeData 给不了(只有 elevation /
          // shadowColor)。所以补一圈发丝描边兜住四条边,阴影只负责纵深。
          shape: RoundedRectangleBorder(
            side: BorderSide(color: colors.hairline, width: 0.5),
            borderRadius:
                BorderRadius.circular(AppShell.isDesktopStyle ? 6 : 8),
          ),
          // ⚠️ M3 只读 labelTextStyle,PopupMenuThemeData.textStyle 是 M2 遗留
          // 字段,写在那儿不生效(见 popup_menu.dart 的 _PopupMenuDefaultsM3)。
          // 移动端取 lg,与 widget/bottom_action_sheet.dart 的动作项同档。
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final TextStyle style =
                AppShell.isDesktopStyle ? AppText.sm : AppText.lg;
            return style.copyWith(
              color: states.contains(WidgetState.disabled)
                  ? colors.textTertiary
                  : colors.textPrimary,
            );
          }),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: colors.surface,
          modalBackgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
        ),
        // ---- 控件 ----
        checkboxTheme: checkboxTheme(colors, base.brightness),
        switchTheme: switchTheme(colors, base.brightness),
        // FAB 跟「实底主行动」一个语义,走 accent 实底,而不是 M3 默认的
        // primaryContainer(淡底)。
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: colors.accent,
          foregroundColor: colors.onAccent,
        ),
        filledButtonTheme: FilledButtonThemeData(style: buttonShapeStyle()),
        textButtonTheme: TextButtonThemeData(style: textButtonStyle()),
        // 过渡兜底:repo 内已无 ElevatedButton / OutlinedButton 调用点,这两支只防
        // 新代码或第三方误用时观感失控 —— Elevated 等价 FilledButton(实底 accent、
        // 无阴影),Outlined 等价 FilledButton.tonal(无边框灰底)。
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: buttonShapeStyle().merge(ElevatedButton.styleFrom(
            backgroundColor: colors.accent,
            foregroundColor: colors.onAccent,
            elevation: 0,
            shadowColor: Colors.transparent,
          )),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: buttonShapeStyle().merge(OutlinedButton.styleFrom(
            backgroundColor: colors.buttonSecondaryBg,
            foregroundColor: colors.textPrimary,
            side: BorderSide.none,
          )),
        ),
      );

  // ---- 按钮基线 ----
  //
  // 语义与控件的对应关系,调用点凭裸控件即可得到正确观感,不要再写散落的 styleFrom:
  // - 实底主行动 → FilledButton(危险操作只覆盖 backgroundColor: colors.danger)
  // - 次要动作 → FilledButton.tonal,灰底无边框(危险操作只覆盖 foregroundColor:
  //   colors.danger,不描边 —— 形状只编码层级,颜色只编码语义)
  // - 文字动作(对话框确认位、链接式) → TextButton;对话框「取消」位叠 [mutedTextButtonStyle]
  // - 整页唯一主行动 / 通栏 CTA → 在裸控件上叠 [largeButtonStyle]
  //
  // 颜色不写进按钮主题:FilledButton 与 FilledButton.tonal 共享同一个
  // FilledButtonTheme(SDK 的 themeStyleOf 对两个变体返回同一支 style),在主题里写死
  // backgroundColor 会把 tonal 也染成 accent。颜色钉在 colorScheme 上:
  // primary/onPrimary → 主行动实底,secondaryContainer/onSecondaryContainer → 次要灰底。
  // 禁用态是 M3 默认灰(onSurface 的 12%/38%),两个变体共用;按钮内的 busy spinner
  // 别再传 onAccent —— 禁用灰底上白圈看不见,用 CircularProgressIndicator 默认主色。
  //
  // 尺寸分两档,默认是「中档」(行内、列表行、对话框 footer 的最高频尺寸),
  // 通栏/整页场景显式叠大档 —— 让例外显式化,不让最大号当默认。
  //
  // 形态按平台分叉在这里(而不是 pc_theme):PC 登录窗、根导航对话框都在
  // PcTheme.themeData 子树之外,只有挂在 MaterialApp 主题上才能全覆盖;
  // PcTheme.themeData 是 base.copyWith,会自动继承这里的桌面形态。
  //
  // ⚠️ 桌面数值看着偏大不是笔误:desktop 平台的默认 visualDensity 就是 compact,
  // 渲染时最小高度与纵向 padding 各再减 8,中档的 40 实际落在 ~32(与重构前
  // PcDialog 底栏的按钮等高)。

  /// 实底/灰底按钮共用的「中档」形态(尺寸、圆角、字号),不含任何颜色。
  static ButtonStyle buttonShapeStyle() => ButtonStyle(
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppShell.isDesktopStyle ? 4 : 6))),
        minimumSize: WidgetStatePropertyAll(
            AppShell.isDesktopStyle ? const Size(64, 40) : const Size(64, 36)),
        padding: WidgetStatePropertyAll(AppShell.isDesktopStyle
            ? const EdgeInsets.symmetric(horizontal: 20, vertical: 10)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
        textStyle: WidgetStatePropertyAll(AppShell.isDesktopStyle
            ? AppText.sm
            : AppText.base.copyWith(fontWeight: FontWeight.w500)),
        // 移动端保持默认 padded:36 的视觉高度外,可点区域仍撑到 48 不缩水。
        tapTargetSize:
            AppShell.isDesktopStyle ? MaterialTapTargetSize.shrinkWrap : null,
      );

  /// 大档:整页唯一主行动 / 通栏底栏(登录、poll 底栏、转发确认…)。
  /// 只放大形态不带颜色,FilledButton / FilledButton.tonal 都能叠;
  /// 需要同时改色时:FilledButton.styleFrom(backgroundColor: …).merge(largeButtonStyle())。
  static ButtonStyle largeButtonStyle() => ButtonStyle(
        minimumSize: WidgetStatePropertyAll(
            AppShell.isDesktopStyle ? const Size(80, 48) : const Size(64, 44)),
        padding: WidgetStatePropertyAll(AppShell.isDesktopStyle
            ? const EdgeInsets.symmetric(horizontal: 32, vertical: 12)
            : const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
        textStyle: WidgetStatePropertyAll(AppShell.isDesktopStyle
            ? AppText.base
            : AppText.lg.copyWith(fontWeight: FontWeight.w500)),
      );

  /// 文字动作:前景色走组件默认值(colorScheme.primary,即品牌蓝),
  /// 这里只收桌面字号与点击区。
  static ButtonStyle textButtonStyle() => ButtonStyle(
        textStyle: AppShell.isDesktopStyle
            ? const WidgetStatePropertyAll(AppText.sm)
            : null,
        tapTargetSize:
            AppShell.isDesktopStyle ? MaterialTapTargetSize.shrinkWrap : null,
      );

  /// 对话框「取消」位的压灰文字动作,弱于右侧的确认位。
  static ButtonStyle mutedTextButtonStyle(AppColors colors) =>
      TextButton.styleFrom(foregroundColor: colors.textSecondary);

  /// 开关(Switch)的主题:收紧点击区域,选中品牌蓝。
  static SwitchThemeData switchTheme(AppColors colors, Brightness brightness) {
    return SwitchThemeData(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return colors.onAccent;
        }
        return null;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return colors.accent;
        }
        return null;
      }),
    );
  }

  /// 圆形勾选框(微信风格):选中品牌蓝,禁用置灰。
  /// 选人、多选消息等场景全端统一观感;挂在全局 ThemeData 与 PcTheme 上。
  ///
  /// 描边/禁用灰是勾选框自己的中性灰,不复用文字令牌 —— 文字灰在暗色下
  /// (#636366)压不住 #2C2C2E 的面,描边会看不见。
  static CheckboxThemeData checkboxTheme(
      AppColors colors, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final borderGray =
        isDark ? const Color(0xFF5A5A5C) : const Color(0xFFC0C0C0);
    final disabledGray =
        isDark ? const Color(0xFF48484A) : const Color(0xFFC6C6C6);
    return CheckboxThemeData(
      shape: const CircleBorder(),
      side: BorderSide(color: borderGray, width: 1.5),
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (!states.contains(WidgetState.selected)) {
          return Colors.transparent;
        }
        return states.contains(WidgetState.disabled)
            ? disabledGray
            : colors.accent;
      }),
      checkColor: WidgetStatePropertyAll(colors.onAccent),
    );
  }

  /// 移动端状态栏 / 导航栏图标的明暗。桌面端不使用。
  /// 传入的是「界面」的明暗,图标要取反才看得见。
  static SystemUiOverlayStyle systemOverlayStyle(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colors = isDark ? AppColors.dark : AppColors.light;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: colors.cellTop,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
    );
  }
}
