"""TGS(Telegram 动态贴纸)与贴纸包目录的读写工具。

TGS 就是 gzip 压缩的 Lottie JSON。这里固定 gzip 头里的 mtime/文件名,
同样的输入每次生成字节完全一致,重新生成贴纸包时 git 只会看到真正变化的文件。
"""

import gzip
import hashlib
import io
import json
import os
import shutil
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
STICKER_ASSETS = REPO_ROOT / 'chat' / 'assets' / 'sticker'
CACHE_DIR = Path(__file__).resolve().parent / '.cache'

PACK_MANIFEST = 'pack.json'


def dump_lottie(composition: dict) -> bytes:
    return json.dumps(composition, ensure_ascii=False,
                      separators=(',', ':')).encode('utf-8')


def write_tgs(path: Path, composition: dict) -> int:
    buf = io.BytesIO()
    with gzip.GzipFile(filename='', mode='wb', fileobj=buf, compresslevel=9,
                       mtime=0) as f:
        f.write(dump_lottie(composition))
    data = buf.getvalue()
    path.write_bytes(data)
    return len(data)


def read_lottie(path: Path) -> dict:
    data = path.read_bytes()
    if data[:2] == b'\x1f\x8b':
        data = gzip.decompress(data)
    return json.loads(data)


def reset_pack_dir(pack_id: str) -> Path:
    """贴纸包目录整个由脚本生成,先清空,避免删掉的贴纸残留在 assets 里。"""
    pack_dir = STICKER_ASSETS / pack_id
    if pack_dir.exists():
        shutil.rmtree(pack_dir)
    pack_dir.mkdir(parents=True)
    return pack_dir


def write_manifest(pack_dir: Path, *, title_zh: str, title_en: str, order: int,
                   cover: str, stickers: list[str]) -> None:
    """pack.json 的字段含义见 chat/lib/sticker/sticker_pack.dart。"""
    manifest = {
        'title': {'zh': title_zh, 'en': title_en},
        'order': order,
        'cover': cover,
        'stickers': stickers,
    }
    (pack_dir / PACK_MANIFEST).write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + '\n',
        encoding='utf-8')


def fetch_cached(url: str, name: str, sha256: str | None = None) -> Path:
    """下载到 .cache(已 gitignore),命中缓存不再联网。给了 sha256 就校验。"""
    CACHE_DIR.mkdir(exist_ok=True)
    path = CACHE_DIR / name
    if not path.exists():
        print(f'  下载 {url}')
        tmp = path.with_suffix(path.suffix + '.part')
        with urllib.request.urlopen(url, timeout=120) as resp, open(tmp, 'wb') as f:
            shutil.copyfileobj(resp, f)
        os.replace(tmp, path)
    if sha256 is not None:
        actual = hashlib.sha256(path.read_bytes()).hexdigest()
        if actual != sha256:
            path.unlink()
            raise SystemExit(f'{name} 校验失败:期望 {sha256},实际 {actual}')
    return path
