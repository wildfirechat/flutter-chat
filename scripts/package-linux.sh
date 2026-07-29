#!/usr/bin/env bash
#
# 把 chat/ 的 Linux 构建产物打包成 AppImage 和 deb。
#
#   scripts/package-linux.sh                       # release 构建，AppImage + deb 都出
#   scripts/package-linux.sh --deb-only            # 只出 deb
#   scripts/package-linux.sh --appimage-only        # 只出 AppImage
#   scripts/package-linux.sh --debug               # 用 debug 构建打包（一般用不到）
#   scripts/package-linux.sh --skip-build          # 复用已有的 flutter build 产物，不重新编译
#   scripts/package-linux.sh --output DIR          # 产物目录，默认 chat/build/linux_package
#   scripts/package-linux.sh --maintainer "name <mail>"
#   scripts/package-linux.sh --force               # 发现缺库也强行出包（不建议）
#
# 只能在 Linux 上原生跑，且只能在目标架构机器上跑——flutter build linux 不支持
# 交叉编译，imclient/marslib 与 flameshot 也是按 x86_64/arm64/loongarch64/sw64
# 分开预编译的二进制，见 imclient/linux/CMakeLists.txt 与 chat/linux/CMakeLists.txt。
#
# deb 的 Depends 是自动算出来的，不是手写的：对 bundle 里所有 ELF 文件跑 ldd，
# 把没有落在 bundle 目录内的系统库路径反查 `dpkg -S` 找归属的包。这么做是为了
# 避免重蹈覆辙——libwebkit2gtk 这类直接链接的系统库一旦漏写 Depends，后果不是
# "某个功能不可用"，是 ld.so 直接失败、整个 App 起不来（见 chat/pubspec.yaml 里
# webview_all_linux 的注释，以及项目里 aarch64 目标机的经验教训）。反查依赖必须
# 在和目标机同发行版同架构的机器上跑，结果才准。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CHAT_DIR="$REPO_ROOT/chat"

MODE=release
DO_DEB=1
DO_APPIMAGE=1
SKIP_BUILD=0
OUTPUT_DIR=""
MAINTAINER="WildFireChat <support@wildfirechat.cn>"
HOMEPAGE="https://docs.wildfirechat.cn"
FORCE=0

usage() {
  awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --debug)         MODE=debug ;;
    --deb-only)      DO_APPIMAGE=0 ;;
    --appimage-only) DO_DEB=0 ;;
    --skip-build)    SKIP_BUILD=1 ;;
    --output)        OUTPUT_DIR="$2"; shift ;;
    --maintainer)    MAINTAINER="$2"; shift ;;
    --force)         FORCE=1 ;;
    -h|--help)       usage; exit 0 ;;
    *) echo "未知参数: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

if [ "$(uname -s)" != "Linux" ]; then
  echo "错误：只能在 Linux 机器上打包（flutter build linux 不支持交叉编译）。" >&2
  exit 1
fi

: "${OUTPUT_DIR:=$CHAT_DIR/build/linux_package}"
mkdir -p "$OUTPUT_DIR"

TMP_DIRS=()
cleanup() {
  local d
  for d in "${TMP_DIRS[@]:-}"; do
    [ -n "$d" ] && [ -d "$d" ] && rm -rf "$d"
  done
}
trap cleanup EXIT

# ---------------------------------------------------------------- 读取元信息
# 从 CMakeLists.txt / pubspec.yaml 里读，而不是在脚本里另存一份，避免两边改一处忘一处。
LINUX_CMAKE="$CHAT_DIR/linux/CMakeLists.txt"
BINARY_NAME=$(sed -n 's/^set(BINARY_NAME "\(.*\)")/\1/p' "$LINUX_CMAKE" | head -1)
APPLICATION_ID=$(sed -n 's/^set(APPLICATION_ID "\(.*\)")/\1/p' "$LINUX_CMAKE" | head -1)
VERSION=$(sed -n 's/^version: *\([0-9][0-9.]*\).*/\1/p' "$CHAT_DIR/pubspec.yaml" | head -1)
DESKTOP_TEMPLATE="$CHAT_DIR/linux/packaging/app.desktop.in"
DISPLAY_NAME_EN=$(sed -n 's/^Name\[en\]=//p' "$DESKTOP_TEMPLATE" | head -1)
COMMENT_EN=$(sed -n 's/^Comment\[en\]=//p' "$DESKTOP_TEMPLATE" | head -1)

if [ -z "$BINARY_NAME" ] || [ -z "$APPLICATION_ID" ] || [ -z "$VERSION" ]; then
  echo "错误：没能从 linux/CMakeLists.txt / pubspec.yaml 解析出 BINARY_NAME/APPLICATION_ID/VERSION。" >&2
  exit 1
fi

echo "==> $DISPLAY_NAME_EN $VERSION ($BINARY_NAME, $APPLICATION_ID)"

# ---------------------------------------------------------------- 构建
if [ "$SKIP_BUILD" -eq 0 ]; then
  echo "==> flutter build linux --$MODE"
  (cd "$CHAT_DIR" && flutter build linux --$MODE)
fi

BUNDLE_DIR=$(find "$CHAT_DIR/build/linux" -maxdepth 3 -type d -path "*/$MODE/bundle" 2>/dev/null | head -1)
if [ -z "$BUNDLE_DIR" ] || [ ! -x "$BUNDLE_DIR/$BINARY_NAME" ]; then
  echo "错误：找不到构建产物（期望 build/linux/*/$MODE/bundle/$BINARY_NAME）。先跑一次不带 --skip-build。" >&2
  exit 1
fi
echo "==> 构建产物: $BUNDLE_DIR"

HOST_ARCH=$(uname -m)
DEB_ARCH=$(dpkg --print-architecture 2>/dev/null || echo "$HOST_ARCH")

# ---------------------------------------------------------------- 自动扫描运行时依赖
# 填充全局数组 DEPENDS_PKGS（去重后的包名）和 MISSING_LIBS（本机都找不到的库）。
scan_runtime_deps() {
  local root="$1"
  local -A seen_pkgs=()
  local -A seen_missing=()
  DEPENDS_PKGS=()
  MISSING_LIBS=()

  local f line resolved pkg
  while IFS= read -r -d '' f; do
    while IFS= read -r line; do
      if [[ "$line" == *"=> not found"* ]]; then
        resolved=$(echo "$line" | sed -E 's/^[[:space:]]*([^[:space:]]+).*/\1/')
        if [ -z "${seen_missing[$resolved]:-}" ]; then
          seen_missing[$resolved]=1
          MISSING_LIBS+=("$resolved (被 ${f#"$root"/} 需要)")
        fi
        continue
      elif [[ "$line" == *"=>"* ]]; then
        resolved=$(echo "$line" | sed -E 's/.*=>[[:space:]]+([^[:space:]]+).*/\1/')
      elif [[ "$line" =~ ^[[:space:]]*(/[^[:space:]]+) ]]; then
        resolved="${BASH_REMATCH[1]}"
      else
        continue
      fi
      case "$resolved" in
        "$root"/*) continue ;;   # bundle 自带的，不算系统依赖
      esac
      [ -e "$resolved" ] || continue
      pkg=$(dpkg -S "$resolved" 2>/dev/null | head -1 | cut -d: -f1)
      [ -z "$pkg" ] && pkg="???($resolved)"
      if [ -z "${seen_pkgs[$pkg]:-}" ]; then
        seen_pkgs[$pkg]=1
        DEPENDS_PKGS+=("$pkg")
      fi
    done < <(ldd "$f" 2>/dev/null || true)
  done < <(find "$root" -type f \( -name "*.so" -o -name "*.so.*" -o -perm -u+x \) -print0)
}

# ---------------------------------------------------------------- 打 deb
build_deb() {
  echo "==> 扫描运行时依赖 (ldd + dpkg -S)"
  scan_runtime_deps "$BUNDLE_DIR"

  if [ "${#MISSING_LIBS[@]}" -gt 0 ]; then
    echo "警告：以下库在本机都找不到，说明本机运行这份构建产物也会失败：" >&2
    printf '  - %s\n' "${MISSING_LIBS[@]}" >&2
    if [ "$FORCE" -ne 1 ]; then
      echo "先解决缺库问题，或者加 --force 强行出包（不建议分发）。" >&2
      exit 1
    fi
  fi
  echo "==> Depends: ${DEPENDS_PKGS[*]:-无}"

  echo "==> 打包 deb ($DEB_ARCH)"
  local pkgroot
  pkgroot=$(mktemp -d)
  TMP_DIRS+=("$pkgroot")

  local optdir="$pkgroot/opt/$BINARY_NAME"
  mkdir -p "$optdir"
  cp -a "$BUNDLE_DIR/." "$optdir/"

  # desktop/图标挪到标准位置，/opt 下只留运行时需要的东西
  mkdir -p "$pkgroot/usr/share/applications" "$pkgroot/usr/share/icons"
  cp -a "$optdir/share/icons/." "$pkgroot/usr/share/icons/"
  local desktop_src="$optdir/share/applications/${APPLICATION_ID}.desktop"
  local desktop_dst="$pkgroot/usr/share/applications/${APPLICATION_ID}.desktop"
  # bundle 里的 Exec= 是裸的 $BINARY_NAME（PATH 里才找得到），deb 装到 /opt 下必须
  # 改成绝对路径，否则应用菜单点开是"命令不存在"。
  sed "s|^Exec=.*|Exec=/opt/$BINARY_NAME/$BINARY_NAME %U|" "$desktop_src" > "$desktop_dst"
  rm -rf "$optdir/share/applications" "$optdir/share/icons"

  mkdir -p "$pkgroot/usr/bin"
  ln -s "/opt/$BINARY_NAME/$BINARY_NAME" "$pkgroot/usr/bin/$BINARY_NAME"

  local depends="libc6"
  if [ "${#DEPENDS_PKGS[@]}" -gt 0 ]; then
    depends=$(IFS=,; echo "${DEPENDS_PKGS[*]}")
    depends=$(echo "$depends" | sed 's/,/, /g')
  fi

  mkdir -p "$pkgroot/DEBIAN"
  cat > "$pkgroot/DEBIAN/control" <<EOF
Package: $BINARY_NAME
Version: $VERSION
Section: net
Priority: optional
Architecture: $DEB_ARCH
Maintainer: $MAINTAINER
Homepage: $HOMEPAGE
Depends: $depends
Description: $COMMENT_EN
 $DISPLAY_NAME_EN desktop client for Linux.
EOF

  cat > "$pkgroot/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database -q /usr/share/applications || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -qtf /usr/share/icons/hicolor || true
EOF
  cp "$pkgroot/DEBIAN/postinst" "$pkgroot/DEBIAN/postrm"
  chmod 755 "$pkgroot/DEBIAN/postinst" "$pkgroot/DEBIAN/postrm"

  find "$pkgroot" -type d -exec chmod 755 {} \;

  local deb_out="$OUTPUT_DIR/${BINARY_NAME}_${VERSION}_${DEB_ARCH}.deb"
  if dpkg-deb --help 2>&1 | grep -q -- --root-owner-group; then
    dpkg-deb --root-owner-group --build "$pkgroot" "$deb_out"
  elif command -v fakeroot >/dev/null 2>&1; then
    fakeroot dpkg-deb --build "$pkgroot" "$deb_out"
  else
    echo "警告：dpkg-deb 太旧不支持 --root-owner-group，也没有 fakeroot，包内文件属主会是当前用户。" >&2
    dpkg-deb --build "$pkgroot" "$deb_out"
  fi
  echo "==> deb: $deb_out"
}

# ---------------------------------------------------------------- 打 AppImage
APPIMAGETOOL_CACHE_DIR="$CHAT_DIR/native_tools/linux/appimagetool/$HOST_ARCH"

resolve_appimagetool() {
  if command -v appimagetool >/dev/null 2>&1; then
    command -v appimagetool
    return 0
  fi
  local cached="$APPIMAGETOOL_CACHE_DIR/appimagetool"
  if [ -x "$cached" ]; then
    echo "$cached"
    return 0
  fi
  local dl_arch=""
  case "$HOST_ARCH" in
    x86_64)         dl_arch=x86_64 ;;
    aarch64|arm64)  dl_arch=aarch64 ;;
    armv7l|armhf)   dl_arch=armhf ;;
  esac
  if [ -z "$dl_arch" ]; then
    echo "错误：$HOST_ARCH 没有官方 appimagetool 预编译版（loongarch64/sw64 这类国产架构上游没有构建）。" >&2
    echo "      请自行编译 appimagetool，或放一份可执行文件到: $cached" >&2
    return 1
  fi
  echo "==> 本地没有 appimagetool，尝试从 GitHub 下载 ($dl_arch)..." >&2
  mkdir -p "$APPIMAGETOOL_CACHE_DIR"
  local url="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-${dl_arch}.AppImage"
  if ! curl -fL --retry 2 -o "$cached.tmp" "$url"; then
    echo "错误：下载 appimagetool 失败（$url）。机器不通外网的话，手动放一份到 $cached。" >&2
    rm -f "$cached.tmp"
    return 1
  fi
  chmod +x "$cached.tmp"
  mv "$cached.tmp" "$cached"
  echo "$cached"
}

build_appimage() {
  echo "==> 打包 AppImage ($HOST_ARCH)"
  local appdir
  appdir=$(mktemp -d --suffix=.AppDir)
  TMP_DIRS+=("$appdir")

  mkdir -p "$appdir/usr/bin"
  cp -a "$BUNDLE_DIR/." "$appdir/usr/bin/"

  # 整个 bundle（含 data/ lib/）原样搬进 usr/bin/，可执行文件和它期望的相对
  # 布局（同目录下的 data/、lib/）保持不变，不用改 rpath 或任何查找逻辑。
  cat > "$appdir/AppRun" <<EOF
#!/bin/sh
HERE="\$(dirname "\$(readlink -f "\$0")")"
exec "\$HERE/usr/bin/$BINARY_NAME" "\$@"
EOF
  chmod +x "$appdir/AppRun"

  local desktop_src="$appdir/usr/bin/share/applications/${APPLICATION_ID}.desktop"
  cp "$desktop_src" "$appdir/${APPLICATION_ID}.desktop"

  local icon_src="$appdir/usr/bin/share/icons/hicolor/256x256/apps/${APPLICATION_ID}.png"
  if [ -f "$icon_src" ]; then
    cp "$icon_src" "$appdir/${APPLICATION_ID}.png"
    cp "$icon_src" "$appdir/.DirIcon"
  else
    echo "警告：没找到 256x256 图标，AppImage 可能显示不出图标。" >&2
  fi

  local appimagetool
  appimagetool=$(resolve_appimagetool) || return 1

  local out="$OUTPUT_DIR/${DISPLAY_NAME_EN// /}-${VERSION}-${HOST_ARCH}.AppImage"
  # 用 extract-and-run，不依赖构建机上有 FUSE。
  ARCH="$HOST_ARCH" APPIMAGE_EXTRACT_AND_RUN=1 "$appimagetool" "$appdir" "$out"
  echo "==> AppImage: $out"
}

# ---------------------------------------------------------------- 执行
# appimagetool 在 loongarch64/sw64 这类国产架构上大概率没有上游预编译版，属于
# 已知会发生的情况：deb 该出还是要出，不能因为 AppImage 这步不可用就把已经打好
# 的 deb 也一起吞掉，所以这里只记录失败，最后再统一决定退出码。
FAILED=0
[ "$DO_DEB" -eq 1 ] && { build_deb || FAILED=1; }
[ "$DO_APPIMAGE" -eq 1 ] && { build_appimage || FAILED=1; }

echo "==> 产物目录: $OUTPUT_DIR"
ls -lh "$OUTPUT_DIR" 2>/dev/null || true

if [ "$FAILED" -eq 1 ]; then
  echo "==> 有步骤失败，见上面的报错。" >&2
  exit 1
fi
echo "==> 完成"
