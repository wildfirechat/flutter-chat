#!/usr/bin/env python3
"""生成 App 内置的两套 TGS 贴纸包(输出到 chat/assets/sticker/)。

  office_phrases  职场用语:常用回复短语 + 对应的 Noto 动态表情
  noto_emoji      动态表情:挑选的办公常用 Noto 动态表情

素材来源与许可:
  - Noto Animated Emoji(Google),CC BY 4.0,转存为 TGS,职场用语里与文字合成。
  - 思源黑体 Noto Sans SC(Black 字重),SIL OFL 1.1,仅把字形轮廓烘焙进动画。

依赖:pip install fonttools
用法:python3 scripts/stickers/build_builtin_packs.py [office_phrases|noto_emoji ...]
"""

import math
import shutil
import sys
from pathlib import Path

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

from tgs import (CACHE_DIR, fetch_cached, read_lottie, reset_pack_dir,
                 write_manifest, write_tgs)
from text_shapes import TextOutliner

SCRIPT_DIR = Path(__file__).resolve().parent

# 钉在具体提交上,保证重新生成的字形一致
FONT_URL = ('https://raw.githubusercontent.com/google/fonts/'
            '2894aab31764f10f29c421bdfd2340d3b382d384/ofl/notosanssc/'
            'NotoSansSC%5Bwght%5D.ttf')
FONT_SHA256 = 'a3041811a78c361b1de50f953c805e0244951c21c5bd412f7232ef0d899af0da'
NOTO_URL = 'https://fonts.gstatic.com/s/e/notoemoji/latest/{}/lottie.json'

# ── 动态表情:(Noto 码点, 含义)。顺序即面板顺序,高频的放前面 ──────────────
NOTO_EMOJI_PACK = [
    ('1f44d', '点赞'), ('1f44c', 'OK'), ('1f64f', '拜托/感谢'), ('1f44f', '鼓掌'),
    ('1f4aa', '加油'), ('1fae1', '收到'), ('1f91d', '握手'), ('1f64c', '欢呼'),
    ('1f389', '撒花'), ('1f4af', '满分'), ('1f525', '火'), ('1f680', '起飞'),
    ('2705', '完成'), ('1faf6', '比心'), ('2764_fe0f', '爱心'), ('1f44b', '你好'),
    ('1f60a', '微笑'), ('1f602', '笑哭'), ('1f923', '笑翻'), ('1f605', '尴尬'),
    ('1f914', '思考'), ('1f440', '围观'), ('1f92f', '头大'), ('1f97a', '可怜'),
    ('1f62d', '大哭'), ('1f621', '生气'), ('1f631', '惊恐'), ('1fae0', '融化'),
    ('1f634', '困'), ('1f971', '哈欠'), ('1f60e', '酷'), ('1f973', '庆祝'),
    ('1f917', '抱抱'), ('1f929', '崇拜'), ('1f60f', '坏笑'), ('1f648', '捂脸'),
    ('1f910', '闭嘴'), ('270c_fe0f', '耶'), ('1f91e', '好运'), ('2615', '咖啡'),
    ('1f4a1', '灵感'), ('1f4c8', '增长'), ('23f0', '闹钟'), ('1f3c6', '奖杯'),
    ('1f382', '生日'), ('1f381', '礼物'), ('1f339', '玫瑰'), ('1f37b', '干杯'),
]

# ── 职场用语:(短语, Noto 码点, 主色, 文字动效) ─────────────────────────────
BLUE, GREEN, TEAL, AMBER = '#1677FF', '#16A34A', '#0D9488', '#F59E0B'
ORANGE, RED, PINK, PURPLE = '#F97316', '#EF4444', '#EC4899', '#8B5CF6'
INDIGO, SLATE = '#4F46E5', '#475569'

OFFICE_PHRASES_PACK = [
    ('收到', '1fae1', BLUE, 'pop'),
    ('好的', '1f60a', GREEN, 'pop'),
    ('没问题', '1f44c', TEAL, 'pop'),
    ('同意', '1f44d', BLUE, 'pop'),
    ('明白', '1f4a1', AMBER, 'pop'),
    ('已完成', '2705', GREEN, 'bounce'),
    ('马上办', '26a1', ORANGE, 'shake'),
    ('稍等', '23f0', PURPLE, 'swing'),
    ('开会中', '1f910', SLATE, 'pulse'),
    ('我看看', '1f440', INDIGO, 'swing'),
    ('请查收', '1f381', AMBER, 'bounce'),
    ('欢迎', '1f91d', BLUE, 'pop'),
    ('辛苦了', '1f4aa', ORANGE, 'pulse'),
    ('谢谢', '1f64f', PINK, 'pulse'),
    ('加油', '1f525', RED, 'pulse'),
    ('太棒了', '1f44f', ORANGE, 'swing'),
    ('666', '1f64c', RED, 'shake'),
    ('恭喜', '1f389', RED, 'swing'),
    ('冲鸭', '1f680', RED, 'shake'),
    ('拜托了', '1f97a', PURPLE, 'pulse'),
    ('抱歉', '1f605', BLUE, 'swing'),
    ('头大', '1f92f', PURPLE, 'shake'),
    ('早上好', '1f31e', AMBER, 'bounce'),
    ('下班啦', '1f973', TEAL, 'bounce'),
]

CANVAS = 512
EMOJI_BOX = 300          # 表情显示边长
EMOJI_CENTER_Y = 170
TEXT_CENTER_Y = 420
TEXT_MAX_WIDTH = 410
TEXT_MAX_HEIGHT = 128
MIN_LOOP_SECONDS = 2.0   # 整段循环不短于 2s,文字动效不至于太频繁


# ── Lottie 构造工具 ──────────────────────────────────────────────────────────

def static(value):
    return {'a': 0, 'k': value}


def keyframes(points, fr):
    """points: [(秒, 值)],值为数值或列表;相邻关键帧之间缓入缓出。"""
    k = []
    for idx, (sec, value) in enumerate(points):
        frame = {'t': round(sec * fr, 2),
                 's': value if isinstance(value, list) else [value]}
        if idx < len(points) - 1:
            frame['o'] = {'x': 0.33, 'y': 0}
            frame['i'] = {'x': 0.67, 'y': 1}
        k.append(frame)
    return {'a': 1, 'k': k}


def rgb(hex_color, alpha=1.0):
    h = hex_color.lstrip('#')
    return [round(int(h[i:i + 2], 16) / 255, 4) for i in (0, 2, 4)] + [alpha]


def lighten(hex_color, amount):
    r, g, b, _ = rgb(hex_color)
    return [round(c + (1 - c) * amount, 4) for c in (r, g, b)]


def group(name, items, offset=(0, 0)):
    return {
        'ty': 'gr', 'nm': name,
        'it': items + [{
            'ty': 'tr', 'p': static(list(offset)), 'a': static([0, 0]),
            's': static([100, 100]), 'r': static(0), 'o': static(100),
            'sk': static(0), 'sa': static(0),
        }],
    }


def transform(anchor, position=None, scale=None, rotation=None, opacity=None):
    return {
        'o': opacity or static(100),
        'r': rotation or static(0),
        'p': position or static([anchor[0], anchor[1], 0]),
        'a': static([anchor[0], anchor[1], 0]),
        's': scale or static([100, 100, 100]),
    }


def motion_transform(motion, anchor, fr):
    """文字动效。第 0 帧必须是静止状态:面板封面与静态缩略图取的是第 0 帧。"""
    ax, ay = anchor
    if motion == 'pop':
        return transform(anchor, scale=keyframes([
            (0, [100, 100, 100]), (0.10, [90, 90, 100]),
            (0.26, [114, 114, 100]), (0.40, [96, 96, 100]),
            (0.52, [100, 100, 100])], fr))
    if motion == 'pulse':
        return transform(anchor, scale=keyframes([
            (0, [100, 100, 100]), (0.14, [110, 110, 100]),
            (0.28, [100, 100, 100]), (0.42, [107, 107, 100]),
            (0.58, [100, 100, 100])], fr))
    if motion == 'swing':
        return transform(anchor, rotation=keyframes([
            (0, 0), (0.16, -7), (0.36, 6), (0.54, -3), (0.70, 0)], fr))
    if motion == 'shake':
        offsets = [0, 10, -10, 8, -8, 5, -5, 0]
        return transform(anchor, position=keyframes(
            [(i * 0.06, [ax + dx, ay, 0]) for i, dx in enumerate(offsets)], fr))
    if motion == 'bounce':
        return transform(
            anchor,
            position=keyframes([
                (0, [ax, ay, 0]), (0.16, [ax, ay - 26, 0]),
                (0.32, [ax, ay, 0]), (0.42, [ax, ay - 9, 0]),
                (0.52, [ax, ay, 0])], fr),
            scale=keyframes([
                (0, [100, 100, 100]), (0.30, [100, 100, 100]),
                (0.35, [108, 92, 100]), (0.46, [100, 100, 100])], fr))
    raise SystemExit(f'未知动效 {motion}')


# ── 素材 ────────────────────────────────────────────────────────────────────

def black_font() -> Path:
    path = CACHE_DIR / 'NotoSansSC-Black.ttf'
    if not path.exists():
        variable = fetch_cached(FONT_URL, 'NotoSansSC[wght].ttf', FONT_SHA256)
        print('  实例化 Black 字重')
        instancer.instantiateVariableFont(TTFont(variable), {'wght': 900}).save(path)
    return path


def noto_lottie(codepoint: str) -> dict:
    return read_lottie(fetch_cached(NOTO_URL.format(codepoint), f'noto_{codepoint}.json'))


# ── 职场用语 ────────────────────────────────────────────────────────────────

def office_sticker(outliner, phrase, codepoint, color, motion):
    emoji = noto_lottie(codepoint)
    fr = emoji['fr']
    loop = emoji['op'] - emoji['ip']
    repeats = max(1, math.ceil(MIN_LOOP_SECONDS * fr / loop))
    total = loop * repeats

    text = outliner.outline(phrase, center=(CANVAS / 2, TEXT_CENTER_Y),
                            max_width=TEXT_MAX_WIDTH, max_height=TEXT_MAX_HEIGHT,
                            tracking=-0.02)
    stroke = min(30.0, max(16.0, text.font_size * 0.17))
    paths = [{'ty': 'sh', 'ks': static(c)} for c in text.contours]
    face = group('face', paths + [
        {'ty': 'gf', 'o': static(100), 'r': 1, 't': 1,
         's': static([text.center_x, text.top]),
         'e': static([text.center_x, text.bottom]),
         'g': {'p': 2, 'k': static([0, *lighten(color, 0.22), 1, *rgb(color)[:3]])}},
        {'ty': 'st', 'c': static([1, 1, 1, 1]), 'o': static(100), 'w': static(stroke),
         'lc': 2, 'lj': 2, 'ml': 4},
    ])
    shadow = group('shadow', paths + [
        {'ty': 'fl', 'c': static([0, 0, 0, 1]), 'o': static(22), 'r': 1},
        {'ty': 'st', 'c': static([0, 0, 0, 1]), 'o': static(22),
         'w': static(stroke + 4), 'lc': 2, 'lj': 2, 'ml': 4},
    ], offset=(0, max(5.0, stroke * 0.3)))

    # swing 绕文字底边中点摆动,其余绕中心
    anchor = ((text.center_x, text.bottom) if motion == 'swing'
              else (text.center_x, text.center_y))
    layers = [{
        'ddd': 0, 'ind': 1, 'ty': 4, 'nm': phrase, 'sr': 1, 'ao': 0,
        'ks': motion_transform(motion, anchor, fr),
        'shapes': [face, shadow],
        'ip': 0, 'op': total, 'st': 0, 'bm': 0,
    }]

    # 表情预合成首尾相接重复 repeats 次,凑够整段循环
    ew, eh = emoji['w'], emoji['h']
    scale = EMOJI_BOX / max(ew, eh) * 100
    for i in range(repeats):
        layers.append({
            'ddd': 0, 'ind': 2 + i, 'ty': 0, 'nm': f'emoji {codepoint}',
            'refId': 'wfc_emoji', 'sr': 1, 'ao': 0,
            'ks': transform((ew / 2, eh / 2),
                            position=static([CANVAS / 2, EMOJI_CENTER_Y, 0]),
                            scale=static([scale, scale, 100])),
            'w': ew, 'h': eh,
            'ip': i * loop, 'op': (i + 1) * loop, 'st': i * loop - emoji['ip'],
            'bm': 0,
        })

    assets = list(emoji.get('assets', []))
    if any(a.get('id') == 'wfc_emoji' for a in assets):
        raise SystemExit(f'{codepoint} 的资源 id 与预合成冲突')
    assets.append({'id': 'wfc_emoji', 'layers': emoji['layers']})

    return {
        'tgs': 1, 'v': emoji.get('v', '5.7.4'), 'fr': fr, 'ip': 0, 'op': total,
        'w': CANVAS, 'h': CANVAS, 'nm': phrase, 'ddd': 0,
        'assets': assets, 'layers': layers,
    }


def build_office_phrases():
    print('职场用语 office_phrases')
    outliner = TextOutliner(black_font())
    pack_dir = reset_pack_dir('office_phrases')
    files, total = [], 0
    for phrase, codepoint, color, motion in OFFICE_PHRASES_PACK:
        name = f'{phrase}.tgs'
        total += write_tgs(pack_dir / name,
                           office_sticker(outliner, phrase, codepoint, color, motion))
        files.append(name)
    write_manifest(pack_dir, title_zh='职场用语', title_en='Office Phrases',
                   order=10, cover=files[0], stickers=files)
    shutil.copy(SCRIPT_DIR / 'NOTICE_NOTO_EMOJI.txt', pack_dir / 'NOTICE.txt')
    print(f'  {len(files)} 个,共 {total / 1024:.0f} KB')


# ── 动态表情 ────────────────────────────────────────────────────────────────

def build_noto_emoji():
    print('动态表情 noto_emoji')
    pack_dir = reset_pack_dir('noto_emoji')
    files, total = [], 0
    for codepoint, _meaning in NOTO_EMOJI_PACK:
        composition = noto_lottie(codepoint)
        composition['tgs'] = 1
        name = f'{codepoint}.tgs'
        total += write_tgs(pack_dir / name, composition)
        files.append(name)
    write_manifest(pack_dir, title_zh='动态表情', title_en='Animated Emoji',
                   order=20, cover=files[0], stickers=files)
    shutil.copy(SCRIPT_DIR / 'NOTICE_NOTO_EMOJI.txt', pack_dir / 'NOTICE.txt')
    print(f'  {len(files)} 个,共 {total / 1024:.0f} KB')


BUILDERS = {'office_phrases': build_office_phrases, 'noto_emoji': build_noto_emoji}

if __name__ == '__main__':
    targets = sys.argv[1:] or list(BUILDERS)
    for target in targets:
        if target not in BUILDERS:
            raise SystemExit(f'未知贴纸包 {target},可选:{", ".join(BUILDERS)}')
        BUILDERS[target]()
