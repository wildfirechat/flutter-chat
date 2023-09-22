package cn.wildfirechat.rtckit;

import android.app.Activity;
import android.app.Application;
import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.List;

import cn.wildfire.chat.kit.Config;
import cn.wildfirechat.avenginekit.AVEngineKit;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

import cn.wildfire.chat.kit.WfcUIKit;

/**
 * RtckitPlugin
 */
public class RtckitPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private static MethodChannel channel;
    private static Context gContent;
    private static Activity gActivity;

    private static boolean isWfcUIKitInitialized = false;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "rtckit");
        channel.setMethodCallHandler(this);
        gContent = flutterPluginBinding.getApplicationContext();
        if (isWfcUIKitInitialized) {
            return;
        }
        isWfcUIKitInitialized = true;
        Log.e("RtckitPlugin", "isSupportMoment " + WfcUIKit.getWfcUIKit().isSupportMoment());
        Context context = gContent;
        while (context != null) {
            if (context instanceof Application) {
                Application application = (Application) context;
                Config.ICE_SERVERS = null;
                WfcUIKit.getWfcUIKit().init(application);
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

    }

    private void addICEServer(@NonNull MethodCall call, @NonNull Result result) {
        String url = call.argument("url");
        String name = call.argument("name");
        String password = call.argument("password");
        AVEngineKit.Instance().addIceServer(url, name, password);
    }

    private void startSingleCall(@NonNull MethodCall call, @NonNull Result result) {
        String userId = call.argument("userId");
        boolean audioOnly = call.argument("audioOnly");
        if (gActivity != null) {
            WfcUIKit.singleCall(gActivity, userId, audioOnly);
        } else {
            WfcUIKit.singleCall(gContent, userId, audioOnly);
        }
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
    }


    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
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
}
