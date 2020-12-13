import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_imclient/flutter_imclient.dart';
import 'package:flutter_imclient_example/app_server.dart';
import 'package:flutter_imclient_example/config.dart';
import 'package:flutter_imclient_example/home.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  LoginScreenState({this.title = '登录'});
  SharedPreferences prefs;

  String currentUser;
  String title;
  bool isSentCode = false;
  int waitResendCount = 0;
  Timer _timer;

  @override
  void initState() {
    super.initState();
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
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 40, 8, 10),
              child: Text("手机号登录", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),),
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
                  SizedBox(width: 8,),
                  RaisedButton(onPressed: isSentCode? null : (){
                    AppServer.sendCode(phoneFieldController.value.text, (){
                      Fluttertoast.showToast(msg: "验证码发送成功，请在5分钟内进行验证!");
                      final Duration duration = Duration(seconds: 1);
                      _timer = Timer.periodic(duration, (timer) {
                        setState(() {
                          waitResendCount = waitResendCount + 1;
                          if(waitResendCount >= 60) {
                            isSentCode = false;
                            _timer.cancel();
                          }
                        });

                      });

                      setState(() {
                        waitResendCount = 0;
                        isSentCode = true;
                      });
                    }, (msg) => Fluttertoast.showToast(msg: "发送验证码失败!"));
                  }, child: isSentCode ? Text('$waitResendCount s') : Text('发送验证码'), color: Colors.blue, disabledColor: Colors.grey,),
                ],
              ),
            ),
            RaisedButton(
              child: Text(
                '登录',
              ),
              color: Colors.blue[600],
              onPressed: () {
                String phoneNum = phoneFieldController.value.text;
                String code = codeFieldController.value.text;
                if(phoneNum != null && code != null) {
                  AppServer.login(
                      phoneNum, code, (userId, token, isNewUser) {
                    FlutterImclient.connect(Config.IM_Host, userId, token);
                    
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => HomeTabBar()),
                    );
                    SharedPreferences.getInstance().then((value) {
                      value.setString("userId", userId);
                      value.setString("token", token);
                      value.commit();
                    });
                  }, (msg) {
                    Fluttertoast.showToast(msg: "登录失败");
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
