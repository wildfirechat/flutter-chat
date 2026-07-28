# 音视频SDK使用说明

默认使用的是免费版多人音视频，可以更换音视频高级版，支持更高质量的音视频通话和会议功能。关于免费音视频和音视频高级版的区别，请参考[野火音视频简介](https://docs.wildfirechat.cn/blogs/野火音视频简介.html)和[野火音视频使用说明](https://docs.wildfirechat.cn/webrtc/)。

音视频SDK即本包（avenginekit），是基于 flutter_webrtc 的纯 Dart 音视频通话引擎封装，通过 imclient 收发通话信令。音视频和会议的交互界面不是原生代码，而是 chat 应用中的 Flutter 代码（chat/lib/call/）。

如果有需求修改UI界面，直接修改 chat 应用的 Flutter 代码（chat/lib/call/）即可。

## 音视频免费版使用说明
音视频免费版**必须自行部署并配置 turn 服务后才能使用**。请自行搭建 turn 服务（如 coturn），然后修改 avenginekit/lib/internal/config.dart 中的 turn 服务地址、用户名和密码为你自己部署的服务。注意：内置的默认地址（turn:turn.wildfirechat.net:3478）仅供开发调试用，带宽有限，禁止商用，上线前务必替换为自建 turn 服务。

## 音视频高级版的使用说明
音视频高级版包括专业版IM服务，[janus服务](https://gitee.com/wfchat/wf-janus)和客户端音视频高级版SDK。在服务端部署专业版IM服务和janus服务后，客户端需要替换野火发给客户的SDK，替换以后就可以发起音视频通话了。音视频高级版不需要turn服务，不用部署和配置turn服务。

## 音视频会议的使用说明
会议功能是音视频高级版的功能，在打通音视频高级版的音视频通话后，就可以调试和开发会议功能。会议功能的业务逻辑在应用服务实现，音视频UI SDK中会调用应用服务来处理会议的业务。所以如果使用会议功能需要部署应用服务，或者把会议功能的相关代码从应用服务移植到客户的服务上去。

使用应用服务有2中场景，一种场景是没有修改登录逻辑，使用应用服务进行登录，这种方式比较简单，现在demo可以直接使用。另外一种场景是把登录逻辑移动到客户的服务上去，当登录成功后再去IM服务为用户获取token，这时需要多做一项任务，调用应用服务的登录接口（需要做一定的二开，方便实现客户服务调用应用服务模拟登录），为用户获取应用服务的authToken，然后把IMtoken和应用服务的authToken一起返回给客户端。应用服务的接口（包括会议业务）由 Flutter 侧的 AppServer（chat/lib/app_server.dart）直接调用，登录成功后它会自动保存并携带应用服务的authToken，无需再向原生层传递token。
