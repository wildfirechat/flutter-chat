import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:wfc_example/config.dart';
import 'package:wfc_example/organization/model/organization.dart';
import 'package:wfc_example/organization/model/organization_ex.dart';
import 'package:wfc_example/organization/model/employee.dart';
import 'package:wfc_example/organization/model/employee_ex.dart';
import 'package:wfc_example/organization/model/organization_relationship.dart';
import 'package:imclient/imclient.dart';

class OrganizationService {
  bool _isServiceAvailable = false;
  String? _orgAuthToken;

  // Singleton pattern
  OrganizationService._privateConstructor();

  static final OrganizationService _instance = OrganizationService._privateConstructor();

  static OrganizationService get instance => _instance;

  String get _orgServerBaseUrl {
    if (Config.ORG_SERVER_ADDRESS == null || Config.ORG_SERVER_ADDRESS!.isEmpty) {
      throw Exception("ORG_SERVER_ADDRESS is not configured in config.dart");
    }
    return Config.ORG_SERVER_ADDRESS!;
  }

  Future<void> login() async {
    if (_isServiceAvailable) {
      return;
    }

    try {
      // Corresponds to ChatManager.Instance().getAuthCode("admin", 2, Config.IM_SERVER_HOST, callback)
      // The "admin" and type 2 might need to be configurable or based on current user.
      Completer<String> authCodeCompleter = Completer();
      Imclient.getAuthCode("admin", 2, Config.IM_Host, (str) {
        authCodeCompleter.complete(str);
      }, (err) {
        print('OrganizationService login failed $err');
      });

      String authCode = await authCodeCompleter.future;
      final response = await http.post(
        Uri.parse('$_orgServerBaseUrl/api/user_login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'authCode': authCode}),
      );

      if (response.statusCode == 200) {
        // Assuming the login endpoint might return a token or session info
        // If it just returns success, that's fine too.
        // final responseData = jsonDecode(response.body);
        _orgAuthToken ??= response.headers['authToken'] ?? response.headers['authtoken']; // authToken might be in lowercase
        _isServiceAvailable = true;
        print('OrganizationService login successful');
      } else {
        print('OrganizationService login failed: ${response.statusCode} ${response.body}');
        throw Exception('Failed to login to organization service: ${response.statusCode}');
      }
    } catch (e) {
      print('Error during organization service login: $e');
      _isServiceAvailable = false;
      throw Exception('Error during organization service login: $e');
    }
  }

  bool isServiceAvailable() {
    return _isServiceAvailable;
  }

  Future<T> _handleResponse<T>(http.Response response, T Function(dynamic json) fromJson) async {
    if (response.statusCode == 200) {
      try {
        // Check if the body is empty or not JSON
        if (response.body.isEmpty) {
          // If T is void or nullable, this might be acceptable
          if (null is T) {
            return null as T;
          } else {
            throw Exception('Empty response body where data was expected.');
          }
        }
        final dynamic jsonData = jsonDecode(response.body);
        // The API seems to wrap results in a 'result' field and includes 'code' and 'msg'
        // { "code": 0, "msg": "success", "result": { ... } } or { "code": 0, "msg": "success", "result": [ ... ] }
        if (jsonData is Map<String, dynamic> && jsonData.containsKey('code')) {
          if (jsonData['code'] == 0) {
            if (jsonData['result'] == null) {
              if (null is T) {
                return null as T;
              } else {
                // For void methods that return success with no data
                if (T.toString() == 'void') {
                  return null as T; // This is a bit of a hack for void
                }
                throw Exception('Response data is null but expected non-null.');
              }
            }
            return fromJson(jsonData['result']);
          } else {
            throw Exception('API Error: ${jsonData['code']} - ${jsonData['msg']}');
          }
        } else {
          // Fallback if the structure is not as expected, try to parse directly
          return fromJson(jsonData);
        }
      } catch (e) {
        print("Error parsing response: $e, body: ${response.body}");
        throw Exception("Error parsing response: $e");
      }
    } else {
      print("API Error: ${response.statusCode}, body: ${response.body}");
      throw Exception('API Error: ${response.statusCode}');
    }
  }

  Future<List<OrganizationRelationship>> getRelationship(String employeeId) async {
    if (!_isServiceAvailable) throw Exception('Service not available. Call login() first.');
    final response = await _post(
      '$_orgServerBaseUrl/api/relationship/employee',
      {'employeeId': employeeId},
    );
    return _handleResponse<List<OrganizationRelationship>>(response, (json) {
      return (json as List).map((item) => OrganizationRelationship.fromJson(item)).toList();
    });
  }

  Future<List<Organization>> getRootOrganization() async {
    if (!_isServiceAvailable) throw Exception('Service not available. Call login() first.');
    final response = await _post(
      '$_orgServerBaseUrl/api/organization/root',
      {},
    );
    return _handleResponse<List<Organization>>(response, (json) {
      return (json as List).map((item) => Organization.fromJson(item)).toList();
    });
  }

  Future<OrganizationEx> getOrganizationEx(int orgId) async {
    if (!_isServiceAvailable) throw Exception('Service not available. Call login() first.');
    final response = await _post(
      '$_orgServerBaseUrl/api/organization/query_ex',
      {'id': orgId},
    );
    return _handleResponse<OrganizationEx>(response, (json) => OrganizationEx.fromJson(json));
  }

  Future<List<Organization>> getOrganizations(List<int> orgIds) async {
    if (!_isServiceAvailable) throw Exception('Service not available. Call login() first.');
    final response = await _post(
      '$_orgServerBaseUrl/api/organization/query_list',
      {'ids': orgIds},
    );
    return _handleResponse<List<Organization>>(response, (json) {
      return (json as List).map((item) => Organization.fromJson(item)).toList();
    });
  }

  Future<List<String>> getOrgEmployees(int orgId) async {
    if (!_isServiceAvailable) throw Exception('Service not available. Call login() first.');
    final response = await _post(
      '$_orgServerBaseUrl/api/organization/employees',
      {'id': orgId},
    );
    return _handleResponse<List<String>>(response, (json) {
      return (json as List).map((item) => item.toString()).toList();
    });
  }

  // Overloaded method for batch fetching employees - getOrgEmployees(List<int> orgIds, ...)
  Future<List<String>> getOrgEmployeesByOrgIds(List<int> orgIds) async {
    if (!_isServiceAvailable) throw Exception('Service not available. Call login() first.');
    final response = await _post(
      '$_orgServerBaseUrl/api/organization/batch_employees',
      {'ids': orgIds},
    );
    return _handleResponse<List<String>>(response, (json) {
      return (json as List).map((item) => item.toString()).toList();
    });
  }

  Future<Employee> getEmployee(String employeeId) async {
    if (!_isServiceAvailable) throw Exception('Service not available. Call login() first.');
    final response = await _post(
      '$_orgServerBaseUrl/api/employee/query',
      {'employeeId': employeeId},
    );
    return _handleResponse<Employee>(response, (json) => Employee.fromJson(json));
  }

  Future<EmployeeEx> getEmployeeEx(String employeeId) async {
    if (!_isServiceAvailable) throw Exception('Service not available. Call login() first.');
    final response = await _post(
      '$_orgServerBaseUrl/api/employee/query_ex',
      {'employeeId': employeeId},
    );
    return _handleResponse<EmployeeEx>(response, (json) => EmployeeEx.fromJson(json));
  }

  Future<List<Employee>> searchEmployee(int orgId, String keyword) async {
    if (!_isServiceAvailable) throw Exception('Service not available. Call login() first.');
    final response = await _post(
      '$_orgServerBaseUrl/api/employee/search',
      {'organizationId': orgId, 'keyword': keyword},
    );
    return _handleResponse<List<Employee>>(response, (json) {
      return (json as List).map((item) => Employee.fromJson(item)).toList();
    });
  }

  _post(String url, Map<String, dynamic> body) async {
    return await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json', 'authToken': _orgAuthToken!},
      body: jsonEncode(body),
    );
  }

  void clearOrgServiceAuthInfos() {
    _isServiceAvailable = false;
    _orgAuthToken = null;
    // Potentially clear other cached org data if necessary
  }
}
