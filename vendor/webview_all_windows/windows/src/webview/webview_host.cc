#include "webview/webview_host.h"

#include <wrl.h>

#include <cstring>
#include <future>

#include "util/string_converter.h"

using namespace Microsoft::WRL;

namespace webview_all_windows {

// static
std::unique_ptr<WebviewHost>
WebviewHost::Create(WebviewPlatform *platform,
                    std::optional<std::wstring> user_data_directory,
                    std::optional<std::wstring> browser_exe_path,
                    std::optional<std::string> arguments) {
  wil::com_ptr<CoreWebView2EnvironmentOptions> opts;
  if (arguments.has_value()) {
    opts = Microsoft::WRL::Make<CoreWebView2EnvironmentOptions>();
    std::wstring warguments(arguments.value().begin(), arguments.value().end());
    opts->put_AdditionalBrowserArguments(warguments.c_str());
  }

  std::promise<HRESULT> result_promise;
  wil::com_ptr<ICoreWebView2Environment> env;
  auto result = CreateCoreWebView2EnvironmentWithOptions(
      browser_exe_path.has_value() ? browser_exe_path->c_str() : nullptr,
      user_data_directory.has_value() ? user_data_directory->c_str() : nullptr,
      opts.get(),
      Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
          [&promise = result_promise,
           &ptr = env](HRESULT r, ICoreWebView2Environment *env) -> HRESULT {
            promise.set_value(r);
            ptr.swap(env);
            return S_OK;
          })
          .Get());

  if (SUCCEEDED(result)) {
    result = result_promise.get_future().get();
    if ((SUCCEEDED(result) || result == RPC_E_CHANGED_MODE) && env) {
      auto webview_env3 = env.try_query<ICoreWebView2Environment3>();
      if (webview_env3) {
        return std::unique_ptr<WebviewHost>(
            new WebviewHost(platform, std::move(webview_env3)));
      }
    }
  }

  return {};
}

WebviewHost::WebviewHost(WebviewPlatform *platform,
                         wil::com_ptr<ICoreWebView2Environment3> webview_env)
    : webview_env_(webview_env) {
  compositor_ = platform->graphics_context()->CreateCompositor();
}

void WebviewHost::CreateWebview(HWND hwnd, bool offscreen_only,
                                bool owns_window,
                                WebviewCreationCallback callback) {
  // [PATCH] 见 PATCHES.md 补丁 4:下面这个完成回调由 WebView2 异步派发,期间
  // WindowsHostApi(以及它持有的 this)可能已经随子窗口引擎销毁了。捕获存活
  // 令牌,过期就把这次创建的结果整个丢掉 —— 既不能碰 self(compositor() 会读到
  // 已释放内存),也不能回调 callback(它捕获的 WindowsHostApi 与 pigeon reply
  // 同样已经失效)。
  std::weak_ptr<int> alive = alive_;
  CreateWebViewCompositionController(
      hwnd, [=, self = this](
                wil::com_ptr<ICoreWebView2CompositionController> controller,
                std::unique_ptr<WebviewCreationError> error) {
        if (alive.expired()) {
          if (controller) {
            // 控制器已经建出来了,不 Close 会白留一个 WebView2 浏览器进程。
            if (auto c = controller.try_query<ICoreWebView2Controller>()) {
              c->Close();
            }
            controller = nullptr;
          }
          // 正常路径下这个消息窗口由 Webview 析构时销毁(owns_window_),
          // 这里 Webview 没建起来,自己收尾。
          if (owns_window && hwnd != nullptr) {
            DestroyWindow(hwnd);
          }
          return;
        }
        if (controller) {
          std::unique_ptr<Webview> webview(new Webview(
              std::move(controller), self, hwnd, owns_window, offscreen_only));
          callback(std::move(webview), nullptr);
        } else {
          callback(nullptr, std::move(error));
        }
      });
}

void WebviewHost::CreateWebViewPointerInfo(
    PointerInfoCreationCallback callback) {

  ICoreWebView2PointerInfo *pointer;
  auto hr = webview_env_->CreateCoreWebView2PointerInfo(&pointer);

  if (FAILED(hr)) {
    callback(nullptr, WebviewCreationError::create(
                          hr, "CreateWebViewPointerInfo failed."));
  } else if (SUCCEEDED(hr)) {
    callback(std::move(wil::com_ptr<ICoreWebView2PointerInfo>(pointer)),
             nullptr);
  }
}

wil::com_ptr<ICoreWebView2WebResourceRequest>
WebviewHost::CreateWebResourceRequest(const std::string &url,
                                      const std::string &method,
                                      const std::string &headers,
                                      const std::vector<uint8_t> *body) {
  wil::com_ptr<IStream> body_stream;
  if (body != nullptr && !body->empty()) {
    HGLOBAL global = GlobalAlloc(GMEM_MOVEABLE, body->size());
    if (global == nullptr) {
      return nullptr;
    }

    void *data = GlobalLock(global);
    if (data == nullptr) {
      GlobalFree(global);
      return nullptr;
    }
    std::memcpy(data, body->data(), body->size());
    GlobalUnlock(global);

    IStream *stream = nullptr;
    if (FAILED(CreateStreamOnHGlobal(global, TRUE, &stream))) {
      GlobalFree(global);
      return nullptr;
    }
    body_stream.attach(stream);
  }

  wil::com_ptr<ICoreWebView2WebResourceRequest> request;
  if (FAILED(webview_env_->CreateWebResourceRequest(
          util::Utf16FromUtf8(url).c_str(), util::Utf16FromUtf8(method).c_str(),
          body_stream.get(), util::Utf16FromUtf8(headers).c_str(),
          request.put()))) {
    return nullptr;
  }
  return request;
}

void WebviewHost::CreateWebViewCompositionController(
    HWND hwnd, CompositionControllerCreationCallback callback) {
  auto hr = webview_env_->CreateCoreWebView2CompositionController(
      hwnd,
      Callback<
          ICoreWebView2CreateCoreWebView2CompositionControllerCompletedHandler>(
          [callback](HRESULT hr,
                     ICoreWebView2CompositionController *compositionController)
              -> HRESULT {
            if (SUCCEEDED(hr)) {
              callback(
                  std::move(wil::com_ptr<ICoreWebView2CompositionController>(
                      compositionController)),
                  nullptr);
            } else {
              callback(nullptr,
                       WebviewCreationError::create(
                           hr, "CreateCoreWebView2CompositionController "
                               "completion handler failed."));
            }

            return S_OK;
          })
          .Get());

  if (FAILED(hr)) {
    callback(nullptr,
             WebviewCreationError::create(
                 hr, "CreateCoreWebView2CompositionController failed."));
  }
}

} // namespace webview_all_windows
