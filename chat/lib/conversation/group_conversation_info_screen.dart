import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/im_constant.dart';
import 'package:provider/provider.dart';
import 'package:chat/conversation/conversation_screen.dart';
import 'package:chat/viewmodel/conversation_view_model.dart';
import 'package:chat/viewmodel/group_conversation_info_view_model.dart';
import 'package:chat/viewmodel/group_view_model.dart';
import 'package:chat/widget/option_button_item.dart';
import 'package:chat/widget/option_item.dart';
import 'package:chat/widget/option_switch_item.dart';
import 'package:chat/widget/section_divider.dart';

import '../contact/pick_user_screen.dart';
import '../search/search_conversation_result_view.dart';
import '../user_info_widget.dart';
import 'conversation_files_screen.dart';
import 'group_announcement_screen.dart';
import 'group_conversation_info_members_view.dart';
import 'group_manage_screen.dart';
import 'group_qrcode_screen.dart';

class GroupConversationInfoScreen extends StatelessWidget {
  const GroupConversationInfoScreen(this.conversation, {super.key});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GroupConversationInfoViewModel>(
        create: (_) {
          var groupViewModel = GroupConversationInfoViewModel();
          groupViewModel.setup(conversation.target);
          return groupViewModel;
        },
        child: Consumer<GroupConversationInfoViewModel>(
            builder: (context, viewModel, child) => Scaffold(
                  appBar: AppBar(
                    title: const Text('群会话详情'),
                  ),
                  body: SafeArea(
                    child: viewModel.groupMember == null
                        ? const Center(
                            child: CircularProgressIndicator(),
                          )
                        : _buildGroupConversationInfoView(context, viewModel, viewModel.groupMember!),
                  ),
                )));
  }

  Widget _buildGroupConversationInfoView(BuildContext context, GroupConversationInfoViewModel groupConversationInfoViewModel, GroupMember groupMember) {
    var groupViewModel = Provider.of<GroupViewModel>(context);
    var conversationViewModel = Provider.of<ConversationViewModel>(context);
    var conversationInfo = conversationViewModel.conversationInfo!;
    var groupInfo = groupViewModel.getGroupInfo(conversation.target);
    return SingleChildScrollView(
        child: Column(children: [
      GroupConversationInfoMembersView(
        conversation,
        onGroupMemberTap: (userInfo) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => UserInfoWidget(userInfo.userId)),
          );
        },
        onAddActionTap: () {
          _onAddNewConversationMember(context);
        },
        onRemoveActionTap: () {
          _onRemoveConversationMember(context);
        },
        onShowMoreGroupMemberTap: () {
          // TODO
          // Navigator.push(
          //   context,
          //   MaterialPageRoute(builder: (context) => GroupAllMembersWidget(conversation.target, groupMembers, hasPlus, hasMinus)),
          // );
        },
      ),
      const SectionDivider(),
      OptionItem('成员列表', onTap: () {}),
      OptionItem('群聊名称', desc: groupInfo?.name ?? '群聊', onTap: () {
        if (groupMember.type == GroupMemberType.Owner || groupMember.type == GroupMemberType.Manager) {
          _showEditDialog(context, '修改群名称', groupInfo?.name ?? '', (value) {
            Imclient.modifyGroupInfo(conversation.target, ModifyGroupInfoType.Modify_Group_Name, value, () {}, (errorCode) {
              Fluttertoast.showToast(msg: "修改失败: $errorCode");
            });
          });
        } else {
          Fluttertoast.showToast(msg: "只有群主和管理员可以修改群名称");
        }
      }),
      OptionItem('群二维码', rightIcon: Icons.qr_code, onTap: () {
        if (groupInfo != null) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => GroupQrCodeScreen(groupInfo: groupInfo)));
        }
      }),
      OptionItem('群公告', desc: groupConversationInfoViewModel.groupAnnouncement ?? '点击查看', onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => GroupAnnouncementScreen(
                    groupId: conversation.target,
                    canEdit: groupMember.type == GroupMemberType.Owner || groupMember.type == GroupMemberType.Manager))).then((value) {
          groupConversationInfoViewModel.refreshGroupAnnouncement(conversation.target);
        });
      }),
      OptionItem('群备注', desc: groupInfo?.remark, onTap: () {
        _showEditDialog(context, '修改群备注', groupInfo?.remark ?? '', (value) {
          Imclient.setGroupRemark(conversation.target, value, () {}, (errorCode) {
            Fluttertoast.showToast(msg: "修改失败: $errorCode");
          });
        });
      }),
      groupMember.type == GroupMemberType.Manager || groupMember.type == GroupMemberType.Owner
          ? OptionItem('群管理', onTap: () {
              if (groupInfo != null) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => GroupManageScreen(groupInfo: groupInfo)));
              }
            })
          : Container(),
      const SectionDivider(),
      OptionItem('查找聊天内容', onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SearchConversationResultView(
              conversation: conversation,
              keyword: '',
            ),
          ),
        );
      }),
      OptionItem('会话文件', onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConversationFilesScreen(conversation),
          ),
        );
      }),
      const SectionDivider(),
      OptionSwitchItem('消息免打扰', conversationInfo.isSilent, (enable) {
        conversationViewModel.setConversationSilent(conversationInfo.conversation, enable);
      }),
      OptionSwitchItem('置顶聊天', conversationInfo.isTop > 0, (enable) {
        conversationViewModel.setConversationTop(conversationInfo.conversation, enable ? 1 : 0);
      }),
      OptionSwitchItem('保存到通讯录', groupConversationInfoViewModel.isFavGroup, (enable) {
        groupConversationInfoViewModel.setFavGroup(conversationInfo.conversation.target, enable);
      }),
      const SectionDivider(),
      OptionItem('我在本群的昵称', desc: groupMember.alias, onTap: () {
        _showEditDialog(context, '修改群昵称', groupMember.alias ?? '', (value) {
          Imclient.modifyGroupAlias(conversation.target, value, () {}, (errorCode) {
            Fluttertoast.showToast(msg: "修改失败: $errorCode");
          });
        });
      }),
      OptionSwitchItem('显示群成员昵称', !conversationViewModel.isHiddenConversationMemberName, (enable) {
        conversationViewModel.setHideGroupMemberName(conversationInfo.conversation.target, !enable);
      }),
      const SectionDivider(),
      OptionButtonItem('清空聊天记录', () {
        _showClearMessageDialog(context, conversation);
      }),
      groupMember.type == GroupMemberType.Owner ? OptionButtonItem('转移群组', () {}) : Container(),
      groupMember.type == GroupMemberType.Owner ? OptionButtonItem('解散群组', () {}) : Container(),
      groupMember.type != GroupMemberType.Owner ? OptionButtonItem('退出群组', () {}) : Container(),
      const SectionDivider(),
    ]));
  }

  void _showClearMessageDialog(BuildContext context, Conversation conversation) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('清空聊天记录'),
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                Imclient.clearMessages(conversation).then((value) {
                  Fluttertoast.showToast(msg: "清理本地消息成功");
                });
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('清空本地消息'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                Imclient.clearRemoteConversationMessage(conversation, () {
                  Fluttertoast.showToast(msg: "清理远程消息成功");
                }, (errorCode) {
                  Fluttertoast.showToast(msg: "清理远程消息失败: $errorCode");
                });
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('清空远程消息'),
              ),
            ),
          ],
        );
      },
    );
  }

  void _onRemoveConversationMember(BuildContext context) {
    Imclient.getGroupMembers(conversation.target).then((value) {
      if (value.isNotEmpty) {
        List<String> memberIds = [];
        for (var value1 in value) {
          memberIds.add(value1.memberId);
        }
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => PickUserScreen(
                    title: '移除群成员',
                    (context, members) async {
                      if (members.isEmpty) {
                        Navigator.pop(context);
                      } else {
                        Imclient.kickoffGroupMembers(conversation.target, members, () {
                          Navigator.pop(context);
                          Future.delayed(const Duration(milliseconds: 100), () {});
                        }, (errorCode) {});
                      }
                    },
                    disabledUncheckedUsers: [Imclient.currentUserId],
                    candidates: memberIds,
                  )),
        );
      }
    });
  }

  void _onAddNewConversationMember(BuildContext context) {
    if (conversation.conversationType == ConversationType.Group) {
      Imclient.getGroupMembers(conversation.target).then((value) {
        if (value.isNotEmpty) {
          List<String> memberIds = [];
          for (var value1 in value) {
            memberIds.add(value1.memberId);
          }
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => PickUserScreen(
                      title: '添加群成员',
                      (context, members) async {
                        if (members.isEmpty) {
                          Navigator.pop(context);
                        } else {
                          Imclient.addGroupMembers(conversation.target, members, () {
                            Navigator.pop(context);
                            Future.delayed(const Duration(milliseconds: 100), () {});
                          }, (errorCode) {});
                        }
                      },
                      disabledCheckedUsers: memberIds,
                    )),
          );
        }
      });
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => PickUserScreen(
                  title: '选择联系人',
                  (context, members) async {
                    Navigator.pop(context);
                    if (members.isNotEmpty) {
                      List<String> groupMembers = List.from(members);
                      if (!groupMembers.contains(conversation.target)) {
                        groupMembers.add(conversation.target);
                      }
                      Imclient.createGroup(null, null, null, 2, groupMembers, (strValue) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => ConversationScreen(Conversation(conversationType: ConversationType.Group, target: strValue, line: 0))),
                        );
                      }, (errorCode) {
                        Fluttertoast.showToast(msg: "网络错误");
                      });
                    }
                  },
                  disabledCheckedUsers: [conversation.target],
                )),
      );
    }
  }

  void _showEditDialog(BuildContext context, String title, String initialValue, Function(String) onConfirm) {
    TextEditingController controller = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
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
                onConfirm(controller.text);
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }
}
