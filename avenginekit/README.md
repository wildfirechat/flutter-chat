# 音视频SDK使用说明

默认使用的是免费版多人音视频，可以更换音视频高级版，支持更高质量的音视频通话和会议功能。关于免费音视频和音视频高级版的区别，请参考[野火音视频简介](https://docs.wildfirechat.cn/blogs/野火音视频简介.html)和[野火音视频使用说明](https://docs.wildfirechat.cn/webrtc/)。

音视频客户端所有代码都是原生代码，包括音视频SDK和UI SDK。音视频SDK是封装的音视频功能库，包括免费版和高级版。UI SDK是野火UI层的代码，包括音视频和会议的交互界面等，兼容2个版本的音视频SDK。音视频SDK和UI SDK以插件的形式集成进来，通过flutter的接口调起原生UI。

如果有需求修改UI界面，需要修改对应平台的原生代码并打包替换。Android平台UI代码在[这里](https://gitee.com/wfchat/android-chat/tree/master/uikit)；iOS平台UI代码在[这里](https://gitee.com/wfchat/ios-chat/tree/master/wfuikit)。

## 音视频免费版使用说明
音视频免费版使用比较简单，部署turn服务后，然后添加turn服务配置后直接使用就行。
```dart
Rtckit.addICEServer('turn:turn.wildfirechat.net:3478', 'wfchat', 'wfchat1');
```

## 音视频高级版的使用说明
音视频高级版包括专业版IM服务，[janus服务](https://gitee.com/wfchat/wf-janus)和客户端音视频高级版SDK。在服务端部署专业版IM服务和janus服务后，客户端需要替换野火发给客户的SDK，替换以后就可以发起音视频通话了。音视频高级版不需要turn服务，不用部署和配置turn服务。

## 音视频会议的使用说明
会议功能是音视频高级版的功能，在打通音视频高级版的音视频通话后，就可以调试和开发会议功能。会议功能的业务逻辑在应用服务实现，音视频UI SDK中会调用应用服务来处理会议的业务。所以如果使用会议功能需要部署应用服务，或者把会议功能的相关代码从应用服务移植到客户的服务上去。

使用应用服务有2中场景，一种场景是没有修改登录逻辑，使用应用服务进行登录，这种方式比较简单，现在demo可以直接使用。另外一种场景是把登录逻辑移动到客户的服务上去，当登录成功后再去IM服务为用户获取token，这时需要多做一项任务，调用应用服务的登录接口（需要做一定的二开，方便实现客户服务调用应用服务模拟登录），为用户获取应用服务的authToken，然后把IMtoken和应用服务的authToken一起返回给客户端，调用下述方法把token传递给原生层：
```dart
Rtckit.setupAppServer(Config.APP_Server_Address, authToken!);
```
这样原生的代码就可以调用应用服务的会议业务。
