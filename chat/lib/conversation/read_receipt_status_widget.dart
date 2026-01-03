import 'dart:async';

import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_member.dart';
import 'package:chat/conversation/read_receipt_detail_screen.dart';

class ReadReceiptStatusWidget extends StatefulWidget {
  final Message message;

  const ReadReceiptStatusWidget(this.message, {super.key});

  @override
  State<ReadReceiptStatusWidget> createState() => _ReadReceiptStatusWidgetState();
}

class _ReadReceiptStatusWidgetState extends State<ReadReceiptStatusWidget> {
  bool _isEnabled = false;
  int _groupReadCount = 0;
  int _groupTotalCount = 0;
  bool _isSingleConversationRead = false;
  StreamSubscription<MessageReadedEvent>? _readEventSubscription;

  @override
  void initState() {
    super.initState();
    _checkStatus();
    _readEventSubscription = Imclient.IMEventBus.on<MessageReadedEvent>().listen((event) {
      if (!_isEnabled) return;
      bool needUpdate = false;
      for (var report in event.readedReports) {
        if (report.conversation == widget.message.conversation) {
          needUpdate = true;
          break;
        }
      }
      if (needUpdate) {
        if (widget.message.conversation.conversationType == ConversationType.Single) {
          _updateSingleReadStatus();
        } else if (widget.message.conversation.conversationType == ConversationType.Group) {
          _updateGroupReadStatus();
        }
      }
    });
  }

  @override
  void dispose() {
    _readEventSubscription?.cancel();
    super.dispose();
  }

  void _checkStatus() async {
    bool receiptEnabled = await Imclient.isReceiptEnabled();
    bool userEnabled = await Imclient.isUserEnableReceipt();
    bool singleReceiptEnabled = receiptEnabled && userEnabled;
    if (widget.message.conversation.conversationType == ConversationType.Single) {
      if (mounted) {
        setState(() {
          _isEnabled = singleReceiptEnabled;
        });
      }
      if (singleReceiptEnabled) {
        _updateSingleReadStatus();
      }
    } else if (widget.message.conversation.conversationType == ConversationType.Group) {
      bool groupReceiptEnabled = receiptEnabled && userEnabled && await Imclient.isGroupReceiptEnabled();
      if (groupReceiptEnabled) {
        _updateGroupReadStatus();
      }
      if (mounted) {
        setState(() {
          _isEnabled = groupReceiptEnabled;
        });
      }
    }
  }

  void _updateSingleReadStatus() async {
    Map<String, int> readMap = await Imclient.getConversationRead(widget.message.conversation);
    int? readTime = readMap[widget.message.conversation.target];
    bool read = readTime != null && readTime >= widget.message.serverTime;
    if (mounted && _isSingleConversationRead != read) {
      setState(() {
        _isSingleConversationRead = read;
      });
    }
  }
  void _updateGroupReadStatus() async {
    String groupId = widget.message.conversation.target;
    List<GroupMember>? members = await Imclient.getGroupMembers(groupId);
    if (members == null) return;

    int messageTime = widget.message.serverTime;
    // Filter members who joined before the message was sent and exclude self
    List<GroupMember> validMembers = members.where((m) => m.createDt <= messageTime && m.memberId != Imclient.currentUserId).toList();

    if (validMembers.isEmpty) return;

    Map<String, int> readMap = await Imclient.getConversationRead(widget.message.conversation);
    int readCount = 0;
    for (var member in validMembers) {
      int? readTime = readMap[member.memberId];
      if (readTime != null && readTime >= messageTime) {
        readCount++;
      }
    }

    if (mounted && _groupTotalCount != validMembers.length && _groupReadCount != readCount) {
      setState(() {
        _groupTotalCount = validMembers.length;
        _groupReadCount = readCount;
      });
    }
  }

  @override
  void didUpdateWidget(covariant ReadReceiptStatusWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isEnabled) {
      if (widget.message.conversation.conversationType == ConversationType.Group) {
        _updateGroupReadStatus();
      } else if (widget.message.conversation.conversationType == ConversationType.Single) {
        _updateSingleReadStatus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isEnabled) {
      return Container();
    }

    if (widget.message.conversation.conversationType == ConversationType.Single) {
      return Padding(
        padding: const EdgeInsets.only(right: 4, bottom: 2),
        child: Icon(
          Icons.check,
          size: 12,
          color: _isSingleConversationRead ? Colors.blue : Colors.grey,
        ),
      );
    } else if (widget.message.conversation.conversationType == ConversationType.Group) {
      if (_groupTotalCount == 0) {
        return Container();
      }
      double progress = _groupReadCount / _groupTotalCount;
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReadReceiptDetailScreen(widget.message),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(right: 4, bottom: 2),
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 2,
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
          ),
        ),
      );
    }

    return Container();
  }
}
