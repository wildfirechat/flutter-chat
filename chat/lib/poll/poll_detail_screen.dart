import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/poll_message_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/user_info.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';


import '../widget/portrait.dart';
import 'poll_model.dart';
import 'poll_service.dart';


/// 投票详情页
/// 
/// 与 Android 端 PollDetailActivity 对齐
class PollDetailScreen extends StatefulWidget {
  final Message? message;
  final int? pollId;

  const PollDetailScreen({super.key, this.message, this.pollId})
      : assert(message != null || pollId != null, 'message or pollId must be provided');

  /// 从消息进入（投票模式）
  factory PollDetailScreen.fromMessage({required Message message}) {
    return PollDetailScreen(message: message);
  }

  /// 从列表进入（管理模式）
  factory PollDetailScreen.fromList({required int pollId, String? groupId}) {
    return PollDetailScreen(pollId: pollId);
  }

  @override
  State<PollDetailScreen> createState() => _PollDetailScreenState();
}

class _PollDetailScreenState extends State<PollDetailScreen> {
  late int pollId;
  late String? groupId;
  late String currentUserId;

  Poll? poll;
  bool isLoading = true;
  Set<int> selectedOptionIds = {};

  bool get _isServiceAvailable => PollService.isAvailable;

  /// 是否是管理模式（从列表进入且是创建者）
  bool get _isManagerMode => poll?.isCreator == true && widget.message == null;

  /// 是否可以投票
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
      groupId = content.groupId;
    } else {
      pollId = widget.pollId!;
      groupId = null;
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
      setState(() {
        poll = result;
        isLoading = false;
        // 恢复已选择的选项（仅投票模式下）
        if (!_isManagerMode) {
          selectedOptionIds = Set.from(result.myOptionIds);
        }
      });
      // 更新本地消息（如果有变化）
      _updateLocalMessageIfNeeded();
    } catch (e) {
      setState(() => isLoading = false);
      Fluttertoast.showToast(msg: '${_l10n.pollLoadFailed}: $e');
    }
  }

  /// 如果本地消息内容有变化，更新本地消息
  void _updateLocalMessageIfNeeded() {
    if (widget.message == null || widget.message!.content is! PollMessageContent) {
      return;
    }

    final content = widget.message!.content as PollMessageContent;
    bool needUpdate = false;

    // 检查状态是否有变化
    if (poll!.status != content.status) {
      content.status = poll!.status;
      needUpdate = true;
    }

    // 检查总票数是否有变化
    if (poll!.totalVotes != content.totalVotes) {
      content.totalVotes = poll!.totalVotes;
      needUpdate = true;
    }

    // 检查是否已过期
    final now = DateTime.now().millisecondsSinceEpoch;
    if (poll!.endTime > 0 && poll!.endTime < now && content.endTime >= now) {
      content.status = 1;
      needUpdate = true;
    }

    // 如果有变化，更新本地消息
    if (needUpdate) {
      Imclient.updateMessage(widget.message!.messageId, content);
    }
  }

  String _buildTitle() {
    final l10n = _l10n;
    // 多选投票模式下显示已选数量
    if (poll != null && _canVote && poll!.isMultiChoice && selectedOptionIds.isNotEmpty) {
      return l10n.pollSelectedCount(selectedOptionIds.length, poll!.maxSelect);
    }
    return l10n.pollDetail;
  }

  List<Widget> _buildAppBarActions() {
    // 管理模式：显示转发按钮（仅创建者）
    if (_isManagerMode) {
      return [
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: _forwardPoll,
        ),
      ];
    }

    // 投票模式：根据是否可以投票显示提交按钮
    if (_canVote && selectedOptionIds.isNotEmpty) {
      return [
        TextButton(
          onPressed: _onSubmit,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
          ),
          child: Text(_l10n.pollSubmitVote),
        ),
      ];
    }

    return [];
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

  void _forwardPoll() {
    if (poll == null) return;

    // 构建投票消息内容
    final content = PollMessageContent();
    content.pollId = poll!.pollId.toString();
    content.groupId = poll!.groupId;
    content.creatorId = poll!.creatorId;
    content.title = poll!.title;
    content.desc = poll!.desc;
    content.visibility = poll!.visibility;
    content.type = poll!.type;
    content.anonymous = poll!.anonymous;
    content.status = poll!.status;
    content.endTime = poll!.endTime;
    content.totalVotes = poll!.totalVotes;

    // 构建消息对象
    final forwardMessage = Message();
    forwardMessage.content = content;
    forwardMessage.conversation = Conversation(
      conversationType: ConversationType.Group,
      target: poll!.groupId,
    );

    // TODO: 跳转到转发页面
    Fluttertoast.showToast(msg: '转发功能待实现');
  }

  void _onOptionSelected(int optionId) {
    if (!_canVote) return;

    setState(() {
      if (poll!.isSingleChoice) {
        // 单选
        if (selectedOptionIds.contains(optionId)) {
          selectedOptionIds.remove(optionId);
        } else {
          selectedOptionIds.clear();
          selectedOptionIds.add(optionId);
        }
      } else {
        // 多选
        if (selectedOptionIds.contains(optionId)) {
          selectedOptionIds.remove(optionId);
        } else {
          if (poll!.maxSelect > 0 && selectedOptionIds.length >= poll!.maxSelect) {
            Fluttertoast.showToast(
              msg: _l10n.pollMaxSelectLimit(poll!.maxSelect),
            );
            return;
          }
          selectedOptionIds.add(optionId);
        }
      }
    });
  }

  Future<void> _closePoll() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_l10n.confirm),
        content: Text(_l10n.pollCloseConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _doClosePoll();
            },
            child: Text(_l10n.close, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _doClosePoll() async {
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_l10n.confirm),
        content: Text(_l10n.pollDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _doDeletePoll();
            },
            child: Text(_l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _doDeletePoll() async {
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

      // 生成 CSV 内容
      final buffer = StringBuffer();
      // UTF-8 BOM
      buffer.write('\uFEFF');
      buffer.write('${_l10n.pollCsvOption},${_l10n.pollCsvUser},${_l10n.pollCsvTime}\n');

      for (final detail in details) {
        final timeStr = DateTime.fromMillisecondsSinceEpoch(detail.voteTime)
            .toString()
            .substring(0, 19);
        buffer.write('${_escapeCsv(detail.optionText)},${_escapeCsv(detail.userName)},$timeStr\n');
      }

      // 生成安全的文件名
      final safeTitle = _safeFileName(poll!.title);
      final fileName = '${safeTitle}_${_l10n.pollDetailsSuffix}.csv';

      // 写入临时文件
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(buffer.toString(), encoding: const Utf8Codec());

      // 分享文件
      await _shareFile(file);
    } catch (e) {
      Fluttertoast.showToast(msg: '${_l10n.pollExportFailed}: $e');
    }
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

    // 替换文件系统中的非法字符
    String safeName = fileName.replaceAll(RegExp(r'[/\\?%*|"<>]'), '_');

    // 限制文件名长度
    if (safeName.length > 50) {
      safeName = safeName.substring(0, 50);
    }

    return safeName.isEmpty ? _l10n.pollDefaultFileName : safeName;
  }

  Future<void> _shareFile(File file) async {
    // 由于缺少 share_plus 依赖，暂时只显示保存成功提示
    Fluttertoast.showToast(
      msg: '${_l10n.pollShareDetails}: ${file.path}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // gray5
      appBar: AppBar(
        title: Text(_buildTitle()),
        actions: _buildAppBarActions(),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : poll == null
              ? Center(child: Text(_l10n.pollLoadFailed))
              : _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // 可滚动内容
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header（白色背景）
                _buildHeader(),
                // 选项列表（白色背景，与 Header 间隔 8dp）
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  color: Colors.white,
                  child: _buildOptionsList(),
                ),
                // Footer（灰色背景，与选项列表间隔 8dp）
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  child: _buildFooter(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Header - 与 Android poll_detail_header.xml 对齐
  Widget _buildHeader() {
    return FutureBuilder<UserInfo?>(
      future: Imclient.getUserInfo(poll!.creatorId),
      builder: (context, snapshot) {
        final creatorInfo = snapshot.data;
        final creatorName = creatorInfo?.displayName ??
            creatorInfo?.name ??
            poll!.creatorId;

        return Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 创建者信息行 - 与 Android 对齐
              Row(
                children: [
                  // 头像 40dp
                  Portrait(
                    creatorInfo?.portrait ?? '',
                    '',
                    width: 40,
                    height: 40,
                    borderRadius: 20,
                  ),
                  const SizedBox(width: 12),
                  // 创建者名称 - "由 %s 发起" 格式
                  Expanded(
                    child: Text(
                      _l10n.pollCreatorFormat(creatorName),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 状态标签（右侧）
                  _buildHeaderStatusTag(),
                ],
              ),
              const SizedBox(height: 16),

              // 标题 18sp 粗体
              Text(
                poll!.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),

              // 描述 14sp 灰色
              if (poll!.desc.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  poll!.desc,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Header 状态标签 - 显示剩余时间或状态
  Widget _buildHeaderStatusTag() {
    String text;
    Color color;

    final remainingTime = poll!.getRemainingTimeText();
    if (remainingTime != null && remainingTime.isNotEmpty) {
      text = remainingTime;
      color = Colors.orange;
    } else if (poll!.isEnded) {
      text = _l10n.pollStatusEnded;
      color = Colors.grey;
    } else {
      return const SizedBox.shrink();
    }

    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: color,
      ),
    );
  }

  /// 选项列表 - 与 Android item_poll_vote_option.xml 对齐
  Widget _buildOptionsList() {
    return Column(
      children: poll!.options.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final isSelected = selectedOptionIds.contains(option.optionId);
        final showResult = poll!.shouldShowResult;
        final hasVoted = !_canVote;
        // 是否是我投票的选项（非管理模式下）
        final isMyVote = !_isManagerMode && poll!.myOptionIds.contains(option.optionId);

        // 是否显示选中背景
        final showSelectedBg = isMyVote || (isSelected && !hasVoted) || (isSelected && hasVoted);

        return InkWell(
          onTap: () => _onOptionSelected(option.optionId),
          child: Container(
            // 固定高度 56dp，与 Android 对齐
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: showSelectedBg ? const Color(0xFFE8F4FD) : Colors.white,
              border: Border(
                bottom: index < poll!.options.length - 1
                    ? BorderSide(color: Colors.grey[200]!)
                    : BorderSide.none,
              ),
            ),
            child: Row(
              children: [
                // 左侧选择按钮或百分比
                _buildOptionLeft(option, isSelected, isMyVote),
                const SizedBox(width: 12),

                // 选项文字 - 16sp
                Expanded(
                  child: Text(
                    option.optionText,
                    style: TextStyle(
                      fontSize: 16,
                      color: _getOptionTextColor(isMyVote, isSelected),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // 右侧百分比（显示结果时）
                if (showResult) ...[
                  const SizedBox(width: 12),
                  Text(
                    '${option.votePercent}%',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 选项左侧指示器
  Widget _buildOptionLeft(PollOption option, bool isSelected, bool isMyVote) {
    final showResult = poll!.shouldShowResult;

    // 管理模式：隐藏选择框，只留间距
    if (_isManagerMode) {
      return const SizedBox(width: 0);
    }

    // 可以投票：显示选择按钮（24x24）
    if (_canVote) {
      return _buildVoteCheckButton(isSelected);
    }

    // 已投票或已结束：显示选中标记或空白
    if (showResult && isMyVote) {
      // 已投票选项：蓝色圆形对勾
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: Color(0xFF576b95),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check,
          color: Colors.white,
          size: 16,
        ),
      );
    }

    // 其他情况：空白占位（保持对齐）
    return const SizedBox(width: 24);
  }

  /// 投票选择按钮 - 24x24
  Widget _buildVoteCheckButton(bool isSelected) {
    if (poll!.isSingleChoice) {
      // 单选：圆形
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? const Color(0xFF576b95) : Colors.grey[400]!,
            width: 2,
          ),
          color: isSelected ? const Color(0xFF576b95) : Colors.transparent,
        ),
        child: isSelected
            ? const Icon(
                Icons.check,
                color: Colors.white,
                size: 16,
              )
            : null,
      );
    } else {
      // 多选：方形
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? const Color(0xFF576b95) : Colors.grey[400]!,
            width: 2,
          ),
          color: isSelected ? const Color(0xFF576b95) : Colors.transparent,
        ),
        child: isSelected
            ? const Icon(
                Icons.check,
                color: Colors.white,
                size: 16,
              )
            : null,
      );
    }
  }

  Color _getOptionTextColor(bool isMyVote, bool isSelected) {
    if (isMyVote) {
      return const Color(0xFF576b95);
    }
    if (isSelected && _canVote) {
      return const Color(0xFF576b95);
    }
    return const Color(0xFF333333);
  }

  /// Footer - 与 Android poll_detail_footer.xml 对齐
  Widget _buildFooter() {
    final statusParts = <String>[];

    // 投票类型
    statusParts.add(poll!.anonymous == 1 ? _l10n.pollAnonymous : _l10n.pollNamed);

    // 参与人数
    statusParts.add(_l10n.pollVoterCount(poll!.voterCount));

    // 剩余时间
    final remainingTime = _formatRemainingTime();
    if (remainingTime.isNotEmpty) {
      statusParts.add(remainingTime);
    }

    // 状态
    if (poll!.isEnded) {
      statusParts.add(_l10n.pollStatusEnded);
    } else if (poll!.hasVoted) {
      statusParts.add(_l10n.pollAlreadyVoted);
    }

    // 灰色背景，居中显示
    return Container(
      width: double.infinity,
      color: const Color(0xFFF5F5F5), // gray5，与页面背景一致
      padding: const EdgeInsets.all(16),
      child: Text(
        statusParts.join(' · '),
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[600],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  String _formatRemainingTime() {
    if (poll!.isEnded) return '';

    if (poll!.endTime <= 0) {
      return _l10n.pollNoDeadline;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final remaining = poll!.endTime - now;

    if (remaining <= 0) return '';

    final minutes = remaining ~/ 60000;
    final hours = minutes ~/ 60;
    final days = hours ~/ 24;

    if (days > 0) {
      return _l10n.pollDaysLeft(days);
    } else if (hours > 0) {
      return _l10n.pollHoursLeft(hours);
    } else {
      return _l10n.pollMinutesLeft(minutes);
    }
  }

  /// 底部操作栏
  Widget? _buildBottomBar() {
    if (poll == null) return null;

    // 管理模式：显示导出/关闭/删除按钮
    if (_isManagerMode) {
      return _buildManagerBottomBar();
    }

    // 投票模式：显示提交按钮（未投票且未结束时）
    if (_canVote) {
      return _buildVoteBottomBar();
    }

    return null;
  }

  /// 管理模式底部栏
  Widget _buildManagerBottomBar() {
    final isAnonymous = poll!.anonymous == 1;
    final isEnded = poll!.isEnded;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 12 + MediaQuery.of(context).padding.bottom,
      ),
      child: SafeArea(
        child: isAnonymous
            ? _buildAnonymousManagerButtons(isEnded)
            : _buildNamedManagerButtons(isEnded),
      ),
    );
  }

  /// 匿名投票管理按钮
  Widget _buildAnonymousManagerButtons(bool isEnded) {
    if (isEnded) {
      return ElevatedButton(
        onPressed: _deletePoll,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        child: Text(
          _l10n.pollDelete,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    } else {
      return ElevatedButton(
        onPressed: _closePoll,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF576b95),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        child: Text(
          _l10n.pollClose,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
  }

  /// 实名投票管理按钮
  Widget _buildNamedManagerButtons(bool isEnded) {
    return Row(
      children: [
        // 导出按钮
        Expanded(
          flex: 1,
          child: OutlinedButton(
            onPressed: _exportPoll,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF576b95),
              side: const BorderSide(color: Color(0xFF576b95)),
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: Text(
              _l10n.pollExport,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // 关闭/删除按钮
        Expanded(
          flex: 1,
          child: ElevatedButton(
            onPressed: isEnded ? _deletePoll : _closePoll,
            style: ElevatedButton.styleFrom(
              backgroundColor: isEnded ? Colors.red : const Color(0xFF576b95),
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: Text(
              isEnded ? _l10n.pollDelete : _l10n.pollClose,
              style: const TextStyle(
                fontSize:  15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 投票模式底部栏
  Widget _buildVoteBottomBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 12 + MediaQuery.of(context).padding.bottom,
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: selectedOptionIds.isNotEmpty ? _onSubmit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF576b95),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          child: Text(
            _l10n.pollSubmitVote,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
