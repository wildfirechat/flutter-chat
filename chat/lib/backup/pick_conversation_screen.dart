import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/conversation_info.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/home/conversation_list_widget.dart';
import 'package:chat/widget/app_bar_actions.dart';

import 'backup_destination_screen.dart';

class PickConversationScreen extends StatefulWidget {
  final void Function(List<ConversationInfo> conversations, bool includeMedia)?
      onSelected;

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
    final convs = await Imclient.getConversationInfos([
      ConversationType.Single,
      ConversationType.Group,
      ConversationType.Channel
    ], [
      0
    ]);
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

  void _toggleConversation(ConversationInfo info, bool? checked) {
    setState(() {
      if (checked == true) {
        _selectedConversations.add(info);
      } else {
        _selectedConversations.remove(info);
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
          AppBarTextAction(
            label: l10n.next,
            onPressed: _selectedConversations.isEmpty ? null : _onNext,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                CheckboxListTile(
                  title: Text(l10n.selectAll),
                  value:
                      _selectedConversations.length == _conversations.length &&
                          _conversations.isNotEmpty,
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
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: _conversations.length,
                    itemExtent: conversationItemExtent(context),
                    itemBuilder: (context, index) {
                      final info = _conversations[index];
                      final isChecked = _selectedConversations.contains(info);
                      return ConversationListItem(
                        info,
                        key: ValueKey(
                            '${info.conversation.conversationType}-${info.conversation.target}-${info.conversation.line}'),
                        showSubtitle: false,
                        enableLongPress: false,
                        trailing: Checkbox(
                          value: isChecked,
                          onChanged: (checked) =>
                              _toggleConversation(info, checked),
                        ),
                        onTap: (conversation) =>
                            _toggleConversation(info, !isChecked),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
