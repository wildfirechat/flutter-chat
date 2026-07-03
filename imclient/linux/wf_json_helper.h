#ifndef WF_JSON_HELPER_H_
#define WF_JSON_HELPER_H_

#include <flutter/encodable_value.h>

#include <nlohmann/json.hpp>

#include <string>
#include <vector>

namespace imclient {

using json = nlohmann::json;
using EncodableValue = flutter::EncodableValue;
using EncodableMap = flutter::EncodableMap;
using EncodableList = flutter::EncodableList;

// Convert JSON string to EncodableValue (object/array/primitive).
EncodableValue JsonToEncodable(const std::string &json_str);

// Convert JSON string to EncodableValue, reversing the top-level array order.
EncodableValue ReversedJsonArrayToEncodable(const std::string &json_str);

// Convert EncodableValue to JSON string.
std::string EncodableToJson(const EncodableValue &value);

// Helpers to read from EncodableMap.
std::string GetString(const EncodableMap *map, const std::string &key,
                      const std::string &default_value = "");
int64_t GetInt(const EncodableMap *map, const std::string &key,
               int64_t default_value = 0);
double GetDouble(const EncodableMap *map, const std::string &key,
                 double default_value = 0.0);
bool GetBool(const EncodableMap *map, const std::string &key,
             bool default_value = false);
std::vector<int> GetIntList(const EncodableMap *map, const std::string &key);
std::vector<int64_t> GetInt64List(const EncodableMap *map, const std::string &key);
std::vector<std::string> GetStringList(const EncodableMap *map,
                                          const std::string &key);
EncodableMap GetMap(const EncodableMap *map, const std::string &key);

// Helpers to put into EncodableMap.
void PutString(EncodableMap *map, const std::string &key,
               const std::string &value);
void PutInt(EncodableMap *map, const std::string &key, int64_t value);
void PutBool(EncodableMap *map, const std::string &key, bool value);

// Access a raw value in the map. Returns nullptr if not found.
const EncodableValue *FindRawValue(const EncodableMap *map,
                                   const std::string &key);

// Base64 helpers matching mobile SDK behavior.
std::string Base64Encode(const std::vector<uint8_t> &data);
std::vector<uint8_t> Base64Decode(const std::string &str);

}  // namespace imclient

#endif  // WF_JSON_HELPER_H_
