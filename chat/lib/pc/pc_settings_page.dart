import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';
import 'package:provider/provider.dart';
import 'package:chat/constants.dart';
import 'package:chat/pc/widgets/hover_builder.dart';
import 'package:chat/pc/launch_at_login_service.dart';
import 'package:chat/pc/widgets/pc_card.dart';
import 'package:chat/pc/widgets/pc_page_header.dart';
import 'package:chat/pc/widgets/pc_pane_content.dart';
import 'package:chat/pc/widgets/pc_settings_row.dart';
import 'package:chat/settings/account_safety_screen.dart';
import 'package:chat/settings/blacklist_screen.dart';
import 'package:chat/settings/destroy_account_screen.dart';
import 'package:chat/settings/moment_privacy_settings_screen.dart';
import 'package:chat/settings/notification_settings.dart';
import 'package:chat/settings/privacy_find_me_screen.dart';
import 'package:imclient/model/conversation.dart';
import 'package:chat/backup/pc_backup_restore_page.dart';
import 'package:chat/viewmodel/user_view_model.dart';
import 'package:chat/viewmodel/locale_view_model.dart';
import 'package:chat/viewmodel/font_size_view_model.dart';
import 'package:chat/viewmodel/theme_view_model.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chat/app_navigator.dart';
import 'package:chat/utilities.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/utils/layout_scale.dart';
import 'package:chat/theme/app_typography.dart';

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
      _MenuData(
          l10n.general, Icons.tune_rounded, const PcGeneralSettingsDetail()),
      _MenuData(l10n.messageNotification, Icons.notifications_none_rounded,
          const PcNotificationSettingsDetail()),
      _MenuData(l10n.appearanceAndTheme, Icons.palette_outlined,
          const PcAppearanceSettingsDetail()),
      _MenuData(l10n.accountSafety, Icons.security_rounded,
          const PcSecuritySettingsDetail()),
      _MenuData(l10n.privacy, Icons.privacy_tip_outlined,
          const PcPrivacySettingsDetail()),
      _MenuData(l10n.about, Icons.info_outline_rounded,
          const PcAboutSettingsDetail()),
    ];

    return Container(
      color: context.colors.middleBg,
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
                    height: LayoutScale.watchScale(context, 40,
                        cap: LayoutScale.rowCap),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? context.colors.cellSelected
                          : hovered
                              ? context.colors.cellHover
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          size: LayoutScale.watchScale(context, 18,
                              cap: LayoutScale.iconCap),
                          color: isSelected
                              ? context.colors.accent
                              : context.colors.iconSecondary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.title,
                            style: AppText.sm.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                                color: context.colors.textPrimary),
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
  State<PcGeneralSettingsDetail> createState() =>
      _PcGeneralSettingsDetailState();
}

class _PcGeneralSettingsDetailState extends State<PcGeneralSettingsDetail> {
  bool _syncDraftEnabled = true;
  bool _closeToExit = false;
  bool _enableMinimize = true;
  bool _launchAtLogin = false;

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
    _loadLocalPreferences();
  }

  void _loadUserSettings() {
    NotificationSettings.getBool(kUserSettingDisableSyncDraft, invert: true)
        .then((value) {
      if (mounted) {
        setState(() {
          _syncDraftEnabled = value;
        });
      }
    });
  }

  Future<void> _loadLocalPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final launchAtLogin = await LaunchAtLoginService.isEnabled();
    if (mounted) {
      setState(() {
        _closeToExit = prefs.getBool('pc_close_to_exit') ?? false;
        _enableMinimize = prefs.getBool('pc_enable_minimize') ?? true;
        _launchAtLogin = launchAtLogin;
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
    final l10n = AppLocalizations.of(context)!;
    NotificationSettings.setBool(scope, value, invert: revert, onSuccess: () {
      Fluttertoast.showToast(msg: l10n.setSuccess);
    }, onFailure: (errorCode) {
      Fluttertoast.showToast(msg: l10n.networkError);
      _loadUserSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.colors.chatBgDesktop,
      appBar: PcPageHeader(title: l10n.general),
      body: SingleChildScrollView(
        padding: PcPaneContent.defaultPadding,
        child: PcPaneContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PcSettingsSectionTitle(l10n.chat),
              PcCard(children: [
                PcSettingsSwitchRow(
                  title: l10n.syncDraft,
                  subtitle: l10n.syncDraftDesc,
                  value: _syncDraftEnabled,
                  onChanged: (val) {
                    setState(() => _syncDraftEnabled = val);
                    _updateUserSetting(kUserSettingDisableSyncDraft, val,
                        revert: true);
                  },
                ),
              ]),
              const SizedBox(height: 20),
              PcSettingsSectionTitle(l10n.startupAndWindow),
              PcCard(children: [
                PcSettingsSwitchRow(
                  title: l10n.closeToExitTitle,
                  subtitle: l10n.closeToExitDesc,
                  value: _closeToExit,
                  onChanged: (val) {
                    setState(() => _closeToExit = val);
                    _saveLocalPreference('pc_close_to_exit', val);
                    Fluttertoast.showToast(msg: l10n.setSuccess);
                  },
                ),
                const Divider(),
                PcSettingsSwitchRow(
                  title: l10n.minimizeToTaskbarTitle,
                  subtitle: l10n.minimizeToTaskbarDesc,
                  value: _enableMinimize,
                  onChanged: (val) {
                    setState(() => _enableMinimize = val);
                    _saveLocalPreference('pc_enable_minimize', val);
                    Fluttertoast.showToast(msg: l10n.setSuccess);
                  },
                ),
                const Divider(),
                PcSettingsSwitchRow(
                  title: l10n.launchAtLoginTitle,
                  subtitle: l10n.launchAtLoginDesc,
                  value: _launchAtLogin,
                  onChanged: (val) async {
                    final ok = await LaunchAtLoginService.setEnabled(val);
                    if (ok) {
                      setState(() => _launchAtLogin = val);
                    }
                    Fluttertoast.showToast(
                        msg: ok ? l10n.setSuccess : l10n.setFailed);
                  },
                ),
              ]),
              const SizedBox(height: 20),
              PcSettingsSectionTitle(l10n.termsOfService),
              PcCard(children: [
                PcSettingsClickableRow(
                  title: l10n.userAgreement,
                  subtitle: l10n.userAgreementDesc,
                  onTap: () {
                    Utilities.openLink(context, Config.USER_AGREEMENT_URL);
                  },
                ),
                const Divider(),
                PcSettingsClickableRow(
                  title: l10n.privacyPolicy,
                  subtitle: l10n.privacyPolicyDesc,
                  onTap: () {
                    Utilities.openLink(context, Config.PRIVACY_AGREEMENT_URL);
                  },
                ),
              ]),
            ],
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
  State<PcNotificationSettingsDetail> createState() =>
      _PcNotificationSettingsDetailState();
}

class _PcNotificationSettingsDetailState
    extends State<PcNotificationSettingsDetail> {
  // 字段均为 UI 语义（"接收/显示"为 true），与服务端"静默/隐藏"存储语义的
  // 取反由 NotificationSettings 统一处理。
  bool _receiveMsgNotification = true;
  bool _receiveVoipNotification = true;
  bool _showNotificationDetail = true;
  bool _noDisturbing = false;
  int _noDisturbStartTime = 0;
  int _noDisturbEndTime = 0;

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
  }

  void _loadUserSettings() {
    NotificationSettings.getBool(kUserSettingGlobalSilent, invert: true)
        .then((value) {
      if (mounted) {
        setState(() {
          _receiveMsgNotification = value;
        });
      }
    });

    NotificationSettings.getBool(kUserSettingVoipSilent, invert: true)
        .then((value) {
      if (mounted) {
        setState(() {
          _receiveVoipNotification = value;
        });
      }
    });

    NotificationSettings.getBool(kUserSettingHiddenNotificationDetail,
            invert: true)
        .then((value) {
      if (mounted) {
        setState(() {
          _showNotificationDetail = value;
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
    final l10n = AppLocalizations.of(context)!;
    NotificationSettings.setBool(scope, value, invert: revert, onSuccess: () {
      Fluttertoast.showToast(msg: l10n.setSuccess);
    }, onFailure: (errorCode) {
      Fluttertoast.showToast(msg: l10n.networkError);
      _loadUserSettings();
    });
  }

  void _toggleNoDisturb(bool enabled) {
    final l10n = AppLocalizations.of(context)!;
    if (enabled) {
      _noDisturbStartTime = NotificationSettings.defaultNoDisturbStart;
      _noDisturbEndTime = NotificationSettings.defaultNoDisturbEnd;
      Imclient.setNoDisturbingTimes(_noDisturbStartTime, _noDisturbEndTime, () {
        Fluttertoast.showToast(msg: l10n.setSuccess);
        setState(() {
          _noDisturbing = true;
        });
      }, (errorCode) {
        Fluttertoast.showToast(msg: l10n.networkError);
        _loadUserSettings();
      });
    } else {
      Imclient.clearNoDisturbingTimes(() {
        Fluttertoast.showToast(msg: l10n.setSuccess);
        setState(() {
          _noDisturbing = false;
          _noDisturbStartTime = 0;
          _noDisturbEndTime = 0;
        });
      }, (errorCode) {
        Fluttertoast.showToast(msg: l10n.networkError);
        _loadUserSettings();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.colors.chatBgDesktop,
      appBar: PcPageHeader(title: l10n.notifications),
      body: SingleChildScrollView(
        padding: PcPaneContent.defaultPadding,
        child: PcPaneContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PcSettingsSectionTitle(l10n.messageAlerts),
              PcCard(children: [
                PcSettingsSwitchRow(
                  title: l10n.receiveNewMessageNotification,
                  subtitle: l10n.receiveNewMessageNotificationDesc,
                  value: _receiveMsgNotification,
                  onChanged: (val) {
                    setState(() => _receiveMsgNotification = val);
                    _updateUserSetting(kUserSettingGlobalSilent, val,
                        revert: true);
                  },
                ),
                const Divider(),
                PcSettingsSwitchRow(
                  title: l10n.receiveCallNotification,
                  subtitle: l10n.receiveCallNotificationDesc,
                  value: _receiveVoipNotification,
                  onChanged: (val) {
                    setState(() => _receiveVoipNotification = val);
                    _updateUserSetting(kUserSettingVoipSilent, val,
                        revert: true);
                  },
                ),
                const Divider(),
                PcSettingsSwitchRow(
                  title: l10n.showNotificationDetail,
                  subtitle: l10n.showNotificationDetailDesc,
                  value: _showNotificationDetail,
                  onChanged: (val) {
                    setState(() => _showNotificationDetail = val);
                    _updateUserSetting(
                        kUserSettingHiddenNotificationDetail, val,
                        revert: true);
                  },
                ),
                const Divider(),
                PcSettingsSwitchRow(
                  title: l10n.noDisturb,
                  subtitle:
                      _noDisturbing && _noDisturbStartTime != _noDisturbEndTime
                          ? l10n.noDisturbPeriod(
                              NotificationSettings.formatNoDisturbTime(
                                  _noDisturbStartTime, _noDisturbEndTime))
                          : l10n.noDisturbDesc,
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
    );
  }
}

// --- 外观与主题 (Appearance) ---
class PcAppearanceSettingsDetail extends StatelessWidget {
  const PcAppearanceSettingsDetail({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeViewModel = Provider.of<LocaleViewModel>(context);
    final fontSizeViewModel = Provider.of<FontSizeViewModel>(context);
    final themeViewModel = Provider.of<ThemeViewModel>(context);

    String currentLangText = l10n.followSystem;
    if (localeViewModel.localeMode == 'zh') {
      currentLangText = l10n.simplifiedChinese;
    } else if (localeViewModel.localeMode == 'en') {
      currentLangText = l10n.english;
    }

    final currentThemeText = switch (themeViewModel.themeMode) {
      ThemeMode.light => l10n.themeLight,
      ThemeMode.dark => l10n.themeDark,
      ThemeMode.system => l10n.followSystem,
    };

    return Scaffold(
      backgroundColor: context.colors.chatBgDesktop,
      appBar: PcPageHeader(title: l10n.appearanceAndTheme),
      body: SingleChildScrollView(
        padding: PcPaneContent.defaultPadding,
        child: PcPaneContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PcSettingsSectionTitle(l10n.interfaceAppearance),
              PcCard(children: [
                _SettingsSelectorRow(
                  title: l10n.interfaceLanguage,
                  subtitle: l10n.interfaceLanguageDesc,
                  valueText: currentLangText,
                  onTap: (rowContext, tapPosition) {
                    _showLanguageMenu(rowContext, tapPosition);
                  },
                ),
                const Divider(),
                _SettingsSelectorRow(
                  title: l10n.appearanceTheme,
                  subtitle: l10n.appearanceThemeDesc,
                  valueText: currentThemeText,
                  onTap: (rowContext, tapPosition) {
                    _showThemeMenu(rowContext, tapPosition);
                  },
                ),
                const Divider(),
                _SettingsSliderRow(
                  title: l10n.fontSize,
                  subtitle: l10n.fontSizeDesc,
                  index: fontSizeViewModel.index,
                  itemCount: fontSizeViewModel.itemCount,
                  onChanged: fontSizeViewModel.setFontSizeIndex,
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageMenu(BuildContext selectorContext, Offset tapPosition) {
    final l10n = AppLocalizations.of(selectorContext)!;
    final localeViewModel =
        Provider.of<LocaleViewModel>(selectorContext, listen: false);
    final overlay = Navigator.of(selectorContext)
        .overlay!
        .context
        .findRenderObject() as RenderBox;
    showMenu<String>(
      context: selectorContext,
      position: RelativeRect.fromRect(
        overlay.globalToLocal(tapPosition) & Size.zero,
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(value: 'follow_system', child: Text(l10n.followSystem)),
        PopupMenuItem(value: 'zh', child: Text(l10n.simplifiedChinese)),
        PopupMenuItem(value: 'en', child: Text(l10n.english)),
      ],
    ).then((value) {
      if (value != null) {
        localeViewModel.setLocaleMode(value);
        Fluttertoast.showToast(msg: l10n.setSuccessRestartToApply);
      }
    });
  }

  void _showThemeMenu(BuildContext selectorContext, Offset tapPosition) {
    final l10n = AppLocalizations.of(selectorContext)!;
    final themeViewModel =
        Provider.of<ThemeViewModel>(selectorContext, listen: false);
    final overlay = Navigator.of(selectorContext)
        .overlay!
        .context
        .findRenderObject() as RenderBox;
    showMenu<ThemeMode>(
      context: selectorContext,
      position: RelativeRect.fromRect(
        overlay.globalToLocal(tapPosition) & Size.zero,
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(value: ThemeMode.system, child: Text(l10n.followSystem)),
        PopupMenuItem(value: ThemeMode.light, child: Text(l10n.themeLight)),
        PopupMenuItem(value: ThemeMode.dark, child: Text(l10n.themeDark)),
      ],
    ).then((value) {
      if (value != null) {
        themeViewModel.setThemeMode(value);
      }
    });
  }
}

// --- 账号与安全 (Security) ---
class PcSecuritySettingsDetail extends StatefulWidget {
  const PcSecuritySettingsDetail({super.key});

  @override
  State<PcSecuritySettingsDetail> createState() =>
      _PcSecuritySettingsDetailState();
}

class _PcSecuritySettingsDetailState extends State<PcSecuritySettingsDetail> {
  /// 退出入口:对齐原生 iOS 的退出 action sheet,提供「退出」与「注销账号」两项。
  void _handleLogout() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.logout),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(l10n.logout),
                onTap: () {
                  Navigator.pop(dialogContext);
                  _logout();
                },
              ),
              ListTile(
                title: Text(
                  l10n.destroyAccount,
                  style: TextStyle(color: dialogContext.colors.danger),
                ),
                onTap: () {
                  Navigator.pop(dialogContext);
                  openPage(context, const DestroyAccountScreen());
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _logout() {
    Fluttertoast.showToast(msg: AppLocalizations.of(context)!.logoutConfirm);
    navigateToLogin(Navigator.of(context, rootNavigator: true));
    Imclient.disconnect();
  }

  /// 举报(UGC 审核指南 1.2 要求):确认弹窗后打开与官方账号 cgc8c8VV 的单聊,
  /// 用户把举报内容(截图等)发送给官方处理。与移动端设置页行为一致。
  void _showReportDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.reportTitle),
          content: Text(l10n.reportMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                openConversation(
                    context,
                    Conversation(
                        conversationType: ConversationType.Single,
                        target: 'cgc8c8VV'));
              },
              child: Text(
                l10n.reportTitle,
                style: TextStyle(color: dialogContext.colors.danger),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Selector<UserViewModel, UserInfo?>(
      selector: (context, viewModel) =>
          viewModel.getUserInfo(Imclient.currentUserId),
      builder: (context, userInfo, _) {
        if (userInfo == null) {
          return Scaffold(
            backgroundColor: context.colors.chatBgDesktop,
            appBar: PcPageHeader(title: l10n.accountAndSecurity),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          backgroundColor: context.colors.chatBgDesktop,
          appBar: PcPageHeader(title: l10n.accountAndSecurity),
          body: SingleChildScrollView(
            padding: PcPaneContent.defaultPadding,
            child: PcPaneContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PcSettingsSectionTitle(l10n.currentLoginAccount),
                  Container(
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: context.colors.hairline, width: 0.5),
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
                                style: AppText.lg.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: context.colors.textPrimary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.accountName(userInfo.name),
                                style: AppText.xs.copyWith(
                                    color: context.colors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.tonal(
                          onPressed: _handleLogout,
                          // 危险次要:灰底无边框,只换前景色,形态走全局按钮主题。
                          style: FilledButton.styleFrom(
                              foregroundColor: context.colors.danger),
                          child: Text(l10n.signOut),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  PcSettingsSectionTitle(l10n.securitySection),
                  PcCard(children: [
                    PcSettingsClickableRow(
                      title: l10n.changePassword,
                      subtitle: l10n.changePasswordDesc,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const ChangePasswordScreen()),
                        );
                      },
                    ),
                    const Divider(),
                    PcSettingsClickableRow(
                      title: l10n.reportTitle,
                      subtitle: l10n.reportDesc,
                      onTap: _showReportDialog,
                    ),
                  ]),
                  const SizedBox(height: 20),
                  PcSettingsSectionTitle(l10n.dataSection),
                  PcCard(children: [
                    PcSettingsClickableRow(
                      title: l10n.backup_and_restore,
                      subtitle: l10n.backupAndRestoreDesc,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const PcBackupRestorePage()),
                        );
                      },
                    ),
                  ]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// --- 隐私 (Privacy) ---
/// 隐私设置详情页:找到我的方式、黑名单、消息回执、在线状态、
/// 好友验证、朋友圈。从账户与安全抽离为独立一级设置项。
class PcPrivacySettingsDetail extends StatefulWidget {
  const PcPrivacySettingsDetail({super.key});

  @override
  State<PcPrivacySettingsDetail> createState() =>
      _PcPrivacySettingsDetailState();
}

class _PcPrivacySettingsDetailState extends State<PcPrivacySettingsDetail> {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.colors.chatBgDesktop,
      appBar: PcPageHeader(title: l10n.privacy),
      body: SingleChildScrollView(
        padding: PcPaneContent.defaultPadding,
        child: PcPaneContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PcSettingsSectionTitle(l10n.privacy),
              PcCard(children: [
                PcSettingsClickableRow(
                  title: l10n.findMeBy,
                  subtitle: l10n.findMeByDesc,
                  // pushPage 压入子页面,返回时回到本隐私页;
                  // openPage 会整栏替换,返回后只剩空占位页
                  onTap: () => pushPage(context, const FindMeByScreen()),
                ),
                const Divider(),
                PcSettingsClickableRow(
                  title: l10n.blacklist,
                  subtitle: l10n.blacklistDesc,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const BlacklistScreen()),
                    );
                  },
                ),
                // 消息回执:仅当服务端支持时展示
                if (_receiptEnabled) ...[
                  const Divider(),
                  PcSettingsSwitchRow(
                    title: l10n.msgReceipt,
                    subtitle: l10n.msgReceiptDesc,
                    value: _receiptOn,
                    onChanged: _onReceiptChanged,
                  ),
                ],
                // 在线状态:仅当服务端开启在线状态能力时展示
                if (_onlineStateEnabled) ...[
                  const Divider(),
                  PcSettingsSwitchRow(
                    title: l10n.onlineStatus,
                    subtitle: l10n.onlineStatusDesc,
                    value: _showOnlineState,
                    onChanged: _onOnlineStateChanged,
                  ),
                ],
                const Divider(),
                PcSettingsSwitchRow(
                  title: l10n.friendVerify,
                  subtitle: l10n.friendVerifyDesc,
                  value: _friendVerify,
                  onChanged: _onFriendVerifyChanged,
                ),
                // 朋友圈设置,受 Config.ENABLE_MOMENTS 开关控制
                if (Config.ENABLE_MOMENTS) ...[
                  const Divider(),
                  PcSettingsClickableRow(
                    title: l10n.momentWindowTitle,
                    subtitle: l10n.momentsPrivacyDesc,
                    onTap: () =>
                        pushPage(context, const MomentPrivacySettingsScreen()),
                  ),
                ],
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 关于 (About) ---
class PcAboutSettingsDetail extends StatefulWidget {
  const PcAboutSettingsDetail({super.key});

  @override
  State<PcAboutSettingsDetail> createState() => _PcAboutSettingsDetailState();
}

class _PcAboutSettingsDetailState extends State<PcAboutSettingsDetail> {
  Timer? _restartTimer;

  Future<void> _openLogDir() async {
    try {
      final appPath = await Imclient.appPath;
      if (appPath.isEmpty) {
        Fluttertoast.showToast(msg: '无法获取日志目录');
        return;
      }
      final uri = Uri.directory(appPath);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        Fluttertoast.showToast(msg: '无法打开日志目录');
      }
    } catch (e) {
      debugPrint('openLogDir error: $e');
      Fluttertoast.showToast(msg: '打开日志目录失败');
    }
  }

  Future<void> _doRestart() async {
    _restartTimer?.cancel();
    try {
      await Process.start(Platform.resolvedExecutable, []);
      exit(0);
    } catch (e) {
      debugPrint('restart app error: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        await showDialog(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('重启失败'),
              content: const Text('自动重启失败，请关闭应用后手动启动。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(l10n.confirm),
                ),
              ],
            );
          },
        );
      }
    }
  }

  Future<void> _resetClientId() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('警告'),
          content: const Text('重置设备ID会删除本地所有内容（包括聊天记录、设置等），重置后需要重启应用。\n\n是否确认重置？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(foregroundColor: dialogContext.colors.danger),
              child: const Text('确认重置'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    try {
      await Imclient.resetClientId();
    } catch (e) {
      debugPrint('resetClientId error: $e');
      Fluttertoast.showToast(msg: '重置设备ID失败');
      return;
    }

    if (!mounted) return;

    _restartTimer = Timer(const Duration(seconds: 2), _doRestart);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('应用即将重启'),
          content: const Text('重置完成，应用将在 2 秒后自动重启。'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _doRestart();
              },
              child: const Text('立即重启'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _restartTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.colors.chatBgDesktop,
      appBar: PcPageHeader(title: l10n.about),
      body: SingleChildScrollView(
        padding: PcPaneContent.defaultPadding,
        child: PcPaneContent(
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
                      color: context.colors.shadow,
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
              Text(
                l10n.appName,
                style: AppText.xl.copyWith(
                    fontWeight: FontWeight.bold,
                    color: context.colors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.aboutVersion("v1.0.0"),
                style: AppText.xs.copyWith(color: context.colors.textSecondary),
              ),
              const SizedBox(height: 24),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: context.colors.hairline, width: 0.5),
                ),
                child: Text(
                  l10n.aboutDescription,
                  textAlign: TextAlign.center,
                  style: AppText.sm
                      .copyWith(color: context.colors.textPrimary, height: 1.5),
                ),
              ),
              const SizedBox(height: 40),
              // Links
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SettingsTextLink(
                      label: l10n.officialWebsite,
                      url: "https://wildfirechat.cn"),
                  const SizedBox(width: 12),
                  Text("|",
                      style: TextStyle(color: context.colors.textTertiary)),
                  const SizedBox(width: 12),
                  _SettingsTextLink(
                      label: l10n.githubRepo,
                      url: "https://github.com/wildfirechat"),
                  const SizedBox(width: 12),
                  Text("|",
                      style: TextStyle(color: context.colors.textTertiary)),
                  const SizedBox(width: 12),
                  _SettingsTextLink(
                      label: l10n.issueFeedback,
                      url: "https://bbs.wildfirechat.cn"),
                  const SizedBox(width: 12),
                  Text("|",
                      style: TextStyle(color: context.colors.textTertiary)),
                  const SizedBox(width: 12),
                  _SettingsActionLink(
                    label: '日志目录',
                    onTap: _openLogDir,
                  ),
                  const SizedBox(width: 12),
                  Text("|",
                      style: TextStyle(color: context.colors.textTertiary)),
                  const SizedBox(width: 12),
                  _SettingsActionLink(
                    label: '重置设备ID',
                    onTap: _resetClientId,
                    textColor: context.colors.danger,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l10n.wechatContact,
                style: AppText.xs.copyWith(color: context.colors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 3. Shared Reusable Setting Design Components
// ==========================================

class _SettingsSelectorRow extends StatefulWidget {
  final String title;
  final String subtitle;
  final String valueText;
  final void Function(BuildContext, Offset) onTap;

  const _SettingsSelectorRow({
    required this.title,
    required this.subtitle,
    required this.valueText,
    required this.onTap,
  });

  @override
  State<_SettingsSelectorRow> createState() => _SettingsSelectorRowState();
}

class _SettingsSelectorRowState extends State<_SettingsSelectorRow> {
  Offset _tapPosition = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) {
        return Builder(
          builder: (rowContext) => InkWell(
            onTapDown: (details) {
              _tapPosition = details.globalPosition;
            },
            onTap: () => widget.onTap(rowContext, _tapPosition),
            child: Container(
              color: hovered ? context.colors.hoverOverlay : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title,
                            style: AppText.base.copyWith(
                                fontWeight: FontWeight.w500,
                                color: context.colors.textPrimary)),
                        const SizedBox(height: 4),
                        Text(widget.subtitle,
                            style: AppText.xs
                                .copyWith(color: context.colors.textSecondary)),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Text(widget.valueText,
                          style: AppText.sm
                              .copyWith(color: context.colors.textSecondary)),
                      const SizedBox(width: 8),
                      Icon(Icons.keyboard_arrow_down_rounded,
                          size: 18, color: context.colors.textTertiary),
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

/// 档位滑块。用索引而不是倍数驱动 —— 倍数会让 min/max/divisions 与
/// FontSizeViewModel 的档位表脱钩,加一档就会触发 Slider 的 value 越界断言。
class _SettingsSliderRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final int index;
  final int itemCount;
  final ValueChanged<int> onChanged;

  const _SettingsSliderRow({
    required this.title,
    required this.subtitle,
    required this.index,
    required this.itemCount,
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
                    Text(title,
                        style: AppText.base.copyWith(
                            fontWeight: FontWeight.w500,
                            color: context.colors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: AppText.xs
                            .copyWith(color: context.colors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 滑块自身是调节字号的控件,不跟着字号放大:否则档位标签在英文下会横向溢出。
          MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.noScaling),
            child: Column(
              children: [
                Row(
                  children: [
                    Text("A",
                        style: AppText.xs
                            .copyWith(color: context.colors.textSecondary)),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: context.colors.accent,
                          inactiveTrackColor: context.colors.inputBg,
                          thumbColor: context.colors.surface,
                          overlayColor:
                              context.colors.accent.withValues(alpha: 0.1),
                          valueIndicatorColor: context.colors.accent,
                          activeTickMarkColor: context.colors.accent,
                          inactiveTickMarkColor: context.colors.textTertiary,
                          tickMarkShape: const RoundSliderTickMarkShape(
                              tickMarkRadius: 2.0),
                        ),
                        child: Slider(
                          value: index.toDouble(),
                          min: 0,
                          max: (itemCount - 1).toDouble(),
                          divisions: itemCount - 1,
                          onChanged: (value) => onChanged(value.round()),
                        ),
                      ),
                    ),
                    Text("A",
                        style: AppText.lg.copyWith(
                            fontWeight: FontWeight.bold,
                            color: context.colors.textPrimary)),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      for (final label in _fontSizeLabels(context))
                        Expanded(
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.xs
                                .copyWith(color: context.colors.textSecondary),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static List<String> _fontSizeLabels(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      l10n.fontSizeSmall,
      l10n.fontSizeNormal,
      l10n.fontSizeMedium,
      l10n.fontSizeLarge,
      l10n.fontSizeExtraLarge
    ];
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
          onTap: () async {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else if (context.mounted) {
              Fluttertoast.showToast(
                  msg: AppLocalizations.of(context)!.cannotOpenLink);
            }
          },
          child: Text(
            label,
            style: AppText.xs.copyWith(
                color: hovered
                    ? context.colors.accentPressed
                    : context.colors.accent,
                decoration: TextDecoration.underline,
                decorationColor: hovered
                    ? context.colors.accentPressed
                    : context.colors.accent),
          ),
        );
      },
    );
  }
}

class _SettingsActionLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? textColor;

  const _SettingsActionLink({
    required this.label,
    required this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: SystemMouseCursors.click,
      builder: (context, hovered) {
        final baseColor = textColor ?? context.colors.accent;
        final hoverColor = textColor ?? context.colors.accentPressed;
        return GestureDetector(
          onTap: onTap,
          child: Text(
            label,
            style: AppText.xs.copyWith(
                color: hovered ? hoverColor : baseColor,
                decoration: TextDecoration.underline,
                decorationColor: hovered ? hoverColor : baseColor),
          ),
        );
      },
    );
  }
}
