import 'package:flutter/widgets.dart';
import 'package:imclient/model/conversation.dart';

/// 桌面 Shell 的导航状态:侧栏选中的 tab 与会话列表选中的会话。
/// 仅在 PCHome 子树中提供,移动端不使用。
class PCShellViewModel extends ChangeNotifier {
  static const int tabChat = 0;
  static const int tabContact = 1;
  static const int tabWork = 2;
  static const int tabDiscovery = 3;
  static const int tabMe = 4;

  /// 由 PCHome 注入。深层复用组件(如用户信息卡片、右栏用户详情的“发消息”)通过
  /// [openConversation]/[openPage] 请求在右栏打开内容并同步选中态,而不是自己 push 页面。
  void Function(Conversation conversation, {int? toFocusMessageId})? conversationOpener;
  void Function(Widget page)? pageOpener;

  int _selectedTab = tabChat;
  Conversation? _selectedConversation;

  void openConversation(Conversation conversation, {int? toFocusMessageId}) {
    conversationOpener?.call(conversation, toFocusMessageId: toFocusMessageId);
  }

  void openPage(Widget page) {
    pageOpener?.call(page);
  }

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
