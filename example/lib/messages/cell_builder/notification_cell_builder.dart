import 'package:flutter/cupertino.dart';

import '../message_cell.dart';
import '../../ui_model/ui_message.dart';
import 'message_cell_builder.dart';

class NotificationCellBuilder extends MessageCellBuilder {
  NotificationCellBuilder(super.context, super.model);

  @override
  Widget buildContent(BuildContext context) {
    return Container(
        padding: const EdgeInsets.fromLTRB(60, 0, 60, 0),
        child: FutureBuilder<String>(
          future: model.message.content.digest(model.message),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return Text(
                snapshot.data ?? "",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              );
            } else {
              return const Text("");
            }
          },
        ));
  }
}
