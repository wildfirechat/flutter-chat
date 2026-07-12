import 'package:flutter/material.dart';
import 'package:chat/l10n/app_localizations.dart';

import 'package:chat/pc/pc_favorite_list_widget.dart';
import 'package:chat/pc/widgets/pc_nav_cell.dart';

/// PC 中栏使用的收藏分类入口列表。
///
/// 点击分类后通过 [onOpenFavoriteList] 回调在右栏打开对应分类的 [FavoriteListWidget]。
/// 选中态只存在本地:切走 tab 时本组件被销毁,而 pc_home 也同时清空了右栏,
/// 两边一起复位,不会出现“右栏有内容、中栏没高亮”。
class PcFavoriteCategoriesList extends StatefulWidget {
  final void Function(FavoriteCategory category) onOpenFavoriteList;

  const PcFavoriteCategoriesList({
    super.key,
    required this.onOpenFavoriteList,
  });

  @override
  State<PcFavoriteCategoriesList> createState() => _PcFavoriteCategoriesListState();
}

class _PcFavoriteCategoriesListState extends State<PcFavoriteCategoriesList> {
  FavoriteCategory? _selected;

  void _open(FavoriteCategory category) {
    setState(() {
      _selected = category;
    });
    widget.onOpenFavoriteList(category);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final categories = <(FavoriteCategory, String, IconData)>[
      (FavoriteCategory.all, l10n.favoritesAll, Icons.cloud_outlined),
      (FavoriteCategory.file, l10n.favoritesFile, Icons.insert_drive_file_outlined),
      (FavoriteCategory.media, l10n.favoritesMedia, Icons.image_outlined),
      (FavoriteCategory.composite, l10n.favoritesComposite, Icons.chat_bubble_outline_rounded),
    ];

    return SingleChildScrollView(
      child: Column(
        children: [
          for (final (category, title, icon) in categories)
            PcNavCell(
              title: title,
              icon: icon,
              selected: _selected == category,
              onTap: () => _open(category),
            ),
        ],
      ),
    );
  }
}
