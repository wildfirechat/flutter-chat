/*
 * Copyright (c) 2020 WildFireChat. All rights reserved.
 */

package cn.wildfirechat.push.honor;

import android.util.Log;

import com.hihonor.push.sdk.HonorMessageService;
import com.hihonor.push.sdk.HonorPushDataMsg;

import cn.wildfirechat.push.PushService;
import cn.wildfirechat.remote.ChatManager;

public class HonorPushService extends HonorMessageService {
    private static final String TAG = "PushService";

    @Override
    public void onNewToken(String s) {
        super.onNewToken(s);
        Log.d(TAG, "honor onNewToken: " + s);
        // 荣耀通道号是 9，不是华为的 2。上报错了推送服务端会拿荣耀 token 去走 HMS 通道，必然失败。
        ChatManager.Instance().setDeviceToken(s, PushService.PushServiceType.Honor);
    }

    @Override
    public void onMessageReceived(HonorPushDataMsg honorPushDataMsg) {
        super.onMessageReceived(honorPushDataMsg);
        // do nothing
    }
}
