import 'package:flutter/cupertino.dart';
import 'package:chat/utils/layout_scale.dart';

class ConversationInfoMemberActionItem extends StatelessWidget {
  final bool isPlus;

  const ConversationInfoMemberActionItem(this.isPlus, {super.key});

  @override
  Widget build(BuildContext context) {
    late Image image;
    image = isPlus
        ? Image.asset('assets/images/conversation_setting_member_plus.png')
        : Image.asset('assets/images/conversation_setting_member_minus.png');

    final double dimension =
        LayoutScale.watchScale(context, 48.0, cap: LayoutScale.iconCap);

    return Column(
      children: [
        SizedBox.square(dimension: dimension, child: image),
      ],
    );
  }
}
