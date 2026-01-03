import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/im_constant.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/config.dart';
import 'package:chat/contact/invite_friend.dart';
import 'package:chat/viewmodel/user_view_model.dart';
import 'package:chat/widget/option_button_item.dart';
import 'package:chat/widget/option_item.dart';
import 'package:chat/widget/section_divider.dart';

import 'conversation/conversation_screen.dart';

class UserInfoWidget extends StatelessWidget {
  const UserInfoWidget(this.userId, {this.inGroupId, Key? key}) : super(key: key);
  final String userId;
  final String? inGroupId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('用户详情'),
      ),
      body: SafeArea(
        child: Selector<UserViewModel, UserInfo?>(
          selector: (context, viewModel) => viewModel.getUserInfo(userId, groupId: inGroupId),
          builder: (context, userInfo, child) {
            return FutureBuilder<bool>(
              future: _isFriend(userId),
              builder: (context, snapshot) {
                if (userInfo == null || !snapshot.hasData) {
                  return const Center(child: Text("加载中。。。"));
                }
                bool isFriend = snapshot.data!;
                bool isMe = userId == Imclient.currentUserId;

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildHeader(context, userInfo, isFriend),
                      if (isMe) ...[
                        OptionItem('修改昵称', onTap: () {
                          _showSetDisplayNameDialog(context, userInfo);
                        }),
                        const SectionDivider(),
                        OptionItem('更多信息', onTap: () {
                          Fluttertoast.showToast(msg: "方法没有实现");
                        }),
                        const SectionDivider(),
                        OptionButtonItem('发送消息', () {
                          Conversation conversation = Conversation(conversationType: ConversationType.Single, target: userId);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => ConversationScreen(conversation)),
                          );
                        }),
                      ] else if (isFriend) ...[
                        OptionItem('设置昵称或者别名', onTap: () {
                          _showSetAliasDialog(context, userInfo);
                        }),
                        const SectionDivider(),
                        OptionItem('更多信息', onTap: () {
                          Fluttertoast.showToast(msg: "方法没有实现");
                        }),
                        const SectionDivider(),
                        OptionButtonItem('发送消息', () {
                          Conversation conversation = Conversation(conversationType: ConversationType.Single, target: userId);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => ConversationScreen(conversation)),
                          );
                        }),
                        OptionButtonItem('视频聊天', () {
                          // SingleVideoCallView callView = SingleVideoCallView(userId: userId, audioOnly: false);
                          // Navigator.push(context, MaterialPageRoute(builder: (context) => callView));
                        }),
                      ] else ...[
                        const SectionDivider(),
                        OptionItem('更多信息', onTap: () {
                          Fluttertoast.showToast(msg: "方法没有实现");
                        }),
                        const SectionDivider(),
                        OptionButtonItem('添加好友', () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => InviteFriendPage(userId)),
                          );
                        }),
                      ]
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<bool> _isFriend(String userId) async {
    if (Config.AI_ROBOTS.contains(userId)) {
      return true;
    }
    return await Imclient.isMyFriend(userId);
  }

  void _showSetDisplayNameDialog(BuildContext context, UserInfo userInfo) {
    TextEditingController controller = TextEditingController(text: userInfo.displayName);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('修改昵称'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: '请输入昵称'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Imclient.modifyMyInfo({ModifyMyInfoType.Modify_DisplayName: controller.text}, () {
                  Fluttertoast.showToast(msg: "修改成功");
                }, (errorCode) {
                  Fluttertoast.showToast(msg: "修改失败: $errorCode");
                });
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  void _showSetAliasDialog(BuildContext context, UserInfo userInfo) {
    TextEditingController controller = TextEditingController(text: userInfo.friendAlias);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('设置备注'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: '请输入备注名'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Imclient.setFriendAlias(userInfo.userId, controller.text, () {
                  Fluttertoast.showToast(msg: "设置成功");
                }, (errorCode) {
                  Fluttertoast.showToast(msg: "设置失败: $errorCode");
                });
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, UserInfo userInfo, bool isFriend) {
    String? portrait;
    if (userInfo.portrait != null && userInfo.portrait!.isNotEmpty) {
      portrait = userInfo.portrait;
    }

    List<Widget> nameList = [];
    nameList.add(Text(
      userInfo.displayName!,
      textAlign: TextAlign.left,
      style: const TextStyle(fontSize: 18),
    ));
    bool hasAlias = isFriend && userInfo.friendAlias != null && userInfo.friendAlias!.isNotEmpty;
    nameList.add(Container(
      margin: EdgeInsets.only(top: hasAlias ? 3 : 6),
    ));
    if (hasAlias) {
      nameList.add(Text(
        '备注名:${userInfo.friendAlias!}',
        textAlign: TextAlign.left,
        style: const TextStyle(fontSize: 12),
      ));
      nameList.add(Container(
        margin: EdgeInsets.only(top: hasAlias ? 3 : 6),
      ));
    }
    nameList.add(Container(
        constraints: BoxConstraints(maxWidth: View.of(context).physicalSize.width / View.of(context).devicePixelRatio - 100),
        child: Text(
          '野火号:${userInfo.name}',
          textAlign: TextAlign.left,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF3b3b3b),
          ),
          overflow: TextOverflow.ellipsis,
        )));

    return Container(
      height: 80,
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Row(
        children: [
          GestureDetector(
            child: Container(
              height: 60,
              width: 60,
              margin: const EdgeInsets.only(right: 16),
              child: portrait == null ? Image.asset(Config.defaultUserPortrait, width: 32.0, height: 32.0) : Image.network(portrait, width: 32.0, height: 32.0),
            ),
            onTap: () {
              //show user portrait
            },
          ),
          Container(
            margin: const EdgeInsets.only(top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: nameList,
            ),
          )
        ],
      ),
    );
  }
}
