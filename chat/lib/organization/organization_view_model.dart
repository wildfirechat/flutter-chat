import 'package:flutter/foundation.dart';
import 'package:imclient/imclient.dart';
import 'package:chat/organization/model/organization_relationship.dart';
import 'model/organization.dart';
import 'model/organization_ex.dart';
import 'organization_service.dart';

// TODO
// 目前只支持单个公司，及单个根部门
class OrganizationViewModel extends ChangeNotifier {
  final OrganizationService _service = OrganizationService.instance;
  OrganizationEx? _currentOrganizationDetails;
  final List<Organization> _breadcrumbPath = [];
  bool _isLoading = true;
  String? _error;
  List<Organization> _rootOrganizations = [];
  List<Organization> _myOrganizations = [];

  OrganizationEx? get currentOrganizationDetails => _currentOrganizationDetails;

  List<Organization> get breadcrumbPath => _breadcrumbPath;

  bool get isLoading => _isLoading;

  String? get error => _error;

  String? get appBarTitle => _breadcrumbPath.isNotEmpty ? _breadcrumbPath.first.name : null;

  List<Organization> get myOrganizations => _myOrganizations;

  List<Organization> get rootOrganizations => _rootOrganizations;

  Future<void> _ensureLoggedIn() async {
    if (!_service.isServiceAvailable()) {
      await _service.login();
    }
  }

  Future<void> loadMyOrganizations() async {
    try {
      await _ensureLoggedIn();
      _rootOrganizations = await _service.getRootOrganization();
      List<OrganizationRelationship> orgRelations = await _service.getRelationship(Imclient.currentUserId);
      orgRelations.removeWhere((org) => !org.bottom);
      List<int> orgIds = orgRelations.map((r) => r.organizationId).toList();
      if (orgIds.isEmpty) {
        _myOrganizations = [];
      } else {
        _myOrganizations = await _service.getOrganizations(orgIds);
      }
      print('loading my organizations: $_myOrganizations, $_rootOrganizations');
      notifyListeners();
    } catch (e) {
      print('Error loading my organizations: $e');
    }
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

  Future<void> _loadOrganizationDataInternal(int organizationId, {Organization? orgForBreadcrumb, bool isInitialRoot = false}) async {
    _isLoading = true;
    _error = null;
    // Do not notify listeners here if called from another method that handles it at start/end
    // Or, if this is a direct user action like retry, then notify at start.

    try {
      await _ensureLoggedIn();
      final details = await _service.getOrganizationEx(organizationId);
      _currentOrganizationDetails = details;

      if (isInitialRoot && orgForBreadcrumb != null) {
        // _breadcrumbPath = [orgForBreadcrumb];
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
    var orgs = await _service.getOrganizations([orgId]);
    if (orgs.isNotEmpty) {
      var org = orgs[0];
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
        await _loadOrganizationDataInternal(_breadcrumbPath.last.id!, orgForBreadcrumb: _breadcrumbPath.last);
      } else if (currentOrganizationDetails != null) {
        await _loadOrganizationDataInternal(currentOrganizationDetails!.organizationId, orgForBreadcrumb: currentOrganizationDetails?.organization);
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
