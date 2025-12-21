import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dynamic_icon/flutter_dynamic_icon.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    //第一次启动时设置应用badge，触发弹出是否允许通知提示，允许后可以在应用进入到后台时设置badge。
    //只有iOS平台支持，android平台不支持。如果有其他支持android平台badge，请提issue给我们添加。
    if(defaultTargetPlatform == TargetPlatform.iOS) {
      FlutterDynamicIcon.getApplicationIconBadgeNumber().then((value) {
        try {
          FlutterDynamicIcon.setApplicationIconBadgeNumber(value);
        } catch (e) {
          debugPrint("not support badge number");
        }
      });
    }

    return SafeArea(
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              const Padding(padding: EdgeInsets.only(top: 120)),
              Center(child: Image.asset('assets/images/app_icon.png', width: 180.0, height: 180.0),),
              const Padding(padding: EdgeInsets.only(top: 16)),
              const Center(child: Text("野火IM", style: TextStyle(fontSize: 24, color: Colors.black87, decoration: TextDecoration.none),),),
              Expanded(child: Container()),
              const Center(child: Text("沟通如此简单!", style: TextStyle(fontSize: 18, color: Colors.grey, decoration: TextDecoration.none),),),
              const Padding(padding: EdgeInsets.only(bottom: 120))
            ],
          ),
        ));
  }
}