#import "ImclientPlugin.h"

#include <WFClient.h>

#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

#pragma mark - Channel / Dart invocation

static std::mutex g_channel_mutex;
__strong static FlutterMethodChannel *g_channel = nil;

static void SetChannel(FlutterMethodChannel *channel) {
  std::lock_guard<std::mutex> lock(g_channel_mutex);
  g_channel = channel;
}

static void InvokeDartMethod(NSString *method, id arguments) {
  FlutterMethodChannel *channel = nil;
  {
    std::lock_guard<std::mutex> lock(g_channel_mutex);
    channel = g_channel;
  }
  if (!channel) return;

  if (NSThread.isMainThread) {
    [channel invokeMethod:method arguments:arguments];
  } else {
    dispatch_async(dispatch_get_main_queue(), ^{
      [channel invokeMethod:method arguments:arguments];
    });
  }
}

#pragma mark - JSON helpers

static id ObjectFromJsonString(const std::string &json_str) {
  if (json_str.empty()) return nil;
  NSData *data = [NSData dataWithBytes:json_str.data() length:json_str.size()];
  NSError *error = nil;
  id obj = [NSJSONSerialization JSONObjectWithData:data
                                           options:NSJSONReadingAllowFragments
                                             error:&error];
  return obj;
}

static id ReversedArrayIfArray(id value) {
  if ([value isKindOfClass:[NSArray class]]) {
    NSArray *array = value;
    return [[array reverseObjectEnumerator] allObjects];
  }
  return value;
}

static std::string JsonStringFromObject(id obj) {
  if (!obj) return "";
  NSError *error = nil;
  NSData *data = [NSJSONSerialization dataWithJSONObject:obj
                                                 options:0
                                                   error:&error];
  if (!data) return "";
  return std::string((const char *)data.bytes, data.length);
}

#pragma mark - Argument helpers

static NSString *GetNSString(NSDictionary *args, NSString *key, NSString *defaultValue) {
  id value = args[key];
  if ([value isKindOfClass:[NSString class]]) return value;
  return defaultValue;
}

static std::string GetString(NSDictionary *args, NSString *key,
                             const std::string &defaultValue = "") {
  NSString *value = GetNSString(args, key, nil);
  if (value) return [value UTF8String];
  return defaultValue;
}

static int64_t GetInt(NSDictionary *args, NSString *key, int64_t defaultValue = 0) {
  id value = args[key];
  if ([value isKindOfClass:[NSNumber class]]) return [value longLongValue];
  return defaultValue;
}

static bool GetBool(NSDictionary *args, NSString *key, bool defaultValue = false) {
  id value = args[key];
  if ([value isKindOfClass:[NSNumber class]]) return [value boolValue];
  return defaultValue;
}

static std::vector<int> GetIntList(NSDictionary *args, NSString *key) {
  std::vector<int> result;
  id value = args[key];
  if ([value isKindOfClass:[NSArray class]]) {
    for (id item in value) {
      if ([item isKindOfClass:[NSNumber class]]) {
        result.push_back([item intValue]);
      }
    }
  }
  return result;
}

static std::vector<int64_t> GetInt64List(NSDictionary *args, NSString *key) {
  std::vector<int64_t> result;
  id value = args[key];
  if ([value isKindOfClass:[NSArray class]]) {
    for (id item in value) {
      if ([item isKindOfClass:[NSNumber class]]) {
        result.push_back([item longLongValue]);
      }
    }
  }
  return result;
}

static std::vector<std::string> GetStringList(NSDictionary *args, NSString *key) {
  std::vector<std::string> result;
  id value = args[key];
  if ([value isKindOfClass:[NSArray class]]) {
    for (id item in value) {
      if ([item isKindOfClass:[NSString class]]) {
        result.push_back([item UTF8String]);
      }
    }
  }
  return result;
}

static NSDictionary *GetMap(NSDictionary *args, NSString *key) {
  id value = args[key];
  if ([value isKindOfClass:[NSDictionary class]]) return value;
  return nil;
}

#pragma mark - String helpers

static std::string ConvertDllStringAndRelease(const char *str, size_t len) {
  if (!str) return "";
  std::string result(str, len);
  WFClient::releaseDllString(str);
  return result;
}

#pragma mark - Conversation / MessagePayload helpers

struct Conversation {
  int conversation_type;
  std::string target;
  int line;

  Conversation(NSDictionary *map) : conversation_type(0), line(0) {
    if (!map) return;
    // Dart 端大多数接口把 conversation 作为嵌套 map 传递；兼容顶层字段。
    NSDictionary *conv = GetMap(map, @"conversation");
    NSDictionary *source = conv ?: map;
    conversation_type = static_cast<int>(GetInt(source, @"type"));
    target = GetString(source, @"target");
    line = static_cast<int>(GetInt(source, @"line"));
  }
};

struct MessagePayload {
  int content_type;
  std::string searchable_content;
  std::string push_content;
  std::string push_data;
  std::string content;
  std::vector<uint8_t> binary_content;
  std::string local_content;
  std::string remote_media_url;
  std::string local_media_path;
  int media_type;
  int mentioned_type;
  std::vector<std::string> mentioned_targets;
  std::string extra;

  MessagePayload(NSDictionary *map)
      : content_type(0), media_type(0), mentioned_type(0) {
    if (!map) return;
    content_type = static_cast<int>(GetInt(map, @"type"));
    searchable_content = GetString(map, @"searchableContent");
    push_content = GetString(map, @"pushContent");
    push_data = GetString(map, @"pushData");
    content = GetString(map, @"content");
    local_content = GetString(map, @"localContent");
    remote_media_url = GetString(map, @"remoteMediaUrl");
    local_media_path = GetString(map, @"localMediaPath");
    media_type = static_cast<int>(GetInt(map, @"mediaType"));
    mentioned_type = static_cast<int>(GetInt(map, @"mentionedType"));
    extra = GetString(map, @"extra");

    id binary_value = map[@"binaryContent"];
    NSData *data = nil;
    if ([binary_value isKindOfClass:[FlutterStandardTypedData class]]) {
      data = [binary_value data];
    } else if ([binary_value isKindOfClass:[NSData class]]) {
      data = binary_value;
    } else if ([binary_value isKindOfClass:[NSString class]]) {
      data = [[NSData alloc] initWithBase64EncodedString:binary_value options:0];
    }
    if (data) {
      binary_content.assign((const uint8_t *)data.bytes,
                            (const uint8_t *)data.bytes + data.length);
    }

    mentioned_targets = GetStringList(map, @"mentionedTargets");
  }

  NSDictionary *ToDictionary() const {
    NSMutableDictionary *map = [NSMutableDictionary dictionary];
    map[@"type"] = @(content_type);
    map[@"searchableContent"] = [NSString stringWithUTF8String:searchable_content.c_str()];
    map[@"pushContent"] = [NSString stringWithUTF8String:push_content.c_str()];
    map[@"pushData"] = [NSString stringWithUTF8String:push_data.c_str()];
    map[@"content"] = [NSString stringWithUTF8String:content.c_str()];
    if (!binary_content.empty()) {
      NSData *data = [NSData dataWithBytes:binary_content.data()
                                    length:binary_content.size()];
      map[@"binaryContent"] = [data base64EncodedStringWithOptions:0];
    } else {
      map[@"binaryContent"] = @"";
    }
    map[@"localContent"] = [NSString stringWithUTF8String:local_content.c_str()];
    map[@"remoteMediaUrl"] = [NSString stringWithUTF8String:remote_media_url.c_str()];
    map[@"localMediaPath"] = [NSString stringWithUTF8String:local_media_path.c_str()];
    map[@"mediaType"] = @(media_type);
    map[@"mentionedType"] = @(mentioned_type);
    NSMutableArray *targets = [NSMutableArray array];
    for (const auto &t : mentioned_targets) {
      [targets addObject:[NSString stringWithUTF8String:t.c_str()]];
    }
    map[@"mentionedTargets"] = targets;
    map[@"extra"] = [NSString stringWithUTF8String:extra.c_str()];
    return map;
  }
};

static std::string BuildNotifyContentJson(NSDictionary *args) {
  NSDictionary *notify_map = GetMap(args, @"notifyContent");
  if (!notify_map) return "";
  MessagePayload payload(notify_map);
  return JsonStringFromObject(payload.ToDictionary());
}

#pragma mark - C SDK global callbacks

#ifdef WIN32
#define WFCAPI __stdcall
#else
#define WFCAPI
#endif

static void WFCAPI OnConnectionStatusChanged(int connection_status) {
  InvokeDartMethod(@"onConnectionStatusChanged", @(connection_status));
}

static void WFCAPI OnReceiveMessage(const char *cmessages, size_t messages_len,
                                    bool more_msg) {
  std::string json_str(cmessages, messages_len);
  id value = ObjectFromJsonString(json_str);
  NSArray *messages = nil;
  if ([value isKindOfClass:[NSArray class]]) {
    messages = value;
  } else {
    messages = @[];
  }
  InvokeDartMethod(@"onReceiveMessage",
                   @{@"hasMore": @(more_msg), @"messages": messages});
}

static void WFCAPI OnRecallMessage(const char *coperator_id,
                                   size_t operator_id_len,
                                   int64_t message_uid) {
  std::string op(coperator_id, operator_id_len);
  InvokeDartMethod(@"onRecallMessage",
                   @{@"operator": [NSString stringWithUTF8String:op.c_str()],
                     @"messageUid": @(message_uid)});
}

static void WFCAPI OnDeleteMessage(int64_t message_uid) {
  InvokeDartMethod(@"onDeleteMessage", @{@"messageUid": @(message_uid)});
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
  id value = ObjectFromJsonString(json_str);
  NSArray *users = nil;
  if ([value isKindOfClass:[NSArray class]]) {
    users = value;
  } else {
    users = @[];
  }
  InvokeDartMethod(@"onUserInfoUpdated", @{@"users": users});
}

static void WFCAPI OnGroupInfoUpdated(const char *cgroup_infos,
                                      size_t group_infos_len) {
  std::string json_str(cgroup_infos, group_infos_len);
  id value = ObjectFromJsonString(json_str);
  NSArray *groups = nil;
  if ([value isKindOfClass:[NSArray class]]) {
    groups = value;
  } else {
    groups = @[];
  }
  InvokeDartMethod(@"onGroupInfoUpdated", @{@"groups": groups});
}

static void WFCAPI OnGroupMemberUpdated(const char *cgroup_id,
                                        size_t group_id_len) {
  std::string group_id(cgroup_id, group_id_len);
  InvokeDartMethod(@"onGroupMemberUpdated",
                   @{@"groupId": [NSString stringWithUTF8String:group_id.c_str()],
                     @"members": @[]});
}

static void WFCAPI OnFriendListUpdated(const char *cfriend_list,
                                       size_t friend_list_len) {
  std::string json_str(cfriend_list, friend_list_len);
  id value = ObjectFromJsonString(json_str);
  NSArray *friends = nil;
  if ([value isKindOfClass:[NSArray class]]) {
    friends = value;
  } else {
    friends = @[];
  }
  InvokeDartMethod(@"onFriendListUpdated", @{@"friends": friends});
}

static void WFCAPI OnFriendRequestUpdated(const char *crequests,
                                          size_t requests_len) {
  std::string json_str(crequests, requests_len);
  id value = ObjectFromJsonString(json_str);
  NSArray *requests = nil;
  if ([value isKindOfClass:[NSArray class]]) {
    requests = value;
  } else {
    requests = @[];
  }
  InvokeDartMethod(@"onFriendRequestUpdated", @{@"requests": requests});
}

static void WFCAPI OnSettingUpdated() {
  InvokeDartMethod(@"onSettingUpdated", nil);
}

static void WFCAPI OnChannelInfoUpdated(const char *cchannel_info,
                                        size_t channel_info_len) {
  std::string json_str(cchannel_info, channel_info_len);
  id value = ObjectFromJsonString(json_str);
  NSArray *channels = nil;
  if ([value isKindOfClass:[NSArray class]]) {
    channels = value;
  } else {
    channels = @[];
  }
  InvokeDartMethod(@"onChannelInfoUpdated", @{@"channels": channels});
}

#pragma mark - Generic async callbacks

static void WFCAPI OnGeneralVoidSuccess(void *p_obj, int data_type) {
  int64_t request_id = reinterpret_cast<int64_t>(p_obj);
  InvokeDartMethod(@"onOperationVoidSuccess",
                   @{@"requestId": @(request_id)});
}

static void WFCAPI OnGeneralError(void *p_obj, int data_type,
                                  int error_code) {
  int64_t request_id = reinterpret_cast<int64_t>(p_obj);
  InvokeDartMethod(@"onOperationFailure",
                   @{@"requestId": @(request_id),
                     @"errorCode": @(error_code)});
}

static void WFCAPI OnGeneralStringSuccess(void *p_obj, int data_type,
                                          const char *cval, size_t val_len) {
  int64_t request_id = reinterpret_cast<int64_t>(p_obj);
  std::string json_str(cval, val_len);
  id data = ObjectFromJsonString(json_str);
  InvokeDartMethod(@"onOperationStringSuccess",
                   @{@"requestId": @(request_id),
                     @"data": data ?: [NSNull null]});
}

static void WFCAPI OnGetUploadUrlSuccess(void *p_obj, int data_type,
                                         const char *cval, size_t val_len) {
  int64_t request_id = reinterpret_cast<int64_t>(p_obj);
  std::string json_str(cval, val_len);
  id value = ObjectFromJsonString(json_str);
  NSDictionary *dict = nil;
  if ([value isKindOfClass:[NSDictionary class]]) {
    dict = value;
  } else {
    dict = @{};
  }
  InvokeDartMethod(@"onGetUploadUrl",
                   @{@"requestId": @(request_id),
                     @"uploadUrl": dict[@"uploadUrl"] ?: @"",
                     @"downloadUrl": dict[@"downloadUrl"] ?: @"",
                     @"backupUploadUrl": dict[@"backupUploadUrl"] ?: @"",
                     @"type": dict[@"type"] ?: @(0)});
}

static void WFCAPI OnWatchOnlineStateSuccess(void *p_obj, int data_type,
                                             const char *cval, size_t val_len) {
  int64_t request_id = reinterpret_cast<int64_t>(p_obj);
  std::string json_str(cval, val_len);
  id value = ObjectFromJsonString(json_str);
  NSArray *states = nil;
  if ([value isKindOfClass:[NSArray class]]) {
    states = value;
  } else {
    states = @[];
  }
  InvokeDartMethod(@"onWatchOnlineStateSuccess",
                   @{@"requestId": @(request_id),
                     @"states": states});
}

static void WFCAPI OnSendMessageSuccess(void *p_obj, int data_type,
                                        long message_id, int64_t message_uid,
                                        int64_t timestamp) {
  int64_t request_id = reinterpret_cast<int64_t>(p_obj);
  InvokeDartMethod(@"onSendMessageSuccess",
                   @{@"requestId": @(request_id),
                     @"messageId": @(static_cast<int64_t>(message_id)),
                     @"messageUid": @(message_uid),
                     @"timestamp": @(timestamp)});
}

static void WFCAPI OnSendMessagePrepared(void *p_obj, int data_type,
                                         long message_id, int64_t save_time) {
  // PC SDK has no prepared distribution; ignore for now.
}

static void WFCAPI OnSendMessageProgress(void *p_obj, int data_type,
                                         long message_id, int uploaded,
                                         int total) {
  int64_t request_id = reinterpret_cast<int64_t>(p_obj);
  InvokeDartMethod(@"onSendMediaMessageProgress",
                   @{@"requestId": @(request_id),
                     @"messageId": @(static_cast<int64_t>(message_id)),
                     @"uploaded": @(uploaded),
                     @"total": @(total)});
}

static void WFCAPI OnSendMessageMediaUploaded(void *p_obj, int data_type,
                                              long message_id,
                                              const char *cremote_url,
                                              size_t remote_url_len) {
  int64_t request_id = reinterpret_cast<int64_t>(p_obj);
  std::string remote_url(cremote_url, remote_url_len);
  InvokeDartMethod(@"onSendMediaMessageUploaded",
                   @{@"requestId": @(request_id),
                     @"messageId": @(static_cast<int64_t>(message_id)),
                     @"remoteUrl": [NSString stringWithUTF8String:remote_url.c_str()]});
}

static void WFCAPI OnSendMessageError(void *p_obj, int data_type,
                                      long message_id, int error_code) {
  int64_t request_id = reinterpret_cast<int64_t>(p_obj);
  InvokeDartMethod(@"onSendMessageFailure",
                   @{@"requestId": @(request_id),
                     @"messageId": @(static_cast<int64_t>(message_id)),
                     @"errorCode": @(error_code)});
}

#pragma mark - Specialized async callbacks

static void WFCAPI OnGetRemoteMessagesSuccess(void *p_obj, int data_type,
                                              const char *cval,
                                              size_t val_len) {
  int64_t request_id = reinterpret_cast<int64_t>(p_obj);
  std::string json_str(cval, val_len);
  id value = ObjectFromJsonString(json_str);
  NSArray *messages = nil;
  if ([value isKindOfClass:[NSArray class]]) {
    messages = value;
  } else {
    messages = @[];
  }
  InvokeDartMethod(@"onMessagesCallback",
                   @{@"requestId": @(request_id),
                     @"messages": messages});
}

static void WFCAPI OnGetRemoteMessagesError(void *p_obj, int data_type,
                                            int error_code) {
  OnGeneralError(p_obj, data_type, error_code);
}

static void WFCAPI OnSearchUserSuccess(void *p_obj, int data_type,
                                       const char *cval, size_t val_len) {
  int64_t request_id = reinterpret_cast<int64_t>(p_obj);
  std::string json_str(cval, val_len);
  id value = ObjectFromJsonString(json_str);
  NSArray *users = nil;
  if ([value isKindOfClass:[NSArray class]]) {
    users = value;
  } else {
    users = @[];
  }
  InvokeDartMethod(@"onSearchUserResult",
                   @{@"requestId": @(request_id),
                     @"users": users});
}

static void WFCAPI OnChatroomInfoSuccess(void *p_obj, int data_type,
                                         const char *cval, size_t val_len) {
  int64_t request_id = reinterpret_cast<int64_t>(p_obj);
  std::string json_str(cval, val_len);
  id chatroom_info = ObjectFromJsonString(json_str);
  InvokeDartMethod(@"onGetChatroomInfoResult",
                   @{@"requestId": @(request_id),
                     @"chatroomInfo": chatroom_info ?: [NSNull null]});
}

static void WFCAPI OnChatroomMemberInfoSuccess(void *p_obj, int data_type,
                                               const char *cval,
                                               size_t val_len) {
  int64_t request_id = reinterpret_cast<int64_t>(p_obj);
  std::string json_str(cval, val_len);
  id member_info = ObjectFromJsonString(json_str);
  InvokeDartMethod(@"onGetChatroomMemberInfoResult",
                   @{@"requestId": @(request_id),
                     @"chatroomMemberInfo": member_info ?: [NSNull null]});
}

static void WFCAPI OnCreateChannelSuccess(void *p_obj, int data_type,
                                          const char *cval, size_t val_len) {
  int64_t request_id = reinterpret_cast<int64_t>(p_obj);
  std::string json_str(cval, val_len);
  id value = ObjectFromJsonString(json_str);
  NSDictionary *channel_info = nil;
  if ([value isKindOfClass:[NSDictionary class]]) {
    channel_info = value;
  } else if ([value isKindOfClass:[NSString class]]) {
    channel_info = @{@"channelId": value};
  } else {
    NSString *fallback = [NSString stringWithUTF8String:json_str.c_str()];
    channel_info = @{@"channelId": fallback ?: @""};
  }
  InvokeDartMethod(@"onCreateChannelSuccess",
                   @{@"requestId": @(request_id),
                     @"channelInfo": channel_info});
}

static void WFCAPI OnSearchChannelSuccess(void *p_obj, int data_type,
                                          const char *cval, size_t val_len) {
  int64_t request_id = reinterpret_cast<int64_t>(p_obj);
  std::string json_str(cval, val_len);
  id value = ObjectFromJsonString(json_str);
  NSArray *channels = nil;
  if ([value isKindOfClass:[NSArray class]]) {
    channels = value;
  } else {
    channels = @[];
  }
  InvokeDartMethod(@"onSearchChannelResult",
                   @{@"requestId": @(request_id),
                     @"channelInfos": channels});
}

static void WFCAPI OnFilesResult(void *p_obj, int data_type,
                                 const char *cval, size_t val_len) {
  int64_t request_id = reinterpret_cast<int64_t>(p_obj);
  std::string json_str(cval, val_len);
  id value = ObjectFromJsonString(json_str);
  NSArray *files = nil;
  if ([value isKindOfClass:[NSArray class]]) {
    files = value;
  } else {
    files = @[];
  }
  InvokeDartMethod(@"onFilesResult",
                   @{@"requestId": @(request_id),
                     @"files": files});
}

#pragma mark - Method handlers

@interface ImclientPlugin ()
@property(nonatomic, strong) FlutterMethodChannel *channel;
@end

@implementation ImclientPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  FlutterMethodChannel *channel =
      [FlutterMethodChannel methodChannelWithName:@"imclient"
                                  binaryMessenger:[registrar messenger]];

  ImclientPlugin *plugin = [[ImclientPlugin alloc] init];
  [channel setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
    [plugin handleMethodCall:call result:result];
  }];

  plugin.channel = channel;
  SetChannel(channel);

  // fluttertoast 没有 macOS 桌面端实现，注册一个空实现避免 MissingPluginException。
  FlutterMethodChannel *toastChannel =
      [FlutterMethodChannel methodChannelWithName:@"PonnamKarthik/fluttertoast"
                                  binaryMessenger:[registrar messenger]];
  [toastChannel setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
    result(nil);
  }];

  [registrar publish:plugin];
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  NSDictionary *args = call.arguments;
  if (![args isKindOfClass:[NSDictionary class]]) {
    args = @{};
  }

  NSString *method = call.method;
  if ([method isEqualToString:@"initProto"]) {
    [self handleInitProto:args result:result];
  } else if ([method isEqualToString:@"getClientId"]) {
    [self handleGetClientId:args result:result];
  } else if ([method isEqualToString:@"currentUserId"]) {
    [self handleCurrentUserId:args result:result];
  } else if ([method isEqualToString:@"getProtoRevision"]) {
    [self handleGetProtoRevision:args result:result];
  } else if ([method isEqualToString:@"connect"]) {
    [self handleConnect:args result:result];
  } else if ([method isEqualToString:@"disconnect"]) {
    [self handleDisconnect:args result:result];
  } else if ([method isEqualToString:@"connectionStatus"]) {
    [self handleConnectionStatus:args result:result];
  } else if ([method isEqualToString:@"isLogined"]) {
    [self handleIsLogined:args result:result];
  } else if ([method isEqualToString:@"serverDeltaTime"]) {
    [self handleServerDeltaTime:args result:result];
  } else if ([method isEqualToString:@"setBackupAddress"]) {
    [self handleSetBackupAddress:args result:result];
  } else if ([method isEqualToString:@"useSM4"]) {
    [self handleUseSM4:args result:result];
  } else if ([method isEqualToString:@"setLiteMode"]) {
    [self handleSetLiteMode:args result:result];
  } else if ([method isEqualToString:@"setBackupAddressStrategy"]) {
    [self handleSetBackupAddressStrategy:args result:result];
  } else if ([method isEqualToString:@"setProtoUserAgent"]) {
    [self handleSetProtoUserAgent:args result:result];
  } else if ([method isEqualToString:@"addHttpHeader"]) {
    [self handleAddHttpHeader:args result:result];
  } else if ([method isEqualToString:@"setProxyInfo"]) {
    [self handleSetProxyInfo:args result:result];
  } else if ([method isEqualToString:@"registerMessage"]) {
    [self handleRegisterMessage:args result:result];
  } else if ([method isEqualToString:@"getConversationInfos"]) {
    [self handleGetConversationInfos:args result:result];
  } else if ([method isEqualToString:@"getConversationInfo"]) {
    [self handleGetConversationInfo:args result:result];
  } else if ([method isEqualToString:@"searchConversation"]) {
    [self handleSearchConversation:args result:result];
  } else if ([method isEqualToString:@"removeConversation"]) {
    [self handleRemoveConversation:args result:result];
  } else if ([method isEqualToString:@"setConversationTop"]) {
    [self handleSetConversationTop:args result:result];
  } else if ([method isEqualToString:@"setConversationSilent"]) {
    [self handleSetConversationSilent:args result:result];
  } else if ([method isEqualToString:@"setConversationDraft"]) {
    [self handleSetConversationDraft:args result:result];
  } else if ([method isEqualToString:@"setConversationTimestamp"]) {
    [self handleSetConversationTimestamp:args result:result];
  } else if ([method isEqualToString:@"getFirstUnreadMessageId"]) {
    [self handleGetFirstUnreadMessageId:args result:result];
  } else if ([method isEqualToString:@"getConversationUnreadCount"]) {
    [self handleGetConversationUnreadCount:args result:result];
  } else if ([method isEqualToString:@"getConversationsUnreadCount"]) {
    [self handleGetConversationsUnreadCount:args result:result];
  } else if ([method isEqualToString:@"clearConversationUnreadStatus"]) {
    [self handleClearConversationUnreadStatus:args result:result];
  } else if ([method isEqualToString:@"clearConversationsUnreadStatus"]) {
    [self handleClearConversationsUnreadStatus:args result:result];
  } else if ([method isEqualToString:@"clearAllUnreadStatus"]) {
    [self handleClearAllUnreadStatus:args result:result];
  } else if ([method isEqualToString:@"clearMessageUnreadStatus"]) {
    [self handleClearMessageUnreadStatus:args result:result];
  } else if ([method isEqualToString:@"clearMessageUnreadStatusBefore"]) {
    [self handleClearMessageUnreadStatusBefore:args result:result];
  } else if ([method isEqualToString:@"markAsUnRead"]) {
    [self handleMarkAsUnRead:args result:result];
  } else if ([method isEqualToString:@"getConversationRead"]) {
    [self handleGetConversationRead:args result:result];
  } else if ([method isEqualToString:@"getMessageDelivery"]) {
    [self handleGetMessageDelivery:args result:result];
  } else if ([method isEqualToString:@"getMessages"]) {
    [self handleGetMessages:args result:result];
  } else if ([method isEqualToString:@"getMessagesByStatus"]) {
    [self handleGetMessagesByStatus:args result:result];
  } else if ([method isEqualToString:@"getConversationsMessages"]) {
    [self handleGetConversationsMessages:args result:result];
  } else if ([method isEqualToString:@"getConversationsMessageByStatus"]) {
    [self handleGetConversationsMessageByStatus:args result:result];
  } else if ([method isEqualToString:@"getRemoteMessages"]) {
    [self handleGetRemoteMessages:args result:result];
  } else if ([method isEqualToString:@"getRemoteMessage"]) {
    [self handleGetRemoteMessage:args result:result];
  } else if ([method isEqualToString:@"getMessage"]) {
    [self handleGetMessage:args result:result];
  } else if ([method isEqualToString:@"getMessageByUid"]) {
    [self handleGetMessageByUid:args result:result];
  } else if ([method isEqualToString:@"searchMessages"]) {
    [self handleSearchMessages:args result:result];
  } else if ([method isEqualToString:@"searchConversationsMessages"]) {
    [self handleSearchConversationsMessages:args result:result];
  } else if ([method isEqualToString:@"sendMessage"]) {
    [self handleSendMessage:args result:result];
  } else if ([method isEqualToString:@"sendSavedMessage"]) {
    [self handleSendSavedMessage:args result:result];
  } else if ([method isEqualToString:@"cancelSendingMessage"]) {
    [self handleCancelSendingMessage:args result:result];
  } else if ([method isEqualToString:@"recallMessage"]) {
    [self handleRecallMessage:args result:result];
  } else if ([method isEqualToString:@"uploadMedia"]) {
    [self handleUploadMedia:args result:result];
  } else if ([method isEqualToString:@"uploadMediaFile"]) {
    [self handleUploadMediaFile:args result:result];
  } else if ([method isEqualToString:@"getUploadUrl"]) {
    [self handleGetUploadUrl:args result:result];
  } else if ([method isEqualToString:@"getMediaUploadUrl"]) {
    [self handleGetMediaUploadUrl:args result:result];
  } else if ([method isEqualToString:@"isSupportBigFilesUpload"]) {
    [self handleIsSupportBigFilesUpload:args result:result];
  } else if ([method isEqualToString:@"deleteMessage"]) {
    [self handleDeleteMessage:args result:result];
  } else if ([method isEqualToString:@"batchDeleteMessages"]) {
    [self handleBatchDeleteMessages:args result:result];
  } else if ([method isEqualToString:@"deleteRemoteMessage"]) {
    [self handleDeleteRemoteMessage:args result:result];
  } else if ([method isEqualToString:@"clearMessages"]) {
    [self handleClearMessages:args result:result];
  } else if ([method isEqualToString:@"clearMessagesKeepLatest"]) {
    [self handleClearMessagesKeepLatest:args result:result];
  } else if ([method isEqualToString:@"clearRemoteConversationMessage"]) {
    [self handleClearRemoteConversationMessage:args result:result];
  } else if ([method isEqualToString:@"setMediaMessagePlayed"]) {
    [self handleSetMediaMessagePlayed:args result:result];
  } else if ([method isEqualToString:@"setMessageLocalExtra"]) {
    [self handleSetMessageLocalExtra:args result:result];
  } else if ([method isEqualToString:@"insertMessage"]) {
    [self handleInsertMessage:args result:result];
  } else if ([method isEqualToString:@"updateMessage"]) {
    [self handleUpdateMessage:args result:result];
  } else if ([method isEqualToString:@"updateRemoteMessageContent"]) {
    [self handleUpdateRemoteMessageContent:args result:result];
  } else if ([method isEqualToString:@"updateMessageStatus"]) {
    [self handleUpdateMessageStatus:args result:result];
  } else if ([method isEqualToString:@"getMessageCount"]) {
    [self handleGetMessageCount:args result:result];
  } else if ([method isEqualToString:@"getAuthorizedMediaUrl"]) {
    [self handleGetAuthorizedMediaUrl:args result:result];
  } else if ([method isEqualToString:@"startLog"]) {
    [self handleStartLog:args result:result];
  } else if ([method isEqualToString:@"stopLog"]) {
    [self handleStopLog:args result:result];
  } else if ([method isEqualToString:@"setSendLogCommand"]) {
    [self handleSetSendLogCommand:args result:result];
  } else if ([method isEqualToString:@"getLogFilesPath"]) {
    [self handleGetLogFilesPath:args result:result];
  } else if ([method isEqualToString:@"setDeviceToken"]) {
    [self handleSetDeviceToken:args result:result];
  } else if ([method isEqualToString:@"setVoipDeviceToken"]) {
    [self handleSetVoipDeviceToken:args result:result];
  } else if ([method isEqualToString:@"getUserInfo"]) {
    [self handleGetUserInfo:args result:result];
  } else if ([method isEqualToString:@"getUserInfos"]) {
    [self handleGetUserInfos:args result:result];
  } else if ([method isEqualToString:@"searchUser"]) {
    [self handleSearchUser:args result:result];
  } else if ([method isEqualToString:@"getUserInfoAsync"]) {
    [self handleGetUserInfoAsync:args result:result];
  } else if ([method isEqualToString:@"isMyFriend"]) {
    [self handleIsMyFriend:args result:result];
  } else if ([method isEqualToString:@"getMyFriendList"]) {
    [self handleGetMyFriendList:args result:result];
  } else if ([method isEqualToString:@"searchFriends"]) {
    [self handleSearchFriends:args result:result];
  } else if ([method isEqualToString:@"getFriends"]) {
    [self handleGetFriends:args result:result];
  } else if ([method isEqualToString:@"searchGroups"]) {
    [self handleSearchGroups:args result:result];
  } else if ([method isEqualToString:@"getIncommingFriendRequest"]) {
    [self handleGetIncommingFriendRequest:args result:result];
  } else if ([method isEqualToString:@"getOutgoingFriendRequest"]) {
    [self handleGetOutgoingFriendRequest:args result:result];
  } else if ([method isEqualToString:@"getFriendRequest"]) {
    [self handleGetFriendRequest:args result:result];
  } else if ([method isEqualToString:@"loadFriendRequestFromRemote"]) {
    [self handleLoadFriendRequestFromRemote:args result:result];
  } else if ([method isEqualToString:@"getUnreadFriendRequestStatus"]) {
    [self handleGetUnreadFriendRequestStatus:args result:result];
  } else if ([method isEqualToString:@"clearUnreadFriendRequestStatus"]) {
    [self handleClearUnreadFriendRequestStatus:args result:result];
  } else if ([method isEqualToString:@"clearFriendRequest"]) {
    [self handleClearFriendRequest:args result:result];
  } else if ([method isEqualToString:@"deleteFriendRequest"]) {
    [self handleDeleteFriendRequest:args result:result];
  } else if ([method isEqualToString:@"deleteFriend"]) {
    [self handleDeleteFriend:args result:result];
  } else if ([method isEqualToString:@"getFriendAlias"]) {
    [self handleGetFriendAlias:args result:result];
  } else if ([method isEqualToString:@"setFriendAlias"]) {
    [self handleSetFriendAlias:args result:result];
  } else if ([method isEqualToString:@"getFriendExtra"]) {
    [self handleGetFriendExtra:args result:result];
  } else if ([method isEqualToString:@"sendFriendRequest"]) {
    [self handleSendFriendRequest:args result:result];
  } else if ([method isEqualToString:@"handleFriendRequest"]) {
    [self handleHandleFriendRequest:args result:result];
  } else if ([method isEqualToString:@"isBlackListed"]) {
    [self handleIsBlackListed:args result:result];
  } else if ([method isEqualToString:@"getBlackList"]) {
    [self handleGetBlackList:args result:result];
  } else if ([method isEqualToString:@"setBlackList"]) {
    [self handleSetBlackList:args result:result];
  } else if ([method isEqualToString:@"getGroupMembers"]) {
    [self handleGetGroupMembers:args result:result];
  } else if ([method isEqualToString:@"getGroupMembersByCount"]) {
    [self handleGetGroupMembersByCount:args result:result];
  } else if ([method isEqualToString:@"getGroupMembersByTypes"]) {
    [self handleGetGroupMembersByTypes:args result:result];
  } else if ([method isEqualToString:@"getGroupMembersAsync"]) {
    [self handleGetGroupMembersAsync:args result:result];
  } else if ([method isEqualToString:@"getGroupInfo"]) {
    [self handleGetGroupInfo:args result:result];
  } else if ([method isEqualToString:@"getGroupInfos"]) {
    [self handleGetGroupInfos:args result:result];
  } else if ([method isEqualToString:@"getGroupInfoAsync"]) {
    [self handleGetGroupInfoAsync:args result:result];
  } else if ([method isEqualToString:@"getGroupMember"]) {
    [self handleGetGroupMember:args result:result];
  } else if ([method isEqualToString:@"createGroup"]) {
    [self handleCreateGroup:args result:result];
  } else if ([method isEqualToString:@"addGroupMembers"]) {
    [self handleAddGroupMembers:args result:result];
  } else if ([method isEqualToString:@"kickoffGroupMembers"]) {
    [self handleKickoffGroupMembers:args result:result];
  } else if ([method isEqualToString:@"quitGroup"]) {
    [self handleQuitGroup:args result:result];
  } else if ([method isEqualToString:@"quitGroupEx"]) {
    [self handleQuitGroupEx:args result:result];
  } else if ([method isEqualToString:@"dismissGroup"]) {
    [self handleDismissGroup:args result:result];
  } else if ([method isEqualToString:@"modifyGroupInfo"]) {
    [self handleModifyGroupInfo:args result:result];
  } else if ([method isEqualToString:@"modifyGroupAlias"]) {
    [self handleModifyGroupAlias:args result:result];
  } else if ([method isEqualToString:@"modifyGroupMemberAlias"]) {
    [self handleModifyGroupMemberAlias:args result:result];
  } else if ([method isEqualToString:@"transferGroup"]) {
    [self handleTransferGroup:args result:result];
  } else if ([method isEqualToString:@"setGroupManager"]) {
    [self handleSetGroupManager:args result:result];
  } else if ([method isEqualToString:@"muteGroupMember"]) {
    [self handleMuteGroupMember:args result:result];
  } else if ([method isEqualToString:@"allowGroupMember"]) {
    [self handleAllowGroupMember:args result:result];
  } else if ([method isEqualToString:@"getGroupRemark"]) {
    [self handleGetGroupRemark:args result:result];
  } else if ([method isEqualToString:@"setGroupRemark"]) {
    [self handleSetGroupRemark:args result:result];
  } else if ([method isEqualToString:@"getFavGroups"]) {
    [self handleGetFavGroups:args result:result];
  } else if ([method isEqualToString:@"isFavGroup"]) {
    [self handleIsFavGroup:args result:result];
  } else if ([method isEqualToString:@"setFavGroup"]) {
    [self handleSetFavGroup:args result:result];
  } else if ([method isEqualToString:@"getUserSetting"]) {
    [self handleGetUserSetting:args result:result];
  } else if ([method isEqualToString:@"getUserSettings"]) {
    [self handleGetUserSettings:args result:result];
  } else if ([method isEqualToString:@"setUserSetting"]) {
    [self handleSetUserSetting:args result:result];
  } else if ([method isEqualToString:@"modifyMyInfo"]) {
    [self handleModifyMyInfo:args result:result];
  } else if ([method isEqualToString:@"isGlobalSilent"]) {
    [self handleIsGlobalSilent:args result:result];
  } else if ([method isEqualToString:@"setGlobalSilent"]) {
    [self handleSetGlobalSilent:args result:result];
  } else if ([method isEqualToString:@"isVoipNotificationSilent"]) {
    [self handleIsVoipNotificationSilent:args result:result];
  } else if ([method isEqualToString:@"setVoipNotificationSilent"]) {
    [self handleSetVoipNotificationSilent:args result:result];
  } else if ([method isEqualToString:@"isEnableSyncDraft"]) {
    [self handleIsEnableSyncDraft:args result:result];
  } else if ([method isEqualToString:@"setEnableSyncDraft"]) {
    [self handleSetEnableSyncDraft:args result:result];
  } else if ([method isEqualToString:@"getNoDisturbingTimes"]) {
    [self handleGetNoDisturbingTimes:args result:result];
  } else if ([method isEqualToString:@"setNoDisturbingTimes"]) {
    [self handleSetNoDisturbingTimes:args result:result];
  } else if ([method isEqualToString:@"clearNoDisturbingTimes"]) {
    [self handleClearNoDisturbingTimes:args result:result];
  } else if ([method isEqualToString:@"isNoDisturbing"]) {
    [self handleIsNoDisturbing:args result:result];
  } else if ([method isEqualToString:@"isHiddenNotificationDetail"]) {
    [self handleIsHiddenNotificationDetail:args result:result];
  } else if ([method isEqualToString:@"setHiddenNotificationDetail"]) {
    [self handleSetHiddenNotificationDetail:args result:result];
  } else if ([method isEqualToString:@"isHiddenGroupMemberName"]) {
    [self handleIsHiddenGroupMemberName:args result:result];
  } else if ([method isEqualToString:@"setHiddenGroupMemberName"]) {
    [self handleSetHiddenGroupMemberName:args result:result];
  } else if ([method isEqualToString:@"getMyGroups"]) {
    [self handleGetMyGroups:args result:result];
  } else if ([method isEqualToString:@"getCommonGroups"]) {
    [self handleGetCommonGroups:args result:result];
  } else if ([method isEqualToString:@"isUserEnableReceipt"]) {
    [self handleIsUserEnableReceipt:args result:result];
  } else if ([method isEqualToString:@"setUserEnableReceipt"]) {
    [self handleSetUserEnableReceipt:args result:result];
  } else if ([method isEqualToString:@"getFavUsers"]) {
    [self handleGetFavUsers:args result:result];
  } else if ([method isEqualToString:@"isFavUser"]) {
    [self handleIsFavUser:args result:result];
  } else if ([method isEqualToString:@"setFavUser"]) {
    [self handleSetFavUser:args result:result];
  } else if ([method isEqualToString:@"joinChatroom"]) {
    [self handleJoinChatroom:args result:result];
  } else if ([method isEqualToString:@"quitChatroom"]) {
    [self handleQuitChatroom:args result:result];
  } else if ([method isEqualToString:@"getChatroomInfo"]) {
    [self handleGetChatroomInfo:args result:result];
  } else if ([method isEqualToString:@"getChatroomMemberInfo"]) {
    [self handleGetChatroomMemberInfo:args result:result];
  } else if ([method isEqualToString:@"getJoinedChatroomId"]) {
    [self handleGetJoinedChatroomId:args result:result];
  } else if ([method isEqualToString:@"createChannel"]) {
    [self handleCreateChannel:args result:result];
  } else if ([method isEqualToString:@"getChannelInfo"]) {
    [self handleGetChannelInfo:args result:result];
  } else if ([method isEqualToString:@"modifyChannelInfo"]) {
    [self handleModifyChannelInfo:args result:result];
  } else if ([method isEqualToString:@"searchChannel"]) {
    [self handleSearchChannel:args result:result];
  } else if ([method isEqualToString:@"isListenedChannel"]) {
    [self handleIsListenedChannel:args result:result];
  } else if ([method isEqualToString:@"listenChannel"]) {
    [self handleListenChannel:args result:result];
  } else if ([method isEqualToString:@"getMyChannels"]) {
    [self handleGetMyChannels:args result:result];
  } else if ([method isEqualToString:@"getRemoteListenedChannels"]) {
    [self handleGetRemoteListenedChannels:args result:result];
  } else if ([method isEqualToString:@"destroyChannel"]) {
    [self handleDestroyChannel:args result:result];
  } else if ([method isEqualToString:@"getOnlineInfos"]) {
    [self handleGetOnlineInfos:args result:result];
  } else if ([method isEqualToString:@"kickoffPCClient"]) {
    [self handleKickoffPCClient:args result:result];
  } else if ([method isEqualToString:@"isMuteNotificationWhenPcOnline"]) {
    [self handleIsMuteNotificationWhenPcOnline:args result:result];
  } else if ([method isEqualToString:@"setDefaultSilentWhenPcOnline"]) {
    [self handleSetDefaultSilentWhenPcOnline:args result:result];
  } else if ([method isEqualToString:@"muteNotificationWhenPcOnline"]) {
    [self handleMuteNotificationWhenPcOnline:args result:result];
  } else if ([method isEqualToString:@"getUserOnlineState"]) {
    [self handleGetUserOnlineState:args result:result];
  } else if ([method isEqualToString:@"getMyCustomState"]) {
    [self handleGetMyCustomState:args result:result];
  } else if ([method isEqualToString:@"setMyCustomState"]) {
    [self handleSetMyCustomState:args result:result];
  } else if ([method isEqualToString:@"watchOnlineState"]) {
    [self handleWatchOnlineState:args result:result];
  } else if ([method isEqualToString:@"unwatchOnlineState"]) {
    [self handleUnwatchOnlineState:args result:result];
  } else if ([method isEqualToString:@"isEnableUserOnlineState"]) {
    [self handleIsEnableUserOnlineState:args result:result];
  } else if ([method isEqualToString:@"sendConferenceRequest"]) {
    [self handleSendConferenceRequest:args result:result];
  } else if ([method isEqualToString:@"getConversationFiles"]) {
    [self handleGetConversationFiles:args result:result];
  } else if ([method isEqualToString:@"getMyFiles"]) {
    [self handleGetMyFiles:args result:result];
  } else if ([method isEqualToString:@"deleteFileRecord"]) {
    [self handleDeleteFileRecord:args result:result];
  } else if ([method isEqualToString:@"searchFiles"]) {
    [self handleSearchFiles:args result:result];
  } else if ([method isEqualToString:@"searchMyFiles"]) {
    [self handleSearchMyFiles:args result:result];
  } else if ([method isEqualToString:@"getAuthCode"]) {
    [self handleGetAuthCode:args result:result];
  } else if ([method isEqualToString:@"configApplication"]) {
    [self handleConfigApplication:args result:result];
  } else if ([method isEqualToString:@"getWavData"]) {
    [self handleGetWavData:args result:result];
  } else if ([method isEqualToString:@"beginTransaction"]) {
    [self handleBeginTransaction:args result:result];
  } else if ([method isEqualToString:@"commitTransaction"]) {
    [self handleCommitTransaction:args result:result];
  } else if ([method isEqualToString:@"rollbackTransaction"]) {
    [self handleRollbackTransaction:args result:result];
  } else if ([method isEqualToString:@"isCommercialServer"]) {
    [self handleIsCommercialServer:args result:result];
  } else if ([method isEqualToString:@"isReceiptEnabled"]) {
    [self handleIsReceiptEnabled:args result:result];
  } else if ([method isEqualToString:@"isGroupReceiptEnabled"]) {
    [self handleIsGroupReceiptEnabled:args result:result];
  } else if ([method isEqualToString:@"isGlobalDisableSyncDraft"]) {
    [self handleIsGlobalDisableSyncDraft:args result:result];
  } else {
    result(FlutterMethodNotImplemented);
  }
}

- (void)handleInitProto:(NSDictionary *)args result:(FlutterResult)result {
  std::string app_name = GetString(args, @"appName", "wfc_pc");
  std::string app_data_path = GetString(args, @"appDataPath");
  std::string package_name = GetString(args, @"packageName", app_name);
  std::string db_path = GetString(args, @"dbPath");

  WFClient::setAppName(app_name.c_str(), app_name.size());
  if (!app_data_path.empty()) {
    WFClient::setAppDataPath(app_data_path.c_str(), app_data_path.size());
  }
  WFClient::setPackageName(package_name.c_str(), package_name.size());
  if (!db_path.empty()) {
    WFClient::setDBPath(db_path.c_str(), db_path.size());
  }

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

  result(nil);
}

- (void)handleGetClientId:(NSDictionary *)args result:(FlutterResult)result {
  size_t len = 0;
  const char *str = WFClient::getClientId(&len);
  std::string client_id = ConvertDllStringAndRelease(str, len);
  result([NSString stringWithUTF8String:client_id.c_str()]);
}

- (void)handleGetProtoRevision:(NSDictionary *)args result:(FlutterResult)result {
  size_t len = 0;
  const char *str = WFClient::getProtoRevision(&len);
  std::string proto_revision = ConvertDllStringAndRelease(str, len);
  result([NSString stringWithUTF8String:proto_revision.c_str()]);
}

- (void)handleConnect:(NSDictionary *)args result:(FlutterResult)result {
  std::string user_id = GetString(args, @"userId");
  std::string token = GetString(args, @"token");
  int64_t connect_time = WFClient::connect2Server(
      user_id.c_str(), user_id.size(), token.c_str(), token.size());
  result(@(connect_time));
}

- (void)handleDisconnect:(NSDictionary *)args result:(FlutterResult)result {
  bool clear_session = GetBool(args, @"clearSession", false);
  WFClient::disconnect(clear_session ? 1 : 0);
  result(nil);
}

- (void)handleConnectionStatus:(NSDictionary *)args result:(FlutterResult)result {
  result(@(WFClient::getConnectionStatus()));
}

- (void)handleIsLogined:(NSDictionary *)args result:(FlutterResult)result {
  result(@(WFClient::isLogin()));
}

- (void)handleCurrentUserId:(NSDictionary *)args result:(FlutterResult)result {
  size_t len = 0;
  const char *str = WFClient::getCurrentUserId(&len);
  std::string user_id = ConvertDllStringAndRelease(str, len);
  result([NSString stringWithUTF8String:user_id.c_str()]);
}

- (void)handleServerDeltaTime:(NSDictionary *)args result:(FlutterResult)result {
  result(@(WFClient::getServerDeltaTime()));
}

- (void)handleSetBackupAddress:(NSDictionary *)args result:(FlutterResult)result {
  std::string host = GetString(args, @"host");
  int port = static_cast<int>(GetInt(args, @"port", 80));
  WFClient::setBackupAddress(host.c_str(), host.size(), port);
  result(nil);
}

- (void)handleUseSM4:(NSDictionary *)args result:(FlutterResult)result {
  WFClient::useSM4();
  result(nil);
}

- (void)handleSetLiteMode:(NSDictionary *)args result:(FlutterResult)result {
  bool lite_mode = GetBool(args, @"liteMode", false);
  WFClient::setLiteMode(lite_mode);
  result(nil);
}

- (void)handleSetBackupAddressStrategy:(NSDictionary *)args result:(FlutterResult)result {
  int strategy = static_cast<int>(GetInt(args, @"strategy", 0));
  WFClient::setBackupAddressStrategy(strategy);
  result(nil);
}

- (void)handleSetProtoUserAgent:(NSDictionary *)args result:(FlutterResult)result {
  std::string agent = GetString(args, @"agent");
  WFClient::setUserAgent(agent.c_str(), agent.size());
  result(nil);
}

- (void)handleAddHttpHeader:(NSDictionary *)args result:(FlutterResult)result {
  std::string header = GetString(args, @"header");
  std::string value = GetString(args, @"value");
  WFClient::addHttpHeader(header.c_str(), header.size(), value.c_str(),
                          value.size());
  result(nil);
}

- (void)handleSetProxyInfo:(NSDictionary *)args result:(FlutterResult)result {
  std::string host = GetString(args, @"host");
  std::string ip = GetString(args, @"ip");
  int port = static_cast<int>(GetInt(args, @"port", 0));
  std::string user_name = GetString(args, @"userName");
  std::string password = GetString(args, @"password");
  WFClient::setProxyInfo(host.c_str(), host.size(), ip.c_str(), ip.size(),
                         port, user_name.c_str(), user_name.size(),
                         password.c_str(), password.size());
  result(nil);
}

- (void)handleRegisterMessage:(NSDictionary *)args result:(FlutterResult)result {
  int type = static_cast<int>(GetInt(args, @"type", 0));
  int flag = static_cast<int>(GetInt(args, @"flag", 0));
  WFClient::registerMessageFlag(type, flag);
  result(nil);
}

- (void)handleGetConversationInfos:(NSDictionary *)args result:(FlutterResult)result {
  std::vector<int> types = GetIntList(args, @"types");
  std::vector<int> lines = GetIntList(args, @"lines");
  size_t len = 0;
  const char *str = WFClient::getConversationInfos(
      types.data(), static_cast<int>(types.size()), lines.data(),
      static_cast<int>(lines.size()), &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  NSLog(@"[ImclientPlugin] getConversationInfos result json=%@", [NSString stringWithUTF8String:json_str.c_str()]);
  result(ObjectFromJsonString(json_str));
}

- (void)handleGetConversationInfo:(NSDictionary *)args result:(FlutterResult)result {
  Conversation conv(args);
  size_t len = 0;
  const char *str = WFClient::getConversationInfo(
      conv.conversation_type, conv.target.c_str(), conv.target.size(),
      conv.line, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result(ObjectFromJsonString(json_str));
}

- (void)handleSearchConversation:(NSDictionary *)args result:(FlutterResult)result {
  std::string keyword = GetString(args, @"keyword");
  std::vector<int> types = GetIntList(args, @"types");
  std::vector<int> lines = GetIntList(args, @"lines");
  size_t len = 0;
  const char *str = WFClient::searchConversation(
      types.data(), static_cast<int>(types.size()), lines.data(),
      static_cast<int>(lines.size()), keyword.c_str(), keyword.size(), &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result(ObjectFromJsonString(json_str));
}

- (void)handleRemoveConversation:(NSDictionary *)args result:(FlutterResult)result {
  Conversation conv(args);
  bool clear_message = GetBool(args, @"clearMessage", false);
  WFClient::removeConversation(conv.conversation_type, conv.target.c_str(),
                               conv.target.size(), conv.line, clear_message);
  result(nil);
}

- (void)handleSetConversationTop:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  Conversation conv(args);
  int is_top = static_cast<int>(GetInt(args, @"isTop", 0));
  WFClient::setConversationTop(
      conv.conversation_type, conv.target.c_str(), conv.target.size(),
      conv.line, is_top, OnGeneralVoidSuccess, OnGeneralError,
      reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleSetConversationSilent:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  Conversation conv(args);
  bool is_silent = GetBool(args, @"isSilent", false);
  WFClient::setConversationSlient(
      conv.conversation_type, conv.target.c_str(), conv.target.size(),
      conv.line, is_silent, OnGeneralVoidSuccess, OnGeneralError,
      reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleSetConversationDraft:(NSDictionary *)args result:(FlutterResult)result {
  Conversation conv(args);
  std::string draft = GetString(args, @"draft");
  WFClient::setConversationDraft(conv.conversation_type, conv.target.c_str(),
                                 conv.target.size(), conv.line,
                                 draft.c_str(), draft.size());
  result(nil);
}

- (void)handleSetConversationTimestamp:(NSDictionary *)args result:(FlutterResult)result {
  Conversation conv(args);
  int64_t timestamp = GetInt(args, @"timestamp", 0);
  WFClient::setConversationTimestamp(conv.conversation_type,
                                     conv.target.c_str(), conv.target.size(),
                                     conv.line, timestamp);
  result(nil);
}

- (void)handleGetFirstUnreadMessageId:(NSDictionary *)args result:(FlutterResult)result {
  Conversation conv(args);
  long message_id = WFClient::getConversationFirstUnreadMessageId(
      conv.conversation_type, conv.target.c_str(), conv.target.size(),
      conv.line);
  result(@(static_cast<int64_t>(message_id)));
}

- (void)handleGetConversationUnreadCount:(NSDictionary *)args result:(FlutterResult)result {
  Conversation conv(args);
  size_t len = 0;
  const char *str = WFClient::getConversationUnreadCount(
      conv.conversation_type, conv.target.c_str(), conv.target.size(),
      conv.line, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result(ObjectFromJsonString(json_str));
}

- (void)handleGetConversationsUnreadCount:(NSDictionary *)args result:(FlutterResult)result {
  std::vector<int> types = GetIntList(args, @"types");
  std::vector<int> lines = GetIntList(args, @"lines");
  size_t len = 0;
  const char *str = WFClient::getUnreadCount(
      types.data(), static_cast<int>(types.size()), lines.data(),
      static_cast<int>(lines.size()), &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result(ObjectFromJsonString(json_str));
}

- (void)handleClearConversationUnreadStatus:(NSDictionary *)args result:(FlutterResult)result {
  Conversation conv(args);
  bool ret = WFClient::clearUnreadStatus(
      conv.conversation_type, conv.target.c_str(), conv.target.size(),
      conv.line);
  result(@(ret));
}

- (void)handleClearConversationsUnreadStatus:(NSDictionary *)args result:(FlutterResult)result {
  std::vector<int> types = GetIntList(args, @"types");
  std::vector<int> lines = GetIntList(args, @"lines");
  bool ret = WFClient::clearUnreadStatusEx(
      types.data(), static_cast<int>(types.size()), lines.data(),
      static_cast<int>(lines.size()));
  result(@(ret));
}

- (void)handleClearAllUnreadStatus:(NSDictionary *)args result:(FlutterResult)result {
  result(@(WFClient::clearAllUnreadStatus()));
}

- (void)handleClearMessageUnreadStatus:(NSDictionary *)args result:(FlutterResult)result {
  int message_id = static_cast<int>(GetInt(args, @"messageId", 0));
  result(@(WFClient::clearMessageUnreadStatus(message_id)));
}

- (void)handleClearMessageUnreadStatusBefore:(NSDictionary *)args result:(FlutterResult)result {
  Conversation conv(args);
  int message_id = static_cast<int>(GetInt(args, @"messageId", 0));
  bool ret = WFClient::clearMessageUnreadStatusBefore(
      conv.conversation_type, conv.target.c_str(), conv.target.size(),
      conv.line, message_id);
  result(@(ret));
}

- (void)handleMarkAsUnRead:(NSDictionary *)args result:(FlutterResult)result {
  Conversation conv(args);
  int64_t message_uid = WFClient::setLastReceivedMessageUnRead(
      conv.conversation_type, conv.target.c_str(), conv.target.size(),
      conv.line, 0, 0);
  result(@(message_uid > 0));
}

- (void)handleGetConversationRead:(NSDictionary *)args result:(FlutterResult)result {
  Conversation conv(args);
  size_t len = 0;
  const char *str = WFClient::getConversationRead(
      conv.conversation_type, conv.target.c_str(), conv.target.size(),
      conv.line, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  id value = ObjectFromJsonString(json_str);
  if ([value isKindOfClass:[NSArray class]]) {
    result(@{});
  } else if ([value isKindOfClass:[NSDictionary class]]) {
    result(value);
  } else {
    result(@{});
  }
}

- (void)handleGetMessageDelivery:(NSDictionary *)args result:(FlutterResult)result {
  Conversation conv(args);
  size_t len = 0;
  const char *str = WFClient::getMessageDelivery(conv.conversation_type,
                                                  conv.target.c_str(),
                                                  conv.target.size(), &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  id value = ObjectFromJsonString(json_str);
  if ([value isKindOfClass:[NSArray class]]) {
    result(@{});
  } else if ([value isKindOfClass:[NSDictionary class]]) {
    result(value);
  } else {
    result(@{});
  }
}

static void WFCAPI OnMessagesResult(void *p_obj, int data_type,
                                    const char *cval, size_t val_len) {
  FlutterResult result = (__bridge_transfer FlutterResult)p_obj;
  std::string json_str(cval, val_len);
  id value = ObjectFromJsonString(json_str);
  NSArray *messages = nil;
  if ([value isKindOfClass:[NSArray class]]) {
    messages = [[(NSArray *)value reverseObjectEnumerator] allObjects];
  } else {
    messages = @[];
  }
  result(messages);
}

static void WFCAPI OnMessagesError(void *p_obj, int data_code,
                                   int error_code) {
  FlutterResult result = (__bridge_transfer FlutterResult)p_obj;
  result(@[]);
}

- (void)handleGetMessages:(NSDictionary *)args result:(FlutterResult)result {
  Conversation conv(args);
  std::vector<int> content_types = GetIntList(args, @"contentTypes");
  int64_t from_index = GetInt(args, @"fromIndex", 0);
  int count = static_cast<int>(GetInt(args, @"count", 0));
  std::string with_user = GetString(args, @"withUser");
  // 参考 iOS：count > 0 时 desc=true，否则 desc=false。
  bool direction = count > 0;
  int abs_count = std::abs(count);
  WFClient::getMessagesV2(
      conv.conversation_type, conv.target.c_str(), conv.target.size(),
      conv.line, content_types.data(), static_cast<int>(content_types.size()),
      from_index, direction, abs_count, with_user.c_str(),
      with_user.size(), OnMessagesResult, OnMessagesError,
      (__bridge_retained void *)[result copy], 0);
}

- (void)handleGetMessagesByStatus:(NSDictionary *)args result:(FlutterResult)result {
  Conversation conv(args);
  int64_t from_index = GetInt(args, @"fromIndex", 0);
  int count = static_cast<int>(GetInt(args, @"count", 0));
  std::vector<int> message_statuses = GetIntList(args, @"messageStatus");
  std::string with_user = GetString(args, @"withUser");
  bool direction = count > 0;
  int abs_count = std::abs(count);
  WFClient::getMessagesByMessageStatusV2(
      conv.conversation_type, conv.target.c_str(), conv.target.size(),
      conv.line, message_statuses.data(),
      static_cast<int>(message_statuses.size()), from_index, direction,
      abs_count, with_user.c_str(), with_user.size(), OnMessagesResult,
      OnMessagesError, (__bridge_retained void *)[result copy], 0);
}

- (void)handleGetConversationsMessages:(NSDictionary *)args result:(FlutterResult)result {
  std::vector<int> types = GetIntList(args, @"types");
  std::vector<int> lines = GetIntList(args, @"lines");
  std::vector<int> content_types = GetIntList(args, @"contentTypes");
  int64_t from_index = GetInt(args, @"fromIndex", 0);
  int count = static_cast<int>(GetInt(args, @"count", 0));
  std::string with_user = GetString(args, @"withUser");
  bool direction = count > 0;
  int abs_count = std::abs(count);
  WFClient::getMessagesExV2(
      types.data(), static_cast<int>(types.size()), lines.data(),
      static_cast<int>(lines.size()), content_types.data(),
      static_cast<int>(content_types.size()), from_index, direction,
      abs_count, with_user.c_str(), with_user.size(), OnMessagesResult,
      OnMessagesError, (__bridge_retained void *)[result copy], 0);
}

- (void)handleGetConversationsMessageByStatus:(NSDictionary *)args result:(FlutterResult)result {
  std::vector<int> types = GetIntList(args, @"types");
  std::vector<int> lines = GetIntList(args, @"lines");
  int64_t from_index = GetInt(args, @"fromIndex", 0);
  int count = static_cast<int>(GetInt(args, @"count", 0));
  std::vector<int> message_statuses = GetIntList(args, @"messageStatus");
  std::string with_user = GetString(args, @"withUser");
  bool direction = count > 0;
  int abs_count = std::abs(count);
  WFClient::getMessagesEx2V2(
      types.data(), static_cast<int>(types.size()), lines.data(),
      static_cast<int>(lines.size()), message_statuses.data(),
      static_cast<int>(message_statuses.size()), from_index, direction,
      abs_count, with_user.c_str(), with_user.size(), OnMessagesResult,
      OnMessagesError, (__bridge_retained void *)[result copy], 0);
}

- (void)handleGetRemoteMessages:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  Conversation conv(args);
  int64_t before_uid = GetInt(args, @"beforeMessageUid", 0);
  int count = static_cast<int>(GetInt(args, @"count", 0));
  std::vector<int> content_types = GetIntList(args, @"contentTypes");
  WFClient::getRemoteMessages(
      conv.conversation_type, conv.target.c_str(), conv.target.size(),
      conv.line, content_types.data(),
      static_cast<int>(content_types.size()), before_uid, count,
      OnGetRemoteMessagesSuccess, OnGetRemoteMessagesError,
      reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleGetRemoteMessage:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  int64_t message_uid = GetInt(args, @"messageUid", 0);
  WFClient::getRemoteMessage(message_uid, OnGeneralStringSuccess, OnGeneralError,
                             reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleGetMessage:(NSDictionary *)args result:(FlutterResult)result {
  int message_id = static_cast<int>(GetInt(args, @"messageId", 0));
  size_t len = 0;
  const char *str = WFClient::getMessage(message_id, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result(ObjectFromJsonString(json_str));
}

- (void)handleGetMessageByUid:(NSDictionary *)args result:(FlutterResult)result {
  int64_t message_uid = GetInt(args, @"messageUid", 0);
  size_t len = 0;
  const char *str = WFClient::getMessageByUid(message_uid, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result(ReversedArrayIfArray(ObjectFromJsonString(json_str)));
}

- (void)handleSearchMessages:(NSDictionary *)args result:(FlutterResult)result {
  Conversation conv(args);
  std::string keyword = GetString(args, @"keyword");
  bool order = GetBool(args, @"order", false);
  int limit = static_cast<int>(GetInt(args, @"limit", 0));
  int offset = static_cast<int>(GetInt(args, @"offset", 0));
  std::string with_user = GetString(args, @"withUser");
  size_t len = 0;
  const char *str = WFClient::searchMessage(
      conv.conversation_type, conv.target.c_str(), conv.target.size(),
      conv.line, keyword.c_str(), keyword.size(), order, limit, offset,
      with_user.c_str(), with_user.size(), &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result(ObjectFromJsonString(json_str));
}

- (void)handleSearchConversationsMessages:(NSDictionary *)args result:(FlutterResult)result {
  std::vector<int> types = GetIntList(args, @"types");
  std::vector<int> lines = GetIntList(args, @"lines");
  std::vector<int> content_types = GetIntList(args, @"contentTypes");
  std::string keyword = GetString(args, @"keyword");
  int64_t from_index = GetInt(args, @"fromIndex", 0);
  int count = static_cast<int>(GetInt(args, @"count", 0));
  std::string with_user = GetString(args, @"withUser");

  size_t len = 0;
  const char *str = WFClient::searchMessageEx2(
      types.data(), static_cast<int>(types.size()), lines.data(),
      static_cast<int>(lines.size()), content_types.data(),
      static_cast<int>(content_types.size()), keyword.c_str(), keyword.size(),
      from_index, count > 0, std::abs(count), with_user.c_str(),
      with_user.size(), &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result(ReversedArrayIfArray(ObjectFromJsonString(json_str)));
}

- (void)handleSendMessage:(NSDictionary *)args result:(FlutterResult)result {
  Conversation conv(args);
  int64_t request_id = GetInt(args, @"requestId", 0);
  MessagePayload payload(GetMap(args, @"content"));
  std::vector<std::string> to_users = GetStringList(args, @"toUsers");
  int expire_duration = static_cast<int>(GetInt(args, @"expireDuration", 0));

  std::string content_json = JsonStringFromObject(payload.ToDictionary());

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
  result(ObjectFromJsonString(result_json));
}

- (void)handleSendSavedMessage:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  int message_id = static_cast<int>(GetInt(args, @"messageId", 0));
  int expire_duration = static_cast<int>(GetInt(args, @"expireDuration", 0));
  bool ret = WFClient::sendSavedMessage(
      message_id, expire_duration, OnSendMessageSuccess, OnSendMessageError,
      reinterpret_cast<void *>(request_id), 0);
  result(@(ret));
}

- (void)handleCancelSendingMessage:(NSDictionary *)args result:(FlutterResult)result {
  int message_id = static_cast<int>(GetInt(args, @"messageId", 0));
  result(@(WFClient::cancelSendingMessage(message_id)));
}

- (void)handleRecallMessage:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  int64_t message_uid = GetInt(args, @"messageUid", 0);
  WFClient::recallMessage(message_uid, OnGeneralVoidSuccess, OnGeneralError,
                          reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleUploadMedia:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string file_name = GetString(args, @"fileName");
  std::vector<uint8_t> media_data;
  id media_value = args[@"mediaData"];
  NSData *data = nil;
  if ([media_value isKindOfClass:[FlutterStandardTypedData class]]) {
    data = [media_value data];
  } else if ([media_value isKindOfClass:[NSData class]]) {
    data = media_value;
  }
  if (data) {
    media_data.assign((const uint8_t *)data.bytes,
                      (const uint8_t *)data.bytes + data.length);
  }
  int media_type = static_cast<int>(GetInt(args, @"mediaType", 0));

  std::string data_str(media_data.begin(), media_data.end());
  WFClient::uploadMedia(
      file_name.c_str(), file_name.size(), data_str.c_str(),
      static_cast<int>(data_str.size()), media_type,
      OnGeneralStringSuccess, OnGeneralError, nullptr,
      reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleUploadMediaFile:(NSDictionary *)args result:(FlutterResult)result {
  // PC SDK does not support file path upload directly; return empty string callback.
  int64_t request_id = GetInt(args, @"requestId", 0);
  InvokeDartMethod(@"onOperationStringSuccess",
                   @{@"requestId": @(request_id), @"data": @""});
  result(nil);
}

- (void)handleGetUploadUrl:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string file_name = GetString(args, @"fileName");
  std::string content_type = GetString(args, @"contentType");
  int media_type = static_cast<int>(GetInt(args, @"mediaType", 0));
  WFClient::getUploadUrl(file_name.c_str(), file_name.size(), media_type,
                         content_type.c_str(),
                         static_cast<int>(content_type.size()),
                         OnGetUploadUrlSuccess, OnGeneralError,
                         reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleGetMediaUploadUrl:(NSDictionary *)args result:(FlutterResult)result {
  // Same implementation as getUploadUrl; forwards to SDK getUploadUrl.
  [self handleGetUploadUrl:args result:result];
}

- (void)handleIsSupportBigFilesUpload:(NSDictionary *)args result:(FlutterResult)result {
  result(@(WFClient::isSupportBigFilesUpload()));
}

- (void)handleDeleteMessage:(NSDictionary *)args result:(FlutterResult)result {
  int message_id = static_cast<int>(GetInt(args, @"messageId", 0));
  result(@(WFClient::deleteMessage(message_id)));
}

- (void)handleBatchDeleteMessages:(NSDictionary *)args result:(FlutterResult)result {
  std::vector<int64_t> message_uids = GetInt64List(args, @"messageUids");
  bool ret = WFClient::batchDeleteMessages(
      message_uids.data(), static_cast<int64_t>(message_uids.size()));
  result(@(ret));
}

- (void)handleDeleteRemoteMessage:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  int64_t message_uid = GetInt(args, @"messageUid", 0);
  WFClient::deleteRemoteMessage(message_uid, OnGeneralVoidSuccess, OnGeneralError,
                                reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleClearMessages:(NSDictionary *)args result:(FlutterResult)result {
  Conversation conv(args);
  int64_t before = GetInt(args, @"before", 0);
  if (before <= 0) {
    WFClient::clearMessages(conv.conversation_type, conv.target.c_str(),
                            conv.target.size(), conv.line);
  } else {
    WFClient::clearMessagesBefore(conv.conversation_type, conv.target.c_str(),
                                  conv.target.size(), conv.line, before);
  }
  result(@(YES));
}

- (void)handleClearMessagesKeepLatest:(NSDictionary *)args result:(FlutterResult)result {
  Conversation conv(args);
  int keep_count = static_cast<int>(GetInt(args, @"keepCount", 0));
  WFClient::clearMessagesKeep(conv.conversation_type, conv.target.c_str(),
                              conv.target.size(), conv.line, keep_count);
  result(@(YES));
}

- (void)handleClearRemoteConversationMessage:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  Conversation conv(args);
  WFClient::clearRemoteConversationMessage(
      conv.conversation_type, conv.target.c_str(), conv.target.size(),
      conv.line, OnGeneralVoidSuccess, OnGeneralError,
      reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleSetMediaMessagePlayed:(NSDictionary *)args result:(FlutterResult)result {
  int message_id = static_cast<int>(GetInt(args, @"messageId", 0));
  WFClient::setMediaMessagePlayed(message_id);
  result(nil);
}

- (void)handleSetMessageLocalExtra:(NSDictionary *)args result:(FlutterResult)result {
  int message_id = static_cast<int>(GetInt(args, @"messageId", 0));
  std::string local_extra = GetString(args, @"localExtra");
  bool ret = WFClient::setMessageLocalExtra(
      message_id, local_extra.c_str(), local_extra.size());
  result(@(ret));
}

- (void)handleInsertMessage:(NSDictionary *)args result:(FlutterResult)result {
  Conversation conv(args);
  std::string sender = GetString(args, @"sender");
  MessagePayload payload(GetMap(args, @"content"));
  int status = static_cast<int>(GetInt(args, @"status", 0));
  bool notify = GetBool(args, @"notify", false);
  int64_t server_time = GetInt(args, @"serverTime", 0);

  std::string content_json = JsonStringFromObject(payload.ToDictionary());

  size_t len = 0;
  const char *str = WFClient::insertMessage(
      conv.conversation_type, conv.target.c_str(), conv.target.size(),
      conv.line, sender.c_str(), sender.size(), content_json.c_str(),
      content_json.size(), status, notify, server_time, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result(ObjectFromJsonString(json_str));
}

- (void)handleUpdateMessage:(NSDictionary *)args result:(FlutterResult)result {
  int message_id = static_cast<int>(GetInt(args, @"messageId", 0));
  MessagePayload payload(GetMap(args, @"content"));
  std::string content_json = JsonStringFromObject(payload.ToDictionary());
  WFClient::updateMessage(message_id, content_json.c_str(),
                          content_json.size());
  result(nil);
}

- (void)handleUpdateRemoteMessageContent:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  int64_t message_uid = GetInt(args, @"messageUid", 0);
  MessagePayload payload(GetMap(args, @"content"));
  std::string content_json = JsonStringFromObject(payload.ToDictionary());
  bool distribute = GetBool(args, @"distribute", false);
  bool update_local = GetBool(args, @"updateLocal", false);
  WFClient::updateRemoteMessage(
      message_uid, content_json.c_str(), content_json.size(), distribute,
      update_local, OnGeneralVoidSuccess, OnGeneralError,
      reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleUpdateMessageStatus:(NSDictionary *)args result:(FlutterResult)result {
  int message_id = static_cast<int>(GetInt(args, @"messageId", 0));
  int status = static_cast<int>(GetInt(args, @"status", 0));
  WFClient::updateMessageStatus(message_id, status);
  result(nil);
}

- (void)handleGetMessageCount:(NSDictionary *)args result:(FlutterResult)result {
  Conversation conv(args);
  int count = WFClient::getMessageCount(conv.conversation_type,
                                        conv.target.c_str(),
                                        conv.target.size(), conv.line);
  result(@(count));
}

- (void)handleGetAuthorizedMediaUrl:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  int64_t message_uid = GetInt(args, @"messageUid", 0);
  int media_type = static_cast<int>(GetInt(args, @"mediaType", 0));
  std::string media_path = GetString(args, @"mediaPath");
  WFClient::getAuthorizedMediaUrl(
      message_uid, media_type, media_path.c_str(), media_path.size(),
      OnGeneralStringSuccess, OnGeneralError,
      reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleStartLog:(NSDictionary *)args result:(FlutterResult)result {
  // PC SDK has no startLog; return success.
  result(nil);
}

- (void)handleStopLog:(NSDictionary *)args result:(FlutterResult)result {
  // PC SDK has no stopLog; return success.
  result(nil);
}

- (void)handleSetSendLogCommand:(NSDictionary *)args result:(FlutterResult)result {
  // PC SDK has no setSendLogCommand; return success.
  result(nil);
}

- (void)handleGetLogFilesPath:(NSDictionary *)args result:(FlutterResult)result {
  size_t len = 0;
  const char *str = WFClient::getLogFilesPath(&len);
  std::string path = ConvertDllStringAndRelease(str, len);
  result([NSString stringWithUTF8String:path.c_str()]);
}

- (void)handleSetDeviceToken:(NSDictionary *)args result:(FlutterResult)result {
  // PC 端不需要推送 token，直接返回成功。
  result(nil);
}

- (void)handleSetVoipDeviceToken:(NSDictionary *)args result:(FlutterResult)result {
  // PC 端不需要 VoIP 推送 token，直接返回成功。
  result(nil);
}

- (void)handleGetUserInfo:(NSDictionary *)args result:(FlutterResult)result {
  std::string user_id = GetString(args, @"userId");
  bool refresh = GetBool(args, @"refresh", false);
  std::string group_id = GetString(args, @"groupId");
  size_t len = 0;
  const char *str = WFClient::getUserInfo(user_id.c_str(), user_id.size(),
                                          refresh, group_id.c_str(),
                                          group_id.size(), &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result(ObjectFromJsonString(json_str));
}

- (void)handleGetUserInfos:(NSDictionary *)args result:(FlutterResult)result {
  std::vector<std::string> user_ids = GetStringList(args, @"userIds");
  std::string group_id = GetString(args, @"groupId");
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
  result(ObjectFromJsonString(json_str));
}

- (void)handleSearchUser:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string keyword = GetString(args, @"keyword");
  int search_type = static_cast<int>(GetInt(args, @"searchType", 0));
  int page = static_cast<int>(GetInt(args, @"page", 0));
  WFClient::searchUser(keyword.c_str(), keyword.size(), search_type, page,
                       OnSearchUserSuccess, OnGeneralError,
                       reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleGetUserInfoAsync:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string user_id = GetString(args, @"userId");
  bool refresh = GetBool(args, @"refresh", false);
  std::string group_id = GetString(args, @"groupId");
  size_t len = 0;
  const char *str = WFClient::getUserInfo(user_id.c_str(), user_id.size(),
                                          refresh, group_id.c_str(),
                                          group_id.size(), &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  InvokeDartMethod(@"getUserInfoAsyncCallback",
                   @{@"requestId": @(request_id),
                     @"user": ObjectFromJsonString(json_str) ?: [NSNull null]});
  result(nil);
}

- (void)handleIsMyFriend:(NSDictionary *)args result:(FlutterResult)result {
  std::string user_id = GetString(args, @"userId");
  result(@(WFClient::isMyFriend(user_id.c_str(), user_id.size())));
}

- (void)handleGetMyFriendList:(NSDictionary *)args result:(FlutterResult)result {
  bool refresh = GetBool(args, @"refresh", false);
  size_t len = 0;
  const char *str = WFClient::getMyFriendList(refresh, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result(ObjectFromJsonString(json_str));
}

- (void)handleSearchFriends:(NSDictionary *)args result:(FlutterResult)result {
  std::string keyword = GetString(args, @"keyword");
  size_t len = 0;
  const char *str = WFClient::searchFriends(keyword.c_str(), keyword.size(), &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result(ObjectFromJsonString(json_str));
}

- (void)handleGetFriends:(NSDictionary *)args result:(FlutterResult)result {
  bool refresh = GetBool(args, @"refresh", false);
  size_t len = 0;
  const char *str = WFClient::getFriendList(refresh, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result(ObjectFromJsonString(json_str));
}

- (void)handleSearchGroups:(NSDictionary *)args result:(FlutterResult)result {
  std::string keyword = GetString(args, @"keyword");
  size_t len = 0;
  const char *str = WFClient::searchGroups(keyword.c_str(), keyword.size(), &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result(ObjectFromJsonString(json_str));
}

- (void)handleGetIncommingFriendRequest:(NSDictionary *)args result:(FlutterResult)result {
  size_t len = 0;
  const char *str = WFClient::getIncommingFriendRequest(&len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result(ObjectFromJsonString(json_str));
}

- (void)handleGetOutgoingFriendRequest:(NSDictionary *)args result:(FlutterResult)result {
  size_t len = 0;
  const char *str = WFClient::getOutgoingFriendRequest(&len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result(ObjectFromJsonString(json_str));
}

- (void)handleGetFriendRequest:(NSDictionary *)args result:(FlutterResult)result {
  std::string user_id = GetString(args, @"userId");
  int direction = static_cast<int>(GetInt(args, @"direction", 0));
  size_t len = 0;
  const char *str = WFClient::getFriendRequest(user_id.c_str(), user_id.size(),
                                               direction == 1, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result(ObjectFromJsonString(json_str));
}

- (void)handleLoadFriendRequestFromRemote:(NSDictionary *)args result:(FlutterResult)result {
  WFClient::loadFriendRequestFromRemote();
  result(nil);
}

- (void)handleGetUnreadFriendRequestStatus:(NSDictionary *)args result:(FlutterResult)result {
  result(@(WFClient::getUnreadFriendRequestStatus()));
}

- (void)handleClearUnreadFriendRequestStatus:(NSDictionary *)args result:(FlutterResult)result {
  WFClient::clearUnreadFriendRequestStatus();
  result(@(YES));
}

- (void)handleClearFriendRequest:(NSDictionary *)args result:(FlutterResult)result {
  int direction = static_cast<int>(GetInt(args, @"direction", 0));
  int64_t before_time = GetInt(args, @"beforeTime", 0);
  result(@(WFClient::clearFriendRequest(direction, before_time)));
}

- (void)handleDeleteFriendRequest:(NSDictionary *)args result:(FlutterResult)result {
  std::string user_id = GetString(args, @"userId");
  int direction = static_cast<int>(GetInt(args, @"direction", 0));
  result(@(WFClient::deleteFriendRequest(user_id.c_str(), user_id.size(),
                                         direction)));
}

- (void)handleDeleteFriend:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string user_id = GetString(args, @"userId");
  WFClient::deleteFriend(user_id.c_str(), user_id.size(), OnGeneralVoidSuccess,
                         OnGeneralError, reinterpret_cast<void *>(request_id),
                         0);
  result(nil);
}

- (void)handleGetFriendAlias:(NSDictionary *)args result:(FlutterResult)result {
  std::string user_id = GetString(args, @"friendId");
  size_t len = 0;
  const char *str = WFClient::getFriendAlias(user_id.c_str(), user_id.size(),
                                             &len);
  std::string alias = ConvertDllStringAndRelease(str, len);
  result([NSString stringWithUTF8String:alias.c_str()]);
}

- (void)handleSetFriendAlias:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string user_id = GetString(args, @"friendId");
  std::string alias = GetString(args, @"alias");
  WFClient::setFriendAlias(user_id.c_str(), user_id.size(), alias.c_str(),
                           alias.size(), OnGeneralVoidSuccess, OnGeneralError,
                           reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleGetFriendExtra:(NSDictionary *)args result:(FlutterResult)result {
  std::string user_id = GetString(args, @"userId");
  size_t len = 0;
  const char *str = WFClient::getFriendExtra(user_id.c_str(), user_id.size(),
                                             &len);
  std::string extra = ConvertDllStringAndRelease(str, len);
  result([NSString stringWithUTF8String:extra.c_str()]);
}

- (void)handleSendFriendRequest:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string user_id = GetString(args, @"userId");
  std::string reason = GetString(args, @"reason");
  WFClient::sendFriendRequest(user_id.c_str(), user_id.size(), reason.c_str(),
                              reason.size(), "", 0, OnGeneralVoidSuccess,
                              OnGeneralError, reinterpret_cast<void *>(request_id),
                              0);
  result(nil);
}

- (void)handleHandleFriendRequest:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string user_id = GetString(args, @"userId");
  bool accept = GetBool(args, @"accept", false);
  std::string extra = GetString(args, @"extra");
  WFClient::handleFriendRequest(user_id.c_str(), user_id.size(), accept,
                                extra.c_str(), extra.size(),
                                OnGeneralVoidSuccess, OnGeneralError,
                                reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleIsBlackListed:(NSDictionary *)args result:(FlutterResult)result {
  std::string user_id = GetString(args, @"userId");
  result(@(WFClient::isBlackListed(user_id.c_str(), user_id.size())));
}

- (void)handleGetBlackList:(NSDictionary *)args result:(FlutterResult)result {
  bool refresh = GetBool(args, @"refresh", false);
  size_t len = 0;
  const char *str = WFClient::getBlackList(refresh, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result(ObjectFromJsonString(json_str));
}

- (void)handleSetBlackList:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string user_id = GetString(args, @"userId");
  bool is_black_listed = GetBool(args, @"isBlackListed", false);
  WFClient::setBlackList(user_id.c_str(), user_id.size(), is_black_listed,
                         OnGeneralVoidSuccess, OnGeneralError,
                         reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleGetGroupMembers:(NSDictionary *)args result:(FlutterResult)result {
  std::string group_id = GetString(args, @"groupId");
  bool refresh = GetBool(args, @"refresh", false);
  size_t len = 0;
  const char *str = WFClient::getGroupMembers(group_id.c_str(), group_id.size(),
                                              refresh, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result(ObjectFromJsonString(json_str));
}

- (void)handleGetGroupMembersByCount:(NSDictionary *)args result:(FlutterResult)result {
  std::string group_id = GetString(args, @"groupId");
  int count = static_cast<int>(GetInt(args, @"count", 0));
  size_t len = 0;
  const char *str = WFClient::getGroupMembersByCount(
      group_id.c_str(), group_id.size(), count, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result(ObjectFromJsonString(json_str));
}

- (void)handleGetGroupMembersByTypes:(NSDictionary *)args result:(FlutterResult)result {
  std::string group_id = GetString(args, @"groupId");
  int member_type = static_cast<int>(GetInt(args, @"memberType", 0));
  size_t len = 0;
  const char *str = WFClient::getGroupMembersByType(
      group_id.c_str(), group_id.size(), member_type, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result(ObjectFromJsonString(json_str));
}

- (void)handleGetGroupMembersAsync:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string group_id = GetString(args, @"groupId");
  bool refresh = GetBool(args, @"refresh", false);
  size_t len = 0;
  const char *str = WFClient::getGroupMembers(group_id.c_str(), group_id.size(),
                                              refresh, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  id value = ObjectFromJsonString(json_str);
  NSArray *members = nil;
  if ([value isKindOfClass:[NSArray class]]) {
    members = value;
  } else {
    members = @[];
  }
  InvokeDartMethod(@"getGroupMembersAsyncCallback",
                   @{@"requestId": @(request_id),
                     @"members": members});
  result(nil);
}

- (void)handleGetGroupInfo:(NSDictionary *)args result:(FlutterResult)result {
  std::string group_id = GetString(args, @"groupId");
  bool refresh = GetBool(args, @"refresh", false);
  size_t len = 0;
  const char *str = WFClient::getGroupInfo(group_id.c_str(), group_id.size(),
                                           refresh, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result(ObjectFromJsonString(json_str));
}

- (void)handleGetGroupInfos:(NSDictionary *)args result:(FlutterResult)result {
  std::vector<std::string> group_ids = GetStringList(args, @"groupIds");
  NSMutableArray *groups = [NSMutableArray array];
  for (const auto &group_id : group_ids) {
    size_t len = 0;
    const char *str = WFClient::getGroupInfo(group_id.c_str(), group_id.size(),
                                             false, &len);
    std::string json_str = ConvertDllStringAndRelease(str, len);
    id obj = ObjectFromJsonString(json_str);
    if (obj) {
      [groups addObject:obj];
    } else {
      [groups addObject:[NSNull null]];
    }
  }
  result(groups);
}

- (void)handleGetGroupInfoAsync:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string group_id = GetString(args, @"groupId");
  bool refresh = GetBool(args, @"refresh", false);
  size_t len = 0;
  const char *str = WFClient::getGroupInfo(group_id.c_str(), group_id.size(),
                                           refresh, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  InvokeDartMethod(@"getGroupInfoAsyncCallback",
                   @{@"requestId": @(request_id),
                     @"groupInfo": ObjectFromJsonString(json_str) ?: [NSNull null]});
  result(nil);
}

- (void)handleGetGroupMember:(NSDictionary *)args result:(FlutterResult)result {
  std::string group_id = GetString(args, @"groupId");
  std::string member_id = GetString(args, @"memberId");
  size_t len = 0;
  const char *str = WFClient::getGroupMember(group_id.c_str(), group_id.size(),
                                             member_id.c_str(),
                                             member_id.size(), &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result(ObjectFromJsonString(json_str));
}

- (void)handleCreateGroup:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string group_id = GetString(args, @"groupId");
  std::string group_name = GetString(args, @"groupName");
  std::string group_portrait = GetString(args, @"groupPortrait");
  int group_type = static_cast<int>(GetInt(args, @"type", 0));
  std::vector<std::string> members = GetStringList(args, @"groupMembers");
  std::vector<const char *> user_ptrs;
  std::vector<size_t> user_lengths;
  for (const auto &u : members) {
    user_ptrs.push_back(u.c_str());
    user_lengths.push_back(u.size());
  }
  std::vector<int> lines = GetIntList(args, @"notifyLines");
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
  result(nil);
}

- (void)handleAddGroupMembers:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string group_id = GetString(args, @"groupId");
  std::vector<std::string> members = GetStringList(args, @"groupMembers");
  std::vector<const char *> user_ptrs;
  std::vector<size_t> user_lengths;
  for (const auto &u : members) {
    user_ptrs.push_back(u.c_str());
    user_lengths.push_back(u.size());
  }
  std::vector<int> lines = GetIntList(args, @"notifyLines");
  if (lines.empty()) lines.push_back(0);
  std::string notify_content = BuildNotifyContentJson(args);

  WFClient::addMembers(
      group_id.c_str(), group_id.size(),
      user_ptrs.empty() ? nullptr : user_ptrs.data(),
      user_lengths.empty() ? nullptr : user_lengths.data(), members.size(),
      "", 0, lines.data(), static_cast<int>(lines.size()),
      notify_content.c_str(), notify_content.size(), OnGeneralVoidSuccess,
      OnGeneralError, reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleKickoffGroupMembers:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string group_id = GetString(args, @"groupId");
  std::vector<std::string> members = GetStringList(args, @"groupMembers");
  std::vector<const char *> user_ptrs;
  std::vector<size_t> user_lengths;
  for (const auto &u : members) {
    user_ptrs.push_back(u.c_str());
    user_lengths.push_back(u.size());
  }
  std::vector<int> lines = GetIntList(args, @"notifyLines");
  if (lines.empty()) lines.push_back(0);
  std::string notify_content = BuildNotifyContentJson(args);

  WFClient::kickoffMembers(
      group_id.c_str(), group_id.size(),
      user_ptrs.empty() ? nullptr : user_ptrs.data(),
      user_lengths.empty() ? nullptr : user_lengths.data(), members.size(),
      lines.data(), static_cast<int>(lines.size()),
      notify_content.c_str(), notify_content.size(), OnGeneralVoidSuccess,
      OnGeneralError, reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleQuitGroup:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string group_id = GetString(args, @"groupId");
  std::vector<int> lines = GetIntList(args, @"notifyLines");
  if (lines.empty()) lines.push_back(0);
  std::string notify_content = BuildNotifyContentJson(args);

  WFClient::quitGroup(group_id.c_str(), group_id.size(), lines.data(),
                      static_cast<int>(lines.size()),
                      notify_content.c_str(), notify_content.size(),
                      OnGeneralVoidSuccess, OnGeneralError,
                      reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleQuitGroupEx:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string group_id = GetString(args, @"groupId");
  std::vector<int> lines = GetIntList(args, @"notifyLines");
  if (lines.empty()) lines.push_back(0);
  std::string notify_content = BuildNotifyContentJson(args);
  WFClient::quitGroup(group_id.c_str(), group_id.size(), lines.data(),
                      static_cast<int>(lines.size()),
                      notify_content.c_str(), notify_content.size(),
                      OnGeneralVoidSuccess, OnGeneralError,
                      reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleDismissGroup:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string group_id = GetString(args, @"groupId");
  std::vector<int> lines = GetIntList(args, @"notifyLines");
  if (lines.empty()) lines.push_back(0);
  std::string notify_content = BuildNotifyContentJson(args);

  WFClient::dismissGroup(group_id.c_str(), group_id.size(), lines.data(),
                         static_cast<int>(lines.size()),
                         notify_content.c_str(), notify_content.size(),
                         OnGeneralVoidSuccess, OnGeneralError,
                         reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleModifyGroupInfo:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string group_id = GetString(args, @"groupId");
  int modify_type = static_cast<int>(GetInt(args, @"modifyType", 0));
  std::string value = GetString(args, @"value");
  std::vector<int> lines = GetIntList(args, @"notifyLines");
  if (lines.empty()) lines.push_back(0);
  std::string notify_content = BuildNotifyContentJson(args);

  WFClient::modifyGroupInfo(group_id.c_str(), group_id.size(), modify_type,
                            value.c_str(), value.size(), lines.data(),
                            static_cast<int>(lines.size()),
                            notify_content.c_str(), notify_content.size(),
                            OnGeneralVoidSuccess, OnGeneralError,
                            reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleModifyGroupAlias:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string group_id = GetString(args, @"groupId");
  std::string new_alias = GetString(args, @"newAlias");
  std::vector<int> lines = GetIntList(args, @"notifyLines");
  if (lines.empty()) lines.push_back(0);
  std::string notify_content = BuildNotifyContentJson(args);

  WFClient::modifyGroupAlias(group_id.c_str(), group_id.size(),
                             new_alias.c_str(), new_alias.size(), lines.data(),
                             static_cast<int>(lines.size()),
                             notify_content.c_str(), notify_content.size(),
                             OnGeneralVoidSuccess, OnGeneralError,
                             reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleModifyGroupMemberAlias:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string group_id = GetString(args, @"groupId");
  std::string member_id = GetString(args, @"memberId");
  std::string new_alias = GetString(args, @"newAlias");
  std::vector<int> lines = GetIntList(args, @"notifyLines");
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
  result(nil);
}

- (void)handleTransferGroup:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string group_id = GetString(args, @"groupId");
  std::string new_owner = GetString(args, @"newOwner");
  std::vector<int> lines = GetIntList(args, @"notifyLines");
  if (lines.empty()) lines.push_back(0);
  std::string notify_content = BuildNotifyContentJson(args);

  WFClient::transferGroup(group_id.c_str(), group_id.size(),
                          new_owner.c_str(), new_owner.size(), lines.data(),
                          static_cast<int>(lines.size()),
                          notify_content.c_str(), notify_content.size(),
                          OnGeneralVoidSuccess, OnGeneralError,
                          reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleSetGroupManager:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string group_id = GetString(args, @"groupId");
  bool is_set = GetBool(args, @"isSet", false);
  std::vector<std::string> member_ids = GetStringList(args, @"memberIds");
  std::vector<const char *> user_ptrs;
  std::vector<size_t> user_lengths;
  for (const auto &u : member_ids) {
    user_ptrs.push_back(u.c_str());
    user_lengths.push_back(u.size());
  }
  std::vector<int> lines = GetIntList(args, @"notifyLines");
  if (lines.empty()) lines.push_back(0);
  std::string notify_content = BuildNotifyContentJson(args);

  WFClient::setGroupManager(
      group_id.c_str(), group_id.size(), is_set,
      user_ptrs.empty() ? nullptr : user_ptrs.data(),
      user_lengths.empty() ? nullptr : user_lengths.data(), member_ids.size(),
      lines.data(), static_cast<int>(lines.size()),
      notify_content.c_str(), notify_content.size(), OnGeneralVoidSuccess,
      OnGeneralError, reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleMuteGroupMember:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string group_id = GetString(args, @"groupId");
  bool is_set = GetBool(args, @"isSet", false);
  std::vector<std::string> member_ids = GetStringList(args, @"memberIds");
  std::vector<const char *> user_ptrs;
  std::vector<size_t> user_lengths;
  for (const auto &u : member_ids) {
    user_ptrs.push_back(u.c_str());
    user_lengths.push_back(u.size());
  }
  std::vector<int> lines = GetIntList(args, @"notifyLines");
  if (lines.empty()) lines.push_back(0);
  std::string notify_content = BuildNotifyContentJson(args);

  WFClient::muteGroupMember(
      group_id.c_str(), group_id.size(), is_set,
      user_ptrs.empty() ? nullptr : user_ptrs.data(),
      user_lengths.empty() ? nullptr : user_lengths.data(), member_ids.size(),
      lines.data(), static_cast<int>(lines.size()),
      notify_content.c_str(), notify_content.size(), OnGeneralVoidSuccess,
      OnGeneralError, reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleAllowGroupMember:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string group_id = GetString(args, @"groupId");
  bool is_set = GetBool(args, @"isSet", false);
  std::vector<std::string> member_ids = GetStringList(args, @"memberIds");
  std::vector<const char *> user_ptrs;
  std::vector<size_t> user_lengths;
  for (const auto &u : member_ids) {
    user_ptrs.push_back(u.c_str());
    user_lengths.push_back(u.size());
  }
  std::vector<int> lines = GetIntList(args, @"notifyLines");
  if (lines.empty()) lines.push_back(0);
  std::string notify_content = BuildNotifyContentJson(args);

  WFClient::allowGroupMember(
      group_id.c_str(), group_id.size(), is_set,
      user_ptrs.empty() ? nullptr : user_ptrs.data(),
      user_lengths.empty() ? nullptr : user_lengths.data(), member_ids.size(),
      lines.data(), static_cast<int>(lines.size()),
      notify_content.c_str(), notify_content.size(), OnGeneralVoidSuccess,
      OnGeneralError, reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleGetGroupRemark:(NSDictionary *)args result:(FlutterResult)result {
  std::string group_id = GetString(args, @"groupId");
  size_t len = 0;
  const char *str = WFClient::getGroupRemark(group_id.c_str(),
                                             group_id.size(), &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result(ObjectFromJsonString(json_str));
}

- (void)handleSetGroupRemark:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string group_id = GetString(args, @"groupId");
  std::string remark = GetString(args, @"remark");
  WFClient::setGroupRemark(
      group_id.c_str(), group_id.size(), remark.c_str(), remark.size(),
      OnGeneralVoidSuccess, OnGeneralError,
      reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleGetFavGroups:(NSDictionary *)args result:(FlutterResult)result {
  size_t len = 0;
  const char *str = WFClient::getFavGroups(&len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result(ObjectFromJsonString(json_str));
}

- (void)handleIsFavGroup:(NSDictionary *)args result:(FlutterResult)result {
  std::string group_id = GetString(args, @"groupId");
  result(@(WFClient::isFavGroup(group_id.c_str(), group_id.size())));
}

- (void)handleSetFavGroup:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string group_id = GetString(args, @"groupId");
  bool fav = GetBool(args, @"isFav", false);
  WFClient::setFavGroup(group_id.c_str(), group_id.size(), fav,
                        OnGeneralVoidSuccess, OnGeneralError,
                        reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleGetUserSetting:(NSDictionary *)args result:(FlutterResult)result {
  int scope = static_cast<int>(GetInt(args, @"scope", 0));
  std::string key = GetString(args, @"key");
  size_t len = 0;
  const char *str = WFClient::getUserSetting(scope, key.c_str(), key.size(),
                                             &len);
  std::string value = ConvertDllStringAndRelease(str, len);
  result([NSString stringWithUTF8String:value.c_str()]);
}

- (void)handleGetUserSettings:(NSDictionary *)args result:(FlutterResult)result {
  int scope = static_cast<int>(GetInt(args, @"scope", 0));
  size_t len = 0;
  const char *str = WFClient::getUserSettings(scope, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result(ObjectFromJsonString(json_str));
}

- (void)handleSetUserSetting:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  int scope = static_cast<int>(GetInt(args, @"scope", 0));
  std::string key = GetString(args, @"key");
  std::string value = GetString(args, @"value");
  WFClient::setUserSetting(scope, key.c_str(), key.size(), value.c_str(),
                           value.size(), OnGeneralVoidSuccess, OnGeneralError,
                           reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleModifyMyInfo:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  NSDictionary *values = GetMap(args, @"values");
  for (id key in values) {
    int type = 0;
    if ([key isKindOfClass:[NSNumber class]]) {
      type = [key intValue];
    }
    id value_obj = values[key];
    std::string value;
    if ([value_obj isKindOfClass:[NSString class]]) {
      value = [value_obj UTF8String];
    }
    if (!value.empty()) {
      WFClient::modifyMyInfo(type, value.c_str(), value.size(),
                             OnGeneralVoidSuccess, OnGeneralError,
                             reinterpret_cast<void *>(request_id), 0);
    }
  }
  result(nil);
}

- (void)handleIsGlobalSilent:(NSDictionary *)args result:(FlutterResult)result {
  result(@(WFClient::isGlobalSilent()));
}

- (void)handleSetGlobalSilent:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  bool is_silent = GetBool(args, @"isSilent", false);
  WFClient::setGlobalSilent(is_silent, OnGeneralVoidSuccess, OnGeneralError,
                            reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleIsVoipNotificationSilent:(NSDictionary *)args result:(FlutterResult)result {
  result(@NO);
}

- (void)handleSetVoipNotificationSilent:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  // PC 端不处理 VoIP 通知静音，直接返回成功。
  InvokeDartMethod(@"onOperationVoidSuccess",
                   @{@"requestId": @(request_id)});
  result(nil);
}

- (void)handleIsEnableSyncDraft:(NSDictionary *)args result:(FlutterResult)result {
  result(@(WFClient::isEnableSyncDraft()));
}

- (void)handleSetEnableSyncDraft:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  // PC SDK 没有 setEnableSyncDraft，直接返回成功。
  InvokeDartMethod(@"onOperationVoidSuccess",
                   @{@"requestId": @(request_id)});
  result(nil);
}

- (void)handleGetNoDisturbingTimes:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  // PC 端不处理免打扰时段，返回 0:0。
  InvokeDartMethod(@"onOperationIntPairSuccess",
                   @{@"requestId": @(request_id),
                     @"first": @0,
                     @"second": @0});
  result(nil);
}

- (void)handleSetNoDisturbingTimes:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  // PC 端不处理免打扰时段，直接返回成功。
  InvokeDartMethod(@"onOperationVoidSuccess",
                   @{@"requestId": @(request_id)});
  result(nil);
}

- (void)handleClearNoDisturbingTimes:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  // PC 端不处理免打扰时段，直接返回成功。
  InvokeDartMethod(@"onOperationVoidSuccess",
                   @{@"requestId": @(request_id)});
  result(nil);
}

- (void)handleIsNoDisturbing:(NSDictionary *)args result:(FlutterResult)result {
  result(@NO);
}

- (void)handleIsHiddenNotificationDetail:(NSDictionary *)args result:(FlutterResult)result {
  result(@(WFClient::isHiddenNotificationDetail()));
}

- (void)handleSetHiddenNotificationDetail:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  bool is_hidden = GetBool(args, @"isHidden", false);
  WFClient::setHiddenNotificationDetail(is_hidden, OnGeneralVoidSuccess,
                                        OnGeneralError,
                                        reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleIsHiddenGroupMemberName:(NSDictionary *)args result:(FlutterResult)result {
  std::string group_id = GetString(args, @"groupId");
  result(@(WFClient::isHiddenGroupMemberName(group_id.c_str(), group_id.size())));
}

- (void)handleSetHiddenGroupMemberName:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string group_id = GetString(args, @"groupId");
  bool is_hidden = GetBool(args, @"isHidden", false);
  WFClient::setHiddenGroupMemberName(group_id.c_str(), group_id.size(),
                                     is_hidden, OnGeneralVoidSuccess,
                                     OnGeneralError,
                                     reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleGetMyGroups:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  WFClient::getMyGroups(OnGeneralStringSuccess, OnGeneralError,
                        reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleGetCommonGroups:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string user_id = GetString(args, @"userId");
  WFClient::getCommonGroups(user_id.c_str(), user_id.size(),
                            OnGeneralStringSuccess, OnGeneralError,
                            reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleIsUserEnableReceipt:(NSDictionary *)args result:(FlutterResult)result {
  result(@(WFClient::isUserEnableReceipt()));
}

- (void)handleSetUserEnableReceipt:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  bool is_enable = GetBool(args, @"isEnable", false);
  WFClient::setUserEnableReceipt(
      is_enable, OnGeneralVoidSuccess, OnGeneralError,
      reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleGetFavUsers:(NSDictionary *)args result:(FlutterResult)result {
  size_t len = 0;
  const char *str = WFClient::getFavUsers(&len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result(ObjectFromJsonString(json_str));
}

- (void)handleIsFavUser:(NSDictionary *)args result:(FlutterResult)result {
  std::string user_id = GetString(args, @"userId");
  result(@(WFClient::isFavUser(user_id.c_str(), user_id.size())));
}

- (void)handleSetFavUser:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string user_id = GetString(args, @"userId");
  bool is_fav = GetBool(args, @"isFav", false);
  WFClient::setFavUser(user_id.c_str(), user_id.size(), is_fav,
                       OnGeneralVoidSuccess, OnGeneralError,
                       reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleJoinChatroom:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string chatroom_id = GetString(args, @"chatroomId");
  WFClient::joinChatroom(chatroom_id.c_str(), chatroom_id.size(),
                         OnGeneralVoidSuccess, OnGeneralError,
                         reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleQuitChatroom:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string chatroom_id = GetString(args, @"chatroomId");
  WFClient::quitChatroom(chatroom_id.c_str(), chatroom_id.size(),
                         OnGeneralVoidSuccess, OnGeneralError,
                         reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleGetChatroomInfo:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string chatroom_id = GetString(args, @"chatroomId");
  int64_t update_dt = GetInt(args, @"updateDt", 0);
  WFClient::getChatroomInfo(chatroom_id.c_str(), chatroom_id.size(), update_dt,
                            OnChatroomInfoSuccess, OnGeneralError,
                            reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleGetChatroomMemberInfo:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string chatroom_id = GetString(args, @"chatroomId");
  WFClient::getChatroomMemberInfo(chatroom_id.c_str(), chatroom_id.size(), 0,
                                  OnChatroomMemberInfoSuccess, OnGeneralError,
                                  reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleGetJoinedChatroomId:(NSDictionary *)args result:(FlutterResult)result {
  size_t len = 0;
  const char *str = WFClient::getJoinedChatroomId(&len);
  std::string chatroom_id = ConvertDllStringAndRelease(str, len);
  result([NSString stringWithUTF8String:chatroom_id.c_str()]);
}

- (void)handleCreateChannel:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string name = GetString(args, @"name");
  std::string portrait = GetString(args, @"portrait");
  std::string desc = GetString(args, @"desc");
  std::string extra = GetString(args, @"extra");
  WFClient::createChannel(name.c_str(), name.size(), portrait.c_str(),
                          portrait.size(), desc.c_str(), desc.size(),
                          extra.c_str(), extra.size(), OnCreateChannelSuccess,
                          OnGeneralError, reinterpret_cast<void *>(request_id),
                          0);
  result(nil);
}

- (void)handleGetChannelInfo:(NSDictionary *)args result:(FlutterResult)result {
  std::string channel_id = GetString(args, @"channelId");
  bool refresh = GetBool(args, @"refresh", false);
  size_t len = 0;
  const char *str = WFClient::getChannelInfo(channel_id.c_str(),
                                             channel_id.size(), refresh, &len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result(ObjectFromJsonString(json_str));
}

- (void)handleModifyChannelInfo:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string channel_id = GetString(args, @"channelId");
  int type = static_cast<int>(GetInt(args, @"type", 0));
  std::string new_value = GetString(args, @"newValue");
  WFClient::modifyChannelInfo(channel_id.c_str(), channel_id.size(), type,
                              new_value.c_str(), new_value.size(),
                              OnGeneralVoidSuccess, OnGeneralError,
                              reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleSearchChannel:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string keyword = GetString(args, @"keyword");
  WFClient::searchChannel(keyword.c_str(), keyword.size(),
                          OnSearchChannelSuccess, OnGeneralError,
                          reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleIsListenedChannel:(NSDictionary *)args result:(FlutterResult)result {
  std::string channel_id = GetString(args, @"channelId");
  result(@(WFClient::isListenedChannel(channel_id.c_str(), channel_id.size())));
}

- (void)handleListenChannel:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string channel_id = GetString(args, @"channelId");
  bool listen = GetBool(args, @"listen", false);
  WFClient::listenChannel(channel_id.c_str(), channel_id.size(), listen,
                          OnGeneralVoidSuccess, OnGeneralError,
                          reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleGetMyChannels:(NSDictionary *)args result:(FlutterResult)result {
  size_t len = 0;
  const char *str = WFClient::getMyChannels(&len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result(ObjectFromJsonString(json_str));
}

- (void)handleGetRemoteListenedChannels:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  size_t len = 0;
  const char *str = WFClient::getListenedChannels(&len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  id value = ObjectFromJsonString(json_str);
  NSArray *channels = nil;
  if ([value isKindOfClass:[NSArray class]]) {
    channels = value;
  } else {
    channels = @[];
  }
  InvokeDartMethod(@"onOperationStringListSuccess",
                   @{@"requestId": @(request_id),
                     @"strings": channels});
  result(nil);
}

- (void)handleDestroyChannel:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string channel_id = GetString(args, @"channelId");
  WFClient::destoryChannel(channel_id.c_str(), channel_id.size(),
                           OnGeneralVoidSuccess, OnGeneralError,
                           reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleGetOnlineInfos:(NSDictionary *)args result:(FlutterResult)result {
  // PC 端在线状态功能在 macOS 桌面端暂未实现，返回空列表避免 Dart 端崩溃。
  result(@[]);
}

- (void)handleKickoffPCClient:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  // PC 端自身不需要被踢掉，直接返回成功。
  InvokeDartMethod(@"onOperationVoidSuccess",
                   @{@"requestId": @(request_id)});
  result(nil);
}

- (void)handleIsMuteNotificationWhenPcOnline:(NSDictionary *)args result:(FlutterResult)result {
  result(@NO);
}

- (void)handleSetDefaultSilentWhenPcOnline:(NSDictionary *)args result:(FlutterResult)result {
  // PC 端无需处理手机通知静音，直接返回成功。
  result(nil);
}

- (void)handleMuteNotificationWhenPcOnline:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  // PC 端无需处理，直接返回成功。
  InvokeDartMethod(@"onOperationVoidSuccess",
                   @{@"requestId": @(request_id)});
  result(nil);
}

- (void)handleGetUserOnlineState:(NSDictionary *)args result:(FlutterResult)result {
  // PC SDK 没有直接获取单个用户在线状态的接口，返回 null。
  result([NSNull null]);
}

- (void)handleGetMyCustomState:(NSDictionary *)args result:(FlutterResult)result {
  size_t len = 0;
  const char *str = WFClient::getMyCustomState(&len);
  std::string json_str = ConvertDllStringAndRelease(str, len);
  result(ObjectFromJsonString(json_str));
}

- (void)handleSetMyCustomState:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  int custom_state = static_cast<int>(GetInt(args, @"customState", 0));
  std::string custom_text = GetString(args, @"customText");
  NSMutableDictionary *state_dict = [NSMutableDictionary dictionary];
  state_dict[@"state"] = @(custom_state);
  state_dict[@"text"] = [NSString stringWithUTF8String:custom_text.c_str()];
  std::string state_json = JsonStringFromObject(state_dict);
  WFClient::setMyCustomState(
      state_json.c_str(), state_json.size(), OnGeneralVoidSuccess,
      OnGeneralError, reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleWatchOnlineState:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  int conversation_type = static_cast<int>(GetInt(args, @"conversationType", 0));
  std::vector<std::string> targets = GetStringList(args, @"targets");
  int watch_duration = static_cast<int>(GetInt(args, @"watchDuration", 0));
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
  result(nil);
}

- (void)handleUnwatchOnlineState:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  int conversation_type = static_cast<int>(GetInt(args, @"conversationType", 0));
  std::vector<std::string> targets = GetStringList(args, @"targets");
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
  result(nil);
}

- (void)handleIsEnableUserOnlineState:(NSDictionary *)args result:(FlutterResult)result {
  result(@(WFClient::isEnableUserOnlineState()));
}

- (void)handleSendConferenceRequest:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  int64_t session_id = GetInt(args, @"sessionId", 0);
  std::string room_id = GetString(args, @"roomId");
  std::string request = GetString(args, @"request");
  bool advanced = GetBool(args, @"advanced", false);
  std::string data = GetString(args, @"data");
  WFClient::sendConferenceRequest(
      session_id, room_id.c_str(), room_id.size(), request.c_str(),
      request.size(), advanced, data.c_str(), data.size(),
      OnGeneralStringSuccess, OnGeneralError,
      reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleGetConversationFiles:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  Conversation conv(args);
  std::string from_user = GetString(args, @"fromUser");
  int64_t message_uid = GetInt(args, @"beforeMessageUid", 0);
  int order = static_cast<int>(GetInt(args, @"order", 0));
  int count = static_cast<int>(GetInt(args, @"count", 0));
  WFClient::getConversationFiles(
      conv.conversation_type, conv.target.c_str(), conv.target.size(),
      conv.line, from_user.c_str(), from_user.size(), message_uid, order,
      count, OnFilesResult, OnGeneralError,
      reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleGetMyFiles:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  int64_t message_uid = GetInt(args, @"beforeMessageUid", 0);
  int order = static_cast<int>(GetInt(args, @"order", 0));
  int count = static_cast<int>(GetInt(args, @"count", 0));
  WFClient::getMyFiles(message_uid, order, count, OnFilesResult,
                       OnGeneralError,
                       reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleDeleteFileRecord:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  int64_t message_uid = GetInt(args, @"messageUid", 0);
  WFClient::deleteFileRecord(message_uid, OnGeneralVoidSuccess, OnGeneralError,
                             reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleSearchFiles:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string keyword = GetString(args, @"keyword");
  Conversation conv(args);
  std::string from_user = GetString(args, @"fromUser");
  int64_t message_uid = GetInt(args, @"beforeMessageUid", 0);
  int order = static_cast<int>(GetInt(args, @"order", 0));
  int count = static_cast<int>(GetInt(args, @"count", 0));
  WFClient::searchFiles(
      keyword.c_str(), keyword.size(), conv.conversation_type,
      conv.target.c_str(), conv.target.size(), conv.line,
      from_user.c_str(), from_user.size(), message_uid, order, count,
      OnFilesResult, OnGeneralError,
      reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleSearchMyFiles:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string keyword = GetString(args, @"keyword");
  int64_t message_uid = GetInt(args, @"beforeMessageUid", 0);
  int order = static_cast<int>(GetInt(args, @"order", 0));
  int count = static_cast<int>(GetInt(args, @"count", 0));
  WFClient::searchMyFiles(keyword.c_str(), keyword.size(), message_uid, order,
                          count, OnFilesResult, OnGeneralError,
                          reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleGetAuthCode:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string application_id = GetString(args, @"applicationId");
  int type = static_cast<int>(GetInt(args, @"type", 0));
  std::string host = GetString(args, @"host");
  WFClient::getAuthCode(application_id.c_str(), application_id.size(), type,
                        host.c_str(), host.size(), OnGeneralStringSuccess,
                        OnGeneralError,
                        reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleConfigApplication:(NSDictionary *)args result:(FlutterResult)result {
  int64_t request_id = GetInt(args, @"requestId", 0);
  std::string application_id = GetString(args, @"applicationId");
  int type = static_cast<int>(GetInt(args, @"type", 0));
  int64_t timestamp = GetInt(args, @"timestamp", 0);
  std::string nonce = GetString(args, @"nonce");
  std::string signature = GetString(args, @"signature");
  WFClient::configApplication(
      application_id.c_str(), application_id.size(), type, timestamp,
      nonce.c_str(), nonce.size(), signature.c_str(), signature.size(),
      OnGeneralVoidSuccess, OnGeneralError,
      reinterpret_cast<void *>(request_id), 0);
  result(nil);
}

- (void)handleGetWavData:(NSDictionary *)args result:(FlutterResult)result {
  // PC SDK has no AMR to WAV conversion; return empty data.
  result([FlutterStandardTypedData typedDataWithBytes:[NSData data]]);
}

- (void)handleBeginTransaction:(NSDictionary *)args result:(FlutterResult)result {
  result(@(WFClient::beginTransaction()));
}

- (void)handleCommitTransaction:(NSDictionary *)args result:(FlutterResult)result {
  result(@(WFClient::commitTransaction()));
}

- (void)handleRollbackTransaction:(NSDictionary *)args result:(FlutterResult)result {
  result(@(WFClient::rollbackTransaction()));
}

- (void)handleIsCommercialServer:(NSDictionary *)args result:(FlutterResult)result {
  result(@(WFClient::isCommercialServer()));
}

- (void)handleIsReceiptEnabled:(NSDictionary *)args result:(FlutterResult)result {
  result(@(WFClient::isReceiptEnabled()));
}

- (void)handleIsGroupReceiptEnabled:(NSDictionary *)args result:(FlutterResult)result {
  result(@(WFClient::isGroupReceiptEnabled()));
}

- (void)handleIsGlobalDisableSyncDraft:(NSDictionary *)args result:(FlutterResult)result {
  result(@(WFClient::isGlobalDisableSyncDraft()));
}

- (void)dealloc {
  SetChannel(nil);
}

@end
