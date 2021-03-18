package cn.wildfirechat.flutter_imclient;

import android.content.Context;
import android.content.IntentFilter;
import android.os.Build;
import android.os.Handler;
import android.os.LocaleList;
import android.os.Looper;
import android.preference.PreferenceManager;
import android.provider.Settings;
import android.text.TextUtils;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.RequiresApi;
import androidx.lifecycle.Lifecycle;
import androidx.lifecycle.LifecycleObserver;
import androidx.lifecycle.OnLifecycleEvent;
import androidx.lifecycle.ProcessLifecycleOwner;

import com.tencent.mars.BaseEvent;
import com.tencent.mars.Mars;
import com.tencent.mars.app.AppLogic;
import com.tencent.mars.proto.ProtoLogic;
import com.tencent.mars.sdt.SdtLogic;
import com.tencent.mars.xlog.Xlog;


import java.io.File;
import java.io.RandomAccessFile;
import java.nio.channels.FileChannel;
import java.nio.channels.FileLock;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

import cn.wildfirechat.model.ProtoChannelInfo;
import cn.wildfirechat.model.ProtoChatRoomInfo;
import cn.wildfirechat.model.ProtoChatRoomMembersInfo;
import cn.wildfirechat.model.ProtoConversationInfo;
import cn.wildfirechat.model.ProtoConversationSearchresult;
import cn.wildfirechat.model.ProtoFileRecord;
import cn.wildfirechat.model.ProtoFriendRequest;
import cn.wildfirechat.model.ProtoGroupInfo;
import cn.wildfirechat.model.ProtoGroupMember;
import cn.wildfirechat.model.ProtoGroupSearchResult;
import cn.wildfirechat.model.ProtoMessage;
import cn.wildfirechat.model.ProtoMessageContent;
import cn.wildfirechat.model.ProtoReadEntry;
import cn.wildfirechat.model.ProtoUnreadCount;
import cn.wildfirechat.model.ProtoUserInfo;
import cn.wildfirechat.push.PushService;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

import static com.tencent.mars.xlog.Xlog.AppednerModeAsync;

/** FlutterImclientPlugin */
public class FlutterImclientPlugin implements FlutterPlugin, MethodCallHandler, AppLogic.ICallBack, SdtLogic.ICallBack, ProtoLogic.IUserInfoUpdateCallback, ProtoLogic.ISettingUpdateCallback, ProtoLogic.IFriendListUpdateCallback, ProtoLogic.IFriendRequestListUpdateCallback, ProtoLogic.IGroupInfoUpdateCallback, ProtoLogic.IGroupMembersUpdateCallback, ProtoLogic.IChannelInfoUpdateCallback, ProtoLogic.IConnectionStatusCallback, ProtoLogic.IReceiveMessageCallback, ProtoLogic.IConferenceEventCallback {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private MethodChannel channel;
  private Handler handler;
  private BaseEvent.ConnectionReceiver mConnectionReceiver;
  private String appPath;
  private AppLogic.AccountInfo accountInfo = new AppLogic.AccountInfo();
  private AppLogic.DeviceInfo info;
  private String userId;
  private int connectionStatus;
  private boolean isLogined;
  private String clientId;
  private Context gContext;

  private boolean deviceTokenSetted;
  private int pushType;
  private String pushToken;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    gContext = flutterPluginBinding.getApplicationContext();
    Mars.loadDefaultMarsLibrary();

    AppLogic.setCallBack(this);
    SdtLogic.setCallBack(this);
    ProtoLogic.setUserInfoUpdateCallback(this);
    ProtoLogic.setSettingUpdateCallback(this);
    ProtoLogic.setFriendListUpdateCallback(this);
    ProtoLogic.setGroupInfoUpdateCallback(this);
    ProtoLogic.setChannelInfoUpdateCallback(this);
    ProtoLogic.setGroupMembersUpdateCallback(this);
    ProtoLogic.setFriendRequestListUpdateCallback(this);
    ProtoLogic.setConnectionStatusCallback(this);
    ProtoLogic.setReceiveMessageCallback(this);
    ProtoLogic.setConferenceEventCallback(this);


    startLog();
    appPath = flutterPluginBinding.getApplicationContext().getFilesDir().getAbsolutePath();

    handler = new Handler(Looper.getMainLooper());
    Mars.init(flutterPluginBinding.getApplicationContext(), handler);
    if(mConnectionReceiver == null) {
      mConnectionReceiver = new BaseEvent.ConnectionReceiver();
      IntentFilter filter = new IntentFilter();
      filter.addAction("android.net.conn.CONNECTIVITY_CHANGE");
      flutterPluginBinding.getApplicationContext().registerReceiver(mConnectionReceiver, filter);
    }

    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "flutter_imclient");
    channel.setMethodCallHandler(this);

    PushService.init(flutterPluginBinding.getApplicationContext(), BuildConfig.APPLICATION_ID, new PushService.IPushCallback() {
      @Override
      public void onPushToken(int pushType, String pushToken) {
        if(TextUtils.isEmpty(pushToken)) {
          return;
        }

        FlutterImclientPlugin.this.pushType = pushType;
        FlutterImclientPlugin.this.pushToken = pushToken;
        if(connectionStatus == 1) {
          deviceTokenSetted = true;
          ProtoLogic.setDeviceToken(gContext.getPackageName(), pushToken, pushType);
        }
      }
    });

    ProcessLifecycleOwner.get().getLifecycle().addObserver(new LifecycleObserver() {
      @OnLifecycleEvent(Lifecycle.Event.ON_START)
      public void onForeground() {
        BaseEvent.onForeground(true);
      }

      @OnLifecycleEvent(Lifecycle.Event.ON_STOP)
      public void onBackground() {
        BaseEvent.onForeground(false);
      }
    });
  }

  private String getLogPath() {
    return gContext.getCacheDir().getAbsolutePath() + "/log";
  }

  public void startLog() {
    Xlog.setConsoleLogOpen(true);
    String path = getLogPath();
    //wflog为ChatSManager中使用判断日志文件，如果修改需要对应修改
    Xlog.appenderOpen(Xlog.LEVEL_INFO, AppednerModeAsync, path, path, "wflog", null);
  }

  public void stopLog() {
    Xlog.setConsoleLogOpen(false);
  }

  public synchronized String getClientId() {
    if (this.clientId != null) {
      return this.clientId;
    }

    String imei = null;
    try (
            RandomAccessFile fw = new RandomAccessFile(gContext.getFilesDir().getAbsoluteFile() + "/.wfcClientId", "rw");
    ) {

      FileChannel chan = fw.getChannel();
      FileLock lock = chan.lock();
      imei = fw.readLine();
      if (TextUtils.isEmpty(imei)) {
        // 迁移就的clientId
        imei = PreferenceManager.getDefaultSharedPreferences(gContext).getString("mars_core_uid", "");
        if (TextUtils.isEmpty(imei)) {
          try {
            imei = Settings.Secure.getString(gContext.getContentResolver(), Settings.Secure.ANDROID_ID);
          } catch (Exception e) {
            e.printStackTrace();
          }
          if (TextUtils.isEmpty(imei)) {
            imei = UUID.randomUUID().toString();
          }
          imei += System.currentTimeMillis();
        }
        fw.writeBytes(imei);
      }
      lock.release();
    } catch (Exception ex) {
      ex.printStackTrace();
      Log.e("getClientError", "" + ex.getMessage());
    }
    this.clientId = imei;
    return imei;
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    if (call.method.equals("getPlatformVersion")) {
      result.success("Android " + android.os.Build.VERSION.RELEASE);
    } else if("isLogined".equals(call.method)) {
      result.success(isLogined);
    } else if("connect".equals(call.method)) {
      String host = call.argument("host");
      String token = call.argument("token");
      userId = call.argument("userId");

      isLogined = true;
      accountInfo.userName = userId;
      Mars.onCreate(true);
      ProtoLogic.setAuthInfo(userId, token);

      result.success(ProtoLogic.connect(host));

      BaseEvent.onForeground(true);
      BaseEvent.onNetworkChange();
    } else if("currentUserId".equals(call.method)) {
      result.success(userId);
    } else if("connectionStatus".equals(call.method)) {
      result.success(connectionStatus);
    } else if("getClientId".equals(call.method)) {
      result.success(getClientId());
    } else if("serverDeltaTime".equals(call.method)) {
      result.success(ProtoLogic.getServerDeltaTime());
    } else if("registeMessage".equals(call.method)) {
      int type = call.argument("type");
      int flag = call.argument("flag");
      ProtoLogic.registerMessageFlag(type, flag);
      result.success(null);
    } else if("disconnect".equals(call.method)) {
      boolean disablePush = call.argument("disablePush");
      boolean clearSession = call.argument("clearSession");
      int flag = 0;
      if (clearSession) {
        flag = 8;
      } else if(disablePush) {
        flag = 1;
      }

      ProtoLogic.disconnect(flag);
      result.success(null);
    } else if("startLog".equals(call.method)) {
      startLog();
      result.success(null);
    } else if("stopLog".equals(call.method)) {
      stopLog();
      result.success(null);
    } else if("getLogFilesPath".equals(call.method)) {
      result.success(getLogFilesPath());
    } else if("getConversationInfos".equals(call.method)) {
      List<Integer> types = call.argument("types");
      List<Integer> lines = call.argument("lines");
      ProtoConversationInfo[] protoDatas = ProtoLogic.getConversations(convertIntegerList(types), convertIntegerList(lines));
      result.success(convertProtoConversationInfos(protoDatas));
    } else if("getConversationInfo".equals(call.method)) {
      int type = call.argument("type");
      String target = call.argument("target");
      int line = call.argument("line");
      result.success(convertProtoConversationInfo(ProtoLogic.getConversation(type, target, line)));
    } else if("searchConversation".equals(call.method)) {
      List<Integer> types = call.argument("types");
      List<Integer> lines = call.argument("lines");
      String keyword = call.argument("keyword");
      result.success(convertProtoConversationSearchInfos(ProtoLogic.searchConversation(keyword, convertIntegerList(types), convertIntegerList(lines))));
    } else if("removeConversation".equals(call.method)) {
      Map conversation = call.argument("conversation");
      boolean clearMessage = call.argument("clearMessage");
      int type = (int)conversation.get("type");
      String target = (String)conversation.get("target");
      int line = (int)conversation.get("line");
      ProtoLogic.removeConversation(type, target, line, clearMessage);
      result.success(null);
    } else if("setConversationTop".equals(call.method)) {
      int requestId = call.argument("requestId");
      Map conversation = call.argument("conversation");
      int type = (int)conversation.get("type");
      String target = (String)conversation.get("target");
      int line = (int)conversation.get("line");
      boolean isTop = call.argument("isTop");
      String key = type + "-" + line + "-" + target;
      setUserSetting(requestId, 3, key, isTop?"1":"0");
      result.success(null);
    } else if("setConversationSilent".equals(call.method)) {
      int requestId = call.argument("requestId");
      Map conversation = call.argument("conversation");
      int type = (int)conversation.get("type");
      String target = (String)conversation.get("target");
      int line = (int)conversation.get("line");
      boolean isSilent = call.argument("isSilent");
      String key = type + "-" + line + "-" + target;
      setUserSetting(requestId, 1, key, isSilent?"1":"0");
      result.success(null);
    } else if("setConversationDraft".equals(call.method)) {
      Map conversation = call.argument("conversation");
      int type = (int)conversation.get("type");
      String target = (String)conversation.get("target");
      int line = (int)conversation.get("line");
      String draft = call.argument("draft");
      ProtoLogic.setConversationDraft(type, target, line, draft);
      result.success(null);
    } else if("setConversationTimestamp".equals(call.method)) {
      Map conversation = call.argument("conversation");
      int type = (int)conversation.get("type");
      String target = (String)conversation.get("target");
      int line = (int)conversation.get("line");
      long timestamp = getLongPara(call, "timestamp");
      ProtoLogic.setConversationTimestamp(type, target, line, timestamp);
      result.success(null);
    } else if("getFirstUnreadMessageId".equals(call.method)) {
      Map conversation = call.argument("conversation");
      int type = (int)conversation.get("type");
      String target = (String)conversation.get("target");
      int line = (int)conversation.get("line");
      result.success(ProtoLogic.getConversationFirstUnreadMessageId(type, target, line));
    } else if("getConversationUnreadCount".equals(call.method)) {
      Map conversation = call.argument("conversation");
      int type = (int)conversation.get("type");
      String target = (String)conversation.get("target");
      int line = (int)conversation.get("line");
      result.success(convertProtoUnreadCount(ProtoLogic.getUnreadCount(type, target, line)));
    } else if("getConversationsUnreadCount".equals(call.method)) {
      List<Integer> types = call.argument("types");
      List<Integer> lines = call.argument("lines");
      result.success(convertProtoUnreadCount(ProtoLogic.getUnreadCountEx(convertIntegerList(types), convertIntegerList(lines))));
    } else if("clearConversationUnreadStatus".equals(call.method)) {
      Map conversation = call.argument("conversation");
      int type = (int)conversation.get("type");
      String target = (String)conversation.get("target");
      int line = (int)conversation.get("line");
      result.success(ProtoLogic.clearUnreadStatus(type, target, line));
    } else if("clearConversationsUnreadStatus".equals(call.method)) {
      List<Integer> types = call.argument("types");
      List<Integer> lines = call.argument("lines");
      result.success(ProtoLogic.clearUnreadStatusEx(convertIntegerList(types), convertIntegerList(lines)));
    } else if("getConversationRead".equals(call.method)) {
      Map conversation = call.argument("conversation");
      int type = (int)conversation.get("type");
      String target = (String)conversation.get("target");
      int line = (int)conversation.get("line");
      result.success(ProtoLogic.GetConversationRead(type, target, line));
    } else if("getMessageDelivery".equals(call.method)) {
      Map conversation = call.argument("conversation");
      int type = (int)conversation.get("type");
      String target = (String)conversation.get("target");
      result.success(ProtoLogic.GetDelivery(type, target));
    } else if("getMessages".equals(call.method)) {
      Map conversation = call.argument("conversation");
      int type = (int)conversation.get("type");
      String target = (String)conversation.get("target");
      int line = (int)conversation.get("line");

      List<Integer> contentTypes = call.argument("contentTypes");
      String withUser = call.argument("withUser");
      long fromIndex = getLongPara(call, "fromIndex");
      int count = call.argument("count");
      boolean isDesc = false;
      if(count < 0) {
        isDesc = true;
        count = -count;
      }
      if(contentTypes == null || contentTypes.isEmpty()) {
        result.success(convertProtoMessages(ProtoLogic.getMessages(type, target, line, fromIndex, isDesc, count, withUser)));
      } else {
        result.success(convertProtoMessages(ProtoLogic.getMessagesInTypes(type, target, line, convertIntegerList(contentTypes), fromIndex, isDesc, count, withUser)));
      }
    } else if("getMessagesByStatus".equals(call.method)) {
      Map conversation = call.argument("conversation");
      int type = (int)conversation.get("type");
      String target = (String)conversation.get("target");
      int line = (int)conversation.get("line");

      List<Integer> messageStatus = call.argument("messageStatus");
      String withUser = call.argument("withUser");
      long fromIndex = getLongPara(call, "fromIndex");
      int count = call.argument("count");
      boolean isDesc = false;
      if(count < 0) {
        isDesc = true;
        count = -count;
      }
      if(messageStatus == null || messageStatus.isEmpty()) {
        result.success(convertProtoMessages(ProtoLogic.getMessages(type, target, line, fromIndex, isDesc, count, withUser)));
      } else {
        result.success(convertProtoMessages(ProtoLogic.getMessagesInStatus(type, target, line, convertIntegerList(messageStatus), fromIndex, isDesc, count, withUser)));
      }
    } else if("getConversationsMessages".equals(call.method)) {
      List<Integer> types = call.argument("types");
      List<Integer> lines = call.argument("lines");

      List<Integer> contentTypes = call.argument("contentTypes");
      String withUser = call.argument("withUser");
      long fromIndex = getLongPara(call, "fromIndex");
      int count = call.argument("count");
      boolean isDesc = false;
      if(count < 0) {
        isDesc = true;
        count = -count;
      }

      result.success(convertProtoMessages(ProtoLogic.getMessagesEx(convertIntegerList(types), convertIntegerList(lines), convertIntegerList(contentTypes), fromIndex, isDesc, count, withUser)));
    } else if("getConversationsMessageByStatus".equals(call.method)) {
      List<Integer> types = call.argument("types");
      List<Integer> lines = call.argument("lines");

      List<Integer> messageStatus = call.argument("messageStatus");
      String withUser = call.argument("withUser");
      long fromIndex = getLongPara(call, "fromIndex");
      int count = call.argument("count");
      boolean isDesc = false;
      if(count < 0) {
        isDesc = true;
        count = -count;
      }

      result.success(convertProtoMessages(ProtoLogic.getMessagesEx2(convertIntegerList(types), convertIntegerList(lines), convertIntegerList(messageStatus), fromIndex, isDesc, count, withUser)));
    } else if("getRemoteMessages".equals(call.method)) {
      final int requestId = call.argument("requestId");
      Map conversation = call.argument("conversation");
      int type = (int)conversation.get("type");
      String target = (String)conversation.get("target");
      int line = (int)conversation.get("line");
      long beforeMessageUid = getLongPara(call, "beforeMessageUid");
      int count = call.argument("count");

      ProtoLogic.getRemoteMessages(type, target, line, beforeMessageUid, count, new ProtoLogic.ILoadRemoteMessagesCallback() {
        @Override
        public void onSuccess(ProtoMessage[] protoMessages) {
          Map args = new HashMap();
          args.put("messages", convertProtoMessages(protoMessages));
          callback2UI("onMessagesCallback", args);
        }

        @Override
        public void onFailure(int i) {
          callbackFailure(requestId, i);
        }
      });
      result.success(null);
    } else if("getMessage".equals(call.method)) {
      long messageId = getLongPara(call, "messageId");
      result.success(convertProtoMessage(ProtoLogic.getMessage(messageId)));
    } else if("getMessageByUid".equals(call.method)) {
      long messageUid = getLongPara(call, "messageUid");
      result.success(convertProtoMessage(ProtoLogic.getMessageByUid(messageUid)));
    } else if("searchMessages".equals(call.method)) {
      Map conversation = call.argument("conversation");
      int type = (int)conversation.get("type");
      String target = (String)conversation.get("target");
      int line = (int)conversation.get("line");
      String keyword = call.argument("keyword");
      boolean order = call.argument("order");
      int limit = call.argument("limit");
      int offset = call.argument("offset");

      result.success(convertProtoMessages(ProtoLogic.searchMessageEx(type, target, line, keyword, order, limit, offset)));
    } else if("searchConversationsMessages".equals(call.method)) {
      List<Integer> types = call.argument("types");
      List<Integer> lines = call.argument("lines");
      String keyword = call.argument("keyword");
      List<Integer> contentTypes = call.argument("contentTypes");
      long fromIndex = getLongPara(call, "fromIndex");
      int count = call.argument("count");
      boolean desc = false;
      if(count < 0) {
        desc = true;
        count = -count;
      }
      result.success(convertProtoMessages(ProtoLogic.searchMessageEx2(convertIntegerList(types), convertIntegerList(lines), convertIntegerList(contentTypes), keyword, fromIndex, desc, count)));
    } else if("sendMessage".equals(call.method)) {
      int requestId = call.argument("requestId");
      Map conversation = call.argument("conversation");
      Map content = call.argument("content");
      List<String> toUsers = call.argument("toUsers");
      int expireDuration = call.argument("expireDuration") == null ? 0 : (Integer) call.argument("expireDuration");
      ProtoMessage msg = new ProtoMessage();
      msg.setFrom(userId);
      msg.setConversationType((int)conversation.get("type"));
      msg.setTarget((String)conversation.get("target"));
      msg.setLine((int)conversation.get("line"));
      msg.setContent(convertMessageContent(content));
      if(toUsers != null && !toUsers.isEmpty()) {
        String[] arr = new String[toUsers.size()];
        for (int i = 0; i < toUsers.size(); i++) {
          arr[i] = toUsers.get(i);
        }
        msg.setTos(arr);
      }
      ProtoLogic.sendMessage(msg, expireDuration, new SendMessageCallback(requestId, msg));
      result.success(convertProtoMessage(msg));
    } else if("sendSavedMessage".equals(call.method)) {
      int requestId = call.argument("requestId");
      long messageId = getLongPara(call, "messageId");
      int expireDuration = call.argument("expireDuration");
      ProtoLogic.sendMessageEx(messageId, expireDuration, new SendMessageCallback(requestId, null));
      result.success(null);
    } else if("recallMessage".equals(call.method)) {
      int requestId = call.argument("requestId");
      long messageUid = getLongPara(call, "messageUid");
      ProtoLogic.recallMessage(messageUid, new GeneralVoidCallback(requestId));
      result.success(null);
    } else if("uploadMedia".equals(call.method)) {
      result.success(null);
    } else if("deleteMessage".equals(call.method)) {
      long messageId = getLongPara(call, "messageId");
      result.success(ProtoLogic.deleteMessage(messageId));
    } else if("clearMessages".equals(call.method)) {
      Map conversation = call.argument("conversation");
      int type = (int)conversation.get("type");
      String target = (String)conversation.get("target");
      int line = (int)conversation.get("line");
      long before = getLongPara(call, "before");

      boolean ret;
      if(before > 0)
        ret = ProtoLogic.clearMessagesEx(type, target, line, before);
      else
        ret = ProtoLogic.clearMessages(type, target, line);
      result.success(ret);
    } else if("setMediaMessagePlayed".equals(call.method)) {
      long messageId = getLongPara(call, "messageId");
      ProtoLogic.setMediaMessagePlayed(messageId);
      result.success(null);
    } else if("insertMessage".equals(call.method)) {
      Map conversation = call.argument("conversation");
      Map content = call.argument("content");
      int status = call.argument("status");
      long serverTime = getLongPara(call, "serverTime");
      ProtoMessage msg = new ProtoMessage();
      msg.setConversationType((int)conversation.get("type"));
      msg.setTarget((String)conversation.get("target"));
      msg.setLine((int)conversation.get("line"));
      msg.setContent(convertMessageContent(content));
      if(status >= 5) {
        msg.setDirection(1);
      }
      msg.setTimestamp(serverTime);
      msg.setFrom(userId);
      msg.setStatus(status);

      result.success(ProtoLogic.insertMessage(msg));
    } else if("updateMessage".equals(call.method)) {
      long messageId = getLongPara(call, "messageId");
      Map content = call.argument("content");
      ProtoMessage msg = new ProtoMessage();
      msg.setMessageId(messageId);
      msg.setContent(convertMessageContent(content));
      ProtoLogic.updateMessageContent(msg);
      result.success(null);
    } else if("updateMessageStatus".equals(call.method)) {
      long messageId = getLongPara(call, "messageId");
      int status = call.argument("status");
      ProtoLogic.updateMessageStatus(messageId, status);
      result.success(null);
    } else if("getMessageCount".equals(call.method)) {
      Map conversation = call.argument("conversation");
      int type = (int)conversation.get("type");
      String target = (String)conversation.get("target");
      int line = (int)conversation.get("line");

      result.success(ProtoLogic.getMessageCount(type, target, line));
    } else if("getUserInfo".equals(call.method)) {
      String userId = call.argument("userId");
      boolean refresh = call.argument("refresh");
      String groupId = call.argument("groupId");
      result.success(convertProtoUserInfo(ProtoLogic.getUserInfo(userId, groupId, refresh)));
    } else if("getUserInfos".equals(call.method)) {
      List<String> userIds = call.argument("userIds");
      String groupId = call.argument("groupId");
      result.success(convertProtoUserInfos(ProtoLogic.getUserInfos(convertStringList(userIds), groupId)));
    } else if("searchUser".equals(call.method)) {
      final int requestId = call.argument("requestId");
      String keyword = call.argument("keyword");
      int searchType = call.argument("searchType");
      int page = call.argument("page");
      ProtoLogic.searchUser(keyword, searchType, page, new ProtoLogic.ISearchUserCallback() {
        @Override
        public void onSuccess(ProtoUserInfo[] protoUserInfos) {
          Map args = new HashMap();
          args.put("requestId", requestId);
          args.put("users", convertProtoUserInfos(protoUserInfos));
          callback2UI("onSearchUserResult", args);
        }

        @Override
        public void onFailure(int i) {
          callbackFailure(requestId, i);
        }
      });
      result.success(null);
    } else if("getUserInfoAsync".equals(call.method)) {
      final int requestId = call.argument("requestId");
      String userId = call.argument("userId");
      boolean refresh = call.argument("refresh");
      ProtoLogic.getUserInfoEx(userId, refresh, new ProtoLogic.IGetUserInfoCallback() {
        @Override
        public void onSuccess(ProtoUserInfo protoUserInfo) {
          Map args = new HashMap();
          args.put("requestId", requestId);
          args.put("user", convertProtoUserInfo(protoUserInfo));
          callback2UI("onSearchUserResult", args);
        }

        @Override
        public void onFailure(int i) {
          callbackFailure(requestId, i);
        }
      });
      result.success(null);
    } else if("isMyFriend".equals(call.method)) {
      String userId = call.argument("userId");
      result.success(ProtoLogic.isMyFriend(userId));
    } else if("getMyFriendList".equals(call.method)) {
      boolean refresh = call.argument("refresh");
      result.success(convertProtoStringArray(ProtoLogic.getMyFriendList(refresh)));
    } else if("searchFriends".equals(call.method)) {
      String keyword = call.argument("keyword");
      result.success(convertProtoUserInfos(ProtoLogic.searchFriends(keyword)));
    } else if("searchGroups".equals(call.method)) {
      String keyword = call.argument("keyword");
      result.success(convertProtoGroupSearchResults(ProtoLogic.searchGroups(keyword)));
    } else if("getIncommingFriendRequest".equals(call.method)) {
      result.success(convertProtoFriendRequests(ProtoLogic.getFriendRequest(true)));
    } else if("getOutgoingFriendRequest".equals(call.method)) {
      result.success(convertProtoFriendRequests(ProtoLogic.getFriendRequest(false)));
    } else if("getFriendRequest".equals(call.method)) {
      String userId = call.argument("userId");
      int direction = call.argument("direction");
      result.success(convertProtoFriendRequest(ProtoLogic.getOneFriendRequest(userId, direction>0)));
    } else if("loadFriendRequestFromRemote".equals(call.method)) {
      ProtoLogic.loadFriendRequestFromRemote();
      result.success(null);
    } else if("getUnreadFriendRequestStatus".equals(call.method)) {
      result.success(ProtoLogic.getUnreadFriendRequestStatus());
    } else if("clearUnreadFriendRequestStatus".equals(call.method)) {
      result.success(ProtoLogic.clearUnreadFriendRequestStatus());
    } else if("deleteFriend".equals(call.method)) {
      int requestId = call.argument("requestId");
      String userId = call.argument("userId");
      ProtoLogic.deleteFriend(userId, new GeneralVoidCallback(requestId));
      result.success(null);
    } else if("sendFriendRequest".equals(call.method)) {
      int requestId = call.argument("requestId");
      String userId = call.argument("userId");
      String reason = call.argument("reason");
      ProtoLogic.sendFriendRequest(userId, reason, new GeneralVoidCallback(requestId));
      result.success(null);
    } else if("handleFriendRequest".equals(call.method)) {
      int requestId = call.argument("requestId");
      String userId = call.argument("userId");
      String extra = call.argument("extra");
      boolean accept = call.argument("accept");
      ProtoLogic.handleFriendRequest(userId, accept, extra, new GeneralVoidCallback(requestId));
      result.success(null);
    } else if("getFriendAlias".equals(call.method)) {
      String friendId = call.argument("friendId");
      result.success(ProtoLogic.getFriendAlias(friendId));
    } else if("setFriendAlias".equals(call.method)) {
      int requestId = call.argument("requestId");
      String friendId = call.argument("friendId");
      String alias = call.argument("alias");
      ProtoLogic.setFriendAlias(friendId, alias, new GeneralVoidCallback(requestId));
      result.success(null);
    } else if("getFriendExtra".equals(call.method)) {
      String friendId = call.argument("friendId");
      result.success(ProtoLogic.getFriendExtra(friendId));
    } else if("isBlackListed".equals(call.method)) {
      String userId = call.argument("userId");
      result.success(ProtoLogic.isBlackListed(userId));
    } else if("getBlackList".equals(call.method)) {
      boolean refresh = call.argument("refresh");
      result.success(convertProtoStringArray(ProtoLogic.getBlackList(refresh)));
    } else if("setBlackList".equals(call.method)) {
      int requestId = call.argument("requestId");
      String userId = call.argument("userId");
      boolean isBlackListed = call.argument("isBlackListed");
      ProtoLogic.setBlackList(userId, isBlackListed, new GeneralVoidCallback(requestId));
      result.success(null);
    } else if("getGroupMembers".equals(call.method)) {
      String groupId = call.argument("groupId");
      boolean refresh = call.argument("refresh");
      result.success(convertProtoGroupMembers(ProtoLogic.getGroupMembers(groupId, refresh)));
    } else if("getGroupMembersByTypes".equals(call.method)) {
      String groupId = call.argument("groupId");
      int memberType = call.argument("memberType");
      result.success(convertProtoGroupMembers(ProtoLogic.getGroupMembersByType(groupId, memberType)));
    } else if("getGroupMembersAsync".equals(call.method)) {
      final int requestId = call.argument("requestId");
      final String groupId = call.argument("groupId");
      boolean refresh = call.argument("refresh");
      ProtoLogic.getGroupMemberEx(groupId, refresh, new ProtoLogic.IGetGroupMemberCallback() {
        @Override
        public void onSuccess(ProtoGroupMember[] protoGroupMembers) {
          Map args = new HashMap();
          args.put("requestId", requestId);
          args.put("groupId", groupId);
          args.put("members", convertProtoGroupMembers(protoGroupMembers));
          callback2UI("getGroupMembersAsyncCallback", args);
        }

        @Override
        public void onFailure(int i) {
          callbackFailure(requestId, i);
        }
      });
      result.success(null);
    } else if("getGroupInfo".equals(call.method)) {
      String groupId = call.argument("groupId");
      boolean refresh = call.argument("refresh");
      result.success(convertProtoGroupInfo(ProtoLogic.getGroupInfo(groupId, refresh)));
    } else if("getGroupInfoAsync".equals(call.method)) {
      final int requestId = call.argument("requestId");
      String groupId = call.argument("groupId");
      boolean refresh = call.argument("refresh");
      ProtoLogic.getGroupInfoEx(groupId, refresh, new ProtoLogic.IGetGroupInfoCallback() {
        @Override
        public void onSuccess(ProtoGroupInfo protoGroupInfo) {
          Map args = new HashMap();
          args.put("requestId", requestId);
          args.put("groupInfo", convertProtoGroupInfo(protoGroupInfo));
          callback2UI("getGroupInfoAsyncCallback", args);
        }

        @Override
        public void onFailure(int i) {
          callbackFailure(requestId, i);
        }
      });
    } else if("getGroupMember".equals(call.method)) {
      String groupId = call.argument("groupId");
      String memberId = call.argument("memberId");
      result.success(convertProtoGroupMember(ProtoLogic.getGroupMember(groupId, memberId)));
    } else if("createGroup".equals(call.method)) {
      int requestId = call.argument("requestId");
      String groupId = call.argument("groupId");
      String groupName = call.argument("groupName");
      String groupPortrait = call.argument("groupPortrait");
      int groupType = call.argument("type");
      List<String> groupMembers = call.argument("groupMembers");
      List<Integer> notifyLines = call.argument("notifyLines");
      Map notifyContent = call.argument("notifyContent");

      ProtoMessageContent content = convertMessageContent(notifyContent);
      ProtoLogic.createGroup(groupId, groupName, groupPortrait, groupType, convertStringList(groupMembers), convertIntegerList(notifyLines), content, new GeneralStringCallback(requestId));
      result.success(null);
    } else if("addGroupMembers".equals(call.method)) {
      int requestId = call.argument("requestId");
      String groupId = call.argument("groupId");
      List<String> groupMembers = call.argument("groupMembers");
      List<Integer> notifyLines = call.argument("notifyLines");
      Map notifyContent = call.argument("notifyContent");
      ProtoLogic.addMembers(groupId, convertStringList(groupMembers), convertIntegerList(notifyLines), convertMessageContent(notifyContent), new GeneralVoidCallback(requestId));
      result.success(null);
    } else if("kickoffGroupMembers".equals(call.method)) {
      int requestId = call.argument("requestId");
      String groupId = call.argument("groupId");
      List<String> groupMembers = call.argument("groupMembers");
      List<Integer> notifyLines = call.argument("notifyLines");
      Map notifyContent = call.argument("notifyContent");
      ProtoLogic.kickoffMembers(groupId, convertStringList(groupMembers), convertIntegerList(notifyLines), convertMessageContent(notifyContent), new GeneralVoidCallback(requestId));
      result.success(null);
    } else if("quitGroup".equals(call.method)) {
      int requestId = call.argument("requestId");
      String groupId = call.argument("groupId");
      List<Integer> notifyLines = call.argument("notifyLines");
      Map notifyContent = call.argument("notifyContent");
      ProtoLogic.quitGroup(groupId, convertIntegerList(notifyLines), convertMessageContent(notifyContent), new GeneralVoidCallback(requestId));
      result.success(null);
    } else if("dismissGroup".equals(call.method)) {
      int requestId = call.argument("requestId");
      String groupId = call.argument("groupId");
      List<Integer> notifyLines = call.argument("notifyLines");
      Map notifyContent = call.argument("notifyContent");
      ProtoLogic.dismissGroup(groupId, convertIntegerList(notifyLines), convertMessageContent(notifyContent), new GeneralVoidCallback(requestId));
      result.success(null);
    } else if("modifyGroupInfo".equals(call.method)) {
      int requestId = call.argument("requestId");
      String groupId = call.argument("groupId");
      int modifyType = call.argument("modifyType");
      String value = call.argument("value");
      List<Integer> notifyLines = call.argument("notifyLines");
      Map notifyContent = call.argument("notifyContent");
      ProtoLogic.modifyGroupInfo(groupId, modifyType, value, convertIntegerList(notifyLines), convertMessageContent(notifyContent), new GeneralVoidCallback(requestId));
      result.success(null);
    } else if("modifyGroupAlias".equals(call.method)) {
      int requestId = call.argument("requestId");
      String groupId = call.argument("groupId");
      String newAlias = call.argument("newAlias");
      List<Integer> notifyLines = call.argument("notifyLines");
      Map notifyContent = call.argument("notifyContent");
      ProtoLogic.modifyGroupAlias(groupId, newAlias, convertIntegerList(notifyLines), convertMessageContent(notifyContent), new GeneralVoidCallback(requestId));
      result.success(null);
    } else if("modifyGroupMemberAlias".equals(call.method)) {
      int requestId = call.argument("requestId");
      String groupId = call.argument("groupId");
      String memberId = call.argument("memberId");
      String newAlias = call.argument("newAlias");
      List<Integer> notifyLines = call.argument("notifyLines");
      Map notifyContent = call.argument("notifyContent");
      ProtoLogic.modifyGroupMemberAlias(groupId, memberId, newAlias, convertIntegerList(notifyLines), convertMessageContent(notifyContent), new GeneralVoidCallback(requestId));
      result.success(null);
    } else if("transferGroup".equals(call.method)) {
      int requestId = call.argument("requestId");
      String groupId = call.argument("groupId");
      String newOwner = call.argument("newOwner");
      List<Integer> notifyLines = call.argument("notifyLines");
      Map notifyContent = call.argument("notifyContent");
      ProtoLogic.transferGroup(groupId, newOwner, convertIntegerList(notifyLines), convertMessageContent(notifyContent), new GeneralVoidCallback(requestId));
      result.success(null);
    } else if("setGroupManager".equals(call.method)) {
      int requestId = call.argument("requestId");
      String groupId = call.argument("groupId");
      boolean isSet = call.argument("isSet");
      List<String> memberIds = call.argument("memberIds");
      List<Integer> notifyLines = call.argument("notifyLines");
      Map notifyContent = call.argument("notifyContent");
      ProtoLogic.setGroupManager(groupId, isSet, convertStringList(memberIds), convertIntegerList(notifyLines), convertMessageContent(notifyContent), new GeneralVoidCallback(requestId));
      result.success(null);
    } else if("muteGroupMember".equals(call.method)) {
      int requestId = call.argument("requestId");
      String groupId = call.argument("groupId");
      boolean isSet = call.argument("isSet");
      List<String> memberIds = call.argument("memberIds");
      List<Integer> notifyLines = call.argument("notifyLines");
      Map notifyContent = call.argument("notifyContent");
      ProtoLogic.muteOrAllowGroupMember(groupId, false, isSet, convertStringList(memberIds), convertIntegerList(notifyLines), convertMessageContent(notifyContent), new GeneralVoidCallback(requestId));
      result.success(null);
    } else if("allowGroupMember".equals(call.method)) {
      int requestId = call.argument("requestId");
      String groupId = call.argument("groupId");
      boolean isSet = call.argument("isSet");
      List<String> memberIds = call.argument("memberIds");
      List<Integer> notifyLines = call.argument("notifyLines");
      Map notifyContent = call.argument("notifyContent");
      ProtoLogic.muteOrAllowGroupMember(groupId, true, isSet, convertStringList(memberIds), convertIntegerList(notifyLines), convertMessageContent(notifyContent), new GeneralVoidCallback(requestId));
      result.success(null);
    } else if("isFavGroup".equals(call.method)) {
      String groupId = call.argument("groupId");
      String value = getUserSetting(6, groupId);
      result.success(value.equals("1"));
    } else if("setFavGroup".equals(call.method)) {
      int requestId = call.argument("requestId");
      String groupId = call.argument("groupId");
      boolean isFav = call.argument("isFav");
      setUserSetting(requestId, 6, groupId, isFav?"1":"0");
      result.success(null);
    } else if("getUserSetting".equals(call.method)) {
      int scope = call.argument("scope");
      String key = call.argument("key");
      result.success(getUserSetting(scope, key));
    } else if("getUserSettings".equals(call.method)) {
      int scope = call.argument("scope");
      result.success(getUserSettings(scope));
    } else if("setUserSetting".equals(call.method)) {
      int requestId = call.argument("requestId");
      int scope = call.argument("scope");
      String key = call.argument("key");
      String value = call.argument("value");
      setUserSetting(requestId, scope, key, value);
      result.success(null);
    } else if("modifyMyInfo".equals(call.method)) {
      int requestId = call.argument("requestId");
      Map values = call.argument("values");
      ProtoLogic.modifyMyInfo(values, new GeneralVoidCallback(requestId));
      result.success(null);
    } else if("isGlobalSlient".equals(call.method)) {
      result.success("1".equals(getUserSetting(2, "")));
    } else if("setGlobalSlient".equals(call.method)) {
      int requestId = call.argument("requestId");
      boolean isSilent = call.argument("isSilent");
      setUserSetting(requestId, 2, "", isSilent?"1":"0");
      result.success(null);
    } else if("getNoDisturbingTimes".equals(call.method)) {
      int requestId = call.argument("requestId");
      Map args = new HashMap();
      args.put("requestId", requestId);
      String string = getUserSetting(17, "");
      if(TextUtils.isEmpty(string)) {

      } else {
        String[] arras = string.split("\\|");
        if(arras.length == 2) {
          int startMins = Integer.parseInt(arras[0]);
          int endMins = Integer.parseInt(arras[1]);
          args.put("first", startMins);
          args.put("second", endMins);
          callback2UI("onOperationIntPairSuccess", args);
          result.success(null);
          return;
        }
      }
      args.put("errorCode", -1);
      callback2UI("onOperationFailure", args);
      result.success(null);
    } else if("setNoDisturbingTimes".equals(call.method)) {
      int requestId = call.argument("requestId");
      int startMins = call.argument("startMins");
      int endMins = call.argument("endMins");
      String value = startMins + "|" + endMins;
      setUserSetting(requestId, 17, "", value);
      result.success(null);
    } else if("clearNoDisturbingTimes".equals(call.method)) {
      int requestId = call.argument("requestId");
      setUserSetting(requestId, 17, "", "");
      result.success(null);
    } else if("isHiddenNotificationDetail".equals(call.method)) {
      result.success("1".equals(getUserSetting(4, "")));
    } else if("setHiddenNotificationDetail".equals(call.method)) {
      int requestId = call.argument("requestId");
      boolean isHidden = call.argument("isHidden");
      setUserSetting(requestId, 4, "", isHidden?"1":"0");
      result.success(null);
    } else if("isHiddenGroupMemberName".equals(call.method)) {
      String groupId = call.argument("groupId");
      result.success("1".equals(getUserSetting(5, groupId)));
    } else if("setHiddenGroupMemberName".equals(call.method)) {
      int requestId = call.argument("requestId");
      String groupId = call.argument("groupId");
      boolean isHidden = call.argument("isHidden");
      setUserSetting(requestId, 5, groupId, isHidden?"1":"0");
      result.success(null);
    } else if("isUserEnableReceipt".equals(call.method)) {
      result.success("1".equals(getUserSetting(13, "")));
    } else if("setUserEnableReceipt".equals(call.method)) {
      int requestId = call.argument("requestId");
      boolean isEnable = call.argument("isEnable");
      setUserSetting(requestId, 13, "", isEnable?"0":"1");
      result.success(null);
    } else if("getFavUsers".equals(call.method)) {
      Map<String, String> map = getUserSettings(14);
      List<String> output = new ArrayList<>();
      for (Map.Entry<String, String> entry:map.entrySet()) {
        if("1".equals(entry.getValue()))
          output.add(entry.getKey());
      }
      result.success(output);
    } else if("isFavUser".equals(call.method)) {
      String userId = call.argument("userId");
      result.success("1".equals(getUserSetting(14, userId)));
    } else if("setFavUser".equals(call.method)) {
      int requestId = call.argument("requestId");
      String userId = call.argument("userId");
      boolean isFav = call.argument("isFav");
      setUserSetting(requestId, 14, userId, isFav?"1":"0");
      result.success(null);
    } else if("joinChatroom".equals(call.method)) {
      int requestId = call.argument("requestId");
      String chatroomId = call.argument("chatroomId");
      ProtoLogic.joinChatRoom(chatroomId, new GeneralVoidCallback(requestId));
      result.success(null);
    } else if("quitChatroom".equals(call.method)) {
      int requestId = call.argument("requestId");
      String chatroomId = call.argument("chatroomId");
      ProtoLogic.quitChatRoom(chatroomId, new GeneralVoidCallback(requestId));
      result.success(null);
    } else if("getChatroomInfo".equals(call.method)) {
      final int requestId = call.argument("requestId");
      final String chatroomId = call.argument("chatroomId");
      long updateDt = getLongPara(call, "updateDt");
      ProtoLogic.getChatRoomInfo(chatroomId, updateDt, new ProtoLogic.IGetChatRoomInfoCallback() {
        @Override
        public void onSuccess(ProtoChatRoomInfo protoChatRoomInfo) {
          Map args = new HashMap();
          args.put("requestId", requestId);
          args.put("chatroomInfo", convertProtoChatroomInfo(protoChatRoomInfo));
          callback2UI("onGetChatroomInfoResult", args);
        }

        @Override
        public void onFailure(int i) {
          callbackFailure(requestId, i);
        }
      });
      result.success(null);
    } else if("getChatroomMemberInfo".equals(call.method)) {
      final int requestId = call.argument("requestId");
      final String chatroomId = call.argument("chatroomId");
      int maxCount = call.argument("maxCount");
      ProtoLogic.getChatRoomMembersInfo(chatroomId, maxCount, new ProtoLogic.IGetChatRoomMembersInfoCallback() {
        @Override
        public void onSuccess(ProtoChatRoomMembersInfo protoChatRoomMembersInfo) {
          Map args = new HashMap();
          args.put("requestId", requestId);
          args.put("chatroomMemberInfo", convertProtoChatroomMemberInfo(protoChatRoomMembersInfo));
          callback2UI("onGetChatroomMemberInfoResult", args);
        }

        @Override
        public void onFailure(int i) {
          callbackFailure(requestId, i);
        }
      });
      result.success(null);
    } else if("createChannel".equals(call.method)) {
      final int requestId = call.argument("requestId");
      String channelName = call.argument("channelName");
      String channelPortrait = call.argument("channelPortrait");
      String desc = call.argument("desc");
      String extra = call.argument("extra");
      ProtoLogic.createChannel(null, channelName, channelPortrait, 0, desc, extra, new ProtoLogic.ICreateChannelCallback() {
        @Override
        public void onSuccess(ProtoChannelInfo protoChannelInfo) {
          Map args = new HashMap();
          args.put("requestId", requestId);
          args.put("channelInfo", convertProtoChannelInfo(protoChannelInfo));
          callback2UI("onCreateChannelSuccess", args);
        }

        @Override
        public void onFailure(int i) {
          callbackFailure(requestId, i);
        }
      });

      result.success(null);
    } else if("getChannelInfo".equals(call.method)) {
      String channelId = call.argument("channelId");
      boolean refresh = call.argument("refresh");
      result.success(convertProtoChannelInfo(ProtoLogic.getChannelInfo(channelId, refresh)));
    } else if("modifyChannelInfo".equals(call.method)) {
      int requestId = call.argument("requestId");
      String channelId = call.argument("channelId");
      int type = call.argument("type");
      String newValue = call.argument("newValue");
      ProtoLogic.modifyChannelInfo(channelId, type, newValue, new GeneralVoidCallback(requestId));
      result.success(null);
    } else if("searchChannel".equals(call.method)) {
      final int requestId = call.argument("requestId");
      String keyword = call.argument("keyword");
      ProtoLogic.searchChannel(keyword, new ProtoLogic.ISearchChannelCallback() {
        @Override
        public void onSuccess(ProtoChannelInfo[] protoChannelInfos) {
          Map args = new HashMap();
          args.put("requestId", requestId);
          args.put("channelInfo", convertProtoChannelInfos(protoChannelInfos));
          callback2UI("onSearchChannelResult", args);
        }

        @Override
        public void onFailure(int i) {
          callbackFailure(requestId, i);
        }
      });
      result.success(null);
    } else if("isListenedChannel".equals(call.method)) {
      String channelId = call.argument("channelId");
      result.success("1".equals(getUserSetting(9, channelId)));
    } else if("listenChannel".equals(call.method)) {
      int requestId = call.argument("requestId");
      String channelId = call.argument("channelId");
      boolean listen = call.argument("listen");
      ProtoLogic.listenChannel(channelId, listen, new GeneralVoidCallback(requestId));
      result.success(null);
    } else if("getListenedChannels".equals(call.method)) {
      Map<String, String> map = getUserSettings(9);
      List<String> output = new ArrayList<>();
      for (Map.Entry<String, String> entry:map.entrySet()) {
        if("1".equals(entry.getValue()))
          output.add(entry.getKey());
      }
      result.success(output);
    } else if("destoryChannel".equals(call.method)) {
      int requestId = call.argument("requestId");
      String channelId = call.argument("channelId");
      ProtoLogic.destoryChannel(channelId, new GeneralVoidCallback(requestId));
      result.success(null);
    } else if("getOnlineInfos".equals(call.method)) {
      String pcOnline = getUserSetting(10, "PC");
      String webOnline = getUserSetting(10,"Web");
      String wxOnline = getUserSetting(10, "WX");
      List out = new ArrayList();
      if(!TextUtils.isEmpty(pcOnline))
        out.add(pcOnlineInfo(pcOnline, 0));
      if(!TextUtils.isEmpty(webOnline))
        out.add(pcOnlineInfo(webOnline, 1));
      if(!TextUtils.isEmpty(wxOnline))
        out.add(pcOnlineInfo(wxOnline, 2));
      result.success(out);
    } else if("kickoffPCClient".equals(call.method)) {
      int requestId = call.argument("requestId");
      String clientId = call.argument("clientId");
      ProtoLogic.kickoffPCClient(clientId, new GeneralVoidCallback(requestId));
      result.success(null);
    } else if("isMuteNotificationWhenPcOnline".equals(call.method)) {
      result.success("1".equals(getUserSetting(15, "")));
    } else if("muteNotificationWhenPcOnline".equals(call.method)) {
      int requestId = call.argument("requestId");
      boolean isMute = call.argument("isMute");
      setUserSetting(requestId, 15, "", isMute?"1":"0");
      result.success(null);
    } else if("getConversationFiles".equals(call.method)) {
      final int requestId = call.argument("requestId");
      String userId = call.argument("userId");
      Map conversation = call.argument("conversation");
      long beforeMessageUid = getLongPara(call, "beforeMessageUid");
      int count = call.argument("count");

      int type = 0;
      int line  = 0;
      String target = null;
      if(conversation != null) {
        type = (int)conversation.get("type");
        target = (String)conversation.get("target");
        line = (int)conversation.get("line");
      }
      ProtoLogic.getConversationFileRecords(type, target, line, userId, beforeMessageUid, count, new ProtoLogic.ILoadFileRecordCallback() {
        @Override
        public void onSuccess(ProtoFileRecord[] protoFileRecords) {
          Map args = new HashMap();
          args.put("requestId", requestId);
          args.put("files", convertProtoFileRecords(protoFileRecords));
          callback2UI("onFilesResult", args);
        }

        @Override
        public void onFailure(int i) {
          callbackFailure(requestId, i);
        }
      });
      result.success(null);
    } else if("getMyFiles".equals(call.method)) {
      final int requestId = call.argument("requestId");
      long beforeMessageUid = getLongPara(call, "beforeMessageUid");
      int count = call.argument("count");
      ProtoLogic.getMyFileRecords(beforeMessageUid, count, new ProtoLogic.ILoadFileRecordCallback() {
        @Override
        public void onSuccess(ProtoFileRecord[] protoFileRecords) {
          Map args = new HashMap();
          args.put("requestId", requestId);
          args.put("files", convertProtoFileRecords(protoFileRecords));
          callback2UI("onFilesResult", args);
        }

        @Override
        public void onFailure(int i) {
          callbackFailure(requestId, i);
        }
      });
      result.success(null);
    } else if("deleteFileRecord".equals(call.method)) {
      int requestId = call.argument("requestId");
      long messageUid = getLongPara(call, "messageUid");
      ProtoLogic.deleteFileRecords(messageUid, new GeneralVoidCallback(requestId));
      result.success(null);
    } else if("searchFiles".equals(call.method)) {
      final int requestId = call.argument("requestId");
      String keyword = call.argument("keyword");
      String userId = call.argument("userId");
      Map conversation = call.argument("conversation");
      long beforeMessageUid = getLongPara(call, "beforeMessageUid");
      int count = call.argument("count");

      int type = 0;
      int line  = 0;
      String target = null;
      if(conversation != null) {
        type = (int)conversation.get("type");
        target = (String)conversation.get("target");
        line = (int)conversation.get("line");
      }
      ProtoLogic.searchConversationFileRecords(keyword, type, target, line, userId, beforeMessageUid, count, new ProtoLogic.ILoadFileRecordCallback() {
        @Override
        public void onSuccess(ProtoFileRecord[] protoFileRecords) {
          Map args = new HashMap();
          args.put("requestId", requestId);
          args.put("files", convertProtoFileRecords(protoFileRecords));
          callback2UI("onFilesResult", args);
        }

        @Override
        public void onFailure(int i) {
          callbackFailure(requestId, i);
        }
      });
      result.success(null);
    } else if("searchMyFiles".equals(call.method)) {
      final int requestId = call.argument("requestId");
      String keyword = call.argument("keyword");
      long beforeMessageUid = getLongPara(call, "beforeMessageUid");
      int count = call.argument("count");

      ProtoLogic.searchMyFileRecords(keyword, beforeMessageUid, count, new ProtoLogic.ILoadFileRecordCallback() {
        @Override
        public void onSuccess(ProtoFileRecord[] protoFileRecords) {
          Map args = new HashMap();
          args.put("requestId", requestId);
          args.put("files", convertProtoFileRecords(protoFileRecords));
          callback2UI("onFilesResult", args);
        }

        @Override
        public void onFailure(int i) {
          callbackFailure(requestId, i);
        }
      });
      result.success(null);
    } else if("getAuthorizedMediaUrl".equals(call.method)) {
      final int requestId = call.argument("requestId");
      final String mediaPath = call.argument("mediaPath");
      long messageUid = getLongPara(call, "messageUid");
      int mediaType = call.argument("mediaType");
      ProtoLogic.getAuthorizedMediaUrl(messageUid, mediaType, mediaPath, new ProtoLogic.IGeneralCallback2() {
        @Override
        public void onSuccess(String s) {
          Map args = new HashMap();
          args.put("requestId", requestId);
          args.put("string", s);
          callback2UI("onOperationStringSuccess", args);
        }

        @Override
        public void onFailure(int i) {
          Map args = new HashMap();
          args.put("requestId", requestId);
          args.put("string", mediaPath);
          callback2UI("onOperationStringSuccess", args);
        }
      });
      result.success(null);
    } else if("getWavData".equals(call.method)) {
      result.success(null);
    } else if("beginTransaction".equals(call.method)) {
      result.success(ProtoLogic.beginTransaction());;
    } else if("commitTransaction".equals(call.method)) {
      ProtoLogic.commitTransaction();
      result.success(null);
    } else if("isCommercialServer".equals(call.method)) {
      result.success(ProtoLogic.isCommercialServer());
    } else if("isReceiptEnabled".equals(call.method)) {
      result.success(ProtoLogic.isReceiptEnabled());;
    } else {
      result.notImplemented();
    }
  }

  private void callback2UI(@NonNull final String method, @Nullable final Object arguments) {
    handler.post(new Runnable() {
      @Override
      public void run() {
        channel.invokeMethod(method, arguments);
      }
    });

  }
  private int[] convertIntegerList(List<Integer> ints) {
    if (ints == null || ints.size() == 0) {
      int[] arr = new int[1];
      arr[0] = 0;
      return  arr;
    }

    int[] arr = new int[ints.size()];
    for (int i = 0; i < ints.size(); i++) {
      arr[i] = ints.get(i);
    }
    return arr;
  }

  private long getLongPara(MethodCall call, String key) {
    return Long.valueOf(call.argument(key).toString());
  }

  private List<Map<String, Object>> convertProtoConversationInfos(ProtoConversationInfo[] protoDatas) {
    List<Map<String, Object>> output = new ArrayList<>();
    if(protoDatas == null) {
      return output;
    }
    for (ProtoConversationInfo protoData:protoDatas) {
      output.add(convertProtoConversationInfo(protoData));
    }
    return output;
  }

  private Map<String, Object> convertProtoConversationInfo(ProtoConversationInfo protoData) {
    Map<String, Object> map = new HashMap<>();

    Map<String, Object> conversation = new HashMap<>();
    conversation.put("type", protoData.getConversationType());
    conversation.put("target", protoData.getTarget());
    conversation.put("line", protoData.getLine());
    map.put("conversation", conversation);

    Map lastMsg = convertProtoMessage(protoData.getLastMessage());
    if(lastMsg != null)
      map.put("lastMessage", lastMsg);

    if(!TextUtils.isEmpty(protoData.getDraft()))
      map.put("draft", protoData.getDraft());

    map.put("timestamp", protoData.getTimestamp());

    Map unread = convertProtoUnreadCount(protoData.getUnreadCount());
    if(unread != null)
      map.put("unreadCount", unread);

    if(protoData.isTop())
      map.put("isTop", protoData.isTop());
    if(protoData.isSilent())
      map.put("isSilent", protoData.isSilent());

    return map;
  }

  private Map<String, Object> convertProtoUnreadCount(ProtoUnreadCount protoData) {
    if(protoData == null) {
      return null;
    }
    Map<String, Object> map = new HashMap<>();
    map.put("unread", protoData.getUnread());
    if(protoData.getUnreadMention() > 0) {
      map.put("unreadMention", protoData.getUnreadMention());
    }

    if(protoData.getUnreadMentionAll() > 0) {
      map.put("unreadMentionAll", protoData.getUnreadMentionAll());
    }
    return map;
  }

  private Map<String, Object> convertProtoMessage(ProtoMessage protoData) {
    if(TextUtils.isEmpty(protoData.getTarget())) {
      return null;
    }
    Map<String, Object> map = new HashMap<>();

    map.put("fromUser", protoData.getFrom());

    Map<String, Object> conversation = new HashMap<>();
    conversation.put("type", protoData.getConversationType());
    conversation.put("target", protoData.getTarget());
    conversation.put("line", protoData.getLine());
    map.put("conversation", conversation);
    if(protoData.getMessageId() > 0)
      map.put("messageId", protoData.getMessageId());
    if(protoData.getMessageUid() > 0)
      map.put("messageUid", protoData.getMessageUid());
    if(protoData.getTimestamp() > 0)
      map.put("timestamp", protoData.getTimestamp());

    if(protoData.getTos() != null && protoData.getTos().length > 0) {
      map.put("toUsers", convertProtoStringArray(protoData.getTos()));
    }

    map.put("direction", protoData.getDirection());
    map.put("status", protoData.getStatus());
    map.put("content", convertProtoMessageContent(protoData.getContent()));
    return map;
  }
  private List<Map<String, Object>> convertProtoMessages(ProtoMessage[] protoDatas) {
    List output = new ArrayList();
    for (ProtoMessage protoData:protoDatas) {
      output.add(convertProtoMessage(protoData));
    }
    return output;
  }

  private List<Map<String, Object>> convertProtoMessageList(List<ProtoMessage> protoDatas) {
    List output = new ArrayList();
    for (ProtoMessage protoData:protoDatas) {
      output.add(convertProtoMessage(protoData));
    }
    return output;
  }

  private List<String> convertProtoStringArray(String[] arr) {
    List output = new ArrayList();
    for (String a:arr) {
      output.add(a);
    }
    return output;
  }

  private Map<String, Object> convertProtoMessageContent(ProtoMessageContent protoData) {
    Map<String, Object> map = new HashMap<>();
    map.put("type", protoData.getType());

    if(!TextUtils.isEmpty(protoData.getSearchableContent()))
      map.put("searchableContent", protoData.getSearchableContent());
    if(!TextUtils.isEmpty(protoData.getPushContent()))
      map.put("pushContent", protoData.getPushContent());
    if(!TextUtils.isEmpty(protoData.getPushData()))
      map.put("pushData", protoData.getPushData());
    if(!TextUtils.isEmpty(protoData.getContent()))
      map.put("content", protoData.getContent());
    if(protoData.getBinaryContent() != null && protoData.getBinaryContent().length > 0)
      map.put("binaryContent", protoData.getBinaryContent());
    if(!TextUtils.isEmpty(protoData.getLocalContent()))
      map.put("localContent", protoData.getLocalContent());
    if(protoData.getMediaType() > 0)
      map.put("mediaType", protoData.getMediaType());
    if(!TextUtils.isEmpty(protoData.getRemoteMediaUrl()))
      map.put("remoteMediaUrl", protoData.getRemoteMediaUrl());
    if(!TextUtils.isEmpty(protoData.getLocalMediaPath()))
      map.put("localMediaPath", protoData.getLocalMediaPath());
    if(protoData.getMentionedType() > 0)
      map.put("mentionedType", protoData.getMentionedType());
    if(protoData.getMentionedTargets() != null && protoData.getMentionedTargets().length > 0)
      map.put("mentionedTargets", convertProtoStringArray(protoData.getMentionedTargets()));
    if(!TextUtils.isEmpty(protoData.getExtra()))
      map.put("extra", protoData.getExtra());

    return map;
  }

  private Map<String, Object> convertProtoReadEntry(ProtoReadEntry protoData) {
    Map<String, Object> map = new HashMap<>();

    Map<String, Object> conversation = new HashMap<>();
    conversation.put("type", protoData.conversationType);
    conversation.put("target", protoData.target);
    conversation.put("line", protoData.line);
    map.put("conversation", conversation);

    map.put("userId", protoData.userId);
    map.put("readDt", protoData.readDt);
    return map;
  }

  private List<Map<String, Object>> convertProtoReadEntryList(List<ProtoReadEntry> protoDatas) {
    List output = new ArrayList();
    for (ProtoReadEntry protoData:protoDatas) {
      output.add(convertProtoReadEntry(protoData));
    }
    return output;
  }

  private Map<String, Object> convertProtoUserInfo(ProtoUserInfo protoData) {
    Map<String, Object> map = new HashMap<>();
    map.put("userId", protoData.getUid());
    map.put("name", protoData.getName());
    if(!TextUtils.isEmpty(protoData.getPortrait()))
      map.put("portrait", protoData.getPortrait());
    if(protoData.getDeleted() > 0) {
      map.put("deleted", protoData.getDeleted());
      map.put("displayName", "已删除用户");
    } else {
      if (!TextUtils.isEmpty(protoData.getDisplayName()))
        map.put("displayName", protoData.getDisplayName());
      map.put("gender", protoData.getGender());
      //Todo convert more data


      if(!TextUtils.isEmpty(protoData.getFriendAlias()))
        map.put("friendAlias", protoData.getFriendAlias());
      if(!TextUtils.isEmpty(protoData.getGroupAlias()))
        map.put("groupAlias", protoData.getGroupAlias());
      if(!TextUtils.isEmpty(protoData.getExtra()))
        map.put("extra", protoData.getExtra());
      if(protoData.getUpdateDt() > 0)
        map.put("updateDt", protoData.getUpdateDt());
      if(protoData.getType() > 0)
        map.put("type", protoData.getType());
    }
    return map;
  }

  private List<Map<String, Object>> convertProtoUserInfoList(List<ProtoUserInfo> protoDatas) {
    List output = new ArrayList();
    for (ProtoUserInfo protoData:protoDatas) {
      output.add(convertProtoUserInfo(protoData));
    }
    return output;
  }

  private List<Map<String, Object>> convertProtoUserInfos(ProtoUserInfo[] protoDatas) {
    List output = new ArrayList();
    for (ProtoUserInfo protoData:protoDatas) {
      output.add(convertProtoUserInfo(protoData));
    }
    return output;
  }

  private Map<String, Object> convertProtoGroupInfo(ProtoGroupInfo protoData) {
    if (protoData == null) return null;

    Map<String, Object> map = new HashMap<>();
    map.put("type", protoData.getType());
    map.put("target", protoData.getTarget());
    if (!TextUtils.isEmpty(protoData.getName()))
      map.put("name", protoData.getName());
    if (!TextUtils.isEmpty(protoData.getExtra()))
      map.put("extra", protoData.getExtra());
    if (!TextUtils.isEmpty(protoData.getPortrait()))
      map.put("portrait", protoData.getPortrait());
    if (!TextUtils.isEmpty(protoData.getOwner()))
      map.put("owner", protoData.getOwner());
    //Todo
    return map;
  }

  private List<Map<String, Object>> convertProtoGroupInfoList(List<ProtoGroupInfo> protoDatas) {
    List output = new ArrayList();
    for (ProtoGroupInfo protoData:protoDatas) {
      output.add(convertProtoGroupInfo(protoData));
    }
    return output;
  }

  private List<Map<String, Object>> convertProtoGroupInfos(ProtoGroupInfo[] protoDatas) {
    List output = new ArrayList();
    for (ProtoGroupInfo protoData:protoDatas) {
      output.add(convertProtoGroupInfo(protoData));
    }
    return output;
  }

  private Map<String, Object> convertProtoGroupMember(ProtoGroupMember protoData) {
    Map<String, Object> map = new HashMap<>();
    map.put("groupId", protoData.getGroupId());
    map.put("memberId", protoData.getMemberId());
    if (!TextUtils.isEmpty(protoData.getAlias()))
      map.put("alias", protoData.getAlias());
    if(protoData.getType() > 0)
      map.put("type", protoData.getType());
    if(protoData.getCreateDt() > 0)
      map.put("createDt", protoData.getCreateDt());
    if(protoData.getUpdateDt() > 0)
      map.put("updateDt", protoData.getUpdateDt());
    return map;
  }

  private List<Map<String, Object>> convertProtoGroupMemberList(List<ProtoGroupMember> protoDatas) {
    List output = new ArrayList();
    for (ProtoGroupMember protoData:protoDatas) {
      output.add(convertProtoGroupMember(protoData));
    }
    return output;
  }

  private List<Map<String, Object>> convertProtoGroupMembers(ProtoGroupMember[] protoDatas) {
    List output = new ArrayList();
    for (ProtoGroupMember protoData:protoDatas) {
      output.add(convertProtoGroupMember(protoData));
    }
    return output;
  }

  private Map<String, Object> convertProtoGroupSearchResult(ProtoGroupSearchResult protoData) {
    Map<String, Object> map = new HashMap<>();
    map.put("groupInfo", convertProtoGroupInfo(protoData.getGroupInfo()));
    map.put("marchType", protoData.getMarchType());
    if(protoData.getMarchedMembers() != null && protoData.getMarchedMembers().length > 0) {
      map.put("marchedMemberNames", convertProtoStringArray(protoData.getMarchedMembers()));
    }
    return map;
  }

  private List<Map<String, Object>> convertProtoGroupSearchResults(ProtoGroupSearchResult[] protoDatas) {
    List output = new ArrayList();
    for (ProtoGroupSearchResult protoData:protoDatas) {
      output.add(convertProtoGroupSearchResult(protoData));
    }
    return output;
  }
  private Map<String, Object> convertProtoChannelInfo(ProtoChannelInfo protoData) {
    Map<String, Object> map = new HashMap<>();
    map.put("channelId", protoData.getChannelId());
    if (!TextUtils.isEmpty(protoData.getDesc()))
      map.put("desc", protoData.getDesc());
    if (!TextUtils.isEmpty(protoData.getName()))
      map.put("name", protoData.getName());
    if (!TextUtils.isEmpty(protoData.getExtra()))
      map.put("extra", protoData.getExtra());
    if (!TextUtils.isEmpty(protoData.getPortrait()))
      map.put("portrait", protoData.getPortrait());
    if (!TextUtils.isEmpty(protoData.getOwner()))
      map.put("owner", protoData.getOwner());
    if(protoData.getStatus()>0)
      map.put("status", protoData.getStatus());
    if(protoData.getUpdateDt()>0)
      map.put("updateDt", protoData.getUpdateDt());
    return map;
  }

  private List<Map<String, Object>> convertProtoChannelInfoList(List<ProtoChannelInfo> protoDatas) {
    List output = new ArrayList();
    for (ProtoChannelInfo protoData:protoDatas) {
      output.add(convertProtoChannelInfo(protoData));
    }
    return output;
  }

  private List<Map<String, Object>> convertProtoChannelInfos(ProtoChannelInfo[] protoDatas) {
    List output = new ArrayList();
    for (ProtoChannelInfo protoData:protoDatas) {
      output.add(convertProtoChannelInfo(protoData));
    }
    return output;
  }

  private Map<String, Object> convertProtoConversationSearchInfo(ProtoConversationSearchresult protoData) {
    Map<String, Object> map = new HashMap<>();

    Map<String, Object> conversation = new HashMap<>();
    conversation.put("type", protoData.getConversationType());
    conversation.put("target", protoData.getTarget());
    conversation.put("line", protoData.getLine());
    map.put("conversation", conversation);

    Map lastMsg = convertProtoMessage(protoData.getMarchedMessage());
    if(lastMsg != null)
      map.put("marchedMessage", lastMsg);

    map.put("marchedCount", protoData.getMarchedCount());
    map.put("timestamp", protoData.getTimestamp());

    return map;
  }

  private List<Map<String, Object>> convertProtoConversationSearchInfos(ProtoConversationSearchresult[] protoDatas) {
    List output = new ArrayList();
    for (ProtoConversationSearchresult protoData:protoDatas) {
      output.add(convertProtoConversationSearchInfo(protoData));
    }
    return output;
  }

  private Map<String, Object> convertProtoFriendRequest(ProtoFriendRequest protoData) {
    Map<String, Object> map = new HashMap<>();
    map.put("direction", protoData.getDirection());
    map.put("target", protoData.getTarget());
    if(!TextUtils.isEmpty(protoData.getReason()))
      map.put("reason", protoData.getReason());
    map.put("status", protoData.getStatus());
    map.put("readStatus", protoData.getReadStatus());
    map.put("timestamp", protoData.getTimestamp());
    return map;
  }

  private List<Map<String, Object>> convertProtoFriendRequests(ProtoFriendRequest[] protoDatas) {
    List output = new ArrayList();
    for (ProtoFriendRequest protoData:protoDatas) {
      output.add(convertProtoFriendRequest(protoData));
    }
    return output;
  }

  private Map<String, Object> convertProtoFileRecord(ProtoFileRecord protoData) {
    Map<String, Object> map = new HashMap<>();
    Map<String, Object> conversation = new HashMap<>();
    conversation.put("type", protoData.getConversationType());
    conversation.put("target", protoData.getTarget());
    conversation.put("line", protoData.getLine());
    map.put("conversation", conversation);

    map.put("messageUid", protoData.getMessageUid());
    map.put("userId", protoData.getUserId());
    map.put("name", protoData.getName());
    map.put("url", protoData.getUrl());
    map.put("size", protoData.getSize());
    map.put("downloadCount", protoData.getDownloadCount());
    map.put("timestamp", protoData.getTimestamp());
    return map;
  }

  private List<Map<String, Object>> convertProtoFileRecords(ProtoFileRecord[] protoDatas) {
    List output = new ArrayList();
    for (ProtoFileRecord protoData:protoDatas) {
      output.add(convertProtoFileRecord(protoData));
    }
    return output;
  }

  private Map<String, Object> convertProtoChatroomInfo(ProtoChatRoomInfo protoData) {
    Map<String, Object> map = new HashMap<>();
    map.put("title", protoData.getTitle());
    map.put("desc", protoData.getDesc());
    map.put("portrait", protoData.getPortrait());
    map.put("extra", protoData.getExtra());
    map.put("state", protoData.getState());
    map.put("memberCount", protoData.getMemberCount());
    map.put("createDt", protoData.getCreateDt());
    map.put("updateDt", protoData.getUpdateDt());
    return map;
  }

  private Map<String, Object> convertProtoChatroomMemberInfo(ProtoChatRoomMembersInfo protoData) {
    Map<String, Object> map = new HashMap<>();
    map.put("memberCount", protoData.getMemberCount());
    if(protoData.getMembers() != null)
    map.put("members", protoData.getMembers());
    return map;
  }

  private Map<String, Object> pcOnlineInfo(String strInfo, int type) {
    Map map = new HashMap();
    map.put("type", type);
    if(!TextUtils.isEmpty(strInfo)) {
      map.put("isOnline", true);
      String[] parts = strInfo.split("\\|");
      if(parts.length == 4) {
        map.put("timestamp", Long.parseLong(parts[0]));
        map.put("platform", Long.parseLong(parts[1]));
        map.put("clientId", Long.parseLong(parts[2]));
        map.put("clientName", Long.parseLong(parts[3]));
      }
    } else {
      map.put("isOnline", false);
    }
    return map;
  }

  private String[] convertStringList(List<String> list) {
    if(list == null || list.isEmpty())
      return null;

    String[] arr = new String[list.size()];
    for (int i = 0; i < list.size(); i++) {
      arr[i] = list.get(i);
    }
    return arr;
  }

  private ProtoMessageContent convertMessageContent(Map<String, Object> map) {
    ProtoMessageContent protoData = new ProtoMessageContent();
    if(map == null || map.isEmpty() || !map.containsKey("type")) {
      return null;
    }

    protoData.setType((int)map.get("type"));
    protoData.setSearchableContent((String)map.get("searchableContent"));
    protoData.setPushContent((String)map.get("pushContent"));
    protoData.setPushData((String)map.get("pushData"));
    protoData.setContent((String)map.get("content"));
    protoData.setBinaryContent((byte[])map.get("binaryContent"));
    protoData.setLocalContent((String)map.get("localContent"));
    protoData.setMediaType((int)map.get("mediaType"));
    protoData.setRemoteMediaUrl((String)map.get("remoteMediaUrl"));
    protoData.setLocalMediaPath((String)map.get("localMediaPath"));
    protoData.setMentionedType((int)map.get("mentionedType"));
    if(map.get("mentionedTargets") != null) {
      List<String> ts = (List<String>)map.get("mentionedTargets");
      if(!ts.isEmpty()) {
        String[] arr = new String[ts.size()];
        for (int i = 0; i < ts.size(); i++) {
          arr[i] = ts.get(i);
        }
        protoData.setMentionedTargets(arr);
      }
    }
    protoData.setExtra((String)map.get("extra"));

    return protoData;
  }

  private void callbackFailure(int requestId, int errorCode) {
    Map args = new HashMap();
    args.put("requestId", requestId);
    args.put("errorCode", errorCode);
    callback2UI("onOperationFailure", args);
  }

  private class GeneralVoidCallback implements ProtoLogic.IGeneralCallback {
    private int requestId;

    public GeneralVoidCallback(int requestId) {
      this.requestId = requestId;
    }

    @Override
    public void onSuccess() {
      Map args = new HashMap();
      args.put("requestId", requestId);
      callback2UI("onOperationVoidSuccess", args);
    }

    @Override
    public void onFailure(int i) {
      callbackFailure(requestId, i);
    }
  }

  private class GeneralStringCallback implements ProtoLogic.IGeneralCallback2 {
    private int requestId;

    public GeneralStringCallback(int requestId) {
      this.requestId = requestId;
    }

    @Override
    public void onSuccess(String string) {
      Map args = new HashMap();
      args.put("requestId", requestId);
      args.put("string", string);
      callback2UI("onOperationStringSuccess", args);
    }

    @Override
    public void onFailure(int i) {
      callbackFailure(requestId, i);
    }
  }
  private class SendMessageCallback implements ProtoLogic.ISendMessageCallback {
    private int requestId;
    private ProtoMessage message;

    public SendMessageCallback(int requestId, ProtoMessage msg) {
      this.requestId = requestId;
      this.message = msg;
    }

    @Override
    public void onSuccess(long l, long l1) {
      Map args = new HashMap();
      args.put("requestId", requestId);
      args.put("messageUid", l);
      args.put("timestamp", l1);
      callback2UI("onSendMessageSuccess", args);
    }

    @Override
    public void onFailure(int i) {
      callbackFailure(requestId, i);
    }

    @Override
    public void onPrepared(long l, long l1) {
      if(message != null) {
        message.setMessageId(l);
        message.setTimestamp(l1);
      }
    }

    @Override
    public void onProgress(long l, long l1) {
      Map args = new HashMap();
      args.put("requestId", requestId);
      args.put("uploaded", l);
      args.put("total", l1);
      callback2UI("onSendMediaMessageProgress", args);
    }

    @Override
    public void onMediaUploaded(String s) {
      Map args = new HashMap();
      args.put("requestId", requestId);
      args.put("remoteUrl", s);
      callback2UI("onSendMediaMessageUploaded", args);
    }
  }

  private void setUserSetting(int requestId, int scope, String key, String value) {
    ProtoLogic.setUserSetting(scope, key, value, new GeneralVoidCallback(requestId));
  }

  private String getUserSetting(int scope, String key) {
    return ProtoLogic.getUserSetting(scope, key);
  }

  private Map<String, String> getUserSettings(int scope) {
    return ProtoLogic.getUserSettings(scope);
  }

  private void updateConnectionStatus(int status) {
    connectionStatus = status;
    callback2UI("onConnectionStatusChanged", status);
    if(connectionStatus == 1 && !deviceTokenSetted && !TextUtils.isEmpty(pushToken)) {
      deviceTokenSetted = true;
      ProtoLogic.setDeviceToken(gContext.getPackageName(), pushToken, pushType);
    }
  }

  public List<String> getLogFilesPath() {
    List<String> paths = new ArrayList<>();
    String path = getLogPath();

    //遍历path目录下的所有日志文件，以wflog开头的
    File dir = new File(path);
    File[] subFile = dir.listFiles();
    if (subFile != null) {
      for (File file : subFile) {
        //wflog为ChatService中定义的，如果修改需要对应修改
        if (file.isFile() && file.getName().startsWith("wflog_")) {
          paths.add(file.getAbsolutePath());
        }
      }
    }
    return paths;
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    Mars.onDestroy();
    ProtoLogic.appWillTerminate();

    AppLogic.setCallBack(null);
    SdtLogic.setCallBack(null);
    ProtoLogic.setUserInfoUpdateCallback(null);
    ProtoLogic.setSettingUpdateCallback(null);
    ProtoLogic.setFriendListUpdateCallback(null);
    ProtoLogic.setGroupInfoUpdateCallback(null);
    ProtoLogic.setChannelInfoUpdateCallback(null);
    ProtoLogic.setGroupMembersUpdateCallback(null);
    ProtoLogic.setFriendRequestListUpdateCallback(null);
    ProtoLogic.setConnectionStatusCallback(null);
    ProtoLogic.setReceiveMessageCallback(null);
    ProtoLogic.setConferenceEventCallback(null);

    channel.setMethodCallHandler(null);
  }

  @Override
  public String getAppFilePath() {
    if (userId != null)
      return appPath + "/" + userId;
    return appPath;
  }

  @Override
  public AppLogic.AccountInfo getAccountInfo() {
    return accountInfo;
  }

  @Override
  public int getClientVersion() {
    return 1;
  }

  @Override
  public AppLogic.DeviceInfo getDeviceType() {
    if(info == null) {
      info = new AppLogic.DeviceInfo(getClientId());
      info.packagename = gContext.getPackageName();
      info.device = Build.MANUFACTURER;
      info.deviceversion = Build.VERSION.RELEASE;
      info.phonename = Build.MODEL;

      Locale locale;
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
        locale = LocaleList.getDefault().get(0);
      } else {
        locale = Locale.getDefault();
      }

      info.language = locale.getLanguage();
      info.language = TextUtils.isDigitsOnly(info.language) ? "zh_CN" : info.language;
    }
    return info;
  }

  @Override
  public void reportSignalDetectResults(String s) {

  }

  @Override
  public void onChannelInfoUpdated(List<ProtoChannelInfo> list) {
    Map args = new HashMap();
    args.put("channels", convertProtoChannelInfoList(list));
    callback2UI("onChannelInfoUpdated", args);
  }

  @Override
  public void onConferenceEvent(String s) {

  }

  @Override
  public void onConnectionStatusChanged(int i) {
    updateConnectionStatus(i);
  }

  @Override
  public void onFriendListUpdated(String[] strings) {
    Map args = new HashMap();
    args.put("friends", convertProtoStringArray(strings));
    callback2UI("onFriendListUpdated", args);
  }

  @Override
  public void onFriendRequestUpdated(String[] strings) {
    Map args = new HashMap();
    args.put("requests", convertProtoStringArray(strings));
    callback2UI("onFriendRequestUpdated", args);
  }

  @Override
  public void onGroupInfoUpdated(List<ProtoGroupInfo> list) {
    Map args = new HashMap();
    args.put("groups", convertProtoGroupInfoList(list));
    callback2UI("onGroupInfoUpdated", args);
  }

  @Override
  public void onGroupMembersUpdated(String s, List<ProtoGroupMember> list) {
    Map args = new HashMap();
    args.put("groupId", s);
    args.put("members", convertProtoGroupMemberList(list));
    callback2UI("onGroupMemberUpdated", args);
  }

  @Override
  public void onReceiveMessage(List<ProtoMessage> list, boolean b) {
    Map<String, Object> args = new HashMap<>();
    args.put("messages", convertProtoMessageList(list));
    args.put("hasMore", b);
    callback2UI("onReceiveMessage", args);
  }

  @Override
  public void onRecallMessage(long l) {
    Map<String, Object> args = new HashMap<>();
    args.put("messageUid", l);
    callback2UI("onRecallMessage", args);
  }

  @Override
  public void onDeleteMessage(long l) {
    Map<String, Object> args = new HashMap<>();
    args.put("messageUid", l);
    callback2UI("onDeleteMessage", args);
  }

  @Override
  public void onUserReceivedMessage(Map<String, Long> map) {
    callback2UI("onMessageDelivered", map);
  }

  @Override
  public void onUserReadedMessage(List<ProtoReadEntry> list) {
    Map<String, Object> args = new HashMap<>();
    args.put("readeds", convertProtoReadEntryList(list));
    callback2UI("onMessageReaded", args);
  }

  @Override
  public void onSettingUpdated() {
    callback2UI("onSettingUpdated", null);
  }

  @Override
  public void onUserInfoUpdated(List<ProtoUserInfo> list) {
    Map<String, Object> args = new HashMap<>();
    args.put("users", convertProtoUserInfoList(list));
    callback2UI("onUserInfoUpdated", args);
  }
}
