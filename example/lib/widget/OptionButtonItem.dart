import 'package:flutter/material.dart';

class OptionButtonItem extends StatelessWidget {
  final String title;
  final bool showBottomDivider;
  final GestureTapCallback onTap;

  const OptionButtonItem(
    this.title,
    this.onTap, {
    this.showBottomDivider = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(15, 10, 5, 10),
          height: 32,
          child: Center(
              child: Text(
            title,
            style: const TextStyle(color: Colors.red),
          )),
        ),
        Container(
          //margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 0.0),
          height: showBottomDivider ? 0.5 : 0,
          color: const Color(0xdbdbdbdb),
        ),
      ],
    );
  }
}
