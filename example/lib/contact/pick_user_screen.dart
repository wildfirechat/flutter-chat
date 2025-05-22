import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';

import 'package:wfc_example/config.dart';
import 'package:wfc_example/viewmodel/pick_user_view_model.dart';
import 'package:wfc_example/widget/portrait.dart';

typedef OnPickUserCallback = void Function(BuildContext context, List<String> pickedUsers);

class PickUserScreen extends StatelessWidget {
  PickUserScreen(this.callback, {this.title = '', this.maxSelected = 1024, this.candidates, this.disabledCheckedUsers, this.disabledUncheckedUsers, super.key});

  final String title;
  final OnPickUserCallback callback;
  final int maxSelected;
  final List<String>? candidates;
  final List<String>? disabledCheckedUsers;
  final List<String>? disabledUncheckedUsers;
  late PickUserViewModel _pickUserViewModel;

  void _onPressedDone(BuildContext context) {
    callback(context, _pickUserViewModel.pickedUsers.map((u) => u.userId).toList());
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PickUserViewModel>(
        create: (_) {
          _pickUserViewModel = PickUserViewModel();
          () async {
            var userIds = candidates ?? await Imclient.getMyFriendList(refresh: false);
            var userInfos = await Imclient.getUserInfos(userIds);
            _pickUserViewModel.setup(userInfos, maxPickCount: maxSelected, uncheckableUserIds: disabledUncheckedUsers, disabledUserIds: disabledCheckedUsers);
          }();
          return _pickUserViewModel;
        },
        // 不使用 Consumer 的话，下面的 _pickUserViewModel 会提示未初始化，不能正常监听使用
        child: Consumer<PickUserViewModel>(
            builder: (context, viewModel, child) => Scaffold(
                  appBar: AppBar(
                    title: Text(title),
                    actions: [
                      GestureDetector(
                        onTap: () => _onPressedDone(context),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                          child: Text(
                            _pickUserViewModel.pickedUsers.isNotEmpty ? '完成(${_pickUserViewModel.pickedUsers.length})' : '取消',
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      )
                    ],
                  ),
                  body: SafeArea(
                    child: ListView.builder(
                        itemCount: _pickUserViewModel.users.length,
                        itemBuilder: /*1*/ (context, i) {
                          // String userId = _pickUserViewModel.users[i];
                          // return _contactRow(userId, i);
                          return ContactSelectableItem(_pickUserViewModel.users[i]);
                        }),
                  ),
                )));
  }
}

class ContactSelectableItem extends StatelessWidget {
  final UserInfo userInfo;

  const ContactSelectableItem(this.userInfo, {super.key});

  @override
  Widget build(BuildContext context) {
    PickUserViewModel pickUserViewModel = Provider.of<PickUserViewModel>(context);

    return CheckboxListTile(
      enabled: pickUserViewModel.isCheckable(userInfo.userId),
      value: pickUserViewModel.isChecked(userInfo.userId),
      onChanged: (bool? value) {
        if (!pickUserViewModel.pickUser(userInfo, value!)) {
          Fluttertoast.showToast(msg: "超过最大人数限制");
        }
      },
      title: Column(
        children: <Widget>[
          Container(
            height: 52.0,
            margin: const EdgeInsets.fromLTRB(16.0, 0.0, 0.0, 0.0),
            child: Row(
              children: <Widget>[
                Portrait(userInfo.portrait ?? Config.defaultUserPortrait, Config.defaultUserPortrait),
                Container(
                  margin: const EdgeInsets.only(left: 16),
                ),
                Expanded(
                    child: Text(
                  userInfo.displayName ?? '<${userInfo.userId}>',
                  style: const TextStyle(fontSize: 15.0),
                )),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 0.0),
            height: 0.5,
            color: const Color(0xffebebeb),
          ),
        ],
      ),
    );
  }
}
