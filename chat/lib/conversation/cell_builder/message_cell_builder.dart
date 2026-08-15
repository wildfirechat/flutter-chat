import 'package:flutter/material.dart';

import '../../utilities.dart';
import '../message_cell.dart';
import '../../ui_model/ui_message.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/app_shell.dart';

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
    // ignore: invalid_use_of_protected_member
    state.setState(f);
  }

  Widget build(BuildContext context) {
    final basePadding = model.showTimeLabel ? 5.0 : 3.0;
    final verticalExtra = AppShell.isDesktopStyle ? 6.0 : 0.0;
    return Container(
      padding: EdgeInsets.fromLTRB(
        basePadding,
        basePadding + verticalExtra,
        basePadding,
        basePadding + verticalExtra,
      ),
      child: Column(
        children: [
          model.showTimeLabel
              ? Padding(
                  padding: const EdgeInsets.all(3),
                  child: Text(
                    Utilities.formatMessageTime(
                        context, model.message.serverTime),
                    style: AppText.xs
                        .copyWith(color: context.colors.textSecondary),
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
