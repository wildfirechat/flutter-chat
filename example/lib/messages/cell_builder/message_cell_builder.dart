import 'dart:async';

import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';

import '../../utilities.dart';
import '../message_cell.dart';
import '../message_model.dart';

abstract class MessageCellBuilder {
  MessageModel model;
  MessageState state;

  final EventBus _eventBus = Imclient.IMEventBus;
  late StreamSubscription<UserInfoUpdatedEvent> _userInfoUpdatedSubscription;

  MessageCellBuilder(this.state, this.model) {
    _userInfoUpdatedSubscription = _eventBus.on<UserInfoUpdatedEvent>().listen((event) {
        for(var value in event.userInfos) {
            if(value.userId == model.message.fromUser) {
              setState(() {

              });
              break;
            }
        }
    });
  }

  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(model.showTimeLabel?5:3),
      child: Column(
        children: [
          model.showTimeLabel ? Padding(padding: const EdgeInsets.all(3), child: Text(Utilities.formatMessageTime(model.message.serverTime), style: const TextStyle(fontSize: 12, color: Colors.grey),),) : Container(),
          Container(child: getContent(context),),
        ],
      ),
    );
  }

  void dispose() {
    _userInfoUpdatedSubscription.cancel();
  }

  Widget getContent(BuildContext context);

  void setState(VoidCallback callback) {
    state.refreshAfter(callback);
  }
}