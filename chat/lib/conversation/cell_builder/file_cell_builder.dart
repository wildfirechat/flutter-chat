import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imclient/message/file_message_content.dart';
import 'package:chat/conversation/cell_builder/portrait_cell_builder.dart';
import 'package:chat/utilities.dart';

import '../message_cell.dart';
import '../../ui_model/ui_message.dart';
import 'package:chat/theme/app_typography.dart';

class FileCellBuilder extends PortraitCellBuilder {
  late FileMessageContent fileMessageContent;

  FileCellBuilder(BuildContext context, UIMessage model)
      : super(context, model) {
    fileMessageContent = model.message.content as FileMessageContent;
  }

  @override
  Widget buildMessageContent(BuildContext context) {
    String imagePaht =
        'assets/images/file_type/${Utilities.fileType(fileMessageContent.name)}.png';
    Image image = Image.asset(imagePaht, width: 32.0, height: 32.0);
    Text nameText = Text(
      fileMessageContent.name,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    SizedBox padding = const SizedBox(
      width: 3,
      height: 3,
    );
    Text sizeText = Text(
      Utilities.formatSize(fileMessageContent.size),
      style: AppText.xs,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        padding,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              // 文件名最多占窗口宽的三分之一。数值与原先直接读
              // PlatformDispatcher.views.first 时一致(都是本窗口的逻辑宽),
              // 但走 MediaQuery 才会在窗口尺寸变化时重建 —— 而且多窗口下
              // views.first 拿到的是主窗口,子窗口(媒体预览/搜索)里是错的。
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width / 3),
              child: nameText,
            ),
            padding,
            sizeText,
          ],
        ),
        SizedBox(
          width: 32,
          height: 32,
          child: image,
        ),
        padding,
      ],
    );
  }
}
