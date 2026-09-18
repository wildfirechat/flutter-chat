package cn.wildfirechat.chat;

import android.content.Context;
import android.media.AudioDeviceInfo;
import android.media.AudioManager;
import android.os.Build;
import android.util.Log;

import androidx.annotation.NonNull;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * 当前音频输出设备的查询，目前只用于播放语音消息，参考 android-chat 的 AudioPlayModeUtils。
 * <p>
 * 只做一次性查询，不监听热插拔：语音消息通常只有几秒，播放中途插拔耳机的收益不值得再引入
 * AudioDeviceCallback 的生命周期管理。
 */
public class AudioOutputChannel {
    private static final String TAG = "AudioOutputChannel";
    private static final String CHANNEL_NAME = "chat.wildfire/audio_output";

    private final AudioManager audioManager;

    public AudioOutputChannel(Context context, BinaryMessenger messenger) {
        Context appContext = context.getApplicationContext();
        this.audioManager = (AudioManager) appContext.getSystemService(Context.AUDIO_SERVICE);
        new MethodChannel(messenger, CHANNEL_NAME).setMethodCallHandler(this::onMethodCall);
    }

    private void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        if ("isHeadsetOn".equals(call.method)) {
            result.success(isHeadsetOn());
        } else {
            result.notImplemented();
        }
    }

    private boolean isHeadsetOn() {
        if (audioManager == null) {
            return false;
        }
        try {
            for (AudioDeviceInfo device : audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)) {
                if (isHeadsetType(device.getType())) {
                    return true;
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "query audio output devices failed", e);
        }
        return false;
    }

    /**
     * 声音会直接进耳朵的输出设备。外放音箱(TYPE_BLUETOOTH_A2DP 之外的 USB/HDMI 等)不算，
     * 判断错了只是多提示一句「请贴近手机聆听」，不影响出声。
     */
    private static boolean isHeadsetType(int type) {
        if (type == AudioDeviceInfo.TYPE_WIRED_HEADSET
            || type == AudioDeviceInfo.TYPE_WIRED_HEADPHONES
            || type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP
            || type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO) {
            return true;
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
            && type == AudioDeviceInfo.TYPE_USB_HEADSET) {
            return true;
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P
            && type == AudioDeviceInfo.TYPE_HEARING_AID) {
            return true;
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
            && type == AudioDeviceInfo.TYPE_BLE_HEADSET) {
            return true;
        }
        return false;
    }
}
