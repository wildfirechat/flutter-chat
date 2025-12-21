import './employee.dart';
import './organization.dart';

class OrganizationEx {
  final int organizationId;
  final Organization? organization;
  final List<Organization>? subOrganizations;
  final List<Employee>? employees;

  OrganizationEx({
    required this.organizationId,
    this.organization,
    this.subOrganizations,
    this.employees,
  });

  factory OrganizationEx.fromJson(Map<String, dynamic> json) {
    return OrganizationEx(
      organizationId: json['organizationId'] ?? 0,
      organization: json['organization'] != null
          ? Organization.fromJson(json['organization'])
          : null,
      subOrganizations: json['subOrganizations'] != null
          ? (json['subOrganizations'] as List)
              .map((i) => Organization.fromJson(i))
              .toList()
          : null,
      employees: json['employees'] != null
          ? (json['employees'] as List)
              .map((i) => Employee.fromJson(i))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'organizationId': organizationId,
      'organization': organization?.toJson(),
      'subOrganizations':
          subOrganizations?.map((e) => e.toJson()).toList(),
      'employees': employees?.map((e) => e.toJson()).toList(),
    };
  }
}
