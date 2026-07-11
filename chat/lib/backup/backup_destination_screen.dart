import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation_info.dart';
import 'package:imclient/model/pc_online_info.dart';
import 'package:chat/backup/pc_backup_progress_screen.dart';
import 'package:chat/backup/backup_and_restore_screen.dart'; // For local backup reuse logic if needed, or redirect
import 'package:chat/backup/backup_manager.dart';

import 'backup_models.dart';
import 'package:chat/theme/app_typography.dart';

class BackupDestinationScreen extends StatefulWidget {
  final List<ConversationInfo> conversations;
  final bool includeMedia;

  const BackupDestinationScreen({
    Key? key,
    required this.conversations,
    required this.includeMedia,
  }) : super(key: key);

  @override
  _BackupDestinationScreenState createState() => _BackupDestinationScreenState();
}

class _BackupDestinationScreenState extends State<BackupDestinationScreen> {
  List<PCOnlineInfo> _pcOnlineInfos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPCOnline();
  }

  Future<void> _checkPCOnline() async {
    try {
      final infos = await Imclient.getPCOnlineInfos();
      debugPrint('jyj _checkPCOnline $infos');
      if (mounted) {
        setState(() {
          _pcOnlineInfos = infos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onBackupToLocal() {
    // We can reuse the existing BackupAndRestoreScreen logic or create a dedicated progress screen.
    // Since createBackup is async and has callbacks, we can show a dialog or new screen.
    // For simplicity, let's create a temporary progress dialog here.
    _showLocalBackupProgress();
  }

  void _showLocalBackupProgress() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _LocalBackupProgressDialog(
        conversations: widget.conversations,
        includeMedia: widget.includeMedia,
      ),
    );
  }

  void _onBackupToPC() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PCBackupProgressScreen(
          conversations: widget.conversations,
          includeMedia: widget.includeMedia,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isPCOnline = _pcOnlineInfos.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Backup Destination')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _BackupOptionCard(
                  icon: Icons.phone_android,
                  title: 'Backup to Local Storage',
                  subtitle: 'Save backup files to this device.',
                  onTap: _onBackupToLocal,
                ),
                const SizedBox(height: 16),
                Opacity(
                  opacity: isPCOnline ? 1.0 : 0.5,
                  child: _BackupOptionCard(
                    icon: Icons.computer,
                    title: isPCOnline ? 'Backup to PC' : 'Backup to PC (Offline)',
                    subtitle: isPCOnline
                        ? 'PC Client is online. Click to start.'
                        : 'Please login to PC Client first.',
                    onTap: isPCOnline ? _onBackupToPC : null,
                  ),
                ),
              ],
            ),
    );
  }
}

class _BackupOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _BackupOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(icon, size: 40, color: Colors.blue),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.lg.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalBackupProgressDialog extends StatefulWidget {
  final List<ConversationInfo> conversations;
  final bool includeMedia;

  const _LocalBackupProgressDialog({
    required this.conversations,
    required this.includeMedia,
  });

  @override
  _LocalBackupProgressDialogState createState() => _LocalBackupProgressDialogState();
}

class _LocalBackupProgressDialogState extends State<_LocalBackupProgressDialog> {
  String _status = "Starting...";
  double _progress = 0.0;
  bool _finished = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startBackup();
  }

  void _startBackup() {
    BackupManager().createBackup(
      conversationInfos: widget.conversations,
      onProgress: (p) {
        if (mounted) {
          setState(() {
            _status = "${p.phase} (${p.current}/${p.total})";
            if (p.total > 0) {
              _progress = p.current / p.total;
            }
          });
        }
      },
      onSuccess: (metadata) {
        if (mounted) {
          setState(() {
            _status = "Backup Completed Successfully!";
            _progress = 1.0;
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
      title: const Text("Local Backup"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            Text("Error: $_error", style: const TextStyle(color: Colors.red))
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
            onPressed: () {
               Navigator.pop(context); // Close dialog
               Navigator.pop(context); // Close Destination Screen
               Navigator.pop(context); // Close Picker Screen (Back to List)
            },
            child: const Text("Done"),
          )
        else
          TextButton(
            onPressed: () {
              BackupManager().cancelCurrentOperation();
              Navigator.pop(context);
            },
            child: const Text("Cancel"),
          )
      ],
    );
  }
}
