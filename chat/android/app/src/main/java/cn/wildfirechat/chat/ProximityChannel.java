package cn.wildfirechat.chat;

import android.content.Context;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.os.PowerManager;
import android.util.Log;

import androidx.annotation.NonNull;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * 播放语音消息期间的距离传感器，参考 android-chat 的 AudioPlayManager。
 * <p>
 * 贴近时的息屏交给系统：PROXIMITY_SCREEN_OFF_WAKE_LOCK 这把锁持有期间，系统自己会在
 * 贴近时息屏、离开时亮屏，不需要我们跟着传感器事件手动开关屏幕。传感器事件只用来告诉
 * Flutter 侧远近变化，由它决定切听筒还是扬声器。
 */
public class ProximityChannel implements SensorEventListener {
    private static final String TAG = "ProximityChannel";
    private static final String CHANNEL_NAME = "chat.wildfire/proximity";
    // 兜底超时，防止 Flutter 侧没来得及 stop 时把锁一直持有
    private static final long WAKE_LOCK_TIMEOUT_MS = 10 * 60 * 1000L;

    private final MethodChannel channel;
    private final SensorManager sensorManager;
    private final Sensor proximitySensor;
    private final PowerManager powerManager;

    private PowerManager.WakeLock wakeLock;
    private boolean monitoring;
    private Boolean lastNear;

    public ProximityChannel(Context context, BinaryMessenger messenger) {
        Context appContext = context.getApplicationContext();
        this.channel = new MethodChannel(messenger, CHANNEL_NAME);
        this.sensorManager = (SensorManager) appContext.getSystemService(Context.SENSOR_SERVICE);
        this.proximitySensor = sensorManager == null
            ? null
            : sensorManager.getDefaultSensor(Sensor.TYPE_PROXIMITY);
        this.powerManager = (PowerManager) appContext.getSystemService(Context.POWER_SERVICE);
        this.channel.setMethodCallHandler(this::onMethodCall);
    }

    private void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case "start":
                result.success(start());
                break;
            case "stop":
                stop();
                result.success(null);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    /**
     * @return 是否真的开始监听。没有距离传感器(部分平板)时返回 false，Flutter 侧据此不做自动切换。
     */
    private boolean start() {
        if (monitoring) {
            return true;
        }
        if (sensorManager == null || proximitySensor == null) {
            return false;
        }
        monitoring = true;
        lastNear = null;
        sensorManager.registerListener(this, proximitySensor, SensorManager.SENSOR_DELAY_NORMAL);
        acquireProximityWakeLock();
        return true;
    }

    private void stop() {
        if (!monitoring) {
            return;
        }
        monitoring = false;
        lastNear = null;
        if (sensorManager != null) {
            sensorManager.unregisterListener(this);
        }
        releaseProximityWakeLock();
    }

    private void acquireProximityWakeLock() {
        if (powerManager == null
            || !powerManager.isWakeLockLevelSupported(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK)) {
            return;
        }
        try {
            if (wakeLock == null) {
                wakeLock = powerManager.newWakeLock(
                    PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK, "wfc:VoiceMessagePlay");
                wakeLock.setReferenceCounted(false);
            }
            if (!wakeLock.isHeld()) {
                wakeLock.acquire(WAKE_LOCK_TIMEOUT_MS);
            }
        } catch (Exception e) {
            Log.e(TAG, "acquire proximity wake lock failed", e);
        }
    }

    private void releaseProximityWakeLock() {
        if (wakeLock == null) {
            return;
        }
        try {
            if (wakeLock.isHeld()) {
                wakeLock.release();
            }
        } catch (Exception e) {
            Log.e(TAG, "release proximity wake lock failed", e);
        }
    }

    @Override
    public void onSensorChanged(SensorEvent event) {
        if (!monitoring || proximitySensor == null) {
            return;
        }
        // 距离传感器多为二值(0/最大量程)，小于量程即视为贴近；量程很大的设备按 5cm 截断
        float threshold = Math.min(proximitySensor.getMaximumRange(), 5.0f);
        boolean near = event.values[0] < threshold;
        if (lastNear != null && lastNear == near) {
            return;
        }
        lastNear = near;
        channel.invokeMethod("onProximityChanged", near);
    }

    @Override
    public void onAccuracyChanged(Sensor sensor, int accuracy) {
    }
}
