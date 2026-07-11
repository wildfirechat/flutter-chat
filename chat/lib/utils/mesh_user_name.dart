import 'package:flutter/material.dart';
import 'package:imclient/model/user_info.dart';
import 'mesh_user_display.dart';

/// 统一渲染外部用户名称的控件。
///
/// 如果用户来自外部域，名称后会追加 "@域名称"，域名称使用黄色且字号比 [style] 小 2。
/// 普通用户则按普通 [Text] 渲染。
class MeshUserName extends StatelessWidget {
  final UserInfo userInfo;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  const MeshUserName(
    this.userInfo, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final span = MeshUserDisplay.getReadableNameSpan(userInfo, style: style);
    // 没有域后缀时退化为普通 Text，保持行为一致
    if (span.children == null || span.children!.length <= 1) {
      return Text(
        userInfo.getReadableName(),
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
      );
    }
    return Text.rich(
      span,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}
