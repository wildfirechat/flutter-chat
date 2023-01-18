## 野火IM解决方案

野火IM是专业级即时通讯和实时音视频整体解决方案，由北京野火无限网络科技有限公司维护和支持。

主要特性有：私有部署安全可靠，性能强大，功能齐全，全平台支持，开源率高，部署运维简单，二次开发友好，方便与第三方系统对接或者嵌入现有系统中。详细情况请参考[在线文档](https://docs.wildfirechat.cn)。

主要包括一下项目：

| [GitHub仓库地址(主站)](https://github.com/wildfirechat)      | [码云仓库地址(镜像)](https://gitee.com/wfchat)        | 说明                                                                                      | 备注                                           |
| ------------------------------------------------------------ | ----------------------------------------------------- | ----------------------------------------------------------------------------------------- | ---------------------------------------------- |
| [android-chat](https://github.com/wildfirechat/android-chat) | [android-chat](https://gitee.com/wfchat/android-chat) | 野火IM Android SDK源码和App源码                                                           | 可以很方便地进行二次开发，或集成到现有应用当中 |
| [ios-chat](https://github.com/wildfirechat/ios-chat)         | [ios-chat](https://gitee.com/wfchat/ios-chat)         | 野火IM iOS SDK源码和App源码                                                               | 可以很方便地进行二次开发，或集成到现有应用当中 |
| [pc-chat](https://github.com/wildfirechat/pc-chat)           | [pc-chat](https://gitee.com/wfchat/pc-chat)           | 基于[Electron](https://electronjs.org/)开发的PC平台应用                                   |                                                |
| [web-chat](https://github.com/wildfirechat/web-chat)         | [web-chat](https://gitee.com/wfchat/web-chat)         | Web平台的Demo, [体验地址](http://web.wildfirechat.cn)                                     |                                                |
| [wx-chat](https://github.com/wildfirechat/wx-chat)           | [wx-chat](https://gitee.com/wfchat/wx-chat)           | 微信小程序平台的Demo                                                                      |                                                |
| [server](https://github.com/wildfirechat/server)             | [server](https://gitee.com/wfchat/server)             | IM server                                                                                 |                                                |
| [app server](https://github.com/wildfirechat/app_server)     | [app server](https://gitee.com/wfchat/app_server)     | 应用服务端                                                                                |                                                |
| [robot_server](https://github.com/wildfirechat/robot_server) | [robot_server](https://gitee.com/wfchat/robot_server) | 机器人服务端                                                                              |                                                |
| [push_server](https://github.com/wildfirechat/push_server)   | [push_server](https://gitee.com/wfchat/push_server)   | 推送服务器                                                                                |                                                |
| [docs](https://github.com/wildfirechat/docs)                 | [docs](https://gitee.com/wfchat/docs)                 | 野火IM相关文档，包含设计、概念、开发、使用说明，[在线查看](https://docs.wildfirechat.cn/) |                                                |  |


# WFC Flutter Plugins
野火Flutter插件，包含即时通讯插件和实时音视频插件。

## V1版本
master分支为新版本，之前旧版本在v1分支。请尽快升级到新版本。

## 运行
进入到项目工程目录下，依次执行下述命令：
1. ``` cd example && flutter packages get && cd .. ```
2. ``` cd example/ios/ && pod install && cd ..```(仅iOS平台需要)
3. ``` cd example && flutter run ```

## 集成到flutter应用
1. 在项目的```pubspec.yaml```文件依赖配置中，添加如下内容。其中 ```${path_to_imclient}``` 和 ```${path_to_imclient}``` 为 本项目的```imclient```和```rtckit```目录。
```
dependencies:
  flutter:
    sdk: flutter

  imclient:
    path: ${path_to_imclient}
  rtckit:
    path: ${path_to_rtckit}
```
2. 项目目录下执行 ``` flutter packages get``` 命令。
3. 如果有iOS平台，执行 ``` cd example/ios/ && pod install ``` 命令。
4. 分别运行iOS平台和Android平台。

## SDK的使用
### 基础知识
必须对野火IM有一定认识后才可以顺利使用，建议做到以下几点：
1. 仔细阅读野火[基础知识](https://docs.wildfirechat.cn/base_knowledge/)，建议最好把[文档](https://docs.wildfirechat.cn)都看一遍，仔细阅读一遍绝对会物超所值的。
2. 仔细查看插件的接口文件```FlutterImclient.dart```文件，大概130+个接口，根据接口名称和简单的注释还有参数，了解到具体的功能，这样后面使用时也比较好找。
3. 查看插件带的demo应用。demo应用十分不完善，但也基本能反应出使用的方法，如果您有时间可以给我们提PR来完善这个demo。
4. 如果您有原生客户端开发经验，可以查看对于客户端的demo，原生客户端demo比较完善。

### 初始化
初始化在应用启动时唯一调用一次即可，参数是各种事件的回调。
```
FlutterImclient.init(...);
```

### 连接
连接需要```IM Token```，必须在应用服务进行获取```token```，获取```token```时必须使用从SDK内获取到的```clientId```，否则会连接不上。
```
var clientId = await FlutterImclient.clientId;
// 调用应用服务去IM服务获取token，需要使用从SDK内获取的clientId。得到token后调用connect函数。
FlutterImclient.connect(Config.IM_Host, userId, token);
```

### 获取会话列表
展示用户的所有会话的列表使用。
```
FlutterImclient.getConversationInfos([ConversationType.Single, ConversationType.Group, ConversationType.Channel], [0]);
```

### 获取消息
从指定会话获取消息，可以指定消息其实id和获取条目数，实际使用时可以滚动加载。
```
FlutterImclient.getMessages(conversation, 0, 10);
```

### 发送消息
构造消息内容，把消息发送到指定会话去。
```
FlutterImclient.sendMessage(conversation, txtMsgContent);
```

### 获取用户信息
refresh参数表明是否强制从服务器刷新用户信息，函数会返回本地数据库存储用户信息，如果不存在将返回null。refresh为true或者用户信息不存在时会从服务器更新用户信息，如果信息有变化，会通过用户信息变更回调通知。注意仅当单聊会话和用户详情时强制刷新，避免反复refresh调用出现死循环。
```
getUserInfo(userId, refresh:false);
```

### 获取群组信息
获取群组信息，具有可选参数refresh，refresh的使用方法请参考获取用户信息。
```
getGroupInfo(groupId, refresh:false);
```

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
在iOS平台，pushType是无效参数，可以为任意值；在Android平台pushType为选取的推送平台。

### 4 服务端推送开发
下载[野火推送服务](https://gitee.com/wfchat/push_server)，在此基础上进行二次开发。推送服务会收到IM服务的推送请求，推送请求中有这个pushType和deviceToken及要推送的内容，推送服务根据这些信息找到对应厂商进行推送。

## 一些知识要点
1. 获取token的过程一定是先从客户端获取clientId，然后应用服务使用clientId和userId参数获取token，返回给当前客户端使用。即token是和客户端绑定的，该token仅能在当前客户端使用。
2. 获取用户/群组/频道信息时，都是直接返回本地数据，如果本地没有会返回null且去服务器更新，更新成功后会有eventbus通知。编写UI代码时需要考虑到获取信息为空的可能，并做好监听，以便信息更新能更新UI。
3. 展示消息是分批获取的，先获取最新的一部分，然后列表滚动式再加载下一批，以此类推。
