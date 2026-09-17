# 贴纸包工具

App 的贴纸面板读取 `chat/assets/sticker/` 下的目录,每个目录是一套贴纸包。运行时代码在 `chat/lib/sticker/`。

## 支持的格式

| 格式 | 来源 | App 端处理 |
| --- | --- | --- |
| `.tgs` | Telegram 动态贴纸(gzip 压缩的 Lottie) | `lottie` 渲染,后台 isolate 解析 |
| `.webp` / `.png` / `.jpg` / `.gif` | Telegram 静态贴纸、普通图片、动图 | Flutter `Image` 解码 |
| `.webm` | Telegram 视频贴纸(VP9 + alpha) | **不直接支持**,导入时转成带透明通道的动态 WebP |

收到的远端贴纸按文件头判断格式(gzip → TGS,JSON → Lottie,其余当图片),不依赖 URL 扩展名。

## 贴纸包目录

```
chat/assets/sticker/office_phrases/
  pack.json        标题、排序、封面、贴纸顺序、联想关键词
  收到.tgs ...
  NOTICE.txt       素材许可声明(不会显示在面板里)
```

`pack.json` 字段见 `chat/lib/sticker/sticker_pack.dart`。没有 `pack.json` 的旧目录(`B数`、`程序员`)按文件名排序,封面取 `assets/sticker/<目录名>.<扩展名>`。

### 输入联想

输入框里整段文字命中贴纸关键词时,输入栏上方浮出候选贴纸,点一下发送并清空输入(微信"表情联想")。匹配规则见 `chat/lib/sticker/sticker_suggestions.dart`。

- 有 `pack.json` 的包:关键词只看 `keywords` 字段(文件名 → 关键词列表),没列出的贴纸不参与联想。职场用语是短语本身;动态表情是脚本里的含义(`/` 分隔)加上表情字符,所以输入 👍 也能联想到动态版。
- 旧目录:文件名(去掉扩展名)就是配字,直接当关键词。
- `import_telegram_pack.py` 导入的包不写关键词(文件名多是编号),需要联想时手动在 `pack.json` 里补 `keywords`,重新导入会覆盖。

**新增目录要在 `chat/pubspec.yaml` 的 `flutter.assets` 里登记**(assets 不递归),并且要重新 `flutter run`,热重载不会带上新资源。

## 内置贴纸包

```bash
pip3 install fonttools
python3 scripts/stickers/build_builtin_packs.py              # 两套都生成
python3 scripts/stickers/build_builtin_packs.py office_phrases
```

- `office_phrases` 职场用语:24 个常用回复短语,每个配一个 Noto 动态表情。短语、表情、颜色、文字动效都在脚本顶部的 `OFFICE_PHRASES_PACK` 里改。
- `noto_emoji` 动态表情:48 个办公常用 Noto 动态表情,列表在 `NOTO_EMOJI_PACK`。

字形轮廓直接烘焙进动画,播放端不需要字体。文字动效的第 0 帧必须是静止完整画面,面板标签页封面显示的是第 0 帧。下载的字体、表情缓存在 `.cache/`(已 gitignore)。输出是确定性的,内容不变时重新生成不会产生 git 改动。

### 素材许可

- [Noto Animated Emoji](https://googlefonts.github.io/noto-emoji-animation/):CC BY 4.0,**商用需署名**。每个包目录里已附 `NOTICE.txt`,正式发布前还要在 App 内可见的位置(如"关于"页)注明。
- [思源黑体 Noto Sans SC](https://github.com/google/fonts/tree/main/ofl/notosanssc):SIL OFL 1.1,只使用了字形轮廓。

## 导入 Telegram 贴纸包

先用任意 Telegram 贴纸导出工具把整套贴纸下载成文件,再:

```bash
brew install ffmpeg webp        # 只有包含 .webm 视频贴纸时需要
python3 scripts/stickers/import_telegram_pack.py ~/Downloads/cats cats \
    --title-zh 猫猫 --title-en Cats --order 30
```

然后把 `- assets/sticker/cats/` 加进 `chat/pubspec.yaml`。注意贴纸本身的版权归原作者,商用前要确认授权。

## 跨端兼容

贴纸消息发出去的是贴纸文件本身。其它端(原生 Android/iOS、Web、Electron PC)目前只按图片渲染贴纸,收到 `.tgs` 会显示不出来,需要各端同样接入 Lottie(如 lottie-android、lottie-ios、lottie-web)并按文件头识别 gzip。
