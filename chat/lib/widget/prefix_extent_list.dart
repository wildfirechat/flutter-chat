import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 变高列表项的前缀和。
///
/// 为什么要有这个东西:`ListView.builder(itemExtentBuilder: ...)` 落到
/// [RenderSliverFixedExtentBoxAdaptor] 上时,`indexToLayoutOffset`、
/// `getMinChildIndexForScrollOffset`、`getMaxChildIndexForScrollOffset`、
/// `computeMaxScrollOffset` 全都是从下标 0 开始逐项调用 itemExtentBuilder 累加的,
/// 每次调用 O(n)。而一帧 layout 里这些方法会被调用「2 + 可见子项数」次,
/// 于是单帧回调次数是 O(n × 可见项数) —— 两万条联系人时每帧几十万次,
/// 滚动必然掉帧。
///
/// [ItemExtents] 把每项高度一次性累加成前缀和,几何计算降到 O(1)/O(log n)。
/// 顺带把「列表总高度」变成精确值(框架默认是按可见项平均高度外推的估计值),
/// A-Z 索引跳转的目标偏移因此不会再落到 maxScrollExtent 之外。
class ItemExtents {
  ItemExtents(List<double> extents) : _offsets = _accumulate(extents);

  /// 长度 n+1,`_offsets[i]` 是第 i 项的起始偏移,`_offsets[n]` 是列表总高度。
  final Float64List _offsets;

  static Float64List _accumulate(List<double> extents) {
    final offsets = Float64List(extents.length + 1);
    double sum = 0;
    for (int i = 0; i < extents.length; i++) {
      sum += extents[i];
      offsets[i + 1] = sum;
    }
    return offsets;
  }

  int get length => _offsets.length - 1;

  double get totalExtent => _offsets[length];

  /// 第 [index] 项的起始偏移。允许 `index == length`(即列表末尾)。
  double offsetOf(int index) {
    if (index <= 0) return 0;
    if (index >= length) return _offsets[length];
    return _offsets[index];
  }

  double extentOf(int index) {
    if (index < 0 || index >= length) return 0;
    return _offsets[index + 1] - _offsets[index];
  }

  /// 语义与框架的 `_getChildIndexForScrollOffset` 完全一致:
  /// 「首个累计偏移 >= scrollOffset 的下标」减一,再夹到 [0, length-1]。
  /// 保持一致是为了不引入与原 itemExtentBuilder 路径不同的边界行为。
  int indexForOffset(double scrollOffset) {
    if (length == 0 || scrollOffset <= 0) return 0;
    int low = 0;
    int high = length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (_offsets[mid] >= scrollOffset) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }
    final index = low - 1;
    if (index < 0) return 0;
    if (index > length - 1) return length - 1;
    return index;
  }
}

/// 用 [ItemExtents] 描述子项高度的定高型 sliver。
///
/// 用法与 [SliverVariedExtentList] 相同,但要求调用方把每项高度预先算好。
/// `extents.length` 必须与 delegate 的 childCount 一致。
class SliverPrefixExtentList extends SliverMultiBoxAdaptorWidget {
  const SliverPrefixExtentList({
    super.key,
    required super.delegate,
    required this.extents,
  });

  final ItemExtents extents;

  @override
  RenderSliverPrefixExtentList createRenderObject(BuildContext context) {
    final element = context as SliverMultiBoxAdaptorElement;
    return RenderSliverPrefixExtentList(
        childManager: element, extents: extents);
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderSliverPrefixExtentList renderObject) {
    renderObject.extents = extents;
  }
}

class RenderSliverPrefixExtentList extends RenderSliverFixedExtentBoxAdaptor {
  RenderSliverPrefixExtentList({
    required super.childManager,
    required ItemExtents extents,
  }) : _extents = extents;

  ItemExtents get extents => _extents;
  ItemExtents _extents;

  set extents(ItemExtents value) {
    if (identical(_extents, value)) return;
    _extents = value;
    markNeedsLayout();
  }

  /// 必须为 null:performLayout 里断言 itemExtent 与 itemExtentBuilder 二选一。
  @override
  double? get itemExtent => null;

  /// 只有 `_getChildConstraints` 会用到它,这里是 O(1) 的数组读。
  @override
  ItemExtentBuilder get itemExtentBuilder => _itemExtentBuilder;

  double? _itemExtentBuilder(int index, SliverLayoutDimensions dimensions) =>
      index >= 0 && index < _extents.length ? _extents.extentOf(index) : null;

  @override
  double indexToLayoutOffset(double itemExtent, int index) =>
      _extents.offsetOf(index);

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset, double itemExtent) =>
      _extents.indexForOffset(scrollOffset);

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset, double itemExtent) =>
      _extents.indexForOffset(scrollOffset);

  @override
  double computeMaxScrollOffset(
          SliverConstraints constraints, double itemExtent) =>
      _extents.totalExtent;

  /// 总高度是已知的精确值,不必让框架按可见项平均高度外推。
  @override
  double estimateMaxScrollOffset(
    SliverConstraints constraints, {
    int? firstIndex,
    int? lastIndex,
    double? leadingScrollOffset,
    double? trailingScrollOffset,
  }) =>
      _extents.totalExtent;
}
