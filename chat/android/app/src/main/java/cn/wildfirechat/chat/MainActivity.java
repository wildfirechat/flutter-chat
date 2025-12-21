package cn.wildfirechat.chat;

import android.content.Context;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.KeyEvent;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import io.flutter.embedding.android.FlutterActivity;

public class MainActivity extends FlutterActivity {
    private static final String TAG = "MainActivity";
    private boolean doubleBackToExitPressedOnce = false;

    @Override
    public String getCachedEngineId() {
        // Return the ID of the pre-warmed FlutterEngine
        return WfcApplication.FLUTTER_ENGINE_ID;
    }

    @Override
    public boolean shouldDestroyEngineWithHost() {
        // Do not destroy the pre-warmed FlutterEngine when the activity is destroyed
        return false;
    }
}
