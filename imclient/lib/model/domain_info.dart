class DomainInfo {
  DomainInfo({
    required this.domainId,
    this.name = '',
    this.desc,
    this.email,
    this.tel,
    this.address,
    this.extra,
    this.updateDt = 0,
  });

  /// 域 ID
  String domainId;

  /// 域名称
  String name;

  /// 域描述
  String? desc;

  /// 邮箱
  String? email;

  /// 电话
  String? tel;

  /// 地址
  String? address;

  /// 扩展信息
  String? extra;

  /// 更新时间
  int updateDt;

  factory DomainInfo.fromJson(Map<dynamic, dynamic> json) {
    return DomainInfo(
      domainId: json['domainId'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      desc: _emptyToNull(json['desc']),
      email: _emptyToNull(json['email']),
      tel: _emptyToNull(json['tel']),
      address: _emptyToNull(json['address']),
      extra: _emptyToNull(json['extra']),
      updateDt: json['updateDt'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'domainId': domainId,
      'name': name,
      'desc': desc,
      'email': email,
      'tel': tel,
      'address': address,
      'extra': extra,
      'updateDt': updateDt,
    };
  }

  static String? _emptyToNull(dynamic value) {
    if (value == null || value == '') return null;
    return value.toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DomainInfo &&
          runtimeType == other.runtimeType &&
          domainId == other.domainId &&
          updateDt == other.updateDt);

  @override
  int get hashCode => domainId.hashCode ^ updateDt.hashCode;

  @override
  String toString() {
    return 'DomainInfo{domainId: $domainId, name: $name}';
  }
}
