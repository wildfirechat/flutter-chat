#include "wf_client_helper.h"

#include "wf_json_helper.h"

namespace imclient {

Conversation::Conversation(const flutter::EncodableMap *map) {
  if (!map) return;
  // Dart passes conversation as a nested map; fall back to top-level fields.
  const flutter::EncodableMap *source = map;
  const flutter::EncodableValue *conv_value = FindRawValue(map, "conversation");
  if (conv_value) {
    const flutter::EncodableMap *nested =
        std::get_if<flutter::EncodableMap>(conv_value);
    if (nested) source = nested;
  }
  conversation_type = static_cast<int>(GetInt(source, "type"));
  target = GetString(source, "target");
  line = static_cast<int>(GetInt(source, "line"));
}

flutter::EncodableMap Conversation::ToEncodable() const {
  flutter::EncodableMap map;
  map[flutter::EncodableValue("type")] =
      flutter::EncodableValue(conversation_type);
  map[flutter::EncodableValue("target")] = flutter::EncodableValue(target);
  map[flutter::EncodableValue("line")] = flutter::EncodableValue(line);
  return map;
}

MessagePayload::MessagePayload(const flutter::EncodableMap *map) {
  if (!map) return;
  content_type = static_cast<int>(GetInt(map, "type"));
  searchable_content = GetString(map, "searchableContent");
  push_content = GetString(map, "pushContent");
  push_data = GetString(map, "pushData");
  content = GetString(map, "content");
  local_content = GetString(map, "localContent");
  remote_media_url = GetString(map, "remoteMediaUrl");
  local_media_path = GetString(map, "localMediaPath");
  media_type = static_cast<int>(GetInt(map, "mediaType"));
  mentioned_type = static_cast<int>(GetInt(map, "mentionedType"));
  extra = GetString(map, "extra");

  const flutter::EncodableValue *binary_value = FindRawValue(map, "binaryContent");
  if (binary_value) {
    const std::vector<uint8_t> *bytes =
        std::get_if<std::vector<uint8_t>>(binary_value);
    if (bytes) binary_content = *bytes;
  }

  mentioned_targets = GetStringList(map, "mentionedTargets");
}

flutter::EncodableMap MessagePayload::ToEncodable() const {
  flutter::EncodableMap map;
  map[flutter::EncodableValue("type")] =
      flutter::EncodableValue(content_type);
  map[flutter::EncodableValue("searchableContent")] =
      flutter::EncodableValue(searchable_content);
  map[flutter::EncodableValue("pushContent")] =
      flutter::EncodableValue(push_content);
  map[flutter::EncodableValue("pushData")] =
      flutter::EncodableValue(push_data);
  map[flutter::EncodableValue("content")] =
      flutter::EncodableValue(content);
  map[flutter::EncodableValue("binaryContent")] =
      flutter::EncodableValue(Base64Encode(binary_content));
  map[flutter::EncodableValue("localContent")] =
      flutter::EncodableValue(local_content);
  map[flutter::EncodableValue("remoteMediaUrl")] =
      flutter::EncodableValue(remote_media_url);
  map[flutter::EncodableValue("localMediaPath")] =
      flutter::EncodableValue(local_media_path);
  map[flutter::EncodableValue("mediaType")] =
      flutter::EncodableValue(media_type);
  map[flutter::EncodableValue("mentionedType")] =
      flutter::EncodableValue(mentioned_type);
  map[flutter::EncodableValue("mentionedTargets")] =
      flutter::EncodableValue(std::vector<std::string>(mentioned_targets.begin(),
                                                   mentioned_targets.end()));
  map[flutter::EncodableValue("extra")] = flutter::EncodableValue(extra);
  return map;
}

DllString::DllString(const char *str, size_t len) : str_(str), len_(len) {}

DllString::~DllString() { Release(); }

void DllString::Release() {
  if (str_) {
    WFClient::releaseDllString(str_);
    str_ = nullptr;
    len_ = 0;
  }
}

}  // namespace imclient
