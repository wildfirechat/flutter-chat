#!/usr/bin/env python3
import re
import os

HANDLERS_BLOCK = r'''
static void WFCAPI OnSearchUserSuccess(void *p_obj, int data_type,
                                       const char *cval, size_t val_len) {
  int64_t request_id = reinterpret_cast<int64_t>(p_obj);
  std::string json_str(cval, val_len);
  flutter::EncodableValue value = JsonToEncodable(json_str);
  flutter::EncodableList users;
  if (auto *list = std::get_if<flutter::EncodableList>(&value)) {
    users = *list;
  }
  flutter::EncodableMap args;
  args[flutter::EncodableValue("requestId")] =
      flutter::EncodableValue(request_id);
  args[flutter::EncodableValue("users")] = flutter::EncodableValue(users);
  InvokeDartMethod("onSearchUserResult", args);
}

static void WFCAPI OnChatroomInfoSuccess(void *p_obj, int data_type,
                                         const char *cval, size_t val_len) {
  int64_t request_id = reinterpret_cast<int64_t>(p_obj);
  std::string json_str(cval, val_len);
  flutter::EncodableValue value = JsonToEncodable(json_str);
  flutter::EncodableMap args;
  args[flutter::EncodableValue("requestId")] =
      flutter::EncodableValue(request_id);
  args[flutter::EncodableValue("chatroomInfo")] = value;
  InvokeDartMethod("onGetChatroomInfoResult", args);
}

static void WFCAPI OnChatroomMemberInfoSuccess(void *p_obj, int data_type,
                                               const char *cval,
                                               size_t val_len) {
  int64_t request_id = reinterpret_cast<int64_t>(p_obj);
  std::string json_str(cval, val_len);
  flutter::EncodableValue value = JsonToEncodable(json_str);
  flutter::EncodableMap args;
  args[flutter::EncodableValue("requestId")] =
      flutter::EncodableValue(request_id);
  args[flutter::EncodableValue("chatroomMemberInfo")] = value;
  InvokeDartMethod("onGetChatroomMemberInfoResult", args);
}

static void WFCAPI OnCreateChannelSuccess(void *p_obj, int data_type,
                                          const char *cval, size_t val_len) {
  int64_t request_id = reinterpret_cast<int64_t>(p_obj);
  std::string json_str(cval, val_len);
  flutter::EncodableValue value = JsonToEncodable(json_str);
  flutter::EncodableMap channel_info;
  if (auto *map = std::get_if<flutter::EncodableMap>(&value)) {
    channel_info = *map;
  } else if (auto *str = std::get_if<std::string>(&value)) {
    channel_info[flutter::EncodableValue("channelId")] =
        flutter::EncodableValue(*str);
  } else {
    channel_info[flutter::EncodableValue("channelId")] =
        flutter::EncodableValue(json_str);
  }
  flutter::EncodableMap args;
  args[flutter::EncodableValue("requestId")] =
      flutter::EncodableValue(request_id);
  args[flutter::EncodableValue("channelInfo")] =
      flutter::EncodableValue(channel_info);
  InvokeDartMethod("onCreateChannelSuccess", args);
}

static void WFCAPI OnSearchChannelSuccess(void *p_obj, int data_type,
                                          const char *cval, size_t val_len) {
  int64_t request_id = reinterpret_cast<int64_t>(p_obj);
  std::string json_str(cval, val_len);
  flutter::EncodableValue value = JsonToEncodable(json_str);
  flutter::EncodableList channels;
  if (auto *list = std::get_if<flutter::EncodableList>(&value)) {
    channels = *list;
  }
  flutter::EncodableMap args;
  args[flutter::EncodableValue("requestId")] =
      flutter::EncodableValue(request_id);
  args[flutter::EncodableValue("channelInfos")] =
      flutter::EncodableValue(channels);
  InvokeDartMethod("onSearchChannelResult", args);
}

std::string BuildNotifyContentJson(const flutter::EncodableMap *args) {
  const flutter::EncodableValue *notify_value = FindRawValue(args, "notifyContent");
  if (!notify_value) return "";
  const flutter::EncodableMap *notify_map =
      std::get_if<flutter::EncodableMap>(notify_value);
  if (!notify_map) return "";
  MessagePayload payload(notify_map);
  return EncodableToJson(flutter::EncodableValue(payload.ToEncodable()));
}

void HandleStartLog(const flutter::EncodableMap *args,
                    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleStopLog(const flutter::EncodableMap *args,
                   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleSetSendLogCommand(const flutter::EncodableMap *args,
                             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleGetLogFilesPath(const flutter::EncodableMap *args,
                           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleSetDeviceToken(const flutter::EncodableMap *args,
                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleSetVoipDeviceToken(const flutter::EncodableMap *args,
                              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleGetUserInfo(const flutter::EncodableMap *args,
                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string user_id = GetString(args, "userId");
  bool refresh = GetBool(args, "refresh", false);
  std::string group_id = GetString(args, "groupId");
  size_t len = 0;
  const char *str = WFClient::getUserInfo(user_id.c_str(), user_id.size(),
                                          refresh, group_id.c_str(),
                                          group_id.size(), &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result->Success(JsonToEncodable(json_str));
}

void HandleGetUserInfos(const flutter::EncodableMap *args,
                        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::vector<std::string> user_ids = GetStringList(args, "userIds");
  std::string group_id = GetString(args, "groupId");
  std::vector<const char *> user_ptrs;
  std::vector<size_t> user_lengths;
  for (const auto &u : user_ids) {
    user_ptrs.push_back(u.c_str());
    user_lengths.push_back(u.size());
  }
  size_t len = 0;
  const char *str = WFClient::getUserInfos(
      user_ptrs.empty() ? nullptr : user_ptrs.data(),
      user_lengths.empty() ? nullptr : user_lengths.data(), user_ids.size(),
      group_id.c_str(), group_id.size(), &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result->Success(JsonToEncodable(json_str));
}

void HandleSearchUser(const flutter::EncodableMap *args,
                      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string keyword = GetString(args, "keyword");
  int search_type = static_cast<int>(GetInt(args, "searchType", 0));
  int page = static_cast<int>(GetInt(args, "page", 0));
  WFClient::searchUser(keyword.c_str(), keyword.size(), search_type, page,
                       OnSearchUserSuccess, OnGeneralError,
                       reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleGetUserInfoAsync(const flutter::EncodableMap *args,
                            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string user_id = GetString(args, "userId");
  bool refresh = GetBool(args, "refresh", false);
  std::string group_id = GetString(args, "groupId");
  size_t len = 0;
  const char *str = WFClient::getUserInfo(user_id.c_str(), user_id.size(),
                                          refresh, group_id.c_str(),
                                          group_id.size(), &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  flutter::EncodableMap callback_args;
  callback_args[flutter::EncodableValue("requestId")] =
      flutter::EncodableValue(request_id);
  callback_args[flutter::EncodableValue("user")] = JsonToEncodable(json_str);
  InvokeDartMethod("getUserInfoAsyncCallback", callback_args);
  result->Success();
}

void HandleIsMyFriend(const flutter::EncodableMap *args,
                      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string user_id = GetString(args, "userId");
  result->Success(flutter::EncodableValue(
      WFClient::isMyFriend(user_id.c_str(), user_id.size())));
}

void HandleGetMyFriendList(const flutter::EncodableMap *args,
                           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  bool refresh = GetBool(args, "refresh", false);
  size_t len = 0;
  const char *str = WFClient::getMyFriendList(refresh, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result->Success(JsonToEncodable(json_str));
}

void HandleSearchFriends(const flutter::EncodableMap *args,
                         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string keyword = GetString(args, "keyword");
  size_t len = 0;
  const char *str = WFClient::searchFriends(keyword.c_str(), keyword.size(), &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result->Success(JsonToEncodable(json_str));
}

void HandleGetFriends(const flutter::EncodableMap *args,
                      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleSearchGroups(const flutter::EncodableMap *args,
                        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string keyword = GetString(args, "keyword");
  size_t len = 0;
  const char *str = WFClient::searchGroups(keyword.c_str(), keyword.size(), &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result->Success(JsonToEncodable(json_str));
}

void HandleGetIncommingFriendRequest(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  size_t len = 0;
  const char *str = WFClient::getIncommingFriendRequest(&len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result->Success(JsonToEncodable(json_str));
}

void HandleGetOutgoingFriendRequest(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  size_t len = 0;
  const char *str = WFClient::getOutgoingFriendRequest(&len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result->Success(JsonToEncodable(json_str));
}

void HandleGetFriendRequest(const flutter::EncodableMap *args,
                            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string user_id = GetString(args, "userId");
  int direction = static_cast<int>(GetInt(args, "direction", 0));
  size_t len = 0;
  const char *str = WFClient::getFriendRequest(user_id.c_str(), user_id.size(),
                                               direction == 0, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result->Success(JsonToEncodable(json_str));
}

void HandleLoadFriendRequestFromRemote(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  WFClient::loadFriendRequestFromRemote();
  result->Success();
}

void HandleGetUnreadFriendRequestStatus(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success(
      flutter::EncodableValue(WFClient::getUnreadFriendRequestStatus()));
}

void HandleClearUnreadFriendRequestStatus(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  WFClient::clearUnreadFriendRequestStatus();
  result->Success(flutter::EncodableValue(true));
}

void HandleClearFriendRequest(const flutter::EncodableMap *args,
                              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleDeleteFriendRequest(const flutter::EncodableMap *args,
                               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleDeleteFriend(const flutter::EncodableMap *args,
                        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string user_id = GetString(args, "userId");
  WFClient::deleteFriend(user_id.c_str(), user_id.size(), OnGeneralVoidSuccess,
                         OnGeneralError, reinterpret_cast<void *>(request_id),
                         0);
  result->Success();
}

void HandleGetFriendAlias(const flutter::EncodableMap *args,
                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string user_id = GetString(args, "friendId");
  size_t len = 0;
  const char *str = WFClient::getFriendAlias(user_id.c_str(), user_id.size(),
                                             &len);
  std::string alias = ConvertDllStringAndRelease(str, len);
  result->Success(flutter::EncodableValue(alias));
}

void HandleSetFriendAlias(const flutter::EncodableMap *args,
                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string user_id = GetString(args, "friendId");
  std::string alias = GetString(args, "alias");
  WFClient::setFriendAlias(user_id.c_str(), user_id.size(), alias.c_str(),
                           alias.size(), OnGeneralVoidSuccess, OnGeneralError,
                           reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleGetFriendExtra(const flutter::EncodableMap *args,
                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string user_id = GetString(args, "userId");
  size_t len = 0;
  const char *str = WFClient::getFriendExtra(user_id.c_str(), user_id.size(),
                                             &len);
  std::string extra = ConvertDllStringAndRelease(str, len);
  result->Success(flutter::EncodableValue(extra));
}

void HandleSendFriendRequest(const flutter::EncodableMap *args,
                             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string user_id = GetString(args, "userId");
  std::string reason = GetString(args, "reason");
  WFClient::sendFriendRequest(user_id.c_str(), user_id.size(), reason.c_str(),
                              reason.size(), "", 0, OnGeneralVoidSuccess,
                              OnGeneralError, reinterpret_cast<void *>(request_id),
                              0);
  result->Success();
}

void HandleHandleFriendRequest(const flutter::EncodableMap *args,
                               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string user_id = GetString(args, "userId");
  bool accept = GetBool(args, "accept", false);
  std::string extra = GetString(args, "extra");
  WFClient::handleFriendRequest(user_id.c_str(), user_id.size(), accept,
                                extra.c_str(), extra.size(),
                                OnGeneralVoidSuccess, OnGeneralError,
                                reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleIsBlackListed(const flutter::EncodableMap *args,
                         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string user_id = GetString(args, "userId");
  result->Success(flutter::EncodableValue(
      WFClient::isBlackListed(user_id.c_str(), user_id.size())));
}

void HandleGetBlackList(const flutter::EncodableMap *args,
                        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  bool refresh = GetBool(args, "refresh", false);
  size_t len = 0;
  const char *str = WFClient::getBlackList(refresh, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result->Success(JsonToEncodable(json_str));
}

void HandleSetBlackList(const flutter::EncodableMap *args,
                        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string user_id = GetString(args, "userId");
  bool is_black_listed = GetBool(args, "isBlackListed", false);
  WFClient::setBlackList(user_id.c_str(), user_id.size(), is_black_listed,
                         OnGeneralVoidSuccess, OnGeneralError,
                         reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleGetGroupMembers(const flutter::EncodableMap *args,
                           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string group_id = GetString(args, "groupId");
  bool refresh = GetBool(args, "refresh", false);
  size_t len = 0;
  const char *str = WFClient::getGroupMembers(group_id.c_str(), group_id.size(),
                                              refresh, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result->Success(JsonToEncodable(json_str));
}

void HandleGetGroupMembersByCount(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string group_id = GetString(args, "groupId");
  int count = static_cast<int>(GetInt(args, "count", 0));
  size_t len = 0;
  const char *str = WFClient::getGroupMembersByCount(
      group_id.c_str(), group_id.size(), count, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result->Success(JsonToEncodable(json_str));
}

void HandleGetGroupMembersByTypes(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string group_id = GetString(args, "groupId");
  int member_type = static_cast<int>(GetInt(args, "memberType", 0));
  size_t len = 0;
  const char *str = WFClient::getGroupMembersByType(
      group_id.c_str(), group_id.size(), member_type, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result->Success(JsonToEncodable(json_str));
}

void HandleGetGroupMembersAsync(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string group_id = GetString(args, "groupId");
  bool refresh = GetBool(args, "refresh", false);
  size_t len = 0;
  const char *str = WFClient::getGroupMembers(group_id.c_str(), group_id.size(),
                                              refresh, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  flutter::EncodableValue value = JsonToEncodable(json_str);
  flutter::EncodableList members;
  if (auto *list = std::get_if<flutter::EncodableList>(&value)) {
    members = *list;
  }
  flutter::EncodableMap callback_args;
  callback_args[flutter::EncodableValue("requestId")] =
      flutter::EncodableValue(request_id);
  callback_args[flutter::EncodableValue("members")] =
      flutter::EncodableValue(members);
  InvokeDartMethod("getGroupMembersAsyncCallback", callback_args);
  result->Success();
}

void HandleGetGroupInfo(const flutter::EncodableMap *args,
                        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string group_id = GetString(args, "groupId");
  bool refresh = GetBool(args, "refresh", false);
  size_t len = 0;
  const char *str = WFClient::getGroupInfo(group_id.c_str(), group_id.size(),
                                           refresh, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result->Success(JsonToEncodable(json_str));
}

void HandleGetGroupInfos(const flutter::EncodableMap *args,
                         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::vector<std::string> group_ids = GetStringList(args, "groupIds");
  flutter::EncodableList groups;
  for (const auto &group_id : group_ids) {
    size_t len = 0;
    const char *str = WFClient::getGroupInfo(group_id.c_str(), group_id.size(),
                                             false, &len);
    std::string json_str = ConvertDllStringAndRelease(str, len);
    groups.push_back(JsonToEncodable(json_str));
  }
  result->Success(flutter::EncodableValue(groups));
}

void HandleGetGroupInfoAsync(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string group_id = GetString(args, "groupId");
  bool refresh = GetBool(args, "refresh", false);
  size_t len = 0;
  const char *str = WFClient::getGroupInfo(group_id.c_str(), group_id.size(),
                                           refresh, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  flutter::EncodableMap callback_args;
  callback_args[flutter::EncodableValue("requestId")] =
      flutter::EncodableValue(request_id);
  callback_args[flutter::EncodableValue("groupInfo")] =
      JsonToEncodable(json_str);
  InvokeDartMethod("getGroupInfoAsyncCallback", callback_args);
  result->Success();
}

void HandleGetGroupMember(const flutter::EncodableMap *args,
                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string group_id = GetString(args, "groupId");
  std::string member_id = GetString(args, "memberId");
  size_t len = 0;
  const char *str = WFClient::getGroupMember(group_id.c_str(), group_id.size(),
                                             member_id.c_str(),
                                             member_id.size(), &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result->Success(JsonToEncodable(json_str));
}

void HandleCreateGroup(const flutter::EncodableMap *args,
                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string group_id = GetString(args, "groupId");
  std::string group_name = GetString(args, "groupName");
  std::string group_portrait = GetString(args, "groupPortrait");
  int group_type = static_cast<int>(GetInt(args, "type", 0));
  std::vector<std::string> members = GetStringList(args, "groupMembers");
  std::vector<const char *> user_ptrs;
  std::vector<size_t> user_lengths;
  for (const auto &u : members) {
    user_ptrs.push_back(u.c_str());
    user_lengths.push_back(u.size());
  }
  std::vector<int> lines = GetIntList(args, "notifyLines");
  if (lines.empty()) lines.push_back(0);
  std::string notify_content = BuildNotifyContentJson(args);

  WFClient::createGroup(
      group_id.c_str(), group_id.size(), group_type, group_name.c_str(),
      group_name.size(), group_portrait.c_str(), group_portrait.size(), "", 0,
      user_ptrs.empty() ? nullptr : user_ptrs.data(),
      user_lengths.empty() ? nullptr : user_lengths.data(), members.size(),
      "", 0, lines.data(), static_cast<int>(lines.size()),
      notify_content.c_str(), notify_content.size(), OnGeneralStringSuccess,
      OnGeneralError, reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleAddGroupMembers(const flutter::EncodableMap *args,
                           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string group_id = GetString(args, "groupId");
  std::vector<std::string> members = GetStringList(args, "groupMembers");
  std::vector<const char *> user_ptrs;
  std::vector<size_t> user_lengths;
  for (const auto &u : members) {
    user_ptrs.push_back(u.c_str());
    user_lengths.push_back(u.size());
  }
  std::vector<int> lines = GetIntList(args, "notifyLines");
  if (lines.empty()) lines.push_back(0);
  std::string notify_content = BuildNotifyContentJson(args);

  WFClient::addMembers(
      group_id.c_str(), group_id.size(),
      user_ptrs.empty() ? nullptr : user_ptrs.data(),
      user_lengths.empty() ? nullptr : user_lengths.data(), members.size(),
      "", 0, lines.data(), static_cast<int>(lines.size()),
      notify_content.c_str(), notify_content.size(), OnGeneralVoidSuccess,
      OnGeneralError, reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleKickoffGroupMembers(const flutter::EncodableMap *args,
                               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string group_id = GetString(args, "groupId");
  std::vector<std::string> members = GetStringList(args, "groupMembers");
  std::vector<const char *> user_ptrs;
  std::vector<size_t> user_lengths;
  for (const auto &u : members) {
    user_ptrs.push_back(u.c_str());
    user_lengths.push_back(u.size());
  }
  std::vector<int> lines = GetIntList(args, "notifyLines");
  if (lines.empty()) lines.push_back(0);
  std::string notify_content = BuildNotifyContentJson(args);

  WFClient::kickoffMembers(
      group_id.c_str(), group_id.size(),
      user_ptrs.empty() ? nullptr : user_ptrs.data(),
      user_lengths.empty() ? nullptr : user_lengths.data(), members.size(),
      lines.data(), static_cast<int>(lines.size()),
      notify_content.c_str(), notify_content.size(), OnGeneralVoidSuccess,
      OnGeneralError, reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleQuitGroup(const flutter::EncodableMap *args,
                     std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string group_id = GetString(args, "groupId");
  std::vector<int> lines = GetIntList(args, "notifyLines");
  if (lines.empty()) lines.push_back(0);
  std::string notify_content = BuildNotifyContentJson(args);

  WFClient::quitGroup(group_id.c_str(), group_id.size(), lines.data(),
                      static_cast<int>(lines.size()),
                      notify_content.c_str(), notify_content.size(),
                      OnGeneralVoidSuccess, OnGeneralError,
                      reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleQuitGroupEx(const flutter::EncodableMap *args,
                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleDismissGroup(const flutter::EncodableMap *args,
                        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string group_id = GetString(args, "groupId");
  std::vector<int> lines = GetIntList(args, "notifyLines");
  if (lines.empty()) lines.push_back(0);
  std::string notify_content = BuildNotifyContentJson(args);

  WFClient::dismissGroup(group_id.c_str(), group_id.size(), lines.data(),
                         static_cast<int>(lines.size()),
                         notify_content.c_str(), notify_content.size(),
                         OnGeneralVoidSuccess, OnGeneralError,
                         reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleModifyGroupInfo(const flutter::EncodableMap *args,
                           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string group_id = GetString(args, "groupId");
  int modify_type = static_cast<int>(GetInt(args, "modifyType", 0));
  std::string value = GetString(args, "value");
  std::vector<int> lines = GetIntList(args, "notifyLines");
  if (lines.empty()) lines.push_back(0);
  std::string notify_content = BuildNotifyContentJson(args);

  WFClient::modifyGroupInfo(group_id.c_str(), group_id.size(), modify_type,
                            value.c_str(), value.size(), lines.data(),
                            static_cast<int>(lines.size()),
                            notify_content.c_str(), notify_content.size(),
                            OnGeneralVoidSuccess, OnGeneralError,
                            reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleModifyGroupAlias(const flutter::EncodableMap *args,
                            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string group_id = GetString(args, "groupId");
  std::string new_alias = GetString(args, "newAlias");
  std::vector<int> lines = GetIntList(args, "notifyLines");
  if (lines.empty()) lines.push_back(0);
  std::string notify_content = BuildNotifyContentJson(args);

  WFClient::modifyGroupAlias(group_id.c_str(), group_id.size(),
                             new_alias.c_str(), new_alias.size(), lines.data(),
                             static_cast<int>(lines.size()),
                             notify_content.c_str(), notify_content.size(),
                             OnGeneralVoidSuccess, OnGeneralError,
                             reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleModifyGroupMemberAlias(const flutter::EncodableMap *args,
                                  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string group_id = GetString(args, "groupId");
  std::string member_id = GetString(args, "memberId");
  std::string new_alias = GetString(args, "newAlias");
  std::vector<int> lines = GetIntList(args, "notifyLines");
  if (lines.empty()) lines.push_back(0);
  std::string notify_content = BuildNotifyContentJson(args);

  WFClient::modifyGroupMemberAlias(group_id.c_str(), group_id.size(),
                                   member_id.c_str(), member_id.size(),
                                   new_alias.c_str(), new_alias.size(),
                                   lines.data(), static_cast<int>(lines.size()),
                                   notify_content.c_str(),
                                   notify_content.size(), OnGeneralVoidSuccess,
                                   OnGeneralError,
                                   reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleTransferGroup(const flutter::EncodableMap *args,
                         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string group_id = GetString(args, "groupId");
  std::string new_owner = GetString(args, "newOwner");
  std::vector<int> lines = GetIntList(args, "notifyLines");
  if (lines.empty()) lines.push_back(0);
  std::string notify_content = BuildNotifyContentJson(args);

  WFClient::transferGroup(group_id.c_str(), group_id.size(),
                          new_owner.c_str(), new_owner.size(), lines.data(),
                          static_cast<int>(lines.size()),
                          notify_content.c_str(), notify_content.size(),
                          OnGeneralVoidSuccess, OnGeneralError,
                          reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleSetGroupManager(const flutter::EncodableMap *args,
                           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string group_id = GetString(args, "groupId");
  bool is_set = GetBool(args, "isSet", false);
  std::vector<std::string> member_ids = GetStringList(args, "memberIds");
  std::vector<const char *> user_ptrs;
  std::vector<size_t> user_lengths;
  for (const auto &u : member_ids) {
    user_ptrs.push_back(u.c_str());
    user_lengths.push_back(u.size());
  }
  std::vector<int> lines = GetIntList(args, "notifyLines");
  if (lines.empty()) lines.push_back(0);
  std::string notify_content = BuildNotifyContentJson(args);

  WFClient::setGroupManager(
      group_id.c_str(), group_id.size(), is_set,
      user_ptrs.empty() ? nullptr : user_ptrs.data(),
      user_lengths.empty() ? nullptr : user_lengths.data(), member_ids.size(),
      lines.data(), static_cast<int>(lines.size()),
      notify_content.c_str(), notify_content.size(), OnGeneralVoidSuccess,
      OnGeneralError, reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleMuteGroupMember(const flutter::EncodableMap *args,
                           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string group_id = GetString(args, "groupId");
  bool is_set = GetBool(args, "isSet", false);
  std::vector<std::string> member_ids = GetStringList(args, "memberIds");
  std::vector<const char *> user_ptrs;
  std::vector<size_t> user_lengths;
  for (const auto &u : member_ids) {
    user_ptrs.push_back(u.c_str());
    user_lengths.push_back(u.size());
  }
  std::vector<int> lines = GetIntList(args, "notifyLines");
  if (lines.empty()) lines.push_back(0);
  std::string notify_content = BuildNotifyContentJson(args);

  WFClient::muteGroupMember(
      group_id.c_str(), group_id.size(), is_set,
      user_ptrs.empty() ? nullptr : user_ptrs.data(),
      user_lengths.empty() ? nullptr : user_lengths.data(), member_ids.size(),
      lines.data(), static_cast<int>(lines.size()),
      notify_content.c_str(), notify_content.size(), OnGeneralVoidSuccess,
      OnGeneralError, reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleAllowGroupMember(const flutter::EncodableMap *args,
                            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string group_id = GetString(args, "groupId");
  bool is_set = GetBool(args, "isSet", false);
  std::vector<std::string> member_ids = GetStringList(args, "memberIds");
  std::vector<const char *> user_ptrs;
  std::vector<size_t> user_lengths;
  for (const auto &u : member_ids) {
    user_ptrs.push_back(u.c_str());
    user_lengths.push_back(u.size());
  }
  std::vector<int> lines = GetIntList(args, "notifyLines");
  if (lines.empty()) lines.push_back(0);
  std::string notify_content = BuildNotifyContentJson(args);

  WFClient::allowGroupMember(
      group_id.c_str(), group_id.size(), is_set,
      user_ptrs.empty() ? nullptr : user_ptrs.data(),
      user_lengths.empty() ? nullptr : user_lengths.data(), member_ids.size(),
      lines.data(), static_cast<int>(lines.size()),
      notify_content.c_str(), notify_content.size(), OnGeneralVoidSuccess,
      OnGeneralError, reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleGetGroupRemark(const flutter::EncodableMap *args,
                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleSetGroupRemark(const flutter::EncodableMap *args,
                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleGetFavGroups(const flutter::EncodableMap *args,
                        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  size_t len = 0;
  const char *str = WFClient::getFavGroups(&len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result->Success(JsonToEncodable(json_str));
}

void HandleIsFavGroup(const flutter::EncodableMap *args,
                      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string group_id = GetString(args, "groupId");
  result->Success(flutter::EncodableValue(
      WFClient::isFavGroup(group_id.c_str(), group_id.size())));
}

void HandleSetFavGroup(const flutter::EncodableMap *args,
                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string group_id = GetString(args, "groupId");
  bool fav = GetBool(args, "isFav", false);
  WFClient::setFavGroup(group_id.c_str(), group_id.size(), fav,
                        OnGeneralVoidSuccess, OnGeneralError,
                        reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleGetUserSetting(const flutter::EncodableMap *args,
                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int scope = static_cast<int>(GetInt(args, "scope", 0));
  std::string key = GetString(args, "key");
  size_t len = 0;
  const char *str = WFClient::getUserSetting(scope, key.c_str(), key.size(),
                                             &len);
  std::string value = ConvertDllStringAndRelease(str, len);
  result->Success(flutter::EncodableValue(value));
}

void HandleGetUserSettings(const flutter::EncodableMap *args,
                           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int scope = static_cast<int>(GetInt(args, "scope", 0));
  size_t len = 0;
  const char *str = WFClient::getUserSettings(scope, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result->Success(JsonToEncodable(json_str));
}

void HandleSetUserSetting(const flutter::EncodableMap *args,
                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  int scope = static_cast<int>(GetInt(args, "scope", 0));
  std::string key = GetString(args, "key");
  std::string value = GetString(args, "value");
  WFClient::setUserSetting(scope, key.c_str(), key.size(), value.c_str(),
                           value.size(), OnGeneralVoidSuccess, OnGeneralError,
                           reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleModifyMyInfo(const flutter::EncodableMap *args,
                        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  flutter::EncodableMap values = GetMap(args, "values");
  for (const auto &pair : values) {
    int type = 0;
    if (auto *i = std::get_if<int>(&pair.first)) {
      type = *i;
    } else if (auto *i64 = std::get_if<int64_t>(&pair.first)) {
      type = static_cast<int>(*i64);
    }
    std::string value;
    if (auto *s = std::get_if<std::string>(&pair.second)) {
      value = *s;
    }
    if (!value.empty()) {
      WFClient::modifyMyInfo(type, value.c_str(), value.size(),
                             OnGeneralVoidSuccess, OnGeneralError,
                             reinterpret_cast<void *>(request_id), 0);
    }
  }
  result->Success();
}

void HandleIsGlobalSilent(const flutter::EncodableMap *args,
                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success(flutter::EncodableValue(WFClient::isGlobalSilent()));
}

void HandleSetGlobalSilent(const flutter::EncodableMap *args,
                           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  bool is_silent = GetBool(args, "isSilent", false);
  WFClient::setGlobalSilent(is_silent, OnGeneralVoidSuccess, OnGeneralError,
                            reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleIsVoipNotificationSilent(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleSetVoipNotificationSilent(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleIsEnableSyncDraft(const flutter::EncodableMap *args,
                             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleSetEnableSyncDraft(const flutter::EncodableMap *args,
                              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleGetNoDisturbingTimes(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleSetNoDisturbingTimes(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleClearNoDisturbingTimes(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleIsNoDisturbing(const flutter::EncodableMap *args,
                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleIsHiddenNotificationDetail(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success(flutter::EncodableValue(WFClient::isHiddenNotificationDetail()));
}

void HandleSetHiddenNotificationDetail(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  bool is_hidden = GetBool(args, "isHidden", false);
  WFClient::setHiddenNotificationDetail(is_hidden, OnGeneralVoidSuccess,
                                        OnGeneralError,
                                        reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleIsHiddenGroupMemberName(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string group_id = GetString(args, "groupId");
  result->Success(flutter::EncodableValue(
      WFClient::isHiddenGroupMemberName(group_id.c_str(), group_id.size())));
}

void HandleSetHiddenGroupMemberName(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string group_id = GetString(args, "groupId");
  bool is_hidden = GetBool(args, "isHidden", false);
  WFClient::setHiddenGroupMemberName(group_id.c_str(), group_id.size(),
                                     is_hidden, OnGeneralVoidSuccess,
                                     OnGeneralError,
                                     reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleGetMyGroups(const flutter::EncodableMap *args,
                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleGetCommonGroups(const flutter::EncodableMap *args,
                           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleIsUserEnableReceipt(const flutter::EncodableMap *args,
                               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleSetUserEnableReceipt(const flutter::EncodableMap *args,
                                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleGetFavUsers(const flutter::EncodableMap *args,
                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  size_t len = 0;
  const char *str = WFClient::getFavUsers(&len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result->Success(JsonToEncodable(json_str));
}

void HandleIsFavUser(const flutter::EncodableMap *args,
                     std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string user_id = GetString(args, "userId");
  result->Success(flutter::EncodableValue(
      WFClient::isFavUser(user_id.c_str(), user_id.size())));
}

void HandleSetFavUser(const flutter::EncodableMap *args,
                      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string user_id = GetString(args, "userId");
  bool fav = GetBool(args, "isFav", false);
  WFClient::setFavUser(user_id.c_str(), user_id.size(), fav,
                       OnGeneralVoidSuccess, OnGeneralError,
                       reinterpret_cast<void *>(request_id));
  result->Success();
}

void HandleJoinChatroom(const flutter::EncodableMap *args,
                        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string chatroom_id = GetString(args, "chatroomId");
  WFClient::joinChatroom(chatroom_id.c_str(), chatroom_id.size(),
                         OnGeneralVoidSuccess, OnGeneralError,
                         reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleQuitChatroom(const flutter::EncodableMap *args,
                        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string chatroom_id = GetString(args, "chatroomId");
  WFClient::quitChatroom(chatroom_id.c_str(), chatroom_id.size(),
                         OnGeneralVoidSuccess, OnGeneralError,
                         reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleGetChatroomInfo(const flutter::EncodableMap *args,
                           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string chatroom_id = GetString(args, "chatroomId");
  int64_t update_dt = GetInt(args, "updateDt", 0);
  WFClient::getChatroomInfo(chatroom_id.c_str(), chatroom_id.size(), update_dt,
                            OnChatroomInfoSuccess, OnGeneralError,
                            reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleGetChatroomMemberInfo(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string chatroom_id = GetString(args, "chatroomId");
  WFClient::getChatroomMemberInfo(chatroom_id.c_str(), chatroom_id.size(), 0,
                                  OnChatroomMemberInfoSuccess, OnGeneralError,
                                  reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleGetJoinedChatroomId(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleCreateChannel(const flutter::EncodableMap *args,
                         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string name = GetString(args, "name");
  std::string portrait = GetString(args, "portrait");
  std::string desc = GetString(args, "desc");
  std::string extra = GetString(args, "extra");
  WFClient::createChannel(name.c_str(), name.size(), portrait.c_str(),
                          portrait.size(), desc.c_str(), desc.size(),
                          extra.c_str(), extra.size(), OnCreateChannelSuccess,
                          OnGeneralError, reinterpret_cast<void *>(request_id),
                          0);
  result->Success();
}

void HandleGetChannelInfo(const flutter::EncodableMap *args,
                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string channel_id = GetString(args, "channelId");
  bool refresh = GetBool(args, "refresh", false);
  size_t len = 0;
  const char *str = WFClient::getChannelInfo(channel_id.c_str(),
                                             channel_id.size(), refresh, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result->Success(JsonToEncodable(json_str));
}

void HandleModifyChannelInfo(const flutter::EncodableMap *args,
                             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string channel_id = GetString(args, "channelId");
  int type = static_cast<int>(GetInt(args, "type", 0));
  std::string new_value = GetString(args, "newValue");
  WFClient::modifyChannelInfo(channel_id.c_str(), channel_id.size(), type,
                              new_value.c_str(), new_value.size(),
                              OnGeneralVoidSuccess, OnGeneralError,
                              reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleSearchChannel(const flutter::EncodableMap *args,
                         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string keyword = GetString(args, "keyword");
  WFClient::searchChannel(keyword.c_str(), keyword.size(),
                          OnSearchChannelSuccess, OnGeneralError,
                          reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleIsListenedChannel(const flutter::EncodableMap *args,
                             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string channel_id = GetString(args, "channelId");
  result->Success(flutter::EncodableValue(
      WFClient::isListenedChannel(channel_id.c_str(), channel_id.size())));
}

void HandleListenChannel(const flutter::EncodableMap *args,
                         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string channel_id = GetString(args, "channelId");
  bool listen = GetBool(args, "listen", false);
  WFClient::listenChannel(channel_id.c_str(), channel_id.size(), listen,
                          OnGeneralVoidSuccess, OnGeneralError,
                          reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleGetMyChannels(const flutter::EncodableMap *args,
                         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  size_t len = 0;
  const char *str = WFClient::getMyChannels(&len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result->Success(JsonToEncodable(json_str));
}

void HandleGetRemoteListenedChannels(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  size_t len = 0;
  const char *str = WFClient::getListenedChannels(&len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  flutter::EncodableValue value = JsonToEncodable(json_str);
  flutter::EncodableList channels;
  if (auto *list = std::get_if<flutter::EncodableList>(&value)) {
    channels = *list;
  }
  flutter::EncodableMap callback_args;
  callback_args[flutter::EncodableValue("requestId")] =
      flutter::EncodableValue(request_id);
  callback_args[flutter::EncodableValue("strings")] =
      flutter::EncodableValue(channels);
  InvokeDartMethod("onOperationStringListSuccess", callback_args);
  result->Success();
}

void HandleDestroyChannel(const flutter::EncodableMap *args,
                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string channel_id = GetString(args, "channelId");
  WFClient::destoryChannel(channel_id.c_str(), channel_id.size(),
                           OnGeneralVoidSuccess, OnGeneralError,
                           reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleGetOnlineInfos(const flutter::EncodableMap *args,
                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleKickoffPCClient(const flutter::EncodableMap *args,
                           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleIsMuteNotificationWhenPcOnline(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleSetDefaultSilentWhenPcOnline(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleMuteNotificationWhenPcOnline(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleGetUserOnlineState(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleGetMyCustomState(const flutter::EncodableMap *args,
                            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleSetMyCustomState(const flutter::EncodableMap *args,
                            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleWatchOnlineState(const flutter::EncodableMap *args,
                            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleUnwatchOnlineState(const flutter::EncodableMap *args,
                              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleIsEnableUserOnlineState(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleSendConferenceRequest(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleGetConversationFiles(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleGetMyFiles(const flutter::EncodableMap *args,
                      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleDeleteFileRecord(const flutter::EncodableMap *args,
                            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleSearchFiles(const flutter::EncodableMap *args,
                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleSearchMyFiles(const flutter::EncodableMap *args,
                         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleGetAuthCode(const flutter::EncodableMap *args,
                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleConfigApplication(const flutter::EncodableMap *args,
                             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleGetWavData(const flutter::EncodableMap *args,
                      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleBeginTransaction(const flutter::EncodableMap *args,
                            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success(flutter::EncodableValue(WFClient::beginTransaction()));
}

void HandleCommitTransaction(const flutter::EncodableMap *args,
                             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success(flutter::EncodableValue(WFClient::commitTransaction()));
}

void HandleRollbackTransaction(const flutter::EncodableMap *args,
                               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success(flutter::EncodableValue(WFClient::rollbackTransaction()));
}

void HandleIsCommercialServer(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleIsReceiptEnabled(const flutter::EncodableMap *args,
                            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleIsGroupReceiptEnabled(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}

void HandleIsGlobalDisableSyncDraft(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->NotImplemented();
}
'''

DISPATCH_CASES = r'''  } else if (method == "startLog") {
    HandleStartLog(args, std::move(result));
  } else if (method == "stopLog") {
    HandleStopLog(args, std::move(result));
  } else if (method == "setSendLogCommand") {
    HandleSetSendLogCommand(args, std::move(result));
  } else if (method == "getLogFilesPath") {
    HandleGetLogFilesPath(args, std::move(result));
  } else if (method == "setDeviceToken") {
    HandleSetDeviceToken(args, std::move(result));
  } else if (method == "setVoipDeviceToken") {
    HandleSetVoipDeviceToken(args, std::move(result));
  } else if (method == "getUserInfo") {
    HandleGetUserInfo(args, std::move(result));
  } else if (method == "getUserInfos") {
    HandleGetUserInfos(args, std::move(result));
  } else if (method == "searchUser") {
    HandleSearchUser(args, std::move(result));
  } else if (method == "getUserInfoAsync") {
    HandleGetUserInfoAsync(args, std::move(result));
  } else if (method == "isMyFriend") {
    HandleIsMyFriend(args, std::move(result));
  } else if (method == "getMyFriendList") {
    HandleGetMyFriendList(args, std::move(result));
  } else if (method == "searchFriends") {
    HandleSearchFriends(args, std::move(result));
  } else if (method == "getFriends") {
    HandleGetFriends(args, std::move(result));
  } else if (method == "searchGroups") {
    HandleSearchGroups(args, std::move(result));
  } else if (method == "getIncommingFriendRequest") {
    HandleGetIncommingFriendRequest(args, std::move(result));
  } else if (method == "getOutgoingFriendRequest") {
    HandleGetOutgoingFriendRequest(args, std::move(result));
  } else if (method == "getFriendRequest") {
    HandleGetFriendRequest(args, std::move(result));
  } else if (method == "loadFriendRequestFromRemote") {
    HandleLoadFriendRequestFromRemote(args, std::move(result));
  } else if (method == "getUnreadFriendRequestStatus") {
    HandleGetUnreadFriendRequestStatus(args, std::move(result));
  } else if (method == "clearUnreadFriendRequestStatus") {
    HandleClearUnreadFriendRequestStatus(args, std::move(result));
  } else if (method == "clearFriendRequest") {
    HandleClearFriendRequest(args, std::move(result));
  } else if (method == "deleteFriendRequest") {
    HandleDeleteFriendRequest(args, std::move(result));
  } else if (method == "deleteFriend") {
    HandleDeleteFriend(args, std::move(result));
  } else if (method == "getFriendAlias") {
    HandleGetFriendAlias(args, std::move(result));
  } else if (method == "setFriendAlias") {
    HandleSetFriendAlias(args, std::move(result));
  } else if (method == "getFriendExtra") {
    HandleGetFriendExtra(args, std::move(result));
  } else if (method == "sendFriendRequest") {
    HandleSendFriendRequest(args, std::move(result));
  } else if (method == "handleFriendRequest") {
    HandleHandleFriendRequest(args, std::move(result));
  } else if (method == "isBlackListed") {
    HandleIsBlackListed(args, std::move(result));
  } else if (method == "getBlackList") {
    HandleGetBlackList(args, std::move(result));
  } else if (method == "setBlackList") {
    HandleSetBlackList(args, std::move(result));
  } else if (method == "getGroupMembers") {
    HandleGetGroupMembers(args, std::move(result));
  } else if (method == "getGroupMembersByCount") {
    HandleGetGroupMembersByCount(args, std::move(result));
  } else if (method == "getGroupMembersByTypes") {
    HandleGetGroupMembersByTypes(args, std::move(result));
  } else if (method == "getGroupMembersAsync") {
    HandleGetGroupMembersAsync(args, std::move(result));
  } else if (method == "getGroupInfo") {
    HandleGetGroupInfo(args, std::move(result));
  } else if (method == "getGroupInfos") {
    HandleGetGroupInfos(args, std::move(result));
  } else if (method == "getGroupInfoAsync") {
    HandleGetGroupInfoAsync(args, std::move(result));
  } else if (method == "getGroupMember") {
    HandleGetGroupMember(args, std::move(result));
  } else if (method == "createGroup") {
    HandleCreateGroup(args, std::move(result));
  } else if (method == "addGroupMembers") {
    HandleAddGroupMembers(args, std::move(result));
  } else if (method == "kickoffGroupMembers") {
    HandleKickoffGroupMembers(args, std::move(result));
  } else if (method == "quitGroup") {
    HandleQuitGroup(args, std::move(result));
  } else if (method == "quitGroupEx") {
    HandleQuitGroupEx(args, std::move(result));
  } else if (method == "dismissGroup") {
    HandleDismissGroup(args, std::move(result));
  } else if (method == "modifyGroupInfo") {
    HandleModifyGroupInfo(args, std::move(result));
  } else if (method == "modifyGroupAlias") {
    HandleModifyGroupAlias(args, std::move(result));
  } else if (method == "modifyGroupMemberAlias") {
    HandleModifyGroupMemberAlias(args, std::move(result));
  } else if (method == "transferGroup") {
    HandleTransferGroup(args, std::move(result));
  } else if (method == "setGroupManager") {
    HandleSetGroupManager(args, std::move(result));
  } else if (method == "muteGroupMember") {
    HandleMuteGroupMember(args, std::move(result));
  } else if (method == "allowGroupMember") {
    HandleAllowGroupMember(args, std::move(result));
  } else if (method == "getGroupRemark") {
    HandleGetGroupRemark(args, std::move(result));
  } else if (method == "setGroupRemark") {
    HandleSetGroupRemark(args, std::move(result));
  } else if (method == "getFavGroups") {
    HandleGetFavGroups(args, std::move(result));
  } else if (method == "isFavGroup") {
    HandleIsFavGroup(args, std::move(result));
  } else if (method == "setFavGroup") {
    HandleSetFavGroup(args, std::move(result));
  } else if (method == "getUserSetting") {
    HandleGetUserSetting(args, std::move(result));
  } else if (method == "getUserSettings") {
    HandleGetUserSettings(args, std::move(result));
  } else if (method == "setUserSetting") {
    HandleSetUserSetting(args, std::move(result));
  } else if (method == "modifyMyInfo") {
    HandleModifyMyInfo(args, std::move(result));
  } else if (method == "isGlobalSilent") {
    HandleIsGlobalSilent(args, std::move(result));
  } else if (method == "setGlobalSilent") {
    HandleSetGlobalSilent(args, std::move(result));
  } else if (method == "isVoipNotificationSilent") {
    HandleIsVoipNotificationSilent(args, std::move(result));
  } else if (method == "setVoipNotificationSilent") {
    HandleSetVoipNotificationSilent(args, std::move(result));
  } else if (method == "isEnableSyncDraft") {
    HandleIsEnableSyncDraft(args, std::move(result));
  } else if (method == "setEnableSyncDraft") {
    HandleSetEnableSyncDraft(args, std::move(result));
  } else if (method == "getNoDisturbingTimes") {
    HandleGetNoDisturbingTimes(args, std::move(result));
  } else if (method == "setNoDisturbingTimes") {
    HandleSetNoDisturbingTimes(args, std::move(result));
  } else if (method == "clearNoDisturbingTimes") {
    HandleClearNoDisturbingTimes(args, std::move(result));
  } else if (method == "isNoDisturbing") {
    HandleIsNoDisturbing(args, std::move(result));
  } else if (method == "isHiddenNotificationDetail") {
    HandleIsHiddenNotificationDetail(args, std::move(result));
  } else if (method == "setHiddenNotificationDetail") {
    HandleSetHiddenNotificationDetail(args, std::move(result));
  } else if (method == "isHiddenGroupMemberName") {
    HandleIsHiddenGroupMemberName(args, std::move(result));
  } else if (method == "setHiddenGroupMemberName") {
    HandleSetHiddenGroupMemberName(args, std::move(result));
  } else if (method == "getMyGroups") {
    HandleGetMyGroups(args, std::move(result));
  } else if (method == "getCommonGroups") {
    HandleGetCommonGroups(args, std::move(result));
  } else if (method == "isUserEnableReceipt") {
    HandleIsUserEnableReceipt(args, std::move(result));
  } else if (method == "setUserEnableReceipt") {
    HandleSetUserEnableReceipt(args, std::move(result));
  } else if (method == "getFavUsers") {
    HandleGetFavUsers(args, std::move(result));
  } else if (method == "isFavUser") {
    HandleIsFavUser(args, std::move(result));
  } else if (method == "setFavUser") {
    HandleSetFavUser(args, std::move(result));
  } else if (method == "joinChatroom") {
    HandleJoinChatroom(args, std::move(result));
  } else if (method == "quitChatroom") {
    HandleQuitChatroom(args, std::move(result));
  } else if (method == "getChatroomInfo") {
    HandleGetChatroomInfo(args, std::move(result));
  } else if (method == "getChatroomMemberInfo") {
    HandleGetChatroomMemberInfo(args, std::move(result));
  } else if (method == "getJoinedChatroomId") {
    HandleGetJoinedChatroomId(args, std::move(result));
  } else if (method == "createChannel") {
    HandleCreateChannel(args, std::move(result));
  } else if (method == "getChannelInfo") {
    HandleGetChannelInfo(args, std::move(result));
  } else if (method == "modifyChannelInfo") {
    HandleModifyChannelInfo(args, std::move(result));
  } else if (method == "searchChannel") {
    HandleSearchChannel(args, std::move(result));
  } else if (method == "isListenedChannel") {
    HandleIsListenedChannel(args, std::move(result));
  } else if (method == "listenChannel") {
    HandleListenChannel(args, std::move(result));
  } else if (method == "getMyChannels") {
    HandleGetMyChannels(args, std::move(result));
  } else if (method == "getRemoteListenedChannels") {
    HandleGetRemoteListenedChannels(args, std::move(result));
  } else if (method == "destroyChannel") {
    HandleDestroyChannel(args, std::move(result));
  } else if (method == "getOnlineInfos") {
    HandleGetOnlineInfos(args, std::move(result));
  } else if (method == "kickoffPCClient") {
    HandleKickoffPCClient(args, std::move(result));
  } else if (method == "isMuteNotificationWhenPcOnline") {
    HandleIsMuteNotificationWhenPcOnline(args, std::move(result));
  } else if (method == "setDefaultSilentWhenPcOnline") {
    HandleSetDefaultSilentWhenPcOnline(args, std::move(result));
  } else if (method == "muteNotificationWhenPcOnline") {
    HandleMuteNotificationWhenPcOnline(args, std::move(result));
  } else if (method == "getUserOnlineState") {
    HandleGetUserOnlineState(args, std::move(result));
  } else if (method == "getMyCustomState") {
    HandleGetMyCustomState(args, std::move(result));
  } else if (method == "setMyCustomState") {
    HandleSetMyCustomState(args, std::move(result));
  } else if (method == "watchOnlineState") {
    HandleWatchOnlineState(args, std::move(result));
  } else if (method == "unwatchOnlineState") {
    HandleUnwatchOnlineState(args, std::move(result));
  } else if (method == "isEnableUserOnlineState") {
    HandleIsEnableUserOnlineState(args, std::move(result));
  } else if (method == "sendConferenceRequest") {
    HandleSendConferenceRequest(args, std::move(result));
  } else if (method == "getConversationFiles") {
    HandleGetConversationFiles(args, std::move(result));
  } else if (method == "getMyFiles") {
    HandleGetMyFiles(args, std::move(result));
  } else if (method == "deleteFileRecord") {
    HandleDeleteFileRecord(args, std::move(result));
  } else if (method == "searchFiles") {
    HandleSearchFiles(args, std::move(result));
  } else if (method == "searchMyFiles") {
    HandleSearchMyFiles(args, std::move(result));
  } else if (method == "getAuthCode") {
    HandleGetAuthCode(args, std::move(result));
  } else if (method == "configApplication") {
    HandleConfigApplication(args, std::move(result));
  } else if (method == "getWavData") {
    HandleGetWavData(args, std::move(result));
  } else if (method == "beginTransaction") {
    HandleBeginTransaction(args, std::move(result));
  } else if (method == "commitTransaction") {
    HandleCommitTransaction(args, std::move(result));
  } else if (method == "rollbackTransaction") {
    HandleRollbackTransaction(args, std::move(result));
  } else if (method == "isCommercialServer") {
    HandleIsCommercialServer(args, std::move(result));
  } else if (method == "isReceiptEnabled") {
    HandleIsReceiptEnabled(args, std::move(result));
  } else if (method == "isGroupReceiptEnabled") {
    HandleIsGroupReceiptEnabled(args, std::move(result));
  } else if (method == "isGlobalDisableSyncDraft") {
    HandleIsGlobalDisableSyncDraft(args, std::move(result));
'''

GET_MESSAGES_BY_STATUS_BODY = r'''void HandleGetMessagesByStatus(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  Conversation conv(args);
  int64_t from_index = GetInt(args, "fromIndex", 0);
  int count = static_cast<int>(GetInt(args, "count", 0));
  std::vector<int> message_statuses = GetIntList(args, "messageStatus");
  std::string with_user = GetString(args, "withUser");
  std::vector<int> types = {conv.conversation_type};
  std::vector<int> lines = {conv.line};

  size_t len = 0;
  const char *str = WFClient::getMessagesByMessageStatus(
      types.data(), static_cast<int>(types.size()), lines.data(),
      static_cast<int>(lines.size()), message_statuses.data(),
      static_cast<int>(message_statuses.size()), from_index, count > 0,
      std::abs(count), with_user.c_str(), with_user.size(), &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result->Success(JsonToEncodable(json_str));
}'''

GET_CONVERSATIONS_MESSAGE_BY_STATUS_BODY = r'''void HandleGetConversationsMessageByStatus(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::vector<int> types = GetIntList(args, "types");
  std::vector<int> lines = GetIntList(args, "lines");
  int64_t from_index = GetInt(args, "fromIndex", 0);
  int count = static_cast<int>(GetInt(args, "count", 0));
  std::vector<int> message_statuses = GetIntList(args, "messageStatus");
  std::string with_user = GetString(args, "withUser");

  size_t len = 0;
  const char *str = WFClient::getMessagesByMessageStatus(
      types.data(), static_cast<int>(types.size()), lines.data(),
      static_cast<int>(lines.size()), message_statuses.data(),
      static_cast<int>(message_statuses.size()), from_index, count > 0,
      std::abs(count), with_user.c_str(), with_user.size(), &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result->Success(JsonToEncodable(json_str));
}'''


def replace_function_body(content, func_name, new_body):
    pattern = (
        r"void\s+" + re.escape(func_name) +
        r"\(\s*const\s+flutter::EncodableMap\s*\*args,\s*"
        r"std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>\s+result\)\s*\{"
        r"[^}]*result->NotImplemented\(\);[^}]*\}"
    )
    if not re.search(pattern, content, flags=re.DOTALL):
        raise RuntimeError(f"Could not find stub body for {func_name}")
    return re.sub(pattern, new_body, content, flags=re.DOTALL, count=1)


def insert_handlers(content, is_macos):
    if is_macos:
        marker = "}  // namespace\n\n@implementation ImclientPlugin"
        if marker not in content:
            raise RuntimeError("macOS handler insertion marker not found")
        return content.replace(marker, HANDLERS_BLOCK + "\n" + marker, 1)
    else:
        marker = "void ImclientPlugin::RegisterWithRegistrar("
        idx = content.find(marker)
        if idx < 0:
            raise RuntimeError("Windows/Linux handler insertion marker not found")
        # Insert a blank line before the handlers
        return content[:idx] + HANDLERS_BLOCK + "\n" + content[idx:]


def insert_dispatch_cases(content):
    marker = "  } else {\n    result->NotImplemented();\n  }\n}"
    if marker not in content:
        raise RuntimeError("dispatch insertion marker not found")
    # Replace the final else block with the new cases plus the final else block.
    new_block = DISPATCH_CASES + "\n  } else {\n    result->NotImplemented();\n  }\n}"
    return content.replace(marker, new_block, 1)


def process_file(path, is_macos):
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    content = replace_function_body(content, "HandleGetMessagesByStatus",
                                    GET_MESSAGES_BY_STATUS_BODY)
    content = replace_function_body(
        content, "HandleGetConversationsMessageByStatus",
        GET_CONVERSATIONS_MESSAGE_BY_STATUS_BODY)
    content = insert_handlers(content, is_macos)
    content = insert_dispatch_cases(content)

    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"Updated {path}")


def main():
    base = "/Users/rain/Workspace/wfc_flutter_plugins/imclient"
    process_file(os.path.join(base, "windows", "imclient_plugin.cpp"), False)
    process_file(os.path.join(base, "linux", "imclient_plugin.cpp"), False)
    process_file(os.path.join(base, "macos", "Classes", "ImclientPlugin.mm"), True)


if __name__ == "__main__":
    main()
