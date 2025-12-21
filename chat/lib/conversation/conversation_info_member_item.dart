import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imclient/model/user_info.dart';
import 'package:chat/widget/portrait.dart';

import '../config.dart';

class ConversationInfoMemberItem extends StatelessWidget {
  final UserInfo userInfo;

  const ConversationInfoMemberItem(this.userInfo, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Portrait(userInfo.portrait ?? Config.defaultUserPortrait, Config.defaultUserPortrait),
        SizedBox(
          height: 16,
          child: Text(userInfo.getReadableName(), overflow: TextOverflow.ellipsis, maxLines: 1, style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
