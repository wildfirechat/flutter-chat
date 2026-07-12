import 'dart:async';

import 'package:chat/backup/backup_manager.dart';
import 'package:chat/backup/backup_models.dart';
import 'package:chat/backup/backup_phase_localization.dart';
import 'package:chat/backup/pc_backup_server.dart';
import 'package:chat/backup/pick_conversation_screen.dart';
import 'package:chat/pc/widgets/pc_page_header.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation_info.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class PcBackupRestorePage extends StatefulWidget {
  const PcBackupRestorePage({super.key});

  @override
  State<PcBackupRestorePage> createState() => _PcBackupRestorePageState();
}

class _PcBackupRestorePageState extends State<PcBackupRestorePage> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;
  List<BackupMetadata> _backups = [];
  bool _isLoading = true;
  StreamSubscription? _backupCompletedSubscription;

  @override
  void initState() {
    super.initState();
    _loadBackups();
    _backupCompletedSubscription = PcBackupServer().backupCompleted.listen((_) {
      if (mounted) _loadBackups();
    });
  }

  @override
  void dispose() {
    _backupCompletedSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadBackups() async {
    setState(() => _isLoading = true);
    try {
      final backups = await BackupManager().getBackupListForPC();
      setState(() {
        _backups = backups;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      Fluttertoast.showToast(msg: l10n.pcLoadBackupsFailed(e.toString()));
    }
  }

  Future<void> _openBackupFolder() async {
    try {
      final dir = await BackupManager().getPCBackupReceivedDirectory();
      final uri = Uri.directory(dir);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        Fluttertoast.showToast(msg: l10n.pcCannotOpenFolder);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: l10n.pcOpenFolderFailed(e.toString()));
    }
  }

  void _backupLocalData() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PickConversationScreen(
          onSelected: (conversations, includeMedia) {
            _showLocalBackupProgress(conversations);
          },
        ),
      ),
    );
  }

  void _showMobileBackupHint() {
    _showMobileHint(l10n.pcBackupMobileDataHint);
  }

  void _showMobileRestoreHint() {
    _showMobileHint(l10n.pcRestoreToMobileHint);
  }

  void _showMobileHint(String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.pcMobileOperationHintTitle),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  void _showLocalBackupProgress(List<ConversationInfo> selected) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _LocalBackupProgressDialog(
        conversations: selected,
      ),
    ).then((_) => _loadBackups());
  }

  void _showLocalRestoreProgress(String backupDir) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _LocalRestoreProgressDialog(backupDir: backupDir),
    );
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
      setState(() => _backups.remove(backup));
      Fluttertoast.showToast(msg: l10n.pcBackupDeleted);
    } catch (e) {
      Fluttertoast.showToast(msg: l10n.pcDeleteBackupFailed(e.toString()));
    }
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
    return Scaffold(
      backgroundColor: context.colors.chatBgDesktop,
      appBar: PcPageHeader(
        title: AppLocalizations.of(context)!.backup_and_restore,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle(l10n.pcBackupMobileInteraction),
                _buildCard([
                  _buildClickableRow(
                    l10n.pcBackupMobileData,
                    l10n.pcBackupMobileDataDesc,
                    Icons.phone_iphone,
                    _showMobileBackupHint,
                  ),
                  const Divider(height: 0.5),
                  _buildClickableRow(
                    l10n.pcRestoreToMobile,
                    l10n.pcRestoreToMobileDesc,
                    Icons.mobile_friendly,
                    _showMobileRestoreHint,
                  ),
                ]),
                const SizedBox(height: 20),
                _buildSectionTitle(l10n.pcBackupLocalData),
                _buildCard([
                  _buildClickableRow(
                    l10n.pcBackupLocalData,
                    l10n.pcBackupLocalDataDesc,
                    Icons.backup,
                    _backupLocalData,
                  ),
                  const Divider(height: 0.5),
                  _buildClickableRow(
                    l10n.pcOpenBackupFolder,
                    l10n.pcOpenBackupFolderDesc,
                    Icons.folder_open,
                    _openBackupFolder,
                  ),
                ]),
                const SizedBox(height: 20),
                _buildSectionTitle(l10n.pcLocalBackup),
                _buildCard([
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_backups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: Text(l10n.pcNoBackups)),
                    )
                  else
                    ..._backups.asMap().entries.map((entry) {
                      final index = entry.key;
                      final backup = entry.value;
                      return Column(
                        children: [
                          if (index > 0) const Divider(height: 0.5),
                          _buildBackupRow(backup),
                        ],
                      );
                    }),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: AppText.xs.copyWith(fontWeight: FontWeight.w600, color: context.colors.textSecondary),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.hairline, width: 0.5),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildClickableRow(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 20, color: context.colors.iconSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.base.copyWith(fontWeight: FontWeight.w500, color: context.colors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: AppText.xs.copyWith(color: context.colors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.colors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupRow(BackupMetadata backup) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                if (backup.backupDir != null) {
                  _showLocalRestoreProgress(backup.backupDir!);
                }
              },
              child: Row(
                children: [
                  Icon(Icons.backup, size: 20, color: context.colors.iconSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_formatDate(backup.backupTime), style: AppText.base.copyWith(fontWeight: FontWeight.w500, color: context.colors.textPrimary)),
                        const SizedBox(height: 4),
                        Text(
                          l10n.backupListSubtitle(
                            '${backup.statistics?.totalConversations ?? 0}',
                            '${backup.statistics?.totalMessages ?? 0}',
                          ),
                          style: AppText.xs.copyWith(color: context.colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.restore, color: Colors.blue),
                onPressed: () {
                  if (backup.backupDir != null) {
                    _showLocalRestoreProgress(backup.backupDir!);
                  }
                },
              ),
              IconButton(
                icon: Icon(Icons.delete, color: context.colors.danger),
                onPressed: () => _deleteBackup(backup),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LocalBackupProgressDialog extends StatefulWidget {
  final List<ConversationInfo> conversations;

  const _LocalBackupProgressDialog({required this.conversations});

  @override
  State<_LocalBackupProgressDialog> createState() => _LocalBackupProgressDialogState();
}

class _LocalBackupProgressDialogState extends State<_LocalBackupProgressDialog> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;
  String _status = '';
  double _progress = 0;
  bool _finished = false;
  String? _error;
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
      _status = l10n.pcPreparing;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startBackup();
      });
    }
  }

  void _startBackup() {
    BackupManager().createBackup(
      conversationInfos: widget.conversations,
      password: Imclient.currentUserId,
      passwordHint: null,
      targetDirectoryGetter: BackupManager().getPCBackupReceivedDirectory,
      appType: BACKUP_APP_TYPE_PC,
      onProgress: (p) {
        if (mounted) {
          setState(() {
            _status = '${localizeBackupPhase(l10n, p.phase)} (${p.current}/${p.total})';
            if (p.total > 0) _progress = p.current / p.total;
          });
        }
      },
      onSuccess: (_) {
        if (mounted) {
          setState(() {
            _status = l10n.pcBackupCompleted;
            _progress = 1;
            _finished = true;
          });
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _error = err;
            _finished = true;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(l10n.pcLocalBackup),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            Text(l10n.backupFailed(_error!), style: const TextStyle(color: Colors.red))
          else ...[
            Text(_status),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: _progress),
          ],
        ],
      ),
      actions: [
        if (_finished)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.done),
          )
        else
          TextButton(
            onPressed: () {
              BackupManager().cancelCurrentOperation();
              Navigator.pop(context);
            },
            child: Text(l10n.cancel),
          ),
      ],
    );
  }
}

class _LocalRestoreProgressDialog extends StatefulWidget {
  final String backupDir;

  const _LocalRestoreProgressDialog({required this.backupDir});

  @override
  State<_LocalRestoreProgressDialog> createState() => _LocalRestoreProgressDialogState();
}

class _LocalRestoreProgressDialogState extends State<_LocalRestoreProgressDialog> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;
  String _status = '';
  double _progress = 0;
  bool _finished = false;
  String? _error;
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
      _status = l10n.restoringConversations;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startRestore();
      });
    }
  }

  void _startRestore() {
    BackupManager().restoreBackup(
      widget.backupDir,
      password: Imclient.currentUserId,
      onProgress: (p) {
        if (mounted) {
          setState(() {
            _status = '${localizeBackupPhase(l10n, p.phase)} (${p.current}/${p.total})';
            if (p.total > 0) _progress = p.current / p.total;
          });
        }
      },
      onSuccess: (msgCount, mediaCount) {
        if (mounted) {
          setState(() {
            _status = l10n.pcRestoreCompleted('$msgCount');
            _progress = 1;
            _finished = true;
          });
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _error = err;
            _finished = true;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(l10n.pcRestoreBackup),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            Text(l10n.backupFailed(_error!), style: const TextStyle(color: Colors.red))
          else ...[
            Text(_status),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: _progress),
          ],
        ],
      ),
      actions: [
        if (_finished)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.done),
          )
        else
          TextButton(
            onPressed: () {
              BackupManager().cancelCurrentOperation();
              Navigator.pop(context);
            },
            child: Text(l10n.cancel),
          ),
      ],
    );
  }
}
