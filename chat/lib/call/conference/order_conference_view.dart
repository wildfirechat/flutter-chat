import 'dart:math';

import 'package:flutter/material.dart';
import 'package:chat/app_server.dart';
import 'package:chat/widget/app_switch.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:imclient/imclient.dart';

/// 预定会议页面
class OrderConferenceView extends StatefulWidget {
  const OrderConferenceView({Key? key}) : super(key: key);

  @override
  State<OrderConferenceView> createState() => _OrderConferenceViewState();
}

class _OrderConferenceViewState extends State<OrderConferenceView> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  DateTime? _startTime;
  DateTime? _endTime;
  bool _audioOnly = false;
  bool _audience = false;
  bool _advance = false;
  bool _allowTurnOnMic = true;
  bool _enablePassword = false;
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;

  String _generatePin() {
    var rng = Random();
    var pin = '';
    for (var i = 0; i < 6; i++) {
      pin += rng.nextInt(10).toString();
    }
    return pin;
  }

  Future<void> _pickStartTime() async {
    var date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(minutes: 5)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    var time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(DateTime.now().add(const Duration(minutes: 5))),
    );
    if (time == null) return;
    setState(() {
      _startTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickEndTime() async {
    var initial = _startTime?.add(const Duration(hours: 1)) ?? DateTime.now().add(const Duration(hours: 1));
    var date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    var time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    setState(() {
      _endTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _orderConference() {
    var l10n = AppLocalizations.of(context)!;
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.conferenceInputTitle)),
      );
      return;
    }
    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.conferenceSelectStartAndEndTime)),
      );
      return;
    }
    if (_endTime!.isBefore(_startTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.conferenceTimeInvalid)),
      );
      return;
    }

    setState(() => _loading = true);

    var info = {
      'conferenceTitle': _titleController.text,
      'title': _titleController.text,
      'desc': _descController.text,
      'pin': _generatePin(),
      'password': _enablePassword ? _passwordController.text : '',
      'owner': Imclient.currentUserId,
      'startTime': _startTime!.millisecondsSinceEpoch ~/ 1000,
      'endTime': _endTime!.millisecondsSinceEpoch ~/ 1000,
      'audioOnly': _audioOnly,
      'audience': _audience,
      'advance': _advance,
      'allowSwitchMode': _allowTurnOnMic,
      'record': false,
    };

    AppServer.createConference(info, (conferenceId) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.conferenceOrdered)),
        );
        Navigator.of(context).pop();
      }
    }, (error) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.conferenceOrderFailedWithError(error))),
        );
      }
    });
  }

  String _formatTime(BuildContext context, DateTime? time) {
    if (time == null) return AppLocalizations.of(context)!.pleaseSelect;
    return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    var l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.colors.primaryBackground,
      appBar: AppBar(
        title: Text(l10n.conferenceOrder),
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
              title: Text(l10n.conferenceStartTime, style: TextStyle(color: context.colors.textPrimary)),
              trailing: Text(_formatTime(context, _startTime),
                  style: AppText.base.copyWith(color: context.colors.success)),
              onTap: _pickStartTime,
            ),
            ListTile(
              title: Text(l10n.conferenceEndTime, style: TextStyle(color: context.colors.textPrimary)),
              trailing: Text(_formatTime(context, _endTime),
                  style: AppText.base.copyWith(color: context.colors.success)),
              onTap: _pickEndTime,
            ),
            ListTile(
              title: Text(l10n.conferenceAudioOnly, style: TextStyle(color: context.colors.textPrimary)),
              trailing: AppSwitch(
                value: _audioOnly,
                onChanged: (v) => setState(() => _audioOnly = v),
              ),
            ),
            ListTile(
              title: Text(l10n.conferenceDefaultAudience, style: TextStyle(color: context.colors.textPrimary)),
              trailing: AppSwitch(
                value: _audience,
                onChanged: (v) => setState(() => _audience = v),
              ),
            ),
            ListTile(
              title: Text(l10n.conferenceAdvanced, style: TextStyle(color: context.colors.textPrimary)),
              trailing: AppSwitch(
                value: _advance,
                onChanged: (v) => setState(() => _advance = v),
              ),
            ),
            ListTile(
              title: Text(l10n.conferenceAllowTurnOnMic, style: TextStyle(color: context.colors.textPrimary)),
              trailing: AppSwitch(
                value: _allowTurnOnMic,
                onChanged: (v) => setState(() => _allowTurnOnMic = v),
              ),
            ),
            ListTile(
              title: Text(l10n.conferenceEnablePassword, style: TextStyle(color: context.colors.textPrimary)),
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
                onPressed: _loading ? null : _orderConference,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.conferenceOrderAction),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
