import '../config.dart';

/// 双网媒体 URL 前缀转换器。
///
/// 参考 iOS [WFRedirector]，当 [Config.MAIN_MEDIA_URL_PREFIX] 与
/// [Config.BACKUP_MEDIA_URL_PREFIX] 均配置时，根据当前网络环境把 URL
/// 中的主/备前缀互换。
class MediaUrlRedirector {
  const MediaUrlRedirector._();

  static bool _connectedToMainNetwork = true;

  /// 更新当前连接的网络类型。
  /// [mainNetwork] 为 true 表示连接在主网，false 表示连接在备网。
  static void setConnectedToMainNetwork(bool mainNetwork) {
    _connectedToMainNetwork = mainNetwork;
  }

  /// 转换媒体类 URL（头像、图片、视频、文件等）。
  /// 未配置主备前缀时原样返回。
  static String redirect(String originalUrl) {
    final mainPrefix = Config.MAIN_MEDIA_URL_PREFIX;
    final backupPrefix = Config.BACKUP_MEDIA_URL_PREFIX;
    if (mainPrefix == null ||
        backupPrefix == null ||
        mainPrefix.isEmpty ||
        backupPrefix.isEmpty) {
      return originalUrl;
    }

    if (_connectedToMainNetwork) {
      // 主网下，把备网地址前缀替换成主网。
      if (originalUrl.startsWith(backupPrefix)) {
        return mainPrefix + originalUrl.substring(backupPrefix.length);
      }
    } else {
      // 备网下，把主网地址前缀替换成备网。
      if (originalUrl.startsWith(mainPrefix)) {
        return backupPrefix + originalUrl.substring(mainPrefix.length);
      }
    }
    return originalUrl;
  }
}
