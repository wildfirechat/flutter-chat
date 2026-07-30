import 'dart:async';

import 'package:chat/organization/model/employee.dart';
import 'package:chat/organization/model/employee_ex.dart';
import 'package:chat/organization/model/organization.dart';
import 'package:chat/organization/model/organization_ex.dart';
import 'package:chat/organization/model/organization_relationship.dart';
import 'package:chat/organization/organization_service.dart';
import 'package:imclient/imclient.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../event_bus.dart';

/// 根节点更新完成
class RootOrganizationUpdatedEvent {}

/// 我的组织关系更新完成
class MyOrganizationUpdatedEvent {}

/// 组织信息更新完成，object 为 organizationId(int)
class OrganizationUpdatedEvent {
  final int organizationId;
  final Organization? organization;

  OrganizationUpdatedEvent(this.organizationId, this.organization);
}

/// 组织层级信息更新完成，包括组织信息、子组织信息、当前层级员工信息，object 为 organizationId(int)
class OrganizationExUpdatedEvent {
  final int organizationId;
  final OrganizationEx? organizationEx;

  OrganizationExUpdatedEvent(this.organizationId, this.organizationEx);
}

/// 员工信息更新完成，object 为 employeeId(String)
class EmployeeUpdatedEvent {
  final String employeeId;
  final Employee? employee;

  EmployeeUpdatedEvent(this.employeeId, this.employee);
}

/// 员工附加信息更新完成，包括员工信息及员工的关系，object 为 employeeId(String)
class EmployeeExUpdatedEvent {
  final String employeeId;
  final EmployeeEx? employeeEx;

  EmployeeExUpdatedEvent(this.employeeId, this.employeeEx);
}

/// 关系信息更新完成，object 为 employeeId(String)
class OrgRelationUpdatedEvent {
  final String employeeId;
  final List<OrganizationRelationship> relationships;

  OrgRelationUpdatedEvent(this.employeeId, this.relationships);
}

class OrganizationCache {
  static const String _keyBottomOrganizationIds = 'WFC_bottomOrganizationIds';
  static const String _keyRootOrganizationIds = 'WFC_rootOrganizationIds';
  static const String _keyOrganizationPrefix = 'WFC_organization_';

  final OrganizationService _service = OrganizationService.instance;
  final Map<String, Employee> _employeeDict = {};
  final Map<String, EmployeeEx> _employeeExDict = {};
  final Map<int, Organization> _organizationDict = {};
  final Map<int, OrganizationEx> _organizationExDict = {};
  final Map<String, List<OrganizationRelationship>> _relationshipDict = {};

  List<int> rootOrganizationIds = [];
  List<int> bottomOrganizationIds = [];

  // Singleton
  OrganizationCache._privateConstructor();

  static final OrganizationCache _instance =
      OrganizationCache._privateConstructor();

  static OrganizationCache get instance => _instance;

  Future<void> initialize() async {
    await _restoreMyOrganizationInfos();
  }

  Future<void> _restoreMyOrganizationInfos() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> restoreIds = [];

    final List<String>? bottoms =
        prefs.getStringList(_keyBottomOrganizationIds);
    if (bottoms != null) {
      bottomOrganizationIds = bottoms
          .map((e) => int.tryParse(e) ?? 0)
          .where((e) => e != 0)
          .toList();
      restoreIds.addAll(bottoms);
    } else {
      bottomOrganizationIds = [];
    }

    final List<String>? roots = prefs.getStringList(_keyRootOrganizationIds);
    if (roots != null) {
      rootOrganizationIds =
          roots.map((e) => int.tryParse(e) ?? 0).where((e) => e != 0).toList();
      restoreIds.addAll(roots);
    } else {
      rootOrganizationIds = [];
    }

    for (final idStr in restoreIds) {
      final orgId = int.tryParse(idStr);
      if (orgId == null) continue;
      final json = prefs.getString('$_keyOrganizationPrefix$orgId');
      if (json != null && json.isNotEmpty) {
        try {
          final org = Organization.fromJsonString(json);
          if (org.id != 0) {
            _organizationDict[org.id] = org;
          }
        } catch (e) {
          print('Failed to restore organization $orgId: $e');
        }
      }
    }
  }

  Future<void> clearCaches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyBottomOrganizationIds);
    await prefs.remove(_keyRootOrganizationIds);

    // Also clear persisted organization details
    for (final id in _organizationDict.keys) {
      await prefs.remove('$_keyOrganizationPrefix$id');
    }

    _employeeDict.clear();
    _employeeExDict.clear();
    _organizationDict.clear();
    _organizationExDict.clear();
    _relationshipDict.clear();
    rootOrganizationIds = [];
    bottomOrganizationIds = [];
  }

  Future<void> loadMyOrganizationInfos() async {
    if (!_service.isServiceAvailable()) {
      try {
        await _service.login();
      } catch (e) {
        print('OrganizationCache loadMyOrganizationInfos login failed: $e');
        return;
      }
    }

    final currentUserId = Imclient.currentUserId;
    if (currentUserId == null || currentUserId.isEmpty) {
      print(
          'OrganizationCache loadMyOrganizationInfos: current user id is empty');
      return;
    }

    // Load relationships / bottom organizations
    _service.getRelationship(currentUserId).then((relationships) async {
      _relationshipDict[currentUserId] = relationships;
      eventBus.fire(OrgRelationUpdatedEvent(currentUserId, relationships));

      final bottomIds = relationships
          .where((r) => r.bottom)
          .map((r) => r.organizationId)
          .toList();
      bottomOrganizationIds = bottomIds;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyBottomOrganizationIds,
          bottomIds.map((e) => e.toString()).toList());

      if (bottomIds.isNotEmpty) {
        _service.getOrganizations(bottomIds).then((organizations) async {
          for (final org in organizations) {
            if (org.id != 0) {
              _organizationDict[org.id] = org;
              await _persistOrganization(org, prefs);
            }
          }
        }).catchError((error) {
          print('Failed to load bottom organizations: $error');
        });
        eventBus.fire(MyOrganizationUpdatedEvent());
      }
    }).catchError((error) {
      print('Failed to load relationships: $error');
    });

    // Load root organizations
    _service.getRootOrganization().then((organizations) async {
      final rootIds = <int>[];
      final prefs = await SharedPreferences.getInstance();
      for (final org in organizations) {
        if (org.id != 0) {
          rootIds.add(org.id);
          _organizationDict[org.id] = org;
          await _persistOrganization(org, prefs);
        }
      }
      rootOrganizationIds = rootIds;
      await prefs.setStringList(
          _keyRootOrganizationIds, rootIds.map((e) => e.toString()).toList());
      eventBus.fire(RootOrganizationUpdatedEvent());
    }).catchError((error) {
      print('Failed to load root organizations: $error');
    });
  }

  Future<void> _persistOrganization(
      Organization org, SharedPreferences prefs) async {
    await prefs.setString(
        '$_keyOrganizationPrefix${org.id}', org.toJsonString());
  }

  Future<List<OrganizationRelationship>> getRelationship(String employeeId,
      {bool refresh = false}) async {
    var rs = _relationshipDict[employeeId];
    if (rs == null) {
      refresh = true;
    } else {
      if (!refresh) {
        return rs;
      }
    }

    if (refresh) {
      try {
        rs = await _service.getRelationship(employeeId);
        _relationshipDict[employeeId] = rs;
        eventBus.fire(OrgRelationUpdatedEvent(employeeId, rs));
      } catch (e) {
        print('Failed to get relationship for $employeeId: $e');
      }
    }
    return rs ?? [];
  }

  List<OrganizationRelationship>? getRelationshipSync(String employeeId,
      {bool refresh = false}) {
    var rs = _relationshipDict[employeeId];
    if (rs == null) {
      refresh = true;
    }

    if (refresh) {
      _service.getRelationship(employeeId).then((value) {
        _relationshipDict[employeeId] = value;
        eventBus.fire(OrgRelationUpdatedEvent(employeeId, value));
      }).catchError((error) {
        print('Failed to get relationship for $employeeId: $error');
      });
    }
    return rs;
  }

  Employee? getEmployee(String employeeId, {bool refresh = false}) {
    var employee = _employeeDict[employeeId];
    if (employee == null) {
      refresh = true;
    }

    if (refresh) {
      _service.getEmployee(employeeId).then((value) {
        _employeeDict[employeeId] = value;
        eventBus.fire(EmployeeUpdatedEvent(employeeId, value));
      }).catchError((error) {
        print('Failed to get employee $employeeId: $error');
      });
    }
    return employee;
  }

  EmployeeEx? getEmployeeEx(String employeeId, {bool refresh = false}) {
    var ex = _employeeExDict[employeeId];
    if (ex == null) {
      refresh = true;
      ex = EmployeeEx(
        employeeId: employeeId,
        employee: _employeeDict[employeeId],
        relationships: _relationshipDict[employeeId],
      );
    }

    if (refresh) {
      _service.getEmployeeEx(employeeId).then((value) {
        _employeeExDict[employeeId] = value;
        if (value.employee != null) {
          _employeeDict[employeeId] = value.employee!;
        }
        if (value.relationships != null) {
          _relationshipDict[employeeId] = value.relationships!;
        }
        eventBus.fire(EmployeeExUpdatedEvent(employeeId, value));
        eventBus.fire(EmployeeUpdatedEvent(employeeId, value.employee));
        if (value.relationships != null) {
          eventBus
              .fire(OrgRelationUpdatedEvent(employeeId, value.relationships!));
        }
      }).catchError((error) {
        print('Failed to get employee ex $employeeId: $error');
      });
    }
    return ex;
  }

  Organization? getOrganization(int organizationId, {bool refresh = false}) {
    var org = _organizationDict[organizationId];
    if (org == null) {
      refresh = true;
    }

    if (refresh) {
      _service.getOrganizations([organizationId]).then((organizations) {
        if (organizations.isNotEmpty) {
          final loaded = organizations.first;
          _organizationDict[organizationId] = loaded;
          eventBus.fire(OrganizationUpdatedEvent(organizationId, loaded));
        }
      }).catchError((error) {
        print('Failed to get organization $organizationId: $error');
      });
    }
    return org;
  }

  Future<OrganizationEx?> getOrganizationEx(
    int organizationId, {
    bool refresh = false,
  }) async {
    var ex = _organizationExDict[organizationId];
    if (ex == null) {
      refresh = true;
      ex = OrganizationEx(
        organizationId: organizationId,
        organization: getOrganization(organizationId, refresh: false),
      );
    }

    if (refresh) {
      try {
        final loaded = await _service.getOrganizationEx(organizationId);
        for (final sub in loaded.subOrganizations ?? []) {
          if (sub.id != 0) {
            _organizationDict[sub.id] = sub;
          }
        }
        for (final emp in loaded.employees ?? []) {
          _employeeDict[emp.employeeId] = emp;
        }
        _organizationExDict[organizationId] = loaded;
        eventBus.fire(OrganizationExUpdatedEvent(organizationId, loaded));
      } catch (e) {
        print('Failed to get organization ex $organizationId: $e');
        // 无缓存可兜底时向上抛出，让 view model 进入错误/重试分支；
        // 有旧缓存则降级返回旧数据。
        if (_organizationExDict[organizationId] == null) {
          rethrow;
        }
      }
    }
    return _organizationExDict[organizationId] ?? ex;
  }

  OrganizationEx? getOrganizationExSync(int organizationId,
      {bool refresh = false}) {
    var ex = _organizationExDict[organizationId];
    if (ex == null) {
      refresh = true;
      ex = OrganizationEx(
        organizationId: organizationId,
        organization: getOrganization(organizationId, refresh: false),
      );
    }

    if (refresh) {
      _service.getOrganizationEx(organizationId).then((loaded) {
        for (final sub in loaded.subOrganizations ?? []) {
          if (sub.id != 0) {
            _organizationDict[sub.id] = sub;
          }
        }
        for (final emp in loaded.employees ?? []) {
          _employeeDict[emp.employeeId] = emp;
        }
        _organizationExDict[organizationId] = loaded;
        eventBus.fire(OrganizationExUpdatedEvent(organizationId, loaded));
      }).catchError((error) {
        print('Failed to get organization ex $organizationId: $error');
      });
    }
    return ex;
  }
}
