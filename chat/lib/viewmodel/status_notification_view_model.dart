import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/pc_online_info.dart';

class StatusNotificationViewModel extends ChangeNotifier {
  int _connectionStatus = kConnectionStatusConnected;
  List<PCOnlineInfo> _pcOnlineInfos = [];
  bool _isMuteWhenPcOnline = false;
  StreamSubscription? _connectionStatusSubscription;
  StreamSubscription? _userSettingUpdatedSubscription;

  int get connectionStatus => _connectionStatus;
  List<PCOnlineInfo> get pcOnlineInfos => _pcOnlineInfos;

  /// 其它端在线时是否关闭手机通知,多端登录条的「，手机通知已关闭」后缀读它。
  bool get isMuteWhenPcOnline => _isMuteWhenPcOnline;

  StatusNotificationViewModel() {
    _init();
  }

  void _init() async {
    _connectionStatus = await Imclient.connectionStatus;
    refreshOnlineInfos();

    _connectionStatusSubscription =
        Imclient.IMEventBus.on<ConnectionStatusChangedEvent>().listen((event) {
      _connectionStatus = event.connectionStatus;
      if (_connectionStatus == kConnectionStatusConnected) {
        refreshOnlineInfos();
      }
      notifyListeners();
    });

    _userSettingUpdatedSubscription =
        Imclient.IMEventBus.on<UserSettingUpdatedEvent>().listen((event) {
      refreshOnlineInfos();
    });
  }

  void refreshOnlineInfos() async {
    if (_connectionStatus == kConnectionStatusConnected) {
      _pcOnlineInfos = await Imclient.getPCOnlineInfos();
      _isMuteWhenPcOnline = await Imclient.isMuteNotificationWhenPcOnline();
      notifyListeners();
    } else {
      _pcOnlineInfos = [];
      _isMuteWhenPcOnline = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _connectionStatusSubscription?.cancel();
    _userSettingUpdatedSubscription?.cancel();
    super.dispose();
  }
}
