#ifndef IMC_CLIENT_DESKTOP_PLUGIN_H_
#define IMC_CLIENT_DESKTOP_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_linux.h>

#include <memory>

namespace imclient {

class ImclientPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarLinux *registrar);

  ImclientPlugin();

  virtual ~ImclientPlugin();

  // Disallow copy and assign.
  ImclientPlugin(const ImclientPlugin&) = delete;
  ImclientPlugin& operator=(const ImclientPlugin&) = delete;

 private:
  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

}  // namespace imclient

#endif  // IMC_CLIENT_DESKTOP_PLUGIN_H_
