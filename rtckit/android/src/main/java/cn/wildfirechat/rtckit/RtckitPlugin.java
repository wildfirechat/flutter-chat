package cn.wildfirechat.rtckit;

import android.app.Activity;
import android.app.Application;
import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.text.TextUtils;
import android.util.Log;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import org.webrtc.Logging;
import org.webrtc.RendererCommon;
import org.webrtc.StatsReport;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CountDownLatch;

import cn.wildfirechat.avenginekit.AVAudioManager;
import cn.wildfirechat.avenginekit.AVEngineKit;
import cn.wildfirechat.model.Conversation;
import cn.wildfirechat.remote.ChatManager;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

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

    public static Map<String, CallSessionDelegator> delegators = new HashMap<>();
    public static Map<Integer, NativeView> videoViews = new HashMap<>();

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

        isWfcUIKitInitialized = true;
        gContent = flutterPluginBinding.getApplicationContext();
        Context context = gContent;
        while (context != null) {
            if (context instanceof Application) {
                Application application = (Application) context;
                AVEngineKit.init(application, this);
                AVEngineKit.Instance().setVideoProfile(30, false);
                AVEngineKit.SCREEN_SHARING_REPLACE_MODE = true;
                break;
            } else {
                context = context.getApplicationContext();
            }
        }

        flutterPluginBinding
                .getPlatformViewRegistry()
                .registerViewFactory("<platform-view-type>", new NativeViewFactory(videoViews));
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
        Conversation conversation = new Conversation(Conversation.ConversationType.Single, userId);

        CallSessionDelegator callSessionDelegator = new CallSessionDelegator(null);
        AVEngineKit.CallSession callSession = AVEngineKit.Instance().startCall(conversation, Arrays.asList(userId), audioOnly, callSessionDelegator);
        if(callSession != null) {
            callSessionDelegator.callSession = callSession;
            delegators.put(callSession.getCallId(), callSessionDelegator);
        }
        result.success(callSession2Map(callSession));
    }

    private void startMultiCall(@NonNull MethodCall call, @NonNull Result result) {
        String groupId = call.argument("groupId");
        List<String> participants = call.argument("participants");
        boolean audioOnly = call.argument("audioOnly");
        Conversation conversation = new Conversation(Conversation.ConversationType.Group, groupId);

        CallSessionDelegator callSessionDelegator = new CallSessionDelegator(null);
        AVEngineKit.CallSession callSession = AVEngineKit.Instance().startCall(conversation, participants, audioOnly, callSessionDelegator);
        if(callSession != null) {
            callSessionDelegator.callSession = callSession;
            delegators.put(callSession.getCallId(), callSessionDelegator);
        }
        result.success(callSession2Map(callSession));
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
        result.success(callSession2Map(callSession));
    }

    private boolean isMainThread() {
        return Looper.myLooper() == Looper.getMainLooper();
    }
    private Map<String, Object> callSession2Map(AVEngineKit.CallSession callSession) {
        if (callSession == null) {
            return null;
        }
        Map<String, Object> obj = new HashMap<>();
        obj.put("callId", callSession.getCallId());
        if(!TextUtils.isEmpty(callSession.getInitiator())) {
            obj.put("initiator", callSession.getInitiator());
        }
        if(!TextUtils.isEmpty(callSession.getInviter())) {
            obj.put("inviter", callSession.getInviter());
        }
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

        if(callSession.getState() == AVEngineKit.CallState.Connected && AVEngineKit.Instance().getAVAudioManager() != null) {
            final boolean[] speaker = {false};
            if(isMainThread()) {
                speaker[0] = AVEngineKit.Instance().getAVAudioManager().getSelectedAudioDevice() == AVAudioManager.AudioDevice.SPEAKER_PHONE;
            } else {
                CountDownLatch countDownLatch = new CountDownLatch(1);
                ChatManager.Instance().getMainHandler().post(() -> {
                    speaker[0] = AVEngineKit.Instance().getAVAudioManager().getSelectedAudioDevice() == AVAudioManager.AudioDevice.SPEAKER_PHONE;
                    countDownLatch.countDown();
                });
                try {
                    countDownLatch.await();
                } catch (InterruptedException e) {}
            }
            obj.put("speaker", speaker[0]);
        } else {
            obj.put("speaker", !callSession.isAudioOnly());
        }
        obj.put("videoMuted", callSession.videoMuted);
        obj.put("audioMuted", callSession.audioMuted);
        obj.put("conference", callSession.isConference());
        obj.put("audience", callSession.isAudience());
        obj.put("advanced", callSession.isAdvanced());
        obj.put("multiCall", callSession.getParticipantIds().size() > 1);
        return obj;
    }

    private void setLocalVideoView(@NonNull MethodCall call, @NonNull Result result) {
        String callId = call.argument("callId");
        int viewId = call.argument("viewId");
        NativeView view = videoViews.get(viewId);
        if(view != null) {
            View container = view.getView();
            if(container instanceof FrameLayout) {
                FrameLayout layout = (FrameLayout) container;
                AVEngineKit.Instance().getCurrentSession().setupLocalVideoView(layout, RendererCommon.ScalingType.SCALE_ASPECT_FIT);
            }
        }
    }
    private void setRemoteVideoView(@NonNull MethodCall call, @NonNull Result result) {
        String callId = call.argument("callId");
        String userId = call.argument("userId");
        boolean screenSharing = call.argument("screenSharing");
        int viewId = call.argument("viewId");
        NativeView view = videoViews.get(viewId);
        if(view != null) {
            View container = view.getView();
            if(container instanceof FrameLayout) {
                FrameLayout layout = (FrameLayout) container;
                AVEngineKit.Instance().getCurrentSession().setupRemoteVideoView(userId, screenSharing, layout, RendererCommon.ScalingType.SCALE_ASPECT_FIT);
            }
        }
    }

    private void startPreview(@NonNull MethodCall call, @NonNull Result result) {
        String callId = call.argument("callId");
        AVEngineKit.Instance().getCurrentSession().startPreview();
        result.success(null);
    }

    private void answerCall(@NonNull MethodCall call, @NonNull Result result) {
        String callId = call.argument("callId");
        boolean audioOnly = call.argument("audioOnly");
        AVEngineKit.CallSession callSession = AVEngineKit.Instance().getCurrentSession();
        if (callSession != null && callSession.getState() == AVEngineKit.CallState.Incoming) {
            callSession.answerCall(audioOnly);
        }
        result.success(null);
    }

    private void changeToAudioOnly(@NonNull MethodCall call, @NonNull Result result) {
        String callId = call.argument("callId");
        AVEngineKit.CallSession callSession = AVEngineKit.Instance().getCurrentSession();
        if (callSession != null && callSession.getState() == AVEngineKit.CallState.Connected) {
            callSession.setAudioOnly(true);
        }
        result.success(null);
    }

    private void endCall(@NonNull MethodCall call, @NonNull Result result) {
        String callId = call.argument("callId");
        AVEngineKit.CallSession callSession = AVEngineKit.Instance().getCurrentSession();
        if (callSession == null) {
            Log.d(TAG, "endCall session is null");
        } else {
            Log.d(TAG, "endCall session state " + callSession.getCallId() + " " + callSession.getState());
        }
        if (callSession != null && callSession.getState() != AVEngineKit.CallState.Idle && callSession.getCallId().equals(callId)) {
            callSession.endCall();
        }
        result.success(null);
    }

    private void muteAudio(@NonNull MethodCall call, @NonNull Result result) {
        String callId = call.argument("callId");
        boolean muted = call.argument("muted");
        AVEngineKit.Instance().getCurrentSession().muteAudio(muted);
        result.success(null);
    }

    private void enableSpeaker(@NonNull MethodCall call, @NonNull Result result) {
        String callId = call.argument("callId");
        boolean speaker = call.argument("speaker");
        AVAudioManager audioManager = AVEngineKit.Instance().getAVAudioManager();
        AVAudioManager.AudioDevice currentAudioDevice = audioManager.getSelectedAudioDevice();
        if(currentAudioDevice != AVAudioManager.AudioDevice.WIRED_HEADSET && currentAudioDevice != AVAudioManager.AudioDevice.BLUETOOTH){
            audioManager.selectAudioDevice(speaker?AVAudioManager.AudioDevice.SPEAKER_PHONE:AVAudioManager.AudioDevice.EARPIECE);
        }
        result.success(null);
    }

    private void muteVideo(@NonNull MethodCall call, @NonNull Result result) {
        String callId = call.argument("callId");
        boolean muted = call.argument("muted");
        AVEngineKit.Instance().getCurrentSession().muteVideo(muted);
        result.success(null);
    }

    private void switchCamera(@NonNull MethodCall call, @NonNull Result result) {
        String callId = call.argument("callId");
        AVEngineKit.Instance().getCurrentSession().switchCamera();
        result.success(null);
    }

    private void getCameraPosition(@NonNull MethodCall call, @NonNull Result result) {
        String callId = call.argument("callId");
        //Todo
        result.success(0);
    }

    private void isBluetoothSpeaker(@NonNull MethodCall call, @NonNull Result result) {
        String callId = call.argument("callId");
        AVAudioManager audioManager = AVEngineKit.Instance().getAVAudioManager();
        AVAudioManager.AudioDevice currentAudioDevice = audioManager.getSelectedAudioDevice();
        result.success(currentAudioDevice == AVAudioManager.AudioDevice.BLUETOOTH);
    }

    private void isHeadsetPluggedIn(@NonNull MethodCall call, @NonNull Result result) {
        String callId = call.argument("callId");
        AVAudioManager audioManager = AVEngineKit.Instance().getAVAudioManager();
        AVAudioManager.AudioDevice currentAudioDevice = audioManager.getSelectedAudioDevice();
        result.success(currentAudioDevice == AVAudioManager.AudioDevice.WIRED_HEADSET);
    }

    private void getParticipantIds(@NonNull MethodCall call, @NonNull Result result) {
        String callId = call.argument("callId");
        result.success(AVEngineKit.Instance().getCurrentSession().getParticipantIds());
    }

    private void getParticipantProfiles(@NonNull MethodCall call, @NonNull Result result) {
        String callId = call.argument("callId");
        List<Map<String, Object>> list = new ArrayList<>();
        if(AVEngineKit.Instance().getCurrentSession() != null) {
            if (AVEngineKit.Instance().getCurrentSession().getParticipantProfiles() != null) {
                for (AVEngineKit.ParticipantProfile participantProfile : AVEngineKit.Instance().getCurrentSession().getParticipantProfiles()) {
                    list.add(profile2Dict(participantProfile));
                }
            }
        }
        result.success(list);
    }

    private void getAllProfiles(@NonNull MethodCall call, @NonNull Result result) {
        String callId = call.argument("callId");
        List<Map<String, Object>> list = new ArrayList<>();

        if(AVEngineKit.Instance().getCurrentSession() != null) {
            list.add(profile2Dict(AVEngineKit.Instance().getCurrentSession().getMyProfile()));
            if (AVEngineKit.Instance().getCurrentSession().getParticipantProfiles() != null) {
                for (AVEngineKit.ParticipantProfile participantProfile : AVEngineKit.Instance().getCurrentSession().getParticipantProfiles()) {
                    list.add(profile2Dict(participantProfile));
                }
            }
        }
        result.success(list);
    }

    private void getMyProfiles(@NonNull MethodCall call, @NonNull Result result) {
        String callId = call.argument("callId");

        if(AVEngineKit.Instance().getCurrentSession() != null) {
            result.success(profile2Dict(AVEngineKit.Instance().getCurrentSession().getMyProfile()));
        }
        result.success(null);
    }

    private void inviteNewParticipants(@NonNull MethodCall call, @NonNull Result result) {
        String callId = call.argument("callId");
        List<String> participants = call.argument("participants");

        if(AVEngineKit.Instance().getCurrentSession() != null) {
            AVEngineKit.Instance().getCurrentSession().inviteNewParticipants(participants);
        }
        result.success(null);
    }

    private Map<String, Object> profile2Dict(AVEngineKit.ParticipantProfile profile) {
        Map<String, Object> dict = new HashMap<>();
        
        dict.put("userId", profile.getUserId());
        dict.put("startTime", profile.getStartTime());
        dict.put("state", profile.getState().ordinal());
        dict.put("videoMuted", profile.isVideoMuted());
        dict.put("audioMuted", profile.isAudioMuted());
        dict.put("audience", profile.isAudience());
        dict.put("screenSharing", profile.isScreenSharing());
        dict.put("callExtra", "");
        return dict;
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        if (channel != null) {
            channel.setMethodCallHandler(null);
            channel = null;
        }
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
        CallSessionDelegator delegator = new CallSessionDelegator(callSession);
        callSession.setCallback(delegator);
        delegators.put(callSession.getCallId(), delegator);

        Map data = new HashMap();
        data.put("callSession", callSession2Map(callSession));
        callback2UI("didReceiveCallCallback", data);
    }

    @Override
    public void shouldStartRing(boolean incoming) {
        Map data = new HashMap();
        data.put("incoming", incoming);
        callback2UI("shouldStartRingCallback", data);
    }

    @Override
    public void shouldStopRing() {
        Map data = new HashMap();
        callback2UI("shouldStopRingCallback", data);
    }

    @Override
    public void didCallEnded(AVEngineKit.CallEndReason callEndReason, int duration) {
        Map data = new HashMap();
        data.put("reason", callEndReason.ordinal());
        callback2UI("didEndCallCallback", data);
    }

    private class CallSessionDelegator implements AVEngineKit.CallSessionCallback {
        public AVEngineKit.CallSession callSession;

        private class CallbackBuilder {
            String event;
            Map data = new HashMap();
            CallbackBuilder(String event) {
                this.event = event;
                data.put("callId", callSession.getCallId());
                data.put("session", callSession2Map(callSession));
            }
            CallbackBuilder put(String key, Object value) {
                data.put(key, value);
                return this;
            }

            void callback() {
                RtckitPlugin.callback2UI(event, data);
            }
        }

        public CallSessionDelegator(AVEngineKit.CallSession callSession) {
            this.callSession = callSession;
        }

        @Override
        public void didCallEndWithReason(AVEngineKit.CallEndReason callEndReason) {
            if(callSession == null)
                return;
            RtckitPlugin.delegators.remove(callSession.getCallId());
            new CallbackBuilder("didCallEndWithReason").put("reason", callEndReason.ordinal()).callback();
        }

        @Override
        public void didChangeState(AVEngineKit.CallState callState) {
            if(callSession == null)
                return;
            new CallbackBuilder("didChangeState").put("state", callState.ordinal()).callback();
        }

        @Override
        public void didParticipantJoined(String s, boolean b) {
            if(callSession == null)
                return;
            new CallbackBuilder("didParticipantJoined").put("userId", s).put("screenSharing", b).callback();
        }

        @Override
        public void didParticipantConnected(String s, boolean b) {
            if(callSession == null)
                return;
            new CallbackBuilder("didParticipantConnected").put("userId", s).put("screenSharing", b).callback();
        }

        @Override
        public void didParticipantLeft(String s, AVEngineKit.CallEndReason callEndReason, boolean b) {
            if(callSession == null)
                return;
            new CallbackBuilder("didParticipantLeft").put("userId", s).put("screenSharing", b).put("reason", callEndReason.ordinal()).callback();
        }

        @Override
        public void didChangeMode(boolean b) {
            if(callSession == null)
                return;
            new CallbackBuilder("didChangeMode").put("isAudioOnly", b).callback();
        }

        @Override
        public void didChangeInitiator(String s) {
            if(callSession == null)
                return;
            new CallbackBuilder("didChangeInitiator").callback();
        }

        @Override
        public void didCreateLocalVideoTrack() {
            if(callSession == null)
                return;
            new CallbackBuilder("didCreateLocalVideoTrack").callback();
        }

        @Override
        public void didReceiveRemoteVideoTrack(String s, boolean b) {
            if(callSession == null)
                return;
            new CallbackBuilder("didReceiveRemoteVideoTrack").put("userId", s).put("screenSharing", b).callback();
        }

        @Override
        public void didRemoveRemoteVideoTrack(String s) {
            if(callSession == null)
                return;
//            Map data = new HashMap();
//            data.put("callId", callSession.getCallId());
//            data.put("reason", callEndReason.ordinal());
//            RtckitPlugin.callback2UI("didRemoveRemoteVideoTrack", data);
        }

        @Override
        public void didError(String s) {
            if(callSession == null)
                return;
            new CallbackBuilder("didError").put("error", s).callback();
        }

        @Override
        public void didGetStats(StatsReport[] statsReports) {
            if(callSession == null)
                return;
//            Map data = new HashMap();
//            data.put("callId", callSession.getCallId());
//            data.put("reason", callEndReason.ordinal());
//            RtckitPlugin.callback2UI("didGetStats", data);
        }

        @Override
        public void didVideoMuted(String s, boolean b) {
            if(callSession == null)
                return;
            new CallbackBuilder("didVideoMuted").put("userId", s).put("screenSharing", b).callback();
        }

        @Override
        public void didReportAudioVolume(String s, int i) {
            if(callSession == null)
                return;
            new CallbackBuilder("didReportAudioVolume").put("userId", s).put("volume", i).callback();
        }

        @Override
        public void didAudioDeviceChanged(AVAudioManager.AudioDevice audioDevice) {
            if(callSession == null)
                return;
            new CallbackBuilder("didAudioDeviceChanged").callback();
        }

        @Override
        public void didChangeType(String s, boolean b, boolean b1) {
            if(callSession == null)
                return;
            new CallbackBuilder("didChangeType").put("userId", s).put("screenSharing", b1).put("audience", b).callback();
        }

        @Override
        public void didMuteStateChanged(List<String> list) {
            if(callSession == null)
                return;
            new CallbackBuilder("didMuteStateChanged").put("userIds", list).callback();
        }

        @Override
        public void didMediaLostPacket(String s, int i, boolean b) {
            if(callSession == null)
                return;
            new CallbackBuilder("didMediaLost").put("media", s).put("screenSharing", b).put("lostPackage", i).callback();
        }

        @Override
        public void didMediaLostPacket(String s, String s1, int i, boolean b, boolean b1) {
            if(callSession == null)
                return;
            new CallbackBuilder("didRemoteMediaLost").put("userId", s).put("media", s1).put("lostPackage", i).put("screenSharing", b1).put("uplink", b).callback();
        }
    }
}
