/// 贴纸从哪里来。值语义,可直接作缓存 key。
sealed class StickerSource {
  const StickerSource();

  /// 打包进 App 的贴纸,[path] 为 asset key(如 assets/sticker/noto_emoji/1f44d.tgs)。
  const factory StickerSource.asset(String path) = AssetStickerSource;

  /// 本地文件,比如自己刚发出去、还没被系统清掉的临时文件。
  const factory StickerSource.file(String path) = FileStickerSource;

  /// 远端贴纸,下载走磁盘缓存;[url] 传原始地址,双网前缀转换在下载时做。
  const factory StickerSource.network(String url) = NetworkStickerSource;
}

final class AssetStickerSource extends StickerSource {
  const AssetStickerSource(this.path);

  final String path;

  @override
  bool operator ==(Object other) =>
      other is AssetStickerSource && other.path == path;

  @override
  int get hashCode => Object.hash(AssetStickerSource, path);

  @override
  String toString() => 'StickerSource.asset($path)';
}

final class FileStickerSource extends StickerSource {
  const FileStickerSource(this.path);

  final String path;

  @override
  bool operator ==(Object other) =>
      other is FileStickerSource && other.path == path;

  @override
  int get hashCode => Object.hash(FileStickerSource, path);

  @override
  String toString() => 'StickerSource.file($path)';
}

final class NetworkStickerSource extends StickerSource {
  const NetworkStickerSource(this.url);

  final String url;

  @override
  bool operator ==(Object other) =>
      other is NetworkStickerSource && other.url == url;

  @override
  int get hashCode => Object.hash(NetworkStickerSource, url);

  @override
  String toString() => 'StickerSource.network($url)';
}
