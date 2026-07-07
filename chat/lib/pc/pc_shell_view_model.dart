import 'package:flutter/widgets.dart';
import 'package:imclient/model/conversation.dart';
import 'package:avenginekit/engine/call_session.dart';

/// 桌面 Shell 的导航状态:侧栏选中的 tab、会话列表选中的会话、通话浮窗。
/// 仅桌面端在 main.dart 的 MultiProvider 中注册(应用级生命周期,跨登录复用),
/// 移动端不注册——共享代码用 app_navigator.dart 的入口,取不到时自动走移动端路径。
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
  String? _selectedContactItemId;

  CallSession? _activeCallSession;
  bool _callWindowMinimized = false;
  Offset _callWindowPosition = const Offset(120, 80);

  /// 重置导航状态。PCHome 的 initState 调用(登出后再登录不残留上个账号的选中态)。
  /// 不 notify:调用点处于构建期,新子树随后整体首建,自然读到重置后的值。
  void reset() {
    _selectedTab = tabChat;
    _selectedConversation = null;
    _selectedContactItemId = null;
    _activeCallSession = null;
    _callWindowMinimized = false;
    conversationOpener = null;
    pageOpener = null;
  }

  String? get selectedContactItemId => _selectedContactItemId;

  void selectContactItem(String? itemId) {
    if (_selectedContactItemId == itemId) {
      return;
    }
    _selectedContactItemId = itemId;
    notifyListeners();
  }

  CallSession? get activeCallSession => _activeCallSession;
  bool get callWindowMinimized => _callWindowMinimized;
  Offset get callWindowPosition => _callWindowPosition;

  void startCallSession(CallSession session) {
    _activeCallSession = session;
    _callWindowMinimized = false;
    _callWindowPosition = const Offset(120, 80);
    notifyListeners();
  }

  void endCallSession() {
    _activeCallSession = null;
    _callWindowMinimized = false;
    notifyListeners();
  }

  void minimizeCallWindow(bool minimize) {
    _callWindowMinimized = minimize;
    notifyListeners();
  }

  void setCallWindowPosition(Offset position) {
    _callWindowPosition = position;
    notifyListeners();
  }

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
