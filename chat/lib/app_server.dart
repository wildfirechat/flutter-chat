
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:imclient/imclient.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'model/favorite_item.dart';
import 'utils/media_url_redirector.dart';
import 'widget/slide_verify_dialog.dart';

typedef AppServerErrorCallback = Function(String msg);
typedef AppServerLoginSuccessCallback = Function(String userId, String token, bool isNewUser);

typedef AppServerHTTPCallback = Function(String response);
class AppServer {
  static String? _authToken;

  static int _detectClientPlatform() {
    if (Platform.isAndroid) return 2;
    if (Platform.isWindows) return 3;
    if (Platform.isMacOS) return 4;
    if (Platform.isIOS) return 1;
    if (Platform.isLinux) return 7;
    return 10; // unknown
  }

  /// AppServer 地址，已兼容双网主备选择。
  static String get appServerAddress => Config.appServerAddress;

  static void sendCode(String phoneNum, Function successCallback, AppServerErrorCallback errorCallback, {String? slideVerifyToken}) {
    Map<String, dynamic> body = {'mobile': phoneNum};
    if (slideVerifyToken != null && slideVerifyToken.isNotEmpty) {
      body['slideVerifyToken'] = slideVerifyToken;
    }
    String jsonStr = json.encode(body);
    postJson('/send_code', jsonStr, (response) {
      Map<dynamic, dynamic> map = json.decode(response);
      if(map['code'] == 0) {
        successCallback();
      } else {
        errorCallback(map['message'] ?? '网络错误');
      }
    }, errorCallback);
  }

  static void sendResetCode(String phoneNum, Function successCallback, AppServerErrorCallback errorCallback, {String? slideVerifyToken}) {
    Map<String, dynamic> body = {'mobile': phoneNum};
    if (slideVerifyToken != null && slideVerifyToken.isNotEmpty) {
      body['slideVerifyToken'] = slideVerifyToken;
    }
    String jsonStr = json.encode(body);
    postJson('/send_reset_code', jsonStr, (response) {
      Map<dynamic, dynamic> map = json.decode(response);
      if(map['code'] == 0) {
        successCallback();
      } else {
        errorCallback(map['message'] ?? '网络错误');
      }
    }, errorCallback);
  }

  static void login(String phoneNum, String smsCode, AppServerLoginSuccessCallback successCallback, AppServerErrorCallback errorCallback, {String? slideVerifyToken}) async {
    Map<String, dynamic> body = {'mobile': phoneNum, 'code': smsCode, 'clientId': await Imclient.clientId, 'platform': _detectClientPlatform()};
    if (slideVerifyToken != null && slideVerifyToken.isNotEmpty) {
      body['slideVerifyToken'] = slideVerifyToken;
    }
    String jsonStr = json.encode(body);
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

  static void passwordLogin(String phoneNum, String password, AppServerLoginSuccessCallback successCallback, AppServerErrorCallback errorCallback, {String? slideVerifyToken}) async {
    Map<String, dynamic> body = {'mobile': phoneNum, 'password': password, 'clientId': await Imclient.clientId, 'platform': _detectClientPlatform()};
    if (slideVerifyToken != null && slideVerifyToken.isNotEmpty) {
      body['slideVerifyToken'] = slideVerifyToken;
    }
    String jsonStr = json.encode(body);
    postJson('/login_pwd', jsonStr, (response) {
      Map<dynamic, dynamic> map = json.decode(response);
      if(map['code'] == 0) {
        Map<dynamic, dynamic> result = map['result'];
        String userId = result['userId'];
        String token = result['token'];
        successCallback(userId, token, false);
      } else {
        errorCallback(map['message'] ?? '网络错误');
      }
    }, errorCallback);
  }

  static void resetPassword(String mobile, String smsCode, String newPassword, Function successCallback, AppServerErrorCallback errorCallback, {String? slideVerifyToken}) {
    Map<String, dynamic> body = {'mobile': mobile, 'resetCode': smsCode, 'newPassword': newPassword};
    if (slideVerifyToken != null && slideVerifyToken.isNotEmpty) {
      body['slideVerifyToken'] = slideVerifyToken;
    }
    String jsonStr = json.encode(body);
    postJson('/reset_pwd', jsonStr, (response) {
      Map<dynamic, dynamic> map = json.decode(response);
      if(map['code'] == 0) {
        successCallback();
      } else {
        errorCallback(map['message'] ?? '网络错误');
      }
    }, errorCallback);
  }

  /// 生成滑动验证码
  static Future<void> generateSlideVerifyCode({
    required Function(SlideVerifyData) onSuccess,
    required Function(String) onError,
  }) async {
    try {
      final url = Uri.parse(MediaUrlRedirector.redirect('${Config.appServerAddress}/slide_verify/generate'));
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({}),
      );

      if (response.statusCode != 200) {
        onError('服务器错误: ${response.statusCode}');
        return;
      }

      final Map<String, dynamic> result = json.decode(response.body);

      if (result['code'] != 0) {
        onError(result['message'] ?? '加载验证码失败');
        return;
      }

      final data = result['result'] as Map<String, dynamic>?;
      if (data == null ||
          data['token'] == null ||
          data['backgroundImage'] == null ||
          data['sliderImage'] == null) {
        onError('验证码数据不完整');
        return;
      }

      final token = data['token'] as String;
      final backgroundImageStr = data['backgroundImage'] as String;
      final sliderImageStr = data['sliderImage'] as String;
      final y = (data['y'] as num).toDouble();

      // 解码 base64 图片
      final backgroundBytes = base64.decode(_extractBase64(backgroundImageStr));
      final sliderBytes = base64.decode(_extractBase64(sliderImageStr));

      onSuccess(SlideVerifyData(
        token: token,
        backgroundImageBytes: backgroundBytes,
        sliderImageBytes: sliderBytes,
        y: y,
      ));
    } catch (e) {
      debugPrint('loadCaptcha error: $e');
      onError('加载验证码失败');
    }
  }

  /// 验证滑动验证码
  static Future<void> verifySlideCode({
    required String token,
    required int x,
    required Function onSuccess,
    required Function onError,
  }) async {
    try {
      final url = Uri.parse(MediaUrlRedirector.redirect('${Config.appServerAddress}/slide_verify/verify'));
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'token': token,
          'x': x,
        }),
      );

      if (response.statusCode != 200) {
        onError();
        return;
      }

      final result = json.decode(response.body);

      if (result['code'] == 0) {
        onSuccess();
      } else {
        onError();
      }
    } catch (e) {
      onError();
    }
  }

  /// 从 data URI 中提取 base64 数据
  static String _extractBase64(String dataUri) {
    if (dataUri.contains(',')) {
      return dataUri.substring(dataUri.indexOf(',') + 1);
    }
    return dataUri;
  }

  static void changePassword(String oldPassword, String newPassword, Function successCallback, AppServerErrorCallback errorCallback, {String? slideVerifyToken}) {
    Map<String, dynamic> body = {'oldPassword': oldPassword, 'newPassword': newPassword};
    if (slideVerifyToken != null && slideVerifyToken.isNotEmpty) {
      body['slideVerifyToken'] = slideVerifyToken;
    }
    String jsonStr = json.encode(body);
    postJson('/change_pwd', jsonStr, (response) {
      Map<dynamic, dynamic> map = json.decode(response);
      if(map['code'] == 0) {
        successCallback();
      } else {
        errorCallback(map['message'] ?? '网络错误');
      }
    }, errorCallback);
  }

  static void changeName(String newName, Function successCallback, AppServerErrorCallback errorCallback) {
    String jsonStr = json.encode({'newName': newName});
    postJson('/change_name', jsonStr, (response) {
      Map<dynamic, dynamic> map = json.decode(response);
      if(map['code'] == 0) {
        successCallback();
      } else {
        errorCallback(map['message'] ?? '网络错误');
      }
    }, errorCallback);
  }


  static void scanPCLogin(String token, Function(int) successCallback, AppServerErrorCallback errorCallback) {
    postJson('/scan_pc/$token', '', (response) {
      Map<dynamic, dynamic> map = json.decode(response);
      // scan_pc returns PCSession object in result.
      // AppService.java: if (pcSession.getStatus() == 1) success(pcSession) else failure(status)
      // Here we simplify to callback(status) or similar
      if (map['code'] == 0) {
        var result = map['result'];
        int status = result['status'];
        if(status == 1) {
          successCallback(status);
        } else {
          errorCallback('Status: $status');
        }
      } else {
        errorCallback(map['message'] ?? '网络错误');
      }
    }, errorCallback);
  }

  static void confirmPCLogin(String token, String userId, Function successCallback, AppServerErrorCallback errorCallback) {
    String jsonStr = json.encode({'token': token, 'user_id': userId, 'quick_login': 1});
    postJson('/confirm_pc', jsonStr, (response) {
      Map<dynamic, dynamic> map = json.decode(response);
      if (map['code'] == 0) {
        var result = map['result'];
        int status = result['status'];
        if(status == 2) {
          successCallback();
        } else {
          errorCallback('Status: $status');
        }
      } else {
        errorCallback(map['message'] ?? '网络错误');
      }
    }, errorCallback);
  }

  static void cancelPCLogin(String token, Function successCallback, AppServerErrorCallback errorCallback) {
    String jsonStr = json.encode({'token': token});
    postJson('/cancel_pc', jsonStr, (response) {
      Map<dynamic, dynamic> map = json.decode(response);
      if (map['code'] == 0) {
        var result = map['result'];
        int status = result['status'];
        if(status == 2) { // Cancel returns status 2? AppService.java checks for 2 in success.
          successCallback();
        } else {
           errorCallback('Status: $status');
        }
      } else {
        errorCallback(map['message'] ?? '网络错误');
      }
    }, errorCallback);
  }

  static void createPcSession(int platform, Function(String token) successCallback, AppServerErrorCallback errorCallback) async {
    String jsonStr = json.encode({'clientId': await Imclient.clientId, 'platform': platform});
    postJson('/pc_session', jsonStr, (response) {
      Map<dynamic, dynamic> map = json.decode(response);
      if (map['code'] == 0) {
        String token = map['result']['token'];
        successCallback(token);
      } else {
        errorCallback(map['message'] ?? '网络错误');
      }
    }, errorCallback);
  }

  /// onScanned: 当二维码被扫码但尚未确认时回调,返回扫码用户信息(含 portrait)
  static void pollPcSessionLogin(String token, Function(String userId, String token) successCallback,
      Function(Map<String, dynamic> scannedUser)? onScanned,
      AppServerErrorCallback errorCallback) {
    postJson('/session_login/$token', '{}', (response) {
      Map<dynamic, dynamic> map = json.decode(response);
      if (map['code'] == 0) {
        Map<dynamic, dynamic> result = map['result'];
        String userId = result['userId'];
        String imToken = result['token'];
        successCallback(userId, imToken);
      } else {
        // 检查是否被扫码但未确认: 服务端 code=9 时返回 LoginResponse(userName, portrait)
        // LoginResponse 中没有 status 字段,以 userName/portrait 存在作为判定条件
        if (onScanned != null && map.containsKey('result') && map['result'] is Map) {
          Map<dynamic, dynamic> result = map['result'];
          if (result.containsKey('userName') || result.containsKey('portrait')) {
            onScanned(Map<String, dynamic>.from(result));
            return;
          }
        }
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

  static void getMyPrivateConferenceId(Function(String) successCallback, AppServerErrorCallback errorCallback) {
    postJson('/conference/get_my_id', json.encode({}), (response) {
       Map<dynamic, dynamic> map = json.decode(response);
       if(map['code'] == 0) {
         successCallback(map['result']);
       } else {
         errorCallback(map['message'] ?? '网络错误');
       }
    }, errorCallback);
  }

  static void createConference(Map<String, dynamic> info, Function(String) successCallback, AppServerErrorCallback errorCallback) {
    postJson('/conference/create', json.encode(info), (response) {
       Map<dynamic, dynamic> map = json.decode(response);
       if(map['code'] == 0) {
         successCallback(map['result']);
       } else {
         errorCallback(map['message'] ?? '网络错误');
       }
    }, errorCallback);
  }

  static void queryConferenceInfo(String conferenceId, String password, Function(Map<String, dynamic>) successCallback, AppServerErrorCallback errorCallback) {
    postJson('/conference/info', json.encode({'conferenceId': conferenceId, 'password': password}), (response) {
       Map<dynamic, dynamic> map = json.decode(response);
       if(map['code'] == 0) {
         // Assuming result is the info
         successCallback(map['result'] != null ? Map<String, dynamic>.from(map['result']) : {});
       } else {
         errorCallback(map['message'] ?? '网络错误');
       }
    }, errorCallback);
  }

  static void destroyConference(String conferenceId, Function successCallback, AppServerErrorCallback errorCallback) {
    postJson('/conference/destroy/$conferenceId', json.encode({}), (response) {
       Map<dynamic, dynamic> map = json.decode(response);
       if(map['code'] == 0) {
         successCallback();
       } else {
         errorCallback(map['message'] ?? '网络错误');
       }
    }, errorCallback);
  }

  static void favConference(String conferenceId, Function successCallback, AppServerErrorCallback errorCallback) {
    postJson('/conference/fav/$conferenceId', json.encode({}), (response) {
       Map<dynamic, dynamic> map = json.decode(response);
       if(map['code'] == 0) {
         successCallback();
       } else {
         errorCallback(map['message'] ?? '网络错误');
       }
    }, errorCallback);
  }

  static void unfavConference(String conferenceId, Function successCallback, AppServerErrorCallback errorCallback) {
    postJson('/conference/unfav/$conferenceId', json.encode({}), (response) {
       Map<dynamic, dynamic> map = json.decode(response);
       if(map['code'] == 0) {
         successCallback();
       } else {
         errorCallback(map['message'] ?? '网络错误');
       }
    }, errorCallback);
  }

  static void isFavConference(String conferenceId, Function(bool) successCallback, AppServerErrorCallback errorCallback) {
    postJson('/conference/is_fav/$conferenceId', json.encode({}), (response) {
       Map<dynamic, dynamic> map = json.decode(response);
       if(map['code'] == 0) {
         successCallback(true);
       } else if(map['code'] == 16) {
         successCallback(false);
       } else {
         errorCallback(map['message'] ?? '网络错误');
       }
    }, errorCallback);
  }

  static void getFavConferences(Function(List<Map<String, dynamic>>) successCallback, AppServerErrorCallback errorCallback) {
    postJson('/conference/fav_conferences', json.encode({}), (response) {
       Map<dynamic, dynamic> map = json.decode(response);
       if(map['code'] == 0) {
         List<dynamic> list = map['result'];
         successCallback(list.map((e) => Map<String, dynamic>.from(e)).toList());
       } else {
         errorCallback(map['message'] ?? '网络错误');
       }
    }, errorCallback);
  }

  static void updateConference(Map<String, dynamic> info, Function successCallback, AppServerErrorCallback errorCallback) {
    postJson('/conference/put_info', json.encode(info), (response) {
       Map<dynamic, dynamic> map = json.decode(response);
       if(map['code'] == 0) {
         successCallback();
       } else {
         errorCallback(map['message'] ?? '网络错误');
       }
    }, errorCallback);
  }

  static void recordConference(String conferenceId, bool record, Function successCallback, AppServerErrorCallback errorCallback) {
    postJson('/conference/recording/$conferenceId', json.encode({'recording': record}), (response) {
       Map<dynamic, dynamic> map = json.decode(response);
       if(map['code'] == 0) {
         successCallback();
       } else {
         errorCallback(map['message'] ?? '网络错误');
       }
    }, errorCallback);
  }

  static void setConferenceFocusUserId(String conferenceId, String userId, Function successCallback, AppServerErrorCallback errorCallback) {
    postJson('/conference/focus/$conferenceId', json.encode({'userId': userId}), (response) {
       Map<dynamic, dynamic> map = json.decode(response);
       if(map['code'] == 0) {
         successCallback();
       } else {
         errorCallback(map['message'] ?? '网络错误');
       }
    }, errorCallback);
  }

  static void getGroupPortrait(String groupId, Function(String) successCallback, AppServerErrorCallback errorCallback) {
    _getGroupMembersForPortrait(groupId, (members) {
        if (members.length > 9) {
            members = members.sublist(0, 9);
        }
        var request = {};
        var reqMembers = [];
        for (var member in members) {
            var obj = {};
            String portrait = member['portrait'] ?? '';
            String name = member['name'] ?? '';
            if (portrait.isEmpty || portrait.startsWith(Config.appServerAddress)) {
                obj['name'] = name;
            } else {
                obj['avatarUrl'] = portrait;
            }
            reqMembers.add(obj);
        }
        request['members'] = reqMembers;
        String url = "${Config.appServerAddress}/avatar/group?request=${Uri.encodeComponent(json.encode(request))}";
        url = MediaUrlRedirector.redirect(url);
        successCallback(url);
    }, errorCallback);
  }

  static void _getGroupMembersForPortrait(String groupId, Function(List<Map<String, dynamic>>) successCallback, AppServerErrorCallback errorCallback) {
    postJson('/group/members_for_portrait', json.encode({'groupId': groupId}), (response) {
      Map<dynamic, dynamic> map = json.decode(response);
      if(map['code'] == 0) {
        List<dynamic> list = map['result'];
        successCallback(list.map((e) => Map<String, dynamic>.from(e)).toList());
      } else {
        errorCallback(map['message'] ?? '网络错误');
      }
    }, errorCallback);
  }

  static void postJson(String request, String jsonStr, AppServerHTTPCallback successCallback, AppServerErrorCallback errorCallback) async {
    var url = Config.appServerAddress + request;
    url = MediaUrlRedirector.redirect(url);

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