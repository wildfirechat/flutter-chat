import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_server.dart';
import 'config.dart';
import 'home/home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

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

  void _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      Fluttertoast.showToast(msg: 'Could not launch $url');
    }
  }

  void _toggleLoginMode() {
    setState(() {
      _isPasswordLogin = !_isPasswordLogin;
      codeOrPwdFieldController.clear();
      _isCodeOrPwdEmpty = true;
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
                          : () {
                              AppServer.sendCode(phoneFieldController.value.text,
                                  () {
                                Fluttertoast.showToast(
                                    msg: "验证码发送成功，请在5分钟内进行验证!");
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
                              }, (msg) => Fluttertoast.showToast(msg: "发送验证码失败!"));
                            },
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
                              _launchUrl(Config.USER_AGREEMENT_URL);
                            },
                        ),
                        const TextSpan(text: ' 和 '),
                        TextSpan(
                          text: '隐私政策',
                          style: const TextStyle(color: Colors.blue),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              _launchUrl(Config.PRIVACY_AGREEMENT_URL);
                            },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            ElevatedButton(
              child: const Text(
                '登录',
              ),
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
                        AppServer.passwordLogin(phoneNum, codeOrPwd,
                          (userId, token, isNewUser) {
                          _handleLoginSuccess(userId, token);
                        }, (msg) {
                          Fluttertoast.showToast(msg: "登录失败: $msg");
                        });
                      } else {
                        AppServer.login(phoneNum, codeOrPwd,
                            (userId, token, isNewUser) {
                          _handleLoginSuccess(userId, token);
                        }, (msg) {
                          Fluttertoast.showToast(msg: "登录失败: $msg");
                        });
                      }
                    },
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
      value.commit();
    });
  }
}
