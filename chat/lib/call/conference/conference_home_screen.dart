import 'package:flutter/material.dart';
import 'package:chat/call/conference/create_conference_view.dart';
import 'package:chat/call/conference/join_conference_view.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/app_navigator.dart';

/// 会议入口页：创建会议 / 加入会议
class ConferenceHomeScreen extends StatelessWidget {
  const ConferenceHomeScreen({Key? key}) : super(key: key);

  void _openCreate(BuildContext context) {
    if (isDesktopShell) {
      openPage(context, const CreateConferenceView());
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CreateConferenceView()),
      );
    }
  }

  void _openJoin(BuildContext context) {
    if (isDesktopShell) {
      openPage(context, const JoinConferenceView());
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const JoinConferenceView()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('会议')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.video_call, size: 40, color: Colors.green),
                title: const Text('创建会议', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                subtitle: const Text('发起新的音视频会议'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openCreate(context),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.login, size: 40, color: Colors.blue),
                title: const Text('加入会议', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                subtitle: const Text('输入会议 ID 和密码加入'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openJoin(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
