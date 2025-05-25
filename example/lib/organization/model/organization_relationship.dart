class OrganizationRelationship {
  final String? employeeId;
  final int organizationId;
  final int depth;
  final bool bottom;
  final int parentOrganizationId;

  OrganizationRelationship({
    this.employeeId,
    required this.organizationId,
    required this.depth,
    required this.bottom,
    required this.parentOrganizationId,
  });

  factory OrganizationRelationship.fromJson(Map<String, dynamic> json) {
    return OrganizationRelationship(
      employeeId: json['employeeId'],
      organizationId: json['organizationId'] ?? 0,
      depth: json['depth'] ?? 0,
      bottom: json['bottom'] ?? false,
      parentOrganizationId: json['parentOrganizationId'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employeeId': employeeId,
      'organizationId': organizationId,
      'depth': depth,
      'bottom': bottom,
      'parentOrganizationId': parentOrganizationId,
    };
  }
}
