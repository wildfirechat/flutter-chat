#include "flutter_webrtc/flutter_web_r_t_c_plugin.h"

#include "flutter_common.h"
#include "flutter_webrtc.h"
#include "task_runner_linux.h"

const char* kChannelName = "FlutterWebRTC.Method";
static flutter_webrtc_plugin::FlutterWebRTC* g_shared_instance = nullptr;
//#if defined(_WINDOWS)

namespace flutter_webrtc_plugin {

// A webrtc plugin for windows/linux.
class FlutterWebRTCPluginImpl : public FlutterWebRTCPlugin {
 public:
  static void RegisterWithRegistrar(PluginRegistrar* registrar) {
    auto channel = std::make_unique<MethodChannel>(
        registrar->messenger(), kChannelName,
        &flutter::StandardMethodCodec::GetInstance());

    auto* channel_pointer = channel.get();

    // Uses new instead of make_unique due to private constructor.
    std::unique_ptr<FlutterWebRTCPluginImpl> plugin(
        new FlutterWebRTCPluginImpl(registrar, std::move(channel)));

    channel_pointer->SetMethodCallHandler(
        [plugin_pointer = plugin.get()](const auto& call, auto result) {
          plugin_pointer->HandleMethodCall(call, std::move(result));
        });

    registrar->AddPlugin(std::move(plugin));
  }

  virtual ~FlutterWebRTCPluginImpl() {}

  BinaryMessenger* messenger() { return messenger_; }

  TextureRegistrar* textures() { return textures_; }

  TaskRunner* task_runner() { return task_runner_.get(); }

 private:
  // Creates a plugin that communicates on the given channel.
  FlutterWebRTCPluginImpl(PluginRegistrar* registrar,
                          std::unique_ptr<MethodChannel> channel)
      : channel_(std::move(channel)),
        messenger_(registrar->messenger()),
        textures_(registrar->texture_registrar()),
        task_runner_(std::make_unique<TaskRunnerLinux>()) {
    webrtc_ = std::make_unique<FlutterWebRTC>(this);
    g_shared_instance = webrtc_.get();
  }

  // Called when a method is called on |channel_|;
  void HandleMethodCall(const MethodCall& method_call,
                        std::unique_ptr<MethodResult> result) {
    // handle method call and forward to webrtc native sdk.
    auto method_call_proxy = MethodCallProxy::Create(method_call);
    webrtc_->HandleMethodCall(*method_call_proxy.get(),
                              MethodResultProxy::Create(std::move(result)));
  }

 private:
  std::unique_ptr<MethodChannel> channel_;
  std::unique_ptr<FlutterWebRTC> webrtc_;
  BinaryMessenger* messenger_;
  TextureRegistrar* textures_;
  std::unique_ptr<TaskRunner> task_runner_;
};

}  // namespace flutter_webrtc_plugin

void flutter_web_r_t_c_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  // 【本地补丁,见 ../PATCHES.md】上游此处为
  //   static auto* plugin_registrar = new flutter::PluginRegistrar(registrar);
  // 函数内 static 只在第一次调用时求值,之后每个引擎都复用第一个引擎(主窗口)的
  // registrar,于是 channel 全部建在主窗口的 messenger 上。本项目用
  // desktop_multi_window 把通话开在独立子窗口(独立 Flutter 引擎)里,子窗口的
  // FlutterWebRTC.Method 因此从未在自己的引擎上注册,Dart 侧一调用就是
  // MissingPluginException。macOS 走 -registerWithRegistrar:、Windows 走
  // PluginRegistrarManager,都是每个 registrar 一份,只有 Linux 有这个问题。
  //
  // 改为每个引擎各建一份 wrapper。刻意不回收(与上游一致):
  // FlutterWebRTCBase 的析构会调用进程级的 LibWebRTC::Terminate(),主窗口实例仍
  // 存活时销毁子窗口实例会把整个进程的 libwebrtc 关掉,代价远大于每个通话窗口
  // 泄漏一份 PeerConnectionFactory。
  auto* plugin_registrar = new flutter::PluginRegistrar(registrar);
  flutter_webrtc_plugin::FlutterWebRTCPluginImpl::RegisterWithRegistrar(
      plugin_registrar);
}

flutter_webrtc_plugin::FlutterWebRTC* flutter_webrtc_plugin_get_shared_instance() {
  return g_shared_instance;
} 