import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:imclient/imclient.dart';
import 'package:imclient/message/message_content.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;

import '../config.dart';
import '../utils/media_url_redirector.dart';

/// 云盘服务
///
/// 对接网盘后端 API，提供空间、目录、文件的上传下载与管理。
/// 认证方式：使用 Imclient.getAuthCode 获取认证码，通过 HTTP Header 传递。
class PanService {
  static const String _authCodeId = 'admin';
  static const int _authCodeType = 2;

  static final PanService _instance = PanService._();
  factory PanService() => _instance;
  PanService._();

  /// 检查网盘服务是否可用
  static bool get isAvailable {
    final url = Config.panServerAddress;
    return url != null && url.isNotEmpty;
  }

  /// 获取服务基础地址
  static String get _baseUrl {
    final url = Config.panServerAddress;
    if (url == null || url.isEmpty) {
      throw PanException(-1, '网盘服务未配置');
    }
    return MediaUrlRedirector.redirect(url);
  }

  static String _extractHost(String url) {
    String host = url;
    if (host.startsWith('https://')) {
      host = host.substring(8);
    } else if (host.startsWith('http://')) {
      host = host.substring(7);
    }
    final slashIndex = host.indexOf('/');
    if (slashIndex > 0) {
      host = host.substring(0, slashIndex);
    }
    return host;
  }

  static Future<String> _getAuthCode() async {
    final completer = Completer<String>();
    final host = _extractHost(_baseUrl);

    Imclient.getAuthCode(
      _authCodeId,
      _authCodeType,
      host,
      (authCode) => completer.complete(authCode),
      (errorCode) => completer.completeError(PanException(errorCode, '获取认证码失败')),
    );

    return completer.future;
  }

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> params,
  ) async {
    final authCode = await _getAuthCode();
    final url = Uri.parse('$_baseUrl$path');
    debugPrint('Pan POST $url params: $params');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'authCode': authCode,
      },
      body: json.encode(params),
    );

    debugPrint('Pan POST $path status: ${response.statusCode} body: ${response.body}');
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final code = data['code'] ?? -1;
      if (code != 0) {
        throw PanException(code, data['message'] ?? '请求失败');
      }
      return data;
    } else {
      throw PanException(-1, '网络错误: ${response.statusCode}');
    }
  }

  /// 获取所有可访问的空间列表
  static Future<List<PanSpace>> getSpaces() async {
    final data = await _post('/api/v1/spaces/list', {});
    final list = data['data'] as List?;
    if (list == null) return [];
    return list.map((e) => PanSpace.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 获取我的空间（公共 + 私有）
  static Future<List<PanSpace>> getMySpaces() async {
    final data = await _post('/api/v1/spaces/my', {});
    final list = data['data'] as List?;
    if (list == null) return [];
    return list.map((e) => PanSpace.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 获取指定用户的公共空间
  static Future<PanSpace?> getUserPublicSpace(String userId) async {
    final data = await _post('/api/v1/spaces/user/public', {'targetUserId': userId});
    final result = data['data'];
    if (result is! Map<String, dynamic>) return null;
    return PanSpace.fromJson(result);
  }

  /// 获取空间内文件列表
  static Future<List<PanFile>> getSpaceFiles(int spaceId, {int parentId = 0}) async {
    final data = await _post('/api/v1/spaces/files', {
      'spaceId': spaceId,
      'parentId': parentId,
    });
    final list = data['data'] as List?;
    if (list == null) return [];
    return list.map((e) => PanFile.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 创建文件夹
  static Future<PanFile> createFolder(int spaceId, String name, {int parentId = 0}) async {
    final data = await _post('/api/v1/files/folder', {
      'spaceId': spaceId,
      'parentId': parentId > 0 ? parentId : null,
      'name': name,
    });
    final result = data['data'] as Map<String, dynamic>?;
    if (result == null) throw PanException(-1, '返回数据为空');
    return PanFile.fromJson(result);
  }

  /// 创建文件记录（上传完成后调用）
  static Future<PanFile> createFile({
    required int spaceId,
    required String name,
    required int size,
    required String storageUrl,
    int parentId = 0,
    String? mimeType,
    String? md5,
    bool copy = false,
  }) async {
    final params = <String, dynamic>{
      'spaceId': spaceId,
      'name': name,
      'size': size,
      'storageUrl': storageUrl,
      'copy': copy,
    };
    if (parentId > 0) params['parentId'] = parentId;
    if (mimeType != null && mimeType.isNotEmpty) params['mimeType'] = mimeType;
    if (md5 != null && md5.isNotEmpty) params['md5'] = md5;

    debugPrint('Pan createFile request: $params');
    final data = await _post('/api/v1/files', params);
    debugPrint('Pan createFile response: $data');
    final result = data['data'] as Map<String, dynamic>?;
    if (result == null) throw PanException(-1, '返回数据为空');
    return PanFile.fromJson(result);
  }

  /// 上传文件到指定空间的指定目录，自动处理重名
  static Future<PanFile> uploadFileToSpace({
    required String localPath,
    required PanSpace space,
    int parentId = 0,
    void Function(double progress)? onProgress,
    PanUploadCancelToken? cancelToken,
  }) async {
    final originalName = path.basename(localPath);
    final existingFiles = await getSpaceFiles(space.spaceId, parentId: parentId);
    final uniqueName = _uniqueFileName(existingFiles, originalName);

    return uploadFile(
      localPath: localPath,
      spaceId: space.spaceId,
      parentId: parentId,
      remoteName: uniqueName,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  static String _uniqueFileName(List<PanFile> existingFiles, String originalName) {
    final names = existingFiles.map((f) => f.name).toSet();
    if (!names.contains(originalName)) {
      return originalName;
    }

    final extIndex = originalName.lastIndexOf('.');
    final base = extIndex > 0 ? originalName.substring(0, extIndex) : originalName;
    final ext = extIndex > 0 ? originalName.substring(extIndex) : '';

    int index = 1;
    String candidate;
    do {
      candidate = '$base($index)$ext';
      index++;
    } while (names.contains(candidate));
    return candidate;
  }
  ///
  /// 参考 iOS WFCCIMService.uploadMediaFile 的大文件逻辑：
  /// 当支持大文件上传且（强制预签名或文件 > 100MB）时，先获取预签名上传地址，
  /// 再按类型（1=七牛表单，其他=HTTP PUT）上传，最后调用 createFile 注册记录。
  static Future<PanFile> uploadFile({
    required String localPath,
    required int spaceId,
    int parentId = 0,
    String? remoteName,
    void Function(double progress)? onProgress,
    PanUploadCancelToken? cancelToken,
  }) async {
    debugPrint('Pan uploadFile start: $localPath');
    final file = File(localPath);
    if (!await file.exists()) {
      debugPrint('Pan uploadFile file not exists');
      throw PanException(-1, '文件不存在');
    }

    final name = remoteName ?? path.basename(localPath);
    debugPrint('Pan uploadFile name: $name');
    final size = await file.length();
    debugPrint('Pan uploadFile size: $size');
    final md5 = await _md5File(file);
    debugPrint('Pan uploadFile md5: $md5');
    final mimeType = lookupMimeType(localPath) ?? 'application/octet-stream';
    debugPrint('Pan uploadFile mimeType: $mimeType');

    final bool useLargeUpload = await _shouldUseLargeUpload(size);
    debugPrint('Pan uploadFile useLargeUpload: $useLargeUpload');

    final String storageUrl;
    if (useLargeUpload) {
      debugPrint('Pan uploadFile enter large upload');
      storageUrl = await _uploadLargeFile(
        localPath: localPath,
        name: name,
        size: size,
        mimeType: mimeType,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    } else {
      debugPrint('Pan uploadFile enter small upload');
      storageUrl = await _uploadSmallFile(
        localPath,
        onProgress,
        cancelToken: cancelToken,
      );
    }
    debugPrint('Pan uploadFile storageUrl: $storageUrl');

    if (cancelToken?.isCancelled ?? false) {
      throw PanException(-2, '上传已取消');
    }

    return createFile(
      spaceId: spaceId,
      name: name,
      size: size,
      storageUrl: storageUrl,
      parentId: parentId,
      mimeType: mimeType,
      md5: md5,
    );
  }

  static Future<bool> _shouldUseLargeUpload(int size) async {
    debugPrint('Pan _shouldUseLargeUpload check support');
    final support = await Imclient.isSupportBigFilesUpload();
    debugPrint('Pan isSupportBigFilesUpload: $support');
    if (!support) {
      return false;
    }
    debugPrint('Pan _shouldUseLargeUpload check force');
    final force = await Imclient.isForceBigFilesUpload();
    debugPrint('Pan isForceBigFilesUpload: $force');
    if (force) {
      return true;
    }
    return size > 100 * 1024 * 1024;
  }

  static Future<String> _uploadSmallFile(
    String localPath,
    void Function(double progress)? onProgress, {
    PanUploadCancelToken? cancelToken,
  }) async {
    debugPrint('Pan _uploadSmallFile call Imclient.uploadMediaFile');
    final completer = Completer<String>();

    Imclient.uploadMediaFile(
      localPath,
      MediaType.Media_Type_FILE,
      (url) {
        debugPrint('Pan _uploadSmallFile success: $url');
        if (cancelToken?.isCancelled ?? false) {
          completer.completeError(PanException(-2, '上传已取消'));
        } else {
          completer.complete(url);
        }
      },
      onProgress != null
          ? (uploaded, total) {
              debugPrint('Pan _uploadSmallFile progress: $uploaded / $total');
              if (cancelToken?.isCancelled ?? false) return;
              if (total > 0) onProgress(uploaded / total);
            }
          : (a, b) {},
      (errorCode) {
        debugPrint('Pan _uploadSmallFile error: $errorCode');
        if (cancelToken?.isCancelled ?? false) {
          completer.completeError(PanException(-2, '上传已取消'));
        } else {
          completer.completeError(PanException(errorCode, '上传失败'));
        }
      },
    );

    return completer.future;
  }

  static Future<String> _uploadLargeFile({
    required String localPath,
    required String name,
    required int size,
    required String mimeType,
    void Function(double progress)? onProgress,
    PanUploadCancelToken? cancelToken,
  }) async {
    final uploadInfo = await _getUploadUrl(name, mimeType);
    final uploadUrl = _selectUploadUrl(uploadInfo);

    if (cancelToken?.isCancelled ?? false) {
      throw PanException(-2, '上传已取消');
    }

    if (uploadInfo.type == 1) {
      return _uploadQiniuFile(
        localPath: localPath,
        uploadUrl: uploadUrl,
        downloadUrl: uploadInfo.downloadUrl,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    } else {
      return _uploadPutFile(
        localPath: localPath,
        uploadUrl: uploadUrl,
        downloadUrl: uploadInfo.downloadUrl,
        mimeType: mimeType,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    }
  }

  static Future<_UploadUrlInfo> _getUploadUrl(String fileName, String mimeType) async {
    final completer = Completer<_UploadUrlInfo>();
    Imclient.getMediaUploadUrl(
      fileName,
      MediaType.Media_Type_FILE.index,
      mimeType,
      (uploadUrl, downloadUrl, backupUploadUrl, type) {
        completer.complete(_UploadUrlInfo(
          uploadUrl: uploadUrl,
          downloadUrl: downloadUrl,
          backupUploadUrl: backupUploadUrl,
          type: type,
        ));
      },
      (errorCode) => completer.completeError(PanException(errorCode, '获取上传地址失败')),
    );
    return completer.future;
  }

  static String _selectUploadUrl(_UploadUrlInfo info) {
    // 双网环境下根据主备网络选择；当前版本未接入网络状态，优先主地址。
    if (info.backupUploadUrl.isNotEmpty) {
      // TODO: 结合 MediaUrlRedirector 或网络状态选择主备地址。
    }
    return info.uploadUrl;
  }

  static Future<String> _uploadPutFile({
    required String localPath,
    required String uploadUrl,
    required String downloadUrl,
    required String mimeType,
    void Function(double progress)? onProgress,
    PanUploadCancelToken? cancelToken,
  }) async {
    final file = File(localPath);
    final total = await file.length();
    final client = HttpClient();
    HttpClientRequest? request;
    try {
      request = await client.openUrl('PUT', Uri.parse(uploadUrl));
      request.headers.set('Content-Type', mimeType);
      request.contentLength = total;

      int uploaded = 0;
      await for (final chunk in file.openRead()) {
        if (cancelToken?.isCancelled ?? false) {
          request.abort();
          throw PanException(-2, '上传已取消');
        }
        request.add(chunk);
        await request.flush();
        uploaded += chunk.length;
        if (onProgress != null && total > 0) {
          onProgress(uploaded / total);
        }
      }

      final response = await request.close();
      if (response.statusCode != 200) {
        throw PanException(response.statusCode, '预签名上传失败');
      }
      return downloadUrl;
    } finally {
      client.close();
    }
  }

  static Future<String> _uploadQiniuFile({
    required String localPath,
    required String uploadUrl,
    required String downloadUrl,
    void Function(double progress)? onProgress,
    PanUploadCancelToken? cancelToken,
  }) async {
    if (cancelToken?.isCancelled ?? false) {
      throw PanException(-2, '上传已取消');
    }

    // uploadUrl 格式：endpoint?token&key
    final parts = uploadUrl.split('?');
    if (parts.length != 2) {
      throw PanException(-1, '七牛上传地址格式错误');
    }
    final endpoint = parts[0];
    final queryParts = parts[1].split('&');
    if (queryParts.length != 2) {
      throw PanException(-1, '七牛上传地址缺少 token 或 key');
    }
    final token = queryParts[0];
    final key = queryParts[1];

    final request = http.MultipartRequest('POST', Uri.parse(endpoint))
      ..fields['key'] = key
      ..fields['token'] = token
      ..files.add(await http.MultipartFile.fromPath('file', localPath));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (cancelToken?.isCancelled ?? false) {
      throw PanException(-2, '上传已取消');
    }

    if (response.statusCode != 200) {
      throw PanException(response.statusCode, '七牛上传失败');
    }
    return downloadUrl;
  }

  /// 删除文件/文件夹
  static Future<void> deleteFile(int fileId) async {
    await _post('/api/v1/files/delete', {'fileId': fileId});
  }

  /// 重命名文件/文件夹
  static Future<void> renameFile(int fileId, String newName) async {
    await _post('/api/v1/files/rename', {'fileId': fileId, 'newName': newName});
  }

  /// 移动文件/文件夹
  static Future<void> moveFile(int fileId, int targetSpaceId, {int targetParentId = 0}) async {
    await _post('/api/v1/files/move', {
      'fileId': fileId,
      'targetSpaceId': targetSpaceId,
      'targetParentId': targetParentId,
    });
  }

  /// 复制文件/文件夹
  static Future<void> copyFile(int fileId, int targetSpaceId, {int targetParentId = 0}) async {
    await _post('/api/v1/files/copy', {
      'fileId': fileId,
      'targetSpaceId': targetSpaceId,
      'targetParentId': targetParentId,
    });
  }

  /// 获取文件下载 URL
  static Future<String> getFileDownloadUrl(int fileId) async {
    final data = await _post('/api/v1/files/url', {'fileId': fileId});
    final result = data['data'] as Map<String, dynamic>?;
    if (result == null) throw PanException(-1, '返回数据为空');
    return result['storageUrl'] as String? ?? '';
  }

  /// 检查空间写入权限
  static Future<bool> checkSpaceWritePermission(int spaceId) async {
    final data = await _post('/api/v1/files/check-permission', {'spaceId': spaceId});
    final result = data['data'];
    if (result is bool) return result;
    return false;
  }

  static Future<String> _md5File(File file) async {
    debugPrint('Pan _md5File start');
    final digest = await md5.bind(file.openRead()).first;
    debugPrint('Pan _md5File done');
    return digest.toString();
  }
}

/// 网盘异常
class PanException implements Exception {
  final int code;
  final String message;

  PanException(this.code, this.message);

  @override
  String toString() => 'PanException($code): $message';
}

/// 上传任务取消令牌
class PanUploadCancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

class _UploadUrlInfo {
  final String uploadUrl;
  final String downloadUrl;
  final String backupUploadUrl;
  final int type;

  _UploadUrlInfo({
    required this.uploadUrl,
    required this.downloadUrl,
    required this.backupUploadUrl,
    required this.type,
  });
}

/// 网盘空间类型
enum PanSpaceType {
  globalPublic,
  userPublic,
  userPrivate,
}

/// 网盘空间信息
class PanSpace {
  final int spaceId;
  final PanSpaceType spaceType;
  final String ownerId;
  final String name;
  final int totalQuota;
  final int usedQuota;
  final int fileCount;
  final int folderCount;
  final bool autoInit;
  final String createdAt;
  final bool canManage;

  PanSpace({
    required this.spaceId,
    required this.spaceType,
    required this.ownerId,
    required this.name,
    required this.totalQuota,
    required this.usedQuota,
    required this.fileCount,
    required this.folderCount,
    required this.autoInit,
    required this.createdAt,
    required this.canManage,
  });

  factory PanSpace.fromJson(Map<String, dynamic> json) {
    final typeValue = json['spaceType'] ?? json['type'] ?? 0;
    final PanSpaceType spaceType;
    if (typeValue is String) {
      spaceType = _parseSpaceType(typeValue);
    } else if (typeValue is int) {
      spaceType = PanSpaceType.values[typeValue.clamp(0, PanSpaceType.values.length - 1)];
    } else {
      spaceType = PanSpaceType.globalPublic;
    }
    return PanSpace(
      spaceId: (json['spaceId'] ?? json['id'] as num?)?.toInt() ?? 0,
      spaceType: spaceType,
      ownerId: json['ownerId'] ?? '',
      name: json['name'] ?? '',
      totalQuota: (json['totalQuota'] as num?)?.toInt() ?? 0,
      usedQuota: (json['usedQuota'] as num?)?.toInt() ?? 0,
      fileCount: json['fileCount'] ?? 0,
      folderCount: json['folderCount'] ?? 0,
      autoInit: json['autoInit'] ?? false,
      createdAt: json['createdAt'] ?? '',
      canManage: json['canManage'] ?? false,
    );
  }

  static PanSpaceType _parseSpaceType(String value) {
    switch (value.toUpperCase()) {
      case 'GLOBAL_PUBLIC':
        return PanSpaceType.globalPublic;
      case 'USER_PUBLIC':
        return PanSpaceType.userPublic;
      case 'USER_PRIVATE':
        return PanSpaceType.userPrivate;
      default:
        return PanSpaceType.globalPublic;
    }
  }
}

/// 网盘文件类型
enum PanFileType { file, folder }

/// 网盘文件信息
class PanFile {
  final int fileId;
  final int spaceId;
  final int parentId;
  final String name;
  final PanFileType type;
  final int size;
  final String? mimeType;
  final String? md5;
  final String? storageUrl;
  final int childCount;
  final String creatorId;
  final String? creatorName;
  final String createdAt;
  final String updatedAt;

  PanFile({
    required this.fileId,
    required this.spaceId,
    required this.parentId,
    required this.name,
    required this.type,
    required this.size,
    this.mimeType,
    this.md5,
    this.storageUrl,
    required this.childCount,
    required this.creatorId,
    this.creatorName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PanFile.fromJson(Map<String, dynamic> json) {
    final typeValue = json['type'] ?? 0;
    return PanFile(
      fileId: json['fileId'] ?? json['id'] ?? 0,
      spaceId: json['spaceId'] ?? 0,
      parentId: json['parentId'] ?? 0,
      name: json['name'] ?? '',
      type: typeValue == 1 ? PanFileType.folder : PanFileType.file,
      size: (json['size'] as num?)?.toInt() ?? 0,
      mimeType: json['mimeType'],
      md5: json['md5'],
      storageUrl: json['storageUrl'],
      childCount: json['childCount'] ?? 0,
      creatorId: json['creatorId'] ?? '',
      creatorName: json['creatorName'],
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
    );
  }

  bool get isFolder => type == PanFileType.folder;

  String get sizeText {
    if (isFolder) return '';
    if (size >= 1073741824) return '${(size / 1073741824).toStringAsFixed(1)} GB';
    if (size >= 1048576) return '${(size / 1048576).toStringAsFixed(1)} MB';
    if (size >= 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '$size B';
  }

  String get extension {
    if (isFolder) return '';
    final idx = name.lastIndexOf('.');
    return idx > 0 ? name.substring(idx + 1).toLowerCase() : '';
  }

  PanIconType get iconType {
    if (isFolder) return PanIconType.folder;
    switch (extension) {
      case 'jpg': case 'jpeg': case 'png': case 'gif': case 'bmp': case 'webp':
        return PanIconType.image;
      case 'mp4': case 'avi': case 'mov': case 'mkv': case 'asf': case 'wmv':
      case 'mpeg': case 'ogg': case 'rmvb': case 'f4v':
        return PanIconType.video;
      case 'mp3': case 'wav': case 'aac': case 'flac': case 'amr': case 'acm':
      case 'aif':
        return PanIconType.audio;
      case 'pdf':
        return PanIconType.pdf;
      case 'doc': case 'docx': case 'pages':
        return PanIconType.word;
      case 'xls': case 'xlsx': case 'numbers':
        return PanIconType.excel;
      case 'ppt': case 'pptx': case 'keynote':
        return PanIconType.ppt;
      case 'html': case 'htm':
        return PanIconType.html;
      case 'txt':
        return PanIconType.text;
      case 'exe':
        return PanIconType.exe;
      case 'xml':
        return PanIconType.xml;
      case 'zip': case 'rar': case '7z': case 'gzip': case 'gz':
        return PanIconType.archive;
      default:
        return PanIconType.file;
    }
  }
}

enum PanIconType { folder, image, video, audio, pdf, word, excel, ppt, html, text, exe, xml, archive, file }
