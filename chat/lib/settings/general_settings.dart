import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../login_screen.dart';
import '../pc/pc_platform.dart';
import '../pc/pc_qr_login_screen.dart';
import '../pc/pc_theme.dart';
import '../pc/widgets/pc_page_header.dart';
import '../viewmodel/locale_view_model.dart';
import '../widget/option_item.dart';
import '../widget/section_divider.dart';

class GeneralSettings extends StatelessWidget {
  /// 桌面端登出回调。手机端可忽略。
  final VoidCallback? onLogout;

  const GeneralSettings({super.key, this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isDesktopShell
          ? PcPageHeader(title: AppLocalizations.of(context)!.settings)
          : AppBar(
              title: Text(AppLocalizations.of(context)!.settings),
            ),
      backgroundColor: isDesktopShell ? PcTheme.chatBg : null,
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
                AppLocalizations.of(context)!.theme,
                onTap: () {
                  Fluttertoast.showToast(msg: AppLocalizations.of(context)!.methodNotImpl);
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
                      style: const TextStyle(color: Colors.red, fontSize: 16),
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
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  localeViewModel.setLocaleMode('follow_system');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text(l10n.chinese),
                trailing: localeViewModel.localeMode == 'zh'
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  localeViewModel.setLocaleMode('zh');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text(l10n.english),
                trailing: localeViewModel.localeMode == 'en'
                    ? const Icon(Icons.check, color: Colors.blue)
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

  void _handleLogout(BuildContext context) {
    Fluttertoast.showToast(msg: AppLocalizations.of(context)!.logoutConfirm);

    if (isDesktopShell && onLogout != null) {
      // 桌面端由 PCHome 用根 Navigator 切到登录页。
      onLogout!();
      Imclient.disconnect();
      return;
    }

    bool topIsLogin = false;
    Navigator.of(context).popUntil((route) {
      topIsLogin = route.settings.name == 'login';
      return true;
    });
    if (!topIsLogin) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => isDesktopShell ? const PCQRLoginScreen() : const LoginScreen(),
          settings: const RouteSettings(name: 'login'),
        ),
        (Route<dynamic> route) => false,
      );
    }
    Imclient.disconnect();
  }
}