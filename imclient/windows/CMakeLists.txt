# imclient Windows 构建：仅编译三平台共享的 Dart 回调转发垫片，并打包
# 预编译的 WFClient SDK。方法分发逻辑在 Dart 侧
# （imclient/lib/src/ffi/imclient_ffi_channel.dart），本目录没有业务代码。
#
# 注意：SDK 由 dart:ffi 在运行时加载（DynamicLibrary.open），不做链接期
# 绑定，因此不需要 MarsWrapper.lib 导入库。
cmake_minimum_required(VERSION 3.14)
project(imclient_library VERSION 0.0.1 LANGUAGES C)

add_library(wfc_dart_bridge SHARED
  "../src/wfc_dart_bridge.c"
  "../src/dart_include/dart_api_dl.c"
)
target_include_directories(wfc_dart_bridge PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}/../src"
)

if(CMAKE_SIZEOF_VOID_P EQUAL 8)
  set(MARSWRAPPER_DLL
      "${CMAKE_CURRENT_SOURCE_DIR}/../marslib/windows/x64/MarsWrapper.dll")
else()
  set(MARSWRAPPER_DLL
      "${CMAKE_CURRENT_SOURCE_DIR}/../marslib/windows/win32/MarsWrapper.dll")
endif()

if(NOT EXISTS "${MARSWRAPPER_DLL}")
  message(FATAL_ERROR "MarsWrapper DLL not found: ${MARSWRAPPER_DLL}")
endif()

set(imclient_bundled_libraries
  $<TARGET_FILE:wfc_dart_bridge>
  "${MARSWRAPPER_DLL}"
  PARENT_SCOPE
)
