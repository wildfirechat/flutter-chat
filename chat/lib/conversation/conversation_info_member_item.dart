import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imclient/model/user_info.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/utils/layout_scale.dart';

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
          // 纯文本行:完整跟随字号,否则最大档位下 12sp 的名字会被 16px 的盒子裁掉。
          height: LayoutScale.watchScale(context, 16.0, cap: LayoutScale.textCap),
          child: Text(userInfo.getReadableName(), overflow: TextOverflow.ellipsis, maxLines: 1, style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
