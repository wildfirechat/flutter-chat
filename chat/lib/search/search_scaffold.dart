import 'dart:async';

import 'package:flutter/material.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/widget/app_bar_actions.dart';

/// 微信式搜索页外壳:顶栏是「灰底圆角输入框 + 取消」,内容区由 [builder] 按关键字填。
///
/// 取代原先各处的 [SearchDelegate]:那套壳把输入框裸挂在 AppBar 上(无底色、无放大镜、
/// 无清除按钮),与 App 内其它搜索框(会话内搜索 conversation_search_panel、转发选人
/// ForwardSearchBar)不是一个样子,浅色下几乎看不见输入区在哪。这里统一成同一套形态:
/// [AppColors.searchFieldBg] 淡灰底 + 8 圆角 + 前置放大镜 + 尾部清除。
///
/// 交互也跟着微信走:**边打边搜**,关键字停 [debounce] 后才回调 [builder](按键盘搜索键
/// 立刻生效),不再有「打了字却什么都不显示、必须回车」的空窗 —— 原 SearchDelegate 的
/// buildSuggestions 在多数页面直接返回空 Container,就是那个空窗的来源。
///
/// 移动端与桌面端共用:桌面端全局搜索走 pc_search_view 那套浮层,不经过这里;
/// 但右栏里打开的搜索页(如「在本单位中查找用户」「搜索文件」)仍是这一套。
class SearchScaffold extends StatefulWidget {
  /// 输入框占位文案。
  final String hint;

  /// 内容区。[query] 已 trim,空串表示「还没输入」。
  final Widget Function(BuildContext context, String query) builder;

  final String initialQuery;

  /// 停止输入多久才真正发起搜索。服务端搜索(用户/频道/组织架构)每次都是一趟网络,
  /// 不抖动一下会被逐字符打爆。
  final Duration debounce;

  final bool autofocus;

  const SearchScaffold({
    super.key,
    required this.hint,
    required this.builder,
    this.initialQuery = '',
    this.debounce = const Duration(milliseconds: 250),
    this.autofocus = true,
  });

  @override
  State<SearchScaffold> createState() => _SearchScaffoldState();
}

/// 输入框常态高度。比 App 内其它搜索框(36)高一档:搜索页整页只有这一个输入位,
/// 它就是这一页的主体,按 36 排会显得挤在顶栏里。大字号下由 minHeight 继续撑开。
const double _fieldHeight = 40;

class _SearchScaffoldState extends State<SearchScaffold> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;

  /// 已生效的关键字(trim 过),内容区就是按它来的。
  late String _query;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _query = widget.initialQuery.trim();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    // 清空是立即生效的:内容区该马上回到空态,没必要再等一次抖动。
    if (value.trim().isEmpty) {
      _applyQuery('');
      return;
    }
    _debounce = Timer(widget.debounce, () => _applyQuery(value));
    // 清除按钮的显隐跟着输入走,与关键字是否生效无关。
    setState(() {});
  }

  void _onSubmitted(String value) {
    _debounce?.cancel();
    _applyQuery(value);
  }

  void _applyQuery(String value) {
    final query = value.trim();
    if (query == _query) {
      setState(() {});
      return;
    }
    setState(() => _query = query);
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    _applyQuery('');
    // 微信点清除后光标仍在输入框里,键盘不收。
    _focusNode.requestFocus();
  }

  void _cancel() {
    // 先收键盘再退场,否则退出动画会与键盘收起抢帧。
    _focusNode.unfocus();
    Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        // 微信搜索页没有返回箭头,右侧「取消」就是退路。
        automaticallyImplyLeading: false,
        // 顶栏与内容区同一张底(默认 AppBar 是 cellTop 灰,压在白色结果区上会有一道
        // 明显的横向色阶)。搜索页只有「输入框 + 结果」一件事,顶栏不该被读成独立的
        // 一栏 —— 同色 + 无 tint + 滚动不升色,整页才是连成一片的。
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: _buildField(context),
        actions: [
          // 「取消」是退路不是主动作,用中性色,别跟 accent 的确认位抢眼。
          AppBarTextAction(
            label: l10n.cancel,
            textColor: colors.textPrimary,
            onPressed: _cancel,
          ),
        ],
      ),
      body: widget.builder(context, _query),
    );
  }

  Widget _buildField(BuildContext context) {
    final colors = context.colors;
    return Container(
      // 大字号下要能撑开,所以是 minHeight 不是固定高。
      constraints: const BoxConstraints(minHeight: _fieldHeight),
      decoration: BoxDecoration(
        // 顶栏已经是白面,再用灰面那档 inputBg 会压出一条深色横带 —— 见
        // [AppColors.searchFieldBg]。
        color: colors.searchFieldBg,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        style: AppText.base.copyWith(color: colors.textPrimary),
        textInputAction: TextInputAction.search,
        onChanged: _onChanged,
        onSubmitted: _onSubmitted,
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: AppText.base.copyWith(color: colors.textTertiary),
          prefixIcon: Icon(Icons.search, size: 20, color: colors.iconSecondary),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 34, minHeight: _fieldHeight),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  // IconButton 默认按 48×48 的点击区排版(tapTargetSize.padded),
                  // 不收紧的话敲下第一个字、清除按钮一出现,整条搜索框就被顶高一截。
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(34, _fieldHeight),
                  ),
                  icon:
                      Icon(Icons.cancel, size: 18, color: colors.iconSecondary),
                  onPressed: _clear,
                ),
          suffixIconConstraints:
              const BoxConstraints(minWidth: 34, minHeight: _fieldHeight),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }
}

/// 搜索页内容区的提示态:居中一个淡图标 + 一行说明(可再带一行次要说明)。
/// 空关键字的引导语、搜不到结果、搜索失败都用它,免得各页面各写一个 Center(Text)。
class SearchStatusView extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? detail;

  const SearchStatusView({
    super.key,
    required this.icon,
    required this.message,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: colors.iconSecondary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.base.copyWith(color: colors.textSecondary),
            ),
            if (detail != null && detail!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: AppText.xs.copyWith(color: colors.textTertiary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
