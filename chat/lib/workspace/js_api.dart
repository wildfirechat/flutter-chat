import 'dart:async';
import 'dart:convert';
import 'package:dsbridge_flutter/dsbridge_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';
import 'package:chat/utils/show_toast.dart';
import 'package:chat/workspace/wf_webview_screen.dart';
import 'package:chat/l10n/app_localizations.dart';

import '../contact/pick_user_screen.dart';

class JsApi extends JavaScriptNamespaceInterface {
  final BuildContext context;

  /// 本次绑定的应用地址。非 final:工作台会把关掉的 WebView 收回池子复用
  /// (原生 WebView 销毁不了,见 pubspec 里的说明),复用时要换成新页签的地址
  /// —— `getAuthCode` 取的 host 和 [_preCheck] 都依赖它。见 [rebind]。
  String appUrl;

  late String currentUr;
  final DWebViewController webViewController;

  /// 页内 `openUrl` 的去向。工作台(PC)传入"开新页签",不传则整页 push
  /// [WFWebViewScreen] —— 移动端与独立网页页面走后者。
  final void Function(String url)? onOpenUrl;

  /// 页内 `close` 的去向。工作台(PC)传入"关掉当前页签",不传则 Navigator.pop。
  final VoidCallback? onClose;

  /// 推入一个盖住当前 WebView 的全屏页面(联系人选择、内嵌网页跳转等)。
  ///
  /// 不能自己简单 `Navigator.push`:Linux 上原生 WebView 是叠在 Flutter 画面上的
  /// 独立 GTK 窗口,位置只在 [WebViewWidget] 对应 RenderObject `paint()` 时才会
  /// 同步给原生侧;仅仅被上层不透明路由盖住,Navigator 会跳过它的 `paint()`,
  /// 原生窗口收不到通知,会继续悬浮在最上层挡住新页面、吞掉点击。宿主实现这个
  /// 回调时要先把自己的 [WebViewWidget] 从树上真正摘掉(让插件自身正确的
  /// dispose 流程去隐藏原生窗口),等 [builder] 对应的路由弹出后再挂回来
  /// (重新挂载时第一帧 paint 会自动把原生窗口位置复位)。
  final Future<void> Function(WidgetBuilder builder) pushOverlay;

  JsApi(
    this.context,
    this.appUrl,
    this.webViewController, {
    required this.pushOverlay,
    this.onOpenUrl,
    this.onClose,
  }) {
    currentUr = appUrl;
  }

  setCurrentUrl(String url) {
    currentUr = url;
  }

  /// WebView 被复用到另一个页签时改绑地址。
  void rebind(String url) {
    appUrl = url;
    currentUr = url;
  }

  @override
  void register() {
    registerFunction(openUrl);
    registerFunction(close);
    registerFunction(getAuthCode);
    registerFunction(config);
    registerFunction(toast);
    registerFunction(chooseContacts);
  }

  void openUrl(dynamic url) {
    debugPrint('openUrl $url');
    // 参数有两种形态:工作台 H5 在 `window.__wf_bridge_` 存在时传的是
    // `{url, name}`,否则传 URL 字符串(见 work.html 里 openUrl 的实现)。
    // 早先只做 `'$url'`,拿到对象时会把整个 Map 当地址用。
    final String? resolved = url is String
        ? url
        : (url is Map ? url['url']?.toString() : url?.toString());
    if (resolved == null || resolved.isEmpty) {
      debugPrint('openUrl ignored: 参数里没有地址 -> $url');
      return;
    }
    if (onOpenUrl != null) {
      onOpenUrl!(resolved);
      return;
    }
    unawaited(pushOverlay((context) => WFWebViewScreen(resolved)));
  }

  void close(dynamic obj, CompletionHandler handler) {
    if (onClose != null) {
      onClose!();
      return;
    }
    Navigator.pop(context);
  }

  void getAuthCode(dynamic obj, CompletionHandler handler) {
    debugPrint('getAuthCode $obj ${obj.runtimeType}');
    String appId = obj["appId"];
    int type = obj["appType"];
    String host = Uri.parse(appUrl).host;
    debugPrint('getAuthCode $appId $type $host');
    // // 开发调试时，将 host 固定写是为开发平台上该应用的回调地址对应的 host
    Imclient.getAuthCode(appId, type, host, (result) {
      handler.complete({'code': 0, 'data': result});
    }, (err) {
      debugPrint('getAuthCode error $err');
      handler.complete({'code': err});
    });
  }

  void config(dynamic obj) {
    debugPrint('config $obj');
    String appId = obj["appId"];
    int type = obj["appType"];
    int timestamp = obj["timestamp"];
    String nonce = obj["nonceStr"];
    String signature = obj["signature"];
    Imclient.configApplication(appId, type, timestamp, nonce, signature, () {
      debugPrint('config success');
      webViewController.callHandler('ready', args: null);
    }, (err) {
      debugPrint('config err $err');
      webViewController.callHandler('error', args: ['$err']);
    });
  }

  void toast(dynamic text) {
    debugPrint('toast $text');
    // 走项目自己的 toast:fluttertoast 在桌面端不显示,而工作台是桌面重点场景。
    showToast(msg: '$text');
  }

  void chooseContacts(Object obj, CompletionHandler handler) {
    if (!_preCheck()) {
      _callbackJs(handler, -2);
      return;
    }
    unawaited(pushOverlay((context) =>
        PickUserScreen(title: AppLocalizations.of(context)!.selectContacts,
            (_, members) async {
          if (members.isEmpty) {
            Fluttertoast.showToast(
                msg: AppLocalizations.of(context)!.pickFriendsToSubmitReport);
          } else {
            //callbackJs(handler, 0, userInfos);

            List<UserInfo> userInfos = await Imclient.getUserInfos(members);
            List<Map<String, dynamic>> userInfoList = [];
            for (var userInfo in userInfos) {
              userInfoList.add({
                'uid': userInfo.userId,
                'name': userInfo.name,
                'displayName': userInfo.displayName,
                'portrait': userInfo.portrait,
              });
            }
            _callbackJs2(handler, 0, json.encode(userInfoList));
            Navigator.pop(context);
          }
        })));
  }

  _preCheck() {
    final ok = appUrl == currentUr;
    if (!ok) {
      // chooseContacts "第一次生效、后面不一定生效"排查用:如果这里打出的
      // appUrl/currentUr 不一致,说明页面发生过 _preCheck 判定意义上的"跳走"
      // (含 SPA pushState/hash 变化触发的 onUrlChange),之后的 chooseContacts
      // 全部会在这里被拦掉、静默返回 -2,和 WebView 挂载/隐藏逻辑无关。
      debugPrint('JsApi._preCheck failed: appUrl=$appUrl currentUr=$currentUr');
    }
    return ok;
  }

  _callbackJs(CompletionHandler handler, int code) {
    _callbackJs2(handler, code, null);
  }

  _callbackJs2(CompletionHandler handler, int code, String? result) {
    Map<String, dynamic> object = {};
    object["code"] = code;
    object["data"] = result;
    handler.complete(object);
  }
}
