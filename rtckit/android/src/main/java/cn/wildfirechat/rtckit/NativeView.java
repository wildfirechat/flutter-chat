package cn.wildfirechat.rtckit;

import android.content.Context;
import android.graphics.Color;
import android.view.View;
import android.widget.FrameLayout;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import io.flutter.plugin.platform.PlatformView;
import java.util.Map;

public class NativeView implements PlatformView {
    @NonNull private final FrameLayout frameLayout;

    NativeView(@NonNull Context context, int id, @Nullable Map<String, Object> creationParams) {
        frameLayout = new FrameLayout(context);
    }

    @NonNull
    @Override
    public View getView() {
        return frameLayout;
    }

    @Override
    public void dispose() {}
}