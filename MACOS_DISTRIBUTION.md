# macOS 直接分发指南(签名 + 公证 + 打包)

本文档说明如何将本项目 macOS 版(`WildFireChat.app`)通过 **Developer ID 签名 + 苹果公证(Notarization)** 的方式分发给用户下载使用。

## 1. 背景:为什么不走 Mac App Store

本项目 macOS 版通过 **Developer ID 签名 + 苹果公证(Notarization)** 分发。截图已改用苹果原生 ScreenCaptureKit(见 [SCREENSHOT.md](./SCREENSHOT.md)),`Release.entitlements` 已开启 `com.apple.security.app-sandbox`,历史遗留的 `Copy flameshot.app` 构建阶段与 `native_tools/macos/flameshot.app` 已移除——直接分发与 Mac App Store 上架在沙盒层面均已无障碍(上架其余事项见 §8 Q&A)。

直接分发的硬性要求:

- **Developer ID 签名**:证明开发者身份;
- **公证(Notarization)**:苹果云端扫描并签发票据。自 macOS 10.15 起,未公证的 App 在用户机器上会被 Gatekeeper 拦截("无法打开,因为无法验证开发者")。**注意:开发机上运行正常不代表没问题**,Gatekeeper 只拦截从互联网下载的软件;
- App Store 上架不需要公证(商店审核替代),直接分发每次发版都必须重新公证。

## 2. 前置准备

| 项目 | 说明 |
|------|------|
| Apple Developer 账号 | 付费开发者账号 |
| Developer ID Application 证书 | Xcode → Settings → Accounts → Manage Certificates 创建,或 developer.apple.com 下载,导入钥匙串 |
| 公证凭据(二选一) | a) Apple ID + App 专用密码([appleid.apple.com](https://appleid.apple.com) 生成);b) App Store Connect API Key(.p8 私钥 + Key ID + Issuer ID) |
| Xcode 与 Flutter | 按 [README.md](./README.md) 桌面端要求配置 |

确认证书可用:

```bash
security find-identity -v -p codesigning | grep "Developer ID Application"
# 应输出类似:XX) ABCD1234... "Developer ID Application: Your Company (TEAMID)"
```

## 3. 构建 Release 产物

```bash
cd chat
flutter build macos --release
# 产物路径:
# chat/build/macos/Build/Products/Release/WildFireChat.app
```

## 4. 签名

### 4.1 签名顺序:先内后外

必须从最内层开始签(嵌套组件 → 主 App)。**不要**依赖 `codesign --deep`(苹果官方不推荐,--deep 会用主 App 的 entitlements 错误地签嵌套组件)。

以下命令在 `chat` 目录执行,替换两个变量:

```bash
APP="build/macos/Build/Products/Release/WildFireChat.app"
IDENTITY="Developer ID Application: Your Company (TEAMID)"
```

**第一步:签 Frameworks 内的所有动态库与框架**

```bash
find "$APP/Contents/Frameworks" -type f \( -name "*.dylib" -o -perm +111 \) -exec \
  codesign --sign "$IDENTITY" --options runtime --timestamp --force {} \;
find "$APP/Contents/Frameworks" -name "*.framework" -exec \
  codesign --sign "$IDENTITY" --options runtime --timestamp --force {} \;
```

**第二步:带 entitlements 签主 App**

```bash
codesign --sign "$IDENTITY" --options runtime --timestamp --force \
  --entitlements macos/Runner/Release.entitlements \
  "$APP"
```

注意:`macos/Runner/Release.entitlements` 已开启 `app-sandbox`,并包含 network/audio-input/camera/user-selected files;数据目录在沙盒容器内(应用尚未发布,无需处理老数据迁移)。

### 4.2 验证签名

```bash
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -d --entitlements - "$APP"   # 确认 app-sandbox=true,有 network.client 等
spctl --assess --type execute -vv "$APP"
# 公证前 spctl 会显示 "rejected"(尚未公证),这是正常的
```

## 5. 公证

### 5.1 打包上传

```bash
ditto -c -k --keepParent "$APP" WildFireChat.zip
```

**方式 A:Apple ID + App 专用密码**

```bash
xcrun notarytool submit WildFireChat.zip \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "xxxx-xxxx-xxxx-xxxx" \
  --wait
```

**方式 B:App Store Connect API Key(适合 CI)**

```bash
xcrun notarytool submit WildFireChat.zip \
  --key "AuthKey_XXXXXXXX.p8" \
  --key-id "XXXXXXXX" \
  --issuer "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" \
  --wait
```

`--wait` 会阻塞到出结果(通常 2~10 分钟),输出 `status: Accepted` 即通过。

### 5.2 贴票据(staple)

```bash
xcrun stapler staple "$APP"
```

### 5.3 最终验证

```bash
spctl --assess --type execute -vv "$APP"
# 期望输出:WildFireChat.app: accepted
#            source=Notarized Developer ID
```

### 5.4 公证失败排查

```bash
# 查看详细日志(把 submission-id 换成 submit 输出里的 id)
xcrun notarytool log <submission-id> \
  --apple-id "you@example.com" --team-id "TEAMID" --password "xxxx-xxxx-xxxx-xxxx"
```

常见失败原因:

| 错误特征 | 原因 | 处理 |
|---------|------|------|
| `The binary is not signed` | 某个 dylib/framework 漏签 | 回到 §4.1 第一步,确认 find 覆盖全部 |
| `The signature does not include a secure timestamp` | 签名缺 `--timestamp` | 重签(时间戳服务器需联网) |
| `The executable does not have the hardened runtime enabled` | 缺 `--options runtime` | 重签 |
| `The signature of the binary is invalid` | 主 App 先签、后改了内部文件(顺序错了) | 严格按先内后外重签 |

## 6. 打包 DMG

```bash
# 简单方式:create-dmg(brew install create-dmg)
create-dmg \
  --volname "野火IM" \
  --window-size 600 400 \
  --icon-size 128 \
  --app-drop-link 450 185 \
  "WildFireChat.dmg" \
  "$APP"
```

DMG 本身也建议签名(非必须):`codesign --sign "$IDENTITY" --timestamp WildFireChat.dmg`。

## 7. 发版检查清单

每次发版按顺序执行:

- [ ] 递增 `chat/pubspec.yaml` 的 version
- [ ] `flutter build macos --release`
- [ ] §4 签名(先内后外,主 App 带 Release.entitlements)
- [ ] `codesign --verify --deep --strict` 通过
- [ ] §5 公证 `Accepted` + `stapler staple`
- [ ] `spctl --assess` 显示 `source=Notarized Developer ID`
- [ ] 打 DMG
- [ ] **找一台没装过开发环境的 Mac 验证**:下载 → 双击能直接打开、截图功能可用

## 8. 常见问题

**Q:用户仍提示"已损坏,无法打开"?**
A:多半是没 staple 或用户离线。检查 `xcrun stapler validate "$APP"`;让用户执行 `xattr -dr com.apple.quarantine WildFireChat.app` 可临时绕过(不推荐作为正式方案)。

**Q:公证通过但截图没反应?**
A:与公证无关,是屏幕录制权限未授予。引导用户到 系统设置 → 隐私与安全性 → 屏幕录制 勾选野火IM(见 SCREENSHOT.md §7)。

**Q:可以自动化吗?**
A:可以。把 §3~§6 写成脚本或 GitHub Actions workflow,凭据用 API Key 方式(§5.1 B)存入 CI secrets。注意不要对 Debug 构建做公证,只有发版构建需要。

**Q:以后想回 Mac App Store 怎么办?**
A:沙盒已开启、ScreenCaptureKit 截图沙盒兼容、`LSApplicationCategoryType` 已加、flameshot 打包已移除,macOS 侧障碍已清。提交前还需:① 全功能回归(重点:沙盒容器内数据目录、文件收发、多窗口、通话);② 改用 App Store 分发证书与描述文件签名(不用公证);③ iOS 侧合规项按 CALLKIT_GUIDE.md 与隐私清单处理。
