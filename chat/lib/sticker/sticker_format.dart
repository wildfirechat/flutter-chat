import 'dart:typed_data';

/// 贴纸的渲染方式。
///
/// Telegram 贴纸有三种格式:.tgs(gzip 压缩的 Lottie)走 [lottie];.webp 静态贴纸
/// 走 [image];.webm 视频贴纸运行时不支持,由 scripts/stickers/import_telegram_pack.py
/// 导入时转成动态 WebP(原因见该脚本说明)。
enum StickerFormat {
  image,
  lottie;

  static const _imageExtensions = {'.png', '.jpg', '.jpeg', '.gif', '.webp'};

  /// 按扩展名判断,判断不了返回 null。
  ///
  /// 只适合自己打包的 asset:下载缓存文件与对端上传后的地址,扩展名都不可靠,
  /// 那些场景用 [sniff]。Lottie 只认 .tgs,贴纸包目录里的 pack.json 不会被误当成贴纸。
  static StickerFormat? fromPath(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot < path.lastIndexOf('/')) {
      return null;
    }
    final ext = path.substring(dot).toLowerCase();
    if (ext == '.tgs') {
      return lottie;
    }
    return _imageExtensions.contains(ext) ? image : null;
  }

  /// 按文件头判断:gzip → TGS,JSON 对象 → Lottie,其余交给图片解码器。
  static StickerFormat sniff(Uint8List head) {
    if (head.length >= 2 && head[0] == 0x1f && head[1] == 0x8b) {
      return lottie;
    }
    var i = 0;
    // 跳过 UTF-8 BOM 与前导空白
    if (head.length >= 3 &&
        head[0] == 0xef &&
        head[1] == 0xbb &&
        head[2] == 0xbf) {
      i = 3;
    }
    while (i < head.length && _isJsonWhitespace(head[i])) {
      i++;
    }
    return i < head.length && head[i] == 0x7b /* { */ ? lottie : image;
  }

  static bool _isJsonWhitespace(int byte) =>
      byte == 0x20 || byte == 0x09 || byte == 0x0a || byte == 0x0d;
}
