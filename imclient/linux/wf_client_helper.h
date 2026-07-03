#ifndef WF_CLIENT_HELPER_H_
#define WF_CLIENT_HELPER_H_

#include <WFClient.h>

#include <flutter/encodable_value.h>

#include <stdint.h>
#include <string>
#include <vector>

namespace imclient {

struct Conversation {
  int conversation_type;
  std::string target;
  int line;

  Conversation() : conversation_type(0), line(0) {}
  explicit Conversation(const flutter::EncodableMap *map);

  flutter::EncodableMap ToEncodable() const;
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

  MessagePayload() : content_type(0), media_type(0), mentioned_type(0) {}
  explicit MessagePayload(const flutter::EncodableMap *map);

  flutter::EncodableMap ToEncodable() const;
};

// Releasable string wrapper for WFClient results that need releaseDllString.
class DllString {
 public:
  explicit DllString(const char *str, size_t len);
  ~DllString();

  const char *c_str() const { return str_; }
  size_t length() const { return len_; }
  std::string ToString() const { return std::string(str_, len_); }

  // Disallow copy.
  DllString(const DllString &) = delete;
  DllString &operator=(const DllString &) = delete;

  // Allow move.
  DllString(DllString &&other) noexcept : str_(other.str_), len_(other.len_) {
    other.str_ = nullptr;
    other.len_ = 0;
  }
  DllString &operator=(DllString &&other) noexcept {
    if (this != &other) {
      Release();
      str_ = other.str_;
      len_ = other.len_;
      other.str_ = nullptr;
      other.len_ = 0;
    }
    return *this;
  }

 private:
  void Release();

  const char *str_;
  size_t len_;
};

}  // namespace imclient

#endif  // WF_CLIENT_HELPER_H_
