

import 'dart:async';

import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/user_info.dart';

import '../config.dart';
import '../contact/pick_user_screen.dart';
import '../user_info_widget.dart';

class _MemberItem extends StatefulWidget {
  GroupMember? groupMember;
  bool? isPlus;

  _MemberItem({this.groupMember, this.isPlus});

  @override
  State<StatefulWidget> createState() => _MemberItemState();
}

class _MemberItemState extends State<_MemberItem> {
  UserInfo? userInfo;

  @override
  void initState() {
    super.initState();
    if(widget.groupMember != null) {
      Imclient.getUserInfo(
          widget.groupMember!.memberId, groupId: widget.groupMember!.groupId)
          .then((value) {
        setState(() {
          userInfo = value;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String? portrait;
    String name = '';
    late Image image;
    if(widget.isPlus == null) {
      name = widget.groupMember!.memberId;

      if (userInfo != null) {
        if (userInfo!.portrait != null) {
          portrait = userInfo!.portrait!;
        }
        if (userInfo!.friendAlias != null) {
          name = userInfo!.friendAlias!;
        } else if (userInfo!.groupAlias != null) {
          name = userInfo!.groupAlias!;
        } else if (userInfo!.displayName != null) {
          name = userInfo!.displayName!;
        }
      } else if (widget.groupMember?.alias != null) {
        name = widget.groupMember!.alias!;
      }

      image = portrait == null ? Image.asset(Config.defaultUserPortrait) : Image.network(portrait);
    } else {
      image = widget.isPlus!?Image.asset('assets/images/conversation_setting_member_plus.png'):Image.asset('assets/images/conversation_setting_member_minus.png');
    }

    return Column(
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 0), child: image),
        SizedBox(height: 16, child: Text(name, overflow: TextOverflow.ellipsis, maxLines: 1, style: const TextStyle(fontSize: 12)),),
      ],
    );
  }
}

class GroupAllMembersWidget extends StatefulWidget {
  final String _groupId;
  List<GroupMember> _groupMembers;
  final bool _hasPlus;
  final bool _hasMinus;

  GroupAllMembersWidget(this._groupId, this._groupMembers, this._hasPlus, this._hasMinus, {Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _GroupAllMembersWidgetState();
}

class _GroupAllMembersWidgetState extends State<GroupAllMembersWidget> {

  @override
  Widget build(BuildContext context) {
    int count = widget._groupMembers.length + (widget._hasPlus?1:0) + (widget._hasMinus?1:0);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
          child: GridView.builder(
              itemCount: count,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5),
              itemBuilder: (context, index) {
                GroupMember? gm;
                bool? isPlus;
                if(index < widget._groupMembers.length) {
                  gm = widget._groupMembers[index];
                } else if(index == widget._groupMembers.length) {
                  isPlus = true;
                } else {
                  isPlus = false;
                }

                return GestureDetector(
                  onTap: () {
                    if(gm != null) {
                      _onTapMember(context, gm);
                    } if(isPlus!) {
                      _onTapPlus(context);
                    } else {
                      _onTapMinus(context);
                    }
                  },
                  child: _MemberItem(groupMember: gm, isPlus: isPlus,),
                );
              })
      ),
    );
  }

  void _onTapMember(BuildContext context, GroupMember groupMember) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UserInfoWidget(groupMember.memberId)),
    );
  }

  void _onTapPlus(BuildContext context) {
    Imclient.getGroupMembers(widget._groupId).then((value) {
      if (value.isNotEmpty) {
        List<String> memberIds = [];
        for (var value1 in value) {
          memberIds.add(value1.memberId);
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) =>
              PickUserScreen((context, members) async {
                if(members.isEmpty) {
                  Navigator.pop(context);
                  return;
                }
                Imclient.addGroupMembers(
                    widget._groupId, members, () {
                  Navigator.pop(context);
                  _reloadData();
                }, (errorCode) {
                  Fluttertoast.showToast(msg: "网络错误");
                });
              }, disabledUncheckedUsers: memberIds
              )),
        );
      }
    }
    );
  }

  void _onTapMinus(BuildContext context) {
    Imclient.getGroupMembers(widget._groupId).then((value) {
      if(value.isNotEmpty) {
        List<String> memberIds = [];
        for (var value1 in value) {
          memberIds.add(value1.memberId);
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) =>
              PickUserScreen((context, members) async {
                if(members.isEmpty) {
                  Navigator.pop(context);
                } else {
                  Imclient.kickoffGroupMembers(
                      widget._groupId, members, () {
                    Navigator.pop(context);
                    _reloadData();
                  }, (
                      errorCode) {
                    Fluttertoast.showToast(msg: "网络错误");
                  });
                }
              }, disabledUncheckedUsers: [Imclient.currentUserId],
                candidates: memberIds,
              )),
        );

      }
    });
  }

  void _reloadData() {
    Imclient.getGroupMembers(widget._groupId).then((value) {
      setState(() {
        widget._groupMembers = value;
      });
    });
  }

  late StreamSubscription<GroupMembersUpdatedEvent> _groupMembersUpdatedSubscription;
  final EventBus _eventBus = Imclient.IMEventBus;

  @override
  void initState() {
    super.initState();
    _groupMembersUpdatedSubscription = _eventBus.on<GroupMembersUpdatedEvent>().listen((event) {
      if(event.groupId == widget._groupId) {
        _reloadData();
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    _groupMembersUpdatedSubscription.cancel();
  }
}