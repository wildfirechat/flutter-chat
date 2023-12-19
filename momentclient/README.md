# Flutter平台朋友圈说明
Flutter平台朋友圈是基于原生朋友圈SDK进行包装的，支持android和iOS平台，仅有SDK，没有UI功能，如果需要朋友圈功能，需要自己来开发对应UI。

## 获取SDK
野火朋友圈功能是收费的，依赖专业版IM服务（专业版IM服务开启mongodb数据库），需要对应原生的朋友圈SDK。可以申请[试用](https://docs.wildfirechat.cn/trial/)得到专业版IM服务和朋友圈SDK。

只有使用专业版IM服务且使用mongodb，且客户端使用定制的朋友圈SDK才可以正常使用朋友圈功能。

替换朋友圈SDK的方法：android平台把得到的SDK替换到[android_moment_aars](../android_moment_aars)目录的SDK；iOS平台替换到[WFSDK](ios/WFSDK)目录下的SDK。***iOS平台需要额外处理，删除掉SDK内除了```WFMClientJsonClient.h```以外的所有头文件***。

## 开启朋友圈功能
1. 在example项目的pubspec.yaml文件中，打开下面的注释:
```
momentclient:
  path: ../momentclient/
```
2. 在example项目的```example/android/app/build.gradle```文件中，打开下面的注释:
```
    implementation fileTree(dir: "../../../android_moment_aars", include: ["*.aar"])
```
3. 在example目录下执行```flutter pub get```，如果有iOS平台，进入到```example/ios```，执行```pod install```。
4. 在example项目中初始化imclient的地方，初始化朋友圈，代码如下:
```
  //初始化IM
  Imclient.init(...);

  //初始化朋友圈
  MomentClient.init((comment) {    
  }, (feed){    
  });
```

## 使用
在引入SDK及初始化后，就可以使用朋友圈功能了。朋友圈所有接口都在```MomentClient```对象中，一共16个接口，还是比较简单的。如果发送图片或者视频，需要先上传再发送。朋友圈SDK没有上传功能，需要调用IM服务接口或者你们自己的接口来上传。
