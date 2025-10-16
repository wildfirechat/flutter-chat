import './employee.dart';
import './organization_relationship.dart';

class EmployeeEx {
  final Employee? employee;
  final List<OrganizationRelationship>? relationships;

  EmployeeEx({
    this.employee,
    this.relationships,
  });

  factory EmployeeEx.fromJson(Map<String, dynamic> json) {
    return EmployeeEx(
      employee: json['employee'] != null
          ? Employee.fromJson(json['employee'])
          : null,
      relationships: json['relationships'] != null
          ? (json['relationships'] as List)
              .map((i) => OrganizationRelationship.fromJson(i))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employee': employee?.toJson(),
      'relationships': relationships?.map((e) => e.toJson()).toList(),
    };
  }
}
