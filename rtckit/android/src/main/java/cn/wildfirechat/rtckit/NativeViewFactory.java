package cn.wildfirechat.rtckit;

import android.content.Context;
import androidx.annotation.Nullable;
import androidx.annotation.NonNull;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;
import java.util.Map;

class NativeViewFactory extends PlatformViewFactory {
    private Map<Integer, NativeView> videoViews;
    NativeViewFactory(Map<Integer, NativeView> videoViews) {
        super(StandardMessageCodec.INSTANCE);
        this.videoViews = videoViews;
    }

    @NonNull
    @Override
    public PlatformView create(@NonNull Context context, int id, @Nullable Object args) {
        final Map<String, Object> creationParams = (Map<String, Object>) args;
        NativeView nativeView = new NativeView(context, id, creationParams);
        videoViews.put(id, nativeView);
        return nativeView;
    }
}