
class BackupMetadata {
  String? backupTime;
  String? userId;
  String? deviceName;
  BackupStatistics? statistics;
  List<BackupConversationInfo>? conversations;
  BackupEncryptionInfo? encryption;
  String? backupDir; // Local helper field

  BackupMetadata({
    this.backupTime,
    this.userId,
    this.deviceName,
    this.statistics,
    this.conversations,
    this.encryption,
    this.backupDir,
  });

  factory BackupMetadata.fromJson(Map<String, dynamic> json) {
    return BackupMetadata(
      backupTime: json['backupTime'],
      userId: json['userId'],
      deviceName: json['deviceName'],
      statistics: json['statistics'] != null
          ? BackupStatistics.fromJson(json['statistics'])
          : null,
      conversations: json['conversations'] != null
          ? (json['conversations'] as List)
              .map((e) => BackupConversationInfo.fromJson(e))
              .toList()
          : null,
      encryption: json['encryption'] != null
          ? BackupEncryptionInfo.fromJson(json['encryption'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'backupTime': backupTime,
      'userId': userId,
      'deviceName': deviceName,
      'statistics': statistics?.toJson(),
      'conversations': conversations?.map((e) => e.toJson()).toList(),
      'encryption': encryption?.toJson(),
    };
  }
}

class BackupStatistics {
  int totalConversations;
  int totalMessages;
  int mediaFileCount;
  int mediaTotalSize;
  int firstMessageTime;
  int lastMessageTime;

  BackupStatistics({
    this.totalConversations = 0,
    this.totalMessages = 0,
    this.mediaFileCount = 0,
    this.mediaTotalSize = 0,
    this.firstMessageTime = 0,
    this.lastMessageTime = 0,
  });

  factory BackupStatistics.fromJson(Map<String, dynamic> json) {
    return BackupStatistics(
      totalConversations: json['totalConversations'] ?? 0,
      totalMessages: json['totalMessages'] ?? 0,
      mediaFileCount: json['mediaFileCount'] ?? 0,
      mediaTotalSize: json['mediaTotalSize'] ?? 0,
      firstMessageTime: json['firstMessageTime'] ?? 0,
      lastMessageTime: json['lastMessageTime'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalConversations': totalConversations,
      'totalMessages': totalMessages,
      'mediaFileCount': mediaFileCount,
      'mediaTotalSize': mediaTotalSize,
      'firstMessageTime': firstMessageTime,
      'lastMessageTime': lastMessageTime,
    };
  }
}

class BackupConversationInfo {
  int type;
  String target;
  int line;
  String directory;
  int messageCount;
  int mediaCount;
  int firstMessageTime;
  int lastMessageTime;

  BackupConversationInfo({
    required this.type,
    required this.target,
    required this.line,
    required this.directory,
    this.messageCount = 0,
    this.mediaCount = 0,
    this.firstMessageTime = 0,
    this.lastMessageTime = 0,
  });

  factory BackupConversationInfo.fromJson(Map<String, dynamic> json) {
    return BackupConversationInfo(
      type: json['type'],
      target: json['target'],
      line: json['line'],
      directory: json['directory'],
      messageCount: json['messageCount'] ?? 0,
      mediaCount: json['mediaCount'] ?? 0,
      firstMessageTime: json['firstMessageTime'] ?? 0,
      lastMessageTime: json['lastMessageTime'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'target': target,
      'line': line,
      'directory': directory,
      'messageCount': messageCount,
      'mediaCount': mediaCount,
      'firstMessageTime': firstMessageTime,
      'lastMessageTime': lastMessageTime,
    };
  }
}

class BackupEncryptionInfo {
  bool enabled;
  String? hint;

  BackupEncryptionInfo({
    required this.enabled,
    this.hint,
  });

  factory BackupEncryptionInfo.fromJson(Map<String, dynamic> json) {
    return BackupEncryptionInfo(
      enabled: json['enabled'] ?? false,
      hint: json['hint'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'hint': hint,
    };
  }
}

class BackupProgress {
  int total;
  int current;
  String phase;

  BackupProgress({
    required this.total,
    this.current = 0,
    this.phase = '',
  });

  void increment() {
    current++;
  }
}

class BackupMessage {
  int messageUid;
  String fromUser;
  List<String>? toUsers;
  int direction;
  int status;
  int timestamp;
  String localExtra;
  BackupMessagePayload? payload;
  int mediaFileSize;

  BackupMessage({
    this.messageUid = 0,
    this.fromUser = '',
    this.toUsers,
    this.direction = 0,
    this.status = 0,
    this.timestamp = 0,
    this.localExtra = '',
    this.payload,
    this.mediaFileSize = 0,
  });

  factory BackupMessage.fromJson(Map<String, dynamic> json) {
    return BackupMessage(
      messageUid: json['messageUid'] ?? 0,
      fromUser: json['fromUser'] ?? '',
      toUsers: json['toUsers'] != null ? List<String>.from(json['toUsers']) : null,
      direction: json['direction'] ?? 0,
      status: json['status'] ?? 0,
      timestamp: json['timestamp'] ?? 0,
      localExtra: json['localExtra'] ?? '',
      payload: json['payload'] != null ? BackupMessagePayload.fromJson(json['payload']) : null,
      mediaFileSize: json['mediaFileSize'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messageUid': messageUid,
      'fromUser': fromUser,
      'toUsers': toUsers,
      'direction': direction,
      'status': status,
      'timestamp': timestamp,
      'localExtra': localExtra,
      'payload': payload?.toJson(),
      'mediaFileSize': mediaFileSize,
    };
  }
}

class BackupMessagePayload {
  int contentType;
  String searchableContent;
  String pushContent;
  String pushData;
  String content;
  String binaryContent; // Base64 encoded
  String localContent;
  int mentionedType;
  List<String>? mentionedTargets;
  String extra;
  bool notLoaded;
  int mediaType;
  String remoteMediaUrl;
  BackupMediaInfo? localMediaInfo;

  BackupMessagePayload({
    this.contentType = 0,
    this.searchableContent = '',
    this.pushContent = '',
    this.pushData = '',
    this.content = '',
    this.binaryContent = '',
    this.localContent = '',
    this.mentionedType = 0,
    this.mentionedTargets,
    this.extra = '',
    this.notLoaded = false,
    this.mediaType = 0,
    this.remoteMediaUrl = '',
    this.localMediaInfo,
  });

  factory BackupMessagePayload.fromJson(Map<String, dynamic> json) {
    return BackupMessagePayload(
      contentType: json['contentType'] ?? 0,
      searchableContent: json['searchableContent'] ?? '',
      pushContent: json['pushContent'] ?? '',
      pushData: json['pushData'] ?? '',
      content: json['content'] ?? '',
      binaryContent: json['binaryContent'] ?? '',
      localContent: json['localContent'] ?? '',
      mentionedType: json['mentionedType'] ?? 0,
      mentionedTargets: json['mentionedTargets'] != null ? List<String>.from(json['mentionedTargets']) : null,
      extra: json['extra'] ?? '',
      notLoaded: json['notLoaded'] ?? false,
      mediaType: json['mediaType'] ?? 0,
      remoteMediaUrl: json['remoteMediaUrl'] ?? '',
      localMediaInfo: json['localMediaInfo'] != null ? BackupMediaInfo.fromJson(json['localMediaInfo']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'contentType': contentType,
      'searchableContent': searchableContent,
      'pushContent': pushContent,
      'pushData': pushData,
      'content': content,
      'binaryContent': binaryContent,
      'localContent': localContent,
      'mentionedType': mentionedType,
      'mentionedTargets': mentionedTargets,
      'extra': extra,
      'notLoaded': notLoaded,
      'mediaType': mediaType,
      'remoteMediaUrl': remoteMediaUrl,
      'localMediaInfo': localMediaInfo?.toJson(),
    };
  }
}

class BackupMediaInfo {
  String fileName;
  String fileId;
  int fileSize;
  String md5;
  String relativePath;

  BackupMediaInfo({
    this.fileName = '',
    this.fileId = '',
    this.fileSize = 0,
    this.md5 = '',
    this.relativePath = '',
  });

  factory BackupMediaInfo.fromJson(Map<String, dynamic> json) {
    return BackupMediaInfo(
      fileName: json['fileName'] ?? '',
      fileId: json['fileId'] ?? '',
      fileSize: json['fileSize'] ?? 0,
      md5: json['md5'] ?? '',
      relativePath: json['relativePath'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fileName': fileName,
      'fileId': fileId,
      'fileSize': fileSize,
      'md5': md5,
      'relativePath': relativePath,
    };
  }
}

class PCBackupInfo {
  String? name;
  String? time;
  String? path;
  int fileCount;
  int conversationCount;
  int messageCount;
  int mediaFileCount;

  PCBackupInfo({
    this.name,
    this.time,
    this.path,
    this.fileCount = 0,
    this.conversationCount = 0,
    this.messageCount = 0,
    this.mediaFileCount = 0,
  });

  factory PCBackupInfo.fromJson(Map<String, dynamic> json) {
    return PCBackupInfo(
      name: json['name'],
      time: json['time'],
      path: json['path'],
      fileCount: json['fileCount'] ?? 0,
      conversationCount: json['conversationCount'] ?? 0,
      messageCount: json['messageCount'] ?? 0,
      mediaFileCount: json['mediaFileCount'] ?? 0,
    );
  }
}
