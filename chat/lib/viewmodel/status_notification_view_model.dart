import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/pc_online_info.dart';

class StatusNotificationViewModel extends ChangeNotifier {
  int _connectionStatus = kConnectionStatusConnected;
  List<PCOnlineInfo> _pcOnlineInfos = [];
  StreamSubscription? _connectionStatusSubscription;
  StreamSubscription? _userSettingUpdatedSubscription;

  int get connectionStatus => _connectionStatus;
  List<PCOnlineInfo> get pcOnlineInfos => _pcOnlineInfos;

  StatusNotificationViewModel() {
    _init();
  }

  void _init() async {
    _connectionStatus = await Imclient.connectionStatus;
    refreshOnlineInfos();

    _connectionStatusSubscription = Imclient.IMEventBus.on<ConnectionStatusChangedEvent>().listen((event) {
      _connectionStatus = event.connectionStatus;
      if (_connectionStatus == kConnectionStatusConnected) {
        refreshOnlineInfos();
      }
      notifyListeners();
    });

    _userSettingUpdatedSubscription = Imclient.IMEventBus.on<UserSettingUpdatedEvent>().listen((event) {
      refreshOnlineInfos();
    });
  }

  void refreshOnlineInfos() async {
    if (_connectionStatus == kConnectionStatusConnected) {
      _pcOnlineInfos = await Imclient.getOnlineInfos();
      notifyListeners();
    } else {
      _pcOnlineInfos = [];
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
