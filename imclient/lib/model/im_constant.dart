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
  ///模糊搜索diaplayName，精确匹配name或电话或用户ID
  SearchUserType_General,

  ///精确匹配name或电话
  SearchUserType_Name_Mobile,

  ///精确匹配name
  SearchUserType_Name,

  ///精确匹配电话
  SearchUserType_Mobile,

  ///精确匹配用户ID
  SearchUserType_UserId,

  ///精确匹配name或电话或用户ID
  SearchUserType_Name_Mobile_UserId,
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

class UserSettingScope {
  ///不能直接使用，调用setConversation:silent:方法会使用到此值。
  static const int Conversation_Silent = 1;

  ///不能直接使用
  static const int Global_Silent = 2;

  ///不能直接使用，调用setConversation:top:方法会使用到此值。
  static const int Conversation_Top = 3;

  ///不能直接使用
  static const int Hidden_Notification_Detail = 4;

  ///不能直接使用
  static const int Group_Hide_Nickname = 5;

  ///不能直接使用
  static const int Favourite_Group = 6;

  ///不能直接使用，协议栈内会使用此值
  static const int Conversation_Sync = 7;

  ///不能直接使用，协议栈内会使用此值
  static const int My_Channel = 8;

  ///不能直接使用，协议栈内会使用此值
  static const int Listened_Channel = 9;

  ///不能直接使用，协议栈内会使用此值
  static const int PC_Online = 10;

  ///不能直接使用，协议栈内会使用此值
  static const int Conversation_Readed = 11;

  ///不能直接使用，协议栈内会使用此值
  static const int WebOnline = 12;

  ///不能直接使用，协议栈内会使用此值
  static const int DisableRecipt = 13;

  ///不能直接使用
  static const int Favourite_User = 14;

  ///不能直接使用
  static const int Mute_When_PC_Online = 15;

  ///不能直接使用
  static const int Lines_Readed = 16;

  ///不能直接使用
  static const int No_Disturbing = 17;

  ///不能直接使用，协议栈内会使用此值
  static const int Conversation_Clear_Message = 18;

  ///不能直接使用，协议栈内会使用此值
  static const int Conversation_Draft = 19;

  ///不能直接使用，协议栈内会使用此值
  static const int Disable_Sync_Draft = 20;

  ///不能直接使用，协议栈内会使用此值
  static const int Voip_Silent = 21;

  ///不能直接使用，协议栈内会使用此值
  static const int PTT_Reserved = 22;

  ///不能直接使用，协议栈内会使用此值
  static const int Custom_State = 23;

  ///不能直接使用，协议栈内会使用此值
  static const int Disable_Secret_Chat = 24;

  ///不能直接使用，协议栈内会使用此值
  static const int Ptt_Silent = 25;

  ///不能直接使用，协议栈内会使用此值
  static const int Group_Remark = 26;

  ///不能直接使用，协议栈内会使用此值
  static const int Privacy_Searchable = 27;

  ///不能直接使用，协议栈内会使用此值
  static const int AddFriend_NoVerify = 28;

  ///不能直接使用，协议栈内会使用此值
  static const int Sync_Badge = 29;

  ///不能直接使用
  static const int Lock_PC = 30;

  ///自定义用户设置，请使用1000以上的key
  static const int Custom_Begin = 1000;
}
