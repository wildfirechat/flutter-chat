import 'dart:async';

import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chat/app_server.dart';
import 'package:chat/config.dart';
import 'package:chat/home/app_home.dart';
import 'package:chat/main.dart';
import 'package:chat/utils/show_toast.dart';
import 'package:chat/widget/slide_verify_dialog.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:imclient/imclient_platform.dart';

/// 手机号 + 验证码/密码登录的共享表单逻辑,移动端 [LoginScreen] 与桌面
/// PCQRLoginScreen 的表单视图共用:输入校验、验证码 60s 倒计时、滑动验证、
/// AppServer 登录调用、成功后保存凭证并进入各端主界面。
/// UI 由各端自绘,本类只暴露状态与动作,变化经 notifyListeners 通知。
class LoginFormController extends ChangeNotifier {
  final phoneController = TextEditingController();
  final codeOrPwdController = TextEditingController();

  bool _isPasswordLogin = Config.Prefer_Password_Login;
  bool _agreementChecked = false;
  bool _isSentCode = false;
  int _waitResendCount = 0;
  Timer? _resendTimer;

  /// 发送验证码时已通过滑动验证,提交登录时无需再弹(登录失败后重置)。
  bool _slideVerifiedForCode = false;

  LoginFormController() {
    phoneController.addListener(notifyListeners);
    codeOrPwdController.addListener(notifyListeners);
  }

  bool get isPasswordLogin => _isPasswordLogin;
  bool get agreementChecked => _agreementChecked;
  bool get isSentCode => _isSentCode;
  int get waitResendCount => _waitResendCount;
  bool get phoneValid => phoneController.text.length == 11;
  bool get canSendCode => phoneValid && !_isSentCode;
  bool get canSubmit => phoneValid && codeOrPwdController.text.isNotEmpty;

  set agreementChecked(bool value) {
    _agreementChecked = value;
    notifyListeners();
  }

  /// 在验证码登录与密码登录间切换,清空密码框与验证状态。
  void toggleLoginMode() {
    _isPasswordLogin = !_isPasswordLogin;
    codeOrPwdController.clear();
    _slideVerifiedForCode = false;
    if (_isPasswordLogin) {
      _resendTimer?.cancel();
      _resendTimer = null;
      _isSentCode = false;
      _waitResendCount = 0;
    }
    notifyListeners();
  }

  /// 发送验证码:若开启滑动验证则先验证,通过后由服务端发送并开始倒计时。
  void sendCode(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!Config.ENABLE_SLIDE_VERIFY) {
      AppServer.sendCode(
        phoneController.text,
        () {
          showToast(msg: l10n.sendCodeSuccess);
          _startResendCountdown();
        },
        (msg) => showToast(msg: l10n.sendCodeFailWithError(msg)),
      );
      return;
    }
    SlideVerifyDialog.show(
      context: context,
      listener: _SendCodeSlideVerifyListener(
        phoneNumber: phoneController.text,
        onSent: () {
          _slideVerifiedForCode = true;
          showToast(msg: l10n.sendCodeSuccess);
          _startResendCountdown();
        },
        onError: (msg) => showToast(msg: l10n.sendCodeFailWithError(msg)),
      ),
    );
  }

  void _startResendCountdown() {
    _waitResendCount = 0;
    _isSentCode = true;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _waitResendCount++;
      if (_waitResendCount >= 60) {
        _isSentCode = false;
        timer.cancel();
      }
      notifyListeners();
    });
    notifyListeners();
  }

  /// 提交登录。密码模式必过滑动验证;验证码模式若发码时已验证则直接登录。
  void submit(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!_agreementChecked) {
      showToast(msg: l10n.agreePolicyFirst);
      return;
    }
    final String phone = phoneController.text;
    final String codeOrPwd = codeOrPwdController.text;

    if (_isPasswordLogin) {
      if (Config.ENABLE_SLIDE_VERIFY) {
        SlideVerifyDialog.show(
          context: context,
          listener: _LoginSlideVerifyListener(
            login: (verifyToken) => AppServer.passwordLogin(phone, codeOrPwd,
                (userId, token, isNewUser) {
              _onLoginSuccess(context, userId, token);
            }, (msg) => showToast(msg: l10n.loginFail(msg)),
                slideVerifyToken: verifyToken),
          ),
        );
      } else {
        AppServer.passwordLogin(phone, codeOrPwd, (userId, token, isNewUser) {
          _onLoginSuccess(context, userId, token);
        }, (msg) => showToast(msg: l10n.loginFail(msg)));
      }
      return;
    }

    if (_slideVerifiedForCode || !Config.ENABLE_SLIDE_VERIFY) {
      // 与既有服务端约定一致:发码阶段已滑动验证过,登录请求不再携带 verify token
      _smsLogin(context, phone, codeOrPwd, null);
      return;
    }
    SlideVerifyDialog.show(
      context: context,
      listener: _LoginSlideVerifyListener(
        login: (verifyToken) =>
            _smsLogin(context, phone, codeOrPwd, verifyToken),
      ),
    );
  }

  void _smsLogin(BuildContext context, String phone, String authCode,
      String? slideVerifyToken) {
    final l10n = AppLocalizations.of(context)!;
    AppServer.login(phone, authCode, (userId, token, isNewUser) {
      _onLoginSuccess(context, userId, token);
    }, (msg) {
      showToast(msg: l10n.loginFail(msg));
      _slideVerifiedForCode = false; // 失败后重走滑动验证
      notifyListeners();
    }, slideVerifyToken: slideVerifyToken);
  }

  void _onLoginSuccess(BuildContext context, String userId, String token) {
    Imclient.connect(Config.IM_Host, userId, token);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('userId', userId);
      prefs.setString('token', token);
    });
    MyApp.of(context)?.onLoginSuccess(userId);
    if (context.mounted) {
      showToast(msg: AppLocalizations.of(context)!.loginSuccess);
      // 桌面端不要再 pushReplacement(PCHome):onLoginSuccess 已经把 home 切成
      // PCHome,再压一个路由实例会同时存在两个 PCHome,后注册的 pageOpener 随
      // 被替换路由销毁时被置 null,右栏导航静默失效(设置页点项不切换)。
      // 同 3376556 对扫码登录的处理;移动端 home 是路由,仍需 pushReplacement。
      if (!WfcPlatform.isDesktop) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AppHome()),
        );
      }
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    phoneController.dispose();
    codeOrPwdController.dispose();
    super.dispose();
  }
}

/// 发送验证码的滑动验证监听:验证通过 → 服务端发码 → 回调开始倒计时。
class _SendCodeSlideVerifyListener implements SlideVerifyListener {
  final String phoneNumber;
  final VoidCallback onSent;
  final void Function(String msg) onError;

  _SendCodeSlideVerifyListener(
      {required this.phoneNumber, required this.onSent, required this.onError});

  @override
  void onVerifySuccess(String token) {
    AppServer.sendCode(phoneNumber, onSent, onError, slideVerifyToken: token);
  }

  @override
  void onVerifyFailed() {}

  @override
  void onLoadFailed() {}
}

/// 登录的滑动验证监听:验证通过后携带 verify token 执行登录动作。
class _LoginSlideVerifyListener implements SlideVerifyListener {
  final void Function(String verifyToken) login;

  _LoginSlideVerifyListener({required this.login});

  @override
  void onVerifySuccess(String token) => login(token);

  @override
  void onVerifyFailed() {}

  @override
  void onLoadFailed() {}
}
