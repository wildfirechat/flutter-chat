import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/user_info.dart';

import 'package:chat/repo/user_repo.dart';
import 'package:chat/viewmodel/pick_user_view_model.dart';

/// 建群结果:成功带 groupId,失败带错误码。
class CreateGroupResult {
  final String? groupId;
  final int? errorCode;

  const CreateGroupResult.success(String this.groupId) : errorCode = null;

  const CreateGroupResult.failure(int this.errorCode) : groupId = null;

  bool get isSuccess => groupId != null;
}

/// 转发选目标的状态机。不持有 BuildContext,不做导航,可单测。
///
/// 两种形态:
/// - 选会话(默认):在最近聊天 / 搜索结果里勾选转发目标
/// - 选成员建群:从好友列表挑人建群。建完之后做什么由界面决定——
///   移动端退回选会话流程走确认弹窗(与微信一致),桌面端直接创建并发送。
class ForwardTargetController extends ChangeNotifier {
  ForwardTargetController({bool multiSelect = false})
      : _isMultiSelect = multiSelect;

  static const int _maxGroupMembers = 1024;
  static const int _maxGroupNameLength = 24;

  final List<Conversation> _selectedConversations = [];
  bool _isMultiSelect;
  bool _isSelectingMembers = false;
  bool _creatingGroup = false;
  bool _disposed = false;
  PickUserViewModel? _pickUserViewModel;

  List<Conversation> get selectedConversations =>
      List.unmodifiable(_selectedConversations);

  bool get hasSelection => _selectedConversations.isNotEmpty;

  bool get isMultiSelect => _isMultiSelect;

  bool get isSelectingMembers => _isSelectingMembers;

  bool get creatingGroup => _creatingGroup;

  /// 好友列表加载完成前为 null,界面据此显示 loading。
  PickUserViewModel? get pickUserViewModel => _pickUserViewModel;

  bool isSelected(Conversation conversation) =>
      _selectedConversations.any((c) => _isSameConversation(c, conversation));

  void toggleSelection(Conversation conversation) {
    if (isSelected(conversation)) {
      _selectedConversations
          .removeWhere((c) => _isSameConversation(c, conversation));
    } else {
      _selectedConversations.add(conversation);
    }
    notifyListeners();
  }

  void toggleMultiSelect() {
    _isMultiSelect = !_isMultiSelect;
    if (!_isMultiSelect) {
      _selectedConversations.clear();
    }
    notifyListeners();
  }

  /// 进入建群选人形态。好友加载完成后才挂上 VM,期间界面显示 loading,避免闪一下空列表。
  Future<void> enterMemberSelection() async {
    _isSelectingMembers = true;
    _creatingGroup = false;
    notifyListeners();

    final viewModel = PickUserViewModel();
    final userInfos = await UserRepo.getFriendUserInfos();
    viewModel.setup(userInfos, maxPickCount: _maxGroupMembers);

    // 加载期间可能已退出建群形态,或整个页面已销毁
    if (_disposed || !_isSelectingMembers) {
      viewModel.dispose();
      return;
    }
    _pickUserViewModel = viewModel;
    notifyListeners();
  }

  void exitMemberSelection() {
    final viewModel = _pickUserViewModel;
    _pickUserViewModel = null;
    _isSelectingMembers = false;
    _creatingGroup = false;
    notifyListeners();
    // 等本帧结束、监听它的 Consumer 卸载后再释放
    if (viewModel != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => viewModel.dispose());
    }
  }

  /// 建群。群名按“创建者,成员1,成员2…”拼接,超长时交给 [etcNameBuilder] 收尾。
  ///
  /// 成功时刻意不复位 [creatingGroup]:调用方紧接着就会离开当前界面,
  /// 复位只会让按钮闪一下,还可能在界面销毁后 notify。
  Future<CreateGroupResult> createGroup(
    List<UserInfo> members, {
    required String Function(String names) etcNameBuilder,
  }) async {
    _creatingGroup = true;
    notifyListeners();

    final groupName = await _buildGroupName(members, etcNameBuilder);

    final completer = Completer<CreateGroupResult>();
    Imclient.createGroup(
      null,
      groupName,
      null,
      GroupType.Restricted.index,
      members.map((u) => u.userId).toList(),
      (groupId) => completer.complete(CreateGroupResult.success(groupId)),
      (errorCode) => completer.complete(CreateGroupResult.failure(errorCode)),
    );

    final result = await completer.future;
    if (!result.isSuccess && !_disposed) {
      _creatingGroup = false;
      notifyListeners();
    }
    return result;
  }

  Future<String> _buildGroupName(
      List<UserInfo> members, String Function(String) etcNameBuilder) async {
    final creator = await Imclient.getUserInfo(Imclient.currentUserId);
    var groupName = creator?.displayName ?? '';
    for (var member in members) {
      final name = member.displayName;
      if (name == null) continue;
      if ('$groupName,$name'.length > _maxGroupNameLength) {
        return etcNameBuilder(groupName);
      }
      groupName = '$groupName,$name';
    }
    return groupName;
  }

  @override
  void dispose() {
    _disposed = true;
    _pickUserViewModel?.dispose();
    super.dispose();
  }

  static bool _isSameConversation(Conversation a, Conversation b) =>
      a.target == b.target &&
      a.conversationType == b.conversationType &&
      a.line == b.line;
}
