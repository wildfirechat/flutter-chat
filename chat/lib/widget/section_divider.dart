import 'package:flutter/cupertino.dart';

class SectionDivider extends StatelessWidget {
  const SectionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 18,
      width: View.of(context).physicalSize.width,
      color: const Color(0xffebebeb),
    );
  }
}
