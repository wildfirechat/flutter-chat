import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:chat/l10n/app_localizations.dart';

import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/widgets/hover_builder.dart';
import 'package:chat/pc/widgets/pc_dialog.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'poll_model.dart';
import 'poll_service.dart';
import 'poll_detail_screen.dart';

/// 我发起的投票。
///
/// 删除:移动端左滑,桌面端 hover 出删除按钮 —— 鼠标没有「左滑」这个手势,
/// 桌面端只留 Dismissible 等于没有删除入口。
class PollListScreen extends StatefulWidget {
  final String? groupId;
  final bool asDialog;

  const PollListScreen({super.key, this.groupId, this.asDialog = false});

  static Future<void> show(BuildContext context, String? groupId) {
    if (isDesktopShell) {
      return showPcDialog(
        context: context,
        width: 460,
        height: 560,
        builder: (_) => PollListScreen(groupId: groupId, asDialog: true),
      );
    }
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PollListScreen(groupId: groupId)),
    );
  }

  @override
  State<PollListScreen> createState() => _PollListScreenState();
}

class _PollListScreenState extends State<PollListScreen> {
  List<Poll> _pollList = [];
  bool _isLoading = false;

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _loadPolls();
  }

  Future<void> _loadPolls({bool showSpinner = true}) async {
    if (!PollService.isAvailable) {
      Fluttertoast.showToast(msg: _l10n.pollServiceNotConfigured);
      return;
    }

    if (showSpinner) {
      setState(() => _isLoading = true);
    }

    try {
      final polls = await PollService.getMyPolls();
      if (!mounted) return;
      setState(() {
        _pollList = polls;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      Fluttertoast.showToast(msg: '${_l10n.pollLoadFailed}: $e');
    }
  }

  Future<void> _deletePoll(Poll poll) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_l10n.confirm),
        content: Text(_l10n.pollDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_l10n.delete, style: TextStyle(color: dialogContext.colors.danger)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await PollService.delete(poll.pollId);
      if (mounted) {
        Fluttertoast.showToast(msg: _l10n.deleteSuccess);
        _loadPolls();
      }
    } catch (e) {
      Fluttertoast.showToast(msg: '${_l10n.deleteFailed}: $e');
    }
  }

  void _openDetail(Poll poll) {
    PollDetailScreen.showFromList(context, poll.pollId).then((_) => _loadPolls(showSpinner: false));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final body = Container(
      color: colors.primaryBackground,
      child: RefreshIndicator(
        onRefresh: () => _loadPolls(showSpinner: false),
        child: _buildContent(),
      ),
    );

    if (widget.asDialog) {
      return PcDialogFrame(title: _l10n.myPolls, child: body);
    }

    return Scaffold(
      backgroundColor: colors.primaryBackground,
      appBar: AppBar(title: Text(_l10n.myPolls)),
      body: body,
    );
  }

  Widget _buildContent() {
    final colors = context.colors;

    if (_isLoading && _pollList.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pollList.isEmpty) {
      // 下拉刷新要能在空态触发,故仍挂一个可滚动列表
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
          Icon(Icons.poll_outlined, size: 56, color: colors.textTertiary),
          const SizedBox(height: 12),
          Text(
            _l10n.pollEmptyList,
            textAlign: TextAlign.center,
            style: AppText.base.copyWith(color: colors.textSecondary),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _pollList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _buildPollItem(_pollList[index]),
    );
  }

  Widget _buildPollItem(Poll poll) {
    final card = _PollCard(
      poll: poll,
      onTap: () => _openDetail(poll),
      onDelete: poll.isCreator ? () => _deletePoll(poll) : null,
      statusChip: _buildStatusChip(poll),
      remainingText: poll.getRemainingTimeText(),
    );

    // 桌面端的删除入口在卡片内(hover 显形),不再包一层左滑
    if (isDesktopShell || !poll.isCreator) {
      return Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: card);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Dismissible(
        key: Key('poll_${poll.pollId}'),
        direction: DismissDirection.endToStart,
        background: Container(
          decoration: BoxDecoration(
            color: context.colors.danger,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          child: Icon(Icons.delete_outline, color: context.colors.onAccent),
        ),
        confirmDismiss: (_) async {
          await _deletePoll(poll);
          // 删除成功后靠重新拉列表移除该行,不让 Dismissible 自己抽走
          return false;
        },
        child: card,
      ),
    );
  }

  Widget _buildStatusChip(Poll poll) {
    final colors = context.colors;
    final String label;
    final Color fg;
    final Color bg;

    if (poll.status == 1) {
      label = _l10n.pollStatusEnded;
      fg = colors.textTertiary;
      bg = colors.hairlineSoft;
    } else if (poll.hasVoted) {
      label = _l10n.pollHasVoted;
      fg = colors.success;
      bg = colors.successSoft;
    } else {
      label = _l10n.pollStatusActive;
      fg = colors.accent;
      bg = colors.accentSoft;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: AppText.xxs.copyWith(color: fg)),
    );
  }
}

class _PollCard extends StatelessWidget {
  final Poll poll;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final Widget statusChip;
  final String? remainingText;

  const _PollCard({
    required this.poll,
    required this.onTap,
    required this.statusChip,
    this.onDelete,
    this.remainingText,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    final showHoverDelete = isDesktopShell && onDelete != null;

    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) => GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      poll.title,
                      style: AppText.base.copyWith(fontWeight: FontWeight.w500, color: colors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 删除按钮只在 hover 时占位显形,不 hover 时让位给状态徽标
                  if (showHoverDelete && hovered)
                    HoverBuilder(
                      cursor: SystemMouseCursors.click,
                      builder: (context, deleteHovered) => GestureDetector(
                        onTap: onDelete,
                        child: Tooltip(
                          message: l10n.delete,
                          child: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: deleteHovered ? colors.danger : colors.textTertiary,
                          ),
                        ),
                      ),
                    )
                  else
                    statusChip,
                ],
              ),
              if (poll.desc.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  poll.desc,
                  style: AppText.xs.copyWith(color: colors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.people_outline, size: 14, color: colors.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    '${poll.voterCount}${l10n.pollPeopleCount}',
                    style: AppText.xs.copyWith(color: colors.textTertiary),
                  ),
                  const SizedBox(width: 14),
                  Icon(Icons.how_to_vote_outlined, size: 14, color: colors.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    '${poll.totalVotes}${l10n.pollVotes}',
                    style: AppText.xs.copyWith(color: colors.textTertiary),
                  ),
                  const Spacer(),
                  if (remainingText != null && remainingText!.isNotEmpty)
                    Text(
                      remainingText!,
                      style: AppText.xs.copyWith(color: poll.isEnded ? colors.textTertiary : colors.warning),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
