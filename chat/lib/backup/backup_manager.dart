import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data'; // Re-added import for Uint8List

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:imclient/message/notification/backup_request_notification_content.dart';
import 'package:imclient/message/notification/backup_response_notification_content.dart';
import 'package:imclient/message/notification/restore_request_notification_content.dart';
import 'package:imclient/message/notification/restore_response_notification_content.dart';
import 'package:imclient/model/conversation_info.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/message/media_message_content.dart';
import 'package:imclient/model/message_payload.dart';

import 'backup_models.dart';
import 'backup_crypto.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:chat/pc/pc_platform.dart';

const String BACKUP_VERSION = "1";
const String BACKUP_FORMAT = "directory";
const String BACKUP_MODE_MESSAGE_WITH_MEDIA = "message_with_media";
const String BACKUP_ENCRYPTION_ALGORITHM = "AES-256-CBC";
const String BACKUP_KEY_DERIVATION = "PBKDF2-SHA256";
const String BACKUP_APP_TYPE_MOBILE = "ios-chat";
const String BACKUP_APP_TYPE_PC = "pc-chat";
const String BACKUP_DIR_NAME = "backups";
const String PC_BACKUP_RECEIVED_DIR_NAME = "Backups/received";
const String METADATA_FILE_NAME = "metadata.json";
const String CONVERSATIONS_DIR_NAME = "conversations";
const String MEDIA_DIR_NAME = "media";
const String MESSAGES_FILE_NAME = "messages.json";

class BackupManager {
  static final BackupManager _instance = BackupManager._internal();

  factory BackupManager() => _instance;

  BackupManager._internal();

  bool _isCancelled = false;

  void cancelCurrentOperation() {
    _isCancelled = true;
  }

  Future<String> getBackupRootDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(path.join(appDocDir.path, BACKUP_DIR_NAME));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir.path;
  }

  Future<String> getPCBackupReceivedDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final backupDir =
        Directory(path.join(appDocDir.path, PC_BACKUP_RECEIVED_DIR_NAME));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir.path;
  }

  String get _currentAppType =>
      isDesktopShell ? BACKUP_APP_TYPE_PC : BACKUP_APP_TYPE_MOBILE;

  String _formatBackupTimestamp(DateTime dt) {
    final utc = dt.toUtc();
    return "${utc.year.toString().padLeft(4, '0')}-${utc.month.toString().padLeft(2, '0')}-${utc.day.toString().padLeft(2, '0')}T"
        "${utc.hour.toString().padLeft(2, '0')}:${utc.minute.toString().padLeft(2, '0')}:${utc.second.toString().padLeft(2, '0')}Z";
  }

  String _formatTimestampForDirectory(DateTime dt) {
    final utc = dt.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-${utc.month.toString().padLeft(2, '0')}-${utc.day.toString().padLeft(2, '0')}T'
        '${utc.hour.toString().padLeft(2, '0')}-${utc.minute.toString().padLeft(2, '0')}-${utc.second.toString().padLeft(2, '0')}';
  }

  String _calculateFileMd5(File file) {
    final bytes = file.readAsBytesSync();
    final digest = crypto.md5.convert(bytes);
    return digest.toString();
  }

  String _getConversationDirectoryName(ConversationInfo info) {
    final conv = info.conversation;
    final encodedTarget = Uri.encodeComponent(conv.target);
    return "conv_type${conv.conversationType.index}_${encodedTarget}_line${conv.line}";
  }

  Future<List<BackupMetadata>> getBackupList() async {
    try {
      final rootPath = await getBackupRootDirectory();
      final rootDir = Directory(rootPath);
      final List<BackupMetadata> backups = [];

      if (await rootDir.exists()) {
        final dirs = rootDir.listSync().whereType<Directory>();
        for (var dir in dirs) {
          final metadataFile = File(path.join(dir.path, METADATA_FILE_NAME));
          if (await metadataFile.exists()) {
            try {
              final jsonStr = await metadataFile.readAsString();
              final metadata = BackupMetadata.fromJson(jsonDecode(jsonStr));
              metadata.backupDir = dir.path;
              backups.add(metadata);
            } catch (e) {
              debugPrint("Error parsing metadata for ${dir.path}: $e");
            }
          }
        }
      }
      backups
          .sort((a, b) => (b.backupTime ?? "").compareTo(a.backupTime ?? ""));
      return backups;
    } catch (e) {
      debugPrint("Error getting backup list: $e");
      return [];
    }
  }

  Future<List<BackupMetadata>> getBackupListForPC() async {
    try {
      final rootPath = await getPCBackupReceivedDirectory();
      final rootDir = Directory(rootPath);
      final List<BackupMetadata> backups = [];

      if (await rootDir.exists()) {
        final dirs = rootDir.listSync().whereType<Directory>();
        for (var dir in dirs) {
          final metadataFile = File(path.join(dir.path, METADATA_FILE_NAME));
          if (await metadataFile.exists()) {
            try {
              final jsonStr = await metadataFile.readAsString();
              final metadata = BackupMetadata.fromJson(jsonDecode(jsonStr));
              metadata.backupDir = dir.path;
              backups.add(metadata);
            } catch (e) {
              debugPrint("Error parsing PC metadata for ${dir.path}: $e");
            }
          }
        }
      }
      backups
          .sort((a, b) => (b.backupTime ?? "").compareTo(a.backupTime ?? ""));
      return backups;
    } catch (e) {
      debugPrint("Error getting PC backup list: $e");
      return [];
    }
  }

  Future<void> deleteBackup(String backupPath) async {
    final dir = Directory(backupPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<void> createBackup({
    List<ConversationInfo>? conversationInfos, // Added argument
    String? password,
    String? passwordHint,
    Future<String> Function()? targetDirectoryGetter,
    String? appType,
    Function(BackupProgress)? onProgress,
    Function(BackupMetadata)? onSuccess,
    Function(String)? onError,
  }) async {
    _isCancelled = false;
    try {
      final startTime = DateTime.now();
      final backupId = "backup_${_formatTimestampForDirectory(startTime)}";
      final rootPath = targetDirectoryGetter != null
          ? await targetDirectoryGetter()
          : await getBackupRootDirectory();
      final backupDir = Directory(path.join(rootPath, backupId));
      await backupDir.create(recursive: true);

      final conversationsDir =
          Directory(path.join(backupDir.path, CONVERSATIONS_DIR_NAME));
      await conversationsDir.create(recursive: true);

      // Fetch conversations if not provided
      final targetConversationInfos = conversationInfos ??
          await Imclient.getConversationInfos([
            ConversationType.Single,
            ConversationType.Group,
            ConversationType.Channel
          ], [
            0
          ]);

      final totalConversations = targetConversationInfos.length;
      int totalMessages = 0;
      int mediaFileCount = 0;
      int mediaTotalSize = 0;
      int firstMessageTime = 0;
      int lastMessageTime = 0;
      List<BackupConversationInfo> backupConvInfos = [];

      final progress = BackupProgress(
          total: totalConversations, current: 0, phase: "backupConversations");
      onProgress?.call(progress);

      for (var i = 0; i < targetConversationInfos.length; i++) {
        if (_isCancelled) throw Exception("Cancelled");

        final info = targetConversationInfos[i];
        final convDirName = _getConversationDirectoryName(info);
        final convDir =
            Directory(path.join(conversationsDir.path, convDirName));
        await convDir.create(recursive: true);
        final mediaDir = Directory(path.join(convDir.path, MEDIA_DIR_NAME));
        await mediaDir.create(recursive: true);

        // Fetch messages
        List<BackupMessage> backupMessages = [];
        int msgFromIndex = 0;
        bool hasMore = true;

        // Find first/last message time for this conversation
        int convFirstTime = 0;
        int convLastTime = 0;
        int convMediaCount = 0;

        while (hasMore) {
          if (_isCancelled) throw Exception("Cancelled");

          final messages =
              await Imclient.getMessages(info.conversation, msgFromIndex, 100);
          if (messages.isEmpty) {
            hasMore = false;
            break;
          }

          for (var msg in messages) {
            // Update times
            if (convFirstTime == 0 || msg.serverTime < convFirstTime)
              convFirstTime = msg.serverTime;
            if (convLastTime == 0 || msg.serverTime > convLastTime)
              convLastTime = msg.serverTime;

            // Convert to BackupMessage
            final backupMsg = await _convertToBackupMessage(msg, mediaDir);
            backupMessages.add(backupMsg);

            if (backupMsg.mediaFileSize > 0) {
              mediaFileCount++;
              mediaTotalSize += backupMsg.mediaFileSize;
              convMediaCount++;
            }
          }

          if (messages.length < 100) {
            hasMore = false;
          } else {
            msgFromIndex = messages.last.messageId; // Fetch older messages
          }
        }

        // Build messages.json wrapper matching iOS format
        final conversationSettings = {
          'type': info.conversation.conversationType.index,
          'target': info.conversation.target,
          'line': info.conversation.line,
          'isTop': info.isTop != 0 ? 1 : 0,
          'isSilent': info.isSilent,
          'draft': info.draft ?? '',
        };
        final messagesData = {
          'version': BACKUP_VERSION,
          'conversation': conversationSettings,
          'settings': conversationSettings,
          'messages': backupMessages.map((e) => e.toJson()).toList(),
        };
        String messagesJsonStr = jsonEncode(messagesData);

        // Encrypt if needed
        if (password != null && password.isNotEmpty) {
          final encrypted =
              BackupCrypto.encryptData(utf8.encode(messagesJsonStr), password);
          messagesJsonStr = jsonEncode(encrypted);
        }

        final messagesFile = File(path.join(convDir.path, MESSAGES_FILE_NAME));
        await messagesFile.writeAsString(messagesJsonStr);

        totalMessages += backupMessages.length;
        if (firstMessageTime == 0 ||
            (convFirstTime > 0 && convFirstTime < firstMessageTime))
          firstMessageTime = convFirstTime;
        if (lastMessageTime == 0 ||
            (convLastTime > 0 && convLastTime > lastMessageTime))
          lastMessageTime = convLastTime;

        backupConvInfos.add(BackupConversationInfo(
            conversationId: convDirName,
            type: info.conversation.conversationType.index,
            target: info.conversation.target,
            line: info.conversation.line,
            directory: convDirName,
            messageCount: backupMessages.length,
            mediaCount: convMediaCount,
            firstMessageTime: convFirstTime,
            lastMessageTime: convLastTime));

        progress.current = i + 1;
        onProgress?.call(progress);
      }

      final statistics = BackupStatistics(
          totalConversations: totalConversations,
          totalMessages: totalMessages,
          mediaFileCount: mediaFileCount,
          mediaTotalSize: mediaTotalSize,
          firstMessageTime: firstMessageTime,
          lastMessageTime: lastMessageTime);

      final encryptionInfo = BackupEncryptionInfo(
        enabled: password != null && password.isNotEmpty,
        algorithm: (password != null && password.isNotEmpty)
            ? BACKUP_ENCRYPTION_ALGORITHM
            : null,
        keyDerivation: (password != null && password.isNotEmpty)
            ? BACKUP_KEY_DERIVATION
            : null,
        hint: passwordHint,
      );

      final metadata = BackupMetadata(
          version: BACKUP_VERSION,
          format: BACKUP_FORMAT,
          backupTime: _formatBackupTimestamp(startTime),
          userId: Imclient.currentUserId,
          appType: appType ?? _currentAppType,
          backupMode: BACKUP_MODE_MESSAGE_WITH_MEDIA,
          deviceName: Platform.localHostname,
          statistics: statistics,
          conversations: backupConvInfos,
          encryption: encryptionInfo,
          backupDir: backupDir.path);

      final metadataFile = File(path.join(backupDir.path, METADATA_FILE_NAME));
      await metadataFile.writeAsString(jsonEncode(metadata.toJson()));

      onSuccess?.call(metadata);
    } catch (e) {
      if (!_isCancelled) {
        debugPrint("Backup failed: $e");
      }
      onError?.call(e.toString());
    }
  }

  Future<BackupMessage> _convertToBackupMessage(
      Message msg, Directory mediaDir) async {
    final payload = BackupMessagePayload();
    final content = msg.content;
    final encoded = content.encode();

    payload.contentType = content.meta.type;
    payload.content = encoded.content ?? '';
    payload.searchableContent = encoded.searchableContent ?? '';
    payload.pushContent = encoded.pushContent ?? '';
    payload.pushData = encoded.pushData ?? '';
    payload.binaryContent = encoded.binaryContent != null
        ? base64Encode(encoded.binaryContent!)
        : '';
    payload.localContent = encoded.localContent ?? '';
    payload.mentionedType = encoded.mentionedType;
    payload.mentionedTargets = encoded.mentionedTargets;
    payload.extra = encoded.extra ?? '';
    payload.mediaType = encoded.mediaType.index;
    payload.remoteMediaUrl = encoded.remoteMediaUrl ?? '';

    int mediaFileSize = 0;

    // Media handling
    if (content is MediaMessageContent) {
      try {
        String? localPath = content.localPath;

        if (localPath != null && localPath.isNotEmpty) {
          final file = File(localPath);
          if (await file.exists()) {
            final fileSize = await file.length();
            mediaFileSize = fileSize;

            // Compute MD5 and name file as media_{md5_first16}.{ext}
            final md5 = _calculateFileMd5(file);
            final fileId = md5.length >= 16 ? md5.substring(0, 16) : md5;
            final ext = path.extension(localPath);
            final fileName = "media_$fileId$ext";
            final destFile = File(path.join(mediaDir.path, fileName));
            await file.copy(destFile.path);

            payload.localMediaInfo = BackupMediaInfo(
              fileName: fileName,
              fileId: fileId,
              relativePath: "$MEDIA_DIR_NAME/$fileName",
              fileSize: fileSize,
              md5: md5,
            );
          }
        }
      } catch (e) {
        debugPrint("Backup media error: $e");
      }
    }

    return BackupMessage(
        messageUid: msg.messageUid ?? 0,
        fromUser: msg.fromUser,
        toUsers: msg.toUsers,
        direction: msg.direction.index,
        status: msg.status.index,
        timestamp: msg.serverTime,
        localExtra: msg.localExtra ?? '',
        payload: payload,
        mediaFileSize: mediaFileSize);
  }

  /// Yield to the event loop so the UI can repaint between heavy batches.
  Future<void> _yieldToUI() => Future.delayed(Duration.zero);

  Future<void> restoreBackup(
    String backupPath, {
    String? password,
    Function(BackupProgress)? onProgress,
    Function(int, int)? onSuccess,
    Function(String)? onError,
  }) async {
    _isCancelled = false;
    try {
      final backupDir = Directory(backupPath);
      final metadataFile = File(path.join(backupDir.path, METADATA_FILE_NAME));
      if (!await metadataFile.exists())
        throw Exception("Invalid backup: missing metadata");

      final jsonStr = await metadataFile.readAsString();
      final metadata = BackupMetadata.fromJson(jsonDecode(jsonStr));

      if (metadata.encryption != null && metadata.encryption!.enabled) {
        if (password == null || password.isEmpty) {
          throw Exception("Password required");
        }
      }

      final conversations = metadata.conversations ?? [];
      final progress = BackupProgress(
          total: conversations.length,
          current: 0,
          phase: "restoringConversations");
      onProgress?.call(progress);

      int restoredMsgCount = 0;
      int restoredMediaCount = 0;

      for (var i = 0; i < conversations.length; i++) {
        if (_isCancelled) throw Exception("Cancelled");
        final convInfo = conversations[i];

        final convDir = Directory(path.join(
            backupDir.path, CONVERSATIONS_DIR_NAME, convInfo.directory));
        final messagesFile = File(path.join(convDir.path, MESSAGES_FILE_NAME));

        if (await messagesFile.exists()) {
          String msgsJsonStr = await messagesFile.readAsString();

          // Decrypt if needed
          if (metadata.encryption != null && metadata.encryption!.enabled) {
            final jsonRaw = jsonDecode(msgsJsonStr);
            final decryptedBytes = BackupCrypto.decryptData(jsonRaw, password!);
            msgsJsonStr = utf8.decode(decryptedBytes);
          }

          final msgsJson = jsonDecode(msgsJsonStr);
          final List<dynamic> msgList;
          if (msgsJson is Map<String, dynamic> &&
              msgsJson.containsKey('messages')) {
            msgList = msgsJson['messages'];
          } else if (msgsJson is List) {
            // Legacy format: messages array at root
            msgList = msgsJson;
          } else {
            throw Exception("Invalid messages.json format");
          }

          // Process messages in batches to keep the UI responsive.
          const batchSize = 100;
          for (var start = 0; start < msgList.length; start += batchSize) {
            if (_isCancelled) throw Exception("Cancelled");
            final end = start + batchSize < msgList.length
                ? start + batchSize
                : msgList.length;
            final batch = msgList.sublist(start, end);

            final messagesToInsert = <Message>[];
            for (var mJson in batch) {
              final backupMsg = BackupMessage.fromJson(mJson);
              final msg = _convertToMessage(backupMsg, convInfo, convDir);
              if (msg != null) {
                messagesToInsert.add(msg);
                if (backupMsg.mediaFileSize > 0) {
                  restoredMediaCount++;
                }
              }
            }

            if (isDesktopShell) {
              for (var msg in messagesToInsert) {
                if (_isCancelled) throw Exception("Cancelled");
                await Imclient.insertMessageEx(
                  msg.messageUid ?? 0,
                  msg.conversation,
                  msg.fromUser,
                  msg.content,
                  msg.status.index,
                  msg.serverTime,
                  localExtra: msg.localExtra ?? '',
                  toUsers: msg.toUsers,
                );
              }
            } else {
              for (var msg in messagesToInsert) {
                if (_isCancelled) throw Exception("Cancelled");
                await Imclient.insertMessage(msg.conversation, msg.fromUser,
                    msg.content, msg.status.index, msg.serverTime,
                    toUsers: msg.toUsers);
              }
            }
            restoredMsgCount += messagesToInsert.length;

            // Yield to the event loop so progress UI can repaint.
            if (end < msgList.length) {
              await _yieldToUI();
            }
          }
        }

        progress.current = i + 1;
        onProgress?.call(progress);
        await _yieldToUI();
      }

      onSuccess?.call(restoredMsgCount, restoredMediaCount);
    } catch (e) {
      if (!_isCancelled) {
        debugPrint("Restore failed: $e");
      }
      onError?.call(e.toString());
    }
  }

  Message? _convertToMessage(BackupMessage backupMsg,
      BackupConversationInfo convInfo, Directory convDir) {
    // Reconstruct Message
    final conversation = Conversation(
        conversationType: ConversationType.values[convInfo.type],
        target: convInfo.target,
        line: convInfo.line);

    // Reconstruct MessagePayload first
    final mp = MessagePayload(
        mentionedType: backupMsg.payload!.mentionedType,
        mediaType: MediaType.values[backupMsg.payload!.mediaType]);
    mp.contentType = backupMsg.payload!.contentType;
    mp.content = backupMsg.payload!.content;
    mp.searchableContent = backupMsg.payload!.searchableContent;
    mp.pushContent = backupMsg.payload!.pushContent;
    mp.pushData = backupMsg.payload!.pushData;
    if (backupMsg.payload!.binaryContent.isNotEmpty) {
      mp.binaryContent = base64Decode(backupMsg.payload!.binaryContent);
    }
    mp.localContent = backupMsg.payload!.localContent;
    mp.mentionedTargets = backupMsg.payload!.mentionedTargets;
    mp.extra = backupMsg.payload!.extra;
    mp.remoteMediaUrl = backupMsg.payload!.remoteMediaUrl;

    final content = Imclient.decodeMessageContent(mp);

    // Restore media path
    if (backupMsg.payload!.localMediaInfo != null &&
        content is MediaMessageContent) {
      final mediaInfo = backupMsg.payload!.localMediaInfo!;
      final mediaFile = File(path.join(convDir.path, mediaInfo.relativePath));
      if (mediaFile.existsSync()) {
        content.localPath = mediaFile.path;
      }
    }

    final msg = Message();
    msg.messageUid = backupMsg.messageUid;
    msg.conversation = conversation;
    msg.content = content;
    msg.fromUser = backupMsg.fromUser;
    msg.toUsers = backupMsg.toUsers;
    msg.direction = MessageDirection.values[backupMsg.direction];
    msg.status = MessageStatus.values[backupMsg.status];
    msg.serverTime = backupMsg.timestamp;
    msg.localExtra = backupMsg.localExtra;

    return msg;
  }

  // PC BACKUP & RESTORE

  Future<void> sendRestoreRequest({
    required Function(String ip, int port) onApproved,
    required Function() onRejected,
    required Function(String error) onError,
  }) async {
    _isCancelled = false;
    try {
      final content = RestoreRequestNotificationContent();

      final currentUserId = Imclient.currentUserId;
      if (currentUserId.isEmpty) throw Exception("Not logged in");

      final conversation = Conversation(
        conversationType: ConversationType.Single,
        target: currentUserId,
        line: 0,
      );

      await Imclient.sendMessage(conversation, content,
          successCallback: (messageUid, timestamp) {},
          errorCallback: (errorCode) {});

      // Setup listener
      StreamSubscription? subscription;
      Timer? timeoutTimer;

      void cleanup() {
        subscription?.cancel();
        timeoutTimer?.cancel();
      }

      // Timeout 30s
      timeoutTimer = Timer(const Duration(seconds: 30), () {
        cleanup();
        if (!_isCancelled) {
          onError("Timeout waiting for PC response");
        }
      });

      subscription =
          Imclient.IMEventBus.on<ReceiveMessagesEvent>().listen((event) {
        for (var m in event.messages) {
          if (m.content is RestoreResponseNotificationContent) {
            final currentUserId = Imclient.currentUserId;
            if (currentUserId.isEmpty || m.fromUser != currentUserId) {
              continue;
            }
            final response = m.content as RestoreResponseNotificationContent;
            cleanup();
            if (response.approved) {
              onApproved(response.serverIP ?? "", response.serverPort);
            } else {
              onRejected();
            }
            return;
          }
        }
      });
    } catch (e) {
      onError(e.toString());
    }
  }

  Future<void> sendBackupRequest({
    required List<ConversationInfo> conversationInfos,
    required bool includeMedia,
    required Function(String ip, int port) onApproved,
    required Function() onRejected,
    required Function(String error) onError,
  }) async {
    _isCancelled = false;
    try {
      int totalMessageCount = 0;
      if (!isDesktopShell) {
        for (var info in conversationInfos) {
          try {
            totalMessageCount +=
                await Imclient.getMessageCount(info.conversation);
          } catch (e) {
            debugPrint('getMessageCount failed: $e');
          }
        }
      }

      final content = BackupRequestNotificationContent();
      content.conversationCount = conversationInfos.length;
      content.messageCount = totalMessageCount; // Simplified
      content.includeMedia = includeMedia;
      content.timestamp = DateTime.now().millisecondsSinceEpoch;

      final currentUserId = Imclient.currentUserId;

      final conversation = Conversation(
        conversationType: ConversationType.Single,
        target: currentUserId,
        line: 0,
      );

      await Imclient.sendMessage(conversation, content,
          successCallback: (messageUid, timestamp) {},
          errorCallback: (errorCode) {});

      // Setup listener
      StreamSubscription? subscription;
      Timer? timeoutTimer;

      void cleanup() {
        subscription?.cancel();
        timeoutTimer?.cancel();
      }

      // Timeout 30s
      timeoutTimer = Timer(const Duration(seconds: 30), () {
        cleanup();
        if (!_isCancelled) {
          onError("Timeout waiting for PC response");
        }
      });

      subscription =
          Imclient.IMEventBus.on<ReceiveMessagesEvent>().listen((event) {
        for (var m in event.messages) {
          if (m.content is BackupResponseNotificationContent) {
            final currentUserId = Imclient.currentUserId;
            if (currentUserId.isEmpty || m.fromUser != currentUserId) {
              continue;
            }
            final response = m.content as BackupResponseNotificationContent;
            cleanup();
            if (response.approved) {
              onApproved(response.serverIP ?? "", response.serverPort);
            } else {
              onRejected();
            }
            return;
          }
        }
      });
    } catch (e) {
      onError(e.toString());
    }
  }

  Future<List<PCBackupInfo>> fetchBackupListFromPC(String ip, int port) async {
    final url = Uri.http('$ip:$port', '/restore_list');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> json = jsonDecode(utf8.decode(response.bodyBytes));
      return json.map((e) => PCBackupInfo.fromJson(e)).toList();
    } else {
      throw Exception('Failed to fetch backup list: ${response.statusCode}');
    }
  }

  Future<void> uploadBackupToPC(
    String ip,
    int port, {
    List<ConversationInfo>? conversationInfos, // Added argument
    String? password,
    String? passwordHint,
    Function(BackupProgress)? onProgress,
    Function(BackupMetadata)? onSuccess,
    Function(String)? onError,
  }) async {
    _isCancelled = false;
    String? backupPath;
    try {
      // 1. Create local backup first
      await createBackup(
        conversationInfos: conversationInfos,
        password: password,
        passwordHint: passwordHint,
        onProgress: (progress) {
          progress.phase = "creatingLocalBackup";
          onProgress?.call(progress);
        },
        onSuccess: (metadata) {
          backupPath = metadata.backupDir;
        },
        onError: (err) {
          throw Exception(err);
        },
      );

      if (backupPath == null || _isCancelled) {
        if (_isCancelled) throw Exception("Cancelled");
        throw Exception("Failed to create local backup");
      }

      final backupDir = Directory(backupPath!);
      // final rootPath = await getBackupRootDirectory();

      final files = await backupDir.list(recursive: true).toList();
      final fileList = files.whereType<File>().toList();

      final progress = BackupProgress(
          total: fileList.length, current: 0, phase: "uploadingToPC");
      onProgress?.call(progress);

      for (var i = 0; i < fileList.length; i++) {
        if (_isCancelled) throw Exception("Cancelled");

        final file = fileList[i];
        // Calculate relative path from backup directory
        var relativePath = path.relative(file.path, from: backupDir.path);
        // Normalize path separators to /
        relativePath = relativePath.replaceAll(Platform.pathSeparator, '/');

        await _uploadFileToPC(ip, port, relativePath, file);

        progress.current = i + 1;
        onProgress?.call(progress);
      }

      // Send complete
      final completeUrl = Uri.http('$ip:$port', '/backup_complete');
      // Body: [4 bytes file count (little endian)]
      final bodyBytes = ByteData(4);
      bodyBytes.setUint32(0, fileList.length, Endian.little);
      await http
          .post(completeUrl, body: bodyBytes.buffer.asUint8List(), headers: {
        "Content-Type": "application/octet-stream",
      });

      final metadataFile = File(path.join(backupPath!, METADATA_FILE_NAME));
      if (await metadataFile.exists()) {
        final jsonStr = await metadataFile.readAsString();
        final metadata = BackupMetadata.fromJson(jsonDecode(jsonStr));
        metadata.backupDir = backupPath;
        onSuccess?.call(metadata);
      } else {
        onSuccess?.call(BackupMetadata(backupDir: backupPath));
      }
    } catch (e) {
      onError?.call(e.toString());
    } finally {
      // Cleanup: delete the temporary backup
      if (backupPath != null) {
        try {
          final dir = Directory(backupPath!);
          if (await dir.exists()) {
            await dir.delete(recursive: true);
          }
        } catch (e) {
          debugPrint("Failed to cleanup temp backup: $e");
        }
      }
    }
  }

  Future<void> _uploadFileToPC(
      String ip, int port, String relativePath, File file) async {
    final url = Uri.http('$ip:$port', '/backup');
    final redirectedUrl = url;

    // Protocol: [4 bytes path len][path][8 bytes file len][file content]
    final pathBytes = utf8.encode(relativePath);
    int totalLength = 4 + pathBytes.length + 8;
    Uint8List header = Uint8List(totalLength);
    ByteData buffer = ByteData.view(header.buffer);
    int offset = 0;
    buffer.setInt32(offset, pathBytes.length, Endian.little);
    offset += 4;

    header.setRange(offset, offset + pathBytes.length, pathBytes);
    offset += pathBytes.length;

    final fileLen = await file.length();

    // 注意：file.lengthSync() 在 Dart 中返回 int (64位)
    buffer.setInt64(offset, fileLen, Endian.little);

    debugPrint("Uploading $relativePath, size: $fileLen");

    // Construct body stream
    // Using StreamGroup or manual piping might be complex.
    // Since we know the header and file content, we can try to send it as a single byte array if memory permits,
    // or better, use StreamedRequest correctly but ensure the stream is active.

    // A simpler way for small files is request.bodyBytes but that's for BaseRequest subclasses like Request.
    // For StreamedRequest, we write to sink.

    // Important: file.openRead() returns a Stream<List<int>>.
    // We can add header and then addStream.

    // If addStream hangs, it might be because the request is not being sent until sink is closed?
    // Or maybe the isolate/event loop issue?

    // Let's try sending without StreamedRequest for small files or check if we can use MultipartRequest?
    // No, protocol is raw binary.

    // Alternative: Use http.Client().send(request).
    final client = http.Client();
    try {
      final req = http.StreamedRequest('POST', redirectedUrl);

      // Don't await addStream? No, we should.
      // But we must call client.send(req) to START the request.
      // StreamedRequest logic:
      // 1. Create request.
      // 2. Call client.send(request). This returns a Future<StreamedResponse>.
      // 3. Write to request.sink.
      // 4. request.sink.close().

      req.contentLength = header.lengthInBytes + fileLen;

      // Send request future
      final responseFuture = client.send(req);

      // Write data
      req.sink.add(header.buffer.asUint8List());
      await req.sink.addStream(file.openRead());
      await req.sink.close();

      final response = await responseFuture;
      if (response.statusCode != 200) {
        throw Exception("Upload failed: ${response.statusCode}");
      }
    } finally {
      client.close();
    }
  }

  Future<void> downloadBackupFromPC(
    String ip,
    int port,
    String backupPathRemote, {
    // e.g. "backup_2023..."
    String? password,
    Function(BackupProgress)? onProgress,
    Function(int, int)? onSuccess,
    Function(String)? onError,
  }) async {
    _isCancelled = false;
    try {
      final rootPath = await getBackupRootDirectory();
      // Ensure we use the same directory structure locally
      // backupPathRemote might be absolute path from PC, we should only use the last part as dir name
      String backupDirName = path.basename(backupPathRemote);
      final localBackupDir = Directory(path.join(rootPath, backupDirName));
      if (!await localBackupDir.exists()) {
        await localBackupDir.create(recursive: true);
      }

      // 1. Download metadata
      final metadataUrl = Uri.http(
          '$ip:$port', '/restore_metadata', {'path': backupPathRemote});
      final response = await http.get(metadataUrl);
      if (response.statusCode != 200)
        throw Exception("Failed to get metadata ${response.statusCode}");

      final metadataFile =
          File(path.join(localBackupDir.path, METADATA_FILE_NAME));
      await metadataFile.writeAsBytes(response.bodyBytes);

      final metadata =
          BackupMetadata.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));

      if (metadata.conversations == null) throw Exception("Invalid metadata");

      final progress = BackupProgress(
          total: metadata.conversations!.length, phase: "downloadingFiles");
      onProgress?.call(progress);

      for (var i = 0; i < metadata.conversations!.length; i++) {
        if (_isCancelled) throw Exception("Cancelled");

        final conv = metadata.conversations![i];
        final convDirName = conv.directory;
        final convPathRemote =
            "$backupPathRemote/$CONVERSATIONS_DIR_NAME/$convDirName";

        // Download messages.json
        final messagesRemotePath = "$convPathRemote/$MESSAGES_FILE_NAME";
        final localConvDir = Directory(path.join(
            localBackupDir.path, CONVERSATIONS_DIR_NAME, convDirName));
        if (!await localConvDir.exists())
          await localConvDir.create(recursive: true);

        await _downloadFileFromPC(ip, port, messagesRemotePath,
            File(path.join(localConvDir.path, MESSAGES_FILE_NAME)));

        // Read messages.json to find media
        bool isEncrypted =
            metadata.encryption != null && metadata.encryption!.enabled;
        if (isEncrypted && (password == null || password.isEmpty)) {
          throw Exception("Password required for encrypted backup");
        }

        final msgFile = File(path.join(localConvDir.path, MESSAGES_FILE_NAME));
        final jsonStr = await msgFile.readAsString();
        Map<String, dynamic> messagesJson;
        try {
          final jsonRaw = jsonDecode(jsonStr);
          if (isEncrypted) {
            // Ensure it is encrypted format
            if (jsonRaw is Map<String, dynamic> &&
                jsonRaw.containsKey('salt')) {
              final decryptedBytes =
                  BackupCrypto.decryptData(jsonRaw, password!);
              messagesJson = jsonDecode(utf8.decode(decryptedBytes));
            } else {
              // Fallback or error? Maybe it wasn't encrypted after all?
              messagesJson = jsonRaw;
            }
          } else {
            messagesJson = jsonRaw;
          }
        } catch (e) {
          debugPrint("Failed to parse messages json for ${conv.target}: $e");
          continue;
        }

        final messagesList = (messagesJson['messages'] as List)
            .map((e) => BackupMessage.fromJson(e))
            .toList();

        final localMediaDir =
            Directory(path.join(localConvDir.path, MEDIA_DIR_NAME));
        if (!await localMediaDir.exists()) await localMediaDir.create();

        for (final msg in messagesList) {
          if (_isCancelled) throw Exception("Cancelled");
          if (msg.payload?.localMediaInfo != null) {
            final mediaInfo = msg.payload!.localMediaInfo!;

            final mediaRemotePath = "$convPathRemote/${mediaInfo.relativePath}";
            final localMediaFile =
                File(path.join(localConvDir.path, mediaInfo.relativePath));

            if (!await localMediaFile.exists()) {
              await _downloadFileFromPC(
                  ip, port, mediaRemotePath, localMediaFile);
            }
          }
        }

        progress.current = i + 1;
        onProgress?.call(progress);
      }

      // Restore
      await restoreBackup(localBackupDir.path,
          password: password,
          onProgress: onProgress,
          onSuccess: onSuccess,
          onError: (e) => throw Exception(e));
    } catch (e) {
      onError?.call(e.toString());
    }
  }

  Future<void> _downloadFileFromPC(
      String ip, int port, String remotePath, File targetFile) async {
    final url = Uri.http('$ip:$port', '/restore_file', {'path': remotePath});
    final response = await http.get(url);
    if (response.statusCode == 200) {
      await targetFile.writeAsBytes(response.bodyBytes);
    } else {
      debugPrint("Failed to download $remotePath: ${response.statusCode}");
    }
  }
}
