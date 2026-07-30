import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation_info.dart';
import 'package:chat/app_theme.dart';
import 'package:chat/backup/backup_manager.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';

import 'backup_phase_localization.dart';

class PCBackupProgressScreen extends StatefulWidget {
  final List<ConversationInfo> conversations;
  final bool includeMedia;

  const PCBackupProgressScreen({
    Key? key,
    required this.conversations,
    required this.includeMedia,
  }) : super(key: key);

  @override
  _PCBackupProgressScreenState createState() => _PCBackupProgressScreenState();
}

class _PCBackupProgressScreenState extends State<PCBackupProgressScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;
  String _status = "";
  String _detail = "";
  double _progress = 0.0;
  bool _isFinished = false;
  bool _isError = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _startPCBackupFlow();
    }
  }

  void _startPCBackupFlow() {
    setState(() {
      _status = l10n.pcWaitingForConfirmation;
      _detail = l10n.pcPleaseConfirmOnPC;
    });

    BackupManager().sendBackupRequest(
      conversationInfos: widget.conversations,
      includeMedia: widget.includeMedia,
      onApproved: (ip, port) {
        if (!mounted) return;
        setState(() {
          _status = l10n.pcApproved;
          _detail = l10n.pcConnectingTo(ip, port.toString());
        });
        _startUpload(ip, port);
      },
      onRejected: () {
        if (!mounted) return;
        setState(() {
          _isFinished = true;
          _isError = true;
          _status = l10n.pcRequestRejected;
          _detail = l10n.pcBackupRejectedDesc;
        });
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _isFinished = true;
          _isError = true;
          _status = l10n.failed;
          _detail = err;
        });
      },
    );
  }

  void _startUpload(String ip, int port) {
    BackupManager().uploadBackupToPC(
      ip,
      port,
      conversationInfos: widget.conversations,
      password: Imclient.currentUserId,
      passwordHint: null,
      onProgress: (p) {
        if (!mounted) return;
        setState(() {
          _status = localizeBackupPhase(l10n, p.phase);
          if (p.total > 0) {
            _progress = p.current / p.total;
            _detail = "${p.current} / ${p.total}";
          }
        });
      },
      onSuccess: (metadata) {
        if (!mounted) return;
        setState(() {
          _isFinished = true;
          _status = l10n.pcBackupCompleted;
          _detail = l10n.pcBackupCompletedDesc;
          _progress = 1.0;
        });
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _isFinished = true;
          _isError = true;
          _status = l10n.pcBackupFailed;
          _detail = err;
        });
      },
    );
  }

  void _onClose() {
    // Navigate back to the main Backup Screen (pop 3 times: Progress -> Destination -> Picker)
    Navigator.of(context).popUntil(
        (route) => route.settings.name == null && route.isFirst == false);
    // This might be too aggressive if route names are not set.
    // Let's just pop 3 times manually or use named routes if they were set up.
    // A safer way is to pop until we are back to BackupAndRestoreScreen.
    // Since we don't have named routes, we can just pop context.
    Navigator.pop(context); // Close Progress
    Navigator.pop(context); // Close Destination
    Navigator.pop(context); // Close Picker
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(l10n.pcBackupProgressTitle),
          automaticallyImplyLeading: false),
      body: SafeArea(
        child: SizedBox.expand(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isError)
                        const Icon(Icons.error_outline,
                            size: 80, color: Colors.red)
                      else if (_isFinished)
                        const Icon(Icons.check_circle_outline,
                            size: 80, color: Colors.green)
                      else
                        const SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(strokeWidth: 6),
                        ),
                      const SizedBox(height: 32),
                      Text(
                        _status,
                        textAlign: TextAlign.center,
                        style: AppText.xl.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _detail,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 32),
                      if (!_isFinished && !_isError)
                        LinearProgressIndicator(value: _progress),
                    ],
                  ),
                ),
                if (_isFinished)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: FilledButton(
                      onPressed: _onClose,
                      // 整页唯一主行动,叠大档。
                      style: AppTheme.largeButtonStyle(),
                      child: Text(l10n.pcClose),
                    ),
                  ),
                if (!_isFinished && !_isError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextButton(
                      onPressed: () {
                        BackupManager().cancelCurrentOperation();
                        Navigator.pop(context);
                      },
                      child: Text(l10n.cancel,
                          style: TextStyle(color: context.colors.danger)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
