import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';

/// 双网（政企内外网）环境下，当前使用的是主网络还是备选网络。
///
/// 服务地址选择（[Config.selectServer]）和媒体地址转换（[MediaUrlRedirector]）
/// 都以这里为准，保证同一时刻选的是同一个网络。
/// 双网相关知识请参考：https://docs.wildfirechat.cn/blogs/政企内外双网解决方案.html
class DualNetwork {
  const DualNetwork._();

  // IM 当前或最近一次连接的网络，协议栈未连接时也保持最近一次连接的值
  static int _connectedNetworkType = kConnectedNetworkTypeUnknown;
  static int _connectionStatus = kConnectionStatusUnconnected;

  /// 当前是否使用主网络。
  ///
  /// 设置了固定的备选网络策略时，以策略为准；否则以 IM 连接的网络为准：
  /// 断线重连、同步消息等非 Connected 状态时，沿用最近一次连接的网络；
  /// 还没有连接过时，网络未知，和协议栈保持一致，按主网络处理。
  static bool get isMainNetwork {
    switch (Imclient.backupAddressStrategy) {
      case kBackupAddressStrategyMain:
        return true;
      case kBackupAddressStrategyBackup:
        return false;
      default:
        return _connectedNetworkType != kConnectedNetworkTypeBackup;
    }
  }

  /// IM 是否已连接（含连接后同步消息中），已连接时 [isMainNetwork] 是当前连接的网络。
  static bool get isImConnected =>
      _connectionStatus == kConnectionStatusConnected ||
      _connectionStatus == kConnectionStatusReceiving;

  /// IM 连接到服务器时调用。
  static void onConnected(bool mainNetwork) {
    _connectedNetworkType =
        mainNetwork ? kConnectedNetworkTypeMain : kConnectedNetworkTypeBackup;
  }

  /// IM 连接状态变化时调用。
  static void onConnectionStatusChanged(int status) {
    _connectionStatus = status;
    if (status == kConnectionStatusConnected) {
      // Android 上连接回调里带的网络类型可能早于协议栈更新，连接完成后以协议栈为准校正
      Imclient.connectedNetworkType.then((type) {
        if (type != kConnectedNetworkTypeUnknown) {
          _connectedNetworkType = type;
        }
      }).catchError((e) {
        debugPrint('DualNetwork get connected network type failed: $e');
      });
    }
  }

  /// PC 子窗口没有自己的 IM 连接，用主窗口创建子窗口时的网络初始化。
  static void initSubWindow(bool mainNetwork) {
    onConnected(mainNetwork);
  }
}
