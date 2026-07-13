import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:chat/app_theme.dart';
import 'package:chat/backup/backup_manager.dart';
import 'package:chat/backup/backup_models.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';

import 'backup_phase_localization.dart';

class PCRestoreProgressScreen extends StatefulWidget {
  const PCRestoreProgressScreen({Key? key}) : super(key: key);

  @override
  _PCRestoreProgressScreenState createState() => _PCRestoreProgressScreenState();
}

class _PCRestoreProgressScreenState extends State<PCRestoreProgressScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;
  String _status = "";
  String _detail = "";
  double _progress = 0.0;
  bool _isFinished = false;
  bool _isError = false;
  bool _initialized = false;

  List<PCBackupInfo>? _backupList;
  String? _ip;
  int? _port;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _startPCRestoreFlow();
    }
  }

  void _startPCRestoreFlow() {
    setState(() {
      _status = l10n.pcWaitingForConfirmation;
      _detail = l10n.pcPleaseConfirmOnPC;
    });

    BackupManager().sendRestoreRequest(
      onApproved: (ip, port) {
        if (!mounted) return;
        setState(() {
          _ip = ip;
          _port = port;
          _status = l10n.pcApproved;
          _detail = l10n.pcConnectingTo(ip, port.toString());
        });
        _fetchBackupList(ip, port);
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

  Future<void> _fetchBackupList(String ip, int port) async {
    try {
      final list = await BackupManager().fetchBackupListFromPC(ip, port);
      if (!mounted) return;
      setState(() {
        _backupList = list;
        _status = l10n.pcSelectBackup;
        _detail = l10n.pcFoundBackups(list.length.toString());
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isFinished = true;
        _isError = true;
        _status = l10n.failed;
        _detail = e.toString();
      });
    }
  }

  void _onBackupSelected(PCBackupInfo info) {
    if (_ip == null || _port == null) return;

    _startDownload(info);
  }

  void _startDownload(PCBackupInfo info) {
    _startDownloadWithPassword(info, Imclient.currentUserId);
  }

  void _startDownloadWithPassword(PCBackupInfo info, String? password) {
    setState(() {
      _status = l10n.pcRestoringBackup;
      _detail = l10n.pcPreparing;
      _backupList = null; // Hide list
    });

    BackupManager().downloadBackupFromPC(
      _ip!,
      _port!,
      info.path ?? "",
      password: password,
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
      onSuccess: (msgCount, mediaCount) {
        if (!mounted) return;
        setState(() {
          _isFinished = true;
          _status = l10n.pcRestoreBackup;
          _detail = l10n.pcRestoredMessages(msgCount.toString());
          _progress = 1.0;
        });
      },
      onError: (err) {
        if (!mounted) return;
        if (err.contains("Password required")) {
          // Prompt for password
          _showPasswordDialog(info);
        } else {
          setState(() {
            _isFinished = true;
            _isError = true;
            _status = l10n.failed;
            _detail = err;
          });
        }
      },
    );
  }

  void _showPasswordDialog(PCBackupInfo info) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text(l10n.pcPasswordRequired),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: InputDecoration(labelText: l10n.password),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _isFinished = true;
                  _isError = true;
                  _status = l10n.cancel;
                  _detail = l10n.pcPasswordEntryCancelled;
                });
              },
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _startDownloadWithPassword(info, controller.text);
              },
              child: Text(l10n.confirm),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return l10n.pcUnknownDate;
    try {
      final date = DateTime.parse(isoString).toLocal();
      return DateFormat('yyyy-MM-dd HH:mm').format(date);
    } catch (e) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    // If list is available, show list
    if (_backupList != null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.pcSelectBackup)),
        body: ListView.separated(
          itemCount: _backupList!.length,
          separatorBuilder: (ctx, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = _backupList![index];
            return ListTile(
              leading: const Icon(Icons.backup),
              title: Text(_formatDate(item.time)),
              subtitle: Text(item.name ?? l10n.pcBackupDefaultName),
              onTap: () => _onBackupSelected(item),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pcRestoreProgressTitle), automaticallyImplyLeading: false),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isError)
                const Icon(Icons.error_outline, size: 80, color: Colors.red)
              else if (_isFinished)
                const Icon(Icons.check_circle_outline, size: 80, color: Colors.green)
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
              if (!_isFinished && !_isError) LinearProgressIndicator(value: _progress),
              if (_isFinished)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    // 整页唯一主行动,叠大档。
                    style: AppTheme.largeButtonStyle(),
                    child: Text(l10n.pcClose),
                  ),
                ),
              if (!_isFinished && !_isError)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: TextButton(
                    onPressed: () {
                      BackupManager().cancelCurrentOperation();
                      Navigator.pop(context);
                    },
                    child: Text(l10n.cancel, style: TextStyle(color: context.colors.danger)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
