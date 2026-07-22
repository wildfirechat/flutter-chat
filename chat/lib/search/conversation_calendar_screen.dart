import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/model/conversation.dart';
import 'package:intl/intl.dart';
import 'package:chat/conversation/conversation_screen.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/widgets/pc_page_header.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';

/// 按日期查找聊天内容：从当月起的日历，有消息的日期可点击定位到当天最后一条消息。
class ConversationCalendarScreen extends StatelessWidget {
  final Conversation conversation;

  const ConversationCalendarScreen(this.conversation, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: isDesktopShell
          ? PcPageHeader(
              title: l10n.searchByDate,
              onBack: () => Navigator.of(context).maybePop(),
            )
          : AppBar(
              title: Text(l10n.searchByDate),
            ),
      body: ConversationCalendarView(conversation),
    );
  }
}

/// 日历内容（无 Scaffold/AppBar），供搜索面板等场景内嵌。
class ConversationCalendarView extends StatefulWidget {
  final Conversation conversation;

  /// 点击日期定位到会话消息。为 null 时默认 Navigator.push ConversationScreen(toFocusMessageId:)
  final void Function(Message message)? onLocateMessage;

  const ConversationCalendarView(this.conversation,
      {super.key, this.onLocateMessage});

  @override
  State<ConversationCalendarView> createState() =>
      _ConversationCalendarViewState();
}

class _ConversationCalendarViewState extends State<ConversationCalendarView> {
  final ScrollController _scrollController = ScrollController();

  /// 已展开的月份（当月在最前，往前追加）
  final List<DateTime> _months = [];

  /// 每月消息数缓存，key 为 'yyyy-MM'，避免滚动重建时重复请求
  final Map<String, Future<Map<String, int>>> _countFutures = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _appendMonths(DateTime(now.year, now.month), 3);
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreMonths();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _appendMonths(DateTime fromMonth, int count) {
    for (int i = 0; i < count; i++) {
      final month = DateTime(fromMonth.year, fromMonth.month - i);
      _months.add(month);
    }
  }

  void _loadMoreMonths() {
    setState(() {
      _appendMonths(_months.last, 3);
    });
  }

  String _monthKey(DateTime month) =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';

  Future<Map<String, int>> _countsOf(DateTime month) {
    return _countFutures.putIfAbsent(_monthKey(month), () {
      final start = DateTime(month.year, month.month, 1);
      // 月末：下月 1 号前一秒
      final end = DateTime(month.year, month.month + 1, 1)
          .subtract(const Duration(seconds: 1));
      return Imclient.getMessageCountByDay(
        widget.conversation,
        start.millisecondsSinceEpoch ~/ 1000,
        end.millisecondsSinceEpoch ~/ 1000,
      );
    });
  }

  Future<void> _onDayTap(DateTime day) async {
    final messages = await Imclient.getMessagesByTimestamp(
      widget.conversation,
      DateTime(day.year, day.month, day.day, 23, 59, 59).millisecondsSinceEpoch,
      1,
    );
    if (messages.isNotEmpty && mounted) {
      final onLocateMessage = widget.onLocateMessage;
      if (onLocateMessage != null) {
        onLocateMessage(messages.first);
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConversationScreen(
              widget.conversation,
              toFocusMessageId: messages.first.messageId,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: _months.length,
      itemBuilder: (context, index) => _MonthSection(
        month: _months[index],
        countFuture: _countsOf(_months[index]),
        onDayTap: _onDayTap,
      ),
    );
  }
}

/// 单个月份区块：月份标题 + 星期行 + 7 列日期网格
class _MonthSection extends StatelessWidget {
  final DateTime month;
  final Future<Map<String, int>> countFuture;
  final ValueChanged<DateTime> onDayTap;

  const _MonthSection({
    required this.month,
    required this.countFuture,
    required this.onDayTap,
  });

  String _dayKey(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    // 星期标签（周一起），取一个已知的周一(2024-01-01)起连续 7 天
    final weekdayLabels = List.generate(
      7,
      (i) => DateFormat.E(locale).format(DateTime(2024, 1, 1 + i)),
    );
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = DateTime(month.year, month.month, 1).weekday - 1;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              DateFormat.yMMMM(locale).format(month),
              style: AppText.lg.copyWith(
                color: context.colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Row(
            children: weekdayLabels
                .map((label) => Expanded(
                      child: Center(
                        child: Text(
                          label,
                          style: AppText.xs
                              .copyWith(color: context.colors.textSecondary),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          FutureBuilder<Map<String, int>>(
            future: countFuture,
            builder: (context, snapshot) {
              final counts = snapshot.data ?? const {};
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                ),
                itemCount: leadingBlanks + daysInMonth,
                itemBuilder: (context, index) {
                  if (index < leadingBlanks) {
                    return const SizedBox.shrink();
                  }
                  final day = DateTime(
                      month.year, month.month, index - leadingBlanks + 1);
                  final hasMessages = (counts[_dayKey(day)] ?? 0) > 0;
                  final isFuture = day.isAfter(today);
                  final enabled = hasMessages && !isFuture;
                  return _DayCell(
                    day: day,
                    enabled: enabled,
                    onTap: enabled ? () => onDayTap(day) : null,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final bool enabled;
  final VoidCallback? onTap;

  const _DayCell({
    required this.day,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled ? context.colors.accentSoft : Colors.transparent,
          ),
          alignment: Alignment.center,
          child: Text(
            '${day.day}',
            style: AppText.sm.copyWith(
              color:
                  enabled ? context.colors.accent : context.colors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}
