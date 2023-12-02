

import 'dart:async';

import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/user_info.dart';

import '../config.dart';

class ConversationSettingMembersWidget extends StatefulWidget {
  final Conversation conversation;

  void Function() onPlusItemClicked;
  void Function() onMinusItemClicked;
  void Function(String userId) onItemClicked;
  void Function(List<GroupMember> groupMembers, bool hasPlus, bool hasMinus) onShowMoreClicked;

  ConversationSettingMembersWidget(this.conversation, {required this.onItemClicked, required this.onPlusItemClicked, required this.onMinusItemClicked, required this.onShowMoreClicked, Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => MembersViewState();
}

class _MemberItem extends StatefulWidget {
  GroupMember? groupMember;
  bool? isPlus;
  String? userId;

  _MemberItem({this.groupMember, this.userId, this.isPlus});

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
    } else if(widget.userId != null) {
      Imclient.getUserInfo(
          widget.userId!)
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
      if(widget.groupMember != null) {
        name = widget.groupMember!.memberId;
      } else {
        name = widget.userId!;
      }

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
      } else if (widget.groupMember != null && widget.groupMember?.alias != null) {
        name = widget.groupMember!.alias!;
      }

      image = portrait == null ? Image.asset(Config.defaultUserPortrait) : Image.network(portrait);
    } else {
      image = widget.isPlus!?Image.asset('assets/images/conversation_setting_member_plus.png'):Image.asset('assets/images/conversation_setting_member_minus.png');
    }

    return Column(
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 0), child: image),
        SizedBox(height: 16, child: Text(name, overflow: TextOverflow.ellipsis, maxLines: 1, style: TextStyle(fontSize: 12)),),
      ],
    );
  }
}

class MembersViewState extends State<ConversationSettingMembersWidget> {
  List<GroupMember>? groupMembers;
  GroupInfo? groupInfo;
  late StreamSubscription<GroupMembersUpdatedEvent> _groupMembersUpdatedSubscription;
  final EventBus _eventBus = Imclient.IMEventBus;

  @override
  void initState() {
    super.initState();
    _groupMembersUpdatedSubscription = _eventBus.on<GroupMembersUpdatedEvent>().listen((event) {
      if(event.groupId == widget.conversation.target) {
        _loadData();
      }
    });
    _loadData();
  }

  void _loadData() {
    if(widget.conversation.conversationType == ConversationType.Group) {
      Imclient.getGroupInfo(widget.conversation.target).then((value) {
        groupInfo = value;
        Imclient.getGroupMembers(widget.conversation.target).then((value) {
          setState(() {
            groupMembers = value;
          });
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if((groupMembers == null || groupInfo == null) && widget.conversation.conversationType == ConversationType.Group) {
      return Container();
    }

    List<GroupMember>? showMembers;

    int columnCount = 5;
    int showLines = 4;
    bool hasMore = false;

    bool hasPlus = false;
    bool hasMinus = false;

    late int memberCount;
    if(widget.conversation.conversationType == ConversationType.Group) {
      showMembers = groupMembers;
      memberCount = groupMembers!.length;
      int moreItemCount = 0;
      if(groupInfo!.type != GroupType.Organization) {
        if(groupInfo!.owner == Imclient.currentUserId) {
          moreItemCount = 2;
          hasPlus = true;
          hasMinus = true;
        } else {
          moreItemCount = 1;
          hasPlus = true;
        }
      }

      memberCount += moreItemCount;

      if(memberCount > columnCount * showLines) {
        showMembers = groupMembers!.sublist(0, columnCount * showLines - moreItemCount);
        memberCount = columnCount * showLines;
        hasMore = true;
      }
    } else {
      memberCount = 2;
      hasPlus = true;
    }

    double screenWidth = MediaQuery.of(context).size.width;

    int lines = (memberCount -1) ~/ columnCount + 1;
    double gridHeight = (screenWidth/5) * lines;

    return Column(
      children: [
        SizedBox(
          height: gridHeight,
          child: GridView.builder(
              itemCount: memberCount,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5),
              itemBuilder: (context, index) {
                GroupMember? gm;
                bool? isPlus;
                String? userId;
                if(widget.conversation.conversationType == ConversationType.Group) {
                  if(index < showMembers!.length) {
                    gm = showMembers[index];
                  } else if(index == showMembers.length) {
                    isPlus = true;
                  } else {
                    isPlus = false;
                  }
                } else {
                  if(index == 0) {
                    userId = widget.conversation.target;
                  } else {
                    isPlus = true;
                  }
                }
                return GestureDetector(
                  onTap: () {
                    if(gm != null) {
                      widget.onItemClicked(gm.memberId);
                    } else if(isPlus!) {
                      widget.onPlusItemClicked();
                    } else {
                      widget.onMinusItemClicked();
                    }
                  },
                  child: _MemberItem(groupMember: gm, userId: userId, isPlus: isPlus,),
                );
              }),
        ),
        hasMore?Center(child: TextButton(
          onPressed: () {
            widget.onShowMoreClicked(groupMembers!, hasPlus, hasMinus);
          },
          child: const Text("查看更多群成员 >"),
        ),):const Padding(padding: EdgeInsets.only(top: 15)),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
    _groupMembersUpdatedSubscription.cancel();
  }
}