import 'package:chat/widget/section_divider.dart';
import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/conversation_info.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/user_info.dart';

import '../viewmodel/user_view_model.dart';
import 'package:provider/provider.dart';

import 'backup_destination_screen.dart';

class PickConversationScreen extends StatefulWidget {
  const PickConversationScreen({Key? key}) : super(key: key);

  @override
  _PickConversationScreenState createState() => _PickConversationScreenState();
}

class _PickConversationScreenState extends State<PickConversationScreen> {
  List<ConversationInfo> _conversations = [];
  final Set<ConversationInfo> _selectedConversations = {};
  bool _isLoading = true;
  bool _includeMedia = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final convs = await Imclient.getConversationInfos(
        [ConversationType.Single, ConversationType.Group, ConversationType.Channel], [0]);
    // Filter out empty conversations or system ones if needed
    // For now, keep all user visible ones
    setState(() {
      _conversations = convs;
      // Default select all
      _selectedConversations.addAll(convs);
      _isLoading = false;
    });
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      if (value == true) {
        _selectedConversations.addAll(_conversations);
      } else {
        _selectedConversations.clear();
      }
    });
  }

  void _onNext() {
    if (_selectedConversations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one conversation')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BackupDestinationScreen(
          conversations: _selectedConversations.toList(),
          includeMedia: _includeMedia,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Conversations'),
        actions: [
          TextButton(
            onPressed: _selectedConversations.isEmpty ? null : _onNext,
            child: const Text('Next', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                CheckboxListTile(
                  title: const Text('Select All'),
                  value: _selectedConversations.length == _conversations.length && _conversations.isNotEmpty,
                  onChanged: _toggleSelectAll,
                ),
                CheckboxListTile(
                  title: const Text('Include Media'),
                  subtitle: const Text('Images, Videos, Files, etc.'),
                  value: _includeMedia,
                  onChanged: (val) {
                    setState(() {
                      _includeMedia = val ?? false;
                    });
                  },
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    itemCount: _conversations.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 0.5, indent: 70),
                    itemBuilder: (context, index) {
                      final info = _conversations[index];
                      return _ConversationItem(
                        info: info,
                        isChecked: _selectedConversations.contains(info),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedConversations.add(info);
                            } else {
                              _selectedConversations.remove(info);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _ConversationItem extends StatelessWidget {
  final ConversationInfo info;
  final bool isChecked;
  final ValueChanged<bool?> onChanged;

  const _ConversationItem({
    required this.info,
    required this.isChecked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final conversation = info.conversation;
    String title = conversation.target;
    // Widget portrait;

    // Simple resolution logic
    if (conversation.conversationType == ConversationType.Single) {
      return FutureBuilder<UserInfo?>(
        future: Imclient.getUserInfo(conversation.target),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            title = snapshot.data!.displayName ?? conversation.target;
          }
          return CheckboxListTile(
            title: Text(title),
            subtitle: Text("Type: Private"),
            value: isChecked,
            onChanged: onChanged,
            secondary: const Icon(Icons.person),
          );
        },
      );
    } else if (conversation.conversationType == ConversationType.Group) {
      return FutureBuilder<GroupInfo?>(
        future: Imclient.getGroupInfo(conversation.target),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            title = snapshot.data!.name ?? conversation.target;
          }
          return CheckboxListTile(
            title: Text(title),
            subtitle: Text("Type: Group"),
            value: isChecked,
            onChanged: onChanged,
            secondary: const Icon(Icons.group),
          );
        },
      );
    }

    return CheckboxListTile(
      title: Text(title),
      subtitle: Text("Type: ${conversation.conversationType}"),
      value: isChecked,
      onChanged: onChanged,
      secondary: const Icon(Icons.chat),
    );
  }
}
