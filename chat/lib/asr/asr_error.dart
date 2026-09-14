/// 实时语音输入与语音转文字的错误类型。
///
/// 这一层不产出界面文案，由界面按 [AsrError.kind] 映射成本地化提示，见 voice_input_button.dart。
enum AsrErrorKind {
  /// 没有配置实时语音输入服务地址
  notConfigured,

  /// 没有麦克风权限
  noPermission,

  /// 录音失败，[AsrError.detail] 是底层错误信息
  recordFailed,

  /// 获取 IM 认证码失败，[AsrError.detail] 是错误码
  authCodeFailed,

  /// 语音识别服务鉴权失败（asr-api 返回 401）
  unauthorized,

  /// 连接语音识别服务失败，[AsrError.detail] 是底层错误信息
  connectFailed,

  /// 连接语音识别服务超时
  connectTimeout,

  /// 连接被断开
  disconnected,
}

class AsrError implements Exception {
  const AsrError(this.kind, [this.detail]);

  final AsrErrorKind kind;
  final String? detail;

  @override
  String toString() => detail == null
      ? 'AsrError(${kind.name})'
      : 'AsrError(${kind.name}, $detail)';
}
