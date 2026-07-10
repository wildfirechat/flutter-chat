
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:chat/constants.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/settings/notification_settings.dart';


class MessageNotificationSettings extends StatelessWidget {
  static const List<String> _settingKeys = [
    'new_msg_notification',
    'voip_notification',
    'new_msg_detail',
    'no_disturb',
    'sync_draft',
  ];

  MessageNotificationSettings({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.messageSettings),),
      body: SafeArea(
        child: ListView.builder(
          itemCount: _settingKeys.length,
          itemBuilder: (BuildContext context, int index) {
            return _buildRow(context, index);
          },
        ),
      ),
    );
  }

  String _titleFor(BuildContext context, String key) {
    final l10n = AppLocalizations.of(context)!;
    switch (key) {
      case 'new_msg_notification':
        return l10n.receiveNewMessageNotification;
      case 'voip_notification':
        return l10n.receiveCallNotification;
      case 'new_msg_detail':
        return l10n.showNotificationDetail;
      case 'no_disturb':
        return l10n.noDisturb;
      case 'sync_draft':
        return l10n.syncDraft;
      default:
        return key;
    }
  }

  Widget _buildRow(BuildContext context, int index) {
    String key = _settingKeys[index];
    return MessageNotificationSettingItem(_titleFor(context, key), key);
  }
}

class MessageNotificationSettingItem extends StatefulWidget {
  final String settingName;
  final String settingKey;

  const MessageNotificationSettingItem(this.settingName, this.settingKey, {Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => MessageNotificationSettingItemState();
}

class MessageNotificationSettingItemState extends State<MessageNotificationSettingItem> {
  bool isEnabled = false;
  int scope = 0;
  bool revertValue = false;
  int startTime = 0;
  int endTime = 0;


  @override
  void initState() {
    super.initState();
    switch(widget.settingKey) {
      case 'new_msg_notification':
        scope = kUserSettingGlobalSilent;
        revertValue = true;
        break;
      case 'voip_notification':
        scope = kUserSettingVoipSilent;
        revertValue = true;
        break;
      case 'new_msg_detail':
        scope = kUserSettingHiddenNotificationDetail;
        revertValue = true;
        break;
      case 'no_disturb':
        scope = kUserSettingNoDisturbing;
        break;
      case 'sync_draft':
        scope = kUserSettingDisableSyncDraft;
        revertValue = true;
        break;
      default:
        return;
    }

    loadData();
  }

  void loadData() {
    if(widget.settingKey == 'no_disturb') {
      Imclient.getNoDisturbingTimes((first, second) {
        setState(() {
          startTime = first;
          endTime = second;
          isEnabled = first != second;
        });
      }, (errorCode) {
        setState(() {
          isEnabled = false;
          startTime = 0;
          endTime = 0;
        });
      });
    } else {
      NotificationSettings.getBool(scope, invert: revertValue).then((value) {
        setState(() {
          isEnabled = value;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Padding(padding: EdgeInsets.all(8)),
            Text(widget.settingName),
            Expanded(child: Container()),
            (widget.settingKey == 'no_disturb' && startTime != endTime) ? Text(NotificationSettings.formatNoDisturbTime(startTime, endTime)):Container(),
            Transform.scale(
              scale: 0.6,
              child: Switch(value: isEnabled, onChanged: (enable) {
              final l10n = AppLocalizations.of(context)!;
              setState(() {
                isEnabled = enable;
              });

              if(widget.settingKey == 'no_disturb') {
               if(isEnabled) {
                 startTime = NotificationSettings.defaultNoDisturbStart;
                 endTime = NotificationSettings.defaultNoDisturbEnd;
                 Imclient.setNoDisturbingTimes(startTime, endTime, () {
                   Fluttertoast.showToast(msg: l10n.setSuccess);
                 }, (errorCode) {
                   Fluttertoast.showToast(msg: l10n.networkError);
                   loadData();
                 });
               } else {
                 startTime = 0;
                 endTime = 0;
                 Imclient.clearNoDisturbingTimes(() {
                   Fluttertoast.showToast(msg: l10n.setSuccess);
                 }, (errorCode) {
                   Fluttertoast.showToast(msg: l10n.networkError);
                   loadData();
                 });
               }
              } else {
                NotificationSettings.setBool(scope, enable, invert: revertValue, onSuccess: () {
                  Fluttertoast.showToast(msg: l10n.setSuccess);
                }, onFailure: (errorCode) {
                  Fluttertoast.showToast(msg: l10n.networkError);
                  loadData();
                });
               }
             })),
           ],
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 0.0),
          height: 1,
          color: const Color(0xffebebeb),
        ),
      ],
    );
  }
}