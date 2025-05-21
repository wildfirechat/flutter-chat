import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imclient/model/user_info.dart';

import '../config.dart';

class ConversationMemberItem extends StatelessWidget {
  final UserInfo userInfo;

  const ConversationMemberItem(this.userInfo, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox.square(
            dimension: 48,
            child: ClipRRect(
                borderRadius: BorderRadius.circular(6.0),
                child: CachedNetworkImage(
                  imageUrl: userInfo.portrait ?? Config.defaultUserPortrait,
                  width: 44.0,
                  height: 44.0,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Image.asset(Config.defaultUserPortrait, width: 44.0, height: 44.0),
                  errorWidget: (context, url, err) => Image.asset(Config.defaultUserPortrait, width: 44.0, height: 44.0),
                ))),
        SizedBox(
          height: 16,
          child: Text(userInfo.getReadableName(), overflow: TextOverflow.ellipsis, maxLines: 1, style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
