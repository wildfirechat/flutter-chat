import 'package:chat/backup/pick_conversation_screen.dart';
import 'package:chat/backup/pc_restore_progress_screen.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
// import 'package:chat/l10n/app_localizations.dart';

import 'backup_manager.dart';
import 'backup_models.dart';

class BackupAndRestoreScreen extends StatefulWidget {
  const BackupAndRestoreScreen({Key? key}) : super(key: key);

  @override
  _BackupAndRestoreScreenState createState() => _BackupAndRestoreScreenState();
}

class _BackupAndRestoreScreenState extends State<BackupAndRestoreScreen> {
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
      Fluttertoast.showToast(msg: "Failed to load backups: $e");
    }
  }

  Future<void> _deleteBackup(BackupMetadata backup) async {
    if (backup.backupDir == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Backup"),
        content: const Text("Are you sure you want to delete this backup?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
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
      Fluttertoast.showToast(msg: "Backup deleted");
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to delete: $e");
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
      final passwordController = TextEditingController();
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Enter Password"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (backup.encryption!.hint != null &&
                  backup.encryption!.hint!.isNotEmpty)
                Text("Hint: ${backup.encryption!.hint}"),
              const SizedBox(height: 8),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Restore"),
            ),
          ],
        ),
      );

      if (proceed != true) return;
      password = passwordController.text;
    }

    if (!mounted) return;

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Restore Backup"),
        content: const Text(
            "Restoring will merge messages from the backup into your current chat history. Existing messages will NOT be overwritten unless they are duplicates.\n\nDo you want to continue?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Restore"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isRestoring = true;
      _progress =
          BackupProgress(total: 0, current: 0, phase: "Starting restore...");
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
            msg: "Restored $msgCount messages and $mediaCount media files");
      },
      onError: (error) {
        setState(() {
          _isRestoring = false;
          _progress = null;
        });
        Fluttertoast.showToast(msg: "Restore failed: $error");
      },
    );
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return "Unknown";
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
                  _isBackingUp ? "Backing up..." : "Restoring...",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _progress != null && _progress!.total > 0
                      ? _progress!.current / _progress!.total
                      : null,
                ),
                const SizedBox(height: 16),
                Text(_progress?.phase ?? "Processing..."),
                if (_progress != null)
                  Text("${_progress!.current} / ${_progress!.total}"),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _cancelOperation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Cancel"),
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
            title: const Text("Backup & Restore"),
          ),
          body: Column(
            children: [
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _backups.isEmpty
                        ? const Center(child: Text("No backups found"))
                        : ListView.separated(
                            itemCount: _backups.length,
                            separatorBuilder: (ctx, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final backup = _backups[index];
                              return ListTile(
                                leading: const Icon(Icons.backup),
                                title: Text(_formatDate(backup.backupTime)),
                                subtitle: Text(
                                    "${backup.statistics?.totalConversations ?? 0} conversations, ${backup.statistics?.totalMessages ?? 0} messages"),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.grey),
                                        onPressed: (_isBackingUp || _isRestoring)
                                            ? null
                                            : () => _deleteBackup(backup),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: (_isBackingUp || _isRestoring)
                                            ? null
                                            : () => _restoreBackup(backup),
                                        child: const Text("Restore"),
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
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_isBackingUp || _isRestoring) ? null : _createNewBackup,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text("Create New Backup"),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: (_isBackingUp || _isRestoring) ? null : _restoreFromPC,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text("Restore from PC"),
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
