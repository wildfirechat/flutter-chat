import 'package:flutter/material.dart';
import 'package:flutter_dynamic_icon/flutter_dynamic_icon.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    FlutterDynamicIcon.getApplicationIconBadgeNumber().then((value) {
      try {
        FlutterDynamicIcon.setApplicationIconBadgeNumber(value);
      } catch (e) {

      }
    });
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