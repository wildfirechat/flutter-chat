import 'dart:math';

import 'package:flutter/material.dart';
import 'package:avenginekit/engine/avenginekit.dart';
import 'package:imclient/imclient.dart';
import 'package:chat/app_server.dart';
import 'package:chat/pc/call_window/main_avengine_kit_proxy.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/widget/app_switch.dart';
import 'package:chat/l10n/app_localizations.dart';

/// 创建会议页面
class CreateConferenceView extends StatefulWidget {
  const CreateConferenceView({Key? key}) : super(key: key);

  @override
  State<CreateConferenceView> createState() => _CreateConferenceViewState();
}

class _CreateConferenceViewState extends State<CreateConferenceView> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  DateTime _endTime = DateTime.now().add(const Duration(hours: 1));
  bool _audioOnly = false;
  bool _audience = false;
  bool _advance = false;
  bool _record = false;
  bool _allowTurnOnMic = true;
  bool _enablePassword = false;
  bool _loading = false;

  String _generatePin() {
    var rng = Random();
    var pin = '';
    for (var i = 0; i < 6; i++) {
      pin += rng.nextInt(10).toString();
    }
    return pin;
  }

  Future<void> _pickEndTime() async {
    var date = await showDatePicker(
      context: context,
      initialDate: _endTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    var time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endTime),
    );
    if (time == null) return;
    setState(() {
      _endTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Map<String, dynamic> _buildInfo() {
    var pin = _generatePin();
    return {
      'conferenceTitle': _titleController.text,
      'title': _titleController.text,
      'desc': _descController.text,
      'pin': pin,
      'password': _enablePassword ? _passwordController.text : '',
      'audioOnly': _audioOnly,
      'audience': _audience,
      'advance': _advance,
      'record': _record,
      'allowSwitchMode': _allowTurnOnMic,
      'owner': Imclient.currentUserId,
      'startTime': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'endTime': _endTime.millisecondsSinceEpoch ~/ 1000,
    };
  }

  void _createConference({required bool join}) async {
    var l10n = AppLocalizations.of(context)!;
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.conferenceInputTitle)),
      );
      return;
    }
    if (_endTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.conferenceEndTimeInvalid)),
      );
      return;
    }
    setState(() => _loading = true);

    var info = _buildInfo();
    var pin = info['pin'] as String;

    AppServer.createConference(info, (conferenceId) async {
      if (!join) {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.conferenceCreated)),
          );
          Navigator.of(context).pop();
        }
        return;
      }

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
          // ignore: await_only_futures
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
            SnackBar(content: Text(l10n.conferenceJoinFailedWithError(e))),
          );
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }, (error) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.conferenceCreateFailedWithError(error))),
        );
      }
    });
  }

  String _formatTime(DateTime time) {
    return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    var l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.colors.primaryBackground,
      appBar: AppBar(
        title: Text(l10n.conferenceCreate),
        backgroundColor: context.colors.surface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _titleController,
              style: TextStyle(color: context.colors.textPrimary),
              decoration: InputDecoration(labelText: l10n.conferenceTitleLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              style: TextStyle(color: context.colors.textPrimary),
              decoration: InputDecoration(labelText: l10n.conferenceDescLabel),
            ),
            const SizedBox(height: 12),
            ListTile(
              title: Text(l10n.conferenceEndTime,
                  style: TextStyle(color: context.colors.textPrimary)),
              trailing: Text(_formatTime(_endTime),
                  style: AppText.base.copyWith(color: context.colors.success)),
              onTap: _pickEndTime,
            ),
            ListTile(
              title: Text(l10n.conferenceAudioOnly,
                  style: TextStyle(color: context.colors.textPrimary)),
              trailing: AppSwitch(
                value: _audioOnly,
                onChanged: (v) => setState(() => _audioOnly = v),
              ),
            ),
            ListTile(
              title: Text(l10n.conferenceDefaultAudience,
                  style: TextStyle(color: context.colors.textPrimary)),
              trailing: AppSwitch(
                value: _audience,
                onChanged: (v) => setState(() => _audience = v),
              ),
            ),
            ListTile(
              title: Text(l10n.conferenceAdvanced,
                  style: TextStyle(color: context.colors.textPrimary)),
              trailing: AppSwitch(
                value: _advance,
                onChanged: (v) => setState(() => _advance = v),
              ),
            ),
            ListTile(
              title: Text(l10n.conferenceRecord,
                  style: TextStyle(color: context.colors.textPrimary)),
              trailing: AppSwitch(
                value: _record,
                onChanged: (v) => setState(() => _record = v),
              ),
            ),
            ListTile(
              title: Text(l10n.conferenceAllowTurnOnMic,
                  style: TextStyle(color: context.colors.textPrimary)),
              trailing: AppSwitch(
                value: _allowTurnOnMic,
                onChanged: (v) => setState(() => _allowTurnOnMic = v),
              ),
            ),
            ListTile(
              title: Text(l10n.conferenceEnablePassword,
                  style: TextStyle(color: context.colors.textPrimary)),
              trailing: AppSwitch(
                value: _enablePassword,
                onChanged: (v) => setState(() => _enablePassword = v),
              ),
            ),
            if (_enablePassword)
              TextField(
                controller: _passwordController,
                style: TextStyle(color: context.colors.textPrimary),
                decoration: InputDecoration(labelText: l10n.conferencePassword),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _loading ? null : () => _createConference(join: true),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.conferenceCreateAndJoin),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed:
                    _loading ? null : () => _createConference(join: false),
                child: Text(l10n.conferenceOnlyCreate),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
