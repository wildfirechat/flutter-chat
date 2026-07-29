# Project-level configuration.
cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "wildfirechat")
# The unique GTK application identifier for this application. See:
# https://wiki.gnome.org/HowDoI/ChooseApplicationID
# 与 Android 的 applicationId 保持一致，桌面环境靠它把窗口关联到 .desktop 文件。
set(APPLICATION_ID "cn.wildfirechat.chat")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(SET CMP0063 NEW)

# Load bundled libraries from the lib/ directory relative to the binary.
set(CMAKE_INSTALL_RPATH "$ORIGIN/lib")

# Root filesystem for cross-building.
if(FLUTTER_TARGET_PLATFORM_SYSROOT)
  set(CMAKE_SYSROOT ${FLUTTER_TARGET_PLATFORM_SYSROOT})
  set(CMAKE_FIND_ROOT_PATH ${CMAKE_SYSROOT})
  set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
  set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
  set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
  set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
endif()

# Define build configuration options.
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE "Debug" CACHE
    STRING "Flutter build mode" FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
    "Debug" "Profile" "Release")
endif()

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_14)
  target_compile_options(${TARGET} PRIVATE -Wall -Werror)
  target_compile_options(${TARGET} PRIVATE "$<$<NOT:$<CONFIG:Debug>>:-O3>")
  target_compile_definitions(${TARGET} PRIVATE "$<$<NOT:$<CONFIG:Debug>>:NDEBUG>")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# System-level dependencies.
find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK REQUIRED IMPORTED_TARGET gtk+-3.0)
# 直接调用 XSetErrorHandler/XQueryExtension 需要显式链接 libX11
# (gtk+-3.0.pc 不带 -lX11)。Wayland-only 环境找不到就跳过,
# 对应代码由 HAVE_X11 宏开关。
pkg_check_modules(X11 IMPORTED_TARGET x11)

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")

# Run the Flutter tool portions of the build. This must not be removed.
add_dependencies(${BINARY_NAME} flutter_assemble)

# Only the install-generated bundle's copy of the executable will launch
# correctly, since the resources must in the right relative locations. To avoid
# people trying to run the unbundled copy, put it in a subdirectory instead of
# the default top-level location.
set_target_properties(${BINARY_NAME}
  PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/intermediates_do_not_run"
)


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)


# === Installation ===
# By default, "installing" just makes a relocatable bundle in the build
# directory.
set(BUILD_BUNDLE_DIR "${PROJECT_BINARY_DIR}/bundle")
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

# Start with a clean build bundle directory every time.
install(CODE "
  file(REMOVE_RECURSE \"${BUILD_BUNDLE_DIR}/\")
  " COMPONENT Runtime)

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}/lib")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

foreach(bundled_library ${PLUGIN_BUNDLED_LIBRARIES})
  install(FILES "${bundled_library}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endforeach(bundled_library)

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/linux/")
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
if(NOT CMAKE_BUILD_TYPE MATCHES "Debug")
  install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# === Bundle flameshot screenshot tool ===
# 根据目标架构选择对应的 flameshot 二进制目录。
if(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64")
  set(FLAMESHOT_ARCH "x86_64")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
  set(FLAMESHOT_ARCH "arm64")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "arm")
  set(FLAMESHOT_ARCH "arm")
else()
  set(FLAMESHOT_ARCH "${CMAKE_SYSTEM_PROCESSOR}")
  message(WARNING "flameshot: unknown target architecture '${CMAKE_SYSTEM_PROCESSOR}', falling back to literal directory name")
endif()

# native_tools 在应用根目录（chat/native_tools），不在 chat/linux 下。
set(NATIVE_TOOLS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../native_tools")

# 布局是 `flameshot.AppImage --appimage-extract` 的原始产物
# （native_tools/linux/flameshot/<arch>/squashfs-root/usr/{bin,lib,plugins,share}）：
# bin/flameshot + bin/qt.conf（Prefix=../, Plugins=plugins）+ lib/*.so* + plugins/。
# qt.conf 靠 bin/ 和 plugins/ 的兄弟关系找 Qt 平台插件，因此按 usr/ 整体搬运，
# 不能拍平成单层目录，否则 Qt 找不到 platforms 插件起不来。
set(FLAMESHOT_TOOL_DIR "${NATIVE_TOOLS_DIR}/linux/flameshot/${FLAMESHOT_ARCH}/squashfs-root/usr")
if(EXISTS "${FLAMESHOT_TOOL_DIR}/bin/flameshot")
  # install(DIRECTORY) 默认不保留源文件权限，会把 flameshot 可执行文件的
  # 执行位拍成普通 644，导致运行时 Permission denied，必须显式保留源权限。
  install(DIRECTORY "${FLAMESHOT_TOOL_DIR}/"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/flameshot/${FLAMESHOT_ARCH}"
    USE_SOURCE_PERMISSIONS
    COMPONENT Runtime)
else()
  message(WARNING "flameshot: 未找到 ${FLAMESHOT_TOOL_DIR}/bin/flameshot，"
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

# === 桌面集成：应用图标与 .desktop 入口 ===
# 图标与 .desktop 一并装进 bundle 的 share/ 目录，两处消费：
#   1. 运行时 my_application.cc 从 <exe 目录>/share/icons 直接读 PNG 设窗口图标
#      （X11 下的窗口/任务栏图标，不依赖系统是否装了 hicolor-icon-theme）；
#   2. 打 deb/rpm 时把整个 share/ 铺到 /usr/share，应用菜单、Wayland 窗口图标
#      靠 .desktop + hicolor 图标树来认这个应用。
set(INSTALL_BUNDLE_SHARE_DIR "${CMAKE_INSTALL_PREFIX}/share")

# .desktop 里 Exec= 写的路径。bundle 内默认只写可执行文件名（PATH 里找得到才行），
# 打包时用 -DDESKTOP_ENTRY_EXEC=/opt/wildfirechat/wildfirechat 覆盖成安装后的绝对路径。
set(DESKTOP_ENTRY_EXEC "${BINARY_NAME}" CACHE STRING
  "写入 .desktop Exec= 字段的可执行文件路径")

configure_file(
  "${CMAKE_CURRENT_SOURCE_DIR}/packaging/app.desktop.in"
  "${CMAKE_CURRENT_BINARY_DIR}/${APPLICATION_ID}.desktop"
  @ONLY)

install(FILES "${CMAKE_CURRENT_BINARY_DIR}/${APPLICATION_ID}.desktop"
  DESTINATION "${INSTALL_BUNDLE_SHARE_DIR}/applications"
  COMPONENT Runtime)

install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/packaging/icons/"
  DESTINATION "${INSTALL_BUNDLE_SHARE_DIR}/icons"
  COMPONENT Runtime)
