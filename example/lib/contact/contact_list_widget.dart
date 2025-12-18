import 'package:badges/badges.dart' as badge;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import 'package:wfc_example/config.dart';
import 'package:wfc_example/organization/model/organization.dart';
import 'package:wfc_example/organization/organization_view_model.dart';
import 'package:wfc_example/ui_model/ui_contact_info.dart';
import 'package:wfc_example/contact/friend_request_page.dart';
import 'package:wfc_example/viewmodel/contact_list_view_model.dart';
import 'package:wfc_example/widget/portrait.dart';
import 'package:wfc_example/organization/organization_screen.dart';

import '../user_info_widget.dart';
import 'fav_groups.dart';

class ContactListWidget extends StatelessWidget {
  ContactListWidget({super.key});

  final List fixHeaderList = [
    ['assets/images/contact_new_friend.png', '新好友', 'new_friend'],
    ['assets/images/contact_fav_group.png', '收藏群组', 'fav_group'],
    ['assets/images/contact_subscribed_channel.png', '频道', 'subscribed_channel'],
    // ['assets/images/contact_organization.png', '组织架构', 'organization'],
  ];

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<OrganizationViewModel>(
        create: (_) {
          // Initialize OrganizationViewModel to handle organization-related logic
          var organizationViewModel = OrganizationViewModel();
          organizationViewModel.loadMyOrganizations();
          return organizationViewModel;
        },
        child: Selector2<ContactListViewModel, OrganizationViewModel,
                ({List<UIContactInfo> contactList, int unreadFriendRequestCount, List<Organization> rootOrgs, List<Organization> myOrgs})>(
            builder: (_, record, __) {
              return Scaffold(
                body: SafeArea(
                  child: ListView.builder(
                      itemCount: fixHeaderList.length + record.contactList.length + record.rootOrgs.length + record.myOrgs.length,
                      // 使用key帮助ListView正确处理数据更新
                      key: ValueKey('contact_list_${record.contactList.length}'),
                      cacheExtent: 1024,
                      itemExtentBuilder: (i, _) {
                        if (i < fixHeaderList.length + record.rootOrgs.length + record.myOrgs.length) {
                          return 52.5;
                        } else {
                          return record.contactList[i - fixHeaderList.length - record.rootOrgs.length - record.myOrgs.length].showCategory ? 52.5 + 18 : 52.5;
                        }
                      },
                      itemBuilder: (context, i) {
                        if (i < fixHeaderList.length) {
                          return _contactListFixHeader(context, i, record.unreadFriendRequestCount);
                        } else if (i < fixHeaderList.length + record.rootOrgs.length) {
                          var org = record.rootOrgs[i - fixHeaderList.length];
                          return _contactListOrgHeader(context, org, true);
                        } else if (i < fixHeaderList.length + record.rootOrgs.length + record.myOrgs.length) {
                          var org = record.myOrgs[i - fixHeaderList.length - record.rootOrgs.length];
                          return _contactListOrgHeader(context, org, false);
                        } else {
                          var contactInfo = record.contactList[i - fixHeaderList.length - record.rootOrgs.length - record.myOrgs.length];
                          return ContactListItem(
                            contactInfo,
                            key: ValueKey('contact_${contactInfo.userInfo.userId}-${contactInfo.userInfo.updateDt}'),
                          );
                        }
                      }),
                ),
              );
            },
            selector: (_, contactListViewModel, organizationViewModel) => (
                  contactList: contactListViewModel.contactList,
                  unreadFriendRequestCount: contactListViewModel.unreadFriendRequestCount,
                  rootOrgs: organizationViewModel.rootOrganizations,
                  myOrgs: organizationViewModel.myOrganizations
                )));
  }

  Widget _contactListFixHeader(BuildContext context, int index, int unreadFriendRequestCount) {
    String imagePath = fixHeaderList[index][0];
    String title = fixHeaderList[index][1];
    String key = fixHeaderList[index][2];
    return GestureDetector(
      onTap: () {
        if (key == "new_friend") {
          var contactListViewModel = Provider.of<ContactListViewModel>(context, listen: false);
          contactListViewModel.clearUnreadFriendRequestStatus();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FriendRequestPage()),
          );
        } else if (key == "fav_group") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FavGroupsPage()),
          );
        } else if (key == "subscribed_channel") {
          Fluttertoast.showToast(msg: 'TODO');
        } else {
          Fluttertoast.showToast(msg: "方法没有实现");
          if (kDebugMode) {
            print("on tap item $index");
          }
        }
      },
      child: Column(
        children: <Widget>[
          Container(
            height: 52.0,
            margin: const EdgeInsets.fromLTRB(16.0, 0.0, 0.0, 0.0),
            child: Row(
              children: <Widget>[
                key == 'new_friend'
                    ? badge.Badge(
                        showBadge: unreadFriendRequestCount > 0,
                        badgeContent: Text('$unreadFriendRequestCount'),
                        // TODO: Replace 'assets/images/contact_organization.png' with an actual asset if it doesn't exist
                        child: Image.asset(imagePath, width: 40.0, height: 40.0))
                    : Image.asset(imagePath, width: 40.0, height: 40.0),
                Container(
                  margin: const EdgeInsets.only(left: 16),
                ),
                Expanded(
                    child: Text(
                  title,
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

  Widget _contactListOrgHeader(BuildContext context, Organization org, bool isRoot) {
    String imagePath = isRoot ? 'assets/images/contact_organization.png' : 'assets/images/contact_organization_expended.png';
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          // Directly navigate to OrganizationViewPage.
          // The ViewModel in OrganizationViewPage will handle loading the root/default organization.
          MaterialPageRoute(
              builder: (context) => OrganizationScreen(
                    initialOrganizationId: org.id,
                  )),
        );
      },
      child: Column(
        children: <Widget>[
          Container(
            height: 52.0,
            margin: const EdgeInsets.fromLTRB(16.0, 0.0, 0.0, 0.0),
            child: Row(
              children: <Widget>[
                Image.asset(imagePath, width: 40.0, height: 40.0),
                Container(
                  margin: const EdgeInsets.only(left: 16),
                ),
                Expanded(
                    child: Text(
                  org.name ?? '',
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

class ContactListItem extends StatefulWidget {
  final UIContactInfo contactInfo;

  const ContactListItem(this.contactInfo, {super.key});

  @override
  State<ContactListItem> createState() => _ContactListItemState();
}

class _ContactListItemState extends State<ContactListItem> with AutomaticKeepAliveClientMixin {
  // @override
  // void didUpdateWidget(ContactListItem oldWidget) {
  //   super.didUpdateWidget(oldWidget);
  //   if (oldWidget.contactInfo.userInfo.updateDt != widget.contactInfo.userInfo.updateDt) {
  //   do something
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    debugPrint('----------build contactItem');
    // 获取显示名称
    final displayName = widget.contactInfo.userInfo.friendAlias ?? widget.contactInfo.userInfo.displayName ?? '<${widget.contactInfo.userInfo.userId}>';

    return GestureDetector(
      onTap: () => _toUserInfoPage(context),
      child: Column(
        children: <Widget>[
          // 分类标题
          Container(
            height: widget.contactInfo.showCategory ? 18 : 0,
            width: View.of(context).physicalSize.width / View.of(context).devicePixelRatio,
            color: const Color(0xffebebeb),
            padding: const EdgeInsets.only(left: 16),
            child: widget.contactInfo.showCategory ? Text(widget.contactInfo.category == '{' ? '#' : widget.contactInfo.category) : null,
          ),
          Container(
            height: 52.0,
            margin: const EdgeInsets.fromLTRB(16.0, 0.0, 0.0, 0.0),
            child: Row(
              children: <Widget>[
                Portrait(widget.contactInfo.userInfo.portrait ?? Config.defaultUserPortrait, Config.defaultUserPortrait),
                Container(
                  margin: const EdgeInsets.only(left: 16),
                ),
                Expanded(
                    child: Text(
                  displayName,
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

  @override
  bool get wantKeepAlive => true;

  ///
  /// 跳转聊天界面
  ///
  ///
  _toUserInfoPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UserInfoWidget(widget.contactInfo.userInfo.userId)),
    );
  }
}
