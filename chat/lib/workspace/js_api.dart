import 'dart:convert';
import 'package:dsbridge_flutter/dsbridge_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';
import 'package:chat/workspace/wf_webview_screen.dart';

import '../contact/pick_user_screen.dart';

class JsApi extends JavaScriptNamespaceInterface {
  final BuildContext context;
  final String appUrl;
  late String currentUr;
  final DWebViewController webViewController;

  JsApi(this.context, this.appUrl, this.webViewController) {
    currentUr = appUrl;
  }

  setCurrentUrl(String url) {
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => WFWebViewScreen(url)),
    );
  }

  void close(dynamic obj, CompletionHandler handler) {
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
      webViewController.callHandler('ready', args: null);
    }, (err) {
      webViewController.callHandler('error', args: ['$err']);
    });
  }

  void toast(dynamic text) {
    debugPrint('toast $text');
    Fluttertoast.showToast(msg: text);
  }

  void chooseContacts(Object obj, CompletionHandler handler) {
    if (!_preCheck()) {
      _callbackJs(handler, -2);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => PickUserScreen(title: '选择联系人', (_, members) async {
                if (members.isEmpty) {
                  Fluttertoast.showToast(msg: "请选择一位或者多位好友提交日报");
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
              })),
    );
  }

  _preCheck() {
    return appUrl == currentUr;
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
