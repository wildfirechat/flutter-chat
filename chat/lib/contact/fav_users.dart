import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/config.dart';
import 'package:chat/conversation/conversation_screen.dart';
import 'package:chat/viewmodel/user_view_model.dart';
import 'package:chat/widget/portrait.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class FavUsersPage extends StatefulWidget {
  const FavUsersPage({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => FavUsersPageState();
}

class FavUsersPageState extends State<FavUsersPage> {
  List<String> favUserIds = [];

  @override
  void initState() {
    super.initState();
    Imclient.getFavUsers().then((userIds) {
      if (userIds != null) {
        setState(() {
          favUserIds = userIds;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.favFriend),
      ),
      body: ListView.builder(
        itemCount: favUserIds.length,
        itemBuilder: (context, index) {
          return _buildUserItem(favUserIds[index]);
        },
      ),
    );
  }

  Widget _buildUserItem(String userId) {
    return Consumer<UserViewModel>(
      builder: (context, userViewModel, child) {
        UserInfo? userInfo = userViewModel.getUserInfo(userId);
        if (userInfo == null) {
          return Container();
        }
        return ListTile(
          leading: Portrait(userInfo.portrait ?? Config.defaultUserPortrait, Config.defaultUserPortrait),
          title: Text(userInfo.displayName ?? 'User'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ConversationScreen(
                  Conversation(conversationType: ConversationType.Single, target: userId, line: 0),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
