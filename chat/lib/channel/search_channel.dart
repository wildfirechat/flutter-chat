import 'dart:async';

import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:chat/search/async_search_result_view.dart';
import 'package:chat/search/search_scaffold.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/widget/portrait.dart';

import '../config.dart';
import '../l10n/app_localizations.dart';
import 'channel_info_widget.dart';

/// 搜索频道。与[搜索用户]同一套壳与交互:边打边搜、搜不到有提示。
class SearchChannelScreen extends StatelessWidget {
  final String? hint;

  const SearchChannelScreen({super.key, this.hint});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SearchScaffold(
      hint: hint ?? l10n.searchChannelHint,
      builder: (context, query) {
        if (query.isEmpty) {
          return SearchStatusView(
            icon: Icons.podcasts_outlined,
            message: l10n.searchChannelPrompt,
          );
        }
        return AsyncSearchResultView<ChannelInfo>(
          query: query,
          onSearch: _searchChannels,
          emptyMessage: l10n.searchChannelNotFound,
          itemBuilder: (context, channelInfo) =>
              _ChannelResultItem(channelInfo: channelInfo),
        );
      },
    );
  }

  Future<List<ChannelInfo>> _searchChannels(String keyword) {
    final completer = Completer<List<ChannelInfo>>();
    Imclient.searchChannel(keyword, (channelInfos) {
      if (!completer.isCompleted) {
        completer.complete(channelInfos);
      }
    }, (errorCode) {
      if (!completer.isCompleted) {
        completer.completeError(errorCode);
      }
    });
    return completer.future;
  }
}

class _ChannelResultItem extends StatelessWidget {
  final ChannelInfo channelInfo;

  const _ChannelResultItem({required this.channelInfo});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => ChannelInfoWidget(channelInfo: channelInfo)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Portrait(channelInfo.portrait ?? Config.defaultChannelPortrait,
                Config.defaultChannelPortrait,
                width: 40, height: 40, borderRadius: 4.0),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                channelInfo.name ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.base.copyWith(
                    fontWeight: FontWeight.w500,
                    color: context.colors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
