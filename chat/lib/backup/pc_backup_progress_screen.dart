import 'package:flutter/material.dart';
import 'package:imclient/model/conversation_info.dart';
import 'package:chat/backup/backup_manager.dart';
import 'package:chat/backup/backup_models.dart';
import 'package:chat/theme/app_typography.dart';

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
  String _status = "Initializing...";
  String _detail = "Waiting for PC response...";
  double _progress = 0.0;
  bool _isFinished = false;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _startPCBackupFlow();
  }

  void _startPCBackupFlow() {
    setState(() {
      _status = "Waiting for PC confirmation...";
      _detail = "Please confirm the backup request on your PC client.";
    });

    BackupManager().sendBackupRequest(
      conversationInfos: widget.conversations,
      includeMedia: widget.includeMedia,
      onApproved: (ip, port) {
        if (!mounted) return;
        setState(() {
          _status = "Approved! Connecting...";
          _detail = "Connecting to $ip:$port";
        });
        _startUpload(ip, port);
      },
      onRejected: () {
        if (!mounted) return;
        setState(() {
          _isFinished = true;
          _isError = true;
          _status = "Request Rejected";
          _detail = "The backup request was rejected by the PC client.";
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

  void _startUpload(String ip, int port) {
    BackupManager().uploadBackupToPC(
      ip,
      port,
      conversationInfos: widget.conversations,
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
      onSuccess: (metadata) {
        if (!mounted) return;
        setState(() {
          _isFinished = true;
          _status = "Backup Completed!";
          _detail = "Your data has been successfully backed up to PC.";
          _progress = 1.0;
        });
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _isFinished = true;
          _isError = true;
          _status = "Backup Failed";
          _detail = err;
        });
      },
    );
  }

  void _onClose() {
    // Navigate back to the main Backup Screen (pop 3 times: Progress -> Destination -> Picker)
    Navigator.of(context).popUntil((route) => route.settings.name == null && route.isFirst == false);
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
      appBar: AppBar(title: const Text('PC Backup Progress'), automaticallyImplyLeading: false),
      body: Padding(
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
                child: ElevatedButton(
                  onPressed: _onClose,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12)),
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
    );
  }
}
