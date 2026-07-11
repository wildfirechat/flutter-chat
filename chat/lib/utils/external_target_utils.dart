import 'package:flutter/material.dart';
import '../mesh/mesh_constants.dart';

/// 外部用户 ID 解析与显示工具。
///
/// iOS 对应实现：WFCCUtilities 的 isExternalTarget / getExternalDomain /
/// getTargetWithoutDomain / getExternal:withName:withColor:withSize:
class ExternalTargetUtils {
  ExternalTargetUtils._();

  /// 判断 [userId] 是否为外部域用户（格式 `userId@domainId`）。
  static bool isExternalTarget(String userId) {
    if (userId.isEmpty) return false;
    // 排除本地系统账号/机器人等特殊 ID 里的 @
    final atIndex = userId.lastIndexOf('@');
    return atIndex > 0 && atIndex < userId.length - 1;
  }

  /// 从 `userId@domainId` 中提取 domainId。
  static String? getExternalDomain(String userId) {
    if (!isExternalTarget(userId)) return null;
    return userId.substring(userId.lastIndexOf('@') + 1);
  }

  /// 从 `userId@domainId` 中提取纯 userId。
  static String getTargetWithoutDomain(String userId) {
    if (!isExternalTarget(userId)) return userId;
    return userId.substring(0, userId.lastIndexOf('@'));
  }

  /// 构建带域后缀的富文本名称，例如 "张三@某单位"。
  /// [domainName] 为空时只返回 [name]。
  /// 域后缀默认使用 [MeshConstants.externalNameColor]，字号比 [style] 的字号小 2。
  static TextSpan buildExternalNameSpan(
    String name, {
    String? domainName,
    TextStyle? style,
  }) {
    final children = <TextSpan>[
      TextSpan(text: name, style: style),
    ];
    if (domainName != null && domainName.isNotEmpty) {
      final baseFontSize = style?.fontSize ?? 14;
      children.add(TextSpan(
        text: '@$domainName',
        style: TextStyle(
          color: MeshConstants.externalNameColor,
          fontSize: baseFontSize > 2 ? baseFontSize - 2 : baseFontSize,
        ),
      ));
    }
    return TextSpan(children: children);
  }

  /// 返回普通文本形式的带域后缀名称。
  static String buildExternalName(String name, String? domainName) {
    if (domainName == null || domainName.isEmpty) return name;
    return '$name@$domainName';
  }
}
