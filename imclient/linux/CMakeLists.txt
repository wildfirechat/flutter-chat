# imclient Linux 构建：仅编译三平台共享的 Dart 回调转发垫片，并打包
# 预编译的 WFClient SDK。方法分发逻辑在 Dart 侧
# （imclient/lib/src/ffi/imclient_ffi_channel.dart），本目录没有业务代码。
#
# SDK 由 dart:ffi 在运行时加载（DynamicLibrary.open），无链接期依赖。
cmake_minimum_required(VERSION 3.10)
project(imclient_library VERSION 0.0.1 LANGUAGES C)

add_library(wfc_dart_bridge SHARED
  "../src/wfc_dart_bridge.c"
  "../src/dart_include/dart_api_dl.c"
)
target_include_directories(wfc_dart_bridge PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}/../src"
)
set_target_properties(wfc_dart_bridge PROPERTIES
  C_VISIBILITY_PRESET hidden
)

if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
  set(MARSWRAPPER_SO
      "${CMAKE_CURRENT_SOURCE_DIR}/../marslib/linux/arm64/libMarsWrapper.so")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "loongarch64")
  set(MARSWRAPPER_SO
      "${CMAKE_CURRENT_SOURCE_DIR}/../marslib/linux/loongarch64/libMarsWrapper.so")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "sw_64|sw64")
  set(MARSWRAPPER_SO
      "${CMAKE_CURRENT_SOURCE_DIR}/../marslib/linux/sw64/libMarsWrapper.so")
else()
  set(MARSWRAPPER_SO
      "${CMAKE_CURRENT_SOURCE_DIR}/../marslib/linux/x86_64/libMarsWrapper.so")
endif()

if(NOT EXISTS "${MARSWRAPPER_SO}")
  message(FATAL_ERROR "libMarsWrapper.so not found: ${MARSWRAPPER_SO}")
endif()

set(imclient_bundled_libraries
  $<TARGET_FILE:wfc_dart_bridge>
  "${MARSWRAPPER_SO}"
  PARENT_SCOPE
)
