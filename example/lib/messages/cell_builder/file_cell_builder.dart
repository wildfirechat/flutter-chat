
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imclient/message/file_message_content.dart';
import 'package:wfc_example/messages/cell_builder/portrait_cell_builder.dart';
import 'package:wfc_example/utilities.dart';

import '../message_cell.dart';
import '../../ui_model/ui_message.dart';

class FileCellBuilder extends PortraitCellBuilder {
  late FileMessageContent fileMessageContent;

  FileCellBuilder(BuildContext context, UIMessage model) : super(context, model) {
    fileMessageContent = model.message.content as FileMessageContent;
  }

  @override
  Widget buildMessageContent(BuildContext context) {
    String imagePaht = 'assets/images/file_type/${Utilities.fileType(fileMessageContent.name)}.png';
    Image image = Image.asset(imagePaht, width: 32.0, height: 32.0);
    Text nameText = Text(fileMessageContent.name, maxLines: 2, overflow: TextOverflow.ellipsis,);
    SizedBox padding = const SizedBox(width: 3, height: 3,);
    Text sizeText = Text(Utilities.formatSize(fileMessageContent.size), style: const TextStyle(fontSize: 12),);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        padding,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(constraints: BoxConstraints(maxWidth: View.of(context).physicalSize.width/View.of(context).devicePixelRatio/3), child: nameText,),
            padding,
            sizeText,
          ],
        ),
        SizedBox(width: 32, height: 32, child: image,),
        padding,
      ],
    );
  }
}
