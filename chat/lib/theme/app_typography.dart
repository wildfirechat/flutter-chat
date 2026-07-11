import 'package:flutter/widgets.dart';

/// 字号阶梯 —— 全端(移动端 + 桌面端)唯一的字号来源,调用点不要再写死 `fontSize`。
///
/// 命名只标大小、不标用途,与 `vue-pc-chat` 的 `--font-size-*` 同一套模型。
/// (Dart 标识符不能以数字开头,vue 的 `2xl` / `3xl` 在这里落成 [xl] / [xxl]。)
///
/// | 令牌   | px | 常见用途(参考,不是约束)                | vue                |
/// |--------|----|-----------------------------------------|--------------------|
/// | [xxs]  | 11 | 角标数字、字母索引、小号时间戳          | `--font-size-xxs`  |
/// | [xs]   | 12 | 时间戳、元信息、辅助说明                | `--font-size-xs`   |
/// | [sm]   | 13 | 次要信息(会话摘要、说明文字)          | `--font-size-sm`   |
/// | [base] | 14 | 桌面正文、桌面列表标题、表单文字        | `--font-size-base` |
/// | [lg]   | 16 | 移动端消息正文、列表主标题、区块/栏标题 | `--font-size-lg`   |
/// | [xl]   | 20 | 页面 / 弹窗标题                         | `--font-size-2xl`  |
/// | [xxl]  | 24 | 展示级大标题(启动页、扫码页、空状态)  | `--font-size-3xl`  |
/// | [xxxl] | 40 | 头像占位首字母                          | —                  |
///
/// ## ⚠️ [base] 不是移动端正文
///
/// 它是 14,桌面密度的正文;**移动端消息正文 / 列表主标题是 [lg](16)**。
/// 跨端 app 没有单一的「默认正文」—— 看到 `base` 就当默认往移动端套,会把聊天正文缩一号。
///
/// ## 为什么按大小命名
///
/// 用途名(body / caption / headline…)会在调用点撒谎:同一个 16,移动端是消息正文、
/// 桌面端是区块标题,按用途命名总有一端是错的。
///
/// 需要「角色」这一层时,**写组件级封装,别把角色塞进字号名** —— 见 pc/pc_theme.dart 的
/// `PcTheme.cellTitle` / `cellSubtitle` / `cellTime` / `paneTitle`:由它们钉死"桌面 cell
/// 该用哪一档",调用点不必自己挑。
///
/// ## 边界
///
/// - **只有字号**。字重、字色仍从祖先 `DefaultTextStyle` / 主题继承(与旧的裸
///   `TextStyle(fontSize: N)` 行为一致);需要时在调用点 `copyWith(fontWeight: ...)` /
///   `copyWith(color: context.colors.xxx)`,颜色令牌见 theme/app_colors.dart。
/// - **不含行高**。全 app 大量固定高度的 cell,把 `height` 塞进令牌会顶破布局。
/// - **是 1.0 倍基准号**。用户的「字体大小」档位由 main.dart 的全局
///   `TextScaler.linear(...)` 统一缩放(对应 vue 的 `--font-scale`),这里不要再自己乘。
class AppText {
  AppText._();

  /// 11 —— 角标数字、字母索引、小号时间戳。
  static const TextStyle xxs = TextStyle(fontSize: 11);

  /// 12 —— 时间戳、元信息、辅助说明。
  static const TextStyle xs = TextStyle(fontSize: 12);

  /// 13 —— 次要信息(会话摘要、说明文字)。
  static const TextStyle sm = TextStyle(fontSize: 13);

  /// 14 —— 桌面正文、桌面列表标题、表单文字。
  ///
  /// ⚠️ **不是移动端正文**,移动端正文是 [lg]。
  static const TextStyle base = TextStyle(fontSize: 14);

  /// 16 —— 移动端消息正文、列表主标题、区块/栏标题。
  static const TextStyle lg = TextStyle(fontSize: 16);

  /// 20 —— 页面 / 弹窗标题。
  static const TextStyle xl = TextStyle(fontSize: 20);

  /// 24 —— 展示级大标题(启动页、扫码页、空状态)。
  static const TextStyle xxl = TextStyle(fontSize: 24);

  /// 40 —— 头像占位首字母。是头像里的字形而非正文,故不参与正文阶梯的递进。
  static const TextStyle xxxl = TextStyle(fontSize: 40);
}
