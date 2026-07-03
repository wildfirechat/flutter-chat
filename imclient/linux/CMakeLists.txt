cmake_minimum_required(VERSION 3.10)
project(imclient_plugin LANGUAGES CXX)

set(_imclient_plugin_bundled_libraries $<TARGET_FILE:imclient_plugin>)

add_library(imclient_plugin SHARED
  "imclient_plugin.cpp"
  "wf_client_helper.cpp"
  "wf_json_helper.cpp"
)

apply_standard_settings(imclient_plugin)
set_target_properties(imclient_plugin PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(imclient_plugin PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(imclient_plugin INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/../marslib/include")
target_include_directories(imclient_plugin PRIVATE
  "${CMAKE_CURRENT_SOURCE_DIR}/../marslib/include")

target_link_libraries(imclient_plugin PRIVATE flutter flutter_wrapper_plugin)

# Link the bundled MarsWrapper shared library.
if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
  set(MARSWRAPPER_SO "${CMAKE_CURRENT_SOURCE_DIR}/../marslib/linux/arm64/libMarsWrapper.so")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64")
  set(MARSWRAPPER_SO "${CMAKE_CURRENT_SOURCE_DIR}/../marslib/linux/x86_64/libMarsWrapper.so")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "loongarch64")
  set(MARSWRAPPER_SO "${CMAKE_CURRENT_SOURCE_DIR}/../marslib/linux/loongarch64/libMarsWrapper.so")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "sw_64|sw64")
  set(MARSWRAPPER_SO "${CMAKE_CURRENT_SOURCE_DIR}/../marslib/linux/sw64/libMarsWrapper.so")
else()
  message(FATAL_ERROR "Unsupported Linux architecture: ${CMAKE_SYSTEM_PROCESSOR}")
endif()

if(NOT EXISTS "${MARSWRAPPER_SO}")
  message(FATAL_ERROR "MarsWrapper shared library not found: ${MARSWRAPPER_SO}")
endif()

target_link_libraries(imclient_plugin PRIVATE "${MARSWRAPPER_SO}")

set_target_properties(imclient_plugin PROPERTIES
  BUILD_WITH_INSTALL_RPATH TRUE
  INSTALL_RPATH "$ORIGIN"
)

set(_imclient_plugin_bundled_libraries "${_imclient_plugin_bundled_libraries};${MARSWRAPPER_SO}" PARENT_SCOPE)
