import 'dart:async';

import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';

import '../../utilities.dart';
import '../message_cell.dart';
import '../../ui_model/ui_message.dart';

abstract class MessageCellBuilder {
  UIMessage model;
  BuildContext context;
  late State<MessageCell> state;

  MessageCellBuilder(this.context, this.model);

  void initState(State<MessageCell> s) {
    state = s;
  }

  void dispose() {
    // do nothing
  }

  @protected
  setState(VoidCallback f) {
    state.setState(f);
  }

  Widget build(BuildContext context) {
    return Container(
      color: model.highlighted ? Colors.grey.withOpacity(0.5) : null,
      padding: EdgeInsets.all(model.showTimeLabel ? 5 : 3),
      child: Column(
        children: [
          model.showTimeLabel
              ? Padding(
                  padding: const EdgeInsets.all(3),
                  child: Text(
                    Utilities.formatMessageTime(model.message.serverTime),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                )
              : Container(),
          Container(
            child: buildContent(context),
          ),
        ],
      ),
    );
  }

  Widget buildContent(BuildContext context);

  Widget buildMessageContent(BuildContext context) {
    return buildContent(context);
  }
}
