import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _isCodeEmpty = true;

  @override
  void initState() {
    super.initState();

    // 添加文本控制器监听
    phoneFieldController.addListener(_checkPhoneField);
    codeFieldController.addListener(_checkCodeField);
  }

  @override
  void dispose() {
    // 移除监听器
    phoneFieldController.removeListener(_checkPhoneField);
    codeFieldController.removeListener(_checkCodeField);
    _timer?.cancel();
    super.dispose();
  }

  // 检查电话号码字段
  void _checkPhoneField() {
    setState(() {
      _isPhoneEmpty = phoneFieldController.text.length != 11;
    });
  }

  // 检查验证码字段
  void _checkCodeField() {
    setState(() {
      _isCodeEmpty = codeFieldController.text.isEmpty;
    });
  }

  final phoneFieldController = TextEditingController();
  final codeFieldController = TextEditingController();

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
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 40, 8, 10),
              child: Text("手机号登录",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),),
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
                      placeholder: '请输入Super code',
                      controller: codeFieldController,
                      clearButtonMode: OverlayVisibilityMode.editing,
                      autocorrect: false,
                    ),
                  ),
                  const SizedBox(width: 8,),
                  ElevatedButton(onPressed: isSentCode ? null : () {
                    AppServer.sendCode(phoneFieldController.value.text, () {
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
                    child: isSentCode ? Text('$waitResendCount s') : const Text(
                        '发送验证码'),
                    // color: Colors.blue, disabledColor: Colors.grey,
                  ),
                ],
              ),
            ),
            ElevatedButton(
              child: const Text(
                '登录',
              ),
              // color: Colors.blue[600],
              onPressed: (_isPhoneEmpty || _isCodeEmpty) ? null : () {
                String phoneNum = phoneFieldController.value.text;
                String code = codeFieldController.value.text;
                AppServer.login(phoneNum, code, (userId, token, isNewUser) {
                  Imclient.connect(Config.IM_Host, userId, token);
                  Navigator.replace(context, oldRoute: ModalRoute.of(context)!,
                      newRoute: MaterialPageRoute(
                          builder: (context) => const HomeTabBar()));
                  SharedPreferences.getInstance().then((value) {
                    value.setString("userId", userId);
                    value.setString("token", token);
                    value.commit();
                  });
                }, (msg) {
                  Fluttertoast.showToast(msg: "登录失败");
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
