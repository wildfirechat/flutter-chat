import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/domain_info.dart';

/// Mesh 域信息缓存。
///
/// 外部用户显示需要频繁把 domainId 转成 domainName，这里做内存缓存，
/// 并通过 [DomainInfoUpdatedEvent] 保持同步。
class MeshCache extends ChangeNotifier {
  MeshCache._() {
    _subscription = Imclient.IMEventBus.on<DomainInfoUpdatedEvent>().listen((event) {
      if (event.domainInfo != null) {
        _domains[event.domainInfo!.domainId] = event.domainInfo!;
        notifyListeners();
      }
    });
  }

  static final MeshCache _instance = MeshCache._();
  static MeshCache get instance => _instance;

  final Map<String, DomainInfo> _domains = {};
  StreamSubscription? _subscription;

  /// 获取缓存中的域信息，没有则返回 null。
  DomainInfo? getDomainInfo(String domainId) {
    return _domains[domainId];
  }

  /// 获取域名称，没有则返回 null。
  String? getDomainName(String domainId) {
    return _domains[domainId]?.name;
  }

  /// 从缓存或远程加载域信息。
  Future<DomainInfo?> loadDomainInfo(String domainId, {bool refresh = false}) async {
    if (!refresh && _domains.containsKey(domainId)) {
      return _domains[domainId];
    }
    final info = await Imclient.getDomainInfo(domainId, refresh: refresh);
    if (info != null) {
      _domains[domainId] = info;
      notifyListeners();
    }
    return info;
  }

  /// 预加载多个域信息。
  Future<void> preloadDomainInfos(List<String> domainIds) async {
    final futures = <Future>[];
    for (final domainId in domainIds) {
      if (_domains.containsKey(domainId)) continue;
      futures.add(loadDomainInfo(domainId));
    }
    await Future.wait(futures);
  }

  /// 清空缓存。
  void clear() {
    _domains.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
