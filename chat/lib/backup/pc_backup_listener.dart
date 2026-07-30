import 'dart:async';

import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/notification/backup_request_notification_content.dart';
import 'package:imclient/message/notification/backup_response_notification_content.dart';
import 'package:imclient/message/notification/notification_message_content.dart';
import 'package:imclient/message/notification/restore_request_notification_content.dart';
import 'package:imclient/message/notification/restore_response_notification_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:chat/l10n/app_localizations.dart';

import 'pc_backup_server.dart';

class PcBackupListener extends StatefulWidget {
  final Widget child;

  const PcBackupListener({super.key, required this.child});

  @override
  State<PcBackupListener> createState() => _PcBackupListenerState();
}

class _PcBackupListenerState extends State<PcBackupListener> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;
  StreamSubscription? _msgSubscription;
  bool _isProcessingBackup = false;
  bool _isProcessingRestore = false;
  bool _showBackupProgress = false;
  int _receivedFileCount = 0;
  String? _currentFileName;
  String? _backupPath;

  @override
  void initState() {
    super.initState();
    _msgSubscription = Imclient.IMEventBus.on<ReceiveMessagesEvent>()
        .listen(_onReceiveMessage);
  }

  @override
  void dispose() {
    _msgSubscription?.cancel();
    PcBackupServer().stopServer();
    super.dispose();
  }

  void _onReceiveMessage(ReceiveMessagesEvent event) {
    if (!mounted) return;
    for (final msg in event.messages) {
      final content = msg.content;
      if (content is BackupRequestNotificationContent) {
        if (!_isFromCurrentUser(msg)) continue;
        _handleIfFresh(msg, () => _handleBackupRequest(msg, content));
      } else if (content is RestoreRequestNotificationContent) {
        if (!_isFromCurrentUser(msg)) continue;
        _handleIfFresh(msg, () => _handleRestoreRequest(msg, content));
      }
    }
  }

  /// 备份/恢复请求的有效期为 10 秒,超过直接忽略(如离线同步到的旧请求,
  /// 不应再弹窗打扰用户)。本地时钟可能不准,用 SDK 的 serverDeltaTime
  /// 把本地时间粗略校正为服务器时间再判断。
  Future<void> _handleIfFresh(Message msg, void Function() handle) async {
    try {
      final delta = await Imclient.serverDeltaTime;
      final serverNow = DateTime.now().millisecondsSinceEpoch + delta;
      if (serverNow - msg.serverTime > 10 * 1000) return;
    } catch (_) {
      // serverDeltaTime 获取失败时退化为本地时间判断
      if (DateTime.now().millisecondsSinceEpoch - msg.serverTime > 10 * 1000) {
        return;
      }
    }
    if (!mounted) return;
    handle();
  }

  bool _isFromCurrentUser(Message msg) {
    final currentUserId = Imclient.currentUserId;
    return currentUserId.isNotEmpty && msg.fromUser == currentUserId;
  }

  void _handleBackupRequest(
      Message msg, BackupRequestNotificationContent content) {
    if (_isProcessingBackup || _isProcessingRestore) return;
    _isProcessingBackup = true;

    final includeMediaText =
        content.includeMedia ? l10n.pcIncludeMedia : l10n.pcExcludeMedia;
    final message = l10n.pcBackupRequestContent(
      content.conversationCount.toString(),
      content.messageCount.toString(),
      includeMediaText,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.pcBackupRequestTitle),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _rejectBackupRequest(msg);
              _isProcessingBackup = false;
            },
            child: Text(l10n.reject),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _approveBackupRequest(msg);
            },
            child: Text(l10n.pcStartBackup),
          ),
        ],
      ),
    );
  }

  void _rejectBackupRequest(Message msg) {
    _sendResponse(msg, BackupResponseNotificationContent()..approved = false);
  }

  void _approveBackupRequest(Message msg) async {
    try {
      PcBackupServer()
        ..onBackupStart = (path) {
          if (mounted) {
            setState(() {
              _showBackupProgress = true;
              _backupPath = path;
              _receivedFileCount = 0;
              _currentFileName = l10n.pcPreparing;
            });
          }
        }
        ..onBackupProgress = (progress) {
          if (mounted) {
            setState(() {
              _receivedFileCount = progress.currentFile;
              _currentFileName = progress.currentFileName;
              _backupPath = progress.backupPath;
            });
          }
        }
        ..onBackupComplete = (count, path) {
          if (mounted) {
            setState(() {
              _showBackupProgress = false;
            });
            _showNotification(l10n.pcBackupReceivedTitle,
                l10n.pcBackupReceivedContent(count.toString(), path));
          }
          _isProcessingBackup = false;
        }
        ..onError = (error) {
          if (mounted) {
            setState(() {
              _showBackupProgress = false;
            });
            _showNotification(l10n.pcBackupFailed, error);
          }
          _isProcessingBackup = false;
        };

      final serverInfo = await PcBackupServer().startBackupServer();
      final response = BackupResponseNotificationContent()
        ..approved = true
        ..serverIP = serverInfo['ip']
        ..serverPort = serverInfo['port'];
      _sendResponse(msg, response);
    } catch (e) {
      _showNotification(
          l10n.failed, l10n.pcStartBackupServerFailed(e.toString()));
      _isProcessingBackup = false;
    }
  }

  void _handleRestoreRequest(
      Message msg, RestoreRequestNotificationContent content) {
    if (_isProcessingBackup || _isProcessingRestore) return;
    _isProcessingRestore = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.pcRestoreRequestTitle),
        content: Text(l10n.pcRestoreRequestContent),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _rejectRestoreRequest(msg);
              _isProcessingRestore = false;
            },
            child: Text(l10n.reject),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _approveRestoreRequest(msg);
            },
            child: Text(l10n.pcAllow),
          ),
        ],
      ),
    );
  }

  void _rejectRestoreRequest(Message msg) {
    _sendResponse(msg, RestoreResponseNotificationContent()..approved = false);
  }

  void _approveRestoreRequest(Message msg) async {
    try {
      final serverInfo = await PcBackupServer().startRestoreServer();
      final response = RestoreResponseNotificationContent()
        ..approved = true
        ..serverIP = serverInfo['ip']
        ..serverPort = serverInfo['port'];
      _sendResponse(msg, response);
      _showNotification(l10n.pcRestoreRequestTitle, l10n.pcRestoreAllowed);
    } catch (e) {
      _showNotification(
          l10n.failed, l10n.pcStartRestoreServerFailed(e.toString()));
    }
    _isProcessingRestore = false;
  }

  void _sendResponse(Message originalMsg, NotificationMessageContent response) {
    final conversation = Conversation(
      conversationType: originalMsg.conversation.conversationType,
      target: originalMsg.conversation.target,
      line: originalMsg.conversation.line,
    );
    Imclient.sendMessage(conversation, response,
        successCallback: (messageUid, timestamp) {},
        errorCallback: (errorCode) {});
  }

  void _showNotification(String title, String content) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content, style: const TextStyle()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.done),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showBackupProgress) _buildBackupProgressOverlay(),
      ],
    );
  }

  Widget _buildBackupProgressOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.pcReceivingBackup,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                _buildProgressItem(l10n.pcReceivedFiles, '$_receivedFileCount'),
                _buildProgressItem(
                    l10n.pcCurrentFile, _currentFileName ?? l10n.pcPreparing),
                _buildProgressItem(l10n.pcSaveLocation, _backupPath ?? ''),
                const SizedBox(height: 20),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 16),
                Text(
                  l10n.pcKeepWindowOpenHint,
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
