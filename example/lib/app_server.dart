
import 'dart:convert';

import 'package:flutter_imclient/flutter_imclient.dart';
import 'package:flutter_imclient_example/config.dart';
import 'package:http/http.dart' as http;

typedef AppServerErrorCallback = Function(String msg);
typedef AppServerLoginSuccessCallback = Function(String userId, String token, bool isNewUser);

typedef _appServerHTTPCallback = Function(String response);
class AppServer {

  static void sendCode(String phoneNum, Function successCallback, AppServerErrorCallback errorCallback) {
    String jsonStr = json.encode({'mobile':phoneNum});
    postJson('/send_code', jsonStr, (response) {
      Map<dynamic, dynamic> map = json.decode(response);
      if(map['code'] == 0) {
        successCallback();
      } else {
        errorCallback(map['message'] != null ? map['message'] : '网络错误');
      }
    }, errorCallback);
  }

  static void login(String phoneNum, String smsCode, AppServerLoginSuccessCallback successCallback, AppServerErrorCallback errorCallback) async {
    String jsonStr = json.encode({'mobile':phoneNum, 'code':smsCode, 'clientId':await FlutterImclient.clientId});
    postJson('/login', jsonStr, (response) {
      
      Map<dynamic, dynamic> map = json.decode(response);
      if(map['code'] == 0) {
        Map<dynamic, dynamic> result = map['result'];
        String userId = result['userId'];
        String token = result['token'];
        bool newUser = result['register'];
        successCallback(userId, token, newUser);
      } else {
        errorCallback(map['message'] != null ? map['message'] : '网络错误');
      }
    }, errorCallback);
  }

  static void postJson(String request, String json, _appServerHTTPCallback successCallback, AppServerErrorCallback errorCallback) async {
    var url = Config.APP_Server_Address + request;

    // print(json);
    http.Response response = await http.post(
        url, // post地址
        headers: {"content-type": "application/json"}, //设置content-type为json
        body: json //json参数
    );

    if(response.statusCode != 200) {
      errorCallback(response.body);
    } else {
      successCallback(response.body);
    }
  }
}