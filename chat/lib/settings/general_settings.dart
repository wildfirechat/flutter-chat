import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:provider/provider.dart';
import 'package:chat/config.dart';
import 'package:chat/utilities.dart';
import 'package:chat/l10n/app_localizations.dart';
import '../app_navigator.dart';
import '../pc/pc_platform.dart';
import '../pc/widgets/pc_page_header.dart';
import '../viewmodel/locale_view_model.dart';
import '../viewmodel/theme_view_model.dart';
import 'destroy_account_screen.dart';
import 'font_size_settings_screen.dart';
import 'privacy_settings_screen.dart';
import '../widget/option_item.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';

class GeneralSettings extends StatelessWidget {
  const GeneralSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isDesktopShell
          ? PcPageHeader(title: AppLocalizations.of(context)!.settings)
          : AppBar(
              title: Text(AppLocalizations.of(context)!.settings),
            ),
      backgroundColor: isDesktopShell
          ? context.colors.chatBgDesktop
          : context.colors.primaryBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                color: context.colors.surface,
                child: Column(
                  children: [
                    OptionItem(
                      AppLocalizations.of(context)!.privacySettings,
                      onTap: () {
                        openPage(context, const PrivacySettingsScreen());
                      },
                    ),
                    OptionItem(
                      AppLocalizations.of(context)!.language,
                      onTap: () {
                        _showLanguageDialog(context);
                      },
                    ),
                    OptionItem(
                      AppLocalizations.of(context)!.fontSize,
                      onTap: () {
                        openPage(context, const FontSizeSettingsScreen());
                      },
                    ),
                    OptionItem(
                      AppLocalizations.of(context)!.theme,
                      showBottomDivider: false,
                      onTap: () {
                        _showThemeDialog(context);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                color: context.colors.surface,
                child: OptionItem(
                  AppLocalizations.of(context)!.about,
                  showBottomDivider: false,
                  onTap: () {
                    Fluttertoast.showToast(
                        msg: AppLocalizations.of(context)!.methodNotImpl);
                  },
                ),
              ),
              const SizedBox(height: 18),
              Container(
                color: context.colors.surface,
                child: Column(
                  children: [
                    OptionItem(
                      AppLocalizations.of(context)!.userAgreement,
                      onTap: () {
                        Utilities.openLink(context, Config.USER_AGREEMENT_URL);
                      },
                    ),
                    OptionItem(
                      AppLocalizations.of(context)!.privacyPolicy,
                      onTap: () {
                        Utilities.openLink(
                            context, Config.PRIVACY_AGREEMENT_URL);
                      },
                    ),
                    OptionItem(
                      AppLocalizations.of(context)!.reportTitle,
                      showBottomDivider: false,
                      onTap: () {
                        _showReportDialog(context);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                color: context.colors.surface,
                child: OptionItem(
                  AppLocalizations.of(context)!.diagnostics,
                  showBottomDivider: false,
                  onTap: () {
                    Fluttertoast.showToast(
                        msg: AppLocalizations.of(context)!.methodNotImpl);
                  },
                ),
              ),
              const SizedBox(height: 18),
              Container(
                color: context.colors.surface,
                child: GestureDetector(
                  onTap: () {
                    _handleLogout(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(15, 10, 5, 10),
                    height: 36,
                    child: Center(
                      child: Text(
                        AppLocalizations.of(context)!.logout,
                        style:
                            AppText.lg.copyWith(color: context.colors.danger),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final localeViewModel =
        Provider.of<LocaleViewModel>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l10n.language),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(l10n.followSystem),
                trailing: localeViewModel.localeMode == 'follow_system'
                    ? Icon(Icons.check, color: context.colors.accent)
                    : null,
                onTap: () {
                  localeViewModel.setLocaleMode('follow_system');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text(l10n.chinese),
                trailing: localeViewModel.localeMode == 'zh'
                    ? Icon(Icons.check, color: context.colors.accent)
                    : null,
                onTap: () {
                  localeViewModel.setLocaleMode('zh');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text(l10n.english),
                trailing: localeViewModel.localeMode == 'en'
                    ? Icon(Icons.check, color: context.colors.accent)
                    : null,
                onTap: () {
                  localeViewModel.setLocaleMode('en');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showThemeDialog(BuildContext context) {
    final themeViewModel = Provider.of<ThemeViewModel>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        Widget option(String label, ThemeMode mode) => ListTile(
              title: Text(label),
              trailing: themeViewModel.themeMode == mode
                  ? Icon(Icons.check, color: dialogContext.colors.accent)
                  : null,
              onTap: () {
                themeViewModel.setThemeMode(mode);
                Navigator.pop(dialogContext);
              },
            );
        return AlertDialog(
          title: Text(l10n.theme),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              option(l10n.followSystem, ThemeMode.system),
              option(l10n.themeLight, ThemeMode.light),
              option(l10n.themeDark, ThemeMode.dark),
            ],
          ),
        );
      },
    );
  }

  /// 举报(UGC 审核指南 1.2 要求):确认弹窗后打开与官方账号 cgc8c8VV 的单聊,
  /// 用户把举报内容(截图等)发送给官方处理。交互对齐原生 iOS 设置页的举报入口。
  void _showReportDialog(BuildContext context) {
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
                style: TextStyle(color: context.colors.danger),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 退出入口:对齐原生 iOS 的退出 action sheet,提供「退出」与「注销账号」两项。
  void _handleLogout(BuildContext context) {
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
                  _logout(context);
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

  void _logout(BuildContext context) {
    Fluttertoast.showToast(msg: AppLocalizations.of(context)!.logoutConfirm);
    navigateToLogin(Navigator.of(context, rootNavigator: true));
    Imclient.disconnect();
  }
}
