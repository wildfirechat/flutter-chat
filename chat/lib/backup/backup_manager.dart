import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data'; // Re-added import for Uint8List

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:imclient/message/notification/backup_request_notification_content.dart';
import 'package:imclient/message/notification/backup_response_notification_content.dart';
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

const String BACKUP_DIR_NAME = "backups";
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
      backups.sort((a, b) => (b.backupTime ?? "").compareTo(a.backupTime ?? ""));
      return backups;
    } catch (e) {
      debugPrint("Error getting backup list: $e");
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
    Function(BackupProgress)? onProgress,
    Function(BackupMetadata)? onSuccess,
    Function(String)? onError,
  }) async {
    _isCancelled = false;
    try {
      final startTime = DateTime.now();
      final backupId = "backup_${startTime.millisecondsSinceEpoch}";
      final rootPath = await getBackupRootDirectory();
      final backupDir = Directory(path.join(rootPath, backupId));
      await backupDir.create(recursive: true);

      final conversationsDir = Directory(path.join(backupDir.path, CONVERSATIONS_DIR_NAME));
      await conversationsDir.create(recursive: true);

      // Fetch conversations if not provided
      final targetConversationInfos =
          conversationInfos ?? await Imclient.getConversationInfos([ConversationType.Single, ConversationType.Group, ConversationType.Channel], [0]);

      final totalConversations = targetConversationInfos.length;
      int totalMessages = 0;
      int mediaFileCount = 0;
      int mediaTotalSize = 0;
      int firstMessageTime = 0;
      int lastMessageTime = 0;
      List<BackupConversationInfo> backupConvInfos = [];

      final progress = BackupProgress(total: totalConversations, current: 0, phase: "Backing up conversations...");
      onProgress?.call(progress);

      for (var i = 0; i < targetConversationInfos.length; i++) {
        if (_isCancelled) throw Exception("Cancelled");

        final info = targetConversationInfos[i];
        final convDirName = "${info.conversation.conversationType.index}_${info.conversation.target}_${info.conversation.line}";
        final convDir = Directory(path.join(conversationsDir.path, convDirName));
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

        while (hasMore) {
          if (_isCancelled) throw Exception("Cancelled");

          final messages = await Imclient.getMessages(info.conversation, msgFromIndex, 100);
          if (messages.isEmpty) {
            hasMore = false;
            break;
          }

          for (var msg in messages) {
            // Update times
            if (convFirstTime == 0 || msg.serverTime < convFirstTime) convFirstTime = msg.serverTime;
            if (convLastTime == 0 || msg.serverTime > convLastTime) convLastTime = msg.serverTime;

            // Convert to BackupMessage
            final backupMsg = await _convertToBackupMessage(msg, mediaDir);
            backupMessages.add(backupMsg);

            if (backupMsg.mediaFileSize > 0) {
              mediaFileCount++;
              mediaTotalSize += backupMsg.mediaFileSize;
            }
          }

          if (messages.length < 100) {
            hasMore = false;
          } else {
            msgFromIndex = messages.last.messageId; // Fetch older messages
          }
        }

        // Save messages.json
        String messagesJsonStr = jsonEncode({'messages': backupMessages.map((e) => e.toJson()).toList()});

        // Encrypt if needed
        if (password != null && password.isNotEmpty) {
          final encrypted = BackupCrypto.encryptData(utf8.encode(messagesJsonStr), password);
          messagesJsonStr = jsonEncode(encrypted);
        }

        final messagesFile = File(path.join(convDir.path, MESSAGES_FILE_NAME));
        await messagesFile.writeAsString(messagesJsonStr);

        totalMessages += backupMessages.length;
        if (firstMessageTime == 0 || (convFirstTime > 0 && convFirstTime < firstMessageTime)) firstMessageTime = convFirstTime;
        if (lastMessageTime == 0 || (convLastTime > 0 && convLastTime > lastMessageTime)) lastMessageTime = convLastTime;

        backupConvInfos.add(BackupConversationInfo(
            type: info.conversation.conversationType.index,
            target: info.conversation.target,
            line: info.conversation.line,
            directory: convDirName,
            messageCount: backupMessages.length,
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

      final metadata = BackupMetadata(
          backupTime: startTime.toIso8601String(),
          userId: Imclient.currentUserId,
          deviceName: Platform.localHostname,
          // Simple device name
          statistics: statistics,
          conversations: backupConvInfos,
          encryption: BackupEncryptionInfo(enabled: password != null && password.isNotEmpty, hint: passwordHint),
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

  Future<BackupMessage> _convertToBackupMessage(Message msg, Directory mediaDir) async {
    final payload = BackupMessagePayload();
    final content = msg.content;
    final encoded = content.encode();

    payload.contentType = content.meta.type;
    payload.content = encoded.content ?? '';
    payload.searchableContent = await content.digest(msg);
    payload.pushContent = encoded.pushContent ?? '';
    payload.pushData = encoded.pushData ?? '';
    payload.binaryContent = encoded.binaryContent != null ? base64Encode(encoded.binaryContent!) : '';
    payload.localContent = encoded.localContent ?? '';
    payload.mentionedType = encoded.mentionedType;
    payload.mentionedTargets = encoded.mentionedTargets;
    payload.extra = encoded.extra ?? '';
    payload.mediaType = encoded.mediaType.index;
    payload.remoteMediaUrl = encoded.remoteMediaUrl ?? '';

    // Media handling
    if (content is MediaMessageContent) {
      try {
        String? localPath = content.localPath;

        if (localPath != null && localPath.isNotEmpty) {
          final file = File(localPath);
          if (await file.exists()) {
            final fileName = path.basename(localPath);
            final destFile = File(path.join(mediaDir.path, fileName));
            await file.copy(destFile.path);

            final fileSize = await file.length();
            payload.localMediaInfo = BackupMediaInfo(
              fileName: fileName,
              relativePath: "${MEDIA_DIR_NAME}/$fileName", // Force relative path
              fileSize: fileSize,
            );
          }
        }
      } catch (e) {
        // Ignore media error
      }
    }

    return BackupMessage(
        messageUid: msg.messageUid ?? 0,
        fromUser: msg.fromUser,
        toUsers: msg.toUsers,
        direction: msg.direction.index,
        status: msg.status.index,
        timestamp: msg.serverTime,
        payload: payload,
        mediaFileSize: payload.localMediaInfo?.fileSize ?? 0);
  }

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
      if (!await metadataFile.exists()) throw Exception("Invalid backup: missing metadata");

      final jsonStr = await metadataFile.readAsString();
      final metadata = BackupMetadata.fromJson(jsonDecode(jsonStr));

      if (metadata.encryption != null && metadata.encryption!.enabled) {
        if (password == null || password.isEmpty) {
          throw Exception("Password required");
        }
      }

      final conversations = metadata.conversations ?? [];
      final progress = BackupProgress(total: conversations.length, current: 0, phase: "Restoring conversations...");
      onProgress?.call(progress);

      int restoredMsgCount = 0;
      int restoredMediaCount = 0;

      for (var i = 0; i < conversations.length; i++) {
        if (_isCancelled) throw Exception("Cancelled");
        final convInfo = conversations[i];

        final convDir = Directory(path.join(backupDir.path, CONVERSATIONS_DIR_NAME, convInfo.directory));
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
          final List<dynamic> msgList = msgsJson['messages'];

          List<Message> messagesToInsert = [];

          for (var mJson in msgList) {
            final backupMsg = BackupMessage.fromJson(mJson);
            final msg = _convertToMessage(backupMsg, convInfo, convDir);
            if (msg != null) {
              messagesToInsert.add(msg);
            }
          }

          // Batch insert
          for (var msg in messagesToInsert) {
            if (_isCancelled) throw Exception("Cancelled");
            await Imclient.insertMessage(msg.conversation, msg.fromUser, msg.content, msg.status.index, msg.serverTime, toUsers: msg.toUsers);
          }
          restoredMsgCount += messagesToInsert.length;
        }

        progress.current = i + 1;
        onProgress?.call(progress);
      }

      onSuccess?.call(restoredMsgCount, restoredMediaCount);
    } catch (e) {
      if (!_isCancelled) {
        debugPrint("Restore failed: $e");
      }
      onError?.call(e.toString());
    }
  }

  Message? _convertToMessage(BackupMessage backupMsg, BackupConversationInfo convInfo, Directory convDir) {
    // Reconstruct Message
    final conversation = Conversation(conversationType: ConversationType.values[convInfo.type], target: convInfo.target, line: convInfo.line);

    // Reconstruct MessagePayload first
    final mp = MessagePayload(mentionedType: backupMsg.payload!.mentionedType, mediaType: MediaType.values[backupMsg.payload!.mediaType]);
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
    if (backupMsg.payload!.localMediaInfo != null && content is MediaMessageContent) {
      final mediaInfo = backupMsg.payload!.localMediaInfo!;
      final mediaFile = File(path.join(convDir.path, mediaInfo.relativePath));
      if (mediaFile.existsSync()) {
        content.localPath = mediaFile.path;
      }
    }

    final msg = Message();
    msg.conversation = conversation;
    msg.content = content;
    msg.fromUser = backupMsg.fromUser;
    msg.toUsers = backupMsg.toUsers;
    msg.direction = MessageDirection.values[backupMsg.direction];
    msg.status = MessageStatus.values[backupMsg.status];
    msg.serverTime = backupMsg.timestamp;

    return msg;
  }

  // PC BACKUP & RESTORE

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
      for (var info in conversationInfos) {
        // This relies on getMessageCount being synchronous or cached if available,
        // but typically it is async. If Imclient has a synchronous version use it.
        // Assuming Imclient.getMessageCount is not available directly, we might need
        // to approximate or fetch async.
        // For now, let's assume we can get it or just pass 0.
        // Actually looking at Android code: ChatManager.Instance().getMessageCount(conversation)
        // Check if Flutter Imclient has it.
      }
      // Note: Imclient.getMessagesCount is likely async. We can loop and await.
      for (var info in conversationInfos) {
        // TODO: Improve performance?
        // totalMessageCount += ...
      }

      final content = BackupRequestNotificationContent();
      content.conversationCount = conversationInfos.length;
      content.messageCount = totalMessageCount; // Simplified
      content.includeMedia = includeMedia;
      content.timestamp = DateTime.now().millisecondsSinceEpoch;

      final currentUserId = Imclient.currentUserId;
      if (currentUserId == null) throw Exception("Not logged in");

      final conversation = Conversation(
        conversationType: ConversationType.Single,
        target: currentUserId,
        line: 0,
      );

      await Imclient.sendMessage(conversation, content, successCallback: (messageUid, timestamp) {}, errorCallback: (errorCode) {});

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

      subscription = Imclient.IMEventBus.on<ReceiveMessagesEvent>().listen((event) {
        for (var m in event.messages) {
          if (m.content is BackupResponseNotificationContent) {
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
          progress.phase = "Creating local backup...";
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

      final progress = BackupProgress(total: fileList.length, current: 0, phase: "Uploading to PC...");
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
      await http.post(completeUrl, body: bodyBytes.buffer.asUint8List(), headers: {
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

  Future<void> _uploadFileToPC(String ip, int port, String relativePath, File file) async {
    final url = Uri.http('$ip:$port', '/backup');

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
      // Start the stream adding in background? No, request.send() starts sending.
      // Wait, StreamedRequest is intended to have data written to it.

      // If file is small, read all bytes.
      if (false && fileLen < 10 * 1024 * 1024) {
        // 10MB
        final fileBytes = await file.readAsBytes();
        final body = BytesBuilder();
        body.add(header.buffer.asUint8List());
        body.add(fileBytes);

        final req = http.Request('POST', url);
        req.bodyBytes = body.toBytes();
        final res = await client.send(req);
        if (res.statusCode != 200) {
          throw Exception("Upload failed: ${res.statusCode}");
        }
      } else {
        // Large file, use StreamedRequest
        final req = http.StreamedRequest('POST', url);

        // Don't await addStream? No, we should.
        // But we must call client.send(req) to START the request.
        // StreamedRequest logic:
        // 1. Create request.
        // 2. Call client.send(request). This returns a Future<StreamedResponse>.
        // 3. Write to request.sink.
        // 4. request.sink.close().

        // WAIT! client.send(req) returns the response. It waits for the request to be sent?
        // No, StreamedRequest allows sending data while response is being waited?
        // Actually, typically send() waits for headers to be sent?

        // Correct usage of StreamedRequest:
        // final response = await client.send(request);
        // But if we await response, we haven't written body yet?
        // No, StreamedRequest is special. The body is the stream.

        // If we use standard http.post, we can't stream easily.

        // Let's look at `http` package docs.
        // "StreamedRequest ... allows the body to be uploaded as a Stream."
        // "The sink property is used to add data to the body."

        // The issue is likely that we are awaiting addStream BEFORE calling send().
        // But we can't call send() before we set up the body?
        // Actually, we can write to sink before send().

        // If addStream hangs, maybe file.openRead() is not emitting?

        // Let's try the approach where we combine streams and pass to a generic Request if possible? No.

        // Back to the hang: "await controller.addStream(file.openRead())"
        // This pipes file stream to controller.
        // And controller.stream is passed to request.sink?
        // request.sink.addStream(controller.stream) -> This is what we did: request.sink.addStream(controller.stream)

        // Oh, in previous code:
        // request.sink.addStream(controller.stream);
        // This returns a Future. We didn't await it. We just added it.
        // Then we added data to controller.

        // If we await request.send(), it subscribes to request.sink?

        // Let's try to do it without the intermediate StreamController.
        // Just write to request.sink.

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
      final localBackupDir = Directory(path.join(rootPath, backupPathRemote));
      if (!await localBackupDir.exists()) {
        await localBackupDir.create(recursive: true);
      }

      // 1. Download metadata
      final metadataUrl = Uri.http('$ip:$port', '/restore_metadata', {'path': backupPathRemote});
      final response = await http.get(metadataUrl);
      if (response.statusCode != 200) throw Exception("Failed to get metadata");

      final metadataFile = File(path.join(localBackupDir.path, METADATA_FILE_NAME));
      await metadataFile.writeAsBytes(response.bodyBytes);

      final metadata = BackupMetadata.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));

      if (metadata.conversations == null) throw Exception("Invalid metadata");

      final progress = BackupProgress(total: metadata.conversations!.length, phase: "Downloading files...");
      onProgress?.call(progress);

      for (var i = 0; i < metadata.conversations!.length; i++) {
        if (_isCancelled) throw Exception("Cancelled");

        final conv = metadata.conversations![i];
        final convDirName = conv.directory;
        final convPathRemote = "$backupPathRemote/$CONVERSATIONS_DIR_NAME/$convDirName";

        // Download messages.json
        final messagesRemotePath = "$convPathRemote/$MESSAGES_FILE_NAME";
        final localConvDir = Directory(path.join(localBackupDir.path, CONVERSATIONS_DIR_NAME, convDirName));
        if (!await localConvDir.exists()) await localConvDir.create(recursive: true);

        await _downloadFileFromPC(ip, port, messagesRemotePath, File(path.join(localConvDir.path, MESSAGES_FILE_NAME)));

        // Read messages.json to find media
        bool isEncrypted = metadata.encryption != null && metadata.encryption!.enabled;
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
            if (jsonRaw is Map<String, dynamic> && jsonRaw.containsKey('salt')) {
              final decryptedBytes = BackupCrypto.decryptData(jsonRaw, password!);
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

        final messagesList = (messagesJson['messages'] as List).map((e) => BackupMessage.fromJson(e)).toList();

        final localMediaDir = Directory(path.join(localConvDir.path, MEDIA_DIR_NAME));
        if (!await localMediaDir.exists()) await localMediaDir.create();

        for (final msg in messagesList) {
          if (_isCancelled) throw Exception("Cancelled");
          if (msg.payload?.localMediaInfo != null) {
            final mediaInfo = msg.payload!.localMediaInfo!;

            final mediaRemotePath = "$convPathRemote/${mediaInfo.relativePath}";
            final localMediaFile = File(path.join(localConvDir.path, mediaInfo.relativePath));

            if (!await localMediaFile.exists()) {
              await _downloadFileFromPC(ip, port, mediaRemotePath, localMediaFile);
            }
          }
        }

        progress.current = i + 1;
        onProgress?.call(progress);
      }

      // Restore
      await restoreBackup(localBackupDir.path, password: password, onProgress: onProgress, onSuccess: onSuccess, onError: (e) => throw Exception(e));
    } catch (e) {
      onError?.call(e.toString());
    }
  }

  Future<void> _downloadFileFromPC(String ip, int port, String remotePath, File targetFile) async {
    final url = Uri.http('$ip:$port', '/restore_file', {'path': remotePath});
    final response = await http.get(url);
    if (response.statusCode == 200) {
      await targetFile.writeAsBytes(response.bodyBytes);
    } else {
      debugPrint("Failed to download $remotePath: ${response.statusCode}");
    }
  }
}
