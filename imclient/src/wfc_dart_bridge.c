// wfc_dart_bridge.c — 桌面端唯一的原生垫片，macOS/Windows/Linux 三平台共用。
//
// 职责（且仅有此职责）：把 WFClient SDK 从任意线程发起的 C 回调，同步拷贝
// 载荷后经 Dart_PostCObject_DL 投递到 Dart isolate。所有分发、序列化、业务
// 逻辑都在 Dart 侧（imclient_ffi_channel.dart）。
//
// 为什么需要它：SDK 回调传入的 const char* 指向栈上临时字符串（见
// cpp-client/marswrapper.cc），回调返回即失效；而 dart:ffi 的
// NativeCallable.listener 是异步投递，读取时机不可控，纯 Dart 监听会产生
// use-after-free。本垫片在回调线程上同步完成拷贝，消除该竞态。
//
// 消息格式：Dart_CObject kArray = [int32 tag, ...payload]；字符串以
// kTypedData(Uint8) 传输（Dart_PostCObject_DL 投递时拷贝进消息）。
// tag 常量与 imclient_ffi_channel.dart 中的 _BridgeTag 一一对应。

#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "dart_include/dart_api_dl.h"

#if defined(_WIN32)
#define WFC_EXPORT __declspec(dllexport)
#define WFCAPI __stdcall
#else
#define WFC_EXPORT __attribute__((visibility("default")))
#define WFCAPI
#endif

// ---- tag 常量（与 Dart 侧 _BridgeTag 保持一致） ----
enum {
  kTagConnectionStatus = 1,
  kTagReceiveMessage = 2,
  kTagRecallMessage = 3,
  kTagDeleteMessage = 4,
  kTagUserInfoUpdated = 5,
  kTagGroupInfoUpdated = 6,
  kTagGroupMemberUpdated = 7,
  kTagFriendListUpdated = 8,
  kTagFriendRequestUpdated = 9,
  kTagSettingUpdated = 10,
  kTagChannelInfoUpdated = 11,
  kTagMessageDelivered = 12,
  kTagMessageReaded = 13,
  kTagJoinGroupRequestUpdated = 14,

  kTagDomainInfoUpdated = 15,

  kTagOnlineEventUpdated = 16,

  kTagGeneralVoidSuccess = 20,
  kTagGeneralStringSuccess = 21,
  kTagGeneralError = 22,
  kTagSendMessageSuccess = 23,
  kTagSendMessagePrepared = 24,
  kTagSendMessageProgress = 25,
  kTagSendMessageUploaded = 26,
  kTagSendMessageError = 27,
  kTagUploadMediaProgress = 28,
  kTagConnectedToServer = 29,
};

static Dart_Port_DL g_port = 0;

WFC_EXPORT intptr_t wfc_dart_bridge_init(void *dart_api_data) {
  return Dart_InitializeApiDL(dart_api_data);
}

WFC_EXPORT void wfc_dart_bridge_set_port(int64_t port) { g_port = port; }

// ---- Dart_CObject 构造 ----

static Dart_CObject c_int(int64_t v) {
  Dart_CObject o;
  o.type = Dart_CObject_kInt64;
  o.value.as_int64 = v;
  return o;
}

static Dart_CObject c_bool(bool v) {
  Dart_CObject o;
  o.type = Dart_CObject_kBool;
  o.value.as_bool = v;
  return o;
}

static Dart_CObject c_bytes(const char *p, size_t len) {
  Dart_CObject o;
  o.type = Dart_CObject_kTypedData;
  o.value.as_typed_data.type = Dart_TypedData_kUint8;
  o.value.as_typed_data.length = (intptr_t)len;
  o.value.as_typed_data.values = (const uint8_t *)(p ? p : "");
  return o;
}

static void post(int n, Dart_CObject *items) {
  if (!g_port) return;
  Dart_CObject *ptrs[8];
  Dart_CObject msg;
  for (int i = 0; i < n; ++i) ptrs[i] = &items[i];
  msg.type = Dart_CObject_kArray;
  msg.value.as_array.length = n;
  msg.value.as_array.values = ptrs;
  Dart_PostCObject_DL(g_port, &msg);
}

// ---- 全局监听器（注册进 WFClient::setXxxListener） ----

WFC_EXPORT void WFCAPI wfc_on_connection_status(int status) {
  Dart_CObject a[2] = {c_int(kTagConnectionStatus), c_int(status)};
  post(2, a);
}

WFC_EXPORT void WFCAPI wfc_on_connected(const char *host, size_t host_len,
                                        const char *ip, size_t ip_len,
                                        int nw_type) {
  Dart_CObject a[5] = {c_int(kTagConnectedToServer), c_bytes(host, host_len),
                       c_bytes(ip, ip_len), c_int(0),
                       c_bool(nw_type == 1)};
  post(5, a);
}

WFC_EXPORT void WFCAPI wfc_on_connecting(const char *host, size_t host_len,
                                         const char *ip, size_t ip_len) {
  // connecting 事件暂无业务消费
}

WFC_EXPORT void WFCAPI wfc_on_receive_message(const char *msgs, size_t len,
                                              bool has_more) {
  Dart_CObject a[3] = {c_int(kTagReceiveMessage), c_bytes(msgs, len),
                       c_bool(has_more)};
  post(3, a);
}

WFC_EXPORT void WFCAPI wfc_on_recall_message(const char *op, size_t len,
                                             int64_t message_uid) {
  Dart_CObject a[3] = {c_int(kTagRecallMessage), c_bytes(op, len),
                       c_int(message_uid)};
  post(3, a);
}

WFC_EXPORT void WFCAPI wfc_on_delete_message(int64_t message_uid) {
  Dart_CObject a[2] = {c_int(kTagDeleteMessage), c_int(message_uid)};
  post(2, a);
}

#define GLOBAL_STRING_LISTENER(fn, tag)                                \
  WFC_EXPORT void WFCAPI fn(const char *str, size_t len) {             \
    Dart_CObject a[2] = {c_int(tag), c_bytes(str, len)};               \
    post(2, a);                                                        \
  }

GLOBAL_STRING_LISTENER(wfc_on_userinfo_updated, kTagUserInfoUpdated)
GLOBAL_STRING_LISTENER(wfc_on_groupinfo_updated, kTagGroupInfoUpdated)
GLOBAL_STRING_LISTENER(wfc_on_groupmember_updated, kTagGroupMemberUpdated)
GLOBAL_STRING_LISTENER(wfc_on_friendlist_updated, kTagFriendListUpdated)
GLOBAL_STRING_LISTENER(wfc_on_friendrequest_updated, kTagFriendRequestUpdated)
GLOBAL_STRING_LISTENER(wfc_on_channelinfo_updated, kTagChannelInfoUpdated)
GLOBAL_STRING_LISTENER(wfc_on_message_delivered, kTagMessageDelivered)
GLOBAL_STRING_LISTENER(wfc_on_message_readed, kTagMessageReaded)
GLOBAL_STRING_LISTENER(wfc_on_domain_info_updated, kTagDomainInfoUpdated)
GLOBAL_STRING_LISTENER(wfc_on_online_event_updated, kTagOnlineEventUpdated)

WFC_EXPORT void WFCAPI wfc_on_join_group_request_updated(void) {
  Dart_CObject a[1] = {c_int(kTagJoinGroupRequestUpdated)};
  post(1, a);
}

WFC_EXPORT void WFCAPI wfc_on_setting_updated(void) {
  Dart_CObject a[1] = {c_int(kTagSettingUpdated)};
  post(1, a);
}

// ---- 请求级回调（p_obj 携带 Dart 侧分配的 requestId） ----

WFC_EXPORT void WFCAPI wfc_on_general_void_success(void *p_obj,
                                                   int data_type) {
  Dart_CObject a[2] = {c_int(kTagGeneralVoidSuccess),
                       c_int((int64_t)(intptr_t)p_obj)};
  post(2, a);
}

WFC_EXPORT void WFCAPI wfc_on_general_string_success(void *p_obj,
                                                     int data_type,
                                                     const char *val,
                                                     size_t len) {
  Dart_CObject a[3] = {c_int(kTagGeneralStringSuccess),
                       c_int((int64_t)(intptr_t)p_obj), c_bytes(val, len)};
  post(3, a);
}

WFC_EXPORT void WFCAPI wfc_on_general_error(void *p_obj, int data_type,
                                            int error_code) {
  Dart_CObject a[3] = {c_int(kTagGeneralError),
                       c_int((int64_t)(intptr_t)p_obj), c_int(error_code)};
  post(3, a);
}

WFC_EXPORT void WFCAPI wfc_on_send_message_success(void *p_obj, int data_type,
                                                   long message_id,
                                                   int64_t message_uid,
                                                   int64_t timestamp) {
  Dart_CObject a[5] = {c_int(kTagSendMessageSuccess),
                       c_int((int64_t)(intptr_t)p_obj), c_int(message_id),
                       c_int(message_uid), c_int(timestamp)};
  post(5, a);
}

WFC_EXPORT void WFCAPI wfc_on_send_message_prepared(void *p_obj, int data_type,
                                                    long message_id,
                                                    int64_t save_time) {
  Dart_CObject a[4] = {c_int(kTagSendMessagePrepared),
                       c_int((int64_t)(intptr_t)p_obj), c_int(message_id),
                       c_int(save_time)};
  post(4, a);
}

WFC_EXPORT void WFCAPI wfc_on_send_message_progress(void *p_obj, int data_type,
                                                    long message_id,
                                                    int uploaded, int total) {
  Dart_CObject a[5] = {c_int(kTagSendMessageProgress),
                       c_int((int64_t)(intptr_t)p_obj), c_int(message_id),
                       c_int(uploaded), c_int(total)};
  post(5, a);
}

WFC_EXPORT void WFCAPI wfc_on_send_message_uploaded(void *p_obj, int data_type,
                                                    long message_id,
                                                    const char *remote_url,
                                                    size_t len) {
  Dart_CObject a[4] = {c_int(kTagSendMessageUploaded),
                       c_int((int64_t)(intptr_t)p_obj), c_int(message_id),
                       c_bytes(remote_url, len)};
  post(4, a);
}

WFC_EXPORT void WFCAPI wfc_on_send_message_error(void *p_obj, int data_type,
                                                 long message_id,
                                                 int error_code) {
  Dart_CObject a[4] = {c_int(kTagSendMessageError),
                       c_int((int64_t)(intptr_t)p_obj), c_int(message_id),
                       c_int(error_code)};
  post(4, a);
}

WFC_EXPORT void WFCAPI wfc_on_upload_media_progress(void *p_obj, int data_type,
                                                    int uploaded, int total) {
  Dart_CObject a[4] = {c_int(kTagUploadMediaProgress),
                       c_int((int64_t)(intptr_t)p_obj), c_int(uploaded),
                       c_int(total)};
  post(4, a);
}
