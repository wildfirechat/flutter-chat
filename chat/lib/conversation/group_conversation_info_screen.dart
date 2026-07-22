import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/imclient_platform.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/group_member.dart';
import 'package:imclient/model/im_constant.dart';
import 'package:provider/provider.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/app_navigator.dart';
import 'package:chat/viewmodel/conversation_view_model.dart';
import 'package:chat/viewmodel/group_conversation_info_view_model.dart';
import 'package:chat/viewmodel/group_view_model.dart';
import 'package:chat/widget/option_button_item.dart';
import 'package:chat/widget/option_item.dart';
import 'package:chat/widget/option_switch_item.dart';
import 'package:chat/widget/section_divider.dart';

import '../contact/pick_user_screen.dart';
import '../pc/pc_platform.dart';
import '../pc/pc_user_card.dart';
import '../pc/search_window/search_window_manager.dart';
import '../search/search_conversation_result_view.dart';
import '../user_info_widget.dart';
import 'conversation_files_screen.dart';
import 'conversation_links_screen.dart';
import 'group_announcement_screen.dart';
import 'group_conversation_info_members_view.dart';
import 'group_manage_screen.dart';
import 'group_qrcode_screen.dart';

import 'package:chat/theme/app_colors.dart';

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
                  backgroundColor: isDesktopShell ? context.colors.surface : context.colors.primaryBackground,
                  appBar: isDesktopShell
                      ? null
                      : AppBar(
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
      if (isDesktopShell) const SizedBox(height: 12.0),
      Container(
        color: context.colors.surface,
        child: GroupConversationInfoMembersView(
          conversation,
          onGroupMemberTap: (userInfo, anchor) {
            // 桌面端点群成员弹用户信息卡片(与会话内点头像一致),移动端仍整页打开
            if (isDesktopShell) {
              showPcUserCard(context: context, anchor: anchor, userId: userInfo.userId, groupId: conversation.target);
            } else {
              openPage(context, UserInfoWidget(userInfo.userId));
            }
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
      ),
      const SectionDivider(),
      Container(
        color: context.colors.surface,
        child: Column(
          children: [
            OptionItem(l10n.groupMemberList, onTap: () {}),
            OptionItem(l10n.groupNameLabel, desc: groupInfo?.name ?? '', onTap: () {
              if (groupInfo != null &&
                  groupInfo.type == GroupType.Restricted &&
                  (groupMember.type == GroupMemberType.Owner || groupMember.type == GroupMemberType.Manager)) {
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
                pushPage(context, GroupQrCodeScreen(groupInfo: groupInfo));
              }
            }),
            OptionItem(l10n.groupAnnouncement, desc: groupConversationInfoViewModel.groupAnnouncement ?? l10n.clickToCheck, onTap: () {
              pushPage(
                context,
                GroupAnnouncementScreen(
                  groupId: conversation.target,
                  canEdit: groupMember.type == GroupMemberType.Owner || groupMember.type == GroupMemberType.Manager,
                ),
              );
              groupConversationInfoViewModel.refreshGroupAnnouncement(conversation.target);
            }),
            OptionItem(l10n.groupRemarkLabel, desc: groupInfo?.remark, showBottomDivider: groupInfo == null || groupInfo.type != GroupType.Restricted || (groupMember.type != GroupMemberType.Manager && groupMember.type != GroupMemberType.Owner), onTap: () {
              _showEditDialog(context, l10n.modifyGroupRemarkDialog, groupInfo?.remark ?? '', (value) {
                Imclient.setGroupRemark(conversation.target, value, () {}, (errorCode) {
                  Fluttertoast.showToast(msg: l10n.modifyFailedWithCode(errorCode.toString()));
                });
              });
            }),
            if (groupInfo != null &&
                groupInfo.type == GroupType.Restricted &&
                (groupMember.type == GroupMemberType.Manager || groupMember.type == GroupMemberType.Owner))
              OptionItem(l10n.groupManagement, showBottomDivider: false, onTap: () {
                if (groupInfo != null) {
                  pushPage(context, GroupManageScreen(groupInfo: groupInfo));
                }
              })
          ],
        ),
      ),
      const SectionDivider(),
      Container(
        color: context.colors.surface,
        child: Column(
          children: [
            OptionItem(l10n.searchChatContents, onTap: () {
              // 原生桌面端在独立的"聊天记录"窗口中搜索(类 PC 微信),其它平台保持页内跳转
              if (WfcPlatform.isNativeDesktop) {
                final groupName = groupInfo.name ?? '';
                SearchWindowManager.instance.show(
                  conversation: conversation,
                  conversationTitle: groupName.isNotEmpty
                      ? groupName
                      : conversation.target,
                );
              } else {
                pushPage(
                  context,
                  SearchConversationResultView(
                    conversation: conversation,
                    keyword: '',
                  ),
                );
              }
            }),
            OptionItem(l10n.chatFiles, onTap: () {
              pushPage(context, ConversationFilesScreen(conversation));
            }),
            OptionItem(l10n.chatLinks, showBottomDivider: false, onTap: () {
              openPage(context, ConversationLinksScreen(conversation));
            }),
          ],
        ),
      ),
      const SectionDivider(),
      Container(
        color: context.colors.surface,
        child: Column(
          children: [
            OptionSwitchItem(l10n.muteNotification, conversationInfo.isSilent, (enable) {
              conversationViewModel.setConversationSilent(conversationInfo.conversation, enable);
            }),
            OptionSwitchItem(l10n.stickTop, conversationInfo.isTop > 0, (enable) {
              conversationViewModel.setConversationTop(conversationInfo.conversation, enable ? 1 : 0);
            }),
            OptionSwitchItem(l10n.favoriteGroup, groupConversationInfoViewModel.isFavGroup, showBottomDivider: false, (enable) {
              groupConversationInfoViewModel.setFavGroup(conversationInfo.conversation.target, enable);
            }),
          ],
        ),
      ),
      const SectionDivider(),
      Container(
        color: context.colors.surface,
        child: Column(
          children: [
            OptionItem(l10n.myAliasInGroupLabel, desc: groupMember.alias, onTap: () {
              _showEditDialog(context, l10n.modifyGroupAliasDialog, groupMember.alias ?? '', (value) {
                Imclient.modifyGroupAlias(conversation.target, value, () {}, (errorCode) {
                  Fluttertoast.showToast(msg: l10n.modifyFailedWithCode(errorCode.toString()));
                });
              });
            }),
            OptionSwitchItem(l10n.showGroupMemberNames, !conversationViewModel.isHiddenConversationMemberName, showBottomDivider: false, (enable) {
              conversationViewModel.setHideGroupMemberName(conversationInfo.conversation.target, !enable);
            }),
          ],
        ),
      ),
      const SectionDivider(),
      Container(
        color: context.colors.surface,
        child: Column(
          children: [
            OptionButtonItem(l10n.clearChatHistory, () {
              _showClearMessageDialog(context, conversation);
            }, showBottomDivider: true),
            if (groupMember.type == GroupMemberType.Owner) ...[
              OptionButtonItem(l10n.transferGroup, () {
                _onTransferGroup(context);
              }, showBottomDivider: true),
              OptionButtonItem(l10n.dismissGroup, () {
                _showDismissGroupConfirmDialog(context);
              }, showBottomDivider: false),
            ] else ...[
              OptionButtonItem(l10n.quitGroupChat, () {
                _showQuitGroupConfirmDialog(context);
              }, showBottomDivider: false),
            ],
          ],
        ),
      ),
      const SizedBox(height: SectionDivider.gap),
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
                padding: const EdgeInsets.symmetric(vertical: 8),
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
                padding: const EdgeInsets.symmetric(vertical: 8),
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
        // 桌面为居中 Dialog,移动端整页 push
        showPickUserScreen(
          context,
          title: l10n.removeGroupMembers,
          (pickerContext, members) async {
            if (members.isEmpty) {
              Navigator.pop(pickerContext);
            } else {
              Imclient.kickoffGroupMembers(conversation.target, members, () {
                Navigator.pop(pickerContext);
              }, (errorCode) {});
            }
          },
          disabledUncheckedUsers: [Imclient.currentUserId],
          candidates: memberIds,
          // 移除成员的候选就是现有群成员,从组织架构选人无意义
          showOrganizationEntry: false,
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
          // 桌面为居中 Dialog,移动端整页 push
          showPickUserScreen(
            context,
            title: l10n.addGroupMembers,
            (pickerContext, members) async {
              if (members.isEmpty) {
                Navigator.pop(pickerContext);
              } else {
                Imclient.addGroupMembers(conversation.target, members, () {
                  Navigator.pop(pickerContext);
                }, (errorCode) {
                  if (errorCode == ErrorCode.joinGroupNeedVerify) {
                    Navigator.pop(pickerContext);
                    _showJoinGroupReasonDialog(context, members);
                  }
                });
              }
            },
            disabledCheckedUsers: memberIds,
          );
        }
      });
    } else {
      showPickUserScreen(
        context,
        title: l10n.selectContacts,
        (pickerContext, members) async {
          Navigator.pop(pickerContext);
          if (members.isNotEmpty) {
            List<String> groupMembers = List.from(members);
            if (!groupMembers.contains(conversation.target)) {
              groupMembers.add(conversation.target);
            }
            Imclient.createGroup(null, null, null, 2, groupMembers, (strValue) {
              // 用外层 context(详情页仍挂载):桌面右栏打开新群会话,移动端 push
              openConversation(context, Conversation(conversationType: ConversationType.Group, target: strValue, line: 0));
            }, (errorCode) {
              Fluttertoast.showToast(msg: l10n.networkError);
            });
          }
        },
        disabledCheckedUsers: [conversation.target],
      );
    }
  }

  void _showJoinGroupReasonDialog(BuildContext context, List<String> members) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.joinGroupVerificationEnabled),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.pleaseInputJoinGroupReason),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final reason = controller.text.trim();
              Imclient.sendJoinGroupRequest(
                conversation.target,
                members,
                reason: reason,
                successCallback: () {
                  Fluttertoast.showToast(msg: l10n.joinGroupRequestSent);
                },
                errorCallback: (code) {
                  Fluttertoast.showToast(msg: l10n.sendFailure);
                },
              );
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
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

  void _showDismissGroupConfirmDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l10n.dismissGroup),
          content: Text('${l10n.dismissGroup}？'),
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
                _handleDismissGroup(context);
              },
              child: Text(l10n.confirm, style: const TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showQuitGroupConfirmDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l10n.quitGroupChat),
          content: Text('${l10n.quitGroupChat}？'),
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
                _handleQuitGroup(context);
              },
              child: Text(l10n.confirm, style: const TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _onTransferGroup(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentContext = context;
    Imclient.getGroupMembers(conversation.target).then((members) {
      if (members.isEmpty) return;
      List<String> candidateIds = [];
      for (var member in members) {
        if (member.memberId != Imclient.currentUserId) {
          candidateIds.add(member.memberId);
        }
      }
      if (candidateIds.isEmpty) {
        Fluttertoast.showToast(msg: l10n.noOtherMembersToTransfer);
        return;
      }
      showPickUserScreen(
        currentContext,
        title: l10n.transferGroup,
        (pickerContext, pickedUsers) {
          if (pickedUsers.isEmpty) {
            Navigator.pop(pickerContext);
            return;
          }
          Imclient.transferGroup(conversation.target, pickedUsers.first, () {
            Navigator.pop(pickerContext);
            Fluttertoast.showToast(msg: l10n.transferGroupSuccess);
          }, (errorCode) {
            Fluttertoast.showToast(msg: '${l10n.transferGroup}$errorCode');
          });
        },
        candidates: candidateIds,
        maxSelected: 1,
        showOrganizationEntry: false,
      );
    });
  }

  void _handleDismissGroup(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    
    Imclient.dismissGroup(conversation.target, () {
      Fluttertoast.showToast(msg: '${l10n.dismissGroup}成功');
      Future.delayed(const Duration(milliseconds: 200), () {
        navigator.popUntil((r) => r.isFirst);
      });
    }, (errorCode) {
      Fluttertoast.showToast(msg: '${l10n.dismissGroup}失败: $errorCode');
    });
  }

  void _handleQuitGroup(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    
    Imclient.quitGroup(conversation.target, () {
      Fluttertoast.showToast(msg: '${l10n.quitGroupChat}成功');
      // 延迟后返回到会话列表
      Future.delayed(const Duration(milliseconds: 200), () {
        navigator.popUntil((r) => r.isFirst);
      });
    }, (errorCode) {
      Fluttertoast.showToast(msg: '${l10n.quitGroupChat}失败: $errorCode');
    });
  }
}
