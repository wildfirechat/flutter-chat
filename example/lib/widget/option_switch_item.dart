import 'package:flutter/material.dart';

class OptionSwitchItem extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const OptionSwitchItem(
    this.title,
    this.value,
    this.onChanged, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(15, 10, 5, 10),
          height: 36,
          child: (Row(
            children: [
              Text(title),
              Expanded(child: Container(color: Colors.transparent /*为了实现点击效果*/)),
              Switch(
                  value: value,
                  onChanged: (enable) {
                    onChanged.call(enable);
                  })
            ],
          )),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 0.0),
          height: 0.5,
          color: const Color(0xdbdbdbdb),
        ),
      ],
    );
  }
}
