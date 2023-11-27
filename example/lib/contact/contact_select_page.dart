import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/user_info.dart';
import 'dart:ui';

import 'package:wfc_example/config.dart';
import 'package:wfc_example/contact/friend_request_page.dart';
import 'package:wfc_example/user_info_widget.dart';

import '../messages/messages_screen.dart';


typedef OnSelectMembersCallback = void Function(BuildContext context, List<String> selectedMembers);

class ContactSelectPage extends StatefulWidget {
  ContactSelectPage(this.callback, {this.maxSelected = 0, this.candidates, this.disabledCheckedUsers, this.disabledUncheckedUsers, Key? key}) : super(key: key);
  OnSelectMembersCallback callback;
  int maxSelected;
  List<String>? candidates;
  List<String>? disabledCheckedUsers;
  List<String>? disabledUncheckedUsers;

  @override
  State createState() => _ContactListWidgetState();
}

class _ContactListWidgetState extends State<ContactSelectPage> {
  List<String> friendList = [];
  List<bool> selected = [];
  
  @override
  void initState() {
    super.initState();
    if(widget.candidates == null) {
      Imclient.getMyFriendList(refresh: true).then((value) {
        setState(() {
          if (value != null) {
            friendList = value;
            selected = List.generate(friendList.length, (index) => widget.disabledCheckedUsers != null && widget.disabledCheckedUsers!.contains(friendList[index]));
          }
        });
      });
    } else {
      friendList = widget.candidates!;
      selected = List.generate(friendList.length, (index) => widget.disabledCheckedUsers != null && widget.disabledCheckedUsers!.contains(friendList[index]));
    }
  }

  void _onPressedDone(BuildContext context) {
    List<String> members = [];
    for(int i = 0; i < selected.length; i++) {
      if(selected[i]) {
        members.add(friendList[i]);
      }
    }

    widget.callback(context, members);
  }

  @override
  Widget build(BuildContext context) {
    late String text;
    int selectCount = 0;
    for (var value in selected) {
      if(value) {
        selectCount++;
      }
    }
    int disabledSelectedCount = 0;
    if(widget.disabledCheckedUsers != null) {
      disabledSelectedCount = widget.disabledCheckedUsers!.length;
    }
    if(selectCount- disabledSelectedCount > 0) {
      text = '完成($selectCount/${widget.maxSelected < selected.length ? widget.maxSelected : selected.length})';
    } else {
      text = '取消';
    }
    return Scaffold(
      appBar: AppBar(
        actions: [
          GestureDetector(
            onTap: ()=>_onPressedDone(context),
            child: Padding(padding: const EdgeInsets.fromLTRB(8, 16, 16, 8), child: Text(text, style: TextStyle(fontSize: 18),),),
          )
        ],
      ),
      body: SafeArea(child: ListView.builder(
          itemCount: friendList.length,
          itemBuilder: /*1*/ (context, i) {
              String userId = friendList[i];
              return _contactRow(userId, i);
          }),),
    );
  }

  Widget _contactRow(String userId, int index) {
    return ContactSelectableItem(userId, selected, index, widget.maxSelected, () {
      setState(() {});
    }, disabledCheckedUsers: widget.disabledCheckedUsers, disabledUncheckedUsers: widget.disabledUncheckedUsers);
  }
}

class ContactSelectableItem extends StatefulWidget {
  String userId;
  List<bool> selected;
  int index;
  int maxSelected;
  List<String>? disabledCheckedUsers;
  List<String>? disabledUncheckedUsers;
  void Function() onUpdate;

  ContactSelectableItem(this.userId, this.selected, this.index, this.maxSelected, this.onUpdate, {Key? key, this.disabledCheckedUsers, this.disabledUncheckedUsers}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _ContactListItemState();
  }
}

class _ContactListItemState extends State<ContactSelectableItem> {
  UserInfo? userInfo;
  bool isDisabled = false;

  _ContactListItemState();


  @override
  void initState() {
    super.initState();
    Imclient.getUserInfo(widget.userId).then((value) {
      setState(() {
        userInfo = value;
      });
    });
    if(widget.disabledUncheckedUsers != null && widget.disabledUncheckedUsers!.contains(widget.userId)) {
      isDisabled = true;
    }
    if(widget.disabledCheckedUsers != null && widget.disabledCheckedUsers!.contains(widget.userId)) {
      isDisabled = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    String? portrait;
    String convTitle;

    if(userInfo != null) {
      if(userInfo!.portrait != null && userInfo!.portrait!.isNotEmpty) {
        portrait = userInfo!.portrait!;
      }
      convTitle = userInfo!.displayName!;
    } else {
      convTitle = '用户';
    }

    return CheckboxListTile(
      enabled: !isDisabled,
      value: widget.selected[widget.index],
      onChanged: (bool? value) {
        if(value! && widget.maxSelected > 0) {
          int selectedCount = 0;
          for(var s in widget.selected) {
            if(s) selectedCount++;
          }
          if(widget.maxSelected <= selectedCount) {
            Fluttertoast.showToast(msg: "超过最大人数限制");
            return;
          }
        }

        setState(() {
          widget.selected[widget.index] = value!;
        });
        widget.onUpdate();
      },
      title: Column(
        children: <Widget>[
          Container(
            height: 52.0,
            margin: const EdgeInsets.fromLTRB(16.0, 0.0, 0.0, 0.0),
            child: Row(
              children: <Widget>[
                portrait == null ? Image.asset(Config.defaultUserPortrait, width: 40.0, height: 40.0) : Image.network(portrait, width: 40.0, height: 40.0),
                Container(margin: const EdgeInsets.only(left: 16),),
                Expanded(
                    child: Text(
                      convTitle,
                      style: const TextStyle(fontSize: 15.0),
                    )
                ),
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