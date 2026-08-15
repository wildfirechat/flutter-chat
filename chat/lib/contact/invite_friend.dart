import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:chat/pc/widgets/pc_page_header.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/widget/app_bar_actions.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/app_shell.dart';

class InviteFriendPage extends StatefulWidget {
  const InviteFriendPage(this.userId, {super.key});
  final String userId;

  @override
  State<StatefulWidget> createState() => InviteFriendPageState();
}

class InviteFriendPageState extends State<InviteFriendPage> {
  final fieldController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canSend = fieldController.text.trim().isNotEmpty;
    final actions = [
      AppBarTextAction(
        label: l10n.send,
        onPressed: canSend ? () => _sendInvite(context) : null,
      ),
    ];

    return Scaffold(
      appBar: AppShell.isDesktopStyle
          ? PcPageHeader(
              title: l10n.addFriend,
              onBack: () => Navigator.of(context).maybePop(),
              actions: actions,
            )
          : AppBar(
              actions: actions,
              title: Text(l10n.addFriend),
            ),
      backgroundColor:
          AppShell.isDesktopStyle ? context.colors.chatBgDesktop : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(l10n.inviteReasonHint),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: CupertinoTextField(
                placeholder: l10n.inputReason,
                controller: fieldController,
                clearButtonMode: OverlayVisibilityMode.editing,
                autocorrect: false,
                onChanged: (text) {
                  setState(() {});
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  void _sendInvite(BuildContext context) {
    if (fieldController.value.text.isNotEmpty) {
      final l10n = AppLocalizations.of(context)!;
      Imclient.sendFriendRequest(widget.userId, fieldController.value.text, () {
        Fluttertoast.showToast(msg: l10n.requestSent);
        Navigator.pop(context);
      }, (errorCode) {
        Fluttertoast.showToast(msg: l10n.networkErrorWithCode(errorCode));
      });
    }
  }
}
