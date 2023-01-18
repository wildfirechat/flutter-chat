enum ModifyMyInfoType {
  Modify_DisplayName,
  Modify_Portrait,
  Modify_Gender,
  Modify_Mobile,
  Modify_Email,
  Modify_Address,
  Modify_Company,
  Modify_Social,
  Modify_Extra,
}

enum ModifyGroupInfoType {
  Modify_Group_Name,
  Modify_Group_Portrait,
  Modify_Group_Extra,
  Modify_Group_Mute,
  Modify_Group_JoinType,
  Modify_Group_PrivateChat,
  Modify_Group_Searchable,
  Modify_Group_History_Message,
  Modify_Group_Max_Member_Count
}

enum ModifyChannelInfoType {
  Modify_Channel_Name,
  Modify_Channel_Portrait,
  Modify_Channel_Desc,
  Modify_Channel_Extra,
  Modify_Channel_Secret,
  Modify_Channel_Callback
}

enum SearchUserType {
  ///模糊搜索diaplayName，精确匹配name和电话
  SearchUserType_General,

  ///精确匹配name和电话
  SearchUserType_Name_Mobile,

  ///精确匹配name
  SearchUserType_Name,

  ///精确匹配电话
  SearchUserType_Mobile,
}

enum PlatformType {
  PlatformType_UNSET,
  PlatformType_iOS,
  PlatformType_Android,
  PlatformType_Windows,
  PlatformType_OSX,
  PlatformType_WEB,
  PlatformType_WX,
  PlatformType_Linux,
}
