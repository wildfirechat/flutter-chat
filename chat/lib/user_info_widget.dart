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
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/pc_shell_view_model.dart';
import 'package:chat/viewmodel/contact_list_view_model.dart';
import 'package:chat/viewmodel/user_view_model.dart';
import 'package:chat/widget/option_button_item.dart';
import 'package:chat/widget/option_item.dart';
import 'package:chat/widget/section_divider.dart';

import 'package:chat/pc/widgets/pc_page_header.dart';
import 'conversation/conversation_screen.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class UserInfoWidget extends StatefulWidget {
  const UserInfoWidget(this.userId, {this.inGroupId, this.onOpenPage, super.key});
  final String userId;
  final String? inGroupId;
  /// 桌面端用于在右栏打开二级页面（如 InviteFriendPage）。手机端可忽略。
  final void Function(Widget page)? onOpenPage;

  @override
  State<UserInfoWidget> createState() => _UserInfoWidgetState();
}

class _UserInfoWidgetState extends State<UserInfoWidget> {
  bool _isBlacklisted = false;
  bool _isStarred = false;

  /// 发起单聊:桌面 Shell 内交给 PCShellViewModel 在右栏打开并同步选中态,
  /// 移动端(无该 Provider)保持整页 push。
  void _openSingleConversation(BuildContext context) {
    if (isDesktopShell) {
      final shell = Provider.of<PCShellViewModel>(context, listen: false);
      shell.openConversation(Conversation(conversationType: ConversationType.Single, target: widget.userId));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (context) => ConversationScreen(Conversation(conversationType: ConversationType.Single, target: widget.userId))));
    }
  }

  @override
  void initState() {
    super.initState();
    _refreshUserInfo();
    _checkRelation();
  }

  Future<void> _refreshUserInfo() async {
    await Imclient.getUserInfo(widget.userId, refresh: true);
  }

  void _checkRelation() async {
    bool isBlacklisted = await Imclient.isBlackListed(widget.userId);
    bool isStarred = await Imclient.isFavUser(widget.userId);
    if (mounted) {
      setState(() {
        _isBlacklisted = isBlacklisted;
        _isStarred = isStarred;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final FutureBuilder<bool> actionsBuilder = FutureBuilder<bool>(
      future: _isFriend(widget.userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Container();
        bool isFriend = snapshot.data!;
        bool isMe = widget.userId == Imclient.currentUserId;
        if (isMe) return Container();

        return PopupMenuButton<String>(
          onSelected: (value) => _handleMenuSelection(value, isFriend),
          itemBuilder: (BuildContext context) {
            List<PopupMenuEntry<String>> items = [];
            if (isFriend) {
              items.add(PopupMenuItem(
                value: 'blacklist',
                child: Text(_isBlacklisted ? AppLocalizations.of(context)!.removeFromBlacklist : AppLocalizations.of(context)!.addToBlacklist),
              ));
              items.add(PopupMenuItem(
                value: 'star',
                child: Text(_isStarred ? AppLocalizations.of(context)!.cancelStarredFriend : AppLocalizations.of(context)!.setStarredFriend),
              ));
              items.add(PopupMenuItem(
                value: 'delete',
                child: Text(AppLocalizations.of(context)!.deleteFriend),
              ));
            } else {
              items.add(PopupMenuItem(
                value: 'blacklist',
                child: Text(_isBlacklisted ? AppLocalizations.of(context)!.removeFromBlacklist : AppLocalizations.of(context)!.addToBlacklist),
              ));
              items.add(PopupMenuItem(
                value: 'add_friend',
                child: Text(AppLocalizations.of(context)!.addFriend),
              ));
            }
            return items;
          },
        );
      },
    );

    return Scaffold(
      appBar: isDesktopShell
          ? PcPageHeader(
              title: AppLocalizations.of(context)!.userInfo,
              actions: [actionsBuilder],
            )
          : AppBar(
              title: Text(AppLocalizations.of(context)!.userInfo),
              actions: [actionsBuilder],
            ),
      body: SafeArea(
        child: Selector<UserViewModel, UserInfo?>(
          selector: (context, viewModel) => viewModel.getUserInfo(widget.userId, groupId: widget.inGroupId),
          builder: (context, userInfo, child) {
            return FutureBuilder<bool>(
              future: _isFriend(widget.userId),
              builder: (context, snapshot) {
                if (userInfo == null || !snapshot.hasData) {
                  return Center(child: Text(AppLocalizations.of(context)!.loading));
                }
                bool isFriend = snapshot.data!;
                bool isMe = widget.userId == Imclient.currentUserId;

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildHeader(context, userInfo, isFriend),
                      if (isMe) ...[
                        OptionItem(AppLocalizations.of(context)!.modifyAlias, onTap: () {
                          _showSetDisplayNameDialog(context, userInfo);
                        }),
                        const SectionDivider(),
                        OptionItem(AppLocalizations.of(context)!.moreInfo, onTap: () {
                          Fluttertoast.showToast(msg: AppLocalizations.of(context)!.methodNotImpl);
                        }),
                        const SectionDivider(),
                        OptionButtonItem(AppLocalizations.of(context)!.sendMsg, () {
                          _openSingleConversation(context);
                        }),
                      ] else if (isFriend) ...[
                        OptionItem(AppLocalizations.of(context)!.setAlias, onTap: () {
                          _showSetAliasDialog(context, userInfo);
                        }),
                        const SectionDivider(),
                        OptionItem(AppLocalizations.of(context)!.moreInfo, onTap: () {
                          Fluttertoast.showToast(msg: AppLocalizations.of(context)!.methodNotImpl);
                        }),
                        const SectionDivider(),
                        OptionButtonItem(AppLocalizations.of(context)!.sendMsg, () {
                          _openSingleConversation(context);
                        }),
                        OptionButtonItem('视频聊天', () {
                          // SingleVideoCallView callView = SingleVideoCallView(userId: userId, audioOnly: false);
                          // Navigator.push(context, MaterialPageRoute(builder: (context) => callView));
                        }),
                      ] else ...[
                        const SectionDivider(),
                        OptionItem(AppLocalizations.of(context)!.moreInfo, onTap: () {
                          Fluttertoast.showToast(msg: AppLocalizations.of(context)!.methodNotImpl);
                        }),
                        const SectionDivider(),
                        OptionButtonItem(AppLocalizations.of(context)!.addFriend, () {
                          _openInviteFriendPage(context);
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
          title: Text(AppLocalizations.of(context)!.modifyAlias),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: AppLocalizations.of(context)!.inputNickname),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Imclient.modifyMyInfo({ModifyMyInfoType.Modify_DisplayName: controller.text}, () {
                  Fluttertoast.showToast(msg: AppLocalizations.of(context)!.modifySuccess);
                }, (errorCode) {
                  Fluttertoast.showToast(msg: "${AppLocalizations.of(context)!.modifyFail}: $errorCode");
                });
              },
              child: Text(AppLocalizations.of(context)!.confirm),
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
          title: Text(AppLocalizations.of(context)!.setAlias),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: AppLocalizations.of(context)!.inputAlias),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Imclient.setFriendAlias(userInfo.userId, controller.text, () {
                  Fluttertoast.showToast(msg: AppLocalizations.of(context)!.setSuccess);
                }, (errorCode) {
                  Fluttertoast.showToast(msg: "${AppLocalizations.of(context)!.setFail}: $errorCode");
                });
              },
              child: Text(AppLocalizations.of(context)!.confirm),
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
        '${AppLocalizations.of(context)!.remark}:${userInfo.friendAlias!}',
        textAlign: TextAlign.left,
        style: const TextStyle(fontSize: 12),
      ));
      nameList.add(Container(
        margin: EdgeInsets.only(top: hasAlias ? 3 : 6),
      ));
    }
    nameList.add(Row(
      children: [
        Container(
            constraints: BoxConstraints(maxWidth: View.of(context).physicalSize.width / View.of(context).devicePixelRatio - 120),
            child: Text(
              AppLocalizations.of(context)!.wildfireId(userInfo.name),
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF3b3b3b),
              ),
              overflow: TextOverflow.ellipsis,
            )),
        if (isFriend && _isStarred)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.star, color: Colors.amber, size: 16),
          ),
      ],
    ));

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

  void _handleMenuSelection(String value, bool isFriend) {
    switch (value) {
      case 'blacklist':
        _toggleBlacklist();
        break;
      case 'star':
        _toggleStar();
        break;
      case 'delete':
        _deleteFriend();
        break;
      case 'add_friend':
        _openInviteFriendPage(context);
        break;
    }
  }

  void _openInviteFriendPage(BuildContext context) {
    final page = InviteFriendPage(widget.userId);
    if (isDesktopShell && widget.onOpenPage != null) {
      widget.onOpenPage!(page);
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (context) => page));
    }
  }

  void _toggleBlacklist() {
    Imclient.setBlackList(widget.userId, !_isBlacklisted, () {
      setState(() {
        _isBlacklisted = !_isBlacklisted;
      });
      Fluttertoast.showToast(msg: AppLocalizations.of(context)!.success);
    }, (errorCode) {
      Fluttertoast.showToast(msg: "${AppLocalizations.of(context)!.failed}: $errorCode");
    });
  }

  void _toggleStar() {
    var contactListViewModel = Provider.of<ContactListViewModel>(context, listen: false);
    contactListViewModel.setFavUser(widget.userId, !_isStarred);
    setState(() {
      _isStarred = !_isStarred;
    });
    Fluttertoast.showToast(msg: AppLocalizations.of(context)!.success);
  }

  void _deleteFriend() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.deleteFriend),
          content: Text(AppLocalizations.of(context)!.deleteFriendConfirm),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Imclient.deleteFriend(widget.userId, () {
                  Fluttertoast.showToast(msg: AppLocalizations.of(context)!.success);
                  Navigator.pop(context);
                }, (errorCode) {
                  Fluttertoast.showToast(msg: "${AppLocalizations.of(context)!.failed}: $errorCode");
                });
              },
              child: Text(AppLocalizations.of(context)!.delete, style: const TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
