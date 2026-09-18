import 'package:flutter/material.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/search/search_portal_result_view.dart';
import 'package:chat/search/search_scaffold.dart';

/// 移动端全局搜索页(消息列表右上角放大镜):联系人 / 群 / 频道 / 组织架构 / 聊天记录 一把搜。
///
/// 结果分组展示在 [SearchPortalResultView] 里,桌面端那套浮层(pc_search_view)用的是
/// 同一个结果视图,改结果样式两端一起动。
class SearchPortalScreen extends StatelessWidget {
  const SearchPortalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SearchScaffold(
      hint: l10n.search,
      builder: (context, query) => query.isEmpty
          ? SearchStatusView(
              icon: Icons.search,
              message: l10n.searchKeywordHint,
            )
          : SearchPortalResultView(query),
    );
  }
}
