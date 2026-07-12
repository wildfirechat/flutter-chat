import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:chat/constants.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/settings/notification_settings.dart';
import 'package:chat/theme/app_colors.dart';
import '../widget/option_switch_item.dart';

/// 消息通知设置(移动端)。跨端共享语义见 [NotificationSettings],
/// PC 端对应页面是 pc_settings_page.dart 里的 PcNotificationSettingsDetail。
class MessageNotificationSettings extends StatefulWidget {
  const MessageNotificationSettings({super.key});

  @override
  State<MessageNotificationSettings> createState() => _MessageNotificationSettingsState();
}

class _MessageNotificationSettingsState extends State<MessageNotificationSettings> {
  bool _receiveMsgNotification = true;
  bool _receiveVoipNotification = true;
  bool _showNotificationDetail = true;
  bool _noDisturbing = false;
  int _noDisturbStartTime = 0;
  int _noDisturbEndTime = 0;
  bool _syncDraftEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
  }

  void _loadUserSettings() {
    NotificationSettings.getBool(kUserSettingGlobalSilent, invert: true).then((value) {
      if (!mounted) return;
      setState(() => _receiveMsgNotification = value);
    });
    NotificationSettings.getBool(kUserSettingVoipSilent, invert: true).then((value) {
      if (!mounted) return;
      setState(() => _receiveVoipNotification = value);
    });
    NotificationSettings.getBool(kUserSettingHiddenNotificationDetail, invert: true).then((value) {
      if (!mounted) return;
      setState(() => _showNotificationDetail = value);
    });
    NotificationSettings.getBool(kUserSettingDisableSyncDraft, invert: true).then((value) {
      if (!mounted) return;
      setState(() => _syncDraftEnabled = value);
    });
    Imclient.getNoDisturbingTimes((first, second) {
      if (!mounted) return;
      setState(() {
        _noDisturbStartTime = first;
        _noDisturbEndTime = second;
        _noDisturbing = first != second;
      });
    }, (errorCode) {
      if (!mounted) return;
      setState(() {
        _noDisturbing = false;
        _noDisturbStartTime = 0;
        _noDisturbEndTime = 0;
      });
    });
  }

  /// 乐观更新:开关先动,失败后回读并提示。
  void _updateUserSetting(int scope, bool value, {bool revert = false}) {
    final l10n = AppLocalizations.of(context)!;
    NotificationSettings.setBool(scope, value, invert: revert, onSuccess: () {
      Fluttertoast.showToast(msg: l10n.setSuccess);
    }, onFailure: (errorCode) {
      Fluttertoast.showToast(msg: l10n.networkError);
      _loadUserSettings();
    });
  }

  void _toggleNoDisturb(bool enable) {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _noDisturbing = enable;
      _noDisturbStartTime = enable ? NotificationSettings.defaultNoDisturbStart : 0;
      _noDisturbEndTime = enable ? NotificationSettings.defaultNoDisturbEnd : 0;
    });

    onSuccess() => Fluttertoast.showToast(msg: l10n.setSuccess);
    onFailure(int errorCode) {
      Fluttertoast.showToast(msg: l10n.networkError);
      _loadUserSettings();
    }

    if (enable) {
      Imclient.setNoDisturbingTimes(_noDisturbStartTime, _noDisturbEndTime, onSuccess, onFailure);
    } else {
      Imclient.clearNoDisturbingTimes(onSuccess, onFailure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.messageSettings)),
      backgroundColor: colors.primaryBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                color: colors.surface,
                child: Column(
                  children: [
                    OptionSwitchItem(l10n.receiveNewMessageNotification, _receiveMsgNotification, (value) {
                      setState(() => _receiveMsgNotification = value);
                      _updateUserSetting(kUserSettingGlobalSilent, value, revert: true);
                    }),
                    OptionSwitchItem(l10n.receiveCallNotification, _receiveVoipNotification, (value) {
                      setState(() => _receiveVoipNotification = value);
                      _updateUserSetting(kUserSettingVoipSilent, value, revert: true);
                    }),
                    OptionSwitchItem(l10n.showNotificationDetail, _showNotificationDetail, showBottomDivider: false, (value) {
                      setState(() => _showNotificationDetail = value);
                      _updateUserSetting(kUserSettingHiddenNotificationDetail, value, revert: true);
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                color: colors.surface,
                child: OptionSwitchItem(
                  l10n.noDisturb,
                  _noDisturbing,
                  _toggleNoDisturb,
                  desc: _noDisturbing && _noDisturbStartTime != _noDisturbEndTime
                      ? NotificationSettings.formatNoDisturbTime(_noDisturbStartTime, _noDisturbEndTime)
                      : null,
                  showBottomDivider: false,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                color: colors.surface,
                child: OptionSwitchItem(l10n.syncDraft, _syncDraftEnabled, showBottomDivider: false, (value) {
                  setState(() => _syncDraftEnabled = value);
                  _updateUserSetting(kUserSettingDisableSyncDraft, value, revert: true);
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
