import 'package:badges/badges.dart' as badge;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import 'package:chat/config.dart';
import 'package:chat/organization/model/organization.dart';
import 'package:chat/organization/organization_view_model.dart';
import 'package:chat/ui_model/ui_contact_info.dart';
import 'package:chat/contact/friend_request_page.dart';
import 'package:chat/viewmodel/contact_list_view_model.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/organization/organization_screen.dart';
import 'package:chat/widget/sidebar_index.dart';

import '../user_info_widget.dart';
import 'fav_groups.dart';
import 'subscribed_channels.dart';

class ContactListWidget extends StatefulWidget {
  const ContactListWidget({super.key});

  @override
  State<ContactListWidget> createState() => _ContactListWidgetState();
}

class _ContactListWidgetState extends State<ContactListWidget> {
  final ScrollController _scrollController = ScrollController();
  String _currentLetter = '';
  bool _isTouchingIndex = false;

  List<UIContactInfo>? _cachedContactList;
  int _cachedHeaderCount = 0;
  Map<String, double> _cachedOffsets = {};


  Map<String, double> _getOffsets(List<UIContactInfo> contactList, int headerCount) {
    if (_cachedContactList == contactList && _cachedHeaderCount == headerCount) {
      return _cachedOffsets;
    }
    _cachedContactList = contactList;
    _cachedHeaderCount = headerCount;
    _cachedOffsets = _calculateIndexOffsets(contactList, headerCount);
    return _cachedOffsets;
  }

  Map<String, double> _calculateIndexOffsets(List<UIContactInfo> contactList, int headerCount) {
    Map<String, double> offsets = {};
    double offset = headerCount * 52.5;
    for (var contact in contactList) {
      if (contact.showCategory) {
        String category = contact.category;
        if (category == '{') category = '#';
        if (!offsets.containsKey(category)) {
          offsets[category] = offset;
        }
      }
      offset += contact.showCategory ? 70.5 : 52.5;
    }
    return offsets;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List fixHeaderList = [
      ['assets/images/contact_new_friend.png', AppLocalizations.of(context)!.newFriend, 'new_friend'],
      ['assets/images/contact_fav_group.png', AppLocalizations.of(context)!.favGroup, 'fav_group'],
      ['assets/images/contact_subscribed_channel.png', AppLocalizations.of(context)!.subscribedChannel, 'subscribed_channel'],
      // ['assets/images/contact_organization.png', AppLocalizations.of(context)!.organization, 'organization'],
    ];
    return ChangeNotifierProvider<OrganizationViewModel>(
      create: (_) {
        // Initialize OrganizationViewModel to handle organization-related logic
        var organizationViewModel = OrganizationViewModel();
        organizationViewModel.loadMyOrganizations();
        return organizationViewModel;
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Selector2<ContactListViewModel, OrganizationViewModel,
                  ({List<UIContactInfo> contactList, int unreadFriendRequestCount, List<Organization> rootOrgs, List<Organization> myOrgs})>(
                builder: (_, record, __) {
                  List<String> indexList = _getIndexList(record.contactList);
                  int headerCount = fixHeaderList.length + record.rootOrgs.length + record.myOrgs.length;
                  Map<String, double> indexOffsets = _getOffsets(record.contactList, headerCount);

                  return Stack(
                    children: [
                      ListView.builder(
                          controller: _scrollController,
                          itemCount: headerCount + record.contactList.length,
                          // 使用key帮助ListView正确处理数据更新
                          key: ValueKey('contact_list_${record.contactList.length}'),
                          cacheExtent: 200,
                          addRepaintBoundaries: true,
                          addAutomaticKeepAlives: false,
                          itemExtentBuilder: (index, dimensions) {
                            if (index < headerCount) {
                              return 52.5;
                            } else {
                              final contactInfo = record.contactList[index - headerCount];
                              return contactInfo.showCategory ? 70.5 : 52.5;
                            }
                          },
                          itemBuilder: (context, i) {
                            if (i < fixHeaderList.length) {
                              return _contactListFixHeader(context, i, record.unreadFriendRequestCount, fixHeaderList);
                            } else if (i < fixHeaderList.length + record.rootOrgs.length) {
                              var org = record.rootOrgs[i - fixHeaderList.length];
                              return _contactListOrgHeader(context, org, true);
                            } else if (i < headerCount) {
                              var org = record.myOrgs[i - fixHeaderList.length - record.rootOrgs.length];
                              return _contactListOrgHeader(context, org, false);
                            } else {
                              var contactInfo = record.contactList[i - headerCount];
                              return ContactListItem(
                                contactInfo,
                                key: ValueKey('contact_${contactInfo.userInfo.userId}-${contactInfo.userInfo.updateDt}'),
                              );
                            }
                          }),
                      if (indexList.isNotEmpty)
                        SidebarIndex(
                          indexList: indexList,
                          onIndexSelected: (tag) {
                            final offset = tag == '↑' ? 0.0 : indexOffsets[tag];
                            if (offset != null && _scrollController.hasClients) {
                              _scrollController.jumpTo(offset);
                            }
                          },
                          onTouch: (tag, isTouching) {
                            if (_currentLetter != tag || _isTouchingIndex != isTouching) {
                              setState(() {
                                _currentLetter = tag;
                                _isTouchingIndex = isTouching;
                              });
                            }
                          },
                        ),
                    ],
                  );
                },
                selector: (_, contactListViewModel, organizationViewModel) => (
                  contactList: contactListViewModel.contactList,
                  unreadFriendRequestCount: contactListViewModel.unreadFriendRequestCount,
                  rootOrgs: organizationViewModel.rootOrganizations,
                  myOrgs: organizationViewModel.myOrganizations
                ),
              ),
              if (_isTouchingIndex)
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: _currentLetter == '↑'
                        ? const Icon(Icons.arrow_upward, size: 40, color: Colors.white)
                        : Text(
                            _currentLetter,
                            style: const TextStyle(color: Colors.white, fontSize: 40),
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _getIndexList(List<UIContactInfo> contactList) {
    List<String> indexList = [];
    indexList.add('↑');
    for (var contact in contactList) {
      if (contact.showCategory) {
        String category = contact.category;
        if (category.startsWith("AI")) continue;
        if (category == "{") category = "#";
        if (!indexList.contains(category)) {
          indexList.add(category);
        }
      }
    }
    return indexList;
  }

  Widget _contactListFixHeader(BuildContext context, int index, int unreadFriendRequestCount, List<dynamic> fixHeaderList) {
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
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SubscribedChannelsPage()),
          );
        } else {
          Fluttertoast.showToast(msg: AppLocalizations.of(context)!.methodNotImpl);
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

class ContactListItem extends StatelessWidget {
  final UIContactInfo contactInfo;

  const ContactListItem(this.contactInfo, {super.key});

  @override
  Widget build(BuildContext context) {
    // 获取显示名称
    final displayName = contactInfo.userInfo.friendAlias ?? contactInfo.userInfo.displayName ?? '<${contactInfo.userInfo.userId}>';

    return RepaintBoundary(
      child: GestureDetector(
      onTap: () => _toUserInfoPage(context),
      child: Column(
        children: <Widget>[
          // 分类标题
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
                Portrait(contactInfo.userInfo.portrait ?? Config.defaultUserPortrait, Config.defaultUserPortrait),
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
      ),
    );
  }

  _toUserInfoPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UserInfoWidget(contactInfo.userInfo.userId)),
    );
  }
}



