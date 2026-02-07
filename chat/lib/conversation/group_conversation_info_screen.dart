import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/im_constant.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
                    title: Text(AppLocalizations.of(context)!.groupConversationDetails),
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
    final l10n = AppLocalizations.of(context)!;
    
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
      OptionItem(l10n.groupMemberList, onTap: () {}),
      OptionItem(l10n.groupNameLabel, desc: groupInfo?.name ?? '', onTap: () {
        if (groupMember.type == GroupMemberType.Owner || groupMember.type == GroupMemberType.Manager) {
          _showEditDialog(context, l10n.modifyGroupNameDialog, groupInfo?.name ?? '', (value) {
            Imclient.modifyGroupInfo(conversation.target, ModifyGroupInfoType.Modify_Group_Name, value, () {}, (errorCode) {
              Fluttertoast.showToast(msg: l10n.modifyFailedWithCode(errorCode.toString()));
            });
          });
        } else {
          Fluttertoast.showToast(msg: l10n.onlyOwnerManagerCanModify);
        }
      }),
      OptionItem(l10n.groupQrCode, rightIcon: Icons.qr_code, onTap: () {
        if (groupInfo != null) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => GroupQrCodeScreen(groupInfo: groupInfo)));
        }
      }),
      OptionItem(l10n.groupAnnouncement, desc: groupConversationInfoViewModel.groupAnnouncement ?? l10n.clickToCheck, onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => GroupAnnouncementScreen(
                    groupId: conversation.target,
                    canEdit: groupMember.type == GroupMemberType.Owner || groupMember.type == GroupMemberType.Manager))).then((value) {
          groupConversationInfoViewModel.refreshGroupAnnouncement(conversation.target);
        });
      }),
      OptionItem(l10n.groupRemarkLabel, desc: groupInfo?.remark, onTap: () {
        _showEditDialog(context, l10n.modifyGroupRemarkDialog, groupInfo?.remark ?? '', (value) {
          Imclient.setGroupRemark(conversation.target, value, () {}, (errorCode) {
            Fluttertoast.showToast(msg: l10n.modifyFailedWithCode(errorCode.toString()));
          });
        });
      }),
      groupMember.type == GroupMemberType.Manager || groupMember.type == GroupMemberType.Owner
          ? OptionItem(l10n.groupManagement, onTap: () {
              if (groupInfo != null) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => GroupManageScreen(groupInfo: groupInfo)));
              }
            })
          : Container(),
      const SectionDivider(),
      OptionItem(l10n.searchChatContents, onTap: () {
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
      OptionItem(l10n.chatFiles, onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConversationFilesScreen(conversation),
          ),
        );
      }),
      const SectionDivider(),
      OptionSwitchItem(l10n.muteNotification, conversationInfo.isSilent, (enable) {
        conversationViewModel.setConversationSilent(conversationInfo.conversation, enable);
      }),
      OptionSwitchItem(l10n.stickTop, conversationInfo.isTop > 0, (enable) {
        conversationViewModel.setConversationTop(conversationInfo.conversation, enable ? 1 : 0);
      }),
      OptionSwitchItem(l10n.favoriteGroup, groupConversationInfoViewModel.isFavGroup, (enable) {
        groupConversationInfoViewModel.setFavGroup(conversationInfo.conversation.target, enable);
      }),
      const SectionDivider(),
      OptionItem(l10n.myAliasInGroupLabel, desc: groupMember.alias, onTap: () {
        _showEditDialog(context, l10n.modifyGroupAliasDialog, groupMember.alias ?? '', (value) {
          Imclient.modifyGroupAlias(conversation.target, value, () {}, (errorCode) {
            Fluttertoast.showToast(msg: l10n.modifyFailedWithCode(errorCode.toString()));
          });
        });
      }),
      OptionSwitchItem(l10n.showGroupMemberNames, !conversationViewModel.isHiddenConversationMemberName, (enable) {
        conversationViewModel.setHideGroupMemberName(conversationInfo.conversation.target, !enable);
      }),
      const SectionDivider(),
      OptionButtonItem(l10n.clearChatHistory, () {
        _showClearMessageDialog(context, conversation);
      }),
      groupMember.type == GroupMemberType.Owner ? OptionButtonItem(l10n.transferGroup, () {}) : Container(),
      groupMember.type == GroupMemberType.Owner ? OptionButtonItem(l10n.dissolveGroup, () {}) : Container(),
      groupMember.type != GroupMemberType.Owner ? OptionButtonItem(l10n.quitGroupChat, () {}) : Container(),
      const SectionDivider(),
    ]));
  }

  void _showClearMessageDialog(BuildContext context, Conversation conversation) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(l10n.clearChatHistory),
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                Imclient.clearMessages(conversation).then((value) {
                  Fluttertoast.showToast(msg: l10n.clearLocalMessagesSuccess);
                });
              },
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(l10n.clearLocalMessages),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                Imclient.clearRemoteConversationMessage(conversation, () {
                  Fluttertoast.showToast(msg: l10n.clearRemoteMessagesSuccess);
                }, (errorCode) {
                  Fluttertoast.showToast(msg: l10n.clearRemoteMessagesFailed(errorCode.toString()));
                });
              },
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(l10n.clearRemoteMessages),
              ),
            ),
          ],
        );
      },
    );
  }

  void _onRemoveConversationMember(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                    title: l10n.removeGroupMembers,
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
    final l10n = AppLocalizations.of(context)!;
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
                      title: l10n.addGroupMembers,
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
                  title: l10n.selectContacts,
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
                        Fluttertoast.showToast(msg: l10n.networkError);
                      });
                    }
                  },
                  disabledCheckedUsers: [conversation.target],
                )),
      );
    }
  }

  void _showEditDialog(BuildContext context, String title, String initialValue, Function(String) onConfirm) {
    final l10n = AppLocalizations.of(context)!;
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
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onConfirm(controller.text);
              },
              child: Text(l10n.confirm),
            ),
          ],
        );
      },
    );
  }
}
