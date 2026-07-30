import 'package:chat/backup/pick_conversation_screen.dart';
import 'package:chat/backup/pc_restore_progress_screen.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:intl/intl.dart';
import 'package:chat/app_theme.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/theme/app_colors.dart';

import 'backup_manager.dart';
import 'backup_models.dart';
import 'backup_phase_localization.dart';

class BackupAndRestoreScreen extends StatefulWidget {
  const BackupAndRestoreScreen({Key? key}) : super(key: key);

  @override
  _BackupAndRestoreScreenState createState() => _BackupAndRestoreScreenState();
}

class _BackupAndRestoreScreenState extends State<BackupAndRestoreScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;
  List<BackupMetadata> _backups = [];
  bool _isLoading = true;
  bool _isBackingUp = false;
  bool _isRestoring = false;
  BackupProgress? _progress;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final backups = await BackupManager().getBackupList();
      setState(() {
        _backups = backups;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Fluttertoast.showToast(msg: l10n.pcLoadBackupsFailed('$e'));
    }
  }

  Future<void> _deleteBackup(BackupMetadata backup) async {
    if (backup.backupDir == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteBackup),
        content: Text(l10n.deleteBackupConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await BackupManager().deleteBackup(backup.backupDir!);
      setState(() {
        _backups.remove(backup);
      });
      Fluttertoast.showToast(msg: l10n.pcBackupDeleted);
    } catch (e) {
      Fluttertoast.showToast(msg: l10n.pcDeleteBackupFailed('$e'));
    }
  }

  void _cancelOperation() {
    BackupManager().cancelCurrentOperation();
  }

  Future<void> _createNewBackup() async {
    // Navigate to pick conversation screen
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PickConversationScreen()),
    ).then((_) => _loadBackups()); // Reload backups when returning
  }

  void _restoreFromPC() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PCRestoreProgressScreen()),
    ).then((_) => _loadBackups());
  }

  Future<void> _restoreBackup(BackupMetadata backup) async {
    if (_isBackingUp || _isRestoring) return;

    if (backup.backupDir == null) return;

    String? password;
    if (backup.encryption != null && backup.encryption!.enabled) {
      password = Imclient.currentUserId;
    }

    if (!mounted) return;

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.restoreBackup),
        content: Text(l10n.restoreBackupConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.restoreBackup),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isRestoring = true;
      _progress = BackupProgress(
          total: 0, current: 0, phase: l10n.restoringConversations);
    });

    await BackupManager().restoreBackup(
      backup.backupDir!,
      password: password,
      onProgress: (progress) {
        setState(() {
          _progress = progress;
        });
      },
      onSuccess: (msgCount, mediaCount) {
        setState(() {
          _isRestoring = false;
          _progress = null;
        });
        Fluttertoast.showToast(
            msg: l10n.restoreCompleted('$msgCount', '$mediaCount'));
      },
      onError: (error) {
        setState(() {
          _isRestoring = false;
          _progress = null;
        });
        Fluttertoast.showToast(msg: l10n.pcRestoreFailed(error.toString()));
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

  Widget _buildProgressOverlay() {
    if (!_isBackingUp && !_isRestoring) return const SizedBox.shrink();

    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isBackingUp ? l10n.pcBackupMobileData : l10n.pcRestoreBackup,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _progress != null && _progress!.total > 0
                      ? _progress!.current / _progress!.total
                      : null,
                ),
                const SizedBox(height: 16),
                Text(_progress != null
                    ? localizeBackupPhase(l10n, _progress!.phase)
                    : l10n.pcPreparing),
                if (_progress != null)
                  Text("${_progress!.current} / ${_progress!.total}"),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _cancelOperation,
                  style: FilledButton.styleFrom(
                      backgroundColor: context.colors.danger),
                  child: Text(l10n.cancel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(l10n.backup_and_restore),
          ),
          body: Column(
            children: [
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _backups.isEmpty
                        ? Center(child: Text(l10n.noBackupsFound))
                        : ListView.separated(
                            itemCount: _backups.length,
                            separatorBuilder: (ctx, index) => const Divider(),
                            itemBuilder: (context, index) {
                              final backup = _backups[index];
                              return ListTile(
                                leading: const Icon(Icons.backup),
                                title: Text(_formatDate(backup.backupTime)),
                                subtitle: Text(l10n.backupListSubtitle(
                                  "${backup.statistics?.totalConversations ?? 0}",
                                  "${backup.statistics?.totalMessages ?? 0}",
                                )),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.grey),
                                      onPressed: (_isBackingUp || _isRestoring)
                                          ? null
                                          : () => _deleteBackup(backup),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton(
                                      onPressed: (_isBackingUp || _isRestoring)
                                          ? null
                                          : () => _restoreBackup(backup),
                                      child: Text(l10n.restoreBackup),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // 通栏主行动 + 通栏次要,叠大档。
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: (_isBackingUp || _isRestoring)
                            ? null
                            : _createNewBackup,
                        style: AppTheme.largeButtonStyle(),
                        child: Text(l10n.createNewBackup),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: (_isBackingUp || _isRestoring)
                            ? null
                            : _restoreFromPC,
                        style: AppTheme.largeButtonStyle(),
                        child: Text(l10n.restoreFromPC),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _buildProgressOverlay(),
      ],
    );
  }
}
