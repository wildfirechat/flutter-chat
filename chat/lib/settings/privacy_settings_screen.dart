import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chat/config.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/settings/blacklist_screen.dart';
import 'package:chat/settings/moment_privacy_settings_screen.dart';
import 'package:chat/settings/privacy_find_me_screen.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/widget/option_item.dart';

/// 隐私设置页面
///
/// 从「账号与安全」抽离为独立一级设置项:
/// 找到我的方式、黑名单、消息回执、在线状态、好友验证、朋友圈。
class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  /// 在线状态开关的本地存储 key(语义:向联系人展示我的在线状态)
  static const String _onlineStateKey = 'privacy_show_online_state';

  /// 服务端是否支持消息回执(不支持则不展示该条目)
  bool _receiptEnabled = false;
  bool _receiptOn = false;

  /// 服务端是否开启在线状态能力(未开启则不展示该条目)
  bool _onlineStateEnabled = false;
  bool _showOnlineState = true;

  /// 加我为好友时是否需要验证
  bool _friendVerify = true;

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  /// 进入页面时异步加载服务端能力与各开关初值,加载完成前只展示其余条目。
  Future<void> _loadPrivacySettings() async {
    bool receiptEnabled = false;
    bool receiptOn = false;
    bool onlineStateEnabled = false;
    bool friendVerify = true;
    try {
      receiptEnabled = await Imclient.isReceiptEnabled();
      if (receiptEnabled) {
        receiptOn = await Imclient.isUserEnableReceipt();
      }
      onlineStateEnabled = await Imclient.isEnableUserOnlineState();
      friendVerify = await Imclient.isAddFriendNeedVerify();
    } catch (e) {
      debugPrint('Privacy settings load error: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _receiptEnabled = receiptEnabled;
        _receiptOn = receiptOn;
        _onlineStateEnabled = onlineStateEnabled;
        _showOnlineState = prefs.getBool(_onlineStateKey) ?? true;
        _friendVerify = friendVerify;
      });
    }
  }

  void _onReceiptChanged(bool value) {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _receiptOn = value);
    Imclient.setUserEnableReceipt(value, () {}, (errorCode) {
      if (mounted) {
        setState(() => _receiptOn = !value);
      }
      Fluttertoast.showToast(msg: l10n.operateFail('$errorCode'));
    });
  }

  Future<void> _onOnlineStateChanged(bool value) async {
    setState(() => _showOnlineState = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onlineStateKey, value);
  }

  void _onFriendVerifyChanged(bool value) {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _friendVerify = value);
    Imclient.setAddFriendNeedVerify(value, () {}, (errorCode) {
      if (mounted) {
        setState(() => _friendVerify = !value);
      }
      Fluttertoast.showToast(msg: l10n.operateFail('$errorCode'));
    });
  }

  /// 行间用发丝线分隔(开关行没有自带分隔线,统一在这里补)。
  Widget _buildPrivacyGroup(AppLocalizations l10n) {
    final rows = <Widget>[
      OptionItem(
        l10n.findMeBy,
        showBottomDivider: false,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FindMeByScreen()),
          );
        },
      ),
      OptionItem(
        l10n.blacklist,
        showBottomDivider: false,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BlacklistScreen()),
          );
        },
      ),
      // 消息回执:仅当服务端支持时展示
      if (_receiptEnabled)
        SwitchListTile(
          title: Text(l10n.msgReceipt),
          value: _receiptOn,
          onChanged: _onReceiptChanged,
        ),
      // 在线状态:仅当服务端开启在线状态能力时展示
      if (_onlineStateEnabled)
        SwitchListTile(
          title: Text(l10n.onlineStatus),
          value: _showOnlineState,
          onChanged: _onOnlineStateChanged,
        ),
      SwitchListTile(
        title: Text(l10n.friendVerify),
        value: _friendVerify,
        onChanged: _onFriendVerifyChanged,
      ),
      // 朋友圈设置,受 Config.ENABLE_MOMENTS 开关控制
      if (Config.ENABLE_MOMENTS)
        OptionItem(
          l10n.momentWindowTitle,
          showBottomDivider: false,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const MomentPrivacySettingsScreen()),
            );
          },
        ),
    ];
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      children.add(rows[i]);
      if (i < rows.length - 1) {
        children.add(const Divider(indent: 15, endIndent: 12, height: 1));
      }
    }
    return Container(
      color: context.colors.surface,
      child: Column(children: children),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.privacy),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 10),
              _buildPrivacyGroup(l10n),
            ],
          ),
        ),
      ),
    );
  }
}
