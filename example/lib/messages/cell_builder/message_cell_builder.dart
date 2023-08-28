import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../utilities.dart';
import '../message_cell.dart';
import '../message_model.dart';

abstract class MessageCellBuilder {
  MessageModel model;
  MessageState state;

  MessageCellBuilder(this.state, this.model);

  Widget build(BuildContext context) {
    return Padding(padding: EdgeInsets.all(model.showTimeLabel?5:3), child: Column(
      children: [
        model.showTimeLabel ? Padding(padding: const EdgeInsets.all(3), child: Text(Utilities.formatMessageTime(model.message.serverTime), style: const TextStyle(fontSize: 12, color: Colors.grey),),) : Container(),
        Container(child: getContent(context),),
      ],),
    );
  }

  Widget getContent(BuildContext context);

  void setState(VoidCallback callback) {
    state.refreshAfter(callback);
  }
}