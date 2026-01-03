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
import buffer  from '@ohos.buffer';
import {
    initProto,
    setWfcEventListener,
    getClientId,
    connect,
    getConnectionStatus,
    registerMessageFlag,
    useSM4,
    setProxyInfo,
    disconnect,
    addHttpHeader,
    addMembers,
    getConversationInfos,
    getUserSettings,
    getGroupInfo,
    getUserInfo,
    getGroupMembers,
    getGroupMembersByCount,
    getUserInfos,
    getConversationInfo,
    getListenedChannels,
    getChannelInfo,
    getMyFriendList,
    getFavGroups,
    getFavUsers,
    getIncommingFriendRequest,
    getGroupInfos,
    getUnreadFriendRequestStatus,
    isFavGroup,
    getAuthCode,
    isMyFriend,
    isReceiptEnabled,
    watchOnlineState,
    isSupportBigFilesUpload,
    isUserReceiptEnabled,
    allowGroupMember,
    clearAllNotification,
    clearAllUnreadStatus,
    clearMessages,
    clearMessagesByTime,
    clearRemoteConversationMessages,
    clearUnreadFriendRequestStatus,
    clearUnreadStatus,
    configApplication,
    createChannel,
    createGroup,
    deleteFileRecord,
    getMessagesV2,
    getConversationRead,
    deleteFriend,
    deleteMessage,
    deleteRemoteMessage,
    destoryChannel,
    dismissGroup,
    getAuthorizedMediaUrl,
    getBlackList,
    getChatroomInfo,
    getChatroomMemberInfo,
    getConversationFiles,
    getConversationFirstUnreadMessageId,
    getConversationUnreadCount,
    getFriendAlias,
    getFriendList,
    getMyFiles,
    getOutgoingFriendRequest,
    getRemoteMessage,
    getRemoteMessages,
    getServerDeltaTime,
    getUnreadCount,
    getUploadMediaUrl,
    getUserInfoEx,
    getUserMessages,
    getUserMessagesEx,
    getUserMessagesExV2,
    getUserMessagesV2,
    getUserSetting,
    handleFriendRequest,
    insertMessage,
    isBlackListed,
    isCommercialServer,
    isEnableUserOnlineState,
    isFavUser,
    isGlobalDisableSyncDraft,
    isGlobalSlient,
    isHiddenNotificationDetail,
    isListenedChannel,
    joinChatroom,
    kickoffMembers,
    listenChannel,
    loadFriendRequestFromRemote,
    modifyChannelInfo,
    modifyGroupAlias,
    modifyGroupInfo,
    modifyGroupMemberAlias,
    modifyGroupMemberExtra,
    modifyMyInfo,
    muteGroupMember,
    quitChatroom,
    quitGroup,
    quitGroupEx,
    recall,
    removeConversation,
    searchChannel,
    searchConversation,
    searchFiles,
    searchFriends,
    searchGroups,
    searchMessage,
    searchMessageByTypes,
    searchMessageByTypesAndTimes,
    searchMessageEx,
    searchMessageEx2,
    searchMyFiles,
    searchUser,
    sendConferenceRequest,
    sendFriendRequest,
    sendMessage,
    setBackupAddress,
    setBackupAddressStrategy,
    setBlackList,
    setConversationDraft,
    setConversationSlient,
    setConversationTimestamp,
    setConversationTop,
    setDeviceToken,
    setFavGroup,
    setFavUser,
    setFriendAlias,
    setGlobalSlient,
    setGroupManager,
    setHiddenNotificationDetail,
    setLastReceivedMessageUnRead,
    setMediaMessagePlayed,
    setMessageLocalExtra,
    setUserAgent,
    setUserReceiptEnable,
    setUserSetting,
    transferGroup,
    unwatchOnlineState,
    updateMessage,
    updateMessageStatus,
    updateRemoteMessageContent,
    uploadMedia,
    getMessage,
    getMessageByUid,
    getGroupMember,
    getGroupInfoEx,
    setDisableSyncDraft
} from './marsWrapper';
import json from '@ohos.util.json';
import map from '@hms.core.map.map';
import util from '@ohos.util';
import { HAR_VERSION } from '@ohos/flutter_ohos/BuildProfile';

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
            console.debug('onMethodCall', call.method)
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

        createGroup(groupId, groupType, groupName, groupPortrait, groupExtra, groupMembers, memberExtra, notifyLines, this.__messageMap2Str(notifyContent),
            this.__generalStringCallback(requestId), this.__generalFailCallback(requestId))

    }
    _isHiddenGroupMemberName = (call: MethodCall, result: MethodResult) => {
        let groupId = call.argument('groupId') as string
        let value = getUserSetting(5, groupId)
        result.success(value === '1');
    }
    _isFavGroup = (call: MethodCall, result: MethodResult) => {
        let groupId = call.argument('groupId') as string
        let value = getUserSetting(6, groupId)
        result.success(value === '1');
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

        addMembers(groupId, groupMembers, extra, notifyLines, this.__messageMap2Str(notifyContent), this.__generalVoidCallback(requestId),
            this.__generalFailCallback(requestId))

    }
    _kickoffGroupMembers = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let groupId = call.argument('groupId') as string
        let groupMembers = call.argument('groupMembers') as string[]
        let notifyLines: number[] = call.argument('notifyLines') ? call.argument('notifyLines') : [0]

        let notifyContent = call.argument("notifyContent") as Map<string, object>

        kickoffMembers(groupId, groupMembers, notifyLines, this.__messageMap2Str(notifyContent), this.__generalVoidCallback(requestId),
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
        let messageUid = this.__getLongPara(call, 'messageUid')
        let msg = getMessageByUid(messageUid)
        if (msg) {
            recall(messageUid, () => {
                let obj = {
                    'requestId': requestId,
                } as Record<string, Object>
                this.__callback2UI('onOperationVoidSuccess', obj)

                let obj2 = {
                    'messageUid': messageUid
                } as Record<string, Object>

                this.__callback2UI('onRecallMessage', obj2)

            }, this.__generalFailCallback(requestId))
        }
    }
    _isLogined = (call: MethodCall, result: MethodResult) => {
        result.success(!this.userId)
    }
    _connectionStatus = (call: MethodCall, result: MethodResult) => {
        result.success(getConnectionStatus())
    }
    _serverDeltaTime = (call: MethodCall, result: MethodResult) => {
        result.success(getServerDeltaTime())
    }
    _startLog = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _stopLog = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _setSendLogCommand = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _useSM4 = (call: MethodCall, result: MethodResult) => {
        useSM4()
        result.success(null)
    }
    _setLiteMode = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _setDeviceToken = (call: MethodCall, result: MethodResult) => {
        let deviceToken = call.argument('deviceToken') as string
        let pushType = call.argument('pushType') as number
        setDeviceToken(pushType, deviceToken)
        result.success(null)
    }
    _setVoipDeviceToken = (call: MethodCall, result: MethodResult) => {
        result.success(null)
    }
    _setBackupAddressStrategy = (call: MethodCall, result: MethodResult) => {
        let strategy = call.argument("strategy") as number;
        setBackupAddressStrategy(strategy)
        result.success(null)
    }
    _setBackupAddress = (call: MethodCall, result: MethodResult) => {
        let host = call.argument("host") as string
        let port = call.argument("port") as number
        setBackupAddress(host, port)
        result.success(null)
    }
    _setProtoUserAgent = (call: MethodCall, result: MethodResult) => {
        let agent = call.argument("agent") as string
        setUserAgent(agent)
        result.success(null)
    }
    _addHttpHeader = (call: MethodCall, result: MethodResult) => {
        let header = call.argument("header") as string
        let value = call.argument("value") as string
        addHttpHeader(header, value)
        result.success(null)
    }
    _setProxyInfo = (call: MethodCall, result: MethodResult) => {
        let host = call.argument("host") as string
        let ip = call.argument("ip") as string
        let port = call.argument("port") as number
        let userName = call.argument("userName") as string
        let password = call.argument("password") as string
        setProxyInfo(host, ip, port, userName, password)
        result.success(null)
    }
    _getProtoRevision = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
        result.success('not implement')
    }
    _getLogFilesPath = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _disconnect = (call: MethodCall, result: MethodResult) => {
        let disablePush = call.argument("disablePush") as boolean;
        let clearSession = call.argument("clearSession") as boolean
        disconnect(disablePush, clearSession)
        result.success(null)
    }
    _searchConversation = (call: MethodCall, result: MethodResult) => {
        let cts = call.argument("types") as number[]
        let lines = call.argument("lines") as number[]
        let keyword = call.argument("keyword") as string

        let str = searchConversation(keyword, cts, lines)
        result.success(str ? json.parse(str) : [])
    }
    _removeConversation = (call: MethodCall, result: MethodResult) => {
        let clearMessage = call.argument("clearMessage") as boolean
        let conv = this.__conversationFromArgument(call)
        removeConversation(conv, clearMessage)
        result.success(null)
    }
    _setConversationTop = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let top = call.argument("isTop") as number
        let conv = this.__conversationFromArgument(call)
        setConversationTop(conv, top, this.__generalVoidCallback(requestId), this.__generalFailCallback(requestId))
    }
    _setConversationSilent = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let isSilent = call.argument("isSilent") as boolean
        let conv = this.__conversationFromArgument(call)
        setConversationSlient(conv, isSilent, this.__generalVoidCallback(requestId), this.__generalFailCallback(requestId))
    }
    _setConversationTimestamp = (call: MethodCall, result: MethodResult) => {
        let timestamp = call.argument('timestamp') as number
        let conv = this.__conversationFromArgument(call)
        setConversationTimestamp(conv, '' + timestamp)
    }
    _getFirstUnreadMessageId = (call: MethodCall, result: MethodResult) => {
        let conv = this.__conversationFromArgument(call)
        let messageId = getConversationFirstUnreadMessageId(conv)
        result.success(messageId)
    }
    _getConversationUnreadCount = (call: MethodCall, result: MethodResult) => {
        let conv = this.__conversationFromArgument(call)
        let unread = getConversationUnreadCount(conv)
        result.success(unread ? json.parse(unread) : null)
    }
    _getConversationsUnreadCount = (call: MethodCall, result: MethodResult) => {
        let cts = call.argument("types") as number[]
        let lines = call.argument("lines") as number[]
        let unread = getUnreadCount(cts, lines)
        result.success(unread ? json.parse(unread) : null)
    }
    _clearConversationsUnreadStatus = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _clearMessageUnreadStatus = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _markAsUnRead = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _getConversationRead = (call: MethodCall, result: MethodResult) => {
        let conv = this.__conversationFromArgument(call)
        let read = getConversationRead(conv)
        result.success(read ? json.parse(read) : null)
    }
    _getMessageDelivery = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _getMessagesByStatus = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _getConversationsMessages = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _getConversationsMessageByStatus = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _getRemoteMessages = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let conv = this.__conversationFromArgument(call)
        let beforeMessageUid = this.__getLongPara(call, "beforeMessageUid")
        let count = call.argument("count") as number
        getRemoteMessages(conv, beforeMessageUid, count, str => {
            let obj = {
                'messages': json.parse(str),
                'requestId': requestId,
            } as Record<string, Object>
            this.__callback2UI('onMessagesCallback', obj)
        }, this.__generalFailCallback(requestId))
    }
    _getRemoteMessage = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let messageUid = this.__getLongPara(call, "messageUid")
        getRemoteMessage(messageUid, str => {
            let obj = {
                'message': str ? json.parse(str) : null,
                'requestId': requestId
            } as Record<string, Object>
            this.__callback2UI('onMessageCallback', obj)

        }, this.__generalFailCallback(requestId))
    }
    _getMessage = (call: MethodCall, result: MethodResult) => {
        let messageId = call.argument("messageId") as number
        let msg = getMessage(messageId) as string
        result.success(msg ? json.parse(msg) : null)
    }
    _getMessageByUid = (call: MethodCall, result: MethodResult) => {
        let messageUid = this.__getLongPara(call, "messageUid")
        let msg = getMessageByUid(messageUid)
        result.success(msg ? json.parse(msg) : null)
    }
    _searchMessages = (call: MethodCall, result: MethodResult) => {
        let conv = this.__conversationFromArgument(call)
        let keyword = call.argument("keyword") as string

        // TODO
        let order = call.argument("order") as boolean
        let limit = call.argument("limit") as number
        let offset = call.argument("offset") as number
        let withUser = call.argument("withUser") as string

        let msgs = searchMessage(conv, keyword, withUser)
        result.success(msgs ? (json.parse(msgs) as Record<string, object>[]).reverse() : null)

    }
    _searchConversationsMessages = (call: MethodCall, result: MethodResult) => {
        let cts = call.argument('types') as number[]
        let lines = call.argument("lines") as number[]
        let keyword = call.argument("keyword") as string
        let withUser = call.argument("withUser") as string
        let contentTypes = call.argument("contentTypes") as number[]
        let fromIndex = call.argument("fromIndex") as number
        let count = call.argument("count") as number

        let desc = false
        if (count < 0) {
            desc = true
            count = -count;
        }
        let msgs = searchMessageEx2(cts, lines, contentTypes, keyword, fromIndex, desc, count, withUser)

        result.success(msgs ? json.parse(msgs) : null)
    }
    _sendSavedMessage = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let messageId = call.argument("messageId") as number
        let expireDuration = call.argument("expireDuration") as number
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _cancelSendingMessage = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _uploadMedia = async (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let fileName = call.argument("fileName") as string
        let mediaType = call.argument("mediaType") as number
        let mediaData = call.argument("mediaData") as Uint8Array
        let base64MediaData = await this.base64Helper.encodeToString(mediaData)
        uploadMedia(fileName, base64MediaData, mediaType, remoteUrl => {
            let obj = {
                'requestId': requestId,
                'remoteUrl': remoteUrl
            } as Record<string, Object>
            this.__callback2UI('onUploadMediaUploaded', obj)

        }, this.__generalFailCallback(requestId),
            arrArgs => {
                let value = {
                    'requestId': requestId,
                    'uploaded': arrArgs[0],
                    'total': arrArgs[1],
                } as Record<string, Object>
                this.__callback2UI('onUploadMediaProgress', value)
            })
    }
    _uploadMediaFile = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _getUploadUrl = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let fileName = call.argument("fileName") as string
        let mediaType = call.argument("mediaType") as number
        let contentType = call.argument("contentType") as string

        getUploadMediaUrl(fileName, mediaType, contentType, arrArgs => {
            let value = {
                'requestId': requestId,
                'uploadUrl': arrArgs[0],
                'downloadUrl': arrArgs[1],
                'backupUploadUrl': arrArgs[2],
                'type': arrArgs[3],
            } as Record<string, Object>
            this.__callback2UI('onGetUploadUrl', value)
        }, this.__generalFailCallback(requestId))
    }
    _deleteMessage = (call: MethodCall, result: MethodResult) => {
        let messageId = call.argument('messageId') as number
        deleteMessage(messageId)
        result.success(true)
    }
    _batchDeleteMessages = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _deleteRemoteMessage = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let messageUid = this.__getLongPara(call, "messageUid")

        deleteRemoteMessage(messageUid, this.__generalVoidCallback(requestId), this.__generalFailCallback(requestId))
    }
    _clearMessagesKeepLatest = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _clearRemoteConversationMessage = (call: MethodCall, result: MethodResult) => {
        let conv = this.__conversationFromArgument(call)
        let requestId = call.argument("requestId") as number
        clearRemoteConversationMessages(conv, this.__generalVoidCallback(requestId), this.__generalFailCallback(requestId))
    }
    _setMediaMessagePlayed = (call: MethodCall, result: MethodResult) => {
        let messageId = call.argument('messageId') as number
        setMediaMessagePlayed(messageId)
        result.success(null)
    }
    _setMessageLocalExtra = (call: MethodCall, result: MethodResult) => {
        let messageId = call.argument('messageId') as number
        let localExtra = call.argument('localExtra') as string
        setMessageLocalExtra(messageId, localExtra)
    }
    _insertMessage = (call: MethodCall, result: MethodResult) => {
        let conv = this.__conversationFromArgument(call)
        let content = call.argument('content') as Map<string, object>

        let status = call.argument("status") as number
        let serverTime = call.argument("serverTime") as number
        let toUsers = call.argument('toUsers') ? call.argument('toUsers') as string[] : []
        let sender = call.argument("sender") ? call.argument('sender') as string : this.userId

        let msg = insertMessage(conv, sender, json.stringify(this.__map2record(content)), status, false, toUsers, serverTime)
        result.success(json.parse(msg))

    }
    _updateMessage = (call: MethodCall, result: MethodResult) => {
        let messageId = call.argument("messageId") as number
        let content = call.argument("content") as Map<string, object>
        updateMessage(messageId, json.stringify(this.__map2record(content)))
        result.success(true)
    }
    _updateRemoteMessageContent = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let messageUid = this.__getLongPara(call, "messageUid")
        let content = call.argument("content") as Map<string, object>
        let distribute = call.argument("distribute") as boolean
        let updateLocal = call.argument("updateLocal") as boolean

        updateRemoteMessageContent(messageUid, json.stringify(this.__map2record(content)), distribute, updateLocal, this.__generalVoidCallback(requestId), this.__generalFailCallback(requestId))
    }
    _updateMessageStatus = (call: MethodCall, result: MethodResult) => {
        let messageId = call.argument("messageId") as number
        let status = call.argument("status") as number
        updateMessageStatus(messageId, status)
        result.success(true)
    }
    _getMessageCount = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _searchUser = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let keyword = call.argument("keyword") as string
        let searchType = call.argument("searchType") as number
        let page = call.argument("page") as number

        searchUser(keyword, searchType, page, str => {
            let obj = {
                'requestId': requestId,
                'users': json.parse(str)
            } as Record<string, Object>
            this.__callback2UI('onSearchUserResult', obj)

        }, this.__generalFailCallback(requestId))
    }
    _getUserInfoAsync = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let userId = call.argument("userId") as string
        // TODO
        // FIXME
        let groupId = call.argument("groupId") as string
        let refresh = call.argument("refresh") as boolean
        getUserInfoEx(userId, refresh, str => {
            let obj = {
                'requestId': requestId,
                'user': json.parse(str)
            } as Record<string, Object>
            this.__callback2UI('getUserInfoAsyncCallback', obj)
        }, this.__generalFailCallback(requestId))
    }
    _searchFriends = (call: MethodCall, result: MethodResult) => {
        let keyword = call.argument("keyword") as string
        let str = searchFriends(keyword)
        result.success(str ? json.parse(str) : [])
    }
    _getFriends = (call: MethodCall, result: MethodResult) => {
        let refresh = call.argument("refresh") as boolean
        let str = getMyFriendList(refresh)
        result.success(str ? json.parse(str) : [])
    }
    _searchGroups = (call: MethodCall, result: MethodResult) => {
        let keyword = call.argument("keyword") as string
        let str = searchGroups(keyword)
        result.success(str ? json.parse(str) : [])
    }
    _getOutgoingFriendRequest = (call: MethodCall, result: MethodResult) => {
        let str = getOutgoingFriendRequest()
        result.success(str ? json.parse(str) : [])
    }
    _getFriendRequest = (call: MethodCall, result: MethodResult) => {
        let userId = call.argument("userId") as string
        let direction = call.argument("direction") as number
        // TODO
        console.error(`${call.method} is not implement`);
        // FIXME
    }
    _loadFriendRequestFromRemote = (call: MethodCall, result: MethodResult) => {
        loadFriendRequestFromRemote()
        result.success(null)
    }
    _clearUnreadFriendRequestStatus = (call: MethodCall, result: MethodResult) => {
        clearUnreadFriendRequestStatus()
        result.success(true)
    }
    _clearFriendRequest = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _deleteFriend = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let userId = call.argument("userId") as string
        deleteFriend(userId, this.__generalVoidCallback(requestId), this.__generalFailCallback(requestId))
    }
    _sendFriendRequest = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let userId = call.argument("userId") as string
        let reason = call.argument("reason") as string
        let extra = call.argument("extra") as string
        sendFriendRequest(userId, reason, extra, this.__generalVoidCallback(requestId), this.__generalFailCallback(requestId))
    }
    _handleFriendRequest = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let userId = call.argument("userId") as string
        let extra = call.argument("extra") as string
        let accept = call.argument("accept") as boolean
        handleFriendRequest(userId, accept, this.__generalVoidCallback(requestId), this.__generalFailCallback(requestId), extra)
    }
    _getFriendAlias = (call: MethodCall, result: MethodResult) => {
        let friendId = call.argument("friendId") as string
        result.success(getFriendAlias(friendId))
    }
    _setFriendAlias = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let friendId = call.argument("friendId") as string
        let alias = call.argument("alias") as string
        setFriendAlias(this.userId, alias, this.__generalVoidCallback(requestId), this.__generalFailCallback(requestId))
    }
    _getFriendExtra = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _isBlackListed = (call: MethodCall, result: MethodResult) => {
        let userId = call.argument("userId") as string
        result.success(isBlackListed(userId))

    }
    _getBlackList = (call: MethodCall, result: MethodResult) => {
        let refresh = call.argument("refresh") as boolean
        let str = getBlackList(refresh)
        result.success(str ? json.parse(str) : [])
    }
    _setBlackList = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let userId = call.argument("userId") as string
        let isBlackListed = call.argument("isBlackListed") as boolean
        setBlackList(userId, isBlackListed, this.__generalVoidCallback(requestId), this.__generalFailCallback(requestId))
    }
    _getGroupMembersByTypes = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _getGroupMembersAsync = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _getGroupInfos = (call: MethodCall, result: MethodResult) => {
        let groupIds = call.argument("groupIds") as string[]
        let refresh = call.argument("refresh") as boolean

        let str = getGroupInfos(groupIds, refresh)
        result.success(str ? json.parse(str) : [])
    }
    _getGroupInfoAsync = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let groupId = call.argument("groupId") as string
        let refresh = call.argument("refresh") as boolean

        getGroupInfoEx(groupId, refresh, str => {
            let obj = {
                'requestId': requestId,
                'groupInfo': json.parse(str)
            } as Record<string, Object>
            this.__callback2UI('getGroupInfoAsyncCallback', obj)
        }, this.__generalFailCallback(requestId))
    }
    _quitGroup = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let groupId = call.argument("groupId") as string
        let notifyLines = call.argument("notifyLines") ? call.argument('notifyLines') as number[] : [0]
        let notifyContent = call.argument('notifyContent') as Map<string, object>

        quitGroup(groupId, notifyLines, this.__messageMap2Str(notifyContent), this.__generalVoidCallback(requestId), this.__generalFailCallback(requestId))
    }
    _quitGroupEx = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let keepMessage = call.argument("keepMessage") as boolean
        let groupId = call.argument("groupId") as string
        let notifyLines = call.argument("notifyLines") ? call.argument('notifyLines') as number[] : [0]
        let notifyContent = call.argument('notifyContent') as Map<string, object>

        quitGroupEx(groupId, keepMessage, notifyLines, this.__messageMap2Str(notifyContent), this.__generalVoidCallback(requestId),
            this.__generalFailCallback(requestId))
    }
    _dismissGroup = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let groupId = call.argument("groupId") as string
        let notifyLines = call.argument("notifyLines") ? call.argument('notifyLines') as number[] : [0]
        let notifyContent = call.argument('notifyContent') as Map<string, object>
        dismissGroup(groupId, notifyLines, this.__messageMap2Str(notifyContent), this.__generalVoidCallback(requestId), this.__generalFailCallback(requestId))
    }
    _modifyGroupInfo = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let groupId = call.argument("groupId") as string
        let modifyType = call.argument("modifyType") as number
        let value = call.argument("value") as string
        let notifyLines = call.argument("notifyLines") ? call.argument('notifyLines') as number[] : [0]
        let notifyContent = call.argument('notifyContent') as Map<string, object>

        modifyGroupInfo(groupId, modifyType, value, notifyLines, this.__messageMap2Str(notifyContent), this.__generalVoidCallback(requestId),
            this.__generalFailCallback(requestId))
    }
    _modifyGroupAlias = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let groupId = call.argument("groupId") as string
        let newAlias = call.argument("newAlias") as string
        let notifyLines = call.argument("notifyLines") ? call.argument('notifyLines') as number[] : [0]
        let notifyContent = call.argument('notifyContent') as Map<string, object>

        modifyGroupAlias(groupId, newAlias, notifyLines, this.__messageMap2Str(notifyContent), this.__generalVoidCallback(requestId),
            this.__generalFailCallback(requestId))
    }
    _modifyGroupMemberAlias = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let groupId = call.argument("groupId") as string
        let memberId = call.argument("memberId") as string
        let newAlias = call.argument("newAlias") as string
        let notifyLines = call.argument("notifyLines") ? call.argument('notifyLines') as number[] : [0]
        let notifyContent = call.argument('notifyContent') as Map<string, object>

        modifyGroupMemberAlias(groupId, memberId, newAlias, notifyLines, this.__messageMap2Str(notifyContent), this.__generalVoidCallback(requestId),
            this.__generalFailCallback(requestId))
    }
    _transferGroup = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let groupId = call.argument("groupId") as string
        let newOwner = call.argument("newOwner") as string
        let notifyLines = call.argument("notifyLines") ? call.argument('notifyLines') as number[] : [0]
        let notifyContent = call.argument('notifyContent') as Map<string, object>

        transferGroup(groupId, newOwner, notifyLines, this.__messageMap2Str(notifyContent), this.__generalVoidCallback(requestId),
            this.__generalFailCallback(requestId))
    }
    _setGroupManager = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let groupId = call.argument("groupId") as string
        let isSet = call.argument("isSet") as boolean
        let memberIds = call.argument("memberIds") as string[]
        let notifyLines = call.argument("notifyLines") ? call.argument('notifyLines') as number[] : [0]
        let notifyContent = call.argument('notifyContent') as Map<string, object>

        setGroupManager(groupId, isSet, memberIds, notifyLines, this.__messageMap2Str(notifyContent), this.__generalVoidCallback(requestId),
            this.__generalFailCallback(requestId))
    }
    _muteGroupMember = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let groupId = call.argument("groupId") as string
        let isSet = call.argument("isSet") as boolean
        let memberIds = call.argument("memberIds") as string[]
        let notifyLines = call.argument("notifyLines") ? call.argument('notifyLines') as number[] : [0]
        let notifyContent = call.argument('notifyContent') as Map<string, object>

        muteGroupMember(groupId, isSet, memberIds, notifyLines, this.__messageMap2Str(notifyContent), this.__generalVoidCallback(requestId),
            this.__generalFailCallback(requestId))
    }
    _allowGroupMember = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let groupId = call.argument("groupId") as string
        let isSet = call.argument("isSet") as boolean
        let memberIds = call.argument("memberIds") as string[]
        let notifyLines = call.argument("notifyLines") ? call.argument('notifyLines') as number[] : [0]
        let notifyContent = call.argument('notifyContent') as Map<string, object>

        allowGroupMember(groupId, isSet, memberIds, notifyLines, this.__messageMap2Str(notifyContent), this.__generalVoidCallback(requestId),
            this.__generalFailCallback(requestId))
    }
    _getGroupRemark = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _setGroupRemark = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _setFavGroup = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let groupId = call.argument("groupId") as string
        let isFav = call.argument("isFav") as boolean
        setFavGroup(groupId, isFav, this.__generalVoidCallback(requestId), this.__generalFailCallback(requestId))

    }
    _getUserSetting = (call: MethodCall, result: MethodResult) => {
        let scope = call.argument("scope") as number
        let key = call.argument("key") as string
        result.success(getUserSetting(scope, key))
    }
    _getUserSettings = (call: MethodCall, result: MethodResult) => {
        let scope = call.argument("scope") as number
        result.success(getUserSettings(scope))
    }
    _setUserSetting = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let scope = call.argument("scope") as number
        let key = call.argument("key") as string
        let value = call.argument("value") as string
        setUserSetting(scope, key, value, this.__generalVoidCallback(requestId), this.__generalFailCallback(requestId))
    }
    _modifyMyInfo = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let values = call.argument("values") as Map<number, string>

        // TODO
        console.error(`${call.method} is not implement`);
        // FIXME
        for (let entry of values.entries()) {
            modifyMyInfo(entry[0], entry[1], this.__generalVoidCallback(requestId), this.__generalFailCallback(requestId))
        }
    }
    _isGlobalSilent = (call: MethodCall, result: MethodResult) => {
        result.success(isGlobalSlient())
    }
    _setGlobalSilent = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let isSilent = call.argument("isSilent") as boolean
        setGlobalSlient(isSilent, this.__generalVoidCallback(requestId), this.__generalFailCallback(requestId))
    }
    _isVoipNotificationSilent = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _setVoipNotificationSilent = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _isEnableSyncDraft = (call: MethodCall, result: MethodResult) => {
        result.success(!isGlobalDisableSyncDraft())
    }
    _setEnableSyncDraft = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let enable = call.argument("enable") as boolean
        setDisableSyncDraft(!enable, this.__generalVoidCallback(requestId), this.__generalFailCallback(requestId))
    }
    _getNoDisturbingTimes = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _setNoDisturbingTimes = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _clearNoDisturbingTimes = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _isNoDisturbing = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _isHiddenNotificationDetail = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _setHiddenNotificationDetail = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _setHiddenGroupMemberName = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let groupId = call.argument("groupId") as string
        let isHidden = call.argument("isHidden") as boolean

        setUserSetting(5, groupId, isHidden ? '1' : '0', this.__generalVoidCallback(requestId), this.__generalFailCallback(requestId))
    }
    _getMyGroups = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _getCommonGroups = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _isUserEnableReceipt = (call: MethodCall, result: MethodResult) => {
        result.success(isReceiptEnabled())
    }
    _setUserEnableReceipt = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let isEnable = call.argument("isEnable") as boolean
        setUserReceiptEnable(isEnable, this.__generalVoidCallback(requestId), this.__generalFailCallback(requestId))
    }
    _getFavUsers = (call: MethodCall, result: MethodResult) => {
        let userIds = getFavUsers()
        result.success(userIds ? json.parse(userIds) : [])
    }
    _isFavUser = (call: MethodCall, result: MethodResult) => {
        let userId = call.argument("userId") as string
        result.success(isFavUser(userId))
    }
    _setFavUser = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let userId = call.argument("userId") as string
        let isFav = call.argument("isFav") as boolean
        setFavUser(userId, isFav, this.__generalVoidCallback(requestId), this.__generalFailCallback(requestId))
    }
    _joinChatroom = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let chatroomId = call.argument("chatroomId") as string
        joinChatroom(chatroomId, this.__generalVoidCallback(requestId), this.__generalFailCallback(requestId))
    }
    _quitChatroom = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let chatroomId = call.argument("chatroomId") as string
        quitChatroom(chatroomId, this.__generalVoidCallback(requestId), this.__generalFailCallback(requestId))
    }
    _getChatroomInfo = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let chatroomId = call.argument("chatroomId") as string
        let updateDt = call.argument("updateDt") as number
        getChatroomInfo(chatroomId, updateDt, str => {
            let obj = {
                'requestId': requestId,
                'chatroomInfo': json.parse(str)
            } as Record<string, Object>
            this.__callback2UI('onGetChatroomInfoResult', obj)
        }, this.__generalFailCallback(requestId))
    }
    _getChatroomMemberInfo = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let chatroomId = call.argument("chatroomId") as string
        let maxCount = call.argument("maxCount") as number

        getChatroomMemberInfo(chatroomId, maxCount, str => {
            let obj = {
                'requestId': requestId,
                'chatroomMemberInfo': json.parse(str)
            } as Record<string, Object>
            this.__callback2UI('onGetChatroomMemberInfoResult', obj)
        }, this.__generalFailCallback(requestId))
    }
    _createChannel = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let channelId = call.argument("channelId") as string
        let channelName = call.argument("channelName") as string
        let channelPortrait = call.argument("channelPortrait") as string
        let desc = call.argument("desc") as string
        let extra = call.argument("extra") as string

        createChannel(channelName, channelPortrait, 0, desc, extra, this.__generalStringCallback(requestId), this.__generalFailCallback(requestId))
    }
    _getChannelInfo = (call: MethodCall, result: MethodResult) => {
        let channelId = call.argument("channelId") as string
        let refresh = call.argument("refresh") as boolean
        let str = getChannelInfo(channelId, refresh)
        result.success(str ? json.stringify(str) : null)
    }
    _modifyChannelInfo = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let channelId = call.argument("channelId") as string
        let type = call.argument("type") as number
        let newValue = call.argument("newValue") as string

        modifyChannelInfo(channelId, type, newValue, this.__generalVoidCallback(requestId), this.__generalFailCallback(requestId))
    }
    _searchChannel = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let keyword = call.argument("keyword") as string
        searchChannel(keyword, str => {
            let obj = {
                'requestId': requestId,
                'channelInfos': json.parse(str)
            } as Record<string, Object>
            this.__callback2UI('onSearchChannelResult', obj)
        }, this.__generalFailCallback(requestId))
    }
    _isListenedChannel = (call: MethodCall, result: MethodResult) => {
        let channelId = call.argument("channelId") as string
        result.success(isListenedChannel(channelId))

    }
    _listenChannel = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let channelId = call.argument("channelId") as string
        let listen = call.argument("listen") as boolean
        listenChannel(channelId, listen, this.__generalVoidCallback(requestId), this.__generalFailCallback(requestId))
    }
    _getMyChannels = (call: MethodCall, result: MethodResult) => {
        let str = getListenedChannels()
        result.success(str ? json.parse(str) : [])
    }
    _getRemoteListenedChannels = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _destoryChannel = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let channelId = call.argument("channelId") as string
        destoryChannel(channelId, this.__generalVoidCallback(requestId), this.__generalFailCallback(requestId))
    }
    _getOnlineInfos = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _kickoffPCClient = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _isMuteNotificationWhenPcOnline = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _muteNotificationWhenPcOnline = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _getUserOnlineState = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _getMyCustomState = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _setMyCustomState = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _watchOnlineState = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let targets = call.argument("targets") as string[]
        let conversationType = call.argument("conversationType") as number
        let watchDuration = call.argument("watchDuration") as number

        watchOnlineState(conversationType, targets, watchDuration, str => {
            let obj = {
                'requestId': requestId,
                'states': json.stringify(str)
            } as Record<string, Object>
            this.__callback2UI('onWatchOnlineStateSuccess', obj)

        }, this.__generalFailCallback(requestId))
    }
    _unwatchOnlineState = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let targets = call.argument("targets") as string[]
        let conversationType = call.argument("conversationType") as number
        unwatchOnlineState(conversationType, targets, this.__generalVoidCallback(requestId), this.__generalFailCallback(requestId))
    }
    _isEnableUserOnlineState = (call: MethodCall, result: MethodResult) => {
        result.success(isEnableUserOnlineState())
    }
    _getConversationFiles = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let userId = call.argument('userId') ? call.argument("userId") as string : ''
        let order = call.argument("order") as number
        let conversation = call.argument("conversation") ? this.__conversationFromArgument(call) : ''
        let beforeMessageUid = this.__getLongPara(call, "beforeMessageUid")
        let count = call.argument("count") as number

        getConversationFiles(conversation, userId, beforeMessageUid, order, count, str => {
            let obj = {
                'requestId': requestId,
                'files': json.parse(str)
            } as Record<string, Object>
            this.__callback2UI('onFilesResult', obj)
        }, this.__generalFailCallback(requestId))
    }
    _getMyFiles = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let order = call.argument("order") as number
        let beforeMessageUid = this.__getLongPara(call, "beforeMessageUid");
        let count = call.argument("count") as number
        getMyFiles(beforeMessageUid, count, str => {
            let obj = {
                'requestId': requestId,
                'files': json.parse(str)
            } as Record<string, Object>
            this.__callback2UI('onFilesResult', obj)

        }, this.__generalFailCallback(requestId))
    }
    _deleteFileRecord = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let messageUid = this.__getLongPara(call, "messageUid");
        deleteFileRecord(messageUid, this.__generalVoidCallback(requestId), this.__generalFailCallback(requestId))
    }
    _searchFiles = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let order = call.argument("order") as number
        let keyword = call.argument("keyword") as string
        let userId = call.argument('userId') ? call.argument("userId") as string : ''
        let conversation = this.__conversationFromArgument(call)
        let beforeMessageUid = this.__getLongPara(call, "beforeMessageUid")
        let count = call.argument("count") as number

        searchFiles(keyword, conversation, userId, beforeMessageUid, count, str => {
            let obj = {
                'requestId': requestId,
                'files': json.parse(str)
            } as Record<string, Object>
            this.__callback2UI('onFilesResult', obj)
        }, this.__generalFailCallback(requestId))
    }
    _searchMyFiles = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let keyword = call.argument("keyword") as string
        let beforeMessageUid = this.__getLongPara(call, "beforeMessageUid");
        let count = call.argument("count") as number
        let order = call.argument("order") as number

        searchMyFiles(keyword, beforeMessageUid, order, count, str => {
            let obj = {
                'requestId': requestId,
                'files': json.parse(str)
            } as Record<string, Object>
            this.__callback2UI('onFilesResult', obj)
        }, this.__generalFailCallback(requestId))
    }
    _getAuthorizedMediaUrl = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let mediaPath = call.argument("mediaPath") as string
        let messageUid = this.__getLongPara(call, "messageUid")
        let mediaType = call.argument("mediaType") as number

        getAuthorizedMediaUrl(messageUid, mediaType, mediaPath, arrArgs => {
            let value = {
                'requestId': requestId,
                'string': arrArgs[0],
                'string2': arrArgs[1],
            } as Record<string, Object>
            this.__callback2UI('onOperationStringSuccess', value)
        }, this.__generalFailCallback(requestId))
    }
    _getAuthCode = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let applicationId = call.argument("applicationId") as string
        let type = call.argument("type") as number
        let host = call.argument("host") as string

        getAuthCode(applicationId, type, host, this.__generalStringCallback(requestId), this.__generalFailCallback(requestId))
    }
    _configApplication = (call: MethodCall, result: MethodResult) => {
        let requestId = call.argument("requestId") as number
        let applicationId = call.argument("applicationId") as string
        let type = call.argument("type") as number
        let timestamp = call.argument("timestamp") as number
        let signature = call.argument("signature") as string
        let nonce = call.argument("nonce") as string

        configApplication(applicationId, type, timestamp, nonce, signature, this.__generalVoidCallback(requestId), this.__generalFailCallback(requestId))
    }
    _getWavData = (call: MethodCall, result: MethodResult) => {
        result.success(null)
    }
    _beginTransaction = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _commitTransaction = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _rollbackTransaction = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _isCommercialServer = (call: MethodCall, result: MethodResult) => {
        result.success(isCommercialServer())
    }
    _isReceiptEnabled = (call: MethodCall, result: MethodResult) => {
        result.success(isReceiptEnabled())
    }
    _isGroupReceiptEnabled = (call: MethodCall, result: MethodResult) => {
        // TODO
        console.error(`${call.method} is not implement`);
    }
    _isGlobalDisableSyncDraft = (call: MethodCall, result: MethodResult) => {
        result.success(isGlobalDisableSyncDraft())
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
        "isLogined": this._isLogined,
        "connectionStatus": this._connectionStatus,
        "serverDeltaTime": this._serverDeltaTime,
        "startLog": this._startLog,
        "stopLog": this._stopLog,
        "setSendLogCommand": this._setSendLogCommand,
        "useSM4": this._useSM4,
        "setLiteMode": this._setLiteMode,
        "setDeviceToken": this._setDeviceToken,
        "setVoipDeviceToken": this._setVoipDeviceToken,
        "setBackupAddressStrategy": this._setBackupAddressStrategy,
        "setBackupAddress": this._setBackupAddress,
        "setProtoUserAgent": this._setProtoUserAgent,
        "addHttpHeader": this._addHttpHeader,
        "setProxyInfo": this._setProxyInfo,
        "getProtoRevision": this._getProtoRevision,
        "getLogFilesPath": this._getLogFilesPath,
        "disconnect": this._disconnect,
        "searchConversation": this._searchConversation,
        "removeConversation": this._removeConversation,
        "setConversationTop": this._setConversationTop,
        "setConversationSilent": this._setConversationSilent,
        "setConversationTimestamp": this._setConversationTimestamp,
        "getFirstUnreadMessageId": this._getFirstUnreadMessageId,
        "getConversationUnreadCount": this._getConversationUnreadCount,
        "getConversationsUnreadCount": this._getConversationsUnreadCount,
        "clearConversationsUnreadStatus": this._clearConversationsUnreadStatus,
        "clearMessageUnreadStatus": this._clearMessageUnreadStatus,
        "markAsUnRead": this._markAsUnRead,
        "getConversationRead": this._getConversationRead,
        "getMessageDelivery": this._getMessageDelivery,
        "getMessagesByStatus": this._getMessagesByStatus,
        "getConversationsMessages": this._getConversationsMessages,
        "getConversationsMessageByStatus": this._getConversationsMessageByStatus,
        "getRemoteMessages": this._getRemoteMessages,
        "getRemoteMessage": this._getRemoteMessage,
        "getMessage": this._getMessage,
        "getMessageByUid": this._getMessageByUid,
        "searchMessages": this._searchMessages,
        "searchConversationsMessages": this._searchConversationsMessages,
        "sendSavedMessage": this._sendSavedMessage,
        "cancelSendingMessage": this._cancelSendingMessage,
        "uploadMedia": this._uploadMedia,
        "uploadMediaFile": this._uploadMediaFile,
        "getUploadUrl": this._getUploadUrl,
        "deleteMessage": this._deleteMessage,
        "batchDeleteMessages": this._batchDeleteMessages,
        "deleteRemoteMessage": this._deleteRemoteMessage,
        "clearMessagesKeepLatest": this._clearMessagesKeepLatest,
        "clearRemoteConversationMessage": this._clearRemoteConversationMessage,
        "setMediaMessagePlayed": this._setMediaMessagePlayed,
        "setMessageLocalExtra": this._setMessageLocalExtra,
        "insertMessage": this._insertMessage,
        "updateMessage": this._updateMessage,
        "updateRemoteMessageContent": this._updateRemoteMessageContent,
        "updateMessageStatus": this._updateMessageStatus,
        "getMessageCount": this._getMessageCount,
        "searchUser": this._searchUser,
        "getUserInfoAsync": this._getUserInfoAsync,
        "searchFriends": this._searchFriends,
        "getFriends": this._getFriends,
        "searchGroups": this._searchGroups,
        "getOutgoingFriendRequest": this._getOutgoingFriendRequest,
        "getFriendRequest": this._getFriendRequest,
        "loadFriendRequestFromRemote": this._loadFriendRequestFromRemote,
        "clearUnreadFriendRequestStatus": this._clearUnreadFriendRequestStatus,
        "clearFriendRequest": this._clearFriendRequest,
        "deleteFriend": this._deleteFriend,
        "sendFriendRequest": this._sendFriendRequest,
        "handleFriendRequest": this._handleFriendRequest,
        "getFriendAlias": this._getFriendAlias,
        "setFriendAlias": this._setFriendAlias,
        "getFriendExtra": this._getFriendExtra,
        "isBlackListed": this._isBlackListed,
        "getBlackList": this._getBlackList,
        "setBlackList": this._setBlackList,
        "getGroupMembersByTypes": this._getGroupMembersByTypes,
        "getGroupMembersAsync": this._getGroupMembersAsync,
        "getGroupInfos": this._getGroupInfos,
        "getGroupInfoAsync": this._getGroupInfoAsync,
        "quitGroup": this._quitGroup,
        "quitGroupEx": this._quitGroupEx,
        "dismissGroup": this._dismissGroup,
        "modifyGroupInfo": this._modifyGroupInfo,
        "modifyGroupAlias": this._modifyGroupAlias,
        "modifyGroupMemberAlias": this._modifyGroupMemberAlias,
        "transferGroup": this._transferGroup,
        "setGroupManager": this._setGroupManager,
        "muteGroupMember": this._muteGroupMember,
        "allowGroupMember": this._allowGroupMember,
        "getGroupRemark": this._getGroupRemark,
        "setGroupRemark": this._setGroupRemark,
        "setFavGroup": this._setFavGroup,
        "getUserSetting": this._getUserSetting,
        "getUserSettings": this._getUserSettings,
        "setUserSetting": this._setUserSetting,
        "modifyMyInfo": this._modifyMyInfo,
        "isGlobalSilent": this._isGlobalSilent,
        "setGlobalSilent": this._setGlobalSilent,
        "isVoipNotificationSilent": this._isVoipNotificationSilent,
        "setVoipNotificationSilent": this._setVoipNotificationSilent,
        "isEnableSyncDraft": this._isEnableSyncDraft,
        "setEnableSyncDraft": this._setEnableSyncDraft,
        "getNoDisturbingTimes": this._getNoDisturbingTimes,
        "setNoDisturbingTimes": this._setNoDisturbingTimes,
        "clearNoDisturbingTimes": this._clearNoDisturbingTimes,
        "isNoDisturbing": this._isNoDisturbing,
        "isHiddenNotificationDetail": this._isHiddenNotificationDetail,
        "setHiddenNotificationDetail": this._setHiddenNotificationDetail,
        "setHiddenGroupMemberName": this._setHiddenGroupMemberName,
        "getMyGroups": this._getMyGroups,
        "getCommonGroups": this._getCommonGroups,
        "isUserEnableReceipt": this._isUserEnableReceipt,
        "setUserEnableReceipt": this._setUserEnableReceipt,
        "getFavUsers": this._getFavUsers,
        "isFavUser": this._isFavUser,
        "setFavUser": this._setFavUser,
        "joinChatroom": this._joinChatroom,
        "quitChatroom": this._quitChatroom,
        "getChatroomInfo": this._getChatroomInfo,
        "getChatroomMemberInfo": this._getChatroomMemberInfo,
        "createChannel": this._createChannel,
        "getChannelInfo": this._getChannelInfo,
        "modifyChannelInfo": this._modifyChannelInfo,
        "searchChannel": this._searchChannel,
        "isListenedChannel": this._isListenedChannel,
        "listenChannel": this._listenChannel,
        "getMyChannels": this._getMyChannels,
        "getRemoteListenedChannels": this._getRemoteListenedChannels,
        "destoryChannel": this._destoryChannel,
        "getOnlineInfos": this._getOnlineInfos,
        "kickoffPCClient": this._kickoffPCClient,
        "isMuteNotificationWhenPcOnline": this._isMuteNotificationWhenPcOnline,
        "muteNotificationWhenPcOnline": this._muteNotificationWhenPcOnline,
        "getUserOnlineState": this._getUserOnlineState,
        "getMyCustomState": this._getMyCustomState,
        "setMyCustomState": this._setMyCustomState,
        "watchOnlineState": this._watchOnlineState,
        "unwatchOnlineState": this._unwatchOnlineState,
        "isEnableUserOnlineState": this._isEnableUserOnlineState,
        "getConversationFiles": this._getConversationFiles,
        "getMyFiles": this._getMyFiles,
        "deleteFileRecord": this._deleteFileRecord,
        "searchFiles": this._searchFiles,
        "searchMyFiles": this._searchMyFiles,
        "getAuthorizedMediaUrl": this._getAuthorizedMediaUrl,
        "getAuthCode": this._getAuthCode,
        "configApplication": this._configApplication,
        "getWavData": this._getWavData,
        "beginTransaction": this._beginTransaction,
        "commitTransaction": this._commitTransaction,
        "rollbackTransaction": this._rollbackTransaction,
        "isCommercialServer": this._isCommercialServer,
        "isReceiptEnabled": this._isReceiptEnabled,
        "isGroupReceiptEnabled": this._isGroupReceiptEnabled,
        "isGlobalDisableSyncDraft": this._isGlobalDisableSyncDraft,
    }

    __callback2UI(method: string, args: object ) {
        this.channel?.invokeMethod(method, args)
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

    __conversationFromArgument(call:
        MethodCall, raw:
        boolean = false
    ):
        string {
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
            if (entry[1] instanceof Uint8Array) {
                try {
                    let str = buffer.from(entry[1]).toString('base64')
                    obj[entry[0]] = str;
                } catch (error) {
                    console.error(error)
                }
            } else {
                obj[entry[0]] = entry[1]
            }
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

    __messageMap2Str(map: Map<string, Object>): string {
        if (!map) {
            return ''
        } else {
            return json.stringify(this.__map2record(map))
        }
    }

    __getLongPara(call: MethodCall, key: string): string {
        if (call.argument(key)) {
            return (call.argument(key) as bigint).toString()
        }
        return '0'
    }
}
