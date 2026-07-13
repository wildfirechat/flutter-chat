import 'dart:math';

import 'package:flutter/material.dart';
import 'package:avenginekit/engine/avenginekit.dart';
import 'package:avenginekit/engine/video_profile.dart';
import 'package:imclient/imclient.dart';
import 'package:chat/app_server.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/pc/call_window/main_avengine_kit_proxy.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/widget/app_switch.dart';

/// 创建会议页面
class CreateConferenceView extends StatefulWidget {
  const CreateConferenceView({Key? key}) : super(key: key);

  @override
  State<CreateConferenceView> createState() => _CreateConferenceViewState();
}

class _CreateConferenceViewState extends State<CreateConferenceView> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  bool _audioOnly = false;
  bool _audience = false;
  bool _advance = false;
  bool _record = false;
  bool _loading = false;

  String _generatePin() {
    var rng = Random();
    var pin = '';
    for (var i = 0; i < 6; i++) {
      pin += rng.nextInt(10).toString();
    }
    return pin;
  }

  void _createConference() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入会议标题')),
      );
      return;
    }
    setState(() {
      _loading = true;
    });

    var conferenceId = '${Imclient.currentUserId}_${DateTime.now().millisecondsSinceEpoch}';
    var pin = _generatePin();
    var info = {
      'conferenceId': conferenceId,
      'title': _titleController.text,
      'desc': _descController.text,
      'pin': pin,
      'audioOnly': _audioOnly,
      'audience': _audience,
      'advance': _advance,
      'record': _record,
      'owner': Imclient.currentUserId,
    };

    AppServer.updateConference(info, () async {
      try {
        if (isDesktopShell) {
          await MainAvEngineKitProxy.instance.startConference(
            callId: conferenceId,
            audioOnly: _audioOnly,
            pin: pin,
            host: Imclient.currentUserId,
            title: _titleController.text,
            desc: _descController.text,
            audience: _audience,
            advance: _advance,
            record: _record,
          );
        } else {
          await avEngineKit.startConference(
            conferenceId,
            _audioOnly,
            pin,
            Imclient.currentUserId,
            _titleController.text,
            _descController.text,
            _audience,
            _advance,
            _record,
            '',
            '',
          );
        }
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('创建会议失败: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }, (error) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建会议失败: $error')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('创建会议')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '会议标题'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: '会议描述'),
            ),
            const SizedBox(height: 12),
            ListTile(
              title: const Text('仅音频'),
              onTap: () => setState(() => _audioOnly = !_audioOnly),
              trailing: AppSwitch(
                value: _audioOnly,
                onChanged: (v) => setState(() => _audioOnly = v),
              ),
            ),
            ListTile(
              title: const Text('默认观众'),
              onTap: () => setState(() => _audience = !_audience),
              trailing: AppSwitch(
                value: _audience,
                onChanged: (v) => setState(() => _audience = v),
              ),
            ),
            ListTile(
              title: const Text('高级版'),
              onTap: () => setState(() => _advance = !_advance),
              trailing: AppSwitch(
                value: _advance,
                onChanged: (v) => setState(() => _advance = v),
              ),
            ),
            ListTile(
              title: const Text('录制'),
              onTap: () => setState(() => _record = !_record),
              trailing: AppSwitch(
                value: _record,
                onChanged: (v) => setState(() => _record = v),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _createConference,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('创建并加入'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
