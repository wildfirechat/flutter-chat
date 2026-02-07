import 'package:flutter/material.dart';
import 'package:chat/backup/backup_manager.dart';
import 'package:chat/backup/backup_models.dart';
import 'package:intl/intl.dart';

class PCRestoreProgressScreen extends StatefulWidget {
  const PCRestoreProgressScreen({Key? key}) : super(key: key);

  @override
  _PCRestoreProgressScreenState createState() => _PCRestoreProgressScreenState();
}

class _PCRestoreProgressScreenState extends State<PCRestoreProgressScreen> {
  String _status = "Initializing...";
  String _detail = "Waiting for PC response...";
  double _progress = 0.0;
  bool _isFinished = false;
  bool _isError = false;

  List<PCBackupInfo>? _backupList;
  String? _ip;
  int? _port;

  @override
  void initState() {
    super.initState();
    _startPCRestoreFlow();
  }

  void _startPCRestoreFlow() {
    setState(() {
      _status = "Waiting for PC confirmation...";
      _detail = "Please confirm the restore request on your PC client.";
    });

    BackupManager().sendRestoreRequest(
      onApproved: (ip, port) {
        if (!mounted) return;
        setState(() {
          _ip = ip;
          _port = port;
          _status = "Approved! Fetching backup list...";
          _detail = "Connecting to $ip:$port";
        });
        _fetchBackupList(ip, port);
      },
      onRejected: () {
        if (!mounted) return;
        setState(() {
          _isFinished = true;
          _isError = true;
          _status = "Request Rejected";
          _detail = "The restore request was rejected by the PC client.";
        });
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _isFinished = true;
          _isError = true;
          _status = "Error";
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
        _status = "Select Backup";
        _detail = "Found ${list.length} backups.";
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isFinished = true;
        _isError = true;
        _status = "Error fetching list";
        _detail = e.toString();
      });
    }
  }

  void _onBackupSelected(PCBackupInfo info) {
    if (_ip == null || _port == null) return;

    _startDownload(info);
  }

  void _startDownload(PCBackupInfo info) {
    _startDownloadWithPassword(info, null);
  }

  void _startDownloadWithPassword(PCBackupInfo info, String? password) {
    setState(() {
      _status = "Downloading & Restoring...";
      _detail = "Starting download...";
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
          _status = p.phase;
          if (p.total > 0) {
            _progress = p.current / p.total;
            _detail = "Progress: ${p.current}/${p.total}";
          }
        });
      },
      onSuccess: (msgCount, mediaCount) {
        if (!mounted) return;
        setState(() {
          _isFinished = true;
          _status = "Restore Completed!";
          _detail = "Restored $msgCount messages.";
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
            _status = "Restore Failed";
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
          title: const Text("Enter Password"),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(labelText: "Password"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _isFinished = true;
                  _isError = true;
                  _status = "Cancelled";
                  _detail = "Password entry cancelled";
                });
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _startDownloadWithPassword(info, controller.text);
              },
              child: const Text("OK"),
            ),
          ],
        );
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

  @override
  Widget build(BuildContext context) {
    // If list is available, show list
    if (_backupList != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Select Backup')),
        body: ListView.separated(
          itemCount: _backupList!.length,
          separatorBuilder: (ctx, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = _backupList![index];
            return ListTile(
              leading: const Icon(Icons.backup),
              title: Text(_formatDate(item.time)),
              subtitle: Text(item.name ?? "PC Backup"),
              onTap: () => _onBackupSelected(item),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('PC Restore Progress'), automaticallyImplyLeading: false),
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
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12)),
                    child: const Text('Close'),
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
                    child: const Text('Cancel', style: TextStyle(color: Colors.red)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
