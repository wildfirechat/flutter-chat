import 'dart:async';

import 'package:imclient/model/file_record.dart';

/// 主窗口侧代理把 Imclient 的 callback 式 API 包装成 Future 的统一助手:
/// 结果统一编成 `{errorCode, ...}` map,经 IPC 回传子窗口后由子窗口侧
/// ProxyImclientChannel 的 dispatch 闭包触发回调。
///
/// 三个方法分别对应子窗口侧的三类 dispatch(字符串结果/文件列表/无参成功),
/// 线格式与其一一对应。
class ProxyCompleter {
  ProxyCompleter._();

  /// 字符串结果类接口(sendMomentsRequest/uploadMedia/getAuthorizedMediaUrl 等):
  /// 成功回传 `{'errorCode': 0, 'result': value}`,
  /// 失败回传 `{'errorCode': errorCode, 'result': null}`。
  static Future<dynamic> stringResult(
    void Function(
      void Function(String value) onSuccess,
      void Function(int errorCode) onFailure,
    ) invoke,
  ) {
    final completer = Completer<dynamic>();
    invoke(
      (value) => completer.complete({'errorCode': 0, 'result': value}),
      (errorCode) =>
          completer.complete({'errorCode': errorCode, 'result': null}),
    );
    return completer.future;
  }

  /// 文件记录列表类接口(getConversationFiles/searchFiles):
  /// 成功回传 `{'errorCode': 0, 'files': [...]}`(经 [encodeRecord] 逐条编码),
  /// 失败回传 `{'errorCode': errorCode}`。
  static Future<dynamic> filesResult(
    void Function(
      void Function(List<FileRecord> files) onSuccess,
      void Function(int errorCode) onFailure,
    ) invoke,
    Map<String, dynamic> Function(FileRecord record) encodeRecord,
  ) {
    final completer = Completer<dynamic>();
    invoke(
      (files) => completer.complete({
        'errorCode': 0,
        'files': files.map(encodeRecord).toList(),
      }),
      (errorCode) => completer.complete({'errorCode': errorCode}),
    );
    return completer.future;
  }

  /// 无参成功回调类接口(deleteFileRecord 等):
  /// 成功回传 `{'errorCode': 0}`,失败回传 `{'errorCode': errorCode}`。
  static Future<dynamic> voidResult(
    void Function(
      void Function() onSuccess,
      void Function(int errorCode) onFailure,
    ) invoke,
  ) {
    final completer = Completer<dynamic>();
    invoke(
      () => completer.complete({'errorCode': 0}),
      (errorCode) => completer.complete({'errorCode': errorCode}),
    );
    return completer.future;
  }
}
