import 'dart:async';

import 'package:flutter/material.dart';
import 'package:imclient/message/message.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/message/notification/notification_message_content.dart';
import 'package:imclient/message/notification/recall_notificiation_content.dart';

import '../input_bar/message_input_bar_controller.dart';
import '../message_cell.dart';
import 'message_cell_builder.dart';

class NotificationCellBuilder extends MessageCellBuilder {
  String notificaitonMsgDigest = '';

  NotificationCellBuilder(super.context, super.model);

  late StreamSubscription<UserInfoUpdatedEvent> _userInfoUpdatedSubscription;

  @override
  void initState(State<MessageCell> s) {
    super.initState(s);
    // FIXME
    // optimization
    // TODO 更细致的判断，仅包含用户信息的消息，比如加群等消息，需要重新加载 lastMessage
    if (model.message.content is NotificationMessageContent) {
      _userInfoUpdatedSubscription = Imclient.IMEventBus.on<UserInfoUpdatedEvent>().listen((event) {
        _loadLastMessageDigest();
      });
    }
    _loadLastMessageDigest();
  }

  @override
  void dispose() {
    _userInfoUpdatedSubscription?.cancel();
  }

  @override
  Widget buildContent(BuildContext context) {
    final recallContent = model.message.content is RecallNotificationContent
        ? model.message.content as RecallNotificationContent
        : null;
    final bool showReedit = recallContent != null &&
        model.message.direction == MessageDirection.MessageDirection_Send &&
        model.message.fromUser == Imclient.currentUserId &&
        recallContent.originalContentType == MESSAGE_CONTENT_TYPE_TEXT;

    final reeditWidget = showReedit
        ? GestureDetector(
      onTap: () => _onReeditTapped(context, recallContent!),
      child: Text(
        AppLocalizations.of(context)?.reedit ?? '重新编辑',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: Colors.green),
      ),
    )
        : null;

    return Container(
        padding: const EdgeInsets.fromLTRB(60, 0, 60, 0),
        child: notificaitonMsgDigest.isEmpty
            ? Container(
          width: 200,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
        )
            : Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              notificaitonMsgDigest,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
            if (reeditWidget != null) ...[
              const SizedBox(width: 6),
              reeditWidget,
            ],
          ],
        ));
  }

  void _onReeditTapped(BuildContext context, RecallNotificationContent recallContent) {
    String? text;
    if (recallContent.originalContent != null && recallContent.originalContent!.isNotEmpty) {
      text = recallContent.originalContent;
    } else if (recallContent.originalSearchableContent != null &&
        recallContent.originalSearchableContent!.isNotEmpty) {
      text = recallContent.originalSearchableContent;
    }
    if (text == null || text.isEmpty) {
      return;
    }
    try {
      final controller = Provider.of<MessageInputBarController>(context, listen: false);
      controller.setDraft(text);
    } catch (e) {
      debugPrint('reedit: unable to find MessageInputBarController: $e');
    }
  }

  // 未使用 futureBuilder
  Future<void> _loadLastMessageDigest() async {
    try {
      var digest = '';
      digest = await model.message.content.digest(model.message);
      if (state.mounted) {
        setState(() {
          notificaitonMsgDigest = digest;
        });
      }
    } catch (error) {
      debugPrint("Error fetching conversation data: $error");
      if (state.mounted) {
        setState(() {
          // 设置默认值以避免UI错误
          notificaitonMsgDigest = "";
        });
      }
    }
  }
}
