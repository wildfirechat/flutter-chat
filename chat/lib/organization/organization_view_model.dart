import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:chat/organization/model/organization_relationship.dart';
import 'package:chat/organization/model/employee.dart';
import 'model/organization.dart';
import 'model/organization_ex.dart';
import 'organization_service.dart';
import 'organization_cache.dart';

// TODO
// 目前只支持单个公司，及单个根部门
class OrganizationViewModel extends ChangeNotifier {
  final OrganizationService _service = OrganizationService.instance;
  final OrganizationCache _cache = OrganizationCache.instance;
  OrganizationEx? _currentOrganizationDetails;
  final List<Organization> _breadcrumbPath = [];
  bool _isLoading = true;
  String? _error;
  List<Organization> _rootOrganizations = [];
  List<Organization> _myOrganizations = [];

  String _searchQuery = '';
  List<Employee> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;

  OrganizationEx? get currentOrganizationDetails => _currentOrganizationDetails;

  List<Organization> get breadcrumbPath => _breadcrumbPath;

  bool get isLoading => _isLoading;

  String? get error => _error;

  String? get appBarTitle => _breadcrumbPath.isNotEmpty ? _breadcrumbPath.last.name : null;

  List<Organization> get myOrganizations => _myOrganizations;

  List<Organization> get rootOrganizations => _rootOrganizations;

  String get searchQuery => _searchQuery;

  List<Employee> get searchResults => _searchResults;

  bool get isSearching => _isSearching;

  String? get searchError => _searchError;

  Future<void> _ensureLoggedIn() async {
    if (!_service.isServiceAvailable()) {
      await _service.login();
    }
  }

  Future<void> loadMyOrganizations() async {
    try {
      await _ensureLoggedIn();
      _rootOrganizations = await _service.getRootOrganization();
      final currentUserId = Imclient.currentUserId;
      if (currentUserId == null || currentUserId.isEmpty) {
        _myOrganizations = [];
      } else {
        final orgRelations = await _cache.getRelationship(currentUserId);
        final bottomIds = orgRelations
            .where((r) => r.bottom)
            .map((r) => r.organizationId)
            .toList();
        if (bottomIds.isEmpty) {
          _myOrganizations = [];
        } else {
          final List<Organization> orgs = [];
          final List<int> missingIds = [];
          for (final id in bottomIds) {
            final cachedOrg = _cache.getOrganization(id, refresh: false);
            if (cachedOrg != null) {
              orgs.add(cachedOrg);
            } else {
              missingIds.add(id);
            }
          }
          if (missingIds.isNotEmpty) {
            final loaded = await _service.getOrganizations(missingIds);
            for (final org in loaded) {
              if (org.id != 0) {
                _cache.getOrganization(org.id, refresh: true);
                orgs.add(org);
              }
            }
          }
          _myOrganizations = orgs;
        }
      }
      print('loading my organizations: $_myOrganizations, $_rootOrganizations');
      notifyListeners();
    } catch (e) {
      print('Error loading my organizations: $e');
    }
  }

  Future<void> search(String keyword) async {
    _searchQuery = keyword;
    _searchError = null;

    if (keyword.trim().isEmpty) {
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      await _ensureLoggedIn();
      final int orgId = _breadcrumbPath.isNotEmpty
          ? _breadcrumbPath.last.id
          : (_currentOrganizationDetails?.organizationId ?? 0);
      if (orgId == 0) {
        _searchResults = [];
      } else {
        _searchResults = await _service.searchEmployee(orgId, keyword.trim());
      }
    } catch (e) {
      print('Error searching employees: $e');
      _searchError = '搜索失败: $e';
      _searchResults = [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchQuery = '';
    _searchResults = [];
    _searchError = null;
    _isSearching = false;
    notifyListeners();
  }

  Future<void> loadInitialData({int? organizationId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _ensureLoggedIn();
      if (organizationId != null) {
        await _getOrganizationPath(organizationId, _breadcrumbPath);
        await _loadOrganizationDataInternal(organizationId);
      } else {
        // No specific org, load root organizations and pick the first one
        final rootOrgs = await _service.getRootOrganization();
        if (rootOrgs.isNotEmpty) {
          _breadcrumbPath.add(rootOrgs.first);
          await _loadOrganizationDataInternal(rootOrgs.first.id, orgForBreadcrumb: rootOrgs.first, isInitialRoot: true);
        } else {
          throw Exception('No root organizations found.');
        }
      }
    } catch (e) {
      print('Error loading initial organization data: $e');
      _error = 'Failed to load initial data: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadOrganizationDataInternal(int organizationId, {Organization? orgForBreadcrumb, bool isInitialRoot = false, bool refresh = false}) async {
    _isLoading = true;
    _error = null;
    // Do not notify listeners here if called from another method that handles it at start/end
    // Or, if this is a direct user action like retry, then notify at start.

    try {
      await _ensureLoggedIn();
      final details = await _cache.getOrganizationEx(organizationId, refresh: refresh);
      _currentOrganizationDetails = details;

      if (isInitialRoot && orgForBreadcrumb != null) {
        // Ensure the root organization is present in the breadcrumb path.
        if (_breadcrumbPath.isEmpty || _breadcrumbPath.last.id != orgForBreadcrumb.id) {
          _breadcrumbPath.add(orgForBreadcrumb);
        }
      } else if (orgForBreadcrumb != null) {
        // This is a navigation to a sub-organization
        int existingIndex = _breadcrumbPath.indexWhere((o) => o.id == orgForBreadcrumb.id);
        if (existingIndex != -1) {
          // Navigating up via breadcrumb
          _breadcrumbPath.removeRange(existingIndex + 1, _breadcrumbPath.length);
        } else {
          // Navigating down
          _breadcrumbPath.add(orgForBreadcrumb);
        }
      }
      // If orgForBreadcrumb is null, it implies a refresh of the current view, path doesn't change.
    } catch (e) {
      print('Error loading organization details for $organizationId: $e');
      _error = 'Failed to load details: $e';
    } finally {
      _isLoading = false;
      notifyListeners(); // Ensure UI updates after loading or error
    }
  }

  getOrganizationPath(int orgId) async {
    List<Organization> outOrgPathList = [];
    await _getOrganizationPath(orgId, outOrgPathList);
    return outOrgPathList;
  }

  _getOrganizationPath(int orgId, List<Organization> outOrgPathList) async {
    var org = _cache.getOrganization(orgId, refresh: false);
    if (org == null) {
      var orgs = await _service.getOrganizations([orgId]);
      if (orgs.isNotEmpty) {
        org = orgs[0];
        _cache.getOrganization(orgId, refresh: true);
      }
    }

    if (org != null) {
      outOrgPathList.insert(0, org);
      if (org.parentId != 0) {
        await _getOrganizationPath(org.parentId, outOrgPathList);
      }
    }
  }

  Future<void> navigateToOrganization(Organization org) async {
    // org here is a simple Organization object, from sub-org list or breadcrumb
    _isLoading = true;
    notifyListeners();
    await _loadOrganizationDataInternal(org.id, orgForBreadcrumb: org);
  }

  Future<void> retryLoadData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _ensureLoggedIn();
      if (_breadcrumbPath.isNotEmpty) {
        // Retry loading the current organization in the breadcrumb path
        await _loadOrganizationDataInternal(_breadcrumbPath.last.id!, orgForBreadcrumb: _breadcrumbPath.last, refresh: true);
      } else if (currentOrganizationDetails != null) {
        await _loadOrganizationDataInternal(currentOrganizationDetails!.organizationId, orgForBreadcrumb: currentOrganizationDetails?.organization, refresh: true);
      } else {
        await loadInitialData();
      }
    } catch (e) {
      print('Error retrying data load: $e');
      _error = 'Failed to retry: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool canNavigateBackInHierarchy() {
    return _breadcrumbPath.length > 1;
  }

  Future<void> navigateBackInHierarchy() async {
    if (canNavigateBackInHierarchy()) {
      Organization parentOrg = _breadcrumbPath[_breadcrumbPath.length - 2];
      await navigateToOrganization(parentOrg); // This will update breadcrumb path correctly
    }
  }
}
