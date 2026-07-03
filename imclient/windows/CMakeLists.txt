cmake_minimum_required(VERSION 3.14)
project(imclient_plugin LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must
# not be added to the plugin project itself.
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

# Link the bundled MarsWrapper library.
if(CMAKE_SIZEOF_VOID_P EQUAL 8)
  set(MARSWRAPPER_LIB "${CMAKE_CURRENT_SOURCE_DIR}/../marslib/windows/x64/MarsWrapper.lib")
  set(MARSWRAPPER_DLL "${CMAKE_CURRENT_SOURCE_DIR}/../marslib/windows/x64/MarsWrapper.dll")
else()
  set(MARSWRAPPER_LIB "${CMAKE_CURRENT_SOURCE_DIR}/../marslib/windows/win32/MarsWrapper.lib")
  set(MARSWRAPPER_DLL "${CMAKE_CURRENT_SOURCE_DIR}/../marslib/windows/win32/MarsWrapper.dll")
endif()

if(NOT EXISTS "${MARSWRAPPER_LIB}")
  message(FATAL_ERROR "MarsWrapper import library not found: ${MARSWRAPPER_LIB}. "
      "Please build/provide the PC SDK import library (.lib) for Windows.")
endif()

if(NOT EXISTS "${MARSWRAPPER_DLL}")
  message(FATAL_ERROR "MarsWrapper DLL not found: ${MARSWRAPPER_DLL}")
endif()

target_link_libraries(imclient_plugin PRIVATE "${MARSWRAPPER_LIB}")

# Bundle the DLL with the application output.
set(_imclient_plugin_bundled_libraries "${_imclient_plugin_bundled_libraries};${MARSWRAPPER_DLL}" PARENT_SCOPE)

# Copy the import library to a predictable location if needed.
set_target_properties(imclient_plugin PROPERTIES
  INSTALL_RPATH "$ORIGIN"
)
