import 'dart:async';

import 'package:badges/badges.dart' as badge;
import 'package:event_bus/event_bus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:provider/provider.dart';

import 'package:wfc_example/config.dart';
import 'package:wfc_example/contact/contact_info.dart';
import 'package:wfc_example/contact/friend_request_page.dart';
import 'package:wfc_example/viewmodel/contact_list_view_model.dart';

import '../user_info_widget.dart';
import 'fav_groups.dart';

class ContactListWidget extends StatefulWidget {
  void Function(int unreadCount)? unreadCountCallback;

  ContactListWidget({Key? key, this.unreadCountCallback}) : super(key: key);

  @override
  State createState() => _ContactListWidgetState();
}

class _ContactListWidgetState extends State<ContactListWidget> {
  final EventBus _eventBus = Imclient.IMEventBus;
  late StreamSubscription<FriendRequestUpdateEvent> _friendRequestUpdatedSubscription;

  List fixModelList = [
    ['assets/images/contact_new_friend.png', '新好友', 'new_friend'],
    ['assets/images/contact_fav_group.png', '收藏群组', 'fav_group'],
    ['assets/images/contact_subscribed_channel.png', '订阅频道', 'subscribed_channel'],
  ];
  int unreadFriendRequestCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNewFriendRequestCount();

    _friendRequestUpdatedSubscription = _eventBus.on<FriendRequestUpdateEvent>().listen((event) {
      _loadNewFriendRequestCount();
    });
  }

  void _loadNewFriendRequestCount() {
    Imclient.getUnreadFriendRequestStatus().then((value) {
      if (widget.unreadCountCallback != null) {
        widget.unreadCountCallback!(value);
      }
      setState(() {
        unreadFriendRequestCount = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    var contactListViewModel = Provider.of<ContactListViewModel>(context);
    var contactList = contactListViewModel.contactList;
    return Scaffold(
      body: SafeArea(
        child: ListView.builder(
            itemCount: fixModelList.length + contactList.length,
            itemBuilder: /*1*/ (context, i) {
              if (i < fixModelList.length) {
                return _fixRow(context, i);
              } else {
                return Selector<ContactListViewModel, ContactInfo>(selector: (_, contactInfo) {
                  return contactList[i - fixModelList.length];
                }, builder: (context, contactInfo, child) {
                  return ContactListItem(contactInfo);
                });
              }
            }),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _friendRequestUpdatedSubscription.cancel();
  }

  Widget _fixRow(BuildContext context, int index) {
    String imagePaht = fixModelList[index][0];
    String title = fixModelList[index][1];
    String key = fixModelList[index][2];
    return GestureDetector(
      onTap: () {
        if (key == "new_friend") {
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
                key == 'new_friend' ? badge.Badge(showBadge: unreadFriendRequestCount > 0, badgeContent: Text('$unreadFriendRequestCount'), child: Image.asset(imagePaht, width: 40.0, height: 40.0)) : Image.asset(imagePaht, width: 40.0, height: 40.0),
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
  final ContactInfo contactInfo;

  const ContactListItem(this.contactInfo, {Key? key}) : super(key: key);

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
                contactInfo.userInfo.portrait == null ? Image.asset(Config.defaultUserPortrait, width: 40.0, height: 40.0) : Image.network(contactInfo.userInfo.portrait!, width: 40.0, height: 40.0),
                Container(
                  margin: const EdgeInsets.only(left: 16),
                ),
                Expanded(
                    child: Text(
                  contactInfo.userInfo.displayName!,
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
