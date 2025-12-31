import 'package:flutter/material.dart';

class OptionItem extends StatelessWidget {
  final String title;
  final String? desc;
  final bool showRightArrow;
  final bool showBottomDivider;
  final Image? rightImage;
  final Image? leftImage;
  final IconData? rightIcon;
  final IconData? leftIcon;
  final GestureTapCallback? onTap;

  const OptionItem(this.title,
      {super.key, this.desc = '', this.showRightArrow = true, this.showBottomDivider = true, this.onTap, this.leftImage, this.rightImage, this.leftIcon, this.rightIcon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(15, 10, 5, 10),
            height: 36,
            child: Row(
              children: [
                leftImage != null || leftIcon != null
                    ? Container(
                        height: 20,
                        width: 20,
                        margin: const EdgeInsets.fromLTRB(0, 0, 12, 0),
                        child: leftImage ?? Icon(leftIcon),
                      )
                    : const SizedBox.shrink(),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                desc != null && desc!.isNotEmpty
                    ? Container(
                        constraints: const BoxConstraints(maxWidth: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          desc!,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      )
                    : Container(),
                rightImage != null || rightIcon != null
                    ? Container(
                        height: 20,
                        width: 20,
                        margin: const EdgeInsets.fromLTRB(12, 0, 0, 0),
                        child: rightImage ?? Icon(rightIcon),
                      )
                    : const SizedBox.shrink(),
                showRightArrow ? const Icon(Icons.chevron_right, color: Colors.grey) : Container(),
              ],
            ),
          ),
          showBottomDivider
              ? Container(
                  margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 0.0),
                  height: 0.5,
                  color: const Color(0xdbdbdbdb),
                )
              : Container(),
        ],
      ),
      onTap: () {
        onTap?.call();
      },
    );
  }
}
