package cn.wildfirechat.rtckit;

import android.app.Activity;
import android.app.Application;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import org.json.JSONObject;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import cn.wildfire.chat.kit.Config;
import cn.wildfire.chat.kit.voip.conference.ConferenceInfoActivity;
import cn.wildfire.chat.kit.voip.conference.ConferencePortalActivity;
import cn.wildfirechat.avenginekit.AVEngineKit;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

import cn.wildfire.chat.kit.WfcUIKit;
import okhttp3.HttpUrl;

/**
 * RtckitPlugin
 */
public class RtckitPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware, AVEngineKit.AVEngineCallback {
    private static final String TAG = "WFCUIKit";
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private static MethodChannel channel;
    private static Handler handler;
    private static Context gContent;
    private static Activity gActivity;
    private static boolean isWfcUIKitInitialized = false;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        if (channel == null) {
            channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "rtckit");
            channel.setMethodCallHandler(this);
            handler = new Handler(Looper.getMainLooper());
        }
        if (isWfcUIKitInitialized) {
            return;
        }
        Log.e("RtckitPlugin", "isSupportMoment " + WfcUIKit.getWfcUIKit().isSupportMoment());

        isWfcUIKitInitialized = true;
        gContent = flutterPluginBinding.getApplicationContext();
        Context context = gContent;
        while (context != null) {
            if (context instanceof Application) {
                Application application = (Application) context;
                Config.ICE_SERVERS = null;
                WfcUIKit.getWfcUIKit().init(application);
                WfcUIKit.getWfcUIKit().setAppServiceProvider(AppService.Instance());
                WfcUIKit.getWfcUIKit().setEnableNativeNotification(false);
                WfcUIKit.getWfcUIKit().setAvEngineCallback(this);
                setupWFCDirs(application);
                break;
            } else {
                context = context.getApplicationContext();
            }
        }
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


    private void initProto(@NonNull MethodCall call, @NonNull Result result) {
        result.success(null);
    }

    private void getMaxVideoCallCount(@NonNull MethodCall call, @NonNull Result result) {
        result.success(AVEngineKit.MAX_VIDEO_PARTICIPANT_COUNT);
    }

    private void getMaxAudioCallCount(@NonNull MethodCall call, @NonNull Result result) {
        result.success(AVEngineKit.MAX_AUDIO_PARTICIPANT_COUNT);
    }

    private void seMaxVideoCallCount(@NonNull MethodCall call, @NonNull Result result) {
        AVEngineKit.MAX_VIDEO_PARTICIPANT_COUNT = call.argument("count");
        result.success(null);
    }

    private void seMaxAudioCallCount(@NonNull MethodCall call, @NonNull Result result) {
        AVEngineKit.MAX_AUDIO_PARTICIPANT_COUNT = call.argument("count");
        result.success(null);
    }

    private void addICEServer(@NonNull MethodCall call, @NonNull Result result) {
        String url = call.argument("url");
        String name = call.argument("name");
        String password = call.argument("password");
        AVEngineKit.Instance().addIceServer(url, name, password);
        result.success(null);
    }

    private void startSingleCall(@NonNull MethodCall call, @NonNull Result result) {
        String userId = call.argument("userId");
        boolean audioOnly = call.argument("audioOnly");
        if (gActivity != null) {
            WfcUIKit.singleCall(gActivity, userId, audioOnly);
        } else {
            WfcUIKit.singleCall(gContent, userId, audioOnly);
        }
        result.success(null);
    }

    private void startMultiCall(@NonNull MethodCall call, @NonNull Result result) {
        String groupId = call.argument("groupId");
        List<String> participants = call.argument("participants");
        boolean audioOnly = call.argument("audioOnly");
        if (gActivity != null) {
            WfcUIKit.multiCall(gActivity, groupId, participants, audioOnly);
        } else {
            WfcUIKit.multiCall(gContent, groupId, participants, audioOnly);
        }
        result.success(null);
    }

    private void setupAppServer(@NonNull MethodCall call, @NonNull Result result) {
        String appServerAddress = call.argument("appServerAddress");
        String authToken = call.argument("authToken");
        AppService.APP_SERVER_ADDRESS = appServerAddress;
        String host = HttpUrl.parse(appServerAddress).url().getHost();
        SharedPreferences sp = gContent.getSharedPreferences("WFC_OK_HTTP_COOKIES", Context.MODE_PRIVATE);
        sp.edit()
            .putString("appServer", appServerAddress)
            .putString("authToken:" + host, authToken).apply();
        result.success(null);
    }

    private void showConferenceInfo(@NonNull MethodCall call, @NonNull Result result) {
        String conferenceId = call.argument("conferenceId");
        String password = call.argument("password");
        Intent intent = new Intent(gContent, ConferenceInfoActivity.class);
        intent.putExtra("conferenceId", conferenceId);
        intent.putExtra("password", password);
        gContent.startActivity(intent);
        result.success(null);
    }

    private void showConferencePortal(@NonNull MethodCall call, @NonNull Result result) {
        Intent intent = new Intent(gContent, ConferencePortalActivity.class);
        gContent.startActivity(intent);
        result.success(null);
    }

    private void isSupportMultiCall(@NonNull MethodCall call, @NonNull Result result) {
        result.success(true);
    }

    private void isSupportConference(@NonNull MethodCall call, @NonNull Result result) {
        result.success(AVEngineKit.isSupportConference());
    }

    private void setVideoProfile(@NonNull MethodCall call, @NonNull Result result) {
        int profile = call.argument("profile");
        boolean swapWidthHeight = call.argument("swapWidthHeight");
        AVEngineKit.Instance().setVideoProfile(profile, swapWidthHeight);
        result.success(null);
    }

    private void currentCallSession(@NonNull MethodCall call, @NonNull Result result) {
        AVEngineKit.CallSession callSession = AVEngineKit.Instance().getCurrentSession();
        if (callSession == null) {
            result.success(null);
            return;
        }
        Map<String, Object> obj = new HashMap<>();
        obj.put("callId", callSession.getCallId());
        obj.put("initiator", callSession.getInitiator());
        obj.put("inviter", callSession.getInviter());
        obj.put("state", callSession.getState().ordinal());
        obj.put("startTime", callSession.getStartTime());
        obj.put("connectedTime", callSession.getConnectedTime());
        obj.put("endTime", callSession.getEndTime());
        if (callSession.getConversation() != null) {
            Map<String, Object> convJson = new HashMap<>();
            convJson.put("type", callSession.getConversation().type.getValue());
            convJson.put("target", callSession.getConversation().target);
            convJson.put("line", callSession.getConversation().line);
            obj.put("conversation", convJson);
        }
        obj.put("audioOnly", callSession.isAudioOnly());
        obj.put("endReason", callSession.getEndReason().ordinal());
        obj.put("conference", callSession.isConference());
        obj.put("audience", callSession.isAudience());
        obj.put("advanced", callSession.isAdvanced());
//        obj.put("multiCall", callSession.getParticipantIds().size() > 1);
        result.success(obj);
    }

    private void answerCall(@NonNull MethodCall call, @NonNull Result result) {
        boolean audioOnly = call.argument("audioOnly");
        AVEngineKit.CallSession callSession = AVEngineKit.Instance().getCurrentSession();
        if (callSession != null && callSession.getState() == AVEngineKit.CallState.Incoming) {
            callSession.answerCall(audioOnly);
        }
    }

    private void endCall(@NonNull MethodCall call, @NonNull Result result) {
        String callId = call.argument("callId");
        Log.e(TAG, "endCall " + callId);
        AVEngineKit.CallSession callSession = AVEngineKit.Instance().getCurrentSession();
        if (callSession == null) {
            Log.d(TAG, "endCall session is null");
        } else {
            Log.d(TAG, "endCall session state " + callSession.getCallId() + " " + callSession.getState());
        }
        if (callSession != null && callSession.getState() != AVEngineKit.CallState.Idle && callSession.getCallId().equals(callId)) {
            callSession.endCall();
        }
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        if (channel != null) {
            channel.setMethodCallHandler(null);
            channel = null;
        }
    }

    private void setupWFCDirs(Application application) {
        Config.VIDEO_SAVE_DIR = application.getDir("video", Context.MODE_PRIVATE).getAbsolutePath();
        Config.AUDIO_SAVE_DIR = application.getDir("audio", Context.MODE_PRIVATE).getAbsolutePath();
        Config.PHOTO_SAVE_DIR = application.getDir("photo", Context.MODE_PRIVATE).getAbsolutePath();
        Config.FILE_SAVE_DIR = application.getDir("file", Context.MODE_PRIVATE).getAbsolutePath();
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        gActivity = binding.getActivity();
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        gActivity = null;
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        gActivity = binding.getActivity();
    }

    @Override
    public void onDetachedFromActivity() {

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

    @Override
    public void onReceiveCall(AVEngineKit.CallSession callSession) {
        Map data = new HashMap();
        data.put("callId", callSession.getCallId());
        callback2UI("didReceiveCallCallback", data);
    }

    @Override
    public void shouldStartRing(boolean incoming) {
        Map data = new HashMap();
        data.put("incoming", incoming);
        callback2UI("shouldStartRingCallback", data);
    }

    @Override
    public void shouldSopRing() {
        Map data = new HashMap();
        callback2UI("shouldStopRingCallback", data);
    }

    @Override
    public void didCallEnded(AVEngineKit.CallEndReason callEndReason, int duration) {
        Map data = new HashMap();
        data.put("reason", callEndReason.ordinal());
        callback2UI("didEndCallCallback", data);
    }
}
