
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import '../login_screen.dart';

class GeneralSettings extends StatelessWidget {
  GeneralSettings({Key? key}) : super(key: key);

  final List modelList = [
    //标题，key，是否带有section，是否居中标红
    ['隐私设置', 'privacy_settings', false, false],
    ['主题', 'theme', true, false],
    ['当前版本', 'version', true, false],
    ['反馈', 'feedback', false, false],
    ['关于野火', 'about', false, false],
    ['用户协议', 'user_agreement', true, false],
    ['隐私政策', 'privacy_policy', false, false],
    ['投诉', 'complain', true, false],
    ['诊断', 'diagnose', true, false],
    ['退出', 'quit', true, true],
  ];


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: SafeArea(
        child: ListView.builder(
          itemCount: modelList.length,
          itemBuilder: (BuildContext context, int index) {
            return _buildRow(context, index);
          },
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, int index) {
    String title = modelList[index][0];
    String key = modelList[index][1];
    bool hasSection = modelList[index][2];
    bool center = modelList[index][3];

    return GestureDetector(child: Column(children: [
      Container(
        height: hasSection?18:0,
        width:PlatformDispatcher.instance.views.first.physicalSize.width,
        color: const Color(0xffebebeb),
      ),
      Container(
        margin: const EdgeInsets.fromLTRB(15, 10, 5, 10),
        height: 36,
        child: center?Center(child: Text(title, style: const TextStyle(color: Colors.red),)):Row(children: [Expanded(child: Text(title)),],),
      ),
      Container(
        margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 0.0),
        height: 0.5,
        color: const Color(0xdbdbdbdb),
      ),
    ],),
      onTap: () {
        if(key == "quit") {
          Fluttertoast.showToast(msg: "账号将退出");

          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (Route<dynamic> route) => false,
          );
          Imclient.disconnect();
        } else {
          Fluttertoast.showToast(msg: "方法没有实现");
          print("on tap item $index");
        }
      },);
  }
}