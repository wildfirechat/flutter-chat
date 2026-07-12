import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/conversation_info.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/user_info.dart';
import 'package:chat/l10n/app_localizations.dart';

import 'backup_destination_screen.dart';

class PickConversationScreen extends StatefulWidget {
  final void Function(List<ConversationInfo> conversations, bool includeMedia)? onSelected;

  const PickConversationScreen({Key? key, this.onSelected}) : super(key: key);

  @override
  _PickConversationScreenState createState() => _PickConversationScreenState();
}

class _PickConversationScreenState extends State<PickConversationScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;
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
        SnackBar(content: Text(l10n.pleaseSelectConversation)),
      );
      return;
    }
    if (widget.onSelected != null) {
      widget.onSelected!(_selectedConversations.toList(), _includeMedia);
      Navigator.pop(context);
    } else {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.selectConversations),
        actions: [
          TextButton(
            onPressed: _selectedConversations.isEmpty ? null : _onNext,
            child: Text(l10n.next, style: const TextStyle(color: Colors.black)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                CheckboxListTile(
                  title: Text(l10n.selectAll),
                  value: _selectedConversations.length == _conversations.length && _conversations.isNotEmpty,
                  onChanged: _toggleSelectAll,
                ),
                CheckboxListTile(
                  title: Text(l10n.includeMedia),
                  subtitle: Text(l10n.includeMediaDesc),
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
                        l10n: l10n,
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
  final AppLocalizations l10n;

  const _ConversationItem({
    required this.info,
    required this.isChecked,
    required this.onChanged,
    required this.l10n,
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
            subtitle: Text(l10n.conversationTypeSingle),
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
            subtitle: Text(l10n.conversationTypeGroup),
            value: isChecked,
            onChanged: onChanged,
            secondary: const Icon(Icons.group),
          );
        },
      );
    }

    return CheckboxListTile(
      title: Text(title),
      subtitle: Text(l10n.conversationTypeChannel),
      value: isChecked,
      onChanged: onChanged,
      secondary: const Icon(Icons.chat),
    );
  }
}
