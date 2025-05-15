import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imclient/model/user_info.dart';

import '../config.dart';

class ConversationMemberItem extends StatelessWidget {
  final UserInfo userInfo;

  const ConversationMemberItem(this.userInfo, {super.key});

  @override
  Widget build(BuildContext context) {
    String? portrait;
    String name = '';
    late Image image;
    name = '<${userInfo.userId}>';

    if (userInfo.portrait != null) {
      portrait = userInfo.portrait!;
    }
    if (userInfo.friendAlias != null) {
      name = userInfo.friendAlias!;
    } else if (userInfo.groupAlias != null) {
      name = userInfo.groupAlias!;
    } else if (userInfo.displayName != null) {
      name = userInfo.displayName!;
    }

    image = portrait == null ? Image.asset(Config.defaultUserPortrait) : Image.network(portrait);

    return Column(
      children: [
        SizedBox.square(
          dimension: 48,
          child: image,
        ),
        SizedBox(
          height: 16,
          child: Text(name, overflow: TextOverflow.ellipsis, maxLines: 1, style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
