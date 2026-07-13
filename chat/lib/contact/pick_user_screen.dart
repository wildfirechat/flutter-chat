import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/theme/app_colors.dart';

import 'package:chat/config.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/pc_pick_user_dialog.dart';
import 'package:chat/pc/widgets/pc_dialog.dart';
import 'package:chat/pc/widgets/pc_page_header.dart';
import 'package:chat/repo/user_repo.dart';
import 'package:chat/viewmodel/pick_user_view_model.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/widget/sidebar_index.dart';
import 'package:chat/organization/organization_screen.dart';
import 'package:chat/viewmodel/font_size_view_model.dart';
import 'package:chat/utils/layout_scale.dart';
import 'package:chat/utils/mesh_user_name.dart';
import 'package:chat/theme/app_typography.dart';

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
  bool showOrganizationEntry = true,
}) {
  // 桌面端多选走微信式分栏弹窗(左选人 / 右已选);单选仍用紧凑列表弹窗;移动端整页 push。
  if (isDesktopShell) {
    if (maxSelected > 1) {
      return showPcDialog(
        context: context,
        width: 640,
        height: 520,
        builder: (dialogContext) => PcPickUserView(
          callback,
          title: title,
          maxSelected: maxSelected,
          candidates: candidates,
          disabledCheckedUsers: disabledCheckedUsers,
          disabledUncheckedUsers: disabledUncheckedUsers,
          showMentionAll: showMentionAll,
          showOrganizationEntry: showOrganizationEntry,
        ),
      );
    }
    return showPcDialog(
      context: context,
      width: 420,
      height: 560,
      builder: (dialogContext) => PickUserScreen(
        callback,
        title: title,
        maxSelected: maxSelected,
        candidates: candidates,
        disabledCheckedUsers: disabledCheckedUsers,
        disabledUncheckedUsers: disabledUncheckedUsers,
        showMentionAll: showMentionAll,
        showOrganizationEntry: showOrganizationEntry,
      ),
    );
  }
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (routeContext) => PickUserScreen(
        callback,
        title: title,
        maxSelected: maxSelected,
        candidates: candidates,
        disabledCheckedUsers: disabledCheckedUsers,
        disabledUncheckedUsers: disabledUncheckedUsers,
        showMentionAll: showMentionAll,
        showOrganizationEntry: showOrganizationEntry,
      ),
    ),
  );
}

class PickUserScreen extends StatefulWidget {
  final String title;
  final OnPickUserCallback callback;
  final int maxSelected;
  final List<String>? candidates;
  final List<String>? disabledCheckedUsers;
  final List<String>? disabledUncheckedUsers;
  final bool showMentionAll;
  final bool showOrganizationEntry;
  final VoidCallback? onBack;

  const PickUserScreen(this.callback,
      {this.title = '',
      this.maxSelected = 1024,
      this.candidates,
      this.disabledCheckedUsers,
      this.disabledUncheckedUsers,
      this.showMentionAll = false,
      this.showOrganizationEntry = true,
      this.onBack,
      super.key});

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
    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => OrganizationScreen(
          selectMode: true,
          maxSelected: remaining,
          initialSelectedUserIds: selected,
          disabledUserIds: widget.disabledUncheckedUsers,
          disabledCheckedUserIds: widget.disabledCheckedUsers,
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
      final double categoryHeight = user.showCategory ? LayoutScale.scale(context, 18.0, cap: LayoutScale.textCap) : 0.0;
      final double contentHeight = LayoutScale.scale(context, 52.0, cap: LayoutScale.rowCap);
      const double dividerHeight = 0.5;
      offset += categoryHeight + contentHeight + dividerHeight;
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FontSizeViewModel>();
    return ChangeNotifierProvider<PickUserViewModel>.value(
      value: _pickUserViewModel,
      child: Consumer<PickUserViewModel>(
        builder: (context, viewModel, child) {
          List<String> indexList = viewModel.isSearching ? [] : _getIndexList(viewModel.userList);
          final actions = [
            if (widget.maxSelected > 1)
              GestureDetector(
                onTap: () => _onPressedDone(context),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                  child: Text(
                    viewModel.pickedUsers.isNotEmpty ? AppLocalizations.of(context)!.doneWithCount(viewModel.pickedUsers.length.toString()) : AppLocalizations.of(context)!.cancel,
                    style: AppText.lg,
                  ),
                ),
              )
          ];

          return Scaffold(
            backgroundColor: context.colors.chatBg,
            appBar: isDesktopShell
                ? PcPageHeader(
                    title: widget.title,
                    onBack: widget.onBack,
                    actions: actions,
                  )
                : AppBar(
                    title: Text(widget.title),
                    actions: actions,
                  ),
            body: SafeArea(
              child: Column(
                children: [
                  if (widget.showOrganizationEntry) ...[
                    Container(
                      constraints: BoxConstraints(
                        minHeight: LayoutScale.watchScale(context, 56.0, cap: LayoutScale.rowCap),
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.corporate_fare,
                          color: Theme.of(context).colorScheme.secondary,
                          size: LayoutScale.watchScale(context, 24.0, cap: LayoutScale.iconCap),
                        ),
                        title: const Text('从组织架构选择'),
                        trailing: Icon(
                          Icons.chevron_right,
                          size: LayoutScale.watchScale(context, 20.0, cap: LayoutScale.iconCap),
                        ),
                        onTap: () => _openOrganizationPicker(context),
                      ),
                    ),
                    Divider(
                      indent: isDesktopShell
                          ? 16.0
                          : 16.0 + LayoutScale.watchScale(context, 24.0, cap: LayoutScale.iconCap) + 16.0,
                    ),
                  ],
                  Container(
                    height: 56,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    color: context.colors.surface,
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.colors.inputBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: context.colors.iconSecondary),
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
                                    style: TextStyle(color: context.colors.textPrimary),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      hintText: AppLocalizations.of(context)!.search,
                                      hintStyle: TextStyle(color: context.colors.textTertiary),
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
                                      style: AppText.xxxl.copyWith(color: Colors.white),
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
    final bool checkable = pickUserViewModel.isCheckable(userInfo.userId);

    final double portraitWidth = LayoutScale.watchScale(context, 40.0, cap: LayoutScale.iconCap);
    final double leftIndent = isDesktopShell
        ? 16.0
        : (maxSelected > 1
            ? (16.0 + 32.0 + 8.0 + portraitWidth + 12.0)
            : (16.0 + portraitWidth + 12.0));

    Widget content = Material(
      color: context.colors.surface,
      child: InkWell(
        onTap: checkable
            ? () {
                if (maxSelected == 1) {
                  if (callback != null) {
                    callback!(context, [userInfo.userId]);
                  }
                } else {
                  bool checked = pickUserViewModel.isChecked(userInfo.userId);
                  if (!pickUserViewModel.pickUser(userInfo, !checked)) {
                    Fluttertoast.showToast(msg: AppLocalizations.of(context)!.maxUserLimit);
                  } else {
                    if (!checked && onUserPicked != null) {
                      onUserPicked!();
                    }
                  }
                }
              }
            : null,
        hoverColor: context.colors.hoverOverlay,
        child: Container(
          height: LayoutScale.watchScale(context, 52.0, cap: LayoutScale.rowCap),
          padding: EdgeInsets.only(right: isDesktopShell ? 0.0 : 32.0),
          child: Row(
            children: <Widget>[
              if (maxSelected > 1)
                Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: Checkbox(
                    value: pickUserViewModel.isChecked(userInfo.userId) ||
                        pickUserViewModel.disabledAndCheckedUserIds.contains(userInfo.userId),
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
              Expanded(
                child: Opacity(
                  opacity: checkable ? 1.0 : 0.5,
                  child: Row(
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.only(left: maxSelected > 1 ? 8.0 : 16.0),
                        child: userInfo.userId == '@all'
                            ? Image.asset('assets/images/group_avatar_default.png',
                                width: LayoutScale.watchScale(context, 40.0, cap: LayoutScale.iconCap),
                                height: LayoutScale.watchScale(context, 40.0, cap: LayoutScale.iconCap))
                            : Portrait(userInfo.portrait ?? Config.defaultUserPortrait, Config.defaultUserPortrait, width: 40.0, height: 40.0),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12.0),
                          child: userInfo.userId == '@all'
                              ? Text(
                                  AppLocalizations.of(context)!.allMembers,
                                  style: AppText.lg.copyWith(color: context.colors.textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : MeshUserName(
                                  userInfo,
                                  style: AppText.lg.copyWith(color: context.colors.textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    Widget item = Column(
      children: <Widget>[
        if (showCategory)
          Container(
            height: LayoutScale.watchScale(context, 18.0, cap: LayoutScale.textCap),
            width: double.infinity,
            color: context.colors.sectionGap,
            padding: EdgeInsets.only(left: 16, right: isDesktopShell ? 16.0 : 32.0),
            alignment: Alignment.centerLeft,
            child: Text(
              contactInfo.category == '{' ? '#' : (contactInfo.category == 'AI' ? AppLocalizations.of(context)!.aiRobot : contactInfo.category),
              style: AppText.xs.copyWith(color: context.colors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        content,
        Divider(indent: leftIndent),
      ],
    );

    return item;
  }
}
