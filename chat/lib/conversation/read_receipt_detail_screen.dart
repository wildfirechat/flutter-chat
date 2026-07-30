import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/user_info.dart';
import 'package:chat/config.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/utils/mesh_user_name.dart';
import 'package:chat/mesh/mesh_cache.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/widgets/pc_dialog.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/app_navigator.dart';
import 'package:chat/user_info_widget.dart';
import 'package:chat/utils/layout_scale.dart';
import 'package:chat/theme/app_typography.dart';

class ReadReceiptDetailScreen extends StatefulWidget {
  final Message message;
  final bool asDialog;

  const ReadReceiptDetailScreen(this.message,
      {super.key, this.asDialog = false});

  static Future<void> show(BuildContext context, Message message) {
    if (isDesktopShell) {
      return showPcDialog(
        context: context,
        width: 400,
        height: 480,
        builder: (_) => ReadReceiptDetailScreen(message, asDialog: true),
      );
    }
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReadReceiptDetailScreen(message)),
    );
  }

  @override
  State<ReadReceiptDetailScreen> createState() =>
      _ReadReceiptDetailScreenState();
}

class _ReadReceiptDetailScreenState extends State<ReadReceiptDetailScreen>
    with SingleTickerProviderStateMixin {
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
    if (widget.message.conversation.conversationType !=
        ConversationType.Group) {
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
    List<GroupMember> validMembers =
        members.where((m) => m.createDt <= messageTime).toList();

    // Remove self
    validMembers.removeWhere((m) => m.memberId == Imclient.currentUserId);

    Map<String, int> readMap =
        await Imclient.getConversationRead(widget.message.conversation);

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

    List<UserInfo> readUserInfos =
        await Imclient.getUserInfos(readUserIds, groupId: groupId);
    List<UserInfo> unreadUserInfos =
        await Imclient.getUserInfos(unreadUserIds, groupId: groupId);

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
    if (widget.asDialog) {
      final colors = context.colors;
      return PcDialogFrame(
        title: AppLocalizations.of(context)!.readReceiptDetail,
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              labelColor: colors.accent,
              unselectedLabelColor: colors.textSecondary,
              indicatorColor: colors.accent,
              tabs: [
                Tab(
                    text: AppLocalizations.of(context)!
                        .readCount(_readMembers.length.toString())),
                Tab(
                    text: AppLocalizations.of(context)!
                        .unreadCount(_unreadMembers.length.toString())),
              ],
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildUserList(_readMembers),
                        _buildUserList(_unreadMembers),
                      ],
                    ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.readReceiptDetail),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
                text: AppLocalizations.of(context)!
                    .readCount(_readMembers.length.toString())),
            Tab(
                text: AppLocalizations.of(context)!
                    .unreadCount(_unreadMembers.length.toString())),
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
    return ListView.separated(
      itemCount: users.length,
      separatorBuilder: (context, __) => Divider(
        indent: 16.0 +
            LayoutScale.watchScale(context, 40.0, cap: LayoutScale.iconCap) +
            16.0,
      ),
      itemBuilder: (context, index) {
        var user = users[index];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (widget.asDialog) {
                Navigator.pop(context); // Close the dialog on PC
              }
              openPage(context, UserInfoWidget(user.userId));
            },
            hoverColor: context.colors.hoverOverlay,
            child: Container(
              height: LayoutScale.watchScale(
                  context, isDesktopShell ? 52.0 : 56.0,
                  cap: LayoutScale.rowCap),
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Portrait(
                    user.portrait ?? Config.defaultUserPortrait,
                    Config.defaultUserPortrait,
                    width: 40,
                    height: 40,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: MeshCache.instance,
                      builder: (context, child) {
                        return MeshUserName(
                          user,
                          style: isDesktopShell ? AppText.base : AppText.lg,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
