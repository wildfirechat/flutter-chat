package cn.wildfirechat.momentclient;

import android.app.Activity;
import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.text.TextUtils;
import android.util.Base64;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

import cn.wildfirechat.message.Message;
import cn.wildfirechat.message.core.MessagePayload;
import cn.wildfirechat.model.Conversation;
import cn.wildfirechat.moment.MomentClient;
import cn.wildfirechat.moment.OnReceiveFeedMessageListener;
import cn.wildfirechat.moment.model.Comment;
import cn.wildfirechat.moment.model.Feed;
import cn.wildfirechat.moment.model.FeedEntry;
import cn.wildfirechat.moment.model.Profile;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/** MomentclientPlugin */
public class MomentclientPlugin implements FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private static final String TAG = "MomentclientPlugin";
  private static MethodChannel channel;
  private static Handler handler;

  private static boolean initialized = false;
  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
      if (channel == null){
          channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "momentclient");
          channel.setMethodCallHandler(this);
      }
    if (initialized){
      return;
    }
    initialized = true;
    handler = new Handler(Looper.getMainLooper());
    MomentClient.getInstance().init(flutterPluginBinding.getApplicationContext());
    MomentClient.getInstance().setMomentMessageReceiveListener(new OnReceiveFeedMessageListener() {
      @Override
      public void onReceiveFeedCommentMessage(Message message) {
        Map<String, Object> args = new HashMap<>();
        args.put("comment", convertMessageContent(message.content.encode()));
        callback2UI("onReceiveNewComment", args);
      }

      @Override
      public void onReceiveFeedMessage(Message message) {
        Map<String, Object> args = new HashMap<>();
        args.put("feed", convertMessageContent(message.content.encode()));
        callback2UI("onReceiveMentionedFeed", args);
      }
    });
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    try {
      Method method = this.getClass().getDeclaredMethod(call.method, MethodCall.class, Result.class);
      method.invoke(this, call, result);
    } catch (NoSuchMethodException e) {
      result.notImplemented();
    } catch (InvocationTargetException e) {
      e.printStackTrace();
    } catch (IllegalAccessException e) {
      e.printStackTrace();
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
      if (channel != null){
          channel.setMethodCallHandler(null);
          channel = null;
      }
  }

  private void postFeed(@NonNull MethodCall call, @NonNull Result result) {
    int requestId = intArg(call, "requestId");
    int type = intArg(call, "type");
    String text = call.argument("text");
    ArrayList<String> toUsers = call.argument("toUsers");
    ArrayList<String> excludeUsers = call.argument("excludeUsers");
    ArrayList<String> mentionedUsers = call.argument("mentionedUsers");
    String extra = call.argument("extra");

    Feed feed = new Feed();
    ArrayList<Map> medias = call.argument("medias");
    if(medias != null) {
      feed.medias = new ArrayList<>();
      for (Map media : medias) {
        feed.medias.add(feedEntryFromMap(media));
      }
    }
    feed.type = type;
    feed.text = text;
    feed.toUsers = toUsers;
    feed.excludeUsers = excludeUsers;
    feed.mentionedUser = mentionedUsers;
    feed.extra = extra;
    feed = MomentClient.getInstance().postFeed(feed, new MomentClient.PostCallback() {
      @Override
      public void onSuccess(long l, long l1) {
        callbackBuilder(requestId).put("feedId", l).put("timestamp", l1).success("postFeedSuccess");
      }

      @Override
      public void onFailure(int i) {
        callbackBuilder(requestId).fail(i);
      }
    });
    result.success(jsonToMap(feed.toJsonObject()));
  }
  private void deleteFeed(@NonNull MethodCall call, @NonNull Result result) {
    int requestId = intArg(call, "requestId");
    long feedId = longArg(call, "feedId");
    MomentClient.getInstance().deleteFeed(null, feedId, new MomentClient.GeneralCallback() {
      @Override
      public void onSuccess() {
        callbackBuilder(requestId).success("onOperationVoidSuccess");
      }

      @Override
      public void onFailure(int i) {
        callbackBuilder(requestId).fail(i);
      }
    });
  }

  private void getFeeds(@NonNull MethodCall call, @NonNull Result result) {
    int requestId = intArg(call, "requestId");
    long fromIndex = longArg(call, "fromIndex");
    int count = intArg(call, "count");
    String user = call.argument("user");
    MomentClient.getInstance().getFeeds(fromIndex, count, user, new MomentClient.GetFeedsCallback() {
      @Override
      public void onSuccess(List<Feed> list) {
        List<Object> out = new ArrayList<>();
        for (Feed feed : list) {
          out.add(jsonToMap(feed.toJsonObject()));
        }
        callbackBuilder(requestId).put("feeds", out).success("getFeedsSuccess");
      }

      @Override
      public void onFailure(int i) {
        callbackBuilder(requestId).fail(i);
      }
    });
  }
  private void getFeed(@NonNull MethodCall call, @NonNull Result result) {
    int requestId = intArg(call, "requestId");
    long feedId = longArg(call, "feedId");
    MomentClient.getInstance().getFeed(feedId, new MomentClient.GetFeedCallback() {
      @Override
      public void onSuccess(Feed feed) {
        callbackBuilder(requestId).put("feed", jsonToMap(feed.toJsonObject())).success("getFeedSuccess");
      }

      @Override
      public void onFailure(int i) {
        callbackBuilder(requestId).fail(i);
      }
    });
  }
  private void postComment(@NonNull MethodCall call, @NonNull Result result) {
    int requestId = intArg(call, "requestId");
    int type = intArg(call, "type");
    long feedId = longArg(call, "feedId");
    long replyCommentId = longArg(call, "replyCommentId");
    String text = call.argument("text");
    String replyTo = call.argument("replyTo");
    String extra = call.argument("extra");

    Comment comment = MomentClient.getInstance().postComment(type, feedId, text, replyTo, replyCommentId, extra, new MomentClient.PostCallback() {
      @Override
      public void onSuccess(long l, long l1) {
        callbackBuilder(requestId).put("commentId", l).put("timestamp", l1).success("postCommentSuccess");
      }

      @Override
      public void onFailure(int i) {
        callbackBuilder(requestId).fail(i);
      }
    });
    result.success(jsonToMap(comment.toJsonObject()));
  }
  private void deleteComment(@NonNull MethodCall call, @NonNull Result result) {
    int requestId = intArg(call, "requestId");
    long feedId = longArg(call, "feedId");
    long commentId = longArg(call, "commentId");
    MomentClient.getInstance().deleteComment(null, feedId, commentId, new MomentClient.GeneralCallback() {
      @Override
      public void onSuccess() {
        callbackBuilder(requestId).success("onOperationVoidSuccess");
      }

      @Override
      public void onFailure(int i) {
        callbackBuilder(requestId).fail(i);
      }
    });
  }
  private void getMessages(@NonNull MethodCall call, @NonNull Result result) {
    boolean isNew = call.argument("isNew");
    List<Message> feedMsg = MomentClient.getInstance().getFeedMessages(0, isNew);
    result.success(convertMessageList(feedMsg, false));
  }
  private void getUnreadCount(@NonNull MethodCall call, @NonNull Result result) {
    result.success(MomentClient.getInstance().getUnreadCount());
  }
  private void clearUnreadStatus(@NonNull MethodCall call, @NonNull Result result) {
    MomentClient.getInstance().clearUnreadStatus();
    result.success(null);
  }
  private void storeCache(@NonNull MethodCall call, @NonNull Result result) {
    List<Map> feeds = call.argument("feeds");
    String userId = call.argument("callId");
    List<Feed> fs = new ArrayList<>();
    for (Map map : feeds) {
      Feed f = new Feed();
      f.fromJsonObject(new JSONObject(map));
      fs.add(f);
    }

    MomentClient.getInstance().storeCache(fs, userId);

    result.success(null);
  }
  private void restoreCache(@NonNull MethodCall call, @NonNull Result result) {
    String userId = call.argument("callId");
    List<Feed> feeds = MomentClient.getInstance().restoreCache(userId);
    List<Object> js = new ArrayList<>();
    for (Feed feed : feeds) {
      js.add(jsonToMap(feed.toJsonObject()));
    }
    result.success(js);
  }
  private void getUserProfile(@NonNull MethodCall call, @NonNull Result result) {
    int requestId = intArg(call, "requestId");
    String userId = call.argument("userId");
    MomentClient.getInstance().getUserProfile(userId, new MomentClient.UserProfileCallback() {
      @Override
      public void onSuccess(Profile profile) {
        callbackBuilder(requestId).put("profile", jsonToMap(profile.toJsonObject())).success("getProfileSuccess");
      }

      @Override
      public void onFailure(int i) {
        callbackBuilder(requestId).fail(i);
      }
    });
  }

  private void updateMyProfile(@NonNull MethodCall call, @NonNull Result result) {
    int requestId = intArg(call, "requestId");
    int updateProfileType = intArg(call, "updateProfileType");
    String strValue = call.argument("strValue");
    int intValue = intArg(call, "intValue");
    MomentClient.getInstance().updateUserProfile(updateProfileType, strValue, intValue, new MomentClient.GeneralCallback() {
      @Override
      public void onSuccess() {
        callbackBuilder(requestId).success("onOperationVoidSuccess");
      }

      @Override
      public void onFailure(int i) {
        callbackBuilder(requestId).fail(i);
      }
    });
  }
  private void updateBlackOrBlockList(@NonNull MethodCall call, @NonNull Result result) {
    int requestId = intArg(call, "requestId");
    boolean isBlock = call.argument("isBlock");
    ArrayList<String> addList = call.argument("addList");
    ArrayList<String> removeList = call.argument("removeList");
    MomentClient.getInstance().updateBlackOrBlockList(isBlock, addList, removeList, new MomentClient.GeneralCallback() {
      @Override
      public void onSuccess() {
        callbackBuilder(requestId).success("onOperationVoidSuccess");
      }

      @Override
      public void onFailure(int i) {
        callbackBuilder(requestId).fail(i);
      }
    });
  }
  private void updateLastReadTimestamp(@NonNull MethodCall call, @NonNull Result result) {
    MomentClient.getInstance().updateLastReadTimestamp();
    result.success(null);
  }
  private void getLastReadTimestamp(@NonNull MethodCall call, @NonNull Result result) {
    result.success(MomentClient.getInstance().getLastReadTimestamp());
  }


  public CallbackBuilder callbackBuilder(int requestId) {
    return new CallbackBuilder(requestId);
  }

  private class CallbackBuilder {
    Map args = new HashMap();
    int requestId;

    private CallbackBuilder(int requestId) {
      this.requestId = requestId;
      args.put("requestId", requestId);
    }

    public CallbackBuilder put(String key, Object value) {
      args.put(key, value);
      return this;
    }

    public CallbackBuilder put(String key, int value) {
      args.put(key, value);
      return this;
    }

    public CallbackBuilder put(String key, long value) {
      args.put(key, value);
      return this;
    }

    public CallbackBuilder put(String key, boolean value) {
      args.put(key, value);
      return this;
    }

    public void success(String event) {
      callback2UI(event, args);
    }

    public void fail(int errorcode) {
      callbackFailure(requestId, errorcode);
    }
  }

  private void callbackFailure(int requestId, int errorCode) {
    Map args = new HashMap();
    args.put("requestId", requestId);
    args.put("errorCode", errorCode);
    callback2UI("onOperationFailure", args);
  }

  private static void callback2UI(@NonNull final String method, @Nullable final Object arguments) {
    handler.post(new Runnable() {
      @Override
      public void run() {
        if (channel != null) {
          try {
            channel.invokeMethod(method, arguments);
          } catch (Exception e) {
            Log.e(TAG, "Callback failure!!!");
            e.printStackTrace();
          }
        } else {
          Log.e(TAG, "Unable callback to UI, because engine is deattached");
        }
      }
    });

  }

  private static Object jsonToMap(Object object) {
    if(object instanceof JSONArray) {
      JSONArray arr = (JSONArray) object;
      List<Object> result = new ArrayList();
      for (int i = 0; i < arr.length(); i++) {
        Object o = arr.opt(i);
        result.add(jsonToMap(o));
      }
      return result;
    } else if(object instanceof JSONObject) {
      JSONObject jsonObject = (JSONObject)object;
      Map<String, Object> map = new HashMap<>();
      Iterator<String> keys = jsonObject.keys();
      while (keys.hasNext()) {
        String key = keys.next();
        Object value = jsonObject.opt(key);
        Object map2 = jsonToMap(value);
        map.put(key, map2);
      }
      return map;
    } else {
      return object;
    }
  }

  private static FeedEntry feedEntryFromMap(Map map) {
    FeedEntry entry = new FeedEntry();
    entry.mediaUrl = (String) map.get("m");
    entry.thumbUrl = (String) map.get("t");
    entry.mediaWidth = (int) map.get('w');
    entry.mediaHeight = (int) map.get('h');
    return entry;
  }
  private static Map<String, Object> convertConversation(Conversation protoData) {
    Map<String, Object> conversation = new HashMap<>();
    conversation.put("type", protoData.type.getValue());
    conversation.put("target", protoData.target);
    conversation.put("line", protoData.line);
    return conversation;
  }

  private static List<Map<String, Object>> convertMessageList(List<Message> protoDatas, boolean reverse) {
    ArrayList output = new ArrayList();
    for (Message protoData : protoDatas) {
      if (reverse)
        output.add(0, convertMessage(protoData));
      else
        output.add(convertMessage(protoData));
    }
    return output;
  }
  private static Map<String, Object> convertMessage(Message protoData) {
    if (protoData == null) {
      return null;
    }
    Map<String, Object> map = new HashMap<>();

    map.put("sender", protoData.sender);
    map.put("conversation", convertConversation(protoData.conversation));
    if (protoData.messageId > 0)
      map.put("messageId", protoData.messageId);
    if (protoData.messageUid > 0)
      map.put("messageUid", protoData.messageUid);
    if (protoData.serverTime > 0)
      map.put("serverTime", protoData.serverTime);

    if (protoData.toUsers != null && protoData.toUsers.length > 0) {
      map.put("toUsers", convertProtoStringArray(protoData.toUsers));
    }

    map.put("direction", protoData.direction.value());
    map.put("status", protoData.status.value());
    map.put("content", convertMessageContent(protoData.content.encode()));
    return map;
  }

  private static Map<String, Object> convertMessageContent(MessagePayload protoData) {
    Map<String, Object> map = new HashMap<>();
    map.put("type", protoData.type);

    if (!TextUtils.isEmpty(protoData.searchableContent))
      map.put("searchableContent", protoData.searchableContent);
    if (!TextUtils.isEmpty(protoData.pushContent))
      map.put("pushContent", protoData.pushContent);
    if (!TextUtils.isEmpty(protoData.pushData))
      map.put("pushData", protoData.pushData);
    if (!TextUtils.isEmpty(protoData.content))
      map.put("content", protoData.content);
    if (protoData.binaryContent != null && protoData.binaryContent.length > 0)
      map.put("binaryContent", Base64.encodeToString(protoData.binaryContent, Base64.NO_WRAP));
    if (!TextUtils.isEmpty(protoData.localContent))
      map.put("localContent", protoData.localContent);
    if (protoData.mediaType != null)
      map.put("mediaType", protoData.mediaType.getValue());
    if (!TextUtils.isEmpty(protoData.remoteMediaUrl))
      map.put("remoteMediaUrl", protoData.remoteMediaUrl);
    if (!TextUtils.isEmpty(protoData.localMediaPath))
      map.put("localMediaPath", protoData.localMediaPath);
    if (protoData.mentionedType > 0)
      map.put("mentionedType", protoData.mentionedType);
    if (protoData.mentionedTargets != null && protoData.mentionedTargets.size() > 0)
      map.put("mentionedTargets", protoData.mentionedTargets);
    if (!TextUtils.isEmpty(protoData.extra))
      map.put("extra", protoData.extra);

    return map;
  }

  private static List<String> convertProtoStringArray(String[] arr) {
    List output = new ArrayList();
    for (String a : arr) {
      output.add(a);
    }
    return output;
  }

  private int intArg(MethodCall call, String key) {
    Object object = call.argument(key);
    if(object == null) {
      return 0;
    }
    if(object instanceof Integer) {
      return (Integer)object;
    }
    if(object instanceof Long) {
      long l = (Long)object;
      return (int)l;
    }
    if(object instanceof Float) {
      float f = (Float)object;
      return (int)f;
    }
    if(object instanceof Double) {
      double d = (Double)object;
      return (int)d;
    }

    return 0;
  }

  private long longArg(MethodCall call, String key) {
    Object object = call.argument(key);
    if(object == null) {
      return 0;
    }
    if(object instanceof Integer) {
      int i = (Integer)object;
      return i;
    }
    if(object instanceof Long) {
      long l = (Long)object;
      return l;
    }
    if(object instanceof Float) {
      float f = (Float)object;
      return (long) f;
    }
    if(object instanceof Double) {
      double d = (Double)object;
      return (long)d;
    }

    return 0;
  }
}
