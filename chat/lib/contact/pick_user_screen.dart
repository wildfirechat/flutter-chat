import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:chat/config.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/widgets/pc_dialog.dart';
import 'package:chat/repo/user_repo.dart';
import 'package:chat/viewmodel/pick_user_view_model.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/widget/sidebar_index.dart';
import 'package:chat/organization/organization_screen.dart';

typedef OnPickUserCallback = void Function(BuildContext context, List<String> pickedUsers);

/// 按平台形态呈现选人页:桌面居中 Dialog(420x560),移动端整页 push。
/// 回调中的 Navigator.pop(context) 在两种形态下都会关闭选人 UI。
Future<void> showPickUserScreen(
  BuildContext context,
  OnPickUserCallback callback, {
  String title = '',
  int maxSelected = 1024,
  List<String>? candidates,
  List<String>? disabledCheckedUsers,
  List<String>? disabledUncheckedUsers,
  bool showMentionAll = false,
}) {
  final picker = PickUserScreen(
    callback,
    title: title,
    maxSelected: maxSelected,
    candidates: candidates,
    disabledCheckedUsers: disabledCheckedUsers,
    disabledUncheckedUsers: disabledUncheckedUsers,
    showMentionAll: showMentionAll,
  );
  if (isDesktopShell) {
    return showPcDialog(
      context: context,
      width: 420,
      height: 560,
      builder: (dialogContext) => picker,
    );
  }
  return Navigator.push(context, MaterialPageRoute(builder: (routeContext) => picker));
}

class PickUserScreen extends StatefulWidget {
  final String title;
  final OnPickUserCallback callback;
  final int maxSelected;
  final List<String>? candidates;
  final List<String>? disabledCheckedUsers;
  final List<String>? disabledUncheckedUsers;
  final bool showMentionAll;

  const PickUserScreen(this.callback,
      {this.title = '', this.maxSelected = 1024, this.candidates, this.disabledCheckedUsers, this.disabledUncheckedUsers, this.showMentionAll = false, super.key});

  @override
  State<PickUserScreen> createState() => _PickUserScreenState();
}

class _PickUserScreenState extends State<PickUserScreen> {
  late final PickUserViewModel _pickUserViewModel;
  final ScrollController _scrollController = ScrollController();
  final ScrollController _selectedUsersScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _currentLetter = '';
  bool _isTouchingIndex = false;
  int _previousPickedCount = 0;

  @override
  void initState() {
    super.initState();
    _pickUserViewModel = PickUserViewModel();
    _pickUserViewModel.addListener(_onViewModelChanged);
    _initData();
  }

  @override
  void dispose() {
    _pickUserViewModel.removeListener(_onViewModelChanged);
    _searchController.dispose();
    _scrollController.dispose();
    _selectedUsersScrollController.dispose();
    super.dispose();
  }

  void _onViewModelChanged() {
    if (_pickUserViewModel.pickedUsers.length > _previousPickedCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_selectedUsersScrollController.hasClients) {
          _selectedUsersScrollController.animateTo(
            _selectedUsersScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
    _previousPickedCount = _pickUserViewModel.pickedUsers.length;
  }

  void _initData() async {
    var userInfos = widget.candidates != null ? await Imclient.getUserInfos(widget.candidates!) : await UserRepo.getFriendUserInfos();
    _pickUserViewModel.setup(userInfos,
        maxPickCount: widget.maxSelected,
        uncheckableUserIds: widget.disabledUncheckedUsers,
        disabledUserIds: widget.disabledCheckedUsers,
        showMentionAll: widget.showMentionAll);
  }

  void _onPressedDone(BuildContext context) {
    widget.callback(context, _pickUserViewModel.pickedUsers.map((u) => u.userId).toList());
  }

  Future<void> _openOrganizationPicker(BuildContext context) async {
    final remaining = widget.maxSelected - _pickUserViewModel.pickedUsers.length;
    if (remaining <= 0) {
      Fluttertoast.showToast(msg: AppLocalizations.of(context)!.maxUserLimit);
      return;
    }
    final selected = _pickUserViewModel.pickedUsers.map((u) => u.userId).toList();
    final disabled = <String>{
      ...widget.disabledUncheckedUsers ?? [],
      ...widget.disabledCheckedUsers ?? [],
    }.toList();

    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => OrganizationScreen(
          selectMode: true,
          maxSelected: remaining,
          initialSelectedUserIds: selected,
          disabledUserIds: disabled,
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      final userInfos = await Imclient.getUserInfos(result);
      for (final userInfo in userInfos) {
        if (_pickUserViewModel.pickedUsers.length >= widget.maxSelected) break;
        _pickUserViewModel.pickUser(userInfo, true);
      }
    }
  }

  List<String> _getIndexList(List<UIPickUserInfo> userList) {
    List<String> indexList = [];
    indexList.add('↑');
    for (var user in userList) {
      if (user.showCategory) {
        String category = user.category;
        if (category.startsWith("AI")) continue;
        if (category == "{") category = "#";
        if (!indexList.contains(category)) {
          indexList.add(category);
        }
      }
    }
    return indexList;
  }

  void _jumpToTag(String tag, List<UIPickUserInfo> userList) {
    if (tag == '↑') {
      _scrollController.jumpTo(0.0);
      return;
    }
    String targetCategory = tag;
    if (tag == '#') targetCategory = '{';

    double offset = 0;
    for (var user in userList) {
      if (user.category == targetCategory) {
        _scrollController.jumpTo(offset);
        return;
      }
      offset += user.showCategory ? 70.5 : 52.5;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PickUserViewModel>.value(
      value: _pickUserViewModel,
      child: Consumer<PickUserViewModel>(
        builder: (context, viewModel, child) {
          List<String> indexList = viewModel.isSearching ? [] : _getIndexList(viewModel.userList);
          return Scaffold(
            appBar: AppBar(
              title: Text(widget.title),
              actions: [
                if (widget.maxSelected > 1)
                  GestureDetector(
                    onTap: () => _onPressedDone(context),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                      child: Text(
                        viewModel.pickedUsers.isNotEmpty ? AppLocalizations.of(context)!.doneWithCount(viewModel.pickedUsers.length.toString()) : AppLocalizations.of(context)!.cancel,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  )
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.corporate_fare, color: Theme.of(context).colorScheme.secondary),
                    title: const Text('从组织架构选择'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openOrganizationPicker(context),
                  ),
                  Container(
                    height: 0.5,
                    margin: const EdgeInsets.only(left: 16.0),
                    color: const Color(0xffebebeb),
                  ),
                  Container(
                    height: 56,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    color: Colors.white,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xfff3f4f5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              children: [
                                ConstrainedBox(
                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width - 140),
                                  child: SingleChildScrollView(
                                    controller: _selectedUsersScrollController,
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: viewModel.pickedUsers
                                          .map((u) => Padding(
                                                padding: const EdgeInsets.only(right: 4),
                                                child: GestureDetector(
                                                  onTap: () => viewModel.pickUser(u, false),
                                                  child: Portrait(u.portrait ?? Config.defaultUserPortrait, Config.defaultUserPortrait,
                                                      width: 30, height: 30, borderRadius: 4),
                                                ),
                                              ))
                                          .toList(),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      hintText: AppLocalizations.of(context)!.search,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onChanged: (text) {
                                      viewModel.search(text);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        ListView.builder(
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          controller: _scrollController,
                          itemCount: viewModel.userList.length,
                          itemBuilder: (context, i) {
                            var userInfo = viewModel.userList[i];
                            return SelectableUserItem(
                              userInfo,
                              widget.maxSelected,
                              widget.callback,
                              onUserPicked: () {
                                if (_searchController.text.isNotEmpty) {
                                  _searchController.clear();
                                  viewModel.search('');
                                }
                              },
                            );
                          },
                        ),
                        if (indexList.isNotEmpty)
                          SidebarIndex(
                            indexList: indexList,
                            onIndexSelected: (tag) {
                              _jumpToTag(tag, viewModel.userList);
                            },
                            onTouch: (tag, isTouching) {
                              setState(() {
                                _currentLetter = tag;
                                _isTouchingIndex = isTouching;
                              });
                            },
                          ),
                        if (_isTouchingIndex)
                          Center(
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: _currentLetter == '↑'
                                  ? const Icon(Icons.arrow_upward, size: 40, color: Colors.white)
                                  : Text(
                                      _currentLetter,
                                      style: const TextStyle(color: Colors.white, fontSize: 40),
                                    ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class SelectableUserItem extends StatelessWidget {
  final UIPickUserInfo contactInfo;
  final int maxSelected;
  final OnPickUserCallback? callback;
  final VoidCallback? onUserPicked;

  const SelectableUserItem(this.contactInfo, this.maxSelected, this.callback, {super.key, this.onUserPicked});

  @override
  Widget build(BuildContext context) {
    PickUserViewModel pickUserViewModel = Provider.of<PickUserViewModel>(context);
    UserInfo userInfo = contactInfo.userInfo;
    bool showCategory = contactInfo.showCategory && !pickUserViewModel.isSearching;

    Widget content = Container(
      height: 52.0,
      color: Colors.white,
      child: Row(
        children: <Widget>[
          if (maxSelected > 1)
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Checkbox(
                value: pickUserViewModel.isChecked(userInfo.userId),
                onChanged: pickUserViewModel.isCheckable(userInfo.userId)
                    ? (bool? value) {
                        if (!pickUserViewModel.pickUser(userInfo, value!)) {
                          Fluttertoast.showToast(msg: AppLocalizations.of(context)!.maxUserLimit);
                        } else {
                          if (value == true && onUserPicked != null) {
                            onUserPicked!();
                          }
                        }
                      }
                    : null,
              ),
            ),
          Padding(
            padding: EdgeInsets.only(left: maxSelected > 1 ? 8.0 : 16.0),
            child: userInfo.userId == '@all'
                ? Image.asset('assets/images/group_avatar_default.png', width: 40, height: 40)
                : Portrait(userInfo.portrait ?? Config.defaultUserPortrait, Config.defaultUserPortrait),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: Text(
                userInfo.userId == '@all' ? AppLocalizations.of(context)!.allMembers: userInfo.displayName ?? userInfo.userId,
                style: const TextStyle(fontSize: 15.0),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );

    Widget item = Column(
      children: <Widget>[
        if (showCategory)
          Container(
            height: 18,
            width: double.infinity,
            color: const Color(0xffebebeb),
            padding: const EdgeInsets.only(left: 16),
            alignment: Alignment.centerLeft,
            child: Text(
              contactInfo.category == '{' ? '#' : (contactInfo.category == 'AI' ? AppLocalizations.of(context)!.aiRobot : contactInfo.category),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        content,
        Container(
          margin: const EdgeInsets.only(left: 16.0),
          height: 0.5,
          color: const Color(0xffebebeb),
        ),
      ],
    );

    if (maxSelected == 1) {
      return GestureDetector(
        onTap: () {
          if (callback != null) {
            callback!(context, [userInfo.userId]);
          }
        },
        child: item,
      );
    } else {
      return GestureDetector(
        onTap: () {
          if (pickUserViewModel.isCheckable(userInfo.userId)) {
            bool checked = pickUserViewModel.isChecked(userInfo.userId);
            if (!pickUserViewModel.pickUser(userInfo, !checked)) {
              Fluttertoast.showToast(msg: AppLocalizations.of(context)!.maxUserLimit);
            } else {
              if (!checked && onUserPicked != null) {
                onUserPicked!();
              }
            }
          }
        },
        child: item,
      );
    }
  }
}
