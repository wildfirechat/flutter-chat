import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'poll_model.dart';
import 'poll_service.dart';
import 'poll_detail_screen.dart';

class PollListScreen extends StatefulWidget {
  final String? groupId;

  const PollListScreen({super.key, this.groupId});

  @override
  State<PollListScreen> createState() => _PollListScreenState();
}

class _PollListScreenState extends State<PollListScreen> {
  List<Poll> _pollList = [];
  bool _isLoading = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadPolls();
  }

  Future<void> _loadPolls() async {
    if (_isLoading) return;

    if (!PollService.isAvailable) {
      Fluttertoast.showToast(
        msg: AppLocalizations.of(context)!.pollServiceNotConfigured,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final polls = await PollService.getMyPolls();
      if (mounted) {
        setState(() {
          _pollList = polls;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        Fluttertoast.showToast(
          msg: '${AppLocalizations.of(context)!.pollLoadFailed}: $e',
        );
      }
    }
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      final polls = await PollService.getMyPolls();
      if (mounted) {
        setState(() {
          _pollList = polls;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _deletePoll(Poll poll) async {
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirm),
        content: Text(l10n.pollDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await PollService.delete(poll.pollId);
      if (mounted) {
        Fluttertoast.showToast(msg: l10n.deleteSuccess);
        _loadPolls();
      }
    } catch (e) {
      Fluttertoast.showToast(msg: '${l10n.deleteFailed}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myPolls),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading && _pollList.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pollList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.poll_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              l10n.pollEmptyList,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _pollList.length,
      itemBuilder: (context, index) {
        final poll = _pollList[index];
        return _buildPollItem(poll);
      },
    );
  }

  Widget _buildPollItem(Poll poll) {
    final l10n = AppLocalizations.of(context)!;

    return Dismissible(
      key: Key('poll_${poll.pollId}'),
      direction: poll.isCreator ? DismissDirection.endToStart : DismissDirection.none,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      confirmDismiss: (direction) async {
        if (poll.isCreator) {
          await _deletePoll(poll);
          return false; // 手动处理删除
        }
        return false;
      },
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PollDetailScreen(pollId: poll.pollId),
            ),
          ).then((_) => _loadPolls());
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey[200]!),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      poll.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusTag(poll),
                ],
              ),
              if (poll.desc.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  poll.desc,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 16,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${poll.voterCount}${l10n.pollPeopleCount}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.how_to_vote_outlined,
                    size: 16,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${poll.totalVotes}${l10n.pollVotes}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                  const Spacer(),
                  if (poll.getRemainingTimeText() != null)
                    Text(
                      poll.getRemainingTimeText()!,
                      style: TextStyle(
                        fontSize: 12,
                        color: poll.isEnded ? Colors.grey : Colors.green,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusTag(Poll poll) {
    String text;
    Color color;
    Color bgColor;

    if (poll.status == 1) {
      text = AppLocalizations.of(context)!.pollStatusEnded;
      color = const Color(0xFF999999);
      bgColor = const Color(0xFFF5F5F5);
    } else if (poll.hasVoted) {
      text = AppLocalizations.of(context)!.pollHasVoted;
      color = const Color(0xFF4CAF50);
      bgColor = const Color(0xFFE8F5E9);
    } else {
      text = AppLocalizations.of(context)!.pollStatusActive;
      color = const Color(0xFF576b95);
      bgColor = const Color(0xFFE8F0FE);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
        ),
      ),
    );
  }
}
