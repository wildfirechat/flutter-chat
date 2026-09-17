#!/usr/bin/env python3
"""把一套 Telegram 贴纸(导出的文件目录)导入为 App 内置贴纸包。

Telegram 贴纸有三种格式:
  .tgs   动态贴纸(gzip 压缩的 Lottie)  → 原样拷贝,App 用 lottie 渲染
  .webp  静态贴纸                       → 原样拷贝
  .webm  视频贴纸(VP9 + alpha 通道)    → 转成带透明通道的动态 WebP

App 端不直接播放 .webm:iOS/macOS 的 AVFoundation 不支持 WebM,其余平台的
播放器也大多丢弃 VP9 的 alpha 通道(透明背景会变黑),而且聊天列表里每个
贴纸挂一个视频播放器代价太高。动态 WebP 六端 Image 组件都能直接解码。

依赖:ffmpeg(需带 libvpx-vp9 解码器,否则 alpha 会丢)、img2webp(libwebp)
用法:
  python3 scripts/stickers/import_telegram_pack.py <导出目录> <包 id> \\
      --title-zh 猫猫 --title-en Cats [--order 100] [--cover 文件名]
贴纸顺序按文件名排序;包 id 即 chat/assets/sticker/ 下的目录名,
导入后记得在 chat/pubspec.yaml 的 assets 里加上该目录。
"""

import argparse
import shutil
import subprocess
import tempfile
from fractions import Fraction
from pathlib import Path

from tgs import STICKER_ASSETS, read_lottie, reset_pack_dir, write_manifest

COPY_AS_IS = {'.tgs', '.webp', '.png', '.gif'}


def _require(tool: str) -> None:
    if shutil.which(tool) is None:
        raise SystemExit(f'找不到 {tool},请先安装(macOS: brew install ffmpeg webp)')


def webm_to_webp(src: Path, dst: Path, quality: int) -> None:
    rate = subprocess.run(
        ['ffprobe', '-v', 'error', '-select_streams', 'v:0',
         '-show_entries', 'stream=avg_frame_rate', '-of', 'csv=p=0', str(src)],
        check=True, capture_output=True, text=True).stdout.strip()
    fps = Fraction(rate) if rate and rate != '0/0' else Fraction(30)
    frame_ms = max(1, round(1000 / fps))

    with tempfile.TemporaryDirectory() as tmp:
        # -c:v 写在 -i 前面才会强制用 libvpx 解码;ffmpeg 自带的 vp9 解码器会丢掉 alpha
        subprocess.run(
            ['ffmpeg', '-v', 'error', '-c:v', 'libvpx-vp9', '-i', str(src),
             '-pix_fmt', 'rgba', f'{tmp}/f_%04d.png'],
            check=True)
        frames = sorted(Path(tmp).glob('f_*.png'))
        if not frames:
            raise SystemExit(f'{src.name} 没有解出任何帧')
        cmd = ['img2webp', '-loop', '0', '-lossy', '-q', str(quality),
               '-d', str(frame_ms)]
        cmd += [str(f) for f in frames]
        cmd += ['-o', str(dst)]
        subprocess.run(cmd, check=True, capture_output=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('source', type=Path, help='Telegram 贴纸文件所在目录')
    parser.add_argument('pack_id', help='包 id(ASCII),即 assets/sticker/ 下的目录名')
    parser.add_argument('--title-zh', required=True)
    parser.add_argument('--title-en', required=True)
    parser.add_argument('--order', type=int, default=100,
                        help='面板里的排序,越小越靠前(内置包是 10、20)')
    parser.add_argument('--cover', help='封面文件名(转换前的),默认第一个')
    parser.add_argument('--quality', type=int, default=80, help='webm 转 webp 的质量')
    args = parser.parse_args()

    if not args.pack_id.isascii() or '/' in args.pack_id:
        raise SystemExit('包 id 只能是 ASCII 目录名')
    sources = sorted(p for p in args.source.iterdir()
                     if p.suffix.lower() in COPY_AS_IS | {'.webm'})
    if not sources:
        raise SystemExit(f'{args.source} 里没有 .tgs/.webp/.webm 贴纸')
    if any(p.suffix.lower() == '.webm' for p in sources):
        _require('ffmpeg')
        _require('ffprobe')
        _require('img2webp')

    pack_dir = reset_pack_dir(args.pack_id)
    files: list[str] = []
    renamed: dict[str, str] = {}
    for src in sources:
        suffix = src.suffix.lower()
        if suffix == '.webm':
            name = f'{src.stem}.webp'
            print(f'  转换 {src.name} → {name}')
            webm_to_webp(src, pack_dir / name, args.quality)
        else:
            name = f'{src.stem}{suffix}'
            if suffix == '.tgs':
                read_lottie(src)  # 提前发现损坏文件
            shutil.copyfile(src, pack_dir / name)
        if name in renamed.values():
            raise SystemExit(f'{src.name} 与其它文件转换后重名:{name}')
        renamed[src.name] = name
        files.append(name)

    cover = renamed.get(args.cover, files[0]) if args.cover else files[0]
    write_manifest(pack_dir, title_zh=args.title_zh, title_en=args.title_en,
                   order=args.order, cover=cover, stickers=files)
    rel = pack_dir.relative_to(STICKER_ASSETS.parent.parent)
    print(f'导入 {len(files)} 个贴纸到 {rel}/')
    print(f'别忘了在 chat/pubspec.yaml 的 flutter.assets 里加上:  - {rel}/')


if __name__ == '__main__':
    main()
