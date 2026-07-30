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
    _subscription =
        Imclient.IMEventBus.on<DomainInfoUpdatedEvent>().listen((event) {
      final info = event.domainInfo;
      if (info != null && info.domainId.isNotEmpty) {
        _domains[info.domainId] = info;
        _missing.remove(info.domainId);
        notifyListeners();
      }
    });
  }

  static final MeshCache _instance = MeshCache._();
  static MeshCache get instance => _instance;

  final Map<String, DomainInfo> _domains = {};

  // 本地取不到的域。SDK 未命中时会自行从服务器拉取并回调 DomainInfoUpdatedEvent，
  // 这里挡住 build 路径的重复请求，等事件到达后再解除。
  final Set<String> _missing = {};
  final Map<String, Future<DomainInfo?>> _pending = {};
  StreamSubscription? _subscription;

  /// 获取缓存中的域信息，没有则返回 null。
  DomainInfo? getDomainInfo(String domainId) {
    return _domains[domainId];
  }

  /// 获取域名称，没有则返回 null。
  String? getDomainName(String domainId) {
    return _domains[domainId]?.name;
  }

  /// 从缓存或远程加载域信息。同一 domainId 的并发调用共享一次请求；
  /// 未命中的域会被负缓存，直到 [DomainInfoUpdatedEvent] 到达或 [refresh] 为 true。
  Future<DomainInfo?> loadDomainInfo(String domainId, {bool refresh = false}) {
    if (domainId.isEmpty) return Future.value(null);
    if (!refresh) {
      final cached = _domains[domainId];
      if (cached != null) return Future.value(cached);
      if (_missing.contains(domainId)) return Future.value(null);
    }
    return _pending[domainId] ??= _fetchDomainInfo(domainId, refresh);
  }

  Future<DomainInfo?> _fetchDomainInfo(String domainId, bool refresh) async {
    try {
      final info = await Imclient.getDomainInfo(domainId, refresh: refresh);
      // 桌面端未命中时返回空对象而不是 null，统一按缺失处理
      if (info == null || info.domainId.isEmpty) {
        _missing.add(domainId);
        return null;
      }
      _domains[domainId] = info;
      _missing.remove(domainId);
      notifyListeners();
      return info;
    } catch (_) {
      _missing.add(domainId);
      return null;
    } finally {
      _pending.remove(domainId);
    }
  }

  /// 预加载多个域信息。
  Future<void> preloadDomainInfos(List<String> domainIds) async {
    await Future.wait(domainIds.map(loadDomainInfo));
  }

  /// 用一批已取到的域信息回灌缓存（如 getRemoteDomains 的结果），
  /// 让外部用户名后缀无需再逐个请求即可解析。
  void putDomains(List<DomainInfo> domains) {
    bool changed = false;
    for (final domain in domains) {
      if (domain.domainId.isEmpty) continue;
      _domains[domain.domainId] = domain;
      _missing.remove(domain.domainId);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// 清空缓存。
  void clear() {
    _domains.clear();
    _missing.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
