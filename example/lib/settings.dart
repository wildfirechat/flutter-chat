import 'package:flutter/material.dart';
import 'package:flutter_imclient/flutter_imclient.dart';

class SettingsTab extends StatefulWidget {
  @override
  _SettingsTabState createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(onPressed: (){
          FlutterImclient.disconnect();
        }, child: Text('退出'),
          // color: Colors.red,
        ),
      ),
    );
  }
}
