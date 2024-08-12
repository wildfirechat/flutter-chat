/*
* Copyright (c) 2024 SwanLink (Jiangsu) Technology Development Co., LTD.
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

import {
    AbilityAware,
    AbilityPluginBinding,
    FlutterManager,
    FlutterPlugin,
    FlutterPluginBinding,
    Log,
    MethodCall,
    MethodCallHandler,
    MethodChannel,
    MethodResult
} from '@ohos/flutter_ohos'
import { UIAbility } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { window } from '@kit.ArkUI';
import { initProto, getClientId, connect, getUserInfo, setWfcEventListener, getConversationInfos } from './marsWrapper';
import json from '@ohos.util.json';
import map from '@hms.core.map.map';

const TAG: string = "FlutterQrReaderPlugin";
const CHANNEL_NAME: string = "imclient";
const CHANNEL_VIEW_NAME: string = "me.hetian.flutter_qr_reader.reader_view";

export default class ImclientPlugin implements FlutterPlugin, MethodCallHandler, AbilityAware {
    private channel: MethodChannel | null = null
    private flutterPluginBinding: FlutterPluginBinding | null = null
    private ability: UIAbility | null = null
    private mainWindow: window.Window | null = null;

    getUniqueClassName(): string {
        return TAG
    }

    onAttachedToEngine(binding: FlutterPluginBinding) {
        this.channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL_NAME)
        this.channel?.setMethodCallHandler(this)
        this.flutterPluginBinding = binding
        initProto()
        setWfcEventListener((value: object) => {
            let args = (value as Record<string, Object>)['args'] as Object[]
            let event = args[0] as string
            switch (event) {
                case 'onConnectionStatusChange':
                    this._callback2UI('onConnectionStatusChanged', args[1])
                    break
                default:
                    console.log('unknown event', event, args)
                    break
            }
        })
        // binding.getPlatformViewRegistry()
        //     .registerViewFactory(CHANNEL_VIEW_NAME, new QrReaderFactory(binding.getBinaryMessenger()))
    }

    onDetachedFromEngine(binding: FlutterPluginBinding) {
        this.channel?.setMethodCallHandler(null)
        this.channel = null
    }

    onDetachedFromAbility(): void {
        this.ability = null
        this.offWindowEvent()
    }

    onAttachedToAbility(binding: AbilityPluginBinding): void {
        this.ability = binding.getAbility()
        // this.onWindowEvent(this.ability?.context)
    }

    onWindowEvent(context: Context) {
        // try {
        //     this.mainWindow = FlutterManager.getInstance()
        //         .getWindowStage(FlutterManager.getInstance().getUIAbility(context))
        //         .getMainWindowSync();
        //     this.mainWindow?.on('windowEvent', (data: window.WindowEventType) => {
        //         if (data === window.WindowEventType.WINDOW_SHOWN) {
        //             AppStorage.setOrCreate(CameraConstants.CUSTOM_SCAN_PAGE_IS_BACKGROUND_NAME, false)
        //         } else if (data === window.WindowEventType.WINDOW_HIDDEN) {
        //             AppStorage.setOrCreate(CameraConstants.CUSTOM_SCAN_PAGE_IS_BACKGROUND_NAME, true)
        //         }
        //     });
        // } catch (exception) {
        //     Log.e(TAG, 'Failed to register callback. Cause: ' + JSON.stringify(exception));
        // }
    }

    offWindowEvent() {
        try {
            this.mainWindow?.off('windowEvent');
        } catch (exception) {
            Log.e(TAG, 'Failed to register callback. Cause: ' + JSON.stringify(exception));
        }
    }

    onMethodCall(call: MethodCall, result: MethodResult) {
        try {
            let fn = this.methods[call.method]
            fn?.(call, result)
        } catch (err) {
            Log.e(TAG, 'onMethodCall failed: ' + err);
            // result.error("IMClientPlugin", "onMethodCall failed with err", err);
        }
    }

    _initProto(call: MethodCall, result: MethodResult) {
        // do nothing
    }

    _getClientId(call: MethodCall, result: MethodResult) {
        let clientId: string = getClientId()
        result.success(clientId)
    }

    _connect(call: MethodCall, result: MethodResult) {
        let token: string = call.argument("token");
        let userId: string = call.argument("userId");
        connect('', userId, token)
        // TODO
        let lastConnectTime = 0
        result.success(lastConnectTime)
    }

    _getUserInfo(call: MethodCall, result: MethodResult) {
        let userId: string = call.argument("userId");
        let refresh: boolean = call.argument("refresh");
        let groupId: string = call.argument("groupId");
        let userInfo = getUserInfo(userId, refresh, groupId)
        // TODO
        // FIXME
        // dart 层要求的是 Map，这儿传 Object，不确定是否可以
        // const objToMap = (o) => new Map(Object.entries(o));
        //Object.fromEntries(map.entries())
        result.success(userInfo ? json.parse(userInfo) : null);
    }

    _registerMessage() {
        // TODO
    }

    _getConversationInfos(call: MethodCall, result: MethodResult) {
        let lines = call.argument('lines') as number[]
        let types = call.argument('types') as number[]
        let convsStr = getConversationInfos(types, lines)
        // TODO
        // FIXME
        // string[]
        result.success(convsStr)
    }

    _callback2UI(method: string, args: object) {
        this.channel?.invokeMethod(method, args)
    }

    methods: Record<string, Function> = {
        "initProto": this._initProto,
        "getClientId": this._getClientId,
        "connect": this._connect,
        "getUserInfo": this._getUserInfo,
        "getConversationInfos": this._getConversationInfos,
    }
}