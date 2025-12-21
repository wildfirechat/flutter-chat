import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/model/user_info.dart';
import 'package:chat/config.dart';
import 'package:chat/conversation/conversation_screen.dart';
import 'package:chat/utilities.dart';
import 'package:chat/widget/portrait.dart';

class SearchConversationResultView extends StatefulWidget {
  final Conversation conversation;
  final String keyword;

  const SearchConversationResultView({
    super.key,
    required this.conversation,
    required this.keyword,
  });

  @override
  State<SearchConversationResultView> createState() => _SearchConversationResultViewState();
}

class _SearchConversationResultViewState extends State<SearchConversationResultView> {
  late TextEditingController _controller;
  List<Message> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.keyword);
    _search(widget.keyword);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(String keyword) {
    if (keyword.isEmpty) {
      setState(() {
        _messages = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    Imclient.searchMessages(widget.conversation, keyword, true, 100, 0).then((messages) {
      if (mounted && keyword == _controller.text) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          decoration: const InputDecoration(
            hintText: '搜索',
            border: InputBorder.none,
          ),
          onChanged: (value) {
            _search(value);
          },
          textInputAction: TextInputAction.search,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _messages.isEmpty
              ? const Center(child: Text('没有找到相关消息'))
              : ListView.separated(
                  itemCount: _messages.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    var message = _messages[index];
                    return FutureBuilder<UserInfo?>(
                      future: Imclient.getUserInfo(message.fromUser),
                      builder: (context, snapshot) {
                        var userInfo = snapshot.data;
                        return ListTile(
                          leading: Portrait(
                            userInfo?.portrait ?? '',
                            Config.defaultUserPortrait,
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(userInfo?.displayName ?? message.fromUser),
                              Text(
                                Utilities.formatTime(message.serverTime),
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          subtitle: FutureBuilder<String>(
                            future: message.content.digest(message),
                            builder: (context, snapshot) {
                              return Text(
                                snapshot.data ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ConversationScreen(
                                  widget.conversation,
                                  toFocusMessageId: message.messageId,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
    );
  }
}
