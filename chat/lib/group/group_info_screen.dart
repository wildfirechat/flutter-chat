import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/viewmodel/group_view_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:chat/conversation/conversation_screen.dart';

class GroupInfoScreen extends StatefulWidget {
  final String groupId;
  final String? from;

  const GroupInfoScreen({Key? key, required this.groupId, this.from}) : super(key: key);

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GroupViewModel>(
      builder: (context, groupViewModel, child) {
        var groupInfo = groupViewModel.getGroupInfo(widget.groupId);
        if (groupInfo == null || groupInfo.updateDt == 0) {
          return Scaffold(
            appBar: AppBar(title: const Text("群组信息")),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text("群组信息")),
          body: _buildBody(context, groupInfo),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, GroupInfo groupInfo) {
    String name = groupInfo.remark != null && groupInfo.remark!.isNotEmpty
        ? groupInfo.remark!
        : groupInfo.name ?? '群聊';
    String portrait = groupInfo.portrait ?? '';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: portrait.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: portrait,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Icon(Icons.group, size: 80, color: Colors.grey),
                    errorWidget: (context, url, error) => const Icon(Icons.group, size: 80, color: Colors.grey),
                  )
                : const Icon(Icons.group, size: 80, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 40),
          _buildActionButton(groupInfo),
        ],
      ),
    );
  }

  Widget _buildActionButton(GroupInfo groupInfo) {
    String buttonText;
    bool isJoined = false;

    if (groupInfo.memberDt < -1) {
      buttonText = "加入群聊";
    } else if (groupInfo.memberDt == -1) {
      buttonText = "加入群聊";
    } else {
      buttonText = "进入群聊";
      isJoined = true;
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isLoading ? null : () => _onAction(groupInfo, isJoined),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Text(buttonText),
      ),
    );
  }

  void _onAction(GroupInfo groupInfo, bool isJoined) {
    if (isJoined) {
      _enterGroupChat();
    } else {
      _joinGroup();
    }
  }

  void _enterGroupChat() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationScreen(
          Conversation(conversationType: ConversationType.Group, target: widget.groupId),
        ),
      ),
    );
  }

  void _joinGroup() {
    setState(() {
      _isLoading = true;
    });

    Imclient.addGroupMembers(widget.groupId, [Imclient.currentUserId], () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _enterGroupChat();
      }
    }, (errorCode) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        Fluttertoast.showToast(msg: "加入失败: $errorCode");
      }
    });
  }
}
