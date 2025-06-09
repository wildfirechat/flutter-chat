class Organization {
  final int id;
  final int parentId;
  final String managerId;
  final String name;
  final String? desc;
  final String? portraitUrl;
  final String? tel;
  final String? office;
  final String? groupId;
  final int? memberCount;
  final int? sort;
  final int? updateDt; // Using int for timestamps, can be converted to DateTime
  final int? createDt;

  Organization({
    required this.id,
    required this.parentId,
    required this.managerId,
    required this.name,
    this.desc,
    this.portraitUrl,
    this.tel,
    this.office,
    this.groupId,
    this.memberCount,
    this.sort,
    this.updateDt,
    this.createDt,
  });

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id'] ?? 0,
      parentId: json['parentId'] ?? 0,
      managerId: json['managerId'],
      name: json['name'],
      desc: json['desc'],
      portraitUrl: json['portraitUrl'],
      tel: json['tel'],
      office: json['office'],
      groupId: json['groupId'],
      memberCount: json['memberCount'] ?? 0,
      sort: json['sort'] ?? 0,
      updateDt: json['updateDt'] ?? 0,
      createDt: json['createDt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parentId': parentId,
      'managerId': managerId,
      'name': name,
      'desc': desc,
      'portraitUrl': portraitUrl,
      'tel': tel,
      'office': office,
      'groupId': groupId,
      'memberCount': memberCount,
      'sort': sort,
      'updateDt': updateDt,
      'createDt': createDt,
    };
  }
}
