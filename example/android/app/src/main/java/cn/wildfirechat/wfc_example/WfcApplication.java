package cn.wildfirechat.wfc_example;

import android.app.Application;
import android.content.Context;
import android.os.Build;
import android.os.StrictMode;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.multidex.MultiDex;

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.FlutterEngineCache;
import io.flutter.embedding.engine.dart.DartExecutor;
import io.flutter.view.FlutterMain;
import io.flutter.plugins.GeneratedPluginRegistrant;

public class WfcApplication extends Application {
    private static final String TAG = "WfcApplication";
    private static WfcApplication instance;
    private FlutterEngine flutterEngine;
    public static final String FLUTTER_ENGINE_ID = "wfc_flutter_engine";

    public static WfcApplication getInstance() {
        return instance;
    }

    @Override
    public void onCreate() {
        super.onCreate();
        instance = this;

        // 解决Android 9及以上的网络请求问题
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            StrictMode.VmPolicy.Builder builder = new StrictMode.VmPolicy.Builder();
            StrictMode.setVmPolicy(builder.build());
            builder.detectAll();
        }

        // 设置全局异常处理
        setupExceptionHandler();

        // 预初始化 FlutterEngine 以提高启动性能
        initFlutterEngine();
    }

    private void initFlutterEngine() {
        try {
            // 预热FlutterEngine以加快第一次渲染
            Log.i(TAG, "Initializing Flutter engine");
            FlutterMain.startInitialization(this);
            FlutterMain.ensureInitializationComplete(this, null);

            // 创建和缓存FlutterEngine，并配置更多优化选项
            flutterEngine = new FlutterEngine(this);

            // 配置渲染模式为Surface（对于UI交互更重要）
//            flutterEngine.getRenderer().setSemanticsEnabled(true);

            // 启动Dart执行
            flutterEngine.getDartExecutor().executeDartEntrypoint(
                    DartExecutor.DartEntrypoint.createDefault()
            );

            // 预先加载一些资源
            flutterEngine.getPlatformViewsController().getRegistry();

            // 缓存引擎
            FlutterEngineCache.getInstance().put(FLUTTER_ENGINE_ID, flutterEngine);
            Log.i(TAG, "Flutter engine initialized successfully");
        } catch (Exception e) {
            Log.e(TAG, "Error initializing Flutter engine", e);
        }
    }

    private void setupExceptionHandler() {
        // 设置未捕获异常处理器
        Thread.setDefaultUncaughtExceptionHandler(new Thread.UncaughtExceptionHandler() {
            @Override
            public void uncaughtException(@NonNull Thread thread, @NonNull Throwable throwable) {
                Log.e(TAG, "Uncaught exception", throwable);
                // 在实际应用中，你可能想把错误报告发送到服务器
            }
        });
    }

    @Override
    protected void attachBaseContext(Context base) {
        super.attachBaseContext(base);
        // 启用multidex支持
        MultiDex.install(this);
    }
}
