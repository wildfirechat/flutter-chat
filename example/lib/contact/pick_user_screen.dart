import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';

import 'package:wfc_example/config.dart';
import 'package:wfc_example/repo/user_repo.dart';
import 'package:wfc_example/viewmodel/pick_user_view_model.dart';
import 'package:wfc_example/widget/portrait.dart';
import 'package:wfc_example/widget/sidebar_index.dart';

typedef OnPickUserCallback = void Function(BuildContext context, List<String> pickedUsers);

class PickUserScreen extends StatefulWidget {
  final String title;
  final OnPickUserCallback callback;
  final int maxSelected;
  final List<String>? candidates;
  final List<String>? disabledCheckedUsers;
  final List<String>? disabledUncheckedUsers;
  final bool showMentionAll;

  const PickUserScreen(this.callback, {
    this.title = '',
    this.maxSelected = 1024,
    this.candidates,
    this.disabledCheckedUsers,
    this.disabledUncheckedUsers,
    this.showMentionAll = false,
    super.key
  });

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
    var userInfos = widget.candidates != null
        ? await Imclient.getUserInfos(widget.candidates!)
        : await UserRepo.getFriendUserInfos();
    _pickUserViewModel.setup(
      userInfos,
      maxPickCount: widget.maxSelected,
      uncheckableUserIds: widget.disabledUncheckedUsers,
      disabledUserIds: widget.disabledCheckedUsers,
      showMentionAll: widget.showMentionAll
    );
  }

  void _onPressedDone(BuildContext context) {
    widget.callback(context, _pickUserViewModel.pickedUsers.map((u) => u.userId).toList());
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
                        viewModel.pickedUsers.isNotEmpty ? '完成(${viewModel.pickedUsers.length})' : '取消',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  )
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
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
                                      children: viewModel.pickedUsers.map((u) => Padding(
                                        padding: const EdgeInsets.only(right: 4),
                                        child: GestureDetector(
                                          onTap: () => viewModel.pickUser(u, false),
                                          child: Portrait(u.portrait ?? Config.defaultUserPortrait, Config.defaultUserPortrait, width: 30, height: 30, borderRadius: 4),
                                        ),
                                      )).toList(),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      hintText: '搜索',
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
                onChanged: pickUserViewModel.isCheckable(userInfo.userId) ? (bool? value) {
                  if (!pickUserViewModel.pickUser(userInfo, value!)) {
                    Fluttertoast.showToast(msg: "超过最大人数限制");
                  } else {
                    if (value == true && onUserPicked != null) {
                      onUserPicked!();
                    }
                  }
                } : null,
              ),
            ),
          Padding(
            padding: EdgeInsets.only(left: maxSelected > 1 ? 8.0 : 16.0),
            child: userInfo.userId == 'All'
                ? Image.asset('assets/images/group_avatar_default.png', width: 40, height: 40)
                : Portrait(userInfo.portrait ?? Config.defaultUserPortrait, Config.defaultUserPortrait),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: Text(
                userInfo.displayName ?? userInfo.userId,
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
              contactInfo.category == '{' ? '#' : contactInfo.category,
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
              Fluttertoast.showToast(msg: "超过最大人数限制");
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
