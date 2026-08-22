import 'package:flutter/material.dart';

import 'message_cell_builder.dart';

/// 流式文本取消消息(20)的渲染：不创建任何气泡、不显示任何内容。
/// 正常流程中取消消息在 [ConversationViewModel] 收到时按 streamId 删除对应的
/// generating(14)/generated(15) 消息后不会进入消息列表；此 builder 只是兜底，
/// 防止历史残留/异常路径把 20 渲染成"未知消息"气泡。
class StreamingTextCancelledCellBuilder extends MessageCellBuilder {
  StreamingTextCancelledCellBuilder(super.context, super.model);

  @override
  Widget buildContent(BuildContext context) {
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    // 连时间标签、留白一起不渲染，界面上完全不可见
    return const SizedBox.shrink();
  }
}
