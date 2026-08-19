## 重要声明!!!

Android 和 iOS 可以免费使用，其中iOS可以直接配置 IM_SERVER_HOST来设定服务地址。Android需要联系我们免费获取SDK。

**因反诈合规要求，本项目协议栈默认仅支持连接野火官方服务，不能连接到自行部署的服务。如需获取不受限版本，请联系官方微信（wfchat 或 wildfirechat）免费申请。**

> 联系官方获取到不受限版本后，请替换`./imclient/android/android_client_aars/mars-core-release.aar`文件，并重新编译。

其他平台，包括Windows/Mac/Linux/Harmony平台是付费的，需要联系我们申请试用或者购买，请联系官方微信（wfchat 或 wildfirechat）申请试用。

---------


## 野火IM解决方案

野火IM是专业级即时通讯和实时音视频整体解决方案，由北京野火无限网络科技有限公司维护和支持。

主要特性有：私有部署安全可靠，性能强大，功能齐全，全平台支持，开源率高，部署运维简单，二次开发友好，方便与第三方系统对接或者嵌入现有系统中。详细情况请参考[在线文档](https://docs.wildfirechat.cn)。

主要包括一下项目：

| [GitHub仓库地址(主站)](https://github.com/wildfirechat)            | [码云仓库地址(镜像)](https://gitee.com/wfchat)                | 说明                                                             | 备注                      |
|--------------------------------------------------------------|-------------------------------------------------------|----------------------------------------------------------------|-------------------------|
| [android-chat](https://github.com/wildfirechat/android-chat) | [android-chat](https://gitee.com/wfchat/android-chat) | 野火IM Android SDK源码和App源码                                       | 可以很方便地进行二次开发，或集成到现有应用当中 |
| [ios-chat](https://github.com/wildfirechat/ios-chat)         | [ios-chat](https://gitee.com/wfchat/ios-chat)         | 野火IM iOS SDK源码和App源码                                           | 可以很方便地进行二次开发，或集成到现有应用当中 |
| [pc-chat](https://github.com/wildfirechat/pc-chat)           | [pc-chat](https://gitee.com/wfchat/pc-chat)           | 基于[Electron](https://electronjs.org/)开发的PC平台应用                 |                         |
| [web-chat](https://github.com/wildfirechat/web-chat)         | [web-chat](https://gitee.com/wfchat/web-chat)         | Web平台的Demo, [体验地址](http://web.wildfirechat.cn)                 |                         |
| [wx-chat](https://github.com/wildfirechat/wx-chat)           | [wx-chat](https://gitee.com/wfchat/wx-chat)           | 微信小程序平台的Demo                                                   |                         |
| [server](https://github.com/wildfirechat/server)             | [server](https://gitee.com/wfchat/server)             | IM server                                                      |                         |
| [app server](https://github.com/wildfirechat/app_server)     | [app server](https://gitee.com/wfchat/app_server)     | 应用服务端                                                          |                         |
| [robot_server](https://github.com/wildfirechat/robot_server) | [robot_server](https://gitee.com/wfchat/robot_server) | 机器人服务端                                                         |                         |
| [push_server](https://github.com/wildfirechat/push_server)   | [push_server](https://gitee.com/wfchat/push_server)   | 推送服务器                                                          |                         |
| [docs](https://github.com/wildfirechat/docs)                 | [docs](https://gitee.com/wfchat/docs)                 | 野火IM相关文档，包含设计、概念、开发、使用说明，[在线查看](https://docs.wildfirechat.cn/) |                         |  |

## 技术交流

1. 如果大家发现bug，请在GitHub或码云提issue；如果有需求也请给我们提issue。
2. 其他问题，请到[野火IM论坛](http://bbs.wildfirechat.cn/)进行交流学习
3. 关注我们的公众号。我们有新版本发布或者有重大更新会通过公众号通知大家，另外我们也会不定期的发布一些关于野火IM的技术介绍。

<img src="http://static.wildfirechat.cn/wx_wfc_qrcode.jpg" width = 50% height = 50% />

我们有核心研发工程师轮流值班处理issue和论坛，会及时处理的，疑难Bug的修改和新需求的开发我们也会尽快解决。

# flutter-chat

野火Flutter版 客户端， 支持 Android、iOS、原生鸿蒙和桌面端（Windows、macOS、Linux），包含即时通讯插件和实时音视频插件。不支持龙芯和申威CPU（因为flutter不支持），其他国产操作系统和CPU都支持。

## 项目特点

- **一套代码全平台覆盖**：Android、iOS、原生鸿蒙、Windows、macOS、Linux 共用同一套 Dart UI 与业务逻辑；IM 底层按平台分流——移动端走原生插件（iOS/Android），桌面端走 dart:ffi 直连 libMarsWrapper，鸿蒙走 HAR，对上层暴露统一的 `imclient` Dart API。
- **PC 桌面端深度适配（对齐常见即时通讯 PC 体验）**：三栏式桌面 Shell、系统托盘、微信式沉浸标题栏；完整的桌面多窗口体系——音视频通话、图片视频预览、朋友圈、会话内搜索均为独立窗口，并有统一的多窗口公共层（窗口基类/管理器/事件通道/IM 调用代理）。
- **音视频通话**：单人/多人/会议全支持；移动端可最小化为可拖动悬浮窗（语音显示图标+时长，视频显示远端画面或对方头像，未接通也可最小化）；PC 端通话在独立窗口进行；iOS 已集成 CallKit 系统来电界面。
- **会话内消息查找**：关键字搜索（分页、高亮、搜索历史）、按文件/图片与视频/链接/日期（日历）分类查找、点结果精确定位到消息上下文、定位后可一键"回到最新"；PC 端为独立的"聊天记录"窗口。
- **朋友圈**：自研 `moment` 包（SDK + UI 一体），支持发布图文/视频、评论、点赞、可见范围、背景图设置、按用户查看；移动端发现页进入，PC 端为独立窗口（封面全宽 + 内容居中）。
- **消息体验细节**：消息时间分隔（2 分钟规则、星期几格式）、双击"消息"tab 滚动到第一个未读会话、通话消息卡片（状态+时长+类型图标，点击重拨）、收藏、消息多选转发。
- **系统能力集成**：iOS CallKit 与 Share Extension（从系统分享面板直接分享到会话）、PC 三平台开机自启动（设置-通用内开关）、桌面端 flameshot 截图发送。

## 桌面端截图

本项目桌面端截图：macOS 使用苹果原生 **ScreenCaptureKit**（自研覆盖窗 + 标注编辑器，见 `chat/macos/Runner/Screenshot/`）；Windows/Linux 使用 [flameshot](https://flameshot.org/) 作为独立截图工具，通过 `Process.run` 调起。详细的构建、打包、权限与许可证说明请参考 [SCREENSHOT.md](./SCREENSHOT.md)。

> **macOS 沙盒**：截图使用 ScreenCaptureKit，沙盒兼容（首次使用需在 系统设置 → 隐私与安全性 → 屏幕录制 授权）。`Release.entitlements` 已开启 `com.apple.security.app-sandbox`，对外分发（Developer ID + 公证）或上架 Mac App Store 均可，流程见 [MACOS_DISTRIBUTION.md](./MACOS_DISTRIBUTION.md)。

## 关于 Android Studio、Gradle 版本的重要说明

1. Android Studio 会跟随官方更新，一直使用最新版本
2. 由于 gradle 版本和 flutter 版本有依赖关系，会使用对应的 gradle 版本，目前是 `8.7`
3. Flutter 版本：鸿蒙开发必须使用鸿蒙适配版 Flutter，其他平台使用官方版本，详见下方「鸿蒙(OHOS)开发指南」

## 关于 Linux arm64 环境的重要说明
1. 安装依赖
  ```
  sudo apt install clang cmake ninjia-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libwebkit2gtk-4.1-dev libayatana-appindicator3-dev curl unzip xz-utils zip libglu1-mesa

  ```
2. 安装 flutter 环境
  > 由于官方并没有发布`Linux Arm64`的包，只能通过`git clone` 方式安装；可能也能通过`VS Code`来安装
  ```
  git clone https://github.com/flutter/flutter.git -b stable --depth=1
  flutter --version #确认版本
  ```


## 鸿蒙(OHOS)开发指南

鸿蒙相关的注意事项集中在本节：SDK 费用、Flutter 版本、镜像配置、依赖切换与常见问题。

### 1. SDK 与费用

鸿蒙版所依赖的野火IM鸿蒙 SDK 是付费的，可申请试用（联系方式见顶部「重要声明」）。

### 2. Flutter 版本与 IDE 配置

1. 开发鸿蒙必须使用鸿蒙适配版 Flutter，当前开发版本为 `3.35.8-ohos`（Dart 3.9.x）；其他平台使用官方 Flutter。
2. 请参考 [这儿](https://gitcode.com/openharmony-tpc/flutter_flutter) 安装和配置 Flutter，使用该仓库 3.35.x 系列的鸿蒙适配分支。安装和配置很简单，下载下来解压，然后配置一下环境变量就好了。
3. IDE 开发运行时，需要确保使用的是鸿蒙适配版。

### 3. 配置 pub 镜像

由于目标是能兼容原生鸿蒙，有的包只能从镜像下载，不配置镜像的话，可能下载不到：

```
# Linux、macOS
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

# windows 
setx PUB_HOSTED_URL "https://pub.flutter-io.cn"
setx FLUTTER_STORAGE_BASE_URL "https://storage.flutter-io.cn"
```

### 4. 依赖切换（标准版 ↔ 鸿蒙版）

项目内所有包的 `dependencies` 均使用 pub.dev 标准版；鸿蒙适配版（gitcode 上的 openharmony-sig / openharmony-tpc fork）统一集中在根工程 `chat/pubspec.yaml` 的 `dependency_overrides` 中，由 `[ohos-begin]` 和 `[ohos-end]` 注释标记围成一个区块。

- **构建鸿蒙版本**：启用该区块（取消区块内各条目的注释；仓库当前默认该区块处于注释状态，即标准版依赖）。注意同时要把区块上方的 `flutter_webrtc` 本地补丁 override 注释掉，否则 `dependency_overrides` 中 `flutter_webrtc` 出现两次，pub 会报重复 key。然后执行 `flutter pub get`。
- **构建标准版本（Android/iOS/Windows/macOS/Linux）**：把 `[ohos-begin]` 到 `[ohos-end]` 之间的内容整体注释掉，然后执行 `flutter pub get`，所有依赖即回退到 pub.dev 标准版。

注意事项：

1. 切换后必须重新执行 `flutter pub get`，并建议提交代码前确认 `chat/pubspec.lock` 的变更符合预期。
2. 区块内包含仅鸿蒙需要的 `permission_handler_ohos` 插件，注释区块时会一并移除，无需单独处理。
3. `file_picker` 的鸿蒙 fork 依赖 `web ^0.5.1`，与 `flutter_localization` 鸿蒙版依赖的 `web ^1.1.1` 冲突，因此它和 `fluttertoast`、`flutter_local_notifications`、`mobile_scanner`、`flutter_webrtc` 的鸿蒙 fork 默认未启用（保持标准版），在区块内以注释形式保留，确有需要时可单独启用。
4. 切换时若遇到 gitcode 拉取失败（exit 128），重试 `flutter pub get` 即可。
5. iOS/mac 平台切换后需同步更新 pod 依赖，否则 `Podfile.lock` 中锁定的旧版本会与新解析的插件版本冲突（典型报错：`CocoaPods could not find compatible versions for pod "xxx"`）：
   ```bash
   cd chat/ios 或 cd chat/macos
   pod install --repo-update   # 或者针对报错的 pod 单独执行：pod update <pod名>
   ```
   例如 `flutter_sound` 当前在标准版固定为 9.28.0，若 `Podfile.lock` 中锁定的是其他版本，需执行 `pod update flutter_sound_core`。

### 5. 常见问题

1. 鸿蒙上提示包找不到，请从 [flutter_packages](https://gitcode.com/openharmony-tpc/flutter_packages) 查询已适配鸿蒙平台的版本，并固定为该版本。

## Windows的依赖
1. MSVC 2022(其他版本测试都有问题，有些依赖编译不过去)

## 运行

### 终端运行
进入到项目工程目录下，依次执行下述命令：

1. ``` cd chat && flutter packages get && cd .. ```
2. ``` cd chat/ios/ && pod install && cd ..``` (仅iOS平台需要)
3. ``` cd chat/macos/ && pod install && cd ..``` (仅Mac平台需要)
3. ``` cd chat && flutter run --debug -d ${设备 id}```

### 桌面端运行（Windows / macOS / Linux）
1. 确保使用对应平台的官方 Flutter SDK。
2. 进入 `chat` 目录执行 `flutter packages get`。
3. 运行对应命令：
   - macOS：`flutter run -d macos` 或 `flutter build macos`
   - Windows：`flutter run -d windows` 或 `flutter build windows`
     > 需安装 [Visual Studio 2022](https://aka.ms/vs/17/release/vs_community.exe)，完整环境配置说明，请参考 [Set up Windows development](https://docs.flutter.dev/platform-integration/windows/setup)
   - Linux：`flutter run -d linux` 或 `flutter build linux`
     > Linux 环境配置说明，请参考 [Setup Linux development](https://docs.flutter.dev/platform-integration/linux/setup)
4. 桌面端已支持音视频通话（在独立窗口进行）、图片/视频预览、朋友圈、会话内搜索（"聊天记录"窗口）等功能；拍照等移动端特有的功能在桌面端不显示。
5. macOS 版对外分发（Developer ID 签名 + 公证 + 打包 DMG）的完整流程，请参考 [MACOS_DISTRIBUTION.md](./MACOS_DISTRIBUTION.md)。

## 集成到flutter应用

1. 在项目的```pubspec.yaml```文件依赖配置中，添加如下内容。其中 ```${path_to_imclient}``` 和 ```${path_to_avenginekit}``` 为 本项目的```imclient```和```avenginekit```目录。
    ```
    dependencies:
      flutter:
        sdk: flutter

      imclient:
        path: ${path_to_imclient}
      avenginekit:
        path: ${path_to_avenginekit}
    ```

2. 在项目```android/app/build.gradle```文件中配置混淆规则，并添加依赖
   ```groovy
      buildTypes {
        release {
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig signingConfigs.debug
            shrinkResources true
            // 是否开启混淆，如果开启了混淆，需要在proguard-rules.pro中添加规则，可参考build.gradle同目录中的混淆棍子，避免混淆掉野火IM相关类。
            // 如果开启混淆，但混淆规则配置错误，应用可能无法启动，或不能正常连接到IM服务。
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
        debug{
            signingConfig signingConfigs.debug
            shrinkResources true
            // 是否开启混淆，如果开发调试阶段，不想开启混淆，需要显示配置为false。
            minifyEnabled false
        }
    }


      dependencies {

        // 将path_to_android_xxx_aars 替换成实际路径，可以使用相对路径，但一定要保证路径是正确的；路径不对的话，会报 ClassNotFoundException
        // moment 对应的是朋友圈SDK，ptt对应的是对接SDK。仅当购买或者试用这两个功能的用户打开这两个包的引入。

        // wfc dep start
        implementation fileTree(dir: "${path_to_android_client_aars}", include: ["*.aar"])
        implementation fileTree(dir: "${path_to_android_avclient_aars}", include: ["*.aar"])
        //implementation fileTree(dir: "${path_to_android_moment_aars}", include: ["*.aar"])
        //implementation fileTree(dir: "${path_android_ptt_aars}", include: ["*.aar"])

        // wfc dep end
    }
    ```

3. 项目目录下执行 ``` flutter packages get``` 命令。
4. 如果有iOS平台，执行 ``` cd chat/ios/ && pod install ``` 命令。
5. 分别运行 iOS、Android、鸿蒙或桌面端（Windows / macOS / Linux）平台。桌面端需要使用对应平台的官方 Flutter SDK 编译。
6. Android 平台，集成音视频的时候，需要在`AndroidManifest.xml`入口`activity`的配置里面添加如下`intent-filter`
   ```xml
    <!-- 音视频通话，需要加入下面的 intent-filter-->
    <intent-filter>
        <action android:name="${applicationId}.main" />
        <category android:name="android.intent.category.DEFAULT" />
    </intent-filter>

    ```

## 升级插件注意事项

1. 升级插件时，一定要记得同步升级`android_client_aars`和`android_avclient_aars`等`aars`目录

## 推送

### 1 野火推送基础知识

实现推送需要客户端和服务端研发配合实现，首先需要掌握野火推送的流程才可以，关于野火推送的知识，在[野火推送服务](https://gitee.com/wfchat/push_server)的项目说明上有详细描述，请客户端研发和服务端研发详细阅读。

### 2 推送平台的选取

目前有多种推送方案可选，可以选取手机厂商的推送，也可以选取第三方推送。需要根据您的需求来选取适合您的方案。

### 3 客户端的集成

客户端集成选取的推送平台的flutter插件，每个推送插件注册成功后，都会返回一个注册ID（或者是其他名称，能够唯一代表当前推送设备的ID），然后调用```imclient```的下面接口

```
Imclient.setDeviceToken(pushType, deviceToken);
```

### 4 服务端推送开发

下载[野火推送服务](https://gitee.com/wfchat/push_server)，在此基础上进行二次开发。推送服务会收到IM服务的推送请求，推送请求中有这个pushType和deviceToken及要推送的内容，推送服务根据这些信息找到对应厂商进行推送。

### 5 使用个推

实际上可以选用任意一个或者多个推送服务商，这里给出一个使用个推的介绍。
[对接个推](https://gitee.com/wfchat/flutter-chat/issues/I6P16V?from=project-issue)


## iOS 平台 CallKit / Share Extension

本项目 iOS 端已实现 CallKit 来电与系统级 Share Extension 分享，相关文档如下：

- [CallKit 功能说明与移植指南](./CALLKIT_GUIDE.md)
- [Share Extension 功能说明与移植指南](./SHARE_EXTENSION_GUIDE.md)

> 注意：CallKit 需要真机、VoIP Push 证书及服务器端配合才能完整验证；Share Extension 需要主应用与扩展配置同一个 App Group。

## 截图
会话列表

<img alt="会话列表" height="640" src="./screenshots/conversation_list.png" width="295"/>

消息界面

<img alt="消息界面" height="640" src="./screenshots/message_screen.png" width="295"/>

联系人列表

<img alt="联系人列表" height="640" src="./screenshots/contacts.png" width="295"/>

发现界面

<img alt="发现界面" height="640" src="./screenshots/discover.png" width="295"/>

设置界面

<img alt="设置界面" height="640" src="./screenshots/settings.png" width="295"/>

单人视频通话

<img alt="单人视频通话" height="640" src="./screenshots/video_call_1v1.png" width="295"/>

多人视频通话

<img alt="多人视频通话" height="640" src="./screenshots/video_call_multi.png" width="295"/>

## 常见问题

1. `Execution failed for task ':video_player_android:compileDebugJavaWithJavac'.`
    1. 查看 `chat/.flutter-plugins` 找到 `video_player_android` 的位置，macos 时，位置如下: `video_player_android=/Users/your-user-name/.pub-cache/hosted/pub.flutter-io.cn/video_player_android-2.8.4/`
    2. 参考[Remove -Werror from Android build](https://github.com/flutter/packages/pull/7776/files) 修改`android/build.gradle`
2. 鸿蒙相关的常见问题（包找不到、gitcode 拉取失败、切换后 pod 冲突等），见上方「鸿蒙(OHOS)开发指南」。



## 一些知识要点

1. 获取token的过程一定是先从客户端获取clientId，然后应用服务使用clientId和userId参数获取token，返回给当前客户端使用。即token是和客户端绑定的，该token仅能在当前客户端使用。
2. 获取用户/群组/频道信息时，都是直接返回本地数据，如果本地没有会返回null且去服务器更新，更新成功后会有eventbus通知。编写UI代码时需要考虑到获取信息为空的可能，并做好监听，以便信息更新能更新UI。
3. 展示消息是分批获取的，先获取最新的一部分，然后列表滚动式再加载下一批，以此类推。
4. 免费版本音视频需要用到turn服务，上线前请部署自己的turn服务，野火提供开发的带宽比较小无法支持商用。
5. IM服务init时可以传入各种事件的回调，另外基本上每个事件都会同时触发EventBus事件通知，当需要某个通知时也可以用EventBus事件，所有事件定义在```imclient.dart```文件中，比如```ConnectionStatusChangedEvent```是连接状态变化事件。其他事件可以在这附近找到。
