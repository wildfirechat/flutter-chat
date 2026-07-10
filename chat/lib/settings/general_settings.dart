import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:provider/provider.dart';
import 'package:chat/l10n/app_localizations.dart';
import '../app_navigator.dart';
import '../pc/pc_platform.dart';
import '../pc/widgets/pc_page_header.dart';
import '../viewmodel/locale_view_model.dart';
import '../viewmodel/theme_view_model.dart';
import 'font_size_settings_screen.dart';
import '../widget/option_item.dart';
import '../widget/section_divider.dart';
import 'package:chat/theme/app_colors.dart';

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
      backgroundColor: isDesktopShell ? context.colors.chatBgDesktop : null,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SectionDivider(),
              OptionItem(
                AppLocalizations.of(context)!.privacySettings,
                onTap: () {
                  Fluttertoast.showToast(msg: AppLocalizations.of(context)!.methodNotImpl);
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
                onTap: () {
                  _showThemeDialog(context);
                },
              ),
              const SectionDivider(),
              OptionItem(
                AppLocalizations.of(context)!.about,
                onTap: () {
                  Fluttertoast.showToast(msg: AppLocalizations.of(context)!.methodNotImpl);
                },
              ),
              const SectionDivider(),
              OptionItem(
                AppLocalizations.of(context)!.userAgreement,
                onTap: () {
                  Fluttertoast.showToast(msg: AppLocalizations.of(context)!.methodNotImpl);
                },
              ),
              OptionItem(
                AppLocalizations.of(context)!.privacyPolicy,
                onTap: () {
                  Fluttertoast.showToast(msg: AppLocalizations.of(context)!.methodNotImpl);
                },
              ),
              OptionItem(
                AppLocalizations.of(context)!.complaints,
                onTap: () {
                  Fluttertoast.showToast(msg: AppLocalizations.of(context)!.methodNotImpl);
                },
              ),
              const SectionDivider(),
              OptionItem(
                AppLocalizations.of(context)!.diagnostics,
                onTap: () {
                  Fluttertoast.showToast(msg: AppLocalizations.of(context)!.methodNotImpl);
                },
              ),
              const SectionDivider(),
              GestureDetector(
                onTap: () {
                  _handleLogout(context);
                },
                child: Container(
                  margin: const EdgeInsets.fromLTRB(15, 10, 5, 10),
                  height: 36,
                  child: Center(
                    child: Text(
                      AppLocalizations.of(context)!.logout,
                      style: TextStyle(color: context.colors.danger, fontSize: 16),
                    ),
                  ),
                ),
              ),
              const SectionDivider(),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final localeViewModel = Provider.of<LocaleViewModel>(context, listen: false);
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

  void _handleLogout(BuildContext context) {
    Fluttertoast.showToast(msg: AppLocalizations.of(context)!.logoutConfirm);
    navigateToLogin(Navigator.of(context, rootNavigator: true));
    Imclient.disconnect();
  }
}