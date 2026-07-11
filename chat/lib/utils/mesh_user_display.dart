import 'package:flutter/material.dart';
import 'package:imclient/model/user_info.dart';
import 'external_target_utils.dart';
import '../mesh/mesh_cache.dart';
import '../mesh/mesh_constants.dart';

/// 外部用户显示辅助。
class MeshUserDisplay {
  MeshUserDisplay._();

  /// 拼域后缀时的基础名。占位用户（无 displayName）的可读名会回退到
  /// `xxx@domainId`，去掉自带的域部分，避免拼出 "xxx@domainId@域名"。
  static String _baseName(UserInfo userInfo) {
    final name = userInfo.getReadableName();
    if (name == userInfo.userId) {
      return ExternalTargetUtils.getTargetWithoutDomain(name);
    }
    return name;
  }

  /// 同步获取带域后缀的可读名称。
  /// 如果域名称未缓存，会触发异步加载，调用方应确保有机制在缓存更新后重绘。
  static String getReadableName(UserInfo userInfo) {
    final domainId = ExternalTargetUtils.getExternalDomain(userInfo.userId);
    if (domainId == null) return userInfo.getReadableName();
    final domainName = MeshCache.instance.getDomainName(domainId);
    if (domainName == null || domainName.isEmpty) {
      // 触发异步加载，但本次返回基础名
      MeshCache.instance.loadDomainInfo(domainId);
      return userInfo.getReadableName();
    }
    return ExternalTargetUtils.buildExternalName(_baseName(userInfo), domainName);
  }

  /// 同步获取带域后缀的富文本名称。
  static TextSpan getReadableNameSpan(
    UserInfo userInfo, {
    double? fontSize,
    Color? domainColor,
  }) {
    final domainId = ExternalTargetUtils.getExternalDomain(userInfo.userId);
    if (domainId == null) {
      return TextSpan(text: userInfo.getReadableName());
    }
    String? domainName = MeshCache.instance.getDomainName(domainId);
    if (domainName == null || domainName.isEmpty) {
      MeshCache.instance.loadDomainInfo(domainId);
      domainName = null;
    }
    return ExternalTargetUtils.buildExternalNameSpan(
      domainName == null ? userInfo.getReadableName() : _baseName(userInfo),
      domainName: domainName,
      fontSize: fontSize,
      domainColor: domainColor ?? MeshConstants.externalNameColor,
    );
  }

  /// 异步解析带域后缀的名称，确保域信息已加载。
  static Future<String> resolveReadableName(UserInfo userInfo) async {
    final domainId = ExternalTargetUtils.getExternalDomain(userInfo.userId);
    if (domainId == null) return userInfo.getReadableName();
    final info = await MeshCache.instance.loadDomainInfo(domainId);
    if (info == null || info.name.isEmpty) return userInfo.getReadableName();
    return ExternalTargetUtils.buildExternalName(_baseName(userInfo), info.name);
  }
}
