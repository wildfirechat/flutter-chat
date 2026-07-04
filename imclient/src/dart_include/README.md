# Dart API Dynamic Linking 头文件（vendored）

来源：Dart SDK 3.6.2（Flutter 3.27.4 `bin/cache/dart-sdk/include/`）原样拷贝，
BSD-3 许可（版权声明保留在各文件头部）。

- `wfc_dart_bridge.c` 依赖 `Dart_PostCObject_DL` / `Dart_InitializeApiDL`，
  其中 `dart_api_dl.c` 是**必须编译进垫片的实现源码**（函数指针表在运行时
  由 VM 填充），其余为其头文件闭包。
- 这套 "_DL" API 是 Dart 官方为原生扩展 vendor 而设计的：
  `Dart_InitializeApiDL` 在运行时做 ABI major 版本握手（当前
  `DART_API_DL_MAJOR_VERSION = 2`），与 VM 不兼容时返回 -1，
  `imclient_ffi_channel.dart` 已检查该返回值。因此升级 Flutter SDK 通常
  **不需要**同步更新这些文件，除非握手失败。
- 更新方法：从目标 Flutter SDK 重新拷贝——
  `cp $FLUTTER_ROOT/bin/cache/dart-sdk/include/{dart_api_dl.h,dart_api_dl.c,dart_api.h,dart_native_api.h,dart_version.h} ./`
  `cp $FLUTTER_ROOT/bin/cache/dart-sdk/include/internal/dart_api_dl_impl.h ./internal/`
