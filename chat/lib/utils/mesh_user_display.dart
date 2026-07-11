import 'package:flutter/material.dart';
import 'package:imclient/model/user_info.dart';
import 'external_target_utils.dart';
import '../mesh/mesh_cache.dart';
import '../mesh/mesh_constants.dart';

/// 外部用户显示辅助。
class MeshUserDisplay {
  MeshUserDisplay._();

  /// 同步获取带域后缀的可读名称。
  /// 如果域名称未缓存，会触发异步加载，调用方应确保有机制在缓存更新后重绘。
  static String getReadableName(UserInfo userInfo) {
    final baseName = userInfo.getReadableName();
    final domainId = ExternalTargetUtils.getExternalDomain(userInfo.userId);
    if (domainId == null) return baseName;
    final domainName = MeshCache.instance.getDomainName(domainId);
    if (domainName == null || domainName.isEmpty) {
      // 触发异步加载，但本次返回基础名
      MeshCache.instance.loadDomainInfo(domainId);
      return baseName;
    }
    return ExternalTargetUtils.buildExternalName(baseName, domainName);
  }

  /// 同步获取带域后缀的富文本名称。
  static TextSpan getReadableNameSpan(
    UserInfo userInfo, {
    double? fontSize,
    Color? domainColor,
  }) {
    final baseName = userInfo.getReadableName();
    final domainId = ExternalTargetUtils.getExternalDomain(userInfo.userId);
    if (domainId == null) {
      return TextSpan(text: baseName);
    }
    String? domainName = MeshCache.instance.getDomainName(domainId);
    if (domainName == null || domainName.isEmpty) {
      MeshCache.instance.loadDomainInfo(domainId);
      domainName = null;
    }
    return ExternalTargetUtils.buildExternalNameSpan(
      baseName,
      domainName: domainName,
      fontSize: fontSize,
      domainColor: domainColor ?? MeshConstants.externalNameColor,
    );
  }

  /// 异步解析带域后缀的名称，确保域信息已加载。
  static Future<String> resolveReadableName(UserInfo userInfo) async {
    final baseName = userInfo.getReadableName();
    final domainId = ExternalTargetUtils.getExternalDomain(userInfo.userId);
    if (domainId == null) return baseName;
    final info = await MeshCache.instance.loadDomainInfo(domainId);
    return ExternalTargetUtils.buildExternalName(baseName, info?.name);
  }
}
