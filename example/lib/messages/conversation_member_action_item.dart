import 'package:flutter/cupertino.dart';

class ConversationMemberActionItem extends StatelessWidget {
  final bool isPlus;

  const ConversationMemberActionItem(this.isPlus, {super.key});

  @override
  Widget build(BuildContext context) {
    late Image image;
    image = isPlus ? Image.asset('assets/images/conversation_setting_member_plus.png') : Image.asset('assets/images/conversation_setting_member_minus.png');

    return Column(
      children: [
        SizedBox.square(dimension: 48, child: image),
      ],
    );
  }
}
