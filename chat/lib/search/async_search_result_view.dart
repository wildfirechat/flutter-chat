import 'package:flutter/material.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/search/search_scaffold.dart';

/// 「一个关键字 → 一次异步搜索 → 列表/空态/失败态」的内容区。
///
/// 搜用户、搜频道这类要打服务端的搜索共用它:关键字变了就重新发起,回来的结果带
/// 序号校验,**过期响应直接丢掉**(慢的那一次回来时不能盖掉新关键字的结果)。
/// 原先这些页面是 `while(!finish) await Future.delayed(...)` 空转等回调 + FutureBuilder,
/// 既在 UI 线程上空跑,也没有过期保护。
class AsyncSearchResultView<T> extends StatefulWidget {
  final String query;

  /// 发起一次搜索。失败请抛异常(会展示为搜索失败),没结果返回空列表。
  final Future<List<T>> Function(String query) onSearch;

  final Widget Function(BuildContext context, T item) itemBuilder;

  /// 搜到 0 条时的提示语。
  final String emptyMessage;

  /// 分隔线左缩进,与列表项头像右边缘对齐。
  final double separatorIndent;

  const AsyncSearchResultView({
    super.key,
    required this.query,
    required this.onSearch,
    required this.itemBuilder,
    required this.emptyMessage,
    this.separatorIndent = 64,
  });

  @override
  State<AsyncSearchResultView<T>> createState() =>
      _AsyncSearchResultViewState<T>();
}

class _AsyncSearchResultViewState<T> extends State<AsyncSearchResultView<T>> {
  /// 每发起一次搜索自增;回调回来时对不上就是过期结果。
  int _token = 0;
  List<T>? _result;
  Object? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void didUpdateWidget(covariant AsyncSearchResultView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _search();
    }
  }

  /// 只改字段、不 setState:调用点(initState / didUpdateWidget)后面紧跟着一次 build。
  void _search() {
    final token = ++_token;
    _loading = true;
    _result = null;
    _error = null;
    widget.onSearch(widget.query).then((items) {
      if (!mounted || token != _token) return;
      setState(() {
        _loading = false;
        _result = items;
      });
    }).catchError((Object error) {
      if (!mounted || token != _token) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return SearchStatusView(
        icon: Icons.cloud_off,
        message: AppLocalizations.of(context)!.searchFailed('$_error'),
      );
    }
    final items = _result ?? <T>[];
    if (items.isEmpty) {
      return SearchStatusView(
        icon: Icons.search_off,
        message: widget.emptyMessage,
      );
    }
    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(indent: widget.separatorIndent),
      itemBuilder: (context, index) =>
          widget.itemBuilder(context, items[index]),
    );
  }
}
