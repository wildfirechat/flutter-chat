#include "wf_json_helper.h"

#include <algorithm>
#include <cctype>
#include <sstream>

namespace imclient {

namespace {

const EncodableValue *FindValue(const EncodableMap *map, const std::string &key) {
  if (!map) return nullptr;
  auto it = map->find(EncodableValue(key));
  if (it == map->end()) return nullptr;
  return &it->second;
}

json EncodableToJsonInternal(const EncodableValue &value);

json EncodableListToJson(const EncodableList &list) {
  json arr = json::array();
  for (const auto &item : list) {
    arr.push_back(EncodableToJsonInternal(item));
  }
  return arr;
}

json EncodableMapToJson(const EncodableMap &map) {
  json obj = json::object();
  for (const auto &pair : map) {
    const std::string *key = std::get_if<std::string>(&pair.first);
    if (!key) continue;
    obj[*key] = EncodableToJsonInternal(pair.second);
  }
  return obj;
}

json EncodableToJsonInternal(const EncodableValue &value) {
  switch (value.index()) {
    case 0:  // std::monostate (null)
      return nullptr;
    case 1:  // bool
      return std::get<bool>(value);
    case 2:  // int32_t
      return std::get<int32_t>(value);
    case 3:  // int64_t
      return std::get<int64_t>(value);
    case 4:  // double
      return std::get<double>(value);
    case 5:  // std::string
      return std::get<std::string>(value);
    case 6:  // std::vector<uint8_t>
      return Base64Encode(std::get<std::vector<uint8_t>>(value));
    case 7:  // std::vector<int32_t>
      return EncodableListToJson(
          EncodableList(std::get<std::vector<int32_t>>(value).begin(),
                        std::get<std::vector<int32_t>>(value).end()));
    case 8:  // std::vector<int64_t>
      return EncodableListToJson(
          EncodableList(std::get<std::vector<int64_t>>(value).begin(),
                        std::get<std::vector<int64_t>>(value).end()));
    case 9:  // std::vector<double>
      return EncodableListToJson(
          EncodableList(std::get<std::vector<double>>(value).begin(),
                        std::get<std::vector<double>>(value).end()));
    case 10:  // EncodableList
      return EncodableListToJson(std::get<EncodableList>(value));
    case 11:  // EncodableMap
      return EncodableMapToJson(std::get<EncodableMap>(value));
    default:
      return nullptr;
  }
}

EncodableValue JsonToEncodableInternal(const json &j);

EncodableList JsonArrayToEncodable(const json &j) {
  EncodableList list;
  list.reserve(j.size());
  for (const auto &item : j) {
    list.push_back(JsonToEncodableInternal(item));
  }
  return list;
}

EncodableMap JsonObjectToEncodable(const json &j) {
  EncodableMap map;
  for (auto it = j.begin(); it != j.end(); ++it) {
    map[EncodableValue(it.key())] = JsonToEncodableInternal(it.value());
  }
  return map;
}

EncodableValue JsonToEncodableInternal(const json &j) {
  if (j.is_null()) {
    return EncodableValue();
  }
  if (j.is_boolean()) {
    return EncodableValue(j.get<bool>());
  }
  if (j.is_number_integer()) {
    int64_t v = j.get<int64_t>();
    if (v >= INT32_MIN && v <= INT32_MAX) {
      return EncodableValue(static_cast<int32_t>(v));
    }
    return EncodableValue(v);
  }
  if (j.is_number_float()) {
    return EncodableValue(j.get<double>());
  }
  if (j.is_string()) {
    return EncodableValue(j.get<std::string>());
  }
  if (j.is_array()) {
    return EncodableValue(JsonArrayToEncodable(j));
  }
  if (j.is_object()) {
    return EncodableValue(JsonObjectToEncodable(j));
  }
  return EncodableValue();
}

}  // namespace

EncodableValue JsonToEncodable(const std::string &json_str) {
  try {
    json j = json::parse(json_str);
    return JsonToEncodableInternal(j);
  } catch (...) {
    return EncodableValue();
  }
}

EncodableValue ReversedJsonArrayToEncodable(const std::string &json_str) {
  try {
    json j = json::parse(json_str);
    if (j.is_array()) {
      EncodableList list;
      list.reserve(j.size());
      for (auto it = j.rbegin(); it != j.rend(); ++it) {
        list.push_back(JsonToEncodableInternal(*it));
      }
      return EncodableValue(list);
    }
    return JsonToEncodableInternal(j);
  } catch (...) {
    return EncodableValue();
  }
}

std::string EncodableToJson(const EncodableValue &value) {
  return EncodableToJsonInternal(value).dump();
}

std::string GetString(const EncodableMap *map, const std::string &key,
                      const std::string &default_value) {
  const EncodableValue *value = FindValue(map, key);
  if (!value) return default_value;
  const std::string *str = std::get_if<std::string>(value);
  return str ? *str : default_value;
}

int64_t GetInt(const EncodableMap *map, const std::string &key,
               int64_t default_value) {
  const EncodableValue *value = FindValue(map, key);
  if (!value) return default_value;
  if (const int32_t *v = std::get_if<int32_t>(value)) return *v;
  if (const int64_t *v = std::get_if<int64_t>(value)) return *v;
  return default_value;
}

double GetDouble(const EncodableMap *map, const std::string &key,
                 double default_value) {
  const EncodableValue *value = FindValue(map, key);
  if (!value) return default_value;
  if (const double *v = std::get_if<double>(value)) return *v;
  if (const int32_t *v = std::get_if<int32_t>(value)) return *v;
  if (const int64_t *v = std::get_if<int64_t>(value)) return *v;
  return default_value;
}

bool GetBool(const EncodableMap *map, const std::string &key,
             bool default_value) {
  const EncodableValue *value = FindValue(map, key);
  if (!value) return default_value;
  const bool *v = std::get_if<bool>(value);
  return v ? *v : default_value;
}

std::vector<int> GetIntList(const EncodableMap *map, const std::string &key) {
  std::vector<int> result;
  const EncodableValue *value = FindValue(map, key);
  if (!value) return result;
  const EncodableList *list = std::get_if<EncodableList>(value);
  if (!list) {
    const std::vector<int32_t> *ivec = std::get_if<std::vector<int32_t>>(value);
    if (ivec) {
      result.assign(ivec->begin(), ivec->end());
    }
    return result;
  }
  for (const auto &item : *list) {
    if (const int32_t *v = std::get_if<int32_t>(&item)) {
      result.push_back(*v);
    } else if (const int64_t *v = std::get_if<int64_t>(&item)) {
      result.push_back(static_cast<int>(*v));
    }
  }
  return result;
}

std::vector<int64_t> GetInt64List(const EncodableMap *map, const std::string &key) {
  std::vector<int64_t> result;
  const EncodableValue *value = FindValue(map, key);
  if (!value) return result;
  const EncodableList *list = std::get_if<EncodableList>(value);
  if (!list) {
    const std::vector<int64_t> *ivec = std::get_if<std::vector<int64_t>>(value);
    if (ivec) {
      result.assign(ivec->begin(), ivec->end());
    }
    return result;
  }
  for (const auto &item : *list) {
    if (const int32_t *v = std::get_if<int32_t>(&item)) {
      result.push_back(*v);
    } else if (const int64_t *v = std::get_if<int64_t>(&item)) {
      result.push_back(*v);
    }
  }
  return result;
}

std::vector<std::string> GetStringList(const EncodableMap *map,
                                          const std::string &key) {
  std::vector<std::string> result;
  const EncodableValue *value = FindValue(map, key);
  if (!value) return result;
  const EncodableList *list = std::get_if<EncodableList>(value);
  if (!list) return result;
  for (const auto &item : *list) {
    if (const std::string *v = std::get_if<std::string>(&item)) {
      result.push_back(*v);
    }
  }
  return result;
}

EncodableMap GetMap(const EncodableMap *map, const std::string &key) {
  const EncodableValue *value = FindValue(map, key);
  if (!value) return EncodableMap();
  const EncodableMap *m = std::get_if<EncodableMap>(value);
  return m ? *m : EncodableMap();
}

void PutString(EncodableMap *map, const std::string &key,
               const std::string &value) {
  (*map)[EncodableValue(key)] = EncodableValue(value);
}

void PutInt(EncodableMap *map, const std::string &key, int64_t value) {
  if (value >= INT32_MIN && value <= INT32_MAX) {
    (*map)[EncodableValue(key)] = EncodableValue(static_cast<int32_t>(value));
  } else {
    (*map)[EncodableValue(key)] = EncodableValue(value);
  }
}

void PutBool(EncodableMap *map, const std::string &key, bool value) {
  (*map)[EncodableValue(key)] = EncodableValue(value);
}

const EncodableValue *FindRawValue(const EncodableMap *map,
                                   const std::string &key) {
  if (!map) return nullptr;
  auto it = map->find(EncodableValue(key));
  if (it == map->end()) return nullptr;
  return &it->second;
}

std::string Base64Encode(const std::vector<uint8_t> &data) {
  static const char kBase64Chars[] =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  std::string encoded;
  if (data.empty()) return encoded;
  size_t i = 0;
  uint8_t array3[3];
  uint8_t array4[4];
  for (uint8_t byte : data) {
    array3[i++] = byte;
    if (i == 3) {
      array4[0] = (array3[0] & 0xfc) >> 2;
      array4[1] = ((array3[0] & 0x03) << 4) + ((array3[1] & 0xf0) >> 4);
      array4[2] = ((array3[1] & 0x0f) << 2) + ((array3[2] & 0xc0) >> 6);
      array4[3] = array3[2] & 0x3f;
      for (int j = 0; j < 4; j++) encoded += kBase64Chars[array4[j]];
      i = 0;
    }
  }
  if (i) {
    for (int j = i; j < 3; j++) array3[j] = 0;
    array4[0] = (array3[0] & 0xfc) >> 2;
    array4[1] = ((array3[0] & 0x03) << 4) + ((array3[1] & 0xf0) >> 4);
    array4[2] = ((array3[1] & 0x0f) << 2) + ((array3[2] & 0xc0) >> 6);
    for (int j = 0; j < i + 1; j++) encoded += kBase64Chars[array4[j]];
    while (i++ < 3) encoded += '=';
  }
  return encoded;
}

std::vector<uint8_t> Base64Decode(const std::string &str) {
  static const std::string kBase64Chars =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  std::vector<uint8_t> decoded;
  if (str.empty()) return decoded;
  size_t in_len = str.size();
  size_t i = 0;
  int in_ = 0;
  uint8_t array4[4], array3[3];
  while (in_len-- && (str[in_] != '=') &&
         (isalnum(str[in_]) || str[in_] == '+' || str[in_] == '/')) {
    array4[i++] = str[in_];
    in_++;
    if (i == 4) {
      for (int j = 0; j < 4; j++) {
        array4[j] = kBase64Chars.find(array4[j]);
      }
      array3[0] = (array4[0] << 2) + ((array4[1] & 0x30) >> 4);
      array3[1] = ((array4[1] & 0xf) << 4) + ((array4[2] & 0x3c) >> 2);
      array3[2] = ((array4[2] & 0x3) << 6) + array4[3];
      for (int j = 0; j < 3; j++) decoded.push_back(array3[j]);
      i = 0;
    }
  }
  if (i) {
    for (int j = i; j < 4; j++) array4[j] = 0;
    for (int j = 0; j < 4; j++) {
      array4[j] = kBase64Chars.find(array4[j]);
    }
    array3[0] = (array4[0] << 2) + ((array4[1] & 0x30) >> 4);
    array3[1] = ((array4[1] & 0xf) << 4) + ((array4[2] & 0x3c) >> 2);
    if (i == 4) {
      array3[2] = ((array4[2] & 0x3) << 6) + array4[3];
    }
    for (int j = 0; j < i - 1; j++) decoded.push_back(array3[j]);
  }
  return decoded;
}

}  // namespace imclient
