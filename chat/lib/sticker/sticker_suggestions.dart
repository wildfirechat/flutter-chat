import 'sticker_pack.dart';

/// 输入联想贴纸(微信"表情联想"):按关键词给输入框里的文字找贴纸。
///
/// 只拿整段输入去比,不在句子里挑词:联想出的贴纸点一下会替换掉整段输入发出去,
/// 句子里带个"好的"就弹贴纸只会打扰。命中规则按优先级:
///   1. 与关键词相同;
///   2. 是关键词的开头,如"早上" → 早上好;
///   3. 是关键词的一部分,如"B数" → 心里没有一点B数吗。
/// 2、3 要求输入至少两个字符,单字太容易误中。同一档内按面板顺序(包顺序、包内顺序)。
///
/// 比较前去掉首尾空白、统一小写,并去掉 emoji 变体选择符 U+FE0F:
/// 系统键盘打出的 ❤️ 带它,表情面板里的 ✌ 不带,两边要算同一个。
class StickerSuggestions {
  StickerSuggestions(List<StickerPack> packs)
      : _packs = packs,
        _entries = [
          for (final pack in packs)
            for (final path in pack.stickerPaths)
              if (pack.keywords[path] case final words?)
                (path: path, keywords: words.map(_normalize).toList()),
        ];

  /// 联想条放不下太多,再多也翻不到
  static const int maxResults = 16;

  final List<StickerPack> _packs;
  final List<({String path, List<String> keywords})> _entries;

  static StickerSuggestions? _current;

  /// 基于 [StickerPacks.loaded] 的索引;贴纸包加载完成后换成新的。
  static StickerSuggestions get current {
    final packs = StickerPacks.loaded;
    final cached = _current;
    if (cached != null && identical(cached._packs, packs)) {
      return cached;
    }
    return _current = StickerSuggestions(packs);
  }

  /// 命中的贴纸 asset 路径,按优先级排好;没有命中返回空列表。
  List<String> match(String text) {
    final query = _normalize(text);
    if (query.isEmpty) {
      return const [];
    }
    final allowPartial = query.runes.length >= 2;
    final exact = <String>[];
    final prefix = <String>[];
    final partial = <String>[];
    for (final entry in _entries) {
      if (entry.keywords.contains(query)) {
        exact.add(entry.path);
      } else if (!allowPartial) {
        continue;
      } else if (entry.keywords.any((k) => k.startsWith(query))) {
        prefix.add(entry.path);
      } else if (entry.keywords.any((k) => k.contains(query))) {
        partial.add(entry.path);
      }
    }
    if (exact.isEmpty && prefix.isEmpty && partial.isEmpty) {
      return const [];
    }
    return [...exact, ...prefix, ...partial]
        .take(maxResults)
        .toList(growable: false);
  }

  static String _normalize(String text) =>
      text.trim().replaceAll('️', '').toLowerCase();
}
