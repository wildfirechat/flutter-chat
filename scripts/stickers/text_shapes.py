"""把一行文字转成 Lottie 矢量路径(字形轮廓),不依赖播放端字体。

Lottie 自带的文字图层要求播放端有对应字体,中文字形在各端表现不一致,
所以直接把字形轮廓烘焙成 shape。TrueType 的二次贝塞尔在 BasePen 里
自动升为三次,Lottie 的切线是相对顶点的偏移量。
"""

from dataclasses import dataclass

from fontTools.pens.basePen import BasePen
from fontTools.pens.boundsPen import BoundsPen
from fontTools.ttLib import TTFont


def _r(value: float) -> float:
    return round(value, 1)


class _LottiePathPen(BasePen):
    """记录字形轮廓;坐标经 transform 映射到画布(y 轴向下)。"""

    def __init__(self, glyph_set, transform):
        super().__init__(glyph_set)
        self._tf = transform
        self.contours: list[dict] = []
        self._v: list[tuple[float, float]] = []
        self._i: list[tuple[float, float]] = []
        self._o: list[tuple[float, float]] = []

    def _moveTo(self, pt):
        self._v, self._i, self._o = [self._tf(pt)], [(0, 0)], [(0, 0)]

    def _lineTo(self, pt):
        self._v.append(self._tf(pt))
        self._i.append((0, 0))
        self._o.append((0, 0))

    def _curveToOne(self, pt1, pt2, pt3):
        last = self._v[-1]
        c1, c2, end = self._tf(pt1), self._tf(pt2), self._tf(pt3)
        self._o[-1] = (c1[0] - last[0], c1[1] - last[1])
        self._v.append(end)
        self._i.append((c2[0] - end[0], c2[1] - end[1]))
        self._o.append((0, 0))

    def _closePath(self):
        # 闭合轮廓最后一个点常与起点重合:合并,把它的入切线挪给起点
        if len(self._v) > 1:
            (x0, y0), (x1, y1) = self._v[0], self._v[-1]
            if abs(x0 - x1) < 1e-6 and abs(y0 - y1) < 1e-6:
                self._i[0] = self._i[-1]
                self._v.pop()
                self._i.pop()
                self._o.pop()
        if len(self._v) > 1:
            self.contours.append({
                'c': True,
                'v': [[_r(x), _r(y)] for x, y in self._v],
                'i': [[_r(x), _r(y)] for x, y in self._i],
                'o': [[_r(x), _r(y)] for x, y in self._o],
            })
        self._v, self._i, self._o = [], [], []

    _endPath = _closePath


@dataclass
class TextShapes:
    contours: list[dict]  # Lottie 路径数据({c, v, i, o})
    left: float
    top: float
    right: float
    bottom: float
    font_size: float

    @property
    def center_x(self) -> float:
        return (self.left + self.right) / 2

    @property
    def center_y(self) -> float:
        return (self.top + self.bottom) / 2


class TextOutliner:
    def __init__(self, font_path):
        self._font = TTFont(font_path)
        self._glyph_set = self._font.getGlyphSet()
        self._cmap = self._font.getBestCmap()
        self._hmtx = self._font['hmtx']
        self._upem = self._font['head'].unitsPerEm

    def _glyphs(self, text: str):
        for ch in text:
            name = self._cmap.get(ord(ch))
            if name is None:
                raise SystemExit(f'字体里没有字符 {ch!r}')
            yield name, self._hmtx[name][0]

    def _ink_bounds(self, text: str):
        """文字按 1 单位字号排版时的墨迹边界(字体坐标,y 向上)。"""
        x = 0
        left = bottom = float('inf')
        right = top = float('-inf')
        for name, advance in self._glyphs(text):
            pen = BoundsPen(self._glyph_set)
            self._glyph_set[name].draw(pen)
            if pen.bounds is not None:
                x_min, y_min, x_max, y_max = pen.bounds
                left, right = min(left, x + x_min), max(right, x + x_max)
                bottom, top = min(bottom, y_min), max(top, y_max)
            x += advance
        return left, bottom, right, top

    def outline(self, text: str, *, center: tuple[float, float],
                max_width: float, max_height: float,
                tracking: float = 0.0) -> TextShapes:
        """把墨迹框缩放进 max_width×max_height 并居中到 center。

        tracking 是字间距,单位为 em(负值收紧)。
        """
        track_units = tracking * self._upem
        n = len(text)
        left, bottom, right, top = self._ink_bounds(text)
        right += track_units * (n - 1)
        scale = min(max_width / (right - left), max_height / (top - bottom))
        cx = center[0] - (left + right) / 2 * scale
        cy = center[1] + (top + bottom) / 2 * scale

        contours: list[dict] = []
        pen_x = 0.0
        for name, advance in self._glyphs(text):
            ox = pen_x

            def tf(pt, ox=ox):
                return cx + (ox + pt[0]) * scale, cy - pt[1] * scale

            pen = _LottiePathPen(self._glyph_set, tf)
            self._glyph_set[name].draw(pen)
            contours.extend(pen.contours)
            pen_x += advance + track_units

        return TextShapes(
            contours=contours,
            left=cx + left * scale,
            right=cx + right * scale,
            top=cy - top * scale,
            bottom=cy - bottom * scale,
            font_size=self._upem * scale,
        )
