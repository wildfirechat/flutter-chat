import 'dart:convert';

import 'package:dsbridge_flutter/dsbridge_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/user_info.dart';
import 'package:wfc_example/workspace/wf_webview_screen.dart';

import '../contact/pick_user_screen.dart';

class JsApi extends JavaScriptNamespaceInterface {
  final BuildContext context;
  final String appUrl;
  final DWebViewController webViewController;

  JsApi(this.context, this.appUrl, this.webViewController);

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
    // activity.finish();
    // JSONObject resultObj = new JSONObject();
    // try {
    //   resultObj.put("code", 0);
    //   handler.complete(resultObj);
    // } catch (JSONException e) {
    // e.printStackTrace();
    // }
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
    // if (!preCheck()) {
    //   callbackJs(handler, -2);
    //   return;
    // }
    // JSONObject jsonObject = (JSONObject) obj;
    // int max = jsonObject.optInt("max", 0);
    // Intent intent = PickContactActivity.buildPickIntent(activity, max, null, null);
    // startActivityForResult(intent, REQUEST_CODE_PICK_CONTACT);
    // this.jsCallbackHandlers.put(REQUEST_CODE_PICK_CONTACT, handler);
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
                  handler.complete({'code': 0, 'data': json.encode(userInfoList)});
                  Navigator.pop(context);
                }
              })),
    );
  }

  Map<String, dynamic> _userInfoToJson(UserInfo userInfo) {
    return {
      'userId': userInfo.userId,
      'name': userInfo.name,
      'displayName': userInfo.displayName,
      'portrait': userInfo.portrait,
    };
  }
}
