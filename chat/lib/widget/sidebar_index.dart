import 'dart:math';

import 'package:flutter/material.dart';
import 'package:chat/theme/app_typography.dart';

class SidebarIndex extends StatelessWidget {
  final List<String> indexList;
  final Function(String) onIndexSelected;
  final Function(String, bool) onTouch;

  const SidebarIndex(
      {Key? key,
      required this.indexList,
      required this.onIndexSelected,
      required this.onTouch})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    // textScaler 在 LayoutBuilder 外面读:builder 是在 layout 阶段跑的。
    final textScaler = MediaQuery.textScalerOf(context);
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 30,
        child: LayoutBuilder(builder: (context, constraints) {
          final double itemHeight = constraints.maxHeight / indexList.length;
          final double actualItemHeight = itemHeight > 20 ? 20 : itemHeight;
          final double totalHeight = actualItemHeight * indexList.length;
          // 完整字母表有近 30 项,矮屏上每项只剩十几个逻辑像素。字号必须跟着
          // 项高收口 —— 否则最大字号档(1.45x)会把字撑出行框。
          final double fontSize = min(
              textScaler.scale(AppText.xxs.fontSize!), actualItemHeight * 0.68);
          final double iconSize = min(12.0, actualItemHeight * 0.7);

          return Center(
              child: Container(
                  height: totalHeight,
                  child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (details) {
                        int index =
                            (details.localPosition.dy / actualItemHeight)
                                .floor();
                        if (index >= 0 && index < indexList.length) {
                          onIndexSelected(indexList[index]);
                          onTouch(indexList[index], true);
                        }
                      },
                      onVerticalDragStart: (details) {
                        int index =
                            (details.localPosition.dy / actualItemHeight)
                                .floor();
                        if (index >= 0 && index < indexList.length) {
                          onIndexSelected(indexList[index]);
                          onTouch(indexList[index], true);
                        }
                      },
                      onVerticalDragEnd: (details) {
                        onTouch('', false);
                      },
                      onTapDown: (details) {
                        int index =
                            (details.localPosition.dy / actualItemHeight)
                                .floor();
                        if (index >= 0 && index < indexList.length) {
                          onIndexSelected(indexList[index]);
                          onTouch(indexList[index], true);
                        }
                      },
                      onTapUp: (details) {
                        onTouch('', false);
                      },
                      onTapCancel: () {
                        onTouch('', false);
                      },
                      child: Column(
                        children: indexList
                            .map((tag) => SizedBox(
                                height: actualItemHeight,
                                child: Center(
                                    child: tag == '↑'
                                        ? Icon(Icons.arrow_upward,
                                            size: iconSize,
                                            color: Colors.black54)
                                        : Text(tag,
                                            // 字号已按项高收口,不能再被全局 textScaler 放大一次。
                                            textScaler: TextScaler.noScaling,
                                            style: AppText.xxs.copyWith(
                                                fontSize: fontSize,
                                                height: 1.0,
                                                color: Colors.black54)))))
                            .toList(),
                      ))));
        }),
      ),
    );
  }
}
