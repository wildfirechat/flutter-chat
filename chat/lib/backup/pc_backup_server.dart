import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import 'backup_manager.dart';

class PCBackupServerProgress {
  final int currentFile;
  final String? currentFileName;
  final String? backupPath;
  final int? totalFiles;

  PCBackupServerProgress({
    this.currentFile = 0,
    this.currentFileName,
    this.backupPath,
    this.totalFiles,
  });
}

class PcBackupServer {
  static final PcBackupServer _instance = PcBackupServer._internal();

  factory PcBackupServer() => _instance;

  PcBackupServer._internal();

  HttpServer? _server;
  String? _currentBackupSaveDir;
  int _currentFileCount = 0;
  int _expectedFileCount = 0;
  bool _isBackupCompleting = false;
  Timer? _completionTimer;

  // Callbacks
  void Function(String backupPath)? onBackupStart;
  void Function(PCBackupServerProgress progress)? onBackupProgress;
  void Function(int count, String path)? onBackupComplete;
  void Function(String error)? onError;

  final StreamController<void> _backupCompletedController =
      StreamController<void>.broadcast();

  /// Stream that fires whenever a mobile backup has been fully received.
  Stream<void> get backupCompleted => _backupCompletedController.stream;

  Future<void> stopServer() async {
    _resetCompletionTimer();
    if (_server != null) {
      try {
        await _server!.close();
      } catch (e) {
        // ignore
      }
      _server = null;
    }
  }

  Future<Map<String, dynamic>> startBackupServer() async {
    await stopServer();
    _currentBackupSaveDir = null;
    _currentFileCount = 0;
    _expectedFileCount = 0;
    _isBackupCompleting = false;

    final ip = await _getLocalIP();
    const maxRetries = 10;
    int retryCount = 0;

    final completer = Completer<Map<String, dynamic>>();

    void tryStartServer(int port) async {
      try {
        final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
        _server = server;
        completer.complete({'ip': ip, 'port': port});

        await for (final request in server) {
          _handleBackupRequest(request);
        }
      } catch (e) {
        retryCount++;
        if (retryCount < maxRetries) {
          tryStartServer(_randomPort());
        } else {
          if (!completer.isCompleted) {
            completer.completeError(Exception(
                'Failed to start backup server after $maxRetries attempts'));
          }
        }
      }
    }

    tryStartServer(_randomPort());
    return completer.future;
  }

  void _handleBackupRequest(HttpRequest request) async {
    try {
      if (request.method == 'POST' && request.uri.path == '/backup') {
        final buffer = await _readRequestBody(request);
        await _saveBackupFile(buffer);
        request.response.statusCode = 200;
        request.response.write('OK');
      } else if (request.method == 'POST' &&
          request.uri.path == '/backup_complete') {
        final buffer = await _readRequestBody(request);
        if (buffer.length >= 4) {
          final byteData = ByteData.sublistView(buffer);
          _expectedFileCount = byteData.getInt32(0, Endian.little);
        }

        request.response.statusCode = 200;
        request.response.write('OK');
        await request.response.close();

        if (_currentFileCount >= _expectedFileCount) {
          _onBackupComplete();
        } else {
          _resetCompletionTimer();
        }
        return;
      } else {
        request.response.statusCode = 404;
        request.response.write('Not Found');
      }
    } catch (e) {
      request.response.statusCode = 500;
      request.response.write('Error');
      onError?.call('Backup server request error: $e');
    }
    await request.response.close();
  }

  Future<Uint8List> _readRequestBody(HttpRequest request) async {
    final bytes = <int>[];
    await for (final chunk in request) {
      bytes.addAll(chunk);
    }
    return Uint8List.fromList(bytes);
  }

  Future<void> _saveBackupFile(Uint8List buffer) async {
    int offset = 0;
    final byteData = ByteData.sublistView(buffer);

    // Read path length (4 bytes LE)
    final pathLength = byteData.getInt32(offset, Endian.little);
    offset += 4;

    // Read path
    final relativePath =
        utf8.decode(buffer.sublist(offset, offset + pathLength));
    offset += pathLength;

    // Read file length (8 bytes LE)
    final dataLengthLow = byteData.getInt32(offset, Endian.little);
    offset += 4;
    final dataLengthHigh = byteData.getInt32(offset, Endian.little);
    offset += 4;
    final dataLength = (dataLengthHigh << 32) + dataLengthLow;

    // Read file data
    final dataStart = offset;
    final dataEnd = dataStart + dataLength;
    final fileData = buffer.sublist(dataStart, dataEnd);

    if (_currentBackupSaveDir == null) {
      final backupRoot = await BackupManager().getPCBackupReceivedDirectory();
      final timestamp = _formatTimestampForDirectory(DateTime.now());
      _currentBackupSaveDir = path.join(backupRoot, 'backup_$timestamp');
      await Directory(_currentBackupSaveDir!).create(recursive: true);

      if (path.basename(relativePath) == METADATA_FILE_NAME) {
        onBackupStart?.call(_currentBackupSaveDir!);
      }
    }

    final filePath = path.join(_currentBackupSaveDir!, relativePath);
    final fileDir = path.dirname(filePath);
    await Directory(fileDir).create(recursive: true);

    final file = File(filePath);
    await file.writeAsBytes(fileData);

    _currentFileCount++;

    onBackupProgress?.call(PCBackupServerProgress(
      currentFile: _currentFileCount,
      currentFileName: path.basename(relativePath),
      backupPath: _currentBackupSaveDir,
      totalFiles: _expectedFileCount > 0 ? _expectedFileCount : null,
    ));

    if (_expectedFileCount > 0 && _currentFileCount >= _expectedFileCount) {
      _onBackupComplete();
    } else {
      _resetCompletionTimer();
    }
  }

  void _resetCompletionTimer() {
    _completionTimer?.cancel();
    _completionTimer = Timer(const Duration(seconds: 60), () {
      _onBackupComplete();
    });
  }

  void _onBackupComplete() {
    if (_isBackupCompleting) return;
    _isBackupCompleting = true;

    if (_currentBackupSaveDir != null) {
      onBackupComplete?.call(_currentFileCount, _currentBackupSaveDir!);
      _backupCompletedController.add(null);
    }

    stopServer();
    _currentBackupSaveDir = null;

    Future.delayed(const Duration(seconds: 1), () {
      _isBackupCompleting = false;
    });
  }

  Future<Map<String, dynamic>> startRestoreServer() async {
    await stopServer();

    final ip = await _getLocalIP();
    const maxRetries = 10;
    int retryCount = 0;

    final completer = Completer<Map<String, dynamic>>();

    void tryStartServer(int port) async {
      try {
        final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
        _server = server;
        completer.complete({'ip': ip, 'port': port});

        await for (final request in server) {
          _handleRestoreRequest(request);
        }
      } catch (e) {
        retryCount++;
        if (retryCount < maxRetries) {
          tryStartServer(_randomPort());
        } else {
          if (!completer.isCompleted) {
            completer.completeError(Exception(
                'Failed to start restore server after $maxRetries attempts'));
          }
        }
      }
    }

    tryStartServer(_randomPort());
    return completer.future;
  }

  void _handleRestoreRequest(HttpRequest request) async {
    try {
      if (request.method == 'GET' && request.uri.path == '/restore_list') {
        final list = await _getBackupList();
        final jsonBytes = utf8.encode(jsonEncode(list));
        request.response.headers.contentType = ContentType.json;
        request.response.add(jsonBytes);
      } else if (request.method == 'GET' &&
          request.uri.path == '/restore_metadata') {
        final backupPath = request.uri.queryParameters['path'];
        if (backupPath == null || backupPath.isEmpty) {
          request.response.statusCode = 400;
          request.response.write('Missing backup path');
        } else {
          final metadataPath = path.join(backupPath, METADATA_FILE_NAME);
          final file = File(metadataPath);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            request.response.headers.contentType = ContentType.json;
            request.response.add(bytes);
          } else {
            request.response.statusCode = 404;
            request.response.write('Metadata file not found');
          }
        }
      } else if (request.method == 'GET' &&
          request.uri.path == '/restore_file') {
        final filePath = request.uri.queryParameters['path'];
        if (filePath == null || filePath.isEmpty) {
          request.response.statusCode = 400;
          request.response.write('Missing file path');
        } else {
          final file = File(filePath);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            request.response.headers.contentType = ContentType.binary;
            request.response.add(bytes);
          } else {
            request.response.statusCode = 404;
            request.response.write('File not found');
          }
        }
      } else {
        request.response.statusCode = 404;
        request.response.write('Not Found');
      }
    } catch (e) {
      request.response.statusCode = 500;
      request.response.write('Error');
      onError?.call('Restore server request error: $e');
    }
    await request.response.close();
  }

  Future<List<Map<String, dynamic>>> _getBackupList() async {
    final backupRoot = await BackupManager().getPCBackupReceivedDirectory();
    final receivedDir = Directory(backupRoot);
    if (!await receivedDir.exists()) return [];

    final backups = <Map<String, dynamic>>[];
    final dirs = receivedDir.listSync().whereType<Directory>();

    for (final dir in dirs) {
      final name = path.basename(dir.path);
      if (!name.startsWith('backup_')) continue;

      final metadataPath = path.join(dir.path, METADATA_FILE_NAME);
      final metadataFile = File(metadataPath);
      if (!await metadataFile.exists()) continue;

      try {
        final jsonStr = await metadataFile.readAsString();
        final metadata = jsonDecode(jsonStr);
        int fileCount = 0;
        int conversationCount = 0;
        int messageCount = 0;
        int mediaFileCount = 0;
        int mediaSize = 0;
        String? time;
        String? deviceName;

        if (metadata['statistics'] != null) {
          final stats = metadata['statistics'];
          conversationCount = stats['totalConversations'] ?? 0;
          messageCount = stats['totalMessages'] ?? 0;
          mediaFileCount = stats['mediaFileCount'] ?? 0;
          mediaSize = stats['mediaTotalSize'] ?? 0;
        }
        if (metadata['backupTime'] != null) {
          time = metadata['backupTime'];
        }
        if (metadata['deviceName'] != null) {
          deviceName = metadata['deviceName'];
        }

        fileCount = await _countFiles(dir);

        backups.add({
          'name': name,
          'time': time,
          'path': dir.path,
          'deviceName': deviceName,
          'fileCount': fileCount,
          'conversationCount': conversationCount,
          'messageCount': messageCount,
          'mediaFileCount': mediaFileCount,
          'mediaSize': mediaSize,
        });
      } catch (e) {
        debugPrint('Failed to read metadata for $dir: $e');
      }
    }

    backups.sort((a, b) {
      final timeA =
          DateTime.tryParse(a['time'] ?? '')?.millisecondsSinceEpoch ?? 0;
      final timeB =
          DateTime.tryParse(b['time'] ?? '')?.millisecondsSinceEpoch ?? 0;
      return timeB - timeA;
    });

    return backups;
  }

  Future<int> _countFiles(Directory dir) async {
    int count = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) count++;
    }
    return count;
  }

  Future<String> _getLocalIP() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to get local IP: $e');
    }
    return '127.0.0.1';
  }

  int _randomPort() {
    return Random().nextInt(60000 - 10000 + 1) + 10000;
  }

  String _formatTimestampForDirectory(DateTime dt) {
    final utc = dt.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-${utc.month.toString().padLeft(2, '0')}-${utc.day.toString().padLeft(2, '0')}T'
        '${utc.hour.toString().padLeft(2, '0')}-${utc.minute.toString().padLeft(2, '0')}-${utc.second.toString().padLeft(2, '0')}';
  }
}
