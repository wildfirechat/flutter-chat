import 'package:imclient/model/user_info.dart';

class Employee {
  final String employeeId;
  final int organizationId;
  final String name;
  final String? title;
  final int level;
  final String? mobile;
  final String? email;
  final String? ext;
  final String? office;
  final String? city;
  final String? portraitUrl;
  final String? jobNumber;
  final String? joinTime;
  final int type;
  final int gender;
  final int sort;
  final int createDt;
  final int updateDt;

  Employee({
    required this.employeeId,
    required this.organizationId,
    required this.name,
    this.title,
    required this.level,
    this.mobile,
    this.email,
    this.ext,
    this.office,
    this.city,
    this.portraitUrl,
    this.jobNumber,
    this.joinTime,
    required this.type,
    required this.gender,
    required this.sort,
    required this.createDt,
    required this.updateDt,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      employeeId: json['employeeId'],
      organizationId: json['organizationId'] ?? 0,
      name: json['name'],
      title: json['title'],
      level: json['level'] ?? 0,
      mobile: json['mobile'],
      email: json['email'],
      ext: json['ext'],
      office: json['office'],
      city: json['city'],
      portraitUrl: json['portraitUrl'],
      jobNumber: json['jobNumber'],
      joinTime: json['joinTime'],
      type: json['type'] ?? 0,
      gender: json['gender'] ?? 0,
      sort: json['sort'] ?? 0,
      createDt: json['createDt'] ?? 0,
      updateDt: json['updateDt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employeeId': employeeId,
      'organizationId': organizationId,
      'name': name,
      'title': title,
      'level': level,
      'mobile': mobile,
      'email': email,
      'ext': ext,
      'office': office,
      'city': city,
      'portraitUrl': portraitUrl,
      'jobNumber': jobNumber,
      'joinTime': joinTime,
      'type': type,
      'gender': gender,
      'sort': sort,
      'createDt': createDt,
      'updateDt': updateDt,
    };
  }

  UserInfo toUserInfo() {
    return UserInfo()
      ..userId = employeeId!
      ..displayName = name
      ..portrait = portraitUrl
      ..mobile = mobile!
      ..updateDt = updateDt
      ..type = type;
  }
}
