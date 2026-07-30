import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/poll_message_content.dart';
import 'package:imclient/model/user_info.dart';
import 'package:chat/app_theme.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:path_provider/path_provider.dart';

import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/widgets/pc_dialog.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import '../widget/portrait.dart';
import 'poll_model.dart';
import 'poll_service.dart';

/// 投票详情。
///
/// 两种模式(沿用 Android PollDetailActivity 的语义):
/// - 投票模式:从消息进入,可勾选并提交;已投票/已结束则只读,并展示票数条。
/// - 管理模式:创建者从「我的投票」进入,不投票,只做导出/结束/删除。
///
/// 移动端整页 + 底部操作栏,桌面端弹窗 + 操作栏,入口统一走 [show]。
class PollDetailScreen extends StatefulWidget {
  final Message? message;
  final int? pollId;
  final bool asDialog;

  const PollDetailScreen(
      {super.key, this.message, this.pollId, this.asDialog = false})
      : assert(message != null || pollId != null,
            'message or pollId must be provided');

  /// 从消息进入(投票模式)
  static Future<void> showFromMessage(BuildContext context, Message message) {
    return _show(context,
        (asDialog) => PollDetailScreen(message: message, asDialog: asDialog));
  }

  /// 从列表进入(创建者为管理模式)
  static Future<void> showFromList(BuildContext context, int pollId) {
    return _show(context,
        (asDialog) => PollDetailScreen(pollId: pollId, asDialog: asDialog));
  }

  static Future<void> _show(
      BuildContext context, PollDetailScreen Function(bool asDialog) create) {
    if (isDesktopShell) {
      return showPcDialog(
        context: context,
        width: 460,
        height: 620,
        builder: (_) => create(true),
      );
    }
    return Navigator.push(
        context, MaterialPageRoute(builder: (_) => create(false)));
  }

  @override
  State<PollDetailScreen> createState() => _PollDetailScreenState();
}

class _PollDetailScreenState extends State<PollDetailScreen> {
  late int pollId;
  late String currentUserId;

  Poll? poll;
  bool isLoading = true;
  Set<int> selectedOptionIds = {};

  bool get _isServiceAvailable => PollService.isAvailable;

  /// 管理模式:从列表进入且是创建者
  bool get _isManagerMode => poll?.isCreator == true && widget.message == null;

  bool get _canVote {
    if (poll == null) return false;
    if (_isManagerMode) return false;
    if (poll!.hasVoted) return false;
    if (poll!.isEnded) return false;
    return true;
  }

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    if (widget.message != null) {
      final content = widget.message!.content as PollMessageContent;
      pollId = int.tryParse(content.pollId) ?? 0;
    } else {
      pollId = widget.pollId!;
    }
    currentUserId = Imclient.currentUserId;

    _fetchPollDetail();
  }

  Future<void> _fetchPollDetail() async {
    if (!_isServiceAvailable) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final result = await PollService.getPoll(pollId);
      if (!mounted) return;
      setState(() {
        poll = result;
        isLoading = false;
        // 恢复已选择的选项(仅投票模式下)
        if (!_isManagerMode) {
          selectedOptionIds = Set.from(result.myOptionIds);
        }
      });
      _updateLocalMessageIfNeeded();
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      Fluttertoast.showToast(msg: '${_l10n.pollLoadFailed}: $e');
    }
  }

  /// 服务端状态比消息里的快照新时,回写本地消息,气泡上的票数/状态才不会一直是旧的。
  void _updateLocalMessageIfNeeded() {
    if (widget.message == null ||
        widget.message!.content is! PollMessageContent) {
      return;
    }

    final content = widget.message!.content as PollMessageContent;
    bool needUpdate = false;

    if (poll!.status != content.status) {
      content.status = poll!.status;
      needUpdate = true;
    }

    if (poll!.totalVotes != content.totalVotes) {
      content.totalVotes = poll!.totalVotes;
      needUpdate = true;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (poll!.endTime > 0 && poll!.endTime < now && content.endTime >= now) {
      content.status = 1;
      needUpdate = true;
    }

    if (needUpdate) {
      Imclient.updateMessage(widget.message!.messageId, content);
    }
  }

  /// 多选投票时在标题旁提示已选数量
  String? get _selectionHint {
    if (poll != null &&
        _canVote &&
        poll!.isMultiChoice &&
        selectedOptionIds.isNotEmpty) {
      return _l10n.pollSelectedCount(selectedOptionIds.length, poll!.maxSelect);
    }
    return null;
  }

  Future<void> _onSubmit() async {
    if (!_isServiceAvailable) {
      Fluttertoast.showToast(msg: _l10n.pollServiceNotConfigured);
      return;
    }

    if (selectedOptionIds.isEmpty) {
      Fluttertoast.showToast(msg: _l10n.pollSelectOption);
      return;
    }

    try {
      await PollService.vote(pollId, selectedOptionIds.toList());
      if (mounted) {
        Fluttertoast.showToast(msg: _l10n.pollVoteSuccess);
        _fetchPollDetail();
      }
    } catch (e) {
      Fluttertoast.showToast(msg: '${_l10n.pollVoteFailed}: $e');
    }
  }

  void _onOptionSelected(int optionId) {
    if (!_canVote) return;

    setState(() {
      if (poll!.isSingleChoice) {
        if (selectedOptionIds.contains(optionId)) {
          selectedOptionIds.remove(optionId);
        } else {
          selectedOptionIds
            ..clear()
            ..add(optionId);
        }
      } else {
        if (selectedOptionIds.contains(optionId)) {
          selectedOptionIds.remove(optionId);
        } else {
          if (poll!.maxSelect > 0 &&
              selectedOptionIds.length >= poll!.maxSelect) {
            Fluttertoast.showToast(
                msg: _l10n.pollMaxSelectLimit(poll!.maxSelect));
            return;
          }
          selectedOptionIds.add(optionId);
        }
      }
    });
  }

  Future<bool> _confirm(
      {required String message, required String confirmLabel}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_l10n.confirm),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel,
                style: TextStyle(color: dialogContext.colors.danger)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _closePoll() async {
    if (!await _confirm(
        message: _l10n.pollCloseConfirm, confirmLabel: _l10n.close)) return;

    try {
      await PollService.close(pollId);
      if (mounted) {
        Fluttertoast.showToast(msg: _l10n.pollCloseSuccess);
        _fetchPollDetail();
      }
    } catch (e) {
      Fluttertoast.showToast(msg: '${_l10n.pollCloseFailed}: $e');
    }
  }

  Future<void> _deletePoll() async {
    if (!await _confirm(
        message: _l10n.pollDeleteConfirm, confirmLabel: _l10n.delete)) return;

    try {
      await PollService.delete(pollId);
      if (mounted) {
        Fluttertoast.showToast(msg: _l10n.pollDeleteSuccess);
        Navigator.pop(context);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: '${_l10n.pollDeleteFailed}: $e');
    }
  }

  Future<void> _exportPoll() async {
    if (poll == null) return;

    try {
      final details = await PollService.exportDetails(pollId);
      if (details.isEmpty) {
        Fluttertoast.showToast(msg: _l10n.pollNoVoterDetails);
        return;
      }

      final buffer = StringBuffer();
      buffer.write('﻿'); // UTF-8 BOM,Excel 打开才不乱码
      buffer.write(
          '${_l10n.pollCsvOption},${_l10n.pollCsvUser},${_l10n.pollCsvTime}\n');

      for (final detail in details) {
        final timeStr = DateTime.fromMillisecondsSinceEpoch(detail.voteTime)
            .toString()
            .substring(0, 19);
        buffer.write(
            '${_escapeCsv(detail.optionText)},${_escapeCsv(detail.userName)},$timeStr\n');
      }

      final fileName =
          '${_safeFileName(poll!.title)}_${_l10n.pollDetailsSuffix}.csv';
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(buffer.toString(), encoding: const Utf8Codec());

      // 缺 share_plus 依赖,先把落盘路径给出去
      Fluttertoast.showToast(msg: '${_l10n.pollShareDetails}: ${file.path}');
    } catch (e) {
      Fluttertoast.showToast(msg: '${_l10n.pollExportFailed}: $e');
    }
  }

  /// TODO: 接入转发选人流程(forward/),把 Poll 拼回 PollMessageContent 转发出去。
  /// 先留入口:管理模式下创建者本就该能把投票再发一次,入口去掉了就没人记得补。
  void _forwardPoll() {
    Fluttertoast.showToast(msg: _l10n.pollForwardComingSoon);
  }

  String _escapeCsv(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  String _safeFileName(String fileName) {
    if (fileName.isEmpty) {
      return _l10n.pollDefaultFileName;
    }
    String safeName = fileName.replaceAll(RegExp(r'[/\\?%*|"<>]'), '_');
    if (safeName.length > 50) {
      safeName = safeName.substring(0, 50);
    }
    return safeName.isEmpty ? _l10n.pollDefaultFileName : safeName;
  }

  // ---- 外壳 ----

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final body = isLoading
        ? const Center(child: CircularProgressIndicator())
        : poll == null
            ? Center(
                child: Text(
                  _l10n.pollLoadFailed,
                  style: AppText.base.copyWith(color: colors.textSecondary),
                ),
              )
            : _buildBody();

    if (widget.asDialog) {
      return PcDialogFrame(
        title: _l10n.pollDetail,
        subtitle: _selectionHint,
        footerLeading: _buildFooterLeading(),
        primary: _buildPrimaryAction(),
        secondary: _buildSecondaryAction(),
        child: Container(color: colors.primaryBackground, child: body),
      );
    }

    return Scaffold(
      backgroundColor: colors.primaryBackground,
      appBar: AppBar(
        title: Text(_selectionHint ?? _l10n.pollDetail),
        actions: [
          if (_isManagerMode)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: _l10n.forward,
              onPressed: _forwardPoll,
            ),
        ],
      ),
      body: body,
      bottomNavigationBar: _buildMobileBottomBar(),
    );
  }

  /// 桌面端操作栏左侧的次要入口(管理模式):转发,以及实名投票时的导出明细。
  /// 移动端这两项分别落在 AppBar 与底部栏上。
  Widget? _buildFooterLeading() {
    if (poll == null || !_isManagerMode) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _footerTextButton(
            icon: Icons.share_outlined,
            label: _l10n.forward,
            onPressed: _forwardPoll),
        if (_canExport)
          _footerTextButton(
            icon: Icons.file_download_outlined,
            label: _l10n.pollExport,
            onPressed: _exportPoll,
          ),
      ],
    );
  }

  Widget _footerTextButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: context.colors.textSecondary,
        textStyle: AppText.sm,
      ),
    );
  }

  /// 匿名投票没有可导出的明细。
  bool get _canExport => poll != null && _isManagerMode && poll!.anonymous != 1;

  /// 主操作:管理模式是「结束/删除」,投票模式是「提交投票」;只读时无主操作。
  PcDialogAction? _buildPrimaryAction() {
    if (poll == null) return null;

    if (_isManagerMode) {
      final isEnded = poll!.isEnded;
      return PcDialogAction(
        label: isEnded ? _l10n.pollDelete : _l10n.pollClose,
        onPressed: isEnded ? _deletePoll : _closePoll,
        danger: isEnded,
      );
    }

    if (_canVote) {
      return PcDialogAction(
        label: _l10n.pollSubmitVote,
        onPressed: selectedOptionIds.isEmpty ? null : _onSubmit,
      );
    }

    return null;
  }

  PcDialogAction? _buildSecondaryAction() {
    if (poll == null || !_canVote) return null;
    return PcDialogAction(
        label: _l10n.cancel, onPressed: () => Navigator.pop(context));
  }

  /// 移动端底部操作栏。管理模式实名投票时,导出与主操作并排。
  Widget? _buildMobileBottomBar() {
    final primary = _buildPrimaryAction();
    final export = _canExport;
    if (primary == null && !export) return null;

    final colors = context.colors;
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // 通栏底栏叠大档;危险操作只换背景色,禁用态走 M3 默认灰。
            if (export) ...[
              Expanded(
                child: FilledButton.tonal(
                  onPressed: _exportPoll,
                  style: AppTheme.largeButtonStyle(),
                  child: Text(_l10n.pollExport),
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (primary != null)
              Expanded(
                child: FilledButton(
                  onPressed: primary.onPressed,
                  style: primary.danger
                      ? FilledButton.styleFrom(backgroundColor: colors.danger)
                          .merge(AppTheme.largeButtonStyle())
                      : AppTheme.largeButtonStyle(),
                  child: Text(primary.label),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---- 内容 ----

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          _buildOptionsCard(),
          const SizedBox(height: 12),
          _buildMeta(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final colors = context.colors;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            poll!.title,
            style: AppText.xl.copyWith(
                fontWeight: FontWeight.w600, color: colors.textPrimary),
          ),
          if (poll!.desc.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              poll!.desc,
              style: AppText.base.copyWith(color: colors.textSecondary),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              FutureBuilder<UserInfo?>(
                future: Imclient.getUserInfo(poll!.creatorId),
                builder: (context, snapshot) {
                  final creatorInfo = snapshot.data;
                  final creatorName = creatorInfo?.displayName ??
                      creatorInfo?.name ??
                      poll!.creatorId;
                  return Expanded(
                    child: Row(
                      children: [
                        Portrait(
                          creatorInfo?.portrait ?? '',
                          '',
                          width: 24,
                          height: 24,
                          borderRadius: 12,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _l10n.pollCreatorFormat(creatorName),
                            style: AppText.xs
                                .copyWith(color: colors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildStatusChip(),
            ],
          ),
        ],
      ),
    );
  }

  /// 状态徽标:进行中(蓝) / 已投票(绿) / 已结束(灰)。
  Widget _buildStatusChip() {
    final colors = context.colors;
    final String label;
    final Color fg;
    final Color bg;

    if (poll!.isEnded) {
      label = _l10n.pollStatusEnded;
      fg = colors.textTertiary;
      bg = colors.hairlineSoft;
    } else if (poll!.hasVoted) {
      label = _l10n.pollAlreadyVoted;
      fg = colors.success;
      bg = colors.successSoft;
    } else {
      label = _l10n.pollStatusActive;
      fg = colors.accent;
      bg = colors.accentSoft;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: AppText.xxs.copyWith(color: fg)),
    );
  }

  Widget _buildOptionsCard() {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < poll!.options.length; i++) ...[
            if (i > 0) const Divider(),
            _buildOptionRow(poll!.options[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionRow(PollOption option) {
    final colors = context.colors;
    final isSelected = selectedOptionIds.contains(option.optionId);
    final isMyVote =
        !_isManagerMode && poll!.myOptionIds.contains(option.optionId);
    final showResult = poll!.shouldShowResult;

    // 未出结果时靠勾选框表达选中;出结果后靠票数条,行底色再上色就太花了。
    final highlight = _canVote && isSelected;

    return InkWell(
      onTap: _canVote ? () => _onOptionSelected(option.optionId) : null,
      child: Container(
        color: highlight ? colors.accentSoft : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (_canVote) ...[
                  _buildCheckMark(isSelected),
                  const SizedBox(width: 12),
                ] else if (isMyVote) ...[
                  Icon(Icons.check_circle, size: 20, color: colors.accent),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    option.optionText,
                    style: AppText.base.copyWith(
                      color: isMyVote || isSelected
                          ? colors.accent
                          : colors.textPrimary,
                      fontWeight:
                          isMyVote ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ),
                if (showResult) ...[
                  const SizedBox(width: 12),
                  Text(
                    '${option.voteCount}${_l10n.pollVotes} · ${option.votePercent}%',
                    style: AppText.xs.copyWith(
                        color: isMyVote ? colors.accent : colors.textSecondary),
                  ),
                ],
              ],
            ),
            // 票数条:自己投的那项走主色,其余走灰阶 —— 结果的可读性来自长度,不是颜色。
            if (showResult) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: (option.votePercent.clamp(0, 100)) / 100,
                  minHeight: 4,
                  backgroundColor: colors.hairlineSoft,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      isMyVote ? colors.accent : colors.textTertiary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 单选圆形、多选方形 —— 形状要和「能选几个」对得上。
  Widget _buildCheckMark(bool isSelected) {
    final colors = context.colors;
    final isSingle = poll!.isSingleChoice;
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: isSingle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isSingle ? null : BorderRadius.circular(4),
        border: Border.all(
          color: isSelected ? colors.accent : colors.textTertiary,
          width: 1.5,
        ),
        color: isSelected ? colors.accent : Colors.transparent,
      ),
      child: isSelected
          ? Icon(Icons.check, size: 14, color: colors.onAccent)
          : null,
    );
  }

  /// 页脚一行灰字:实名/匿名 · N人参与 · 剩余时间 · 状态
  Widget _buildMeta() {
    final colors = context.colors;
    final parts = <String>[
      poll!.anonymous == 1 ? _l10n.pollAnonymous : _l10n.pollNamed,
      _l10n.pollVoterCount(poll!.voterCount),
    ];

    final remaining = _formatRemainingTime();
    if (remaining.isNotEmpty) {
      parts.add(remaining);
    }

    if (poll!.isEnded) {
      parts.add(_l10n.pollStatusEnded);
    } else if (poll!.hasVoted) {
      parts.add(_l10n.pollAlreadyVoted);
    }

    return SizedBox(
      width: double.infinity,
      child: Text(
        parts.join(' · '),
        style: AppText.xs.copyWith(color: colors.textTertiary),
        textAlign: TextAlign.center,
      ),
    );
  }

  String _formatRemainingTime() {
    if (poll!.isEnded) return '';

    if (poll!.endTime <= 0) {
      return _l10n.pollNoDeadline;
    }

    final remaining = poll!.endTime - DateTime.now().millisecondsSinceEpoch;
    if (remaining <= 0) return '';

    final minutes = remaining ~/ 60000;
    final hours = minutes ~/ 60;
    final days = hours ~/ 24;

    if (days > 0) {
      return _l10n.pollDaysLeft(days);
    } else if (hours > 0) {
      return _l10n.pollHoursLeft(hours);
    }
    return _l10n.pollMinutesLeft(minutes);
  }
}
