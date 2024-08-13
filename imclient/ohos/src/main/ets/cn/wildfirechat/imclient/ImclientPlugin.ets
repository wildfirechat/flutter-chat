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
    MethodResult,
} from '@ohos/flutter_ohos'
import { UIAbility } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { window } from '@kit.ArkUI';
import {
    initProto,
    getClientId,
    connect,
    getUserInfo,
    getUserInfos,
    setWfcEventListener,
    getConversationInfos,
    registerMessageFlag,
    getGroupInfo,
    getMyFriendList,
    getUnreadFriendRequestStatus,
    getMessagesV2,
    getConversationInfo,
    getIncommingFriendRequest,
    sendMessage,
    clearUnreadStatus,
    setConversationDraft,
    isMyFriend,
    getFavGroups,
    getGroupMembersByCount,
    createGroup,
    getUserSetting,
    getGroupMember,
    getGroupMembers,
    addMembers,
    kickoffMembers,
    clearMessages,
    isSupportBigFilesUpload,
    getMessageByUid,
    recall
} from './marsWrapper';
import json from '@ohos.util.json';
import map from '@hms.core.map.map';
import util from '@ohos.util';

const TAG: string = "IMClientPlugin";
const CHANNEL_NAME: string = "imclient";
const CHANNEL_VIEW_NAME: string = "me.hetian.flutter_qr_reader.reader_view";

export default class ImclientPlugin implements FlutterPlugin, MethodCallHandler, AbilityAware {
    private channel: MethodChannel | null = null
    private flutterPluginBinding: FlutterPluginBinding | null = null
    private ability: UIAbility | null = null
    private mainWindow: window.Window | null = null;
    private base64Helper = new util.Base64Helper()
    private userId: string = ''

    getUniqueClassName(): string {
        return TAG
    }

    onAttachedToEngine(binding: FlutterPluginBinding) {
        this.channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL_NAME)
        this.channel?.setMethodCallHandler(this)
        this.flutterPluginBinding = binding
        initProto(binding.getApplicationContext().filesDir)
        setWfcEventListener((value: object) => {
            let args = (value as Record<string, Object>)['args'] as Object[]
            let event = args[0] as string
            switch (event) {
                case 'onConnectionStatusChange':
                    this.__callback2UI('onConnectionStatusChanged', args[1])
                    break
                case 'onReceiveMessage':
                    let value = {
                        'messages': json.parse(args[1] as string),
                        'hasMore': args[2] === 1
                    } as Record<string, Object>
                    this.__callback2UI('onReceiveMessage', value)
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
            if (!fn) {
                Log.e(TAG, call.method + ' not implement')
            }
            fn?.(call, result)
        } catch (err) {
            Log.e(TAG, 'onMethodCall failed: ' + err);
            // result.error("IMClientPlugin", "onMethodCall failed with err", err);
        }
    }

    _onMethodCall = (call: MethodCall, result: MethodResult) => {

    }
    _initProto = (call: MethodCall, result: MethodResult) => {
        // do nothing
    }
    _getClientId = (call: MethodCall, result: MethodResult) => {
        let clientId: string = getClientId()
        result.success(clientId)
    }
    _connect = (call: MethodCall, result: MethodResult) => {
        let token: string = call.argument("token");
        let userId: string = call.argument("userId");
        connect('', userId, token)
        // TODO
        // FIXME
        let lastConnectTime = 0
        this.userId = userId;
        result.success(lastConnectTime)
    }
    _getUserInfo = (call: MethodCall, result: MethodResult) => {
        let userId: string = call.argument("userId");
        let refresh: boolean = call.argument("refresh");
        let groupId: string = call.argument("groupId");
        let userInfo = getUserInfo(userId, refresh, groupId)
        result.success(userInfo ? json.parse(userInfo) : null);
    }
    _getUserInfos = (call: MethodCall, result: MethodResult) => {
        let userIds: string[] = call.argument("userIds");
        let groupId: string = call.argument("groupId");
        let userInfos = getUserInfos(userIds, groupId)
        result.success(userInfos ? json.parse(userInfos) : []);
    }
    _registerMessage = (call: MethodCall, result: MethodResult) => {
        let type: number = call.argument("type");
        let flag: number = call.argument("flag");
        registerMessageFlag(type, flag)
    }
    _getConversationInfos = (call: MethodCall, result: MethodResult) => {
        let lines = call.argument('lines') as number[]
        let types = call.argument('types') as number[]
        let convsStr = getConversationInfos(types, lines)
        let convs = (convsStr ? json.parse(convsStr) : []) as Record<string, object | null>[]
        convs.map(this.__fixConversationInfo)
        result.success(convs)
    }
    _getGroupInfo = (call: MethodCall, result: MethodResult) => {
        let groupId: string = call.argument('groupId')
        let refresh: boolean = call.argument('refresh')
        let groupInfoStr = getGroupInfo(groupId, refresh)
        result.success(groupInfoStr ? json.parse(groupInfoStr) : null)
    }
    _getMyFriendList = (call: MethodCall, result: MethodResult) => {
        let refresh: boolean = call.argument('refresh')
        let myFriendListStr = getMyFriendList(refresh)
        result.success(myFriendListStr ? json.parse(myFriendListStr) : null)
    }
    _getUnreadFriendRequestStatus = (call: MethodCall, result: MethodResult) => {
        let count = getUnreadFriendRequestStatus()
        result.success(count)
    }
    // 需要试用 this 时，必须使用箭头函数，否则 this 丢失
    _getMessages = (call: MethodCall, result: MethodResult) => {
        let conv = this.__conversationFromArgument(call)

        // TODO
        // FIXME
        // contentTypes
        let contentTypes = call.argument('contentTypes') as number[]
        let withUser = call.argument('withUser') as string
        let fromIndex = call.argument('fromIndex') as number
        let count = call.argument('count') as number
        getMessagesV2(conv, fromIndex, count > 0, count > 0 ? count : -count, withUser, (msgsStr: string) => {
            let msgs = json.parse(msgsStr) as Record<string, object>[]
            result.success(msgs.reverse())
        }, err => {
            result.success([])
        })
    }
    _getConversationInfo = (call: MethodCall, result: MethodResult) => {
        let conv = this.__conversationFromArgument(call, true)
        let convinfo = getConversationInfo(conv)
        let convObj = convinfo ? json.parse(convinfo) as Record<string, object> : null
        result.success(this.__fixConversationInfo(convObj))
    }
    _getIncommingFriendRequest = (call: MethodCall, result: MethodResult) => {
        let str = getIncommingFriendRequest()
        result.success(str ? json.parse(str) : [])
    }
    _sendMessage = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument('requestId') as number
        let conv = this.__conversationFromArgument(call)
        let content = call.argument('content') as Map<string, object>
        let toUsers = call.argument('toUsers') ? call.argument('toUsers') as string[] : []
        let expireDuration = call.argument('expireDuration') ? call.argument('expireDuration') as number : 0

        let messageId: number = 0
        sendMessage(conv, json.stringify(this.__map2record(content)), toUsers, expireDuration,
            // onPrepared
            arrArgs => {

                let msg = {
                    'conversation': json.parse(conv),
                    'content': this.__map2record(content),
                    'status': 0,
                    'direction': 0,
                    'sender': this.userId,
                    'toUsers': toUsers,
                    'messageId': arrArgs[0],
                    'timestamp': Number(arrArgs[1])
                } as Record<string, Object>


                result.success(msg)

                messageId = arrArgs[0]

                let value = {
                    'requestId': requestId,
                    'messageId': arrArgs[0],
                    'message': msg,
                } as Record<string, Object>
                this.__callback2UI('onSendMessageStart', value)
            },
            // onprogress
            arrArgs => {
                let value = {
                    'requestId': requestId,
                    'uploaded': arrArgs[0],
                    'total': arrArgs[1],
                } as Record<string, Object>
                this.__callback2UI('onSendMediaMessageProgress', value)
            },
            // onsuccess
            arrArgs => {
                let value = {
                    'requestId': requestId,
                    'messageId': messageId,
                    'messageUid': arrArgs[0],
                    'timestamp': Number(arrArgs[1])
                } as Record<string, Object>
                this.__callback2UI('onSendMessageSuccess', value)
            },
            // onfail
            err => {
                let value = {
                    'requestId': requestId,
                    'messageId': messageId,
                    'errorCode': err
                } as Record<string, Object>
                this.__callback2UI('onSendMessageFailure', value)
            },
            // onupload
            remoteUrl => {
                let value = {
                    'requestId': requestId,
                    'messageId': messageId,
                    'remoteUrl': remoteUrl,
                } as Record<string, Object>
                this.__callback2UI('onSendMediaMessageUploaded', value)
            })
    }
    _clearConversationUnreadStatus = (call: MethodCall, result: MethodResult) => {
        let conv = this.__conversationFromArgument(call)
        clearUnreadStatus(conv)
        result.success(true)
    }
    _setConversationDraft = (call: MethodCall, result: MethodResult) => {
        let conv = this.__conversationFromArgument(call)
        let draft = call.argument('draft') as string
        setConversationDraft(conv, draft)
        result.success(null)
    }
    _isMyFriend = (call: MethodCall, result: MethodResult) => {
        let userId = call.argument('userId') as string
        result.success(isMyFriend(userId))
    }
    _getFavGroups = (call: MethodCall, result: MethodResult) => {
        let favGroups = getFavGroups();
        result.success(favGroups ? json.parse(favGroups) : [])
    }
    _getGroupMembersByCount = (call: MethodCall, result: MethodResult) => {
        let groupId = call.argument('groupId') as string
        let count = call.argument('count') as number
        let str = getGroupMembersByCount(groupId, count)
        result.success(str ? json.parse(str) : [])
    }
    _createGroup = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let groupId = call.argument("groupId") as string
        let groupName = call.argument("groupName") as string
        let groupExtra = call.argument("groupExtra") as string
        let groupPortrait = call.argument("groupPortrait") as string
        let groupType = call.argument("type") as number
        let memberExtra = call.argument("memberExtra") as string
        let groupMembers = call.argument("groupMembers") as string[]
        let notifyLines: number[] = call.argument("notifyLines") ? call.argument('notifyLines') : [0]
        let notifyContent = call.argument("notifyContent") as Map<string, object>

        createGroup(groupId, groupType, groupName, groupPortrait, groupExtra, groupMembers, memberExtra, notifyLines, notifyContent ? json.stringify(this.__map2record(notifyContent)) : '',
            this.__generalStringCallback(requestId), this.__generalFailCallback(requestId))

    }
    _isHiddenGroupMemberName = (call: MethodCall, result: MethodResult) => {
        let groupId = call.argument('groupId') as string
        let value = getUserSetting(5, groupId)
        return value === '1'
    }
    _isFavGroup = (call: MethodCall, result: MethodResult) => {
        let groupId = call.argument('groupId') as string
        let value = getUserSetting(6, groupId)
        return value === '1'
    }
    _getGroupMember = (call: MethodCall, result: MethodResult) => {
        let groupId = call.argument('groupId') as string
        let memberId = call.argument('memberId') as string
        let str = getGroupMember(groupId, memberId)
        result.success(str ? json.parse(str) : null)
    }
    _getGroupMembers = (call: MethodCall, result: MethodResult) => {
        let groupId = call.argument('groupId') as string
        let refresh = call.argument('refresh') as boolean
        let str = getGroupMembers(groupId, refresh)
        result.success(str ? json.parse(str) : null)
    }
    _addGroupMembers = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let groupId = call.argument('groupId') as string
        let extra = call.argument('extra') as string
        let groupMembers = call.argument('groupMembers') as string[]
        let notifyLines: number[] = call.argument('notifyLines') ? call.argument('notifyLines') : [0]

        let notifyContent = call.argument("notifyContent") as Map<string, object>

        addMembers(groupId, groupMembers, extra, notifyLines, notifyContent ? json.stringify(this.__map2record(notifyContent)) : '', this.__generalVoidCallback(requestId),
            this.__generalFailCallback(requestId))

    }
    _kickoffGroupMembers = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let groupId = call.argument('groupId') as string
        let groupMembers = call.argument('groupMembers') as string[]
        let notifyLines: number[] = call.argument('notifyLines') ? call.argument('notifyLines') : [0]

        let notifyContent = call.argument("notifyContent") as Map<string, object>

        kickoffMembers(groupId, groupMembers, notifyLines, notifyContent ? json.stringify(this.__map2record(notifyContent)) : '', this.__generalVoidCallback(requestId),
            this.__generalFailCallback(requestId))
    }
    _clearMessages = (call: MethodCall, result: MethodResult) => {
        let conv = this.__conversationFromArgument(call)
        let before = call.argument('before') as number
        clearMessages(conv)
        result.success(true)
    }
    _isSupportBigFilesUpload = (call: MethodCall, result: MethodResult) => {
        result.success(isSupportBigFilesUpload())
    }
    _recallMessage = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let messageUid = (call.argument('messageUid') as bigint).toString()
        let msg = getMessageByUid(messageUid)
        if (msg) {
            recall(messageUid, () => {
                let obj = {
                    'requestId': requestId,
                } as Record<string, Object>
                this.__callback2UI('onOperationVoidSuccess', obj)

                let obj2 = {
                    'messageUid':messageUid
                } as Record<string, Object>

                this.__callback2UI('onRecallMessage', obj2)

            }, this.__generalFailCallback(requestId))
        }
    }
    methods: Record<string, Function> = {
        "initProto": this._initProto,
        "getClientId": this._getClientId,
        "connect": this._connect,
        "getUserInfo": this._getUserInfo,
        "getUserInfos": this._getUserInfos,
        "getConversationInfos": this._getConversationInfos,
        "registerMessage": this._registerMessage,
        "getGroupInfo": this._getGroupInfo,
        "getMyFriendList": this._getMyFriendList,
        "getUnreadFriendRequestStatus": this._getUnreadFriendRequestStatus,
        "getMessages": this._getMessages,
        "getConversationInfo": this._getConversationInfo,
        "getIncommingFriendRequest": this._getIncommingFriendRequest,
        "sendMessage": this._sendMessage,
        "clearConversationUnreadStatus": this._clearConversationUnreadStatus,
        "setConversationDraft": this._setConversationDraft,
        "isMyFriend": this._isMyFriend,
        "getFavGroups": this._getFavGroups,
        "getGroupMembersByCount": this._getGroupMembersByCount,
        "createGroup": this._createGroup,
        "isHiddenGroupMemberName": this._isHiddenGroupMemberName,
        "isFavGroup": this._isFavGroup,
        "getGroupMember": this._getGroupMember,
        "getGroupMembers": this._getGroupMembers,
        "addGroupMembers": this._addGroupMembers,
        "kickoffGroupMembers": this._kickoffGroupMembers,
        "clearMessages": this._clearMessages,
        "isSupportBigFilesUpload": this._isSupportBigFilesUpload,
        "recallMessage": this._recallMessage,
    }

    __callback2UI(method: string, args: object) {
        this.channel?.invokeMethod(method, args)
    }

    __convertConversationInfo(info: string): Record<string, object> {

        // TODO
        return {} as Record<string, object>
    }

    __fixConversationInfo = (conv: Record<string, object | null> | null): Record<string, object | null> | null => {
        if (!conv) {
            return null;
        }
        let cv = {
            'type': conv['conversationType'],
            'line': conv['line'],
            'target': conv['target']
        } as Record<string, object>

        conv['conversation'] = cv
        let lastMessage = conv['lastMessage']
        if (lastMessage) {
            if (lastMessage['conversation'] && lastMessage['conversation']['target']) {
                lastMessage['conversation'] = cv
            } else {
                conv['lastMessage'] = null
            }
        }
        return conv
    }

    __conversationFromArgument(call: MethodCall, raw: boolean = false): string {
        if (raw) {
            let obj = {
                'type': call.argument('type'),
                'line': call.argument('line'),
                'target': call.argument('target')
            } as Record<string, object>
            return json.stringify(obj)
        } else {
            let convMap = call.argument('conversation') as Map<string, object>
            let convRecord = this.__map2record(convMap)
            return json.stringify(convRecord)
        }
    }

    __callbackValueBuilder = (): Record<string, Object> => {
        let obj = {} as Record<string, Object>
        return obj
    }
    __map2record = (map: Map<string, Object>): Record<string, Object> => {

        let obj = {} as Record<string, Object>
        for (let entry of map.entries()) {
            obj[entry[0]] = entry[1]
        }
        return obj
    }
    __generalStringCallback = (requestId: number) => {
        return (str: string) => {
            let obj = {
                'requestId': requestId,
                'string': str
            } as Record<string, Object>
            this.__callback2UI('onOperationStringSuccess', obj)
        }
    }
    __generalVoidCallback = (requestId: number) => {
        return () => {
            let obj = {
                'requestId': requestId,
            } as Record<string, Object>
            this.__callback2UI('onOperationVoidSuccess', obj)
        }
    }
    __generalFailCallback = (requestId: number) => {
        return (err: number) => {
            let obj = {
                'requestId': requestId,
                'errorCode': err
            } as Record<string, Object>
            this.__callback2UI('onOperationFailure', obj)
        }
    }
}