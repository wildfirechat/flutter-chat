import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/constants.dart';
import 'package:chat/pc/pc_theme.dart';
import 'package:chat/pc/widgets/hover_builder.dart';
import 'package:chat/pc/widgets/pc_page_header.dart';
import 'package:chat/settings/account_safety_screen.dart';
import 'package:chat/settings/blacklist_screen.dart';
import 'package:chat/backup/backup_and_restore_screen.dart';
import 'package:chat/viewmodel/user_view_model.dart';
import 'package:chat/viewmodel/locale_view_model.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chat/app_navigator.dart';

// ==========================================
// 1. Middle Column: PcSettingsMenu
// ==========================================
class PcSettingsMenu extends StatefulWidget {
  const PcSettingsMenu({super.key});

  @override
  State<PcSettingsMenu> createState() => _PcSettingsMenuState();
}

class _PcSettingsMenuState extends State<PcSettingsMenu> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final menuItems = [
      _MenuData("通用", Icons.tune_rounded, const PcGeneralSettingsDetail()),
      _MenuData(l10n.messageNotification, Icons.notifications_none_rounded, const PcNotificationSettingsDetail()),
      _MenuData("外观与主题", Icons.palette_outlined, const PcAppearanceSettingsDetail()),
      _MenuData(l10n.accountSafety, Icons.security_rounded, const PcSecuritySettingsDetail()),
      _MenuData("关于野火", Icons.info_outline_rounded, const PcAboutSettingsDetail()),
    ];

    return Container(
      color: PcTheme.middleBg,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: menuItems.length,
        itemBuilder: (context, index) {
          final item = menuItems[index];
          final isSelected = _selectedIndex == index;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: HoverBuilder(
              cursor: SystemMouseCursors.click,
              builder: (context, hovered) {
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedIndex = index;
                    });
                    openPage(context, item.page);
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? PcTheme.cellSelected
                          : hovered
                              ? PcTheme.cellHover
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          size: 18,
                          color: isSelected ? PcTheme.accent : PcTheme.sidebarIcon,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                              color: PcTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _MenuData {
  final String title;
  final IconData icon;
  final Widget page;
  _MenuData(this.title, this.icon, this.page);
}

// ==========================================
// 2. Right Pane: Settings Category Detail Screens
// ==========================================

// --- 通用 (General) ---
class PcGeneralSettingsDetail extends StatefulWidget {
  const PcGeneralSettingsDetail({super.key});

  @override
  State<PcGeneralSettingsDetail> createState() => _PcGeneralSettingsDetailState();
}

class _PcGeneralSettingsDetailState extends State<PcGeneralSettingsDetail> {
  bool _syncDraftEnabled = true;
  bool _closeToExit = false;
  bool _enableMinimize = true;

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
    _loadLocalPreferences();
  }

  void _loadUserSettings() {
    Imclient.getUserSetting(kUserSettingDisableSyncDraft, "").then((value) {
      if (mounted) {
        setState(() {
          _syncDraftEnabled = (value.isEmpty || value == '0');
        });
      }
    });
  }

  Future<void> _loadLocalPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _closeToExit = prefs.getBool('pc_close_to_exit') ?? false;
        _enableMinimize = prefs.getBool('pc_enable_minimize') ?? true;
      });
    }
  }

  void _saveLocalPreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    }
  }

  void _updateUserSetting(int scope, bool value, {bool revert = false}) {
    bool sendVal = value;
    if (revert) {
      sendVal = !value;
    }
    Imclient.setUserSetting(scope, "", sendVal ? "1" : "0", () {
      Fluttertoast.showToast(msg: "设置成功");
    }, (errorCode) {
      Fluttertoast.showToast(msg: "网络错误");
      _loadUserSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PcTheme.chatBg,
      appBar: const PcPageHeader(title: "通用"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SettingsSectionTitle("聊天"),
                _SettingsCard(children: [
                  _SettingsSwitchRow(
                    title: "同步草稿",
                    subtitle: "支持聊天草稿在移动端和电脑端之间进行双向同步",
                    value: _syncDraftEnabled,
                    onChanged: (val) {
                      setState(() => _syncDraftEnabled = val);
                      _updateUserSetting(kUserSettingDisableSyncDraft, val, revert: true);
                    },
                  ),
                ]),
                const SizedBox(height: 20),
                const _SettingsSectionTitle("启动与窗口"),
                _SettingsCard(children: [
                  _SettingsSwitchRow(
                    title: "点击窗口关闭按钮时退出整个程序",
                    subtitle: "关闭则默认最小化到系统托盘",
                    value: _closeToExit,
                    onChanged: (val) {
                      setState(() => _closeToExit = val);
                      _saveLocalPreference('pc_close_to_exit', val);
                      Fluttertoast.showToast(msg: "设置成功");
                    },
                  ),
                  const Divider(height: 0.5),
                  _SettingsSwitchRow(
                    title: "开启后主窗体支持最小化到任务栏",
                    subtitle: "开启后支持最小化，关闭则直接保留在前台",
                    value: _enableMinimize,
                    onChanged: (val) {
                      setState(() => _enableMinimize = val);
                      _saveLocalPreference('pc_enable_minimize', val);
                      Fluttertoast.showToast(msg: "设置成功");
                    },
                  ),
                ]),
                const SizedBox(height: 20),
                const _SettingsSectionTitle("服务条款"),
                _SettingsCard(children: [
                  _SettingsClickableRow(
                    title: "用户协议",
                    subtitle: "阅读野火 IM 软件许可及服务协议",
                    onTap: () {
                      Fluttertoast.showToast(msg: "方法未实现");
                    },
                  ),
                  const Divider(height: 0.5),
                  _SettingsClickableRow(
                    title: "隐私政策",
                    subtitle: "阅读野火 IM 隐私保护指引",
                    onTap: () {
                      Fluttertoast.showToast(msg: "方法未实现");
                    },
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- 通知 (Notification) ---
class PcNotificationSettingsDetail extends StatefulWidget {
  const PcNotificationSettingsDetail({super.key});

  @override
  State<PcNotificationSettingsDetail> createState() => _PcNotificationSettingsDetailState();
}

class _PcNotificationSettingsDetailState extends State<PcNotificationSettingsDetail> {
  bool _globalSilent = false;
  bool _voipSilent = false;
  bool _hiddenNotificationDetail = false;
  bool _noDisturbing = false;
  int _noDisturbStartTime = 0;
  int _noDisturbEndTime = 0;

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
  }

  void _loadUserSettings() {
    Imclient.getUserSetting(kUserSettingGlobalSilent, "").then((value) {
      if (mounted) {
        setState(() {
          _globalSilent = !(value.isEmpty || value == '0');
        });
      }
    });

    Imclient.getUserSetting(kUserSettingVoipSilent, "").then((value) {
      if (mounted) {
        setState(() {
          _voipSilent = !(value.isEmpty || value == '0');
        });
      }
    });

    Imclient.getUserSetting(kUserSettingHiddenNotificationDetail, "").then((value) {
      if (mounted) {
        setState(() {
          _hiddenNotificationDetail = !(value.isEmpty || value == '0');
        });
      }
    });

    Imclient.getNoDisturbingTimes((first, second) {
      if (mounted) {
        setState(() {
          _noDisturbStartTime = first;
          _noDisturbEndTime = second;
          _noDisturbing = first != second;
        });
      }
    }, (errorCode) {
      if (mounted) {
        setState(() {
          _noDisturbing = false;
        });
      }
    });
  }

  void _updateUserSetting(int scope, bool value, {bool revert = false}) {
    bool sendVal = value;
    if (revert) {
      sendVal = !value;
    }
    Imclient.setUserSetting(scope, "", sendVal ? "1" : "0", () {
      Fluttertoast.showToast(msg: "设置成功");
    }, (errorCode) {
      Fluttertoast.showToast(msg: "网络错误");
      _loadUserSettings();
    });
  }

  void _toggleNoDisturb(bool enabled) {
    if (enabled) {
      _noDisturbStartTime = 21 * 60 - 8 * 60;
      _noDisturbEndTime = 7 * 60 - 8 * 60;
      Imclient.setNoDisturbingTimes(_noDisturbStartTime, _noDisturbEndTime, () {
        Fluttertoast.showToast(msg: "设置成功");
        setState(() {
          _noDisturbing = true;
        });
      }, (errorCode) {
        Fluttertoast.showToast(msg: "网络错误");
        _loadUserSettings();
      });
    } else {
      Imclient.clearNoDisturbingTimes(() {
        Fluttertoast.showToast(msg: "设置成功");
        setState(() {
          _noDisturbing = false;
          _noDisturbStartTime = 0;
          _noDisturbEndTime = 0;
        });
      }, (errorCode) {
        Fluttertoast.showToast(msg: "网络错误");
        _loadUserSettings();
      });
    }
  }

  String _formatNoDisturbTime(int startTime, int endTime) {
    int localStart = startTime + 8 * 60;
    int localEnd = endTime + 8 * 60;

    int startHour = localStart ~/ 60;
    int startMin = localStart % 60;
    int endHour = localEnd ~/ 60;
    int endMin = localEnd % 60;

    return '${startHour.toString().padLeft(2, '0')}:${startMin.toString().padLeft(2, '0')} - ${endHour.toString().padLeft(2, '0')}:${endMin.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PcTheme.chatBg,
      appBar: const PcPageHeader(title: "通知"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SettingsSectionTitle("消息提醒"),
                _SettingsCard(children: [
                  _SettingsSwitchRow(
                    title: "接收新消息通知",
                    subtitle: "开启或关闭新消息到达时的系统声音和横幅通知",
                    value: _globalSilent,
                    onChanged: (val) {
                      setState(() => _globalSilent = val);
                      _updateUserSetting(kUserSettingGlobalSilent, val, revert: true);
                    },
                  ),
                  const Divider(height: 0.5),
                  _SettingsSwitchRow(
                    title: "接收语音或视频来电通知",
                    subtitle: "开启或关闭新呼叫到达时的来电窗口提醒",
                    value: _voipSilent,
                    onChanged: (val) {
                      setState(() => _voipSilent = val);
                      _updateUserSetting(kUserSettingVoipSilent, val, revert: true);
                    },
                  ),
                  const Divider(height: 0.5),
                  _SettingsSwitchRow(
                    title: "通知显示消息详情",
                    subtitle: "开启后通知显示消息的发件人和预览内容，关闭后只显示“收到一条新消息”",
                    value: _hiddenNotificationDetail,
                    onChanged: (val) {
                      setState(() => _hiddenNotificationDetail = val);
                      _updateUserSetting(kUserSettingHiddenNotificationDetail, val, revert: true);
                    },
                  ),
                  const Divider(height: 0.5),
                  _SettingsSwitchRow(
                    title: "免打扰",
                    subtitle: _noDisturbing && _noDisturbStartTime != _noDisturbEndTime
                        ? "当前免打扰时间段: ${_formatNoDisturbTime(_noDisturbStartTime, _noDisturbEndTime)}"
                        : "开启后在特定时间段内接收消息不发出声音或振动提醒",
                    value: _noDisturbing,
                    onChanged: (val) {
                      _toggleNoDisturb(val);
                    },
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- 外观与主题 (Appearance) ---
class PcAppearanceSettingsDetail extends StatefulWidget {
  const PcAppearanceSettingsDetail({super.key});

  @override
  State<PcAppearanceSettingsDetail> createState() => _PcAppearanceSettingsDetailState();
}

class _PcAppearanceSettingsDetailState extends State<PcAppearanceSettingsDetail> {
  String _themeMode = 'follow_system';
  double _fontScale = 1.0;

  @override
  void initState() {
    super.initState();
    _loadLocalPreferences();
  }

  Future<void> _loadLocalPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _themeMode = prefs.getString('pc_theme_mode') ?? 'follow_system';
        _fontScale = prefs.getDouble('pc_font_scale') ?? 1.0;
      });
    }
  }

  void _saveLocalPreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localeViewModel = Provider.of<LocaleViewModel>(context);

    String currentLangText = "跟随系统";
    if (localeViewModel.localeMode == 'zh') {
      currentLangText = "简体中文";
    } else if (localeViewModel.localeMode == 'en') {
      currentLangText = "English";
    }

    String currentThemeText = "跟随系统";
    if (_themeMode == 'light') {
      currentThemeText = "浅色";
    } else if (_themeMode == 'dark') {
      currentThemeText = "暗黑";
    }

    return Scaffold(
      backgroundColor: PcTheme.chatBg,
      appBar: const PcPageHeader(title: "外观与主题"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SettingsSectionTitle("界面外观"),
                _SettingsCard(children: [
                  _SettingsSelectorRow(
                    title: "界面语言",
                    subtitle: "更改客户端的界面语言，需重新启动应用以生效",
                    valueText: currentLangText,
                    onTap: (rowContext) {
                      _showLanguageMenu(rowContext);
                    },
                  ),
                  const Divider(height: 0.5),
                  _SettingsSelectorRow(
                    title: "外观主题",
                    subtitle: "切换深色、浅色主题风格，或设置跟随系统外观",
                    valueText: currentThemeText,
                    onTap: (rowContext) {
                      _showThemeMenu(rowContext);
                    },
                  ),
                  const Divider(height: 0.5),
                  _SettingsSliderRow(
                    title: "字体大小",
                    subtitle: "调整界面的文本显示大小",
                    value: _fontScale,
                    onChanged: (val) {
                      setState(() => _fontScale = val);
                      _saveLocalPreference('pc_font_scale', val);
                    },
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLanguageMenu(BuildContext selectorContext) {
    final localeViewModel = Provider.of<LocaleViewModel>(context, listen: false);
    final RenderBox button = selectorContext.findRenderObject() as RenderBox;
    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      items: const [
        PopupMenuItem(value: 'follow_system', child: Text("跟随系统")),
        PopupMenuItem(value: 'zh', child: Text("简体中文")),
        PopupMenuItem(value: 'en', child: Text("English")),
      ],
    ).then((value) {
      if (value != null) {
        localeViewModel.setLocaleMode(value);
        Fluttertoast.showToast(msg: "设置成功，重新启动应用以生效");
      }
    });
  }

  void _showThemeMenu(BuildContext selectorContext) {
    final RenderBox button = selectorContext.findRenderObject() as RenderBox;
    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      items: const [
        PopupMenuItem(value: 'follow_system', child: Text("跟随系统")),
        PopupMenuItem(value: 'light', child: Text("浅色")),
        PopupMenuItem(value: 'dark', child: Text("暗黑")),
      ],
    ).then((value) {
      if (value != null) {
        setState(() {
          _themeMode = value;
        });
        _saveLocalPreference('pc_theme_mode', value);
        Fluttertoast.showToast(msg: "外观设置成功");
      }
    });
  }
}

// --- 账号与安全 (Security) ---
class PcSecuritySettingsDetail extends StatefulWidget {
  const PcSecuritySettingsDetail({super.key});

  @override
  State<PcSecuritySettingsDetail> createState() => _PcSecuritySettingsDetailState();
}

class _PcSecuritySettingsDetailState extends State<PcSecuritySettingsDetail> {
  void _handleLogout() {
    Fluttertoast.showToast(msg: AppLocalizations.of(context)!.logoutConfirm);
    navigateToLogin(Navigator.of(context, rootNavigator: true));
    Imclient.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<UserViewModel, UserInfo?>(
      selector: (context, viewModel) => viewModel.getUserInfo(Imclient.currentUserId),
      builder: (context, userInfo, _) {
        if (userInfo == null) {
          return const Scaffold(
            backgroundColor: PcTheme.chatBg,
            appBar: PcPageHeader(title: "账号与安全"),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          backgroundColor: PcTheme.chatBg,
          appBar: const PcPageHeader(title: "账号与安全"),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SettingsSectionTitle("当前登录账号"),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: PcTheme.hairline, width: 0.5),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Portrait(
                            userInfo.portrait ?? Config.defaultUserPortrait,
                            Config.defaultUserPortrait,
                            width: 54,
                            height: 54,
                            borderRadius: 6,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userInfo.displayName ?? userInfo.name,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: PcTheme.textPrimary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "账号: ${userInfo.name}",
                                  style: const TextStyle(fontSize: 12, color: PcTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            onPressed: _handleLogout,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                            child: const Text("退出登录", style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _SettingsSectionTitle("安全与数据"),
                    _SettingsCard(children: [
                      _SettingsClickableRow(
                        title: "修改密码",
                        subtitle: "支持使用旧密码验证修改登录密码",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
                          );
                        },
                      ),
                      const Divider(height: 0.5),
                      _SettingsClickableRow(
                        title: "黑名单",
                        subtitle: "查看和管理已屏蔽的联系人列表",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const BlacklistScreen()),
                          );
                        },
                      ),
                      const Divider(height: 0.5),
                      _SettingsClickableRow(
                        title: "备份与恢复",
                        subtitle: "备份聊天记录到电脑，或从电脑恢复备份到手机客户端",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const BackupAndRestoreScreen()),
                          );
                        },
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// --- 关于 (About) ---
class PcAboutSettingsDetail extends StatelessWidget {
  const PcAboutSettingsDetail({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PcTheme.chatBg,
      appBar: const PcPageHeader(title: "关于野火"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                // Logo
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset("assets/images/app_icon.png"),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "野火 IM",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: PcTheme.textPrimary),
                ),
                const SizedBox(height: 8),
                const Text(
                  "版本 v1.0.0",
                  style: TextStyle(fontSize: 12, color: PcTheme.textSecondary),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: PcTheme.hairline, width: 0.5),
                  ),
                  child: const Text(
                    "野火IM 是安全可靠、开发对接便捷、部署维护简单，方便二次开发和对接现有系统的私有化即时通讯平台。",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: PcTheme.textPrimary, height: 1.5),
                  ),
                ),
                const SizedBox(height: 40),
                // Links
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _SettingsTextLink(label: "官方网站", url: "https://wildfirechat.cn"),
                    SizedBox(width: 12),
                    Text("|", style: TextStyle(color: PcTheme.textTertiary)),
                    SizedBox(width: 12),
                    _SettingsTextLink(label: "GitHub 仓库", url: "https://github.com/wildfirechat"),
                    SizedBox(width: 12),
                    Text("|", style: TextStyle(color: PcTheme.textTertiary)),
                    SizedBox(width: 12),
                    _SettingsTextLink(label: "问题反馈", url: "https://github.com/wildfirechat/issues"),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  "微信联系：wildfirechat 或 wfchat",
                  style: TextStyle(fontSize: 12, color: PcTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 3. Shared Reusable Setting Design Components
// ==========================================

class _SettingsSectionTitle extends StatelessWidget {
  final String title;
  const _SettingsSectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: PcTheme.textSecondary),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PcTheme.hairline, width: 0.5),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: PcTheme.textPrimary)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: PcTheme.textSecondary)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: PcTheme.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SettingsClickableRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsClickableRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) {
        return InkWell(
          onTap: onTap,
          child: Container(
            color: hovered ? Colors.black.withValues(alpha: 0.02) : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: PcTheme.textPrimary)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: PcTheme.textSecondary)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: PcTheme.textTertiary),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SettingsSelectorRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String valueText;
  final void Function(BuildContext) onTap;

  const _SettingsSelectorRow({
    required this.title,
    required this.subtitle,
    required this.valueText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) {
        return Builder(
          builder: (rowContext) => InkWell(
            onTap: () => onTap(rowContext),
            child: Container(
              color: hovered ? Colors.black.withValues(alpha: 0.02) : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: PcTheme.textPrimary)),
                        const SizedBox(height: 4),
                        Text(subtitle, style: const TextStyle(fontSize: 12, color: PcTheme.textSecondary)),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Text(valueText, style: const TextStyle(fontSize: 13, color: PcTheme.textSecondary)),
                      const SizedBox(width: 8),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: PcTheme.textTertiary),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SettingsSliderRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final double value;
  final ValueChanged<double> onChanged;

  const _SettingsSliderRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: PcTheme.textPrimary)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: PcTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text("小", style: TextStyle(fontSize: 11, color: PcTheme.textSecondary)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: PcTheme.accent,
                    inactiveTrackColor: Colors.black12,
                    thumbColor: Colors.white,
                    overlayColor: PcTheme.accent.withValues(alpha: 0.1),
                    valueIndicatorColor: PcTheme.accent,
                  ),
                  child: Slider(
                    value: value,
                    min: 0.85,
                    max: 1.45,
                    divisions: 4,
                    onChanged: onChanged,
                  ),
                ),
              ),
              const Text("大", style: TextStyle(fontSize: 14, color: PcTheme.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsTextLink extends StatelessWidget {
  final String label;
  final String url;

  const _SettingsTextLink({
    required this.label,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) {
        return GestureDetector(
          onTap: () {
            Fluttertoast.showToast(msg: "打开链接: $url");
          },
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: hovered ? PcTheme.accentPressed : PcTheme.accent,
              decoration: TextDecoration.underline,
              decorationColor: hovered ? PcTheme.accentPressed : PcTheme.accent,
            ),
          ),
        );
      },
    );
  }
}
