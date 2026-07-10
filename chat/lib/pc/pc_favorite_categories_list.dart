import 'package:flutter/material.dart';
import 'package:chat/l10n/app_localizations.dart';

import 'package:chat/pc/pc_favorite_list_widget.dart';
import 'package:chat/widget/option_item.dart';

/// PC 中栏使用的收藏分类入口列表。
///
/// 点击分类后通过 [onOpenFavoriteList] 回调在右栏打开对应分类的 [FavoriteListWidget]。
class PcFavoriteCategoriesList extends StatelessWidget {
  final void Function(FavoriteCategory category) onOpenFavoriteList;

  const PcFavoriteCategoriesList({
    super.key,
    required this.onOpenFavoriteList,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Column(
        children: [
          OptionItem(
            l10n.favoritesAll,
            leftIcon: Icons.cloud_outlined,
            onTap: () => onOpenFavoriteList(FavoriteCategory.all),
          ),
          OptionItem(
            l10n.favoritesFile,
            leftIcon: Icons.insert_drive_file_outlined,
            onTap: () => onOpenFavoriteList(FavoriteCategory.file),
          ),
          OptionItem(
            l10n.favoritesMedia,
            leftIcon: Icons.image_outlined,
            onTap: () => onOpenFavoriteList(FavoriteCategory.media),
          ),
          OptionItem(
            l10n.favoritesComposite,
            leftIcon: Icons.chat_bubble_outline_rounded,
            showBottomDivider: false,
            onTap: () => onOpenFavoriteList(FavoriteCategory.composite),
          ),
        ],
      ),
    );
  }
}
