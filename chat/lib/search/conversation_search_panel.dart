import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/model/user_info.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chat/config.dart';
import 'package:chat/conversation/conversation_files_screen.dart';
import 'package:chat/conversation/conversation_links_screen.dart';
import 'package:chat/conversation/conversation_screen.dart';
import 'package:chat/search/conversation_calendar_screen.dart';
import 'package:chat/search/conversation_media_grid_screen.dart';
import 'package:chat/utilities.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/utils/mesh_user_name.dart';
import 'package:chat/mesh/mesh_cache.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/utils/layout_scale.dart';

/// 会话内搜索历史在 SharedPreferences 中的 key
const String _kSearchHistoryKey = 'conversation_search_history';
const int _kSearchHistoryMaxCount = 10;

enum _SearchTab { all, file, media, link, date }

/// PC 微信风格「查找聊天内容」面板：搜索框 + 横向分类标签栏（全部/文件/图片与视频/链接/日期）+ 内容区。
///
/// 无 Scaffold/AppBar，手机端由 SearchConversationResultView 整页承载，PC 端可内嵌进独立窗口。
class ConversationSearchPanel extends StatefulWidget {
  final Conversation conversation;
  final String initialKeyword;

  /// 点击消息定位到会话。为 null 时默认 Navigator.push ConversationScreen(toFocusMessageId:)
  final void Function(Message message)? onLocateMessage;

  /// 可选：是否显示搜索历史区（手机 true；PC 窗口由调用方决定）
  final bool showSearchHistory;

  const ConversationSearchPanel(this.conversation,
      {super.key,
      this.initialKeyword = '',
      this.onLocateMessage,
      this.showSearchHistory = true});

  @override
  State<ConversationSearchPanel> createState() =>
      _ConversationSearchPanelState();
}

class _ConversationSearchPanelState extends State<ConversationSearchPanel> {
  static const int _pageSize = 30;

  late TextEditingController _controller;
  _SearchTab _tab = _SearchTab.all;

  /// 「全部」标签：未输入关键字时的全量消息浏览，新的在前
  final List<Message> _browseMessages = [];
  bool _browseLoading = false;
  bool _browseHasMore = true;
  int _fromMessageId = 0;

  /// 关键字搜索结果（offset 分页）
  final List<Message> _searchResults = [];
  bool _searchLoading = false;
  bool _searchHasMore = true;
  int _searchOffset = 0;

  /// 关键字变化时递增，丢弃过期请求的回调
  int _searchToken = 0;

  List<String> _history = [];

  /// 「日期」标签：选中的日期（null 显示日历，非 null 显示当天消息列表）
  DateTime? _selectedDate;
  List<Message>? _dayMessages;
  bool _dayLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialKeyword);
    _loadHistory();
    if (widget.initialKeyword.trim().isNotEmpty) {
      _searchMessages(reset: true);
    } else {
      _loadMoreBrowse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ---------- 搜索历史 ----------

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _history = prefs.getStringList(_kSearchHistoryKey) ?? [];
      });
    }
  }

  /// 新词去重插头部，上限 [_kSearchHistoryMaxCount] 条
  Future<void> _saveHistory(String keyword) async {
    final word = keyword.trim();
    if (word.isEmpty) return;
    _history.remove(word);
    _history.insert(0, word);
    if (_history.length > _kSearchHistoryMaxCount) {
      _history = _history.sublist(0, _kSearchHistoryMaxCount);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kSearchHistoryKey, _history);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _clearHistory() async {
    _history.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSearchHistoryKey);
    if (mounted) {
      setState(() {});
    }
  }

  // ---------- 「全部」标签：全量消息浏览分页 ----------

  Future<void> _loadMoreBrowse() async {
    if (_browseLoading || !_browseHasMore) return;

    setState(() {
      _browseLoading = true;
    });

    try {
      final messages = await Imclient.getMessages(
          widget.conversation, _fromMessageId, _pageSize);
      if (mounted) {
        setState(() {
          _browseLoading = false;
          if (messages.isNotEmpty) {
            // 各端 getMessages 返回顺序不一致（桌面端实测 [新...旧]），
            // 统一按 messageId 降序，保证新的在前、分页锚点取最旧一条
            messages.sort((a, b) => b.messageId.compareTo(a.messageId));
            _browseMessages.addAll(messages);
            _fromMessageId = messages.last.messageId;
          }
          if (messages.length < _pageSize) {
            _browseHasMore = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _browseLoading = false;
        });
      }
    }
  }

  // ---------- 关键字搜索分页 ----------

  void _onKeywordChanged(String value) {
    final keyword = value.trim();
    setState(() {
      if (keyword.isNotEmpty) {
        // 输入关键字时自动视为在「全部」标签下搜索
        _tab = _SearchTab.all;
      }
    });
    if (keyword.isNotEmpty) {
      _searchMessages(reset: true);
    } else if (_browseMessages.isEmpty && _browseHasMore) {
      // 清空关键字回到浏览列表时，若尚未加载过则补一次首页加载
      _loadMoreBrowse();
    }
  }

  void _searchMessages({bool reset = false}) {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) return;

    if (reset) {
      _searchResults.clear();
      _searchOffset = 0;
      _searchHasMore = true;
      // 让进行中的旧请求回调失效，避免过期结果混入
      _searchToken++;
      _searchLoading = false;
    }
    if (_searchLoading || !_searchHasMore) return;

    final token = _searchToken;
    final offset = _searchOffset;
    setState(() {
      _searchLoading = true;
    });

    Imclient.searchMessages(
            widget.conversation, keyword, true, _pageSize, offset)
        .then((messages) {
      if (!mounted || token != _searchToken) return;
      setState(() {
        _searchLoading = false;
        _searchResults.addAll(messages);
        _searchOffset += messages.length;
        if (messages.length < _pageSize) {
          _searchHasMore = false;
        }
      });
    });
  }

  // ---------- 「日期」标签：当天消息 ----------

  /// 选中某天：加载当天全部消息（本地库逐页向前拉，封顶 500 条防异常），按时间升序展示
  Future<void> _loadDayMessages(DateTime day) async {
    setState(() {
      _selectedDate = day;
      _dayMessages = null;
      _dayLoading = true;
    });
    final dayStartMs =
        DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    var beforeTs = DateTime(day.year, day.month, day.day, 23, 59, 59, 999)
        .millisecondsSinceEpoch;
    final result = <Message>[];
    try {
      while (result.length < 500) {
        final page = await Imclient.getMessagesByTimestamp(
            widget.conversation, beforeTs, 50);
        if (page.isEmpty) break;
        page.sort((a, b) => a.serverTime.compareTo(b.serverTime));
        final inDay =
            page.where((m) => m.serverTime >= dayStartMs).toList();
        result.insertAll(0, inDay);
        // 本页有早于当天的消息，或已不足一页，说明当天消息拉完了
        if (inDay.length < page.length || page.length < 50) break;
        beforeTs = page.first.serverTime - 1;
      }
    } catch (_) {}
    if (mounted && _selectedDate == day) {
      setState(() {
        _dayMessages = result;
        _dayLoading = false;
      });
    }
  }

  // ---------- 消息定位 ----------

  void _locateMessage(Message message) {
    final onLocateMessage = widget.onLocateMessage;
    if (onLocateMessage != null) {
      onLocateMessage(message);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConversationScreen(
            widget.conversation,
            toFocusMessageId: message.messageId,
          ),
        ),
      );
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: _buildSearchField(),
        ),
        _buildTabBar(),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildSearchField() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: context.colors.inputBg,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: _controller,
        style: AppText.base.copyWith(color: context.colors.textPrimary),
        decoration: InputDecoration(
          hintText: l10n.searchHint,
          hintStyle: AppText.base.copyWith(color: context.colors.textTertiary),
          prefixIcon:
              Icon(Icons.search, size: 20, color: context.colors.iconSecondary),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 36, minHeight: 36),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.cancel,
                      size: 18, color: context.colors.iconSecondary),
                  onPressed: () {
                    _controller.clear();
                    _onKeywordChanged('');
                  },
                ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
        onChanged: _onKeywordChanged,
        onSubmitted: (value) => _saveHistory(value),
        textInputAction: TextInputAction.search,
      ),
    );
  }

  Widget _buildTabBar() {
    final l10n = AppLocalizations.of(context)!;
    final tabs = <(_SearchTab, String)>[
      (_SearchTab.all, l10n.tabAll),
      (_SearchTab.file, l10n.chatFiles),
      (_SearchTab.media, l10n.searchMedia),
      (_SearchTab.link, l10n.chatLinks),
      (_SearchTab.date, l10n.searchByDate),
    ];
    return SizedBox(
      height: 44,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            for (final (tab, label) in tabs)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(label),
                  showCheckmark: false,
                  selected: _tab == tab,
                  onSelected: (_) => setState(() => _tab = tab),
                  selectedColor: context.colors.accentSoft,
                  backgroundColor: context.colors.buttonSecondaryBg,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  labelStyle: AppText.base.copyWith(
                    color: _tab == tab
                        ? context.colors.accent
                        : context.colors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_tab) {
      case _SearchTab.file:
        return ConversationFilesView(widget.conversation);
      case _SearchTab.media:
        return ConversationMediaGridView(widget.conversation);
      case _SearchTab.link:
        return ConversationLinksView(widget.conversation);
      case _SearchTab.date:
        return _buildDateContent();
      case _SearchTab.all:
        return _controller.text.trim().isEmpty
            ? _buildBrowseList()
            : _buildSearchResultList();
    }
  }

  /// 「日期」标签：未选日期显示日历；选中后内嵌展示当天消息列表（对齐 PC 微信）
  Widget _buildDateContent() {
    final l10n = AppLocalizations.of(context)!;
    final selected = _selectedDate;
    if (selected == null) {
      return ConversationCalendarView(
        widget.conversation,
        onDaySelected: _loadDayMessages,
      );
    }
    final locale = Localizations.localeOf(context).toString();
    final dayMessages = _dayMessages;
    return Column(
      children: [
        SizedBox(
          height: 44,
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back,
                    size: 20, color: context.colors.iconSecondary),
                tooltip: l10n.searchByDate,
                onPressed: () => setState(() => _selectedDate = null),
              ),
              Text(
                DateFormat.yMMMd(locale).format(selected),
                style: AppText.base.copyWith(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        Expanded(
          child: _dayLoading
              ? const Center(child: CircularProgressIndicator())
              : dayMessages == null || dayMessages.isEmpty
                  ? Center(child: Text(l10n.noSearchResult))
                  : ListView.separated(
                      itemCount: dayMessages.length,
                      separatorBuilder: (context, index) => Divider(
                        indent: 16.0 +
                            LayoutScale.watchScale(context, 48.0,
                                cap: LayoutScale.iconCap) +
                            16.0,
                      ),
                      itemBuilder: (context, index) =>
                          _buildMessageTile(dayMessages[index]),
                    ),
        ),
      ],
    );
  }

  /// 「全部」标签 + 无关键字：搜索历史区 + 全量消息列表（新的在前，滚动到底向前翻页）
  Widget _buildBrowseList() {
    final showHistory = widget.showSearchHistory && _history.isNotEmpty;
    final headerCount = showHistory ? 1 : 0;
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (!_browseLoading &&
            _browseHasMore &&
            scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 200) {
          _loadMoreBrowse();
        }
        return false;
      },
      child: ListView.separated(
        itemCount:
            headerCount + _browseMessages.length + (_browseHasMore ? 1 : 0),
        separatorBuilder: (context, index) => index < headerCount
            ? const SizedBox.shrink()
            : Divider(
                indent: 16.0 +
                    LayoutScale.watchScale(context, 48.0,
                        cap: LayoutScale.iconCap) +
                    16.0,
              ),
        itemBuilder: (context, index) {
          if (index < headerCount) {
            return _buildHistorySection();
          }
          final msgIndex = index - headerCount;
          if (msgIndex >= _browseMessages.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _buildMessageTile(_browseMessages[msgIndex]);
        },
      ),
    );
  }

  Widget _buildHistorySection() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.searchHistoryTitle,
                style: AppText.sm.copyWith(color: context.colors.textSecondary),
              ),
              GestureDetector(
                onTap: _clearHistory,
                child: Text(
                  l10n.clearAll,
                  style:
                      AppText.sm.copyWith(color: context.colors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _history
                .map((word) => ActionChip(
                      label: Text(word),
                      onPressed: () {
                        _controller.text = word;
                        _saveHistory(word);
                        _onKeywordChanged(word);
                      },
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  /// 「全部」标签 + 有关键字：搜索结果列表（offset 分页，滚动到底加载更多）
  Widget _buildSearchResultList() {
    final l10n = AppLocalizations.of(context)!;
    if (_searchResults.isEmpty) {
      return _searchLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(child: Text(l10n.noSearchResult));
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (scrollInfo.metrics.pixels >=
            scrollInfo.metrics.maxScrollExtent - 200) {
          _searchMessages();
        }
        return false;
      },
      child: ListView.separated(
        itemCount: _searchResults.length + (_searchHasMore ? 1 : 0),
        separatorBuilder: (context, index) => Divider(
          indent: 16.0 +
              LayoutScale.watchScale(context, 48.0, cap: LayoutScale.iconCap) +
              16.0,
        ),
        itemBuilder: (context, index) {
          if (index >= _searchResults.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _buildMessageTile(_searchResults[index]);
        },
      ),
    );
  }

  /// 记录最近一次按下的位置，供弹出菜单定位
  Offset _tapPosition = Offset.zero;

  /// 点击消息弹出操作菜单（对齐 PC 微信的「定位到聊天位置」）
  Future<void> _showMessageMenu(Message message) async {
    final l10n = AppLocalizations.of(context)!;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        _tapPosition & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          value: 'locate',
          child: Text(l10n.locateToChatPosition),
        ),
      ],
    );
    if (action == 'locate') {
      final keyword = _controller.text.trim();
      if (keyword.isNotEmpty) {
        _saveHistory(keyword);
      }
      _locateMessage(message);
    }
  }

  Widget _buildMessageTile(Message message) {
    final keyword = _controller.text.trim();
    return FutureBuilder<UserInfo?>(
      future: Imclient.getUserInfo(message.fromUser),
      builder: (context, snapshot) {
        var userInfo = snapshot.data;
        return GestureDetector(
          onTapDown: (details) => _tapPosition = details.globalPosition,
          child: ListTile(
            leading: Portrait(
              userInfo?.portrait ?? '',
              Config.defaultUserPortrait,
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AnimatedBuilder(
                  animation: MeshCache.instance,
                  builder: (context, child) {
                    return userInfo != null
                        ? MeshUserName(userInfo)
                        : Text(message.fromUser);
                  },
                ),
                Text(
                  Utilities.formatTime(context, message.serverTime),
                  style: AppText.xs.copyWith(color: Colors.grey),
                ),
              ],
            ),
            subtitle: FutureBuilder<String>(
              future: message.content.digest(message),
              builder: (context, snapshot) {
                return _highlightedDigest(snapshot.data ?? '', keyword);
              },
            ),
            onTap: () => _showMessageMenu(message),
          ),
        );
      },
    );
  }

  /// 摘要中命中关键字的片段用绿色高亮（大小写不敏感）
  Widget _highlightedDigest(String digest, String keyword) {
    final lowerDigest = digest.toLowerCase();
    final lowerKeyword = keyword.toLowerCase();
    if (keyword.isEmpty || !lowerDigest.contains(lowerKeyword)) {
      return Text(
        digest,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final spans = <TextSpan>[];
    int start = 0;
    while (true) {
      final index = lowerDigest.indexOf(lowerKeyword, start);
      if (index < 0) {
        spans.add(TextSpan(text: digest.substring(start)));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: digest.substring(start, index)));
      }
      spans.add(TextSpan(
        text: digest.substring(index, index + keyword.length),
        style: const TextStyle(color: Colors.green),
      ));
      start = index + keyword.length;
    }
    return Text.rich(
      TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
