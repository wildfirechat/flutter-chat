import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imclient/model/user_info.dart';
import 'package:wfc_example/widget/portrait.dart';

import '../config.dart';

class ConversationMemberItem extends StatelessWidget {
  final UserInfo userInfo;

  const ConversationMemberItem(this.userInfo, {super.key});

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
