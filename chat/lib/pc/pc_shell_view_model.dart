import 'package:flutter/foundation.dart';
import 'package:imclient/model/conversation.dart';

/// 桌面 Shell 的导航状态:侧栏选中的 tab 与会话列表选中的会话。
/// 仅在 PCHome 子树中提供,移动端不使用。
class PCShellViewModel extends ChangeNotifier {
  static const int tabChat = 0;
  static const int tabContact = 1;
  static const int tabMe = 2;

  int _selectedTab = tabChat;
  Conversation? _selectedConversation;

  int get selectedTab => _selectedTab;

  Conversation? get selectedConversation => _selectedConversation;

  void selectTab(int tab) {
    if (_selectedTab == tab) {
      return;
    }
    _selectedTab = tab;
    notifyListeners();
  }

  void selectConversation(Conversation? conversation) {
    if (_selectedConversation == conversation) {
      return;
    }
    _selectedConversation = conversation;
    notifyListeners();
  }
}
