
import 'package:flutter/cupertino.dart';

import '../message_cell.dart';
import '../message_model.dart';
import 'message_cell_builder.dart';

class UnknownCellBuilder extends MessageCellBuilder {
  UnknownCellBuilder(MessageState state, MessageModel model) : super(state, model);

  @override
  Widget getContent(BuildContext context) {
    return const Text('该消息暂未实现，请升级版本!', textAlign: TextAlign.center,);
  }
}