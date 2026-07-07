import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'config.dart';
import 'login/login_form_controller.dart';
import 'utilities.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// 移动端登录页(手机壳)。表单状态与登录流程在共享的 [LoginFormController],
/// 桌面端 PCQRLoginScreen 的表单视图复用同一控制器。
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final LoginFormController _form = LoginFormController();

  @override
  void initState() {
    super.initState();
    _form.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    _form.removeListener(_onFormChanged);
    _form.dispose();
    super.dispose();
  }

  void _onFormChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.loginPageTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 40, 8, 10),
              child: Text(
                _form.isPasswordLogin ? l10n.loginWithPassword : l10n.loginWithPhone,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: CupertinoTextField(
                placeholder: l10n.phoneNumberHint,
                controller: _form.phoneController,
                keyboardType: TextInputType.phone,
                clearButtonMode: OverlayVisibilityMode.editing,
                autocorrect: false,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      placeholder: _form.isPasswordLogin ? l10n.inputPassword : l10n.inputVerificationCode,
                      controller: _form.codeOrPwdController,
                      clearButtonMode: OverlayVisibilityMode.editing,
                      autocorrect: false,
                      obscureText: _form.isPasswordLogin,
                    ),
                  ),
                  if (!_form.isPasswordLogin) ...[
                    const SizedBox(
                      width: 8,
                    ),
                    ElevatedButton(
                      onPressed: _form.canSendCode ? () => _form.sendCode(context) : null,
                      child: _form.isSentCode ? Text('${_form.waitResendCount} s') : Text(l10n.sendCode),
                    ),
                  ],
                ],
              ),
            ),
            Row(
              children: [
                Checkbox(
                  value: _form.agreementChecked,
                  onChanged: (bool? value) {
                    _form.agreementChecked = value!;
                  },
                ),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      text: l10n.readAndAgree,
                      style: const TextStyle(color: Colors.black),
                      children: <TextSpan>[
                        TextSpan(
                          text: l10n.userAgreement,
                          style: const TextStyle(color: Colors.blue),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Utilities.openLink(context, Config.USER_AGREEMENT_URL);
                            },
                        ),
                        TextSpan(text: l10n.and),
                        TextSpan(
                          text: l10n.privacyPolicy,
                          style: const TextStyle(color: Colors.blue),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Utilities.openLink(context, Config.PRIVACY_AGREEMENT_URL);
                            },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            ElevatedButton(
              onPressed: _form.canSubmit ? () => _form.submit(context) : null,
              child: Text(l10n.login),
            ),
            TextButton(
              onPressed: _form.toggleLoginMode,
              child: Text(_form.isPasswordLogin ? l10n.loginWithPhoneCode : l10n.loginWithPassword),
            ),
          ],
        ),
      ),
    );
  }
}
