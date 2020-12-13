package cn.wildfirechat.flutter_imclient_example;

import android.Manifest;

//############ 拷贝区块1开始 ################
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Bundle;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
//############ 拷贝区块1结束 ################

import io.flutter.embedding.android.FlutterActivity;

public class MainActivity extends FlutterActivity {
    //############ 拷贝区块2开始 ################
    private static String[] permissions = {
            android.Manifest.permission.READ_PHONE_STATE,
            Manifest.permission.WRITE_EXTERNAL_STORAGE,
    };
    //############ 拷贝区块2结束 ################

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        //############ 拷贝区块3开始 ################
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            requestPermissions(permissions, 100);
        }
        //############ 拷贝区块3结束 ################
    }

    //############ 拷贝区块4开始 ################
    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);

        for (int grantResult : grantResults) {
            if (grantResult != PackageManager.PERMISSION_GRANTED) {
                Toast.makeText(this, "需要相关权限才能正常使用", Toast.LENGTH_LONG).show();
                finish();
                return;
            }
        }
    }
    //############ 拷贝区块4结束 ################
}
