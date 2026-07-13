import 'package:flutter/material.dart';
import 'package:imclient/message/composite_message_content.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/conversation/cell_builder/portrait_cell_builder.dart';
import 'package:chat/conversation/composite_message_detail_screen.dart';
import 'package:chat/ui_model/ui_message.dart';
import 'package:chat/viewmodel/user_view_model.dart';
import 'package:chat/app_navigator.dart';
import 'package:chat/utils/mesh_user_display.dart';
import 'package:chat/theme/app_typography.dart';

class CompositeCellBuilder extends PortraitCellBuilder {
  late CompositeMessageContent compositeMessageContent;

  CompositeCellBuilder(BuildContext context, UIMessage model) : super(context, model) {
    compositeMessageContent = model.message.content as CompositeMessageContent;
  }

  @override
  Widget buildMessageContent(BuildContext context) {
    return GestureDetector(
      onTap: () {
        pushPage(context, CompositeMessageDetailScreen(compositeMessageContent));
      },
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              compositeMessageContent.title,
              style: AppText.lg.copyWith(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // height 16:标题与预览之间要留呼吸空间,不只是画线。
            const Divider(height: 16),
            Selector<UserViewModel, (UserInfo?, UserInfo?, UserInfo?, UserInfo?)>(
              selector: (context, userViewModel) {
                var msgs = compositeMessageContent.messages;
                return (
                  msgs.isNotEmpty ? userViewModel.getUserInfo(msgs[0].fromUser) : null,
                  msgs.length > 1 ? userViewModel.getUserInfo(msgs[1].fromUser) : null,
                  msgs.length > 2 ? userViewModel.getUserInfo(msgs[2].fromUser) : null,
                  msgs.length > 3 ? userViewModel.getUserInfo(msgs[3].fromUser) : null,
                );
              },
              builder: (context, data, child) {
                var msgs = compositeMessageContent.messages.take(4).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(msgs.length, (index) {
                    var msg = msgs[index];
                    String preview = "";
                    if (msg.content is TextMessageContent) {
                      preview = (msg.content as TextMessageContent).text;
                    } else if (msg.content is ImageMessageContent) {
                      preview = "[图片]";
                    } else {
                      preview = "[消息]";
                    }

                    UserInfo? userInfo;
                    if (index == 0) userInfo = data.$1;
                    else if (index == 1) userInfo = data.$2;
                    else if (index == 2) userInfo = data.$3;
                    else if (index == 3) userInfo = data.$4;

                    String senderName = userInfo != null ? "${MeshUserDisplay.getReadableName(userInfo)}: " : "";

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: userInfo != null
                          ? Text.rich(
                              TextSpan(
                                children: [
                                  MeshUserDisplay.getReadableNameSpan(userInfo, style: AppText.xs.copyWith(color: Colors.grey)),
                                  TextSpan(text: ': $preview', style: AppText.xs.copyWith(color: Colors.grey)),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : Text(
                              preview,
                              style: AppText.xs.copyWith(color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                    );
                  }),
                );
              },
            ),
            if (compositeMessageContent.messages.length > 4)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  "...",
                  style: AppText.xs.copyWith(color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
