
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:imclient/imclient.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'model/favorite_item.dart';

typedef AppServerErrorCallback = Function(String msg);
typedef AppServerLoginSuccessCallback = Function(String userId, String token, bool isNewUser);

typedef AppServerHTTPCallback = Function(String response);
class AppServer {
  static String? _authToken;
  static void sendCode(String phoneNum, Function successCallback, AppServerErrorCallback errorCallback) {
    String jsonStr = json.encode({'mobile':phoneNum});
    postJson('/send_code', jsonStr, (response) {
      Map<dynamic, dynamic> map = json.decode(response);
      if(map['code'] == 0) {
        successCallback();
      } else {
        errorCallback(map['message'] ?? '网络错误');
      }
    }, errorCallback);
  }

  static void login(String phoneNum, String smsCode, AppServerLoginSuccessCallback successCallback, AppServerErrorCallback errorCallback) async {
    String jsonStr = json.encode({'mobile':phoneNum, 'code':smsCode, 'clientId':await Imclient.clientId, 'platform': 2});
    postJson('/login', jsonStr, (response) {

      Map<dynamic, dynamic> map = json.decode(response);
      if(map['code'] == 0) {
        Map<dynamic, dynamic> result = map['result'];
        String userId = result['userId'];
        String token = result['token'];
        bool newUser = result['register'];
        successCallback(userId, token, newUser);
      } else {
        errorCallback(map['message'] ?? '网络错误');
      }
    }, errorCallback);
  }

  static void getGroupAnnouncement(String groupId, Function(String) successCallback, AppServerErrorCallback errorCallback) {
    postJson('/get_group_announcement', json.encode({'groupId': groupId}), (response) {
      Map<dynamic, dynamic> map = json.decode(response);
      if (map['code'] == 0) {
        successCallback(map['result'] != null ? map['result']['text'] : '');
      } else {
        errorCallback(map['message'] ?? '网络错误');
      }
    }, errorCallback);
  }

  static void updateGroupAnnouncement(String groupId, String text, Function successCallback, AppServerErrorCallback errorCallback) {
    postJson('/put_group_announcement', json.encode({'groupId': groupId, 'author':Imclient.currentUserId, 'text': text}), (response) {
      Map<dynamic, dynamic> map = json.decode(response);
      if (map['code'] == 0) {
        successCallback();
      } else {
        errorCallback(map['message'] ?? '网络错误');
      }
    }, errorCallback);
  }

  static void getFavoriteItems(int startId, int count, Function(List<FavoriteItem>, bool) successCallback, AppServerErrorCallback errorCallback) {
    postJson('/fav/list', json.encode({'id': startId, 'count': count}), (response) {
      Map<dynamic, dynamic> map = json.decode(response);
      if (map['code'] == 0) {
        var result = map['result'];
        bool hasMore = result['hasMore'];
        List<dynamic> items = result['items'];
        List<FavoriteItem> favItems = items.map((e) => FavoriteItem.fromJson(e)).toList();
        successCallback(favItems, hasMore);
      } else {
        errorCallback(map['message'] ?? '网络错误');
      }
    }, errorCallback);
  }

  static void addFavoriteItem(FavoriteItem item, Function successCallback, AppServerErrorCallback errorCallback) {
    postJson('/fav/add', json.encode(item.toJson()), (response) {
      Map<dynamic, dynamic> map = json.decode(response);
      if (map['code'] == 0) {
        successCallback();
      } else {
        errorCallback(map['message'] ?? '网络错误');
      }
    }, errorCallback);
  }

  static void removeFavoriteItem(int favId, Function successCallback, AppServerErrorCallback errorCallback) {
    postJson('/fav/del/$favId', json.encode({}), (response) {
      Map<dynamic, dynamic> map = json.decode(response);
      if (map['code'] == 0) {
        successCallback();
      } else {
        errorCallback(map['message'] ?? '网络错误');
      }
    }, errorCallback);
  }

  static void postJson(String request, String jsonStr, AppServerHTTPCallback successCallback, AppServerErrorCallback errorCallback) async {
    var url = Config.APP_Server_Address + request;

    if (_authToken == null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      _authToken = prefs.getString('app_server_auth_token');
    }

    Map<String, String> headers = {"content-type": "application/json"};
    if (_authToken != null) {
      headers['authToken'] = _authToken!;
    }

    // print(json);
    http.Response response = await http.post(
        Uri.parse(url), // post地址
        headers: headers, //设置content-type为json
        body: jsonStr //json参数
    );

    if (response.statusCode != 200) {
      errorCallback(response.body);
    } else {
      _authToken = response.headers['authToken'] ?? response.headers['authtoken'];
      if (_authToken != null) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        prefs.setString('app_server_auth_token', _authToken!);
      }
      successCallback(response.body);
    }
  }
}