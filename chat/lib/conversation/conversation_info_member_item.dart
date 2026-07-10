import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imclient/model/user_info.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/utils/layout_scale.dart';
import 'package:chat/theme/app_colors.dart';

import '../config.dart';

class ConversationInfoMemberItem extends StatelessWidget {
  final UserInfo userInfo;

  const ConversationInfoMemberItem(this.userInfo, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Portrait(
          userInfo.portrait ?? Config.defaultUserPortrait,
          Config.defaultUserPortrait,
          borderRadius: 8.0,
        ),
        const SizedBox(height: 6.0),
        SizedBox(
          // 纯文本行:完整跟随字号,否则最大档位下 12sp 的名字会被 16px 的盒子裁掉。
          height: LayoutScale.watchScale(context, 16.0, cap: LayoutScale.textCap),
          child: Text(
            userInfo.getReadableName(),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              fontSize: 12,
              color: context.colors.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}
