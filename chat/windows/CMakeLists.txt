# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(wildfirechat LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "wildfirechat")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
# 注意：这里必须保持 cxx_std_17（Flutter 模板默认值），不要升到 cxx_std_20。
# MSVC 的 /std:c++20 会隐式启用 /permissive-，而 /permissive- 会把 C4596
# （类体内用类名限定成员声明）从警告提升为**错误**，无法用 /wd 屏蔽。
# screen_retriever_windows(截至 0.2.2，最新版) 和 tray_manager 都是这种写法，
# 一旦开 C++20 这两个插件必然编译失败。若确有代码需要 C++20，请只对具体
# target 单独设置，不要改这个共享函数。
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  # 4596: 第三方插件（screen_retriever_windows / tray_manager）在类体内使用了
  # 类名限定的成员声明，C++17 下是 /W4 警告，这里静音以免刷屏。
  target_compile_options(${TARGET} PRIVATE /W4 /wd"4100" /wd"4596")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)


# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)

# === Bundle flameshot screenshot tool ===
# native_tools 在应用根目录（chat/native_tools），不在 chat/windows 下。
set(NATIVE_TOOLS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../native_tools")

set(FLAMESHOT_TOOL_DIR "${NATIVE_TOOLS_DIR}/windows/flameshot")
if(EXISTS "${FLAMESHOT_TOOL_DIR}/flameshot.exe")
  install(DIRECTORY "${FLAMESHOT_TOOL_DIR}/"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/flameshot"
    COMPONENT Runtime)
else()
  message(WARNING "flameshot: 未找到 ${FLAMESHOT_TOOL_DIR}/flameshot.exe，"
    "截图功能在打出来的包里不可用（见 SCREENSHOT.md 准备二进制）。")
endif()

# === Bundle flameshot license notices ===
set(FLAMESHOT_LICENSE "${NATIVE_TOOLS_DIR}/LICENSE.flameshot")
set(FLAMESHOT_NOTICE "${NATIVE_TOOLS_DIR}/NOTICE.md")
if(EXISTS "${FLAMESHOT_LICENSE}")
  install(FILES "${FLAMESHOT_LICENSE}" DESTINATION "${CMAKE_INSTALL_PREFIX}" COMPONENT Runtime)
endif()
if(EXISTS "${FLAMESHOT_NOTICE}")
  install(FILES "${FLAMESHOT_NOTICE}" DESTINATION "${CMAKE_INSTALL_PREFIX}" COMPONENT Runtime)
endif()
