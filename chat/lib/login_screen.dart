import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_server.dart';
import 'config.dart';
import 'home/home.dart';
import 'utilities.dart';
import 'widget/slide_verify_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  LoginScreenState({this.title = '登录'});

  late SharedPreferences prefs;

  String? currentUser;
  String title;
  bool isSentCode = false;
  int waitResendCount = 0;
  Timer? _timer;

  bool _isPhoneEmpty = true;
  bool _isCodeOrPwdEmpty = true;
  bool _agreementChecked = false;
  bool _isPasswordLogin = false;

  // 滑动验证相关状态
  bool _hasSlideVerifiedForCode = false;
  String? _cachedSlideVerifyToken;

  @override
  void initState() {
    super.initState();

    // 添加文本控制器监听
    phoneFieldController.addListener(_checkPhoneField);
    codeOrPwdFieldController.addListener(_checkCodeOrPwdField);
  }

  @override
  void dispose() {
    // 移除监听器
    phoneFieldController.removeListener(_checkPhoneField);
    codeOrPwdFieldController.removeListener(_checkCodeOrPwdField);
    _timer?.cancel();
    super.dispose();
  }

  // 检查电话号码字段
  void _checkPhoneField() {
    setState(() {
      _isPhoneEmpty = phoneFieldController.text.length != 11;
    });
  }

  // 检查验证码或密码字段
  void _checkCodeOrPwdField() {
    setState(() {
      _isCodeOrPwdEmpty = codeOrPwdFieldController.text.isEmpty;
    });
  }

  final phoneFieldController = TextEditingController();
  final codeOrPwdFieldController = TextEditingController();

  void _toggleLoginMode() {
    setState(() {
      _isPasswordLogin = !_isPasswordLogin;
      codeOrPwdFieldController.clear();
      _isCodeOrPwdEmpty = true;
      // 重置滑动验证状态
      _hasSlideVerifiedForCode = false;
      _cachedSlideVerifyToken = null;
      if (_isPasswordLogin) {
        // Reset timer if switching to password mode
        if (_timer != null) {
          _timer!.cancel();
          _timer = null;
        }
        isSentCode = false;
        waitResendCount = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 40, 8, 10),
              child: Text(
                _isPasswordLogin ? "密码登录" : "手机号登录",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: CupertinoTextField(
                placeholder: '请输入电话号码',
                controller: phoneFieldController,
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
                      placeholder: _isPasswordLogin ? '请输入密码' : '请输入验证码',
                      controller: codeOrPwdFieldController,
                      clearButtonMode: OverlayVisibilityMode.editing,
                      autocorrect: false,
                      obscureText: _isPasswordLogin,
                    ),
                  ),
                  if (!_isPasswordLogin) ...[
                    const SizedBox(
                      width: 8,
                    ),
                    ElevatedButton(
                      onPressed: _isPhoneEmpty || isSentCode
                          ? null
                          : _showSlideVerifyForSendCode,
                      child: isSentCode
                          ? Text('$waitResendCount s')
                          : const Text('发送验证码'),
                    ),
                  ],
                ],
              ),
            ),
            Row(
              children: [
                Checkbox(
                  value: _agreementChecked,
                  onChanged: (bool? value) {
                    setState(() {
                      _agreementChecked = value!;
                    });
                  },
                ),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      text: '我已阅读并同意 ',
                      style: const TextStyle(color: Colors.black),
                      children: <TextSpan>[
                        TextSpan(
                          text: '用户协议',
                          style: const TextStyle(color: Colors.blue),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Utilities.openLink(context, Config.USER_AGREEMENT_URL);
                            },
                        ),
                        const TextSpan(text: ' 和 '),
                        TextSpan(
                          text: '隐私政策',
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
              onPressed: (_isPhoneEmpty || _isCodeOrPwdEmpty)
                  ? null
                  : () {
                      if (!_agreementChecked) {
                        Fluttertoast.showToast(msg: "请先同意用户协议和隐私政策");
                        return;
                      }
                      String phoneNum = phoneFieldController.value.text;
                      String codeOrPwd = codeOrPwdFieldController.value.text;

                      if (_isPasswordLogin) {
                        _showSlideVerifyForPasswordLogin(phoneNum, codeOrPwd);
                      } else {
                        _showSlideVerifyForSmsLogin(phoneNum, codeOrPwd);
                      }
                    },
              child: const Text('登录'),
            ),
            TextButton(
              onPressed: _toggleLoginMode,
              child: Text(_isPasswordLogin ? "手机验证码登录" : "密码登录"),
            ),
          ],
        ),
      ),
    );
  }

  void _handleLoginSuccess(String userId, String token) {
    Imclient.connect(Config.IM_Host, userId, token);
    Navigator.replace(context,
        oldRoute: ModalRoute.of(context)!,
        newRoute: MaterialPageRoute(
            builder: (context) => const HomeTabBar()));
    SharedPreferences.getInstance().then((value) {
      value.setString("userId", userId);
      value.setString("token", token);
    });
  }

  /// 显示滑动验证对话框（用于发送验证码）
  void _showSlideVerifyForSendCode() {
    SlideVerifyDialog.show(
      context: context,
      listener: _SendCodeSlideVerifyListener(
        phoneNumber: phoneFieldController.value.text,
        onStartCountdown: () {
          Fluttertoast.showToast(msg: "验证码发送成功，请在5分钟内进行验证!");
          const Duration duration = Duration(seconds: 1);
          _timer = Timer.periodic(duration, (timer) {
            setState(() {
              waitResendCount = waitResendCount + 1;
              if (waitResendCount >= 60) {
                isSentCode = false;
                _timer!.cancel();
              }
            });
          });

          setState(() {
            waitResendCount = 0;
            isSentCode = true;
          });
        },
        onError: (msg) => Fluttertoast.showToast(msg: "发送验证码失败: $msg"),
        onSetSlideVerified: (token) {
          setState(() {
            _hasSlideVerifiedForCode = true;
            _cachedSlideVerifyToken = token;
          });
        },
      ),
    );
  }

  /// 显示滑动验证对话框（用于密码登录）
  void _showSlideVerifyForPasswordLogin(String phoneNum, String password) {
    SlideVerifyDialog.show(
      context: context,
      listener: _LoginSlideVerifyListener(
        isPasswordLogin: true,
        phoneNumber: phoneNum,
        password: password,
        onLoginSuccess: (userId, token) => _handleLoginSuccess(userId, token),
        onLoginError: (msg) => Fluttertoast.showToast(msg: "登录失败: $msg"),
      ),
    );
  }

  /// 显示滑动验证对话框（用于短信登录）
  void _showSlideVerifyForSmsLogin(String phoneNum, String authCode) {
    // 如果已经通过滑动验证（发送验证码时已验证），直接登录
    if (_hasSlideVerifiedForCode && _cachedSlideVerifyToken != null) {
      _performSmsLogin(phoneNum, authCode, null);
      return;
    }

    SlideVerifyDialog.show(
      context: context,
      listener: _LoginSlideVerifyListener(
        isPasswordLogin: false,
        phoneNumber: phoneNum,
        authCode: authCode,
        onLoginSuccess: (userId, token) => _handleLoginSuccess(userId, token),
        onLoginError: (msg) {
          Fluttertoast.showToast(msg: "登录失败: $msg");
          // 登录失败，重置验证标志
          setState(() {
            _hasSlideVerifiedForCode = false;
            _cachedSlideVerifyToken = null;
          });
        },
      ),
    );
  }

  /// 执行短信登录
  void _performSmsLogin(String phoneNum, String authCode, String? slideVerifyToken) {
    AppServer.login(phoneNum, authCode,
        (userId, token, isNewUser) {
      _handleLoginSuccess(userId, token);
    }, (msg) {
      Fluttertoast.showToast(msg: "登录失败: $msg");
      // 登录失败，重置验证标志
      setState(() {
        _hasSlideVerifiedForCode = false;
        _cachedSlideVerifyToken = null;
      });
    }, slideVerifyToken: slideVerifyToken);
  }
}

/// 发送验证码滑动验证监听器
class _SendCodeSlideVerifyListener implements SlideVerifyListener {
  final String phoneNumber;
  final VoidCallback onStartCountdown;
  final Function(String) onError;
  final Function(String) onSetSlideVerified;

  _SendCodeSlideVerifyListener({
    required this.phoneNumber,
    required this.onStartCountdown,
    required this.onError,
    required this.onSetSlideVerified,
  });

  @override
  void onVerifySuccess(String token) {
    // 发送验证码
    AppServer.sendCode(phoneNumber, () {
      onSetSlideVerified(token);
      onStartCountdown();
    }, (msg) {
      onError(msg);
    }, slideVerifyToken: token);
  }

  @override
  void onVerifyFailed() {
    // 验证失败，不处理，由对话框自动重置
  }

  @override
  void onLoadFailed() {
    // 加载失败，不处理
  }
}

/// 登录滑动验证监听器
class _LoginSlideVerifyListener implements SlideVerifyListener {
  final bool isPasswordLogin;
  final String phoneNumber;
  final String? password;
  final String? authCode;
  final Function(String userId, String token) onLoginSuccess;
  final Function(String msg) onLoginError;

  _LoginSlideVerifyListener({
    required this.isPasswordLogin,
    required this.phoneNumber,
    this.password,
    this.authCode,
    required this.onLoginSuccess,
    required this.onLoginError,
  });

  @override
  void onVerifySuccess(String token) {
    if (isPasswordLogin) {
      AppServer.passwordLogin(phoneNumber, password!,
        (userId, token, isNewUser) {
        onLoginSuccess(userId, token);
      }, (msg) {
        onLoginError(msg);
      }, slideVerifyToken: token);
    } else {
      AppServer.login(phoneNumber, authCode!,
          (userId, token, isNewUser) {
        onLoginSuccess(userId, token);
      }, (msg) {
        onLoginError(msg);
      }, slideVerifyToken: token);
    }
  }

  @override
  void onVerifyFailed() {
    // 验证失败，不处理，由对话框自动重置
  }

  @override
  void onLoadFailed() {
    // 加载失败，不处理
  }
}
