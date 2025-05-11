import 'package:badges/badges.dart' as badge;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import 'package:wfc_example/config.dart';
import 'package:wfc_example/ui_model/ui_contact_info.dart';
import 'package:wfc_example/contact/friend_request_page.dart';
import 'package:wfc_example/viewmodel/contact_list_view_model.dart';

import '../user_info_widget.dart';
import 'fav_groups.dart';

class ContactListWidget extends StatelessWidget {
  ContactListWidget({super.key});

  final List fixHeaderList = [
    ['assets/images/contact_new_friend.png', '新好友', 'new_friend'],
    ['assets/images/contact_fav_group.png', '收藏群组', 'fav_group'],
    ['assets/images/contact_subscribed_channel.png', '订阅频道', 'subscribed_channel'],
  ];

  @override
  Widget build(BuildContext context) {
    return Selector<ContactListViewModel, ({List<UIContactInfo> contactList, int unreadFriendRequestCount})>(
        builder: (_, record, __) => Scaffold(
              body: SafeArea(
                child: ListView.builder(
                    itemCount: fixHeaderList.length + record.contactList.length,
                    itemBuilder: (context, i) {
                      if (i < fixHeaderList.length) {
                        return _contactListHeader(context, i, record.unreadFriendRequestCount);
                      } else {
                        var contactInfo = record.contactList[i - fixHeaderList.length];
                        return ContactListItem(contactInfo);
                      }
                    }),
              ),
            ),
        selector: (_, contactListViewModel) => (contactList: contactListViewModel.contactList, unreadFriendRequestCount: contactListViewModel.unreadFriendRequestCount));
  }

  Widget _contactListHeader(BuildContext context, int index, int unreadFriendRequestCount) {
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
}

class ContactListItem extends StatelessWidget {
  final UIContactInfo contactInfo;

  const ContactListItem(this.contactInfo, {super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _toUserInfoPage(context),
      child: Column(
        children: <Widget>[
          Container(
            height: contactInfo.showCategory ? 18 : 0,
            width: View.of(context).physicalSize.width / View.of(context).devicePixelRatio,
            color: const Color(0xffebebeb),
            padding: const EdgeInsets.only(left: 16),
            child: contactInfo.showCategory ? Text(contactInfo.category == '{' ? '#' : contactInfo.category) : null,
          ),
          Container(
            height: 52.0,
            margin: const EdgeInsets.fromLTRB(16.0, 0.0, 0.0, 0.0),
            child: Row(
              children: <Widget>[
                contactInfo.userInfo.portrait == null
                    ? Image.asset(Config.defaultUserPortrait, width: 40.0, height: 40.0)
                    : Image.network(contactInfo.userInfo.portrait!, width: 40.0, height: 40.0),
                Container(
                  margin: const EdgeInsets.only(left: 16),
                ),
                Expanded(
                    child: Text(
                  contactInfo.userInfo.friendAlias ?? contactInfo.userInfo.displayName ?? '<${contactInfo.userInfo.userId}>',
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

  ///
  /// 跳转聊天界面
  ///
  ///
  _toUserInfoPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UserInfoWidget(contactInfo.userInfo.userId)),
    );
  }
}
