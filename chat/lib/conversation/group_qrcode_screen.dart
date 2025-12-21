import 'package:flutter/material.dart';
import 'package:imclient/model/group_info.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/config.dart';

class GroupQRCodeScreen extends StatelessWidget {
  final GroupInfo groupInfo;

  const GroupQRCodeScreen({super.key, required this.groupInfo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('群二维码'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Portrait(groupInfo.portrait ?? Config.defaultGroupPortrait, Config.defaultGroupPortrait, width: 80, height: 80),
            const SizedBox(height: 16),
            Text(groupInfo.name ?? 'Group Name', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            // Placeholder for QR Code
            Container(
              width: 200,
              height: 200,
              color: Colors.grey[300],
              child: const Center(child: Text('QR Code Placeholder')),
            ),
            const SizedBox(height: 16),
            const Text('扫一扫二维码，加入群聊'),
          ],
        ),
      ),
    );
  }
}
