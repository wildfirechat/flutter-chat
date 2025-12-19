import 'package:flutter/material.dart';

class SidebarIndex extends StatelessWidget {
  final List<String> indexList;
  final Function(String) onIndexSelected;
  final Function(String, bool) onTouch;

  const SidebarIndex({Key? key, required this.indexList, required this.onIndexSelected, required this.onTouch}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 30,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double itemHeight = constraints.maxHeight / indexList.length;
            final double actualItemHeight = itemHeight > 20 ? 20 : itemHeight;
            final double totalHeight = actualItemHeight * indexList.length;

            return Center(
                child: Container(
                    height: totalHeight,
                    child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragUpdate: (details) {
                            int index = (details.localPosition.dy / actualItemHeight).floor();
                            if (index >= 0 && index < indexList.length) {
                                onIndexSelected(indexList[index]);
                                onTouch(indexList[index], true);
                            }
                        },
                        onVerticalDragStart: (details) {
                            int index = (details.localPosition.dy / actualItemHeight).floor();
                            if (index >= 0 && index < indexList.length) {
                                onIndexSelected(indexList[index]);
                                onTouch(indexList[index], true);
                            }
                        },
                        onVerticalDragEnd: (details) {
                            onTouch('', false);
                        },
                        onTapDown: (details) {
                            int index = (details.localPosition.dy / actualItemHeight).floor();
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
                            children: indexList.map((tag) => SizedBox(
                                height: actualItemHeight,
                                child: Center(
                                  child: tag == '↑' 
                                    ? const Icon(Icons.arrow_upward, size: 12, color: Colors.black54)
                                    : Text(tag, style: const TextStyle(fontSize: 10, color: Colors.black54))
                                )
                            )).toList(),
                        )
                    )
                )
            );
          }
        ),
      ),
    );
  }
}
