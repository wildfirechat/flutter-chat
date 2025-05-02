import 'dart:async';

import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';

import '../../utilities.dart';
import '../message_cell.dart';
import '../../ui_model/ui_message.dart';

abstract class MessageCellBuilder {
  UIMessage model;

  MessageCellBuilder(this.model);

  Widget build(BuildContext context) {
    return Padding(
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
            child: getContent(context),
          ),
        ],
      ),
    );
  }

  Widget getContent(BuildContext context);
}
