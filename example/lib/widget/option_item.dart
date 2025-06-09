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
      {super.key,
      this.desc = '',
      this.showRightArrow = true,
      this.showBottomDivider = true,
      this.onTap,
      this.leftImage,
      this.rightImage,
      this.leftIcon,
      this.rightIcon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: Column(
        children: [
          // Container(
          //   height: showTopDividerSection ? 18 : 0,
          //   width: View.of(context).physicalSize.width,
          //   color: const Color(0xffebebeb),
          // ),
          Container(
            margin: const EdgeInsets.fromLTRB(15, 10, 5, 10),
            height: 36,
            child: (Row(
              children: [
                leftImage != null || leftIcon != null
                    ? Container(
                        height: 20,
                        width: 20,
                        margin: const EdgeInsets.fromLTRB(0, 0, 12, 0),
                        child: leftImage ?? Icon(leftIcon),
                      )
                    : const SizedBox.shrink(),
                Text(title),
                Expanded(child: Container(color: Colors.transparent /*为了实现点击效果*/)),
                desc != null && desc!.isNotEmpty ? Text(desc!) : Container(),
                rightImage != null || rightIcon != null
                    ? Container(
                        height: 20,
                        width: 20,
                        margin: const EdgeInsets.fromLTRB(12, 0, 0, 0),
                        child: rightImage ?? Icon(rightIcon),
                      )
                    : const SizedBox.shrink(),
                showRightArrow ? const Icon(Icons.chevron_right) : Container()
              ],
            )),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 0.0),
            height: 0.5,
            color: const Color(0xdbdbdbdb),
          ),
        ],
      ),
      onTap: () {
        onTap?.call();
      },
    );
  }
}
