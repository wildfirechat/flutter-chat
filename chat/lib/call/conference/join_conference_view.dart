import 'package:flutter/material.dart';
import 'package:avenginekit/engine/avenginekit.dart';
import 'package:avenginekit/engine/video_profile.dart';
import 'package:chat/app_server.dart';
import 'package:chat/l10n/app_localizations.dart';

/// 加入会议页面
class JoinConferenceView extends StatefulWidget {
  final String? initialConferenceId;

  const JoinConferenceView({Key? key, this.initialConferenceId}) : super(key: key);

  @override
  State<JoinConferenceView> createState() => _JoinConferenceViewState();
}

class _JoinConferenceViewState extends State<JoinConferenceView> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _conferenceInfo;

  @override
  void initState() {
    super.initState();
    if (widget.initialConferenceId != null) {
      _idController.text = widget.initialConferenceId!;
    }
  }

  void _queryInfo() {
    if (_idController.text.isEmpty) return;
    setState(() => _loading = true);
    AppServer.queryConferenceInfo(_idController.text, _pinController.text, (info) {
      setState(() {
        _conferenceInfo = info;
        _loading = false;
      });
    }, (error) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('查询会议失败: $error')),
      );
    });
  }

  void _joinConference() {
    if (_conferenceInfo == null) return;
    setState(() => _loading = true);
    var conferenceId = _conferenceInfo!['conferenceId'] ?? _idController.text;
    var audioOnly = _conferenceInfo!['audioOnly'] ?? false;
    var pin = _conferenceInfo!['pin'] ?? _pinController.text;
    var title = _conferenceInfo!['title'] ?? '';
    var desc = _conferenceInfo!['desc'] ?? '';
    var audience = _conferenceInfo!['audience'] ?? false;
    var advance = _conferenceInfo!['advance'] ?? false;
    var host = _conferenceInfo!['owner'] ?? _conferenceInfo!['host'] ?? '';

    var session = avEngineKit.joinConference(
      conferenceId,
      audioOnly,
      pin,
      host,
      title,
      desc,
      audience,
      advance,
      false,
      false,
      '',
      '',
    );
    setState(() => _loading = false);
    if (session != null && mounted) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('加入会议失败')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('加入会议')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _idController,
              decoration: const InputDecoration(labelText: '会议ID'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pinController,
              decoration: const InputDecoration(labelText: '会议密码'),
            ),
            const SizedBox(height: 24),
            if (_conferenceInfo != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_conferenceInfo!['title'] ?? '',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(_conferenceInfo!['desc'] ?? ''),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _joinConference,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('加入会议'),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _queryInfo,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('查询会议'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
