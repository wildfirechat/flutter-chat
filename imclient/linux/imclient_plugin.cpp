#include "imclient_plugin.h"

#include "wf_client_helper.h"
#include "wf_json_helper.h"

#include <WFClient.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_linux.h>
#include <flutter/standard_method_codec.h>

#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <map>
#include <memory>
#include <mutex>
#include <sstream>
#include <string>
#include <vector>

namespace imclient {

namespace {

// Flutter method channel used to send events back to Dart.
flutter::MethodChannel<flutter::EncodableValue> *g_channel = nullptr;
std::mutex g_channel_mutex;

int64_t NextRequestId() {
  static int64_t request_id = 0;
  return ++request_id;
}

// Store pending Dart callbacks keyed by request id.
std::map<int64_t, flutter::MethodChannel<flutter::EncodableValue> *> g_callbacks;
std::mutex g_callbacks_mutex;

flutter::MethodChannel<flutter::EncodableValue> *GetChannel() {
  std::lock_guard<std::mutex> lock(g_channel_mutex);
  return g_channel;
}

void SetChannel(flutter::MethodChannel<flutter::EncodableValue> *channel) {
  std::lock_guard<std::mutex> lock(g_channel_mutex);
  g_channel = channel;
}

void InvokeDartMethod(const std::string &method,
                      std::unique_ptr<flutter::EncodableValue> args) {
  auto *channel = GetChannel();
  if (channel) {
    channel->InvokeMethod(method, std::move(args));
  }
}

void InvokeDartMethod(const std::string &method,
                      const flutter::EncodableValue &args) {
  InvokeDartMethod(method,
                   std::make_unique<flutter::EncodableValue>(args));
}

std::string ConvertDllStringAndRelease(const char *str, size_t len) {
  if (!str) return "";
  std::string result(str, len);
  WFClient::releaseDllString(str);
  return result;
}

std::string ConvertDllString(const char *str, size_t len) {
  if (!str) return "";
  return std::string(str, len);
}

// ---------------- C SDK global callbacks ----------------

#ifdef WIN32
#define WFCAPI __stdcall
#else
#define WFCAPI
#endif

static void WFCAPI OnConnectionStatusChanged(int connection_status) {
  InvokeDartMethod("onConnectionStatusChanged",
                   flutter::EncodableValue(connection_status));
}

static void WFCAPI OnReceiveMessage(const char *cmessages, size_t messages_len,
                                    bool more_msg) {
  std::string json_str(cmessages, messages_len);
  flutter::EncodableValue value = JsonToEncodable(json_str);
  flutter::EncodableList messages;
  if (auto *list = std::get_if<flutter::EncodableList>(&value)) {
    messages = *list;
  }
  flutter::EncodableMap args;
  args[flutter::EncodableValue("hasMore")] = flutter::EncodableValue(more_msg);
  args[flutter::EncodableValue("messages")] =
      flutter::EncodableValue(messages);
  InvokeDartMethod("onReceiveMessage", args);
}

static void WFCAPI OnRecallMessage(const char *coperator_id,
                                   size_t operator_id_len,
                                   int64_t message_uid) {
  flutter::EncodableMap args;
  args[flutter::EncodableValue("operator")] =
      flutter::EncodableValue(std::string(coperator_id, operator_id_len));
  args[flutter::EncodableValue("messageUid")] =
      flutter::EncodableValue(static_cast<int64_t>(message_uid));
  InvokeDartMethod("onRecallMessage", args);
}

static void WFCAPI OnDeleteMessage(int64_t message_uid) {
  flutter::EncodableMap args;
  args[flutter::EncodableValue("messageUid")] =
      flutter::EncodableValue(static_cast<int64_t>(message_uid));
  InvokeDartMethod("onDeleteMessage", args);
}

static void WFCAPI OnMessageDelivered(const char *cstr, size_t str_len) {
  // PC SDK has no delivery callback distribution; keep empty for now.
}

static void WFCAPI OnMessageReaded(const char *cstr, size_t str_len) {
  // PC SDK has no read callback distribution; keep empty for now.
}

static void WFCAPI OnUserInfoUpdated(const char *cuser_infos,
                                     size_t user_infos_len) {
  std::string json_str(cuser_infos, user_infos_len);
  flutter::EncodableValue value = JsonToEncodable(json_str);
  flutter::EncodableList users;
  if (auto *list = std::get_if<flutter::EncodableList>(&value)) {
    users = *list;
  }
  flutter::EncodableMap args;
  args[flutter::EncodableValue("users")] = flutter::EncodableValue(users);
  InvokeDartMethod("onUserInfoUpdated", args);
}

static void WFCAPI OnGroupInfoUpdated(const char *cgroup_infos,
                                      size_t group_infos_len) {
  std::string json_str(cgroup_infos, group_infos_len);
  flutter::EncodableValue value = JsonToEncodable(json_str);
  flutter::EncodableList groups;
  if (auto *list = std::get_if<flutter::EncodableList>(&value)) {
    groups = *list;
  }
  flutter::EncodableMap args;
  args[flutter::EncodableValue("groups")] = flutter::EncodableValue(groups);
  InvokeDartMethod("onGroupInfoUpdated", args);
}

static void WFCAPI OnGroupMemberUpdated(const char *cgroup_id,
                                        size_t group_id_len) {
  flutter::EncodableMap args;
  args[flutter::EncodableValue("groupId")] =
      flutter::EncodableValue(std::string(cgroup_id, group_id_len));
  // PC SDK only returns groupId; Dart side may fetch members itself.
  args[flutter::EncodableValue("members")] = flutter::EncodableList();
  InvokeDartMethod("onGroupMemberUpdated", args);
}

static void WFCAPI OnFriendListUpdated(const char *cfriend_list,
                                       size_t friend_list_len) {
  std::string json_str(cfriend_list, friend_list_len);
  flutter::EncodableValue value = JsonToEncodable(json_str);
  flutter::EncodableList friends;
  if (auto *list = std::get_if<flutter::EncodableList>(&value)) {
    friends = *list;
  }
  flutter::EncodableMap args;
  args[flutter::EncodableValue("friends")] = flutter::EncodableValue(friends);
  InvokeDartMethod("onFriendListUpdated", args);
}

static void WFCAPI OnFriendRequestUpdated(const char *crequests,
                                          size_t requests_len) {
  std::string json_str(crequests, requests_len);
  flutter::EncodableValue value = JsonToEncodable(json_str);
  flutter::EncodableList requests;
  if (auto *list = std::get_if<flutter::EncodableList>(&value)) {
    requests = *list;
  }
  flutter::EncodableMap args;
  args[flutter::EncodableValue("requests")] =
      flutter::EncodableValue(requests);
  InvokeDartMethod("onFriendRequestUpdated", args);
}

static void WFCAPI OnSettingUpdated() {
  InvokeDartMethod("onSettingUpdated", flutter::EncodableValue());
}

static void WFCAPI OnChannelInfoUpdated(const char *cchannel_info,
                                        size_t channel_info_len) {
  std::string json_str(cchannel_info, channel_info_len);
  flutter::EncodableValue value = JsonToEncodable(json_str);
  flutter::EncodableList channels;
  if (auto *list = std::get_if<flutter::EncodableList>(&value)) {
    channels = *list;
  }
  flutter::EncodableMap args;
  args[flutter::EncodableValue("channels")] =
      flutter::EncodableValue(channels);
  InvokeDartMethod("onChannelInfoUpdated", args);
}

// ---------------- Generic async callbacks ----------------

static void WFCAPI OnGeneralVoidSuccess(void *p_obj, int data_type) {
  int64_t request_id = reinterpret_cast<int64_t>(p_obj);
  flutter::EncodableMap args;
  args[flutter::EncodableValue("requestId")] =
      flutter::EncodableValue(request_id);
  InvokeDartMethod("onOperationVoidSuccess", args);
}

static void WFCAPI OnGeneralError(void *p_obj, int data_type,
                                  int error_code) {
  int64_t request_id = reinterpret_cast<int64_t>(p_obj);
  flutter::EncodableMap args;
  args[flutter::EncodableValue("requestId")] =
      flutter::EncodableValue(request_id);
  args[flutter::EncodableValue("errorCode")] =
      flutter::EncodableValue(error_code);
  InvokeDartMethod("onOperationFailure", args);
}

static void WFCAPI OnGeneralStringSuccess(void *p_obj, int data_type,
                                          const char *cval, size_t val_len) {
  int64_t request_id = reinterpret_cast<int64_t>(p_obj);
  std::string json_str(cval, val_len);
  flutter::EncodableValue value = JsonToEncodable(json_str);
  flutter::EncodableMap args;
  args[flutter::EncodableValue("requestId")] =
      flutter::EncodableValue(request_id);
  args[flutter::EncodableValue("data")] = value;
  InvokeDartMethod("onOperationStringSuccess", args);
}

static void WFCAPI OnGetUploadUrlSuccess(void *p_obj, int data_type,
                                         const char *cval, size_t val_len) {
  int64_t request_id = reinterpret_cast<int64_t>(p_obj);
  std::string json_str(cval, val_len);
  flutter::EncodableValue value = JsonToEncodable(json_str);
  flutter::EncodableMap dict;
  if (auto *map = std::get_if<flutter::EncodableMap>(&value)) {
    dict = *map;
  }

  auto get_string = [&dict](const char *key) -> std::string {
    auto it = dict.find(flutter::EncodableValue(key));
    if (it != dict.end()) {
      if (auto *s = std::get_if<std::string>(&it->second)) return *s;
    }
    return "";
  };
  auto get_int = [&dict](const char *key) -> int64_t {
    auto it = dict.find(flutter::EncodableValue(key));
    if (it != dict.end()) {
      if (auto *i = std::get_if<int32_t>(&it->second)) return *i;
      if (auto *i = std::get_if<int64_t>(&it->second)) return *i;
    }
    return 0;
  };

  flutter::EncodableMap args;
  args[flutter::EncodableValue("requestId")] =
      flutter::EncodableValue(request_id);
  args[flutter::EncodableValue("uploadUrl")] =
      flutter::EncodableValue(get_string("uploadUrl"));
  args[flutter::EncodableValue("downloadUrl")] =
      flutter::EncodableValue(get_string("downloadUrl"));
  args[flutter::EncodableValue("backupUploadUrl")] =
      flutter::EncodableValue(get_string("backupUploadUrl"));
  args[flutter::EncodableValue("type")] =
      flutter::EncodableValue(static_cast<int32_t>(get_int("type")));
  InvokeDartMethod("onGetUploadUrl", args);
}

static void WFCAPI OnWatchOnlineStateSuccess(void *p_obj, int data_type,
                                             const char *cval, size_t val_len) {
  int64_t request_id = reinterpret_cast<int64_t>(p_obj);
  std::string json_str(cval, val_len);
  flutter::EncodableValue value = JsonToEncodable(json_str);
  flutter::EncodableList states;
  if (auto *list = std::get_if<flutter::EncodableList>(&value)) {
    states = *list;
  }
  flutter::EncodableMap args;
  args[flutter::EncodableValue("requestId")] =
      flutter::EncodableValue(request_id);
  args[flutter::EncodableValue("states")] =
      flutter::EncodableValue(states);
  InvokeDartMethod("onWatchOnlineStateSuccess", args);
}

static void WFCAPI OnSendMessageSuccess(void *p_obj, int data_type,
                                        long message_id, int64_t message_uid,
                                        int64_t timestamp) {
  int64_t request_id = reinterpret_cast<int64_t>(p_obj);
  flutter::EncodableMap args;
  args[flutter::EncodableValue("requestId")] =
      flutter::EncodableValue(request_id);
  args[flutter::EncodableValue("messageId")] =
      flutter::EncodableValue(static_cast<int64_t>(message_id));
  args[flutter::EncodableValue("messageUid")] =
      flutter::EncodableValue(static_cast<int64_t>(message_uid));
  args[flutter::EncodableValue("timestamp")] =
      flutter::EncodableValue(static_cast<int64_t>(timestamp));
  InvokeDartMethod("onSendMessageSuccess", args);
}

static void WFCAPI OnSendMessagePrepared(void *p_obj, int data_type,
                                         long message_id, int64_t save_time) {
  // PC SDK has no prepared distribution; ignore for now.
}

static void WFCAPI OnSendMessageProgress(void *p_obj, int data_type,
                                         long message_id, int uploaded,
                                         int total) {
  int64_t request_id = reinterpret_cast<int64_t>(p_obj);
  flutter::EncodableMap args;
  args[flutter::EncodableValue("requestId")] =
      flutter::EncodableValue(request_id);
  args[flutter::EncodableValue("messageId")] =
      flutter::EncodableValue(static_cast<int64_t>(message_id));
  args[flutter::EncodableValue("uploaded")] =
      flutter::EncodableValue(uploaded);
  args[flutter::EncodableValue("total")] = flutter::EncodableValue(total);
  InvokeDartMethod("onSendMediaMessageProgress", args);
}

static void WFCAPI OnSendMessageMediaUploaded(void *p_obj, int data_type,
                                              long message_id,
                                              const char *cremote_url,
                                              size_t remote_url_len) {
  int64_t request_id = reinterpret_cast<int64_t>(p_obj);
  flutter::EncodableMap args;
  args[flutter::EncodableValue("requestId")] =
      flutter::EncodableValue(request_id);
  args[flutter::EncodableValue("messageId")] =
      flutter::EncodableValue(static_cast<int64_t>(message_id));
  args[flutter::EncodableValue("remoteUrl")] =
      flutter::EncodableValue(std::string(cremote_url, remote_url_len));
  InvokeDartMethod("onSendMediaMessageUploaded", args);
}

static void WFCAPI OnSendMessageError(void *p_obj, int data_type,
                                      long message_id, int error_code) {
  int64_t request_id = reinterpret_cast<int64_t>(p_obj);
  flutter::EncodableMap args;
  args[flutter::EncodableValue("requestId")] =
      flutter::EncodableValue(request_id);
  args[flutter::EncodableValue("messageId")] =
      flutter::EncodableValue(static_cast<int64_t>(message_id));
  args[flutter::EncodableValue("errorCode")] =
      flutter::EncodableValue(error_code);
  InvokeDartMethod("onSendMessageFailure", args);
}

// ---------------- Method handlers ----------------

void HandleInitProto(const flutter::EncodableMap *args,
                     std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // PC requires explicit paths and app info before connect.
  std::string app_name = GetString(args, "appName", "wfc_pc");
  std::string app_data_path = GetString(args, "appDataPath", "");
  std::string package_name = GetString(args, "packageName", app_name);
  std::string db_path = GetString(args, "dbPath", "");

  WFClient::setAppName(app_name.c_str(), app_name.size());
  if (!app_data_path.empty()) {
    WFClient::setAppDataPath(app_data_path.c_str(), app_data_path.size());
  }
  WFClient::setPackageName(package_name.c_str(), package_name.size());
  if (!db_path.empty()) {
    WFClient::setDBPath(db_path.c_str(), db_path.size());
  }

  // Register global listeners once.
  WFClient::setConnectionStatusListener(OnConnectionStatusChanged);
  WFClient::setReceiveMessageListener(
      OnReceiveMessage, OnRecallMessage, OnDeleteMessage, OnMessageDelivered,
      OnMessageReaded);
  WFClient::setUserInfoUpdateListener(OnUserInfoUpdated);
  WFClient::setGroupInfoUpdateListener(OnGroupInfoUpdated);
  WFClient::setGroupMemberUpdateListener(OnGroupMemberUpdated);
  WFClient::setFriendUpdateListener(OnFriendListUpdated);
  WFClient::setFriendRequestListener(OnFriendRequestUpdated);
  WFClient::setSettingUpdateListener(OnSettingUpdated);
  WFClient::setChannelInfoUpdateListener(OnChannelInfoUpdated);

  result->Success();
}

void HandleGetClientId(const flutter::EncodableMap *args,
                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  size_t len = 0;
  const char *str = WFClient::getClientId(&len);
  std::string client_id = ConvertDllStringAndRelease(str, len);
  result->Success(flutter::EncodableValue(client_id));
}

void HandleGetProtoRevision(const flutter::EncodableMap *args,
                            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  size_t len = 0;
  const char *str = WFClient::getProtoRevision(&len);
  std::string revision = ConvertDllStringAndRelease(str, len);
  result->Success(flutter::EncodableValue(revision));
}

void HandleConnect(const flutter::EncodableMap *args,
                   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string user_id = GetString(args, "userId");
  std::string token = GetString(args, "token");

  int64_t connect_time = WFClient::connect2Server(
      user_id.c_str(), user_id.size(), token.c_str(), token.size());
  result->Success(flutter::EncodableValue(connect_time));
}

void HandleDisconnect(const flutter::EncodableMap *args,
                      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  bool clear_session = GetBool(args, "clearSession", false);
  WFClient::disconnect(clear_session ? 1 : 0);
  result->Success();
}

void HandleConnectionStatus(const flutter::EncodableMap *args,
                            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int status = WFClient::getConnectionStatus();
  result->Success(flutter::EncodableValue(status));
}

void HandleIsLogined(const flutter::EncodableMap *args,
                     std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  bool logined = WFClient::isLogin();
  result->Success(flutter::EncodableValue(logined));
}

void HandleCurrentUserId(const flutter::EncodableMap *args,
                         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  size_t len = 0;
  const char *str = WFClient::getCurrentUserId(&len);
  std::string user_id = ConvertDllStringAndRelease(str, len);
  result->Success(flutter::EncodableValue(user_id));
}

void HandleServerDeltaTime(const flutter::EncodableMap *args,
                           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t delta = WFClient::getServerDeltaTime();
  result->Success(flutter::EncodableValue(delta));
}

void HandleSetBackupAddress(const flutter::EncodableMap *args,
                            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string host = GetString(args, "host");
  int port = static_cast<int>(GetInt(args, "port", 80));
  WFClient::setBackupAddress(host.c_str(), host.size(), port);
  result->Success();
}

void HandleUseSM4(const flutter::EncodableMap *args,
                  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  WFClient::useSM4();
  result->Success();
}

void HandleSetLiteMode(const flutter::EncodableMap *args,
                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  bool lite_mode = GetBool(args, "liteMode", false);
  WFClient::setLiteMode(lite_mode);
  result->Success();
}

void HandleSetBackupAddressStrategy(const flutter::EncodableMap *args,
                                    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int strategy = static_cast<int>(GetInt(args, "strategy", 0));
  WFClient::setBackupAddressStrategy(strategy);
  result->Success();
}

void HandleSetProtoUserAgent(const flutter::EncodableMap *args,
                             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string agent = GetString(args, "agent");
  WFClient::setUserAgent(agent.c_str(), agent.size());
  result->Success();
}

void HandleAddHttpHeader(const flutter::EncodableMap *args,
                         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string header = GetString(args, "header");
  std::string value = GetString(args, "value");
  WFClient::addHttpHeader(header.c_str(), header.size(), value.c_str(),
                          value.size());
  result->Success();
}

void HandleSetProxyInfo(const flutter::EncodableMap *args,
                        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string host = GetString(args, "host");
  std::string ip = GetString(args, "ip");
  int port = static_cast<int>(GetInt(args, "port", 0));
  std::string user_name = GetString(args, "userName");
  std::string password = GetString(args, "password");
  WFClient::setProxyInfo(host.c_str(), host.size(), ip.c_str(), ip.size(),
                         port, user_name.c_str(), user_name.size(),
                         password.c_str(), password.size());
  result->Success();
}

void HandleRegisterMessage(const flutter::EncodableMap *args,
                           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int type = static_cast<int>(GetInt(args, "type", 0));
  int flag = static_cast<int>(GetInt(args, "flag", 0));
  WFClient::registerMessageFlag(type, flag);
  result->Success();
}

void HandleGetConversationInfos(const flutter::EncodableMap *args,
                                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::vector<int> types = GetIntList(args, "types");
  std::vector<int> lines = GetIntList(args, "lines");

  size_t len = 0;
  const char *str = WFClient::getConversationInfos(
      types.data(), static_cast<int>(types.size()), lines.data(),
      static_cast<int>(lines.size()), &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result->Success(JsonToEncodable(json_str));
}

void HandleGetConversationInfo(const flutter::EncodableMap *args,
                               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  Conversation conv(args);
  size_t len = 0;
  const char *str = WFClient::getConversationInfo(
      conv.conversation_type, conv.target.c_str(), conv.target.size(),
      conv.line, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result->Success(JsonToEncodable(json_str));
}

void HandleSearchConversation(const flutter::EncodableMap *args,
                              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string keyword = GetString(args, "keyword");
  std::vector<int> types = GetIntList(args, "types");
  std::vector<int> lines = GetIntList(args, "lines");

  size_t len = 0;
  const char *str = WFClient::searchConversation(
      types.data(), static_cast<int>(types.size()), lines.data(),
      static_cast<int>(lines.size()), keyword.c_str(), keyword.size(), &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result->Success(JsonToEncodable(json_str));
}

void HandleRemoveConversation(const flutter::EncodableMap *args,
                              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  Conversation conv(args);
  bool clear_message = GetBool(args, "clearMessage", false);
  WFClient::removeConversation(conv.conversation_type, conv.target.c_str(),
                               conv.target.size(), conv.line, clear_message);
  result->Success();
}

void HandleSetConversationTop(const flutter::EncodableMap *args,
                              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  Conversation conv(args);
  int is_top = static_cast<int>(GetInt(args, "isTop", 0));
  WFClient::setConversationTop(
      conv.conversation_type, conv.target.c_str(), conv.target.size(),
      conv.line, is_top, OnGeneralVoidSuccess, OnGeneralError,
      reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleSetConversationSilent(const flutter::EncodableMap *args,
                                 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  Conversation conv(args);
  bool is_silent = GetBool(args, "isSilent", false);
  WFClient::setConversationSlient(
      conv.conversation_type, conv.target.c_str(), conv.target.size(),
      conv.line, is_silent, OnGeneralVoidSuccess, OnGeneralError,
      reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleSetConversationDraft(const flutter::EncodableMap *args,
                                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  Conversation conv(args);
  std::string draft = GetString(args, "draft");
  WFClient::setConversationDraft(conv.conversation_type, conv.target.c_str(),
                                 conv.target.size(), conv.line,
                                 draft.c_str(), draft.size());
  result->Success();
}

void HandleSetConversationTimestamp(const flutter::EncodableMap *args,
                                    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  Conversation conv(args);
  int64_t timestamp = GetInt(args, "timestamp", 0);
  WFClient::setConversationTimestamp(conv.conversation_type,
                                     conv.target.c_str(), conv.target.size(),
                                     conv.line, timestamp);
  result->Success();
}

void HandleGetFirstUnreadMessageId(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  Conversation conv(args);
  long message_id = WFClient::getConversationFirstUnreadMessageId(
      conv.conversation_type, conv.target.c_str(), conv.target.size(),
      conv.line);
  result->Success(flutter::EncodableValue(static_cast<int64_t>(message_id)));
}

void HandleGetConversationUnreadCount(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  Conversation conv(args);
  size_t len = 0;
  const char *str = WFClient::getConversationUnreadCount(
      conv.conversation_type, conv.target.c_str(), conv.target.size(),
      conv.line, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result->Success(JsonToEncodable(json_str));
}

void HandleGetConversationsUnreadCount(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::vector<int> types = GetIntList(args, "types");
  std::vector<int> lines = GetIntList(args, "lines");

  size_t len = 0;
  const char *str = WFClient::getUnreadCount(
      types.data(), static_cast<int>(types.size()), lines.data(),
      static_cast<int>(lines.size()), &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result->Success(JsonToEncodable(json_str));
}

void HandleClearConversationUnreadStatus(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  Conversation conv(args);
  bool ret = WFClient::clearUnreadStatus(
      conv.conversation_type, conv.target.c_str(), conv.target.size(),
      conv.line);
  result->Success(flutter::EncodableValue(ret));
}

void HandleClearConversationsUnreadStatus(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::vector<int> types = GetIntList(args, "types");
  std::vector<int> lines = GetIntList(args, "lines");
  bool ret = WFClient::clearUnreadStatusEx(
      types.data(), static_cast<int>(types.size()), lines.data(),
      static_cast<int>(lines.size()));
  result->Success(flutter::EncodableValue(ret));
}

void HandleClearAllUnreadStatus(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  bool ret = WFClient::clearAllUnreadStatus();
  result->Success(flutter::EncodableValue(ret));
}

void HandleClearMessageUnreadStatus(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int message_id = static_cast<int>(GetInt(args, "messageId", 0));
  bool ret = WFClient::clearMessageUnreadStatus(message_id);
  result->Success(flutter::EncodableValue(ret));
}

void HandleClearMessageUnreadStatusBefore(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  Conversation conv(args);
  int message_id = static_cast<int>(GetInt(args, "messageId", 0));
  bool ret = WFClient::clearMessageUnreadStatusBefore(
      conv.conversation_type, conv.target.c_str(), conv.target.size(),
      conv.line, message_id);
  result->Success(flutter::EncodableValue(ret));
}

void HandleMarkAsUnRead(const flutter::EncodableMap *args,
                        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  Conversation conv(args);
  bool sync = GetBool(args, "sync", false);
  int64_t message_uid = WFClient::setLastReceivedMessageUnRead(
      conv.conversation_type, conv.target.c_str(), conv.target.size(),
      conv.line, 0, 0);
  if (sync && message_uid > 0) {
    // Need to send MarkUnreadMessageContent; skip for now.
  }
  result->Success(flutter::EncodableValue(message_uid > 0));
}

void HandleGetConversationRead(const flutter::EncodableMap *args,
                               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  Conversation conv(args);
  size_t len = 0;
  const char *str = WFClient::getConversationRead(
      conv.conversation_type, conv.target.c_str(), conv.target.size(),
      conv.line, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  flutter::EncodableValue value = JsonToEncodable(json_str);
  if (auto *list = std::get_if<flutter::EncodableList>(&value)) {
    // PC SDK may return empty array when no read receipts; normalize to empty map.
    result->Success(flutter::EncodableValue(flutter::EncodableMap()));
  } else if (std::get_if<flutter::EncodableMap>(&value)) {
    result->Success(value);
  } else {
    result->Success(flutter::EncodableValue(flutter::EncodableMap()));
  }
}

void HandleGetMessageDelivery(const flutter::EncodableMap *args,
                              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  Conversation conv(args);
  size_t len = 0;
  const char *str = WFClient::getMessageDelivery(conv.conversation_type,
                                                  conv.target.c_str(),
                                                  conv.target.size(), &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  flutter::EncodableValue value = JsonToEncodable(json_str);
  if (auto *list = std::get_if<flutter::EncodableList>(&value)) {
    result->Success(flutter::EncodableValue(flutter::EncodableMap()));
  } else if (std::get_if<flutter::EncodableMap>(&value)) {
    result->Success(value);
  } else {
    result->Success(flutter::EncodableValue(flutter::EncodableMap()));
  }
}

struct MessagesPromise {
  std::promise<std::string> promise;
};

static void WFCAPI OnGetMessagesSuccess(void *p_obj, int data_type,
                                        const char *cval, size_t val_len) {
  auto *mp = reinterpret_cast<MessagesPromise *>(p_obj);
  std::string json_str(cval, val_len);
  mp->promise.set_value(json_str);
  delete mp;
}

static void WFCAPI OnGetMessagesError(void *p_obj, int data_type,
                                      int error_code) {
  auto *mp = reinterpret_cast<MessagesPromise *>(p_obj);
  mp->promise.set_value("[]");
  delete mp;
}

void HandleGetMessages(const flutter::EncodableMap *args,
                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  Conversation conv(args);
  std::vector<int> content_types = GetIntList(args, "contentTypes");
  int64_t from_index = GetInt(args, "fromIndex", 0);
  int count = static_cast<int>(GetInt(args, "count", 0));
  std::string with_user = GetString(args, "withUser");

  // 参考 iOS：count > 0 表示向前（旧消息）direction=true；
  // count < 0 表示向后（新消息）direction=false，count 取绝对值。
  bool direction = count > 0;
  int abs_count = std::abs(count);

  auto *mp = new MessagesPromise();
  auto future = mp->promise.get_future();
  WFClient::getMessagesV2(
      conv.conversation_type, conv.target.c_str(), conv.target.size(),
      conv.line, content_types.data(), static_cast<int>(content_types.size()),
      from_index, direction, abs_count, with_user.c_str(),
      with_user.size(), OnGetMessagesSuccess, OnGetMessagesError,
      reinterpret_cast<void *>(mp), 0);
  future.wait();
  std::string json_str = future.get();
  result->Success(ReversedJsonArrayToEncodable(json_str));
}

void HandleGetMessagesByStatus(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  Conversation conv(args);
  int64_t from_index = GetInt(args, "fromIndex", 0);
  int count = static_cast<int>(GetInt(args, "count", 0));
  std::vector<int> message_statuses = GetIntList(args, "messageStatus");
  std::string with_user = GetString(args, "withUser");

  bool direction = count > 0;
  int abs_count = std::abs(count);

  auto *mp = new MessagesPromise();
  auto future = mp->promise.get_future();
  WFClient::getMessagesByMessageStatusV2(
      conv.conversation_type, conv.target.c_str(), conv.target.size(),
      conv.line, message_statuses.data(),
      static_cast<int>(message_statuses.size()), from_index, direction,
      abs_count, with_user.c_str(), with_user.size(), OnGetMessagesSuccess,
      OnGetMessagesError, reinterpret_cast<void *>(mp), 0);
  future.wait();
  std::string json_str = future.get();
  result->Success(ReversedJsonArrayToEncodable(json_str));
}

void HandleGetConversationsMessages(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::vector<int> types = GetIntList(args, "types");
  std::vector<int> lines = GetIntList(args, "lines");
  std::vector<int> content_types = GetIntList(args, "contentTypes");
  int64_t from_index = GetInt(args, "fromIndex", 0);
  int count = static_cast<int>(GetInt(args, "count", 0));
  std::string with_user = GetString(args, "withUser");

  bool direction = count > 0;
  int abs_count = std::abs(count);

  auto *mp = new MessagesPromise();
  auto future = mp->promise.get_future();
  WFClient::getMessagesExV2(
      types.data(), static_cast<int>(types.size()), lines.data(),
      static_cast<int>(lines.size()), content_types.data(),
      static_cast<int>(content_types.size()), from_index, direction,
      abs_count, with_user.c_str(), with_user.size(), OnGetMessagesSuccess,
      OnGetMessagesError, reinterpret_cast<void *>(mp), 0);
  future.wait();
  std::string json_str = future.get();
  result->Success(ReversedJsonArrayToEncodable(json_str));
}

void HandleGetConversationsMessageByStatus(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::vector<int> types = GetIntList(args, "types");
  std::vector<int> lines = GetIntList(args, "lines");
  int64_t from_index = GetInt(args, "fromIndex", 0);
  int count = static_cast<int>(GetInt(args, "count", 0));
  std::vector<int> message_statuses = GetIntList(args, "messageStatus");
  std::string with_user = GetString(args, "withUser");

  bool direction = count > 0;
  int abs_count = std::abs(count);

  auto *mp = new MessagesPromise();
  auto future = mp->promise.get_future();
  WFClient::getMessagesEx2V2(
      types.data(), static_cast<int>(types.size()), lines.data(),
      static_cast<int>(lines.size()), message_statuses.data(),
      static_cast<int>(message_statuses.size()), from_index, direction,
      abs_count, with_user.c_str(), with_user.size(), OnGetMessagesSuccess,
      OnGetMessagesError, reinterpret_cast<void *>(mp), 0);
  future.wait();
  std::string json_str = future.get();
  result->Success(ReversedJsonArrayToEncodable(json_str));
}

static void WFCAPI OnGetMessagesSuccess(void *p_obj, int data_type,
                                        const char *cval, size_t val_len) {
  int64_t request_id = reinterpret_cast<int64_t>(p_obj);
  std::string json_str(cval, val_len);
  flutter::EncodableValue value = ReversedJsonArrayToEncodable(json_str);
  flutter::EncodableList messages;
  if (auto *list = std::get_if<flutter::EncodableList>(&value)) {
    messages = *list;
  }
  flutter::EncodableMap args;
  args[flutter::EncodableValue("requestId")] =
      flutter::EncodableValue(request_id);
  args[flutter::EncodableValue("messages")] =
      flutter::EncodableValue(messages);
  InvokeDartMethod("onMessagesCallback", args);
}

static void WFCAPI OnGetMessagesError(void *p_obj, int data_type,
                                      int error_code) {
  int64_t request_id = reinterpret_cast<int64_t>(p_obj);
  flutter::EncodableMap args;
  args[flutter::EncodableValue("requestId")] =
      flutter::EncodableValue(request_id);
  args[flutter::EncodableValue("messages")] =
      flutter::EncodableValue(flutter::EncodableList());
  InvokeDartMethod("onMessagesCallback", args);
}

static void WFCAPI OnGetRemoteMessagesSuccess(void *p_obj, int data_type,
                                              const char *cval,
                                              size_t val_len) {
  int64_t request_id = reinterpret_cast<int64_t>(p_obj);
  std::string json_str(cval, val_len);
  flutter::EncodableValue value = ReversedJsonArrayToEncodable(json_str);
  flutter::EncodableList messages;
  if (auto *list = std::get_if<flutter::EncodableList>(&value)) {
    messages = *list;
  }
  flutter::EncodableMap args;
  args[flutter::EncodableValue("requestId")] =
      flutter::EncodableValue(request_id);
  args[flutter::EncodableValue("messages")] =
      flutter::EncodableValue(messages);
  InvokeDartMethod("onMessagesCallback", args);
}

static void WFCAPI OnGetRemoteMessagesError(void *p_obj, int data_type,
                                            int error_code) {
  OnGeneralError(p_obj, data_type, error_code);
}

void HandleGetRemoteMessages(const flutter::EncodableMap *args,
                             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  Conversation conv(args);
  int64_t before_uid = GetInt(args, "beforeMessageUid", 0);
  int count = static_cast<int>(GetInt(args, "count", 0));
  std::vector<int> content_types = GetIntList(args, "contentTypes");

  WFClient::getRemoteMessages(
      conv.conversation_type, conv.target.c_str(), conv.target.size(),
      conv.line, content_types.data(),
      static_cast<int>(content_types.size()), before_uid, count,
      OnGetRemoteMessagesSuccess, OnGetRemoteMessagesError,
      reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleGetRemoteMessage(const flutter::EncodableMap *args,
                            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  int64_t message_uid = GetInt(args, "messageUid", 0);
  WFClient::getRemoteMessage(message_uid, OnGeneralStringSuccess, OnGeneralError,
                             reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleGetMessage(const flutter::EncodableMap *args,
                      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int message_id = static_cast<int>(GetInt(args, "messageId", 0));
  size_t len = 0;
  const char *str = WFClient::getMessage(message_id, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result->Success(JsonToEncodable(json_str));
}

void HandleGetMessageByUid(const flutter::EncodableMap *args,
                           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t message_uid = GetInt(args, "messageUid", 0);
  size_t len = 0;
  const char *str = WFClient::getMessageByUid(message_uid, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result->Success(JsonToEncodable(json_str));
}

void HandleSearchMessages(const flutter::EncodableMap *args,
                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  Conversation conv(args);
  std::string keyword = GetString(args, "keyword");
  bool order = GetBool(args, "order", false);
  int limit = static_cast<int>(GetInt(args, "limit", 0));
  int offset = static_cast<int>(GetInt(args, "offset", 0));
  std::string with_user = GetString(args, "withUser");

  size_t len = 0;
  const char *str = WFClient::searchMessage(
      conv.conversation_type, conv.target.c_str(), conv.target.size(),
      conv.line, keyword.c_str(), keyword.size(), order, limit, offset,
      with_user.c_str(), with_user.size(), &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result->Success(ReversedJsonArrayToEncodable(json_str));
}

void HandleSearchConversationsMessages(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::vector<int> types = GetIntList(args, "types");
  std::vector<int> lines = GetIntList(args, "lines");
  std::vector<int> content_types = GetIntList(args, "contentTypes");
  std::string keyword = GetString(args, "keyword");
  int64_t from_index = GetInt(args, "fromIndex", 0);
  int count = static_cast<int>(GetInt(args, "count", 0));
  std::string with_user = GetString(args, "withUser");

  size_t len = 0;
  const char *str = WFClient::searchMessageEx2(
      types.data(), static_cast<int>(types.size()), lines.data(),
      static_cast<int>(lines.size()), content_types.data(),
      static_cast<int>(content_types.size()), keyword.c_str(), keyword.size(),
      from_index, count > 0, std::abs(count), with_user.c_str(),
      with_user.size(), &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result->Success(ReversedJsonArrayToEncodable(json_str));
}

void HandleSendMessage(const flutter::EncodableMap *args,
                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  Conversation conv(args);
  int64_t request_id = GetInt(args, "requestId", 0);
  MessagePayload payload(GetMap(args, "content"));
  std::vector<std::string> to_users = GetStringList(args, "toUsers");
  int expire_duration = static_cast<int>(GetInt(args, "expireDuration", 0));

  std::string content_json = EncodableToJson(
      flutter::EncodableValue(payload.ToEncodable()));

  size_t user_count = to_users.size();
  std::vector<const char *> user_ptrs;
  std::vector<size_t> user_lengths;
  for (const auto &u : to_users) {
    user_ptrs.push_back(u.c_str());
    user_lengths.push_back(u.size());
  }

  size_t len = 0;
  const char *str = WFClient::sendMessage(
      conv.conversation_type, conv.target.c_str(), conv.target.size(),
      conv.line, content_json.c_str(), content_json.size(),
      user_ptrs.empty() ? nullptr : user_ptrs.data(),
      user_lengths.empty() ? nullptr : user_lengths.data(), user_count,
      expire_duration, OnSendMessageSuccess, OnSendMessageError,
      OnSendMessagePrepared, OnSendMessageProgress, OnSendMessageMediaUploaded,
      reinterpret_cast<void *>(request_id), 0, &len);

  std::string result_json = ConvertDllStringAndRelease(str, len);
  result->Success(JsonToEncodable(result_json));
}

void HandleSendSavedMessage(const flutter::EncodableMap *args,
                            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  int message_id = static_cast<int>(GetInt(args, "messageId", 0));
  int expire_duration = static_cast<int>(GetInt(args, "expireDuration", 0));
  bool ret = WFClient::sendSavedMessage(
      message_id, expire_duration, OnSendMessageSuccess, OnSendMessageError,
      reinterpret_cast<void *>(request_id), 0);
  result->Success(flutter::EncodableValue(ret));
}

void HandleCancelSendingMessage(const flutter::EncodableMap *args,
                                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int message_id = static_cast<int>(GetInt(args, "messageId", 0));
  bool ret = WFClient::cancelSendingMessage(message_id);
  result->Success(flutter::EncodableValue(ret));
}

void HandleRecallMessage(const flutter::EncodableMap *args,
                         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  int64_t message_uid = GetInt(args, "messageUid", 0);
  WFClient::recallMessage(message_uid, OnGeneralVoidSuccess, OnGeneralError,
                          reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleUploadMedia(const flutter::EncodableMap *args,
                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string file_name = GetString(args, "fileName");
  std::vector<uint8_t> media_data;
  const flutter::EncodableValue *media_value = FindRawValue(args, "mediaData");
  if (media_value) {
    const std::vector<uint8_t> *bytes =
        std::get_if<std::vector<uint8_t>>(media_value);
    if (bytes) media_data = *bytes;
  }
  int media_type = static_cast<int>(GetInt(args, "mediaType", 0));

  std::string data_str(media_data.begin(), media_data.end());
  WFClient::uploadMedia(
      file_name.c_str(), file_name.size(), data_str.c_str(),
      static_cast<int>(data_str.size()), media_type,
      OnGeneralStringSuccess, OnGeneralError, nullptr,
      reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleUploadMediaFile(const flutter::EncodableMap *args,
                           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // PC SDK does not support file path upload directly; return empty string callback.
  int64_t request_id = GetInt(args, "requestId", 0);
  flutter::EncodableMap callback_args;
  callback_args[flutter::EncodableValue("requestId")] =
      flutter::EncodableValue(request_id);
  callback_args[flutter::EncodableValue("data")] =
      flutter::EncodableValue("");
  InvokeDartMethod("onOperationStringSuccess", callback_args);
  result->Success();
}

void HandleGetUploadUrl(const flutter::EncodableMap *args,
                        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string file_name = GetString(args, "fileName");
  std::string content_type = GetString(args, "contentType");
  int media_type = static_cast<int>(GetInt(args, "mediaType", 0));
  WFClient::getUploadUrl(file_name.c_str(), file_name.size(), media_type,
                         content_type.c_str(),
                         static_cast<int>(content_type.size()),
                         OnGetUploadUrlSuccess, OnGeneralError,
                         reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleGetMediaUploadUrl(const flutter::EncodableMap *args,
                             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // Same implementation as getUploadUrl; forwards to SDK getUploadUrl.
  HandleGetUploadUrl(args, std::move(result));
}

void HandleIsSupportBigFilesUpload(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success(flutter::EncodableValue(WFClient::isSupportBigFilesUpload()));
}

void HandleDeleteMessage(const flutter::EncodableMap *args,
                         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int message_id = static_cast<int>(GetInt(args, "messageId", 0));
  bool ret = WFClient::deleteMessage(message_id);
  result->Success(flutter::EncodableValue(ret));
}

void HandleBatchDeleteMessages(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::vector<int64_t> message_uids = GetInt64List(args, "messageUids");
  bool ret = WFClient::batchDeleteMessages(
      message_uids.data(), static_cast<int64_t>(message_uids.size()));
  result->Success(flutter::EncodableValue(ret));
}

void HandleDeleteRemoteMessage(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  int64_t message_uid = GetInt(args, "messageUid", 0);
  WFClient::deleteRemoteMessage(message_uid, OnGeneralVoidSuccess, OnGeneralError,
                                reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleClearMessages(const flutter::EncodableMap *args,
                         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  Conversation conv(args);
  int64_t before = GetInt(args, "before", 0);
  if (before <= 0) {
    WFClient::clearMessages(conv.conversation_type, conv.target.c_str(),
                            conv.target.size(), conv.line);
  } else {
    WFClient::clearMessagesBefore(conv.conversation_type, conv.target.c_str(),
                                  conv.target.size(), conv.line, before);
  }
  result->Success(flutter::EncodableValue(true));
}

void HandleClearMessagesKeepLatest(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  Conversation conv(args);
  int keep_count = static_cast<int>(GetInt(args, "keepCount", 0));
  WFClient::clearMessagesKeep(conv.conversation_type, conv.target.c_str(),
                              conv.target.size(), conv.line, keep_count);
  result->Success(flutter::EncodableValue(true));
}

void HandleClearRemoteConversationMessage(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  Conversation conv(args);
  WFClient::clearRemoteConversationMessage(
      conv.conversation_type, conv.target.c_str(), conv.target.size(),
      conv.line, OnGeneralVoidSuccess, OnGeneralError,
      reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleSetMediaMessagePlayed(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int message_id = static_cast<int>(GetInt(args, "messageId", 0));
  WFClient::setMediaMessagePlayed(message_id);
  result->Success();
}

void HandleSetMessageLocalExtra(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int message_id = static_cast<int>(GetInt(args, "messageId", 0));
  std::string local_extra = GetString(args, "localExtra");
  bool ret = WFClient::setMessageLocalExtra(
      message_id, local_extra.c_str(), local_extra.size());
  result->Success(flutter::EncodableValue(ret));
}

void HandleInsertMessage(const flutter::EncodableMap *args,
                         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  Conversation conv(args);
  std::string sender = GetString(args, "sender");
  MessagePayload payload(GetMap(args, "content"));
  int status = static_cast<int>(GetInt(args, "status", 0));
  bool notify = GetBool(args, "notify", false);
  int64_t server_time = GetInt(args, "serverTime", 0);

  std::string content_json = EncodableToJson(
      flutter::EncodableValue(payload.ToEncodable()));

  size_t len = 0;
  const char *str = WFClient::insertMessage(
      conv.conversation_type, conv.target.c_str(), conv.target.size(),
      conv.line, sender.c_str(), sender.size(), content_json.c_str(),
      content_json.size(), status, notify, server_time, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result->Success(JsonToEncodable(json_str));
}

void HandleUpdateMessage(const flutter::EncodableMap *args,
                         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int message_id = static_cast<int>(GetInt(args, "messageId", 0));
  MessagePayload payload(GetMap(args, "content"));
  std::string content_json = EncodableToJson(
      flutter::EncodableValue(payload.ToEncodable()));
  WFClient::updateMessage(message_id, content_json.c_str(),
                          content_json.size());
  result->Success();
}

void HandleUpdateRemoteMessageContent(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  int64_t message_uid = GetInt(args, "messageUid", 0);
  MessagePayload payload(GetMap(args, "content"));
  std::string content_json = EncodableToJson(
      flutter::EncodableValue(payload.ToEncodable()));
  bool distribute = GetBool(args, "distribute", false);
  bool update_local = GetBool(args, "updateLocal", false);
  WFClient::updateRemoteMessage(
      message_uid, content_json.c_str(), content_json.size(), distribute,
      update_local, OnGeneralVoidSuccess, OnGeneralError,
      reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleUpdateMessageStatus(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int message_id = static_cast<int>(GetInt(args, "messageId", 0));
  int status = static_cast<int>(GetInt(args, "status", 0));
  WFClient::updateMessageStatus(message_id, status);
  result->Success();
}

void HandleGetMessageCount(const flutter::EncodableMap *args,
                           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  Conversation conv(args);
  int count = WFClient::getMessageCount(conv.conversation_type,
                                        conv.target.c_str(),
                                        conv.target.size(), conv.line);
  result->Success(flutter::EncodableValue(count));
}

void HandleGetAuthorizedMediaUrl(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  int64_t message_uid = GetInt(args, "messageUid", 0);
  int media_type = static_cast<int>(GetInt(args, "mediaType", 0));
  std::string media_path = GetString(args, "mediaPath");
  WFClient::getAuthorizedMediaUrl(
      message_uid, media_type, media_path.c_str(), media_path.size(),
      OnGeneralStringSuccess, OnGeneralError,
      reinterpret_cast<void *>(request_id), 0);
  result->Success();
}


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

static void WFCAPI OnFilesResult(void *p_obj, int data_type,
                                 const char *cval, size_t val_len) {
  int64_t request_id = reinterpret_cast<int64_t>(p_obj);
  std::string json_str(cval, val_len);
  flutter::EncodableValue value = JsonToEncodable(json_str);
  flutter::EncodableList files;
  if (auto *list = std::get_if<flutter::EncodableList>(&value)) {
    files = *list;
  }
  flutter::EncodableMap args;
  args[flutter::EncodableValue("requestId")] =
      flutter::EncodableValue(request_id);
  args[flutter::EncodableValue("files")] = flutter::EncodableValue(files);
  InvokeDartMethod("onFilesResult", args);
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
  // PC SDK has no startLog; return success.
  result->Success();
}

void HandleStopLog(const flutter::EncodableMap *args,
                   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // PC SDK has no stopLog; return success.
  result->Success();
}

void HandleSetSendLogCommand(const flutter::EncodableMap *args,
                             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // PC SDK has no setSendLogCommand; return success.
  result->Success();
}

void HandleGetLogFilesPath(const flutter::EncodableMap *args,
                           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  size_t len = 0;
  const char *str = WFClient::getLogFilesPath(&len);
  std::string path = ConvertDllStringAndRelease(str, len);
  result->Success(flutter::EncodableValue(path));
}

void HandleSetDeviceToken(const flutter::EncodableMap *args,
                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success();
}

void HandleSetVoipDeviceToken(const flutter::EncodableMap *args,
                              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success();
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
  bool refresh = GetBool(args, "refresh", false);
  size_t len = 0;
  const char *str = WFClient::getFriendList(refresh, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result->Success(JsonToEncodable(json_str));
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
                                               direction == 1, &len);
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
  int direction = static_cast<int>(GetInt(args, "direction", 0));
  int64_t before_time = GetInt(args, "beforeTime", 0);
  result->Success(
      flutter::EncodableValue(WFClient::clearFriendRequest(direction, before_time)));
}

void HandleDeleteFriendRequest(const flutter::EncodableMap *args,
                               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::string user_id = GetString(args, "userId");
  int direction = static_cast<int>(GetInt(args, "direction", 0));
  result->Success(flutter::EncodableValue(
      WFClient::deleteFriendRequest(user_id.c_str(), user_id.size(), direction)));
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
  std::string group_id = GetString(args, "groupId");
  size_t len = 0;
  const char *str = WFClient::getGroupRemark(group_id.c_str(),
                                             group_id.size(), &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result->Success(JsonToEncodable(json_str));
}

void HandleSetGroupRemark(const flutter::EncodableMap *args,
                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string group_id = GetString(args, "groupId");
  std::string remark = GetString(args, "remark");
  WFClient::setGroupRemark(
      group_id.c_str(), group_id.size(), remark.c_str(), remark.size(),
      OnGeneralVoidSuccess, OnGeneralError,
      reinterpret_cast<void *>(request_id), 0);
  result->Success();
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
  result->Success(flutter::EncodableValue(false));
}

void HandleSetVoipNotificationSilent(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  flutter::EncodableMap callback_args;
  callback_args[flutter::EncodableValue("requestId")] =
      flutter::EncodableValue(request_id);
  InvokeDartMethod("onOperationVoidSuccess", callback_args);
  result->Success();
}

void HandleIsEnableSyncDraft(const flutter::EncodableMap *args,
                             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success(flutter::EncodableValue(WFClient::isEnableSyncDraft()));
}

void HandleSetEnableSyncDraft(const flutter::EncodableMap *args,
                              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  flutter::EncodableMap callback_args;
  callback_args[flutter::EncodableValue("requestId")] =
      flutter::EncodableValue(request_id);
  InvokeDartMethod("onOperationVoidSuccess", callback_args);
  result->Success();
}

void HandleGetNoDisturbingTimes(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  flutter::EncodableMap callback_args;
  callback_args[flutter::EncodableValue("requestId")] =
      flutter::EncodableValue(request_id);
  callback_args[flutter::EncodableValue("first")] =
      flutter::EncodableValue(0);
  callback_args[flutter::EncodableValue("second")] =
      flutter::EncodableValue(0);
  InvokeDartMethod("onOperationIntPairSuccess", callback_args);
  result->Success();
}

void HandleSetNoDisturbingTimes(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  flutter::EncodableMap callback_args;
  callback_args[flutter::EncodableValue("requestId")] =
      flutter::EncodableValue(request_id);
  InvokeDartMethod("onOperationVoidSuccess", callback_args);
  result->Success();
}

void HandleClearNoDisturbingTimes(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  flutter::EncodableMap callback_args;
  callback_args[flutter::EncodableValue("requestId")] =
      flutter::EncodableValue(request_id);
  InvokeDartMethod("onOperationVoidSuccess", callback_args);
  result->Success();
}

void HandleIsNoDisturbing(const flutter::EncodableMap *args,
                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success(flutter::EncodableValue(false));
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
  int64_t request_id = GetInt(args, "requestId", 0);
  WFClient::getMyGroups(OnGeneralStringSuccess, OnGeneralError,
                        reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleGetCommonGroups(const flutter::EncodableMap *args,
                           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string user_id = GetString(args, "userId");
  WFClient::getCommonGroups(user_id.c_str(), user_id.size(),
                            OnGeneralStringSuccess, OnGeneralError,
                            reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleIsUserEnableReceipt(const flutter::EncodableMap *args,
                               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success(flutter::EncodableValue(WFClient::isUserEnableReceipt()));
}

void HandleSetUserEnableReceipt(const flutter::EncodableMap *args,
                                std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  bool is_enable = GetBool(args, "isEnable", false);
  WFClient::setUserEnableReceipt(
      is_enable, OnGeneralVoidSuccess, OnGeneralError,
      reinterpret_cast<void *>(request_id), 0);
  result->Success();
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
  size_t len = 0;
  const char *str = WFClient::getJoinedChatroomId(&len);
  std::string chatroom_id = ConvertDllStringAndRelease(str, len);
  result->Success(flutter::EncodableValue(chatroom_id));
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
  result->Success(flutter::EncodableList());
}

void HandleKickoffPCClient(const flutter::EncodableMap *args,
                           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  flutter::EncodableMap callback_args;
  callback_args[flutter::EncodableValue("requestId")] =
      flutter::EncodableValue(request_id);
  InvokeDartMethod("onOperationVoidSuccess", callback_args);
  result->Success();
}

void HandleIsMuteNotificationWhenPcOnline(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success(flutter::EncodableValue(false));
}

void HandleSetDefaultSilentWhenPcOnline(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success();
}

void HandleMuteNotificationWhenPcOnline(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  flutter::EncodableMap callback_args;
  callback_args[flutter::EncodableValue("requestId")] =
      flutter::EncodableValue(request_id);
  InvokeDartMethod("onOperationVoidSuccess", callback_args);
  result->Success();
}

void HandleGetUserOnlineState(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success();
}

void HandleGetMyCustomState(const flutter::EncodableMap *args,
                            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  size_t len = 0;
  const char *str = WFClient::getMyCustomState(&len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result->Success(JsonToEncodable(json_str));
}

void HandleSetMyCustomState(const flutter::EncodableMap *args,
                            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  int custom_state = static_cast<int>(GetInt(args, "customState", 0));
  std::string custom_text = GetString(args, "customText");
  flutter::EncodableMap state_map;
  state_map[flutter::EncodableValue("state")] =
      flutter::EncodableValue(custom_state);
  state_map[flutter::EncodableValue("text")] =
      flutter::EncodableValue(custom_text);
  std::string state_json = EncodableToJson(flutter::EncodableValue(state_map));
  WFClient::setMyCustomState(
      state_json.c_str(), state_json.size(), OnGeneralVoidSuccess,
      OnGeneralError, reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleWatchOnlineState(const flutter::EncodableMap *args,
                            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  int conversation_type = static_cast<int>(GetInt(args, "conversationType", 0));
  std::vector<std::string> targets = GetStringList(args, "targets");
  int watch_duration = static_cast<int>(GetInt(args, "watchDuration", 0));
  std::vector<const char *> target_ptrs;
  std::vector<size_t> target_lengths;
  for (const auto &t : targets) {
    target_ptrs.push_back(t.c_str());
    target_lengths.push_back(t.size());
  }
  WFClient::watchOnlineState(
      conversation_type,
      target_ptrs.empty() ? nullptr : target_ptrs.data(),
      target_lengths.empty() ? nullptr : target_lengths.data(), targets.size(),
      watch_duration, OnWatchOnlineStateSuccess, OnGeneralError,
      reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleUnwatchOnlineState(const flutter::EncodableMap *args,
                              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  int conversation_type = static_cast<int>(GetInt(args, "conversationType", 0));
  std::vector<std::string> targets = GetStringList(args, "targets");
  std::vector<const char *> target_ptrs;
  std::vector<size_t> target_lengths;
  for (const auto &t : targets) {
    target_ptrs.push_back(t.c_str());
    target_lengths.push_back(t.size());
  }
  WFClient::unwatchOnlineState(
      conversation_type,
      target_ptrs.empty() ? nullptr : target_ptrs.data(),
      target_lengths.empty() ? nullptr : target_lengths.data(), targets.size(),
      OnGeneralVoidSuccess, OnGeneralError,
      reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleIsEnableUserOnlineState(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success(flutter::EncodableValue(WFClient::isEnableUserOnlineState()));
}

void HandleSendConferenceRequest(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  int64_t session_id = GetInt(args, "sessionId", 0);
  std::string room_id = GetString(args, "roomId");
  std::string request = GetString(args, "request");
  bool advanced = GetBool(args, "advanced", false);
  std::string data = GetString(args, "data");
  WFClient::sendConferenceRequest(
      session_id, room_id.c_str(), room_id.size(), request.c_str(),
      request.size(), advanced, data.c_str(), data.size(),
      OnGeneralStringSuccess, OnGeneralError,
      reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleGetConversationFiles(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  Conversation conv(args);
  std::string from_user = GetString(args, "fromUser");
  int64_t message_uid = GetInt(args, "beforeMessageUid", 0);
  int order = static_cast<int>(GetInt(args, "order", 0));
  int count = static_cast<int>(GetInt(args, "count", 0));
  WFClient::getConversationFiles(
      conv.conversation_type, conv.target.c_str(), conv.target.size(),
      conv.line, from_user.c_str(), from_user.size(), message_uid, order,
      count, OnFilesResult, OnGeneralError,
      reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleGetMyFiles(const flutter::EncodableMap *args,
                      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  int64_t message_uid = GetInt(args, "beforeMessageUid", 0);
  int order = static_cast<int>(GetInt(args, "order", 0));
  int count = static_cast<int>(GetInt(args, "count", 0));
  WFClient::getMyFiles(message_uid, order, count, OnFilesResult,
                       OnGeneralError,
                       reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleDeleteFileRecord(const flutter::EncodableMap *args,
                            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  int64_t message_uid = GetInt(args, "messageUid", 0);
  WFClient::deleteFileRecord(message_uid, OnGeneralVoidSuccess, OnGeneralError,
                             reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleSearchFiles(const flutter::EncodableMap *args,
                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string keyword = GetString(args, "keyword");
  Conversation conv(args);
  std::string from_user = GetString(args, "fromUser");
  int64_t message_uid = GetInt(args, "beforeMessageUid", 0);
  int order = static_cast<int>(GetInt(args, "order", 0));
  int count = static_cast<int>(GetInt(args, "count", 0));
  WFClient::searchFiles(
      keyword.c_str(), keyword.size(), conv.conversation_type,
      conv.target.c_str(), conv.target.size(), conv.line,
      from_user.c_str(), from_user.size(), message_uid, order, count,
      OnFilesResult, OnGeneralError,
      reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleSearchMyFiles(const flutter::EncodableMap *args,
                         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string keyword = GetString(args, "keyword");
  int64_t message_uid = GetInt(args, "beforeMessageUid", 0);
  int order = static_cast<int>(GetInt(args, "order", 0));
  int count = static_cast<int>(GetInt(args, "count", 0));
  WFClient::searchMyFiles(keyword.c_str(), keyword.size(), message_uid, order,
                          count, OnFilesResult, OnGeneralError,
                          reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleGetAuthCode(const flutter::EncodableMap *args,
                       std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string application_id = GetString(args, "applicationId");
  int type = static_cast<int>(GetInt(args, "type", 0));
  std::string host = GetString(args, "host");
  WFClient::getAuthCode(application_id.c_str(), application_id.size(), type,
                        host.c_str(), host.size(), OnGeneralStringSuccess,
                        OnGeneralError,
                        reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleConfigApplication(const flutter::EncodableMap *args,
                             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  int64_t request_id = GetInt(args, "requestId", 0);
  std::string application_id = GetString(args, "applicationId");
  int type = static_cast<int>(GetInt(args, "type", 0));
  int64_t timestamp = GetInt(args, "timestamp", 0);
  std::string nonce = GetString(args, "nonce");
  std::string signature = GetString(args, "signature");
  WFClient::configApplication(
      application_id.c_str(), application_id.size(), type, timestamp,
      nonce.c_str(), nonce.size(), signature.c_str(), signature.size(),
      OnGeneralVoidSuccess, OnGeneralError,
      reinterpret_cast<void *>(request_id), 0);
  result->Success();
}

void HandleGetWavData(const flutter::EncodableMap *args,
                      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // PC SDK has no AMR to WAV conversion; return empty data.
  result->Success(flutter::EncodableValue(std::vector<uint8_t>()));
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
  result->Success(flutter::EncodableValue(WFClient::isCommercialServer()));
}

void HandleIsReceiptEnabled(const flutter::EncodableMap *args,
                            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success(flutter::EncodableValue(WFClient::isReceiptEnabled()));
}

void HandleIsGroupReceiptEnabled(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success(flutter::EncodableValue(WFClient::isGroupReceiptEnabled()));
}

void HandleIsGlobalDisableSyncDraft(
    const flutter::EncodableMap *args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  result->Success(flutter::EncodableValue(WFClient::isGlobalDisableSyncDraft()));
}

void ImclientPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarLinux *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "imclient",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<ImclientPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  SetChannel(channel.get());
  plugin->channel_ = std::move(channel);

  registrar->AddPlugin(std::move(plugin));
}

ImclientPlugin::ImclientPlugin() {}

ImclientPlugin::~ImclientPlugin() {
  SetChannel(nullptr);
}

void ImclientPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string &method = method_call.method_name();
  const flutter::EncodableMap *args = nullptr;
  if (method_call.arguments()) {
    args = std::get_if<flutter::EncodableMap>(method_call.arguments());
  }

  if (method == "initProto") {
    HandleInitProto(args, std::move(result));
  } else if (method == "getClientId") {
    HandleGetClientId(args, std::move(result));
  } else if (method == "currentUserId") {
    HandleCurrentUserId(args, std::move(result));
  } else if (method == "getProtoRevision") {
    HandleGetProtoRevision(args, std::move(result));
  } else if (method == "connect") {
    HandleConnect(args, std::move(result));
  } else if (method == "disconnect") {
    HandleDisconnect(args, std::move(result));
  } else if (method == "connectionStatus") {
    HandleConnectionStatus(args, std::move(result));
  } else if (method == "isLogined") {
    HandleIsLogined(args, std::move(result));
  } else if (method == "serverDeltaTime") {
    HandleServerDeltaTime(args, std::move(result));
  } else if (method == "setBackupAddress") {
    HandleSetBackupAddress(args, std::move(result));
  } else if (method == "useSM4") {
    HandleUseSM4(args, std::move(result));
  } else if (method == "setLiteMode") {
    HandleSetLiteMode(args, std::move(result));
  } else if (method == "setBackupAddressStrategy") {
    HandleSetBackupAddressStrategy(args, std::move(result));
  } else if (method == "setProtoUserAgent") {
    HandleSetProtoUserAgent(args, std::move(result));
  } else if (method == "addHttpHeader") {
    HandleAddHttpHeader(args, std::move(result));
  } else if (method == "setProxyInfo") {
    HandleSetProxyInfo(args, std::move(result));
  } else if (method == "registerMessage") {
    HandleRegisterMessage(args, std::move(result));
  } else if (method == "getConversationInfos") {
    HandleGetConversationInfos(args, std::move(result));
  } else if (method == "getConversationInfo") {
    HandleGetConversationInfo(args, std::move(result));
  } else if (method == "searchConversation") {
    HandleSearchConversation(args, std::move(result));
  } else if (method == "removeConversation") {
    HandleRemoveConversation(args, std::move(result));
  } else if (method == "setConversationTop") {
    HandleSetConversationTop(args, std::move(result));
  } else if (method == "setConversationSilent") {
    HandleSetConversationSilent(args, std::move(result));
  } else if (method == "setConversationDraft") {
    HandleSetConversationDraft(args, std::move(result));
  } else if (method == "setConversationTimestamp") {
    HandleSetConversationTimestamp(args, std::move(result));
  } else if (method == "getFirstUnreadMessageId") {
    HandleGetFirstUnreadMessageId(args, std::move(result));
  } else if (method == "getConversationUnreadCount") {
    HandleGetConversationUnreadCount(args, std::move(result));
  } else if (method == "getConversationsUnreadCount") {
    HandleGetConversationsUnreadCount(args, std::move(result));
  } else if (method == "clearConversationUnreadStatus") {
    HandleClearConversationUnreadStatus(args, std::move(result));
  } else if (method == "clearConversationsUnreadStatus") {
    HandleClearConversationsUnreadStatus(args, std::move(result));
  } else if (method == "clearAllUnreadStatus") {
    HandleClearAllUnreadStatus(args, std::move(result));
  } else if (method == "clearMessageUnreadStatus") {
    HandleClearMessageUnreadStatus(args, std::move(result));
  } else if (method == "clearMessageUnreadStatusBefore") {
    HandleClearMessageUnreadStatusBefore(args, std::move(result));
  } else if (method == "markAsUnRead") {
    HandleMarkAsUnRead(args, std::move(result));
  } else if (method == "getConversationRead") {
    HandleGetConversationRead(args, std::move(result));
  } else if (method == "getMessageDelivery") {
    HandleGetMessageDelivery(args, std::move(result));
  } else if (method == "getMessages") {
    HandleGetMessages(args, std::move(result));
  } else if (method == "getMessagesByStatus") {
    HandleGetMessagesByStatus(args, std::move(result));
  } else if (method == "getConversationsMessages") {
    HandleGetConversationsMessages(args, std::move(result));
  } else if (method == "getConversationsMessageByStatus") {
    HandleGetConversationsMessageByStatus(args, std::move(result));
  } else if (method == "getRemoteMessages") {
    HandleGetRemoteMessages(args, std::move(result));
  } else if (method == "getRemoteMessage") {
    HandleGetRemoteMessage(args, std::move(result));
  } else if (method == "getMessage") {
    HandleGetMessage(args, std::move(result));
  } else if (method == "getMessageByUid") {
    HandleGetMessageByUid(args, std::move(result));
  } else if (method == "searchMessages") {
    HandleSearchMessages(args, std::move(result));
  } else if (method == "searchConversationsMessages") {
    HandleSearchConversationsMessages(args, std::move(result));
  } else if (method == "sendMessage") {
    HandleSendMessage(args, std::move(result));
  } else if (method == "sendSavedMessage") {
    HandleSendSavedMessage(args, std::move(result));
  } else if (method == "cancelSendingMessage") {
    HandleCancelSendingMessage(args, std::move(result));
  } else if (method == "recallMessage") {
    HandleRecallMessage(args, std::move(result));
  } else if (method == "uploadMedia") {
    HandleUploadMedia(args, std::move(result));
  } else if (method == "uploadMediaFile") {
    HandleUploadMediaFile(args, std::move(result));
  } else if (method == "getUploadUrl") {
    HandleGetUploadUrl(args, std::move(result));
  } else if (method == "getMediaUploadUrl") {
    HandleGetMediaUploadUrl(args, std::move(result));
  } else if (method == "isSupportBigFilesUpload") {
    HandleIsSupportBigFilesUpload(args, std::move(result));
  } else if (method == "deleteMessage") {
    HandleDeleteMessage(args, std::move(result));
  } else if (method == "batchDeleteMessages") {
    HandleBatchDeleteMessages(args, std::move(result));
  } else if (method == "deleteRemoteMessage") {
    HandleDeleteRemoteMessage(args, std::move(result));
  } else if (method == "clearMessages") {
    HandleClearMessages(args, std::move(result));
  } else if (method == "clearMessagesKeepLatest") {
    HandleClearMessagesKeepLatest(args, std::move(result));
  } else if (method == "clearRemoteConversationMessage") {
    HandleClearRemoteConversationMessage(args, std::move(result));
  } else if (method == "setMediaMessagePlayed") {
    HandleSetMediaMessagePlayed(args, std::move(result));
  } else if (method == "setMessageLocalExtra") {
    HandleSetMessageLocalExtra(args, std::move(result));
  } else if (method == "insertMessage") {
    HandleInsertMessage(args, std::move(result));
  } else if (method == "updateMessage") {
    HandleUpdateMessage(args, std::move(result));
  } else if (method == "updateRemoteMessageContent") {
    HandleUpdateRemoteMessageContent(args, std::move(result));
  } else if (method == "updateMessageStatus") {
    HandleUpdateMessageStatus(args, std::move(result));
  } else if (method == "getMessageCount") {
    HandleGetMessageCount(args, std::move(result));
  } else if (method == "getAuthorizedMediaUrl") {
    HandleGetAuthorizedMediaUrl(args, std::move(result));
  } else if (method == "startLog") {
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

  } else {
    result->NotImplemented();
  }
}

}  // namespace imclient
