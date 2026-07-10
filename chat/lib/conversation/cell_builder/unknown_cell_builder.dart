import 'package:flutter/cupertino.dart';

import '../message_cell.dart';
import '../../l10n/app_localizations.dart';
import '../../ui_model/ui_message.dart';
import 'message_cell_builder.dart';

/// 没有专属 cell builder 的消息类型的兜底展示：
/// 优先显示消息自身的 digest 摘要（所有 MessageContent 都实现），
/// 取不到时才提示"暂未实现"。
class UnknownCellBuilder extends MessageCellBuilder {
  UnknownCellBuilder(super.context, super.model);

  @override
  Widget buildContent(BuildContext context) {
    return FutureBuilder<String>(
      future: model.message.content.digest(model.message),
      builder: (context, snapshot) {
        final digest = snapshot.data;
        if (digest != null && digest.isNotEmpty) {
          return Text(digest);
        }
        return Text(
          AppLocalizations.of(context)!.unknownMessageNotImplemented,
          textAlign: TextAlign.center,
        );
      },
    );
  }
}
