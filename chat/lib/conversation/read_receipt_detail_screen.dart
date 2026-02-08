import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/user_info.dart';
import 'package:chat/config.dart';
import 'package:chat/widget/portrait.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ReadReceiptDetailScreen extends StatefulWidget {
  final Message message;

  const ReadReceiptDetailScreen(this.message, {super.key});

  @override
  State<ReadReceiptDetailScreen> createState() => _ReadReceiptDetailScreenState();
}

class _ReadReceiptDetailScreenState extends State<ReadReceiptDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<UserInfo> _readMembers = [];
  List<UserInfo> _unreadMembers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  void _loadData() async {
    if (widget.message.conversation.conversationType != ConversationType.Group) {
      return;
    }

    String groupId = widget.message.conversation.target;
    List<GroupMember>? members = await Imclient.getGroupMembers(groupId);
    if (members == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Filter members who joined before the message was sent
    int messageTime = widget.message.serverTime;
    List<GroupMember> validMembers = members.where((m) => m.createDt <= messageTime).toList();
    
    // Remove self
    validMembers.removeWhere((m) => m.memberId == Imclient.currentUserId);

    Map<String, int> readMap = await Imclient.getConversationRead(widget.message.conversation);

    List<String> readUserIds = [];
    List<String> unreadUserIds = [];

    for (var member in validMembers) {
      int? readTime = readMap[member.memberId];
      if (readTime != null && readTime >= messageTime) {
        readUserIds.add(member.memberId);
      } else {
        unreadUserIds.add(member.memberId);
      }
    }

    List<UserInfo> readUserInfos = await Imclient.getUserInfos(readUserIds, groupId: groupId);
    List<UserInfo> unreadUserInfos = await Imclient.getUserInfos(unreadUserIds, groupId: groupId);

    if (mounted) {
      setState(() {
        _readMembers = readUserInfos;
        _unreadMembers = unreadUserInfos;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.readReceiptDetail),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: AppLocalizations.of(context)!.readCount(_readMembers.length.toString())),
            Tab(text: AppLocalizations.of(context)!.unreadCount(_unreadMembers.length.toString())),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUserList(_readMembers),
                _buildUserList(_unreadMembers),
              ],
            ),
    );
  }

  Widget _buildUserList(List<UserInfo> users) {
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        var user = users[index];
        return ListTile(
          leading: Portrait(user.portrait ?? Config.defaultUserPortrait, Config.defaultUserPortrait),
          title: Text(user.displayName ?? user.userId),
        );
      },
    );
  }
}
