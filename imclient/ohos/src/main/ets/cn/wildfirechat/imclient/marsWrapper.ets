import clientModule from '@wfc/marswrapper';
type StringCallback = (value: string) => void;
type VoidCallback = () => void;
type SuccessCallback = VoidCallback;
type FailCallback = (error: number) => void;
let wfcEventListener: null | ((value: object) => void) = null;

function initProto(dbPath: string): void {
    clientModule.setDBPath(dbPath);
    clientModule.setConnectionStatusListener(genWfcEventListener('onConnectionStatusChange'));
    clientModule.setConnectToServerListener(genWfcEventListener('onConnectToServer'));
    clientModule.setReceiveMessageListener(genWfcEventListener('onReceiveMessage'),
        genWfcEventListener('onRecallMessage'),
        genWfcEventListener('onDeleteMessage'),
        genWfcEventListener('onMessageDelivered'),
        genWfcEventListener('onMessageRead'));
    clientModule.setConferenceEventListener(genWfcEventListener('onConferenceEvent'));
    clientModule.setOnlineEventListener(genWfcEventListener('onUserOnlineEvent'));
    clientModule.setUserInfoUpdateListener(genWfcEventListener('onUserInfoUpdated'));
    clientModule.setFriendUpdateListener(genWfcEventListener('onFriendListUpdated'));
    clientModule.setFriendRequestListener(genWfcEventListener('onFriendRequestUpdated'));
    clientModule.setGroupInfoUpdateListener(genWfcEventListener('onGroupInfoUpdated'));
    clientModule.setSettingUpdateListener(genWfcEventListener('onSettingUpdated'));
    clientModule.setChannelInfoUpdateListener(genWfcEventListener('onChannelInfoUpdated'));
    clientModule.setGroupMemberUpdateListener(genWfcEventListener('onGroupMemberUpdated'));
    console.log('initProto end')
}
function setWfcEventListener(listener: (args: object) => void) {
    wfcEventListener = listener;
}
const getClientId = (): string =>{
    return clientModule.getClientId();
};
function connect(imHost: string, userId: string, token: string): void {
    clientModule.connect(userId, token);
}
function getConnectionStatus(): number {
    return clientModule.getConnectionStatus();
}
function registerMessageFlag(type: number, flag: number) {
    clientModule.registerMessageFlag(type, flag);
}
function useSM4() {
    clientModule.useSM4();
}
function setProxyInfo(host: string, ip: string, port: number, userName: string, password: string) {
    clientModule.setProxyInfo(host, ip, port, userName, password);
}
function disconnect(disablePush: boolean, clearSession: boolean) {
    clientModule.disconnect(disablePush, clearSession);
}
function addHttpHeader(header: string, value: string) {
    clientModule.addHttpHeader(header, value);
}
function addMembers(groupId: string, memberIds: string[], extra: string, notifyLines: number[], notifyContentStr: string, successCB: () => void, failCB: FailCallback) {
    clientModule.addMembers(memberIds, groupId, extra, notifyLines, notifyContentStr, (_: object)=>{
        successCB();
    }, failCB);
}
function getConversationInfos(types: number[], lines: number[]): string {
    return clientModule.getConversationInfos(types, lines);
}
function getUserSettings(scope: number): string {
    return clientModule.getUserSettings(scope);
}
function getGroupInfo(groupId: string, fresh: boolean): string {
    return clientModule.getGroupInfo(groupId, fresh);
}
function getGroupInfoEx(groupId: string, fresh: boolean, successCB: StringCallback, failCB: FailCallback): void {
    clientModule.getGroupInfoEx(groupId, fresh, stringCallback(successCB), numberCallback(failCB));
}
function getUserInfo(userId: string, fresh: boolean, groupId: string): string {
    return clientModule.getUserInfo(userId, fresh, groupId);
}
function getGroupMembers(groupId: string, fresh: boolean): string {
    return clientModule.getGroupMembers(groupId, fresh);
}

function getGroupMembersByCount(groupId: string, count: number): string {
    return clientModule.getGroupMembersByCount(groupId, count);
}

function getUserInfos(userIds: string[], groupId: string): string {
    return clientModule.getUserInfos(userIds, groupId);
}
function getConversationInfo(conversation: string): string {
    return clientModule.getConversationInfo(conversation);
}
function getListenedChannels(): string {
    return "";
}
function getChannelInfo(channelId: string, refresh: boolean): string {
    return clientModule.getChannelInfo(channelId, refresh);
}
function getMyFriendList(fresh: boolean): string {
    return clientModule.getMyFriendList(fresh);
}
function getFavGroups(): string {
    return clientModule.getFavGroups();
}
function getFavUsers(): string {
    return clientModule.getFavUsers();
}
function getIncommingFriendRequest(): string {
    return clientModule.getIncommingFriendRequest();
}
function getGroupInfos(groupIds: string[], fresh: boolean): string {
    return clientModule.getGroupInfos(groupIds, fresh);
}
function getUnreadFriendRequestStatus(): number {
    return clientModule.getUnreadFriendRequestStatus();
}
function isFavGroup(groupId: string): boolean {
    return clientModule.isFavGroup(groupId) === 1;
}
function getAuthCode(appId: string, appType: number, host: string, successCB: StringCallback, failCB: FailCallback) {
    clientModule.getAuthCode(appId, appType, host, (value: string)=>{
        successCB(value);
    }, failCB);
}
function isMyFriend(userId: string): boolean {
    return clientModule.isMyFriend(userId) === 1;
}
function isReceiptEnabled(): boolean {
    return clientModule.isReceiptEnabled() === 1;
}
function watchOnlineState(conversationType: number, targets: string[], duration: number, successCB: StringCallback, failCB: FailCallback): void {
    clientModule.watchOnlineState(conversationType, targets, duration, stringCallback(successCB), numberCallback(failCB));
}
function isSupportBigFilesUpload(): boolean {
    return clientModule.isSupportBigFilesUpload() === 1;
}
function isUserReceiptEnabled(): boolean {
    return clientModule.isUserReceiptEnabled() === 1;
}
function allowGroupMember(groupId: string, isSet: boolean, memberIds: string[], notifyLines: number[], notifyContentStr: string, successCB: VoidCallback, failCB: FailCallback): void {
    clientModule.allowGroupMember(groupId, isSet, memberIds, notifyLines, notifyContentStr, voidCallback(successCB), numberCallback(failCB));
}
function clearAllNotification(): void {}
function clearAllUnreadStatus(): void {
    clientModule.clearAllUnreadStatus();
}
function clearMessages(conversation: string): void {
    clientModule.clearMessages(conversation);
}
function clearMessagesByTime(conversation: string, before: number): void {
    clientModule.clearMessagesByTime(conversation, before);
}
function clearRemoteConversationMessages(conversation: string, successCB: SuccessCallback, failCB: FailCallback): void {
    clientModule.clearRemoteConversationMessages(conversation, voidCallback(successCB), numberCallback(failCB));
}
function clearUnreadFriendRequestStatus(): void {
    clientModule.clearUnreadFriendRequestStatus();
}
function clearUnreadStatus(conversation: string): void {
    clientModule.clearUnreadStatus(conversation);
}
function configApplication(appId: string, appType: number, timestamp: number, nonceStr: string, signature: string, successCB: VoidCallback, failCB: FailCallback): void {
    clientModule.configApplication(appId, appType, timestamp, nonceStr, signature, voidCallback(successCB), numberCallback(failCB));
}
function createChannel(name: string, portrait: string, status: number, desc: string, extra: string, successCB: StringCallback, failCB: FailCallback): void {
    clientModule.createChannel(name, portrait, status, desc, extra, stringCallback(successCB), numberCallback(failCB));
}
function createGroup(groupId: string, groupType: number, name: string, portrait: string, groupExtra: string, memberIds: string[], memberExtra: string, lines: number[], notifyContentStr: string, successCB: StringCallback, failCB: FailCallback): void {
    clientModule.createGroup(groupId, groupType, name, portrait, groupExtra, memberIds, memberExtra, lines, notifyContentStr, stringCallback(successCB), numberCallback(failCB));
}
function deleteFileRecord(messageUid: string, successCB: SuccessCallback, failCB: FailCallback): void {
    clientModule.deleteFileRecord(messageUid, voidCallback(successCB), numberCallback(failCB));
}
function getMessagesV2(conversation: string, fromIndex: number, before: boolean, count: number, withUser: string, successCB: StringCallback, failCB: FailCallback): void {
    clientModule.getMessagesV2(conversation, [], fromIndex, before, count, withUser, stringCallback(successCB), numberCallback(failCB));
}
function getConversationRead(conversation: string): string {
    return clientModule.getConversationRead(conversation);
}
function deleteFriend(userId: string, successCB: SuccessCallback, failCB: FailCallback): void {
    clientModule.deleteFriend(userId, voidCallback(successCB), numberCallback(failCB));
}
function deleteMessage(messageId: number): void {
    clientModule.deleteMessage(messageId);
}
function deleteRemoteMessage(messageUid: string, successCB: SuccessCallback, failCB: FailCallback): void {
    clientModule.deleteRemoteMessage(messageUid, voidCallback(successCB), numberCallback(failCB));
}
function destoryChannel(channelId: string, successCB: SuccessCallback, failCB: FailCallback): void {
    clientModule.destoryChannel(channelId, voidCallback(successCB), numberCallback(failCB));
}
function dismissGroup(groupId: string, lines: number[], messagePayload: string, successCB: SuccessCallback, failCB: FailCallback): void {
    clientModule.dismissGroup(groupId, lines, messagePayload, voidCallback(successCB), numberCallback(failCB));
}
function getAuthorizedMediaUrl(messaggeUid: string, mediaType: number, mediaPath: string, successCB: (value: object) => void, failCB: FailCallback): void {
    clientModule.getAuthorizedMediaUrl(messaggeUid, mediaType, mediaPath, variableParamsToArrayParamCallback(successCB), numberCallback(failCB));
}
function getBlackList(refresh: boolean): string {
    return clientModule.getBlackList(refresh);
}
function getChatroomInfo(chatroomId: string, updateDt: number, successCB: StringCallback, failCB: FailCallback): void {
    clientModule.getChatroomInfo(chatroomId, String(updateDt), stringCallback(successCB), numberCallback(failCB));
}
function getChatroomMemberInfo(chatroomId: string, maxCount: number, successCB: StringCallback, failCB: FailCallback): void {
    clientModule.getChatroomMemberInfo(chatroomId, maxCount, stringCallback(successCB), numberCallback(failCB));
}
function getConversationFiles(conversation: string, fromUser: string, beforeUid: string, count: number, order:number, successCB: StringCallback, failCB: FailCallback): void {
    clientModule.getConversationFiles(conversation, fromUser, beforeUid, count, order, stringCallback(successCB), numberCallback(failCB));
}
function getConversationFirstUnreadMessageId(conversation: string): number {
    return clientModule.getConversationFirstUnreadMessageId(conversation);
}
function getConversationUnreadCount(conversation: string): string {
    return clientModule.getConversationUnreadCount(conversation);
}
function getFriendAlias(userId: string): string {
    return clientModule.getFriendAlias(userId);
}
function getFriendList(fresh: boolean): string {
    return clientModule.getFriendList(fresh);
}
function getMyFiles(beforeUid: string, count: number, successCB: StringCallback, failCB: FailCallback): void {
    clientModule.getMyFiles(beforeUid, 1, count, stringCallback(successCB), numberCallback(failCB));
}
function getOutgoingFriendRequest(): string {
    return clientModule.getOutgoingFriendRequest();
}
function getRemoteMessage(messageUid: string, successCB: StringCallback, failCB: FailCallback): void {
    clientModule.getRemoteMessage(messageUid, stringCallback(successCB), numberCallback(failCB));
}
function getRemoteMessages(conversation: string, beforeUid: string, count: number, successCB: StringCallback, failCB: FailCallback): void {
    clientModule.getRemoteMessages(conversation, beforeUid, count, stringCallback(successCB), numberCallback(failCB), []);
}
function getServerDeltaTime(): number {
    return clientModule.getServerDeltaTime();
}
function getUnreadCount(types: number[], lines: number[]): string {
    return clientModule.getUnreadCount(types, lines);
}
function getUploadMediaUrl(fileName: string, mediaType: number, contentType: string, successCB: (value: object) => void, failCB: FailCallback): void {
    clientModule.getUploadMediaUrl(fileName, mediaType, contentType, variableParamsToArrayParamCallback(successCB), numberCallback(failCB));
}
function getUserInfoEx(userId: string, refresh: boolean, successCB: StringCallback, failCB: FailCallback): void {
    clientModule.getUserInfoEx(userId, refresh, stringCallback(successCB), numberCallback(failCB));
}
function getUserMessages(userId: string, conversation: string, contentTypes: number[], fromIndex: number, before: boolean, count: number): string {
    return "";
}
function getUserMessagesEx(userId: string, conversationTypes: number[], lines: number[], contentTypes: number[], fromIndex: number, before: boolean, count: number): string {
    return "";
}
function getUserMessagesExV2(userId: string, conversationTypes: number[], lines: number[], fromIndex: number, before: boolean, count: number, contentTypes: number[], successCB: StringCallback, failCB: FailCallback): void {
    clientModule.getUserMessagesExV2(userId, conversationTypes, lines, contentTypes, fromIndex, before, count, '', stringCallback(successCB), numberCallback(failCB));
}
function getUserMessagesV2(userId: string, conversation: string, fromIndex: number, before: boolean, count: number, successCB: StringCallback, failCB: FailCallback): void {
    clientModule.getUserMessagesV2(userId, conversation, [], fromIndex, before, count, '', stringCallback(successCB), numberCallback(failCB));
}
function getUserSetting(scope: number, key: string): string {
    return clientModule.getUserSetting(scope, key);
}
function handleFriendRequest(userId: string, accept: boolean, successCB: VoidCallback, failCB: FailCallback, extra: string): void {
    clientModule.handleFriendRequest(userId, accept, voidCallback(successCB), numberCallback(failCB), extra);
}
function insertMessage(conversation: string, sender: string, messagePayload: string, status: number, notify: boolean, toUsers: string[], serverTime: number): string{
    return clientModule.insertMessage(conversation, sender, messagePayload, status, notify, toUsers, serverTime);
}
function isBlackListed(userId: string): boolean {
    return clientModule.isBlackListed(userId) === 1;
}
function isCommercialServer(): boolean {
    return clientModule.isCommercialServer() === 1;
}
function isEnableUserOnlineState(): boolean {
    return clientModule.isEnableUserOnlineState() === 1;
}
function isFavUser(userId: string): boolean {
    return clientModule.isFavUser(userId) === 1;
}
function isGlobalDisableSyncDraft(): boolean {
    return clientModule.isGlobalDisableSyncDraft() === 1;
}
function setDisableSyncDraft(disable: boolean, successCB: VoidCallback, failCB: FailCallback) {
    clientModule.setUserSetting(20, '', disable ? '1' : '0', successCB, failCB)
}
function isGlobalSlient(): boolean {
    return false;
}
function isHiddenNotificationDetail(): boolean {
    return clientModule.isHiddenNotificationDetail() === 1;
}
function isListenedChannel(channelId: string): boolean {
    return clientModule.isListenedChannel(channelId) === 1;
}
function joinChatroom(chatroomId: string, successCB: VoidCallback, failCB: FailCallback): void {
    clientModule.joinChatroom(chatroomId, voidCallback(successCB), numberCallback(failCB));
}
function kickoffMembers(groupId: string, memberIds: string[], notifyLines: number[], messagePayload: string, successCB: VoidCallback, failCB: FailCallback): void {
    clientModule.kickoffMembers(groupId, memberIds, notifyLines, messagePayload, voidCallback(successCB), numberCallback(failCB));
}
function listenChannel(channelId: string, listen: boolean, successCB: VoidCallback, failCB: FailCallback): void {
    clientModule.listenChannel(channelId, listen, voidCallback(successCB), numberCallback(failCB));
}
function loadFriendRequestFromRemote(): void {
    clientModule.loadFriendRequestFromRemote();
}
function modifyChannelInfo(channelId: string, type: number, newValue: string, successCB: VoidCallback, failCB: FailCallback): void {
    clientModule.modifyChannelInfo(channelId, type, newValue, voidCallback(successCB), numberCallback(failCB));
}
function modifyGroupAlias(groupId: string, alias: string, lines: number[], messagePayload: string, successCB: VoidCallback, failCB: FailCallback): void {
    clientModule.modifyGroupAlias(groupId, alias, lines, messagePayload, voidCallback(successCB), numberCallback(failCB));
}
function modifyGroupInfo(groupId: string, type: number, newValue: string, lines: number[], messagePayload: string, successCB: VoidCallback, failCB: FailCallback): void {
    clientModule.modifyGroupInfo(groupId, type, newValue, lines, messagePayload, voidCallback(successCB), numberCallback(failCB));
}
function modifyGroupMemberAlias(groupId: string, memberId: string, alias: string, lines: number[], messagePayload: string, successCB: VoidCallback, failCB: FailCallback): void {
    clientModule.modifyGroupMemberAlias(groupId, memberId, alias, lines, messagePayload, voidCallback(successCB), numberCallback(failCB));
}
function modifyGroupMemberExtra(groupId: string, memberId: string, extra: string, lines: number[], messagePayload: string, successCB: VoidCallback, failCB: FailCallback): void {
    clientModule.modifyGroupMemberExtra(groupId, memberId, extra, lines, messagePayload, voidCallback(successCB), numberCallback(failCB));
}
function modifyMyInfo(type: number, value: string, successCB: VoidCallback, failCB: FailCallback): void {
    clientModule.modifyMyInfo(type, value, voidCallback(successCB), numberCallback(failCB));
}
function muteGroupMember(groupId: string, isSet: boolean, memberIds: string[], notifyLines: number[], messagePayload: string, successCB: VoidCallback, failCB: FailCallback): void {
    clientModule.muteGroupMember(groupId, isSet, memberIds, notifyLines, messagePayload, voidCallback(successCB), numberCallback(failCB));
}
function quitChatroom(chatroomId: string, successCB: VoidCallback, failCB: FailCallback): void {
    clientModule.quitChatroom(chatroomId, voidCallback(successCB), numberCallback(failCB));
}
function quitGroup(groupId: string, lines: number[], messagePayload: string, successCB: VoidCallback, failCB: FailCallback): void {
    clientModule.quitGroup(groupId, lines, messagePayload, voidCallback(successCB), numberCallback(failCB));
}
function quitGroupEx(groupId: string, keepMessage: boolean, lines: number[], messagePayload: string, successCB: VoidCallback, failCB: FailCallback): void {
    failCB?.(-1);
}
function recall(messageUid: string, successCB: VoidCallback, failCB: FailCallback): void {
    clientModule.recall(messageUid, voidCallback(successCB), numberCallback(failCB));
}
function removeConversation(conversation: string, clearMsg: boolean): void {
    clientModule.removeConversation(conversation, clearMsg);
}
function searchChannel(keyword: string, successCB: StringCallback, failCB: FailCallback): void {
    clientModule.searchChannel(keyword, stringCallback(successCB), numberCallback(failCB));
}
function searchConversation(keyword: string, types: number[], lines: number[]): string {
    return clientModule.searchConversation(keyword, types, lines);
}
function searchFiles(keyword: string, conversation: string, fromUser: string, beforeMessageId: string, count: number, successCB: StringCallback, failCB: FailCallback): void {
    clientModule.searchFiles(keyword, conversation, fromUser, beforeMessageId, 1, count, stringCallback(successCB), numberCallback(failCB));
}
function searchFriends(keyword: string): string {
    return clientModule.searchFriends(keyword);
}
function searchGroups(keyword: string): string {
    return clientModule.searchGroups(keyword);
}
function searchMessage(conversation: string, keyword: string, withUser: string): string {
    return clientModule.searchMessage(conversation, keyword, withUser);
}
function searchMessageByTypes(conversation: string, keyword: string, contentTypes: number[], desc: boolean, limit: number, offset: number, withUser: string): string {
    return clientModule.searchMessageByTypes(conversation, keyword, contentTypes, desc, limit, offset, withUser);
}
function searchMessageByTypesAndTimes(conversation: string, keyword: string, contentTypes: number[], startTime: number, endTime: number, desc: boolean, limit: number, offset: number, withUser: string): string {
    return clientModule.searchMessageByTypesAndTimes(conversation, keyword, contentTypes, startTime, endTime, desc, limit, offset, withUser);
}
function searchMessageEx(conversation: string, keyword: string, desc: boolean, limit: number, offset: number, withUser: string): string {
    return clientModule.searchMessageEx(conversation, keyword, desc, limit, offset, withUser);
}
function searchMessageEx2(conversationTypes: number[], lines: number[], contentTypes: number[], keyword: string, fromIndex: number, desc: boolean, count: number, withUser: string): string {
    return clientModule.searchMessageEx2(conversationTypes, lines, contentTypes, keyword, fromIndex, desc, count, withUser);
}
function searchMyFiles(keyword: string, beforeMessageUid: string, order:number, count: number, successCB: StringCallback, failCB: FailCallback): void {
    clientModule.searchMyFiles(keyword, beforeMessageUid, order, count, stringCallback(successCB), numberCallback(failCB));
}
function searchUser(keyword: string, searchType: number, page: number, successCB: StringCallback, failCB: FailCallback): void {
    clientModule.searchUser(keyword, searchType, page, stringCallback(successCB), numberCallback(failCB));
}
function sendConferenceRequest(sessionId: string, roomId: string, request: string, data: string, advance: boolean, successCB: VoidCallback, failCB: FailCallback): void {
    clientModule.sendConferenceRequest(sessionId, roomId, request, data, voidCallback(successCB), numberCallback(failCB), advance);
}
function sendFriendRequest(userId: string, reason: string, extra: string, successCB: VoidCallback, failCB: FailCallback): void {
    clientModule.sendFriendRequest(userId, reason, extra, voidCallback(successCB), numberCallback(failCB));
}
function sendMessage(conversation: string, messagePayload: string, toUsers: string[], expireDuration: number, prepareCB: (value: object) => void, progressCB: (value: object) => void, successCB: (value: object) => void, failCB: FailCallback, mediaUpload:StringCallback) : void {
    clientModule.sendMessage(conversation, messagePayload, toUsers, expireDuration, variableParamsToArrayParamCallback(prepareCB), variableParamsToArrayParamCallback(progressCB), stringCallback(mediaUpload), variableParamsToArrayParamCallback(successCB), numberCallback(failCB));
}
function setBackupAddress(backupHost: string, backupPort: number): void {
    clientModule.setBackupAddress(backupHost, backupPort);
}
function setBackupAddressStrategy(strategy: number): void {
    clientModule.setBackupAddressStrategy(strategy);
}
function setBlackList(userId: string, block: boolean, successCB: VoidCallback, failCB: FailCallback): void {
    clientModule.setBlackList(userId, block, voidCallback(successCB), numberCallback(failCB));
}
function setConversationDraft(conversation: string, draft: string): void {
    clientModule.setConversationDraft(conversation, draft);
}
function setConversationSlient(conversation: string, silent: boolean, successCB: VoidCallback, failCB: FailCallback): void {
    clientModule.setConversationSilent(conversation, silent, voidCallback(successCB), numberCallback(failCB));
}
function setConversationTimestamp(conversation: string, timestamp: string): void {
    clientModule.setConversationTimestamp(conversation, Number(timestamp));
}
function setConversationTop(conversation: string, top: number, successCB: VoidCallback, failCB: FailCallback): void {
    clientModule.setConversationTop(conversation, top, voidCallback(successCB), numberCallback(failCB));
}
function setDeviceToken(type: number, token: string): void {
    clientModule.setDeviceToken(type, token);
}
function setFavGroup(groupId: string, fav: boolean, successCB: VoidCallback, failCB: FailCallback): void {
    clientModule.setFavGroup(groupId, fav, voidCallback(successCB), numberCallback(failCB));
}
function setFavUser(userId: string, fav: boolean, successCB: VoidCallback, failCB: FailCallback): void {
    clientModule.setFavUser(userId, fav, voidCallback(successCB), numberCallback(failCB));
}
function setFriendAlias(userId: string, alias: string, successCB: VoidCallback, failCB: FailCallback): void {
    clientModule.setFriendAlias(userId, alias, voidCallback(successCB), numberCallback(failCB));
}
function setGlobalSlient(silent: boolean, successCB: VoidCallback, failCB: FailCallback): void {
    clientModule.setGlobalSilent(silent, voidCallback(successCB), numberCallback(failCB));
}
function setGroupManager(groupId: string, isSet: boolean, memberIds: string[], lines: number[], notifyContentStr: string, successCB: VoidCallback, failCB: FailCallback): void {
    clientModule.setGroupManager(groupId, isSet, memberIds, lines, notifyContentStr, voidCallback(successCB), numberCallback(failCB));
}
function setHiddenNotificationDetail(hide: boolean, successCB: VoidCallback, failCB: FailCallback): void {
    clientModule.setHiddenNotificationDetail(hide, voidCallback(successCB), numberCallback(failCB));
}
function setLastReceivedMessageUnRead(conversation: string, messageUid: string, timestamp: string): void {
    clientModule.setLastReceivedMessageUnRead(conversation);
}
function setMediaMessagePlayed(messageId: number): void {
    clientModule.setMediaMessagePlayed(messageId);
}
function setMessageLocalExtra(messageId: number, extra: string): void {
    clientModule.setMessageLocalExtra(messageId, extra);
}
function setUserAgent(userAgent: string): void {
    clientModule.setUserAgent(userAgent);
}
function setUserReceiptEnable(enable: boolean, successCB: VoidCallback, failCB: FailCallback): void {
    clientModule.setUserReceiptEnable(enable, voidCallback(successCB), numberCallback(failCB));
}
function setUserSetting(scope: number, key: string, value: string, successCB: VoidCallback, failCB: FailCallback): void {
    clientModule.setUserSetting(scope, key, value, voidCallback(successCB), numberCallback(failCB));
}
function transferGroup(groupId: string, newOwner: string, lines: number[], messagePayload: string, successCB: VoidCallback, failCB: FailCallback): void {
    clientModule.transferGroup(groupId, newOwner, lines, messagePayload, voidCallback(successCB), numberCallback(failCB));
}
function unwatchOnlineState(conversationType: number, targets: string[], successCB: VoidCallback, failCB: FailCallback): void {
    clientModule.unwatchOnlineState(conversationType, targets, voidCallback(successCB), numberCallback(failCB));
}
function updateMessage(messageId: number, messagePayload: string): void {
    clientModule.updateMessage(messageId, messagePayload);
}
function updateMessageStatus(messageId: number, status: number): void {
    clientModule.updateMessageStatus(messageId, status);
}
function updateRemoteMessageContent(messageUid: string, messagePayload: string, distribute: boolean, updateLocal: boolean, successCB: VoidCallback, failCB: FailCallback): void {
    clientModule.updateRemoteMessageContent(messageUid, messagePayload, distribute, updateLocal, voidCallback(successCB), numberCallback(failCB));
}
function uploadMedia(fileName: string, data: string, mediaType: number, successCB: StringCallback, failCB: FailCallback, progressCB: (value: object) => void): void {
    clientModule.uploadMedia(fileName, data, mediaType, stringCallback(successCB), numberCallback(failCB), progressCB);
}
function getMessage(messageId: number): string {
    return clientModule.getMessage(messageId);
}
function getMessageByUid(messageUid: string): string {
    return clientModule.getMessageByUid(messageUid);
}
function getGroupMember(groupId: string, memberId: string): string {
    return clientModule.getGroupMember(groupId, memberId);
}
function voidCallback(cb: VoidCallback): (value: object) => void {
    return (_: object | null = null)=>{
        cb();
    };
}
function stringCallback(cb: StringCallback): (value: string) => void {
    return (value: string)=>{
        cb(value as string);
    };
}
function numberCallback(cb: FailCallback): (value: number) => void {
    return (value: number)=>{
        cb(value as number);
    };
}
function genWfcEventListener(event: string): (...args: Object[]) => void {
    return (...params: Object[])=>{
        let args: Object[] = [
            event
        ];
        args.push(...params);
        let obj = {
            'args': args
        } as Record<string, Object>;
        wfcEventListener?.(obj);
    };
}

function variableParamsToArrayParamCallback(cb: (value: object) => void) {
    return (...params: object[])=>{
        cb(params);
    };
}
export { initProto as initProto };
export { setWfcEventListener as setWfcEventListener };
export { getClientId as getClientId };
export { connect as connect };
export { getConnectionStatus as getConnectionStatus };
export { registerMessageFlag as registerMessageFlag };
export { useSM4 as useSM4 };
export { setProxyInfo as setProxyInfo };
export { disconnect as disconnect };
export { addHttpHeader as addHttpHeader };
export { addMembers as addMembers };
export { getConversationInfos as getConversationInfos };
export { getUserSettings as getUserSettings };
export { getGroupInfo as getGroupInfo };
export { getUserInfo as getUserInfo };
export { getGroupMembers as getGroupMembers };
export { getGroupMembersByCount as getGroupMembersByCount };
export { getUserInfos as getUserInfos };
export { getConversationInfo as getConversationInfo };
export { getListenedChannels as getListenedChannels };
export { getChannelInfo as getChannelInfo };
export { getMyFriendList as getMyFriendList };
export { getFavGroups as getFavGroups };
export { getFavUsers as getFavUsers };
export { getIncommingFriendRequest as getIncommingFriendRequest };
export { getGroupInfos as getGroupInfos };
export { getUnreadFriendRequestStatus as getUnreadFriendRequestStatus };
export { isFavGroup as isFavGroup };
export { getAuthCode as getAuthCode };
export { isMyFriend as isMyFriend };
export { isReceiptEnabled as isReceiptEnabled };
export { watchOnlineState as watchOnlineState };
export { isSupportBigFilesUpload as isSupportBigFilesUpload };
export { isUserReceiptEnabled as isUserReceiptEnabled };
export { allowGroupMember as allowGroupMember };
export { clearAllNotification as clearAllNotification };
export { clearAllUnreadStatus as clearAllUnreadStatus };
export { clearMessages as clearMessages };
export { clearMessagesByTime as clearMessagesByTime };
export { clearRemoteConversationMessages as clearRemoteConversationMessages };
export { clearUnreadFriendRequestStatus as clearUnreadFriendRequestStatus };
export { clearUnreadStatus as clearUnreadStatus };
export { configApplication as configApplication };
export { createChannel as createChannel };
export { createGroup as createGroup };
export { deleteFileRecord as deleteFileRecord };
export { getMessagesV2 as getMessagesV2 };
export { getConversationRead as getConversationRead };
export { deleteFriend as deleteFriend };
export { deleteMessage as deleteMessage };
export { deleteRemoteMessage as deleteRemoteMessage };
export { destoryChannel as destoryChannel };
export { dismissGroup as dismissGroup };
export { getAuthorizedMediaUrl as getAuthorizedMediaUrl };
export { getBlackList as getBlackList };
export { getChatroomInfo as getChatroomInfo };
export { getChatroomMemberInfo as getChatroomMemberInfo };
export { getConversationFiles as getConversationFiles };
export { getConversationFirstUnreadMessageId as getConversationFirstUnreadMessageId };
export { getConversationUnreadCount as getConversationUnreadCount };
export { getFriendAlias as getFriendAlias };
export { getFriendList as getFriendList };
export { getMyFiles as getMyFiles };
export { getOutgoingFriendRequest as getOutgoingFriendRequest };
export { getRemoteMessage as getRemoteMessage };
export { getRemoteMessages as getRemoteMessages };
export { getServerDeltaTime as getServerDeltaTime };
export { getUnreadCount as getUnreadCount };
export { getUploadMediaUrl as getUploadMediaUrl };
export { getUserInfoEx as getUserInfoEx };
export { getUserMessages as getUserMessages };
export { getUserMessagesEx as getUserMessagesEx };
export { getUserMessagesExV2 as getUserMessagesExV2 };
export { getUserMessagesV2 as getUserMessagesV2 };
export { getUserSetting as getUserSetting };
export { handleFriendRequest as handleFriendRequest };
export { insertMessage as insertMessage };
export { isBlackListed as isBlackListed };
export { isCommercialServer as isCommercialServer };
export { isEnableUserOnlineState as isEnableUserOnlineState };
export { isFavUser as isFavUser };
export { isGlobalDisableSyncDraft as isGlobalDisableSyncDraft };
export { setDisableSyncDraft as setDisableSyncDraft };
export { isGlobalSlient as isGlobalSlient };
export { isHiddenNotificationDetail as isHiddenNotificationDetail };
export { isListenedChannel as isListenedChannel };
export { joinChatroom as joinChatroom };
export { kickoffMembers as kickoffMembers };
export { listenChannel as listenChannel };
export { loadFriendRequestFromRemote as loadFriendRequestFromRemote };
export { modifyChannelInfo as modifyChannelInfo };
export { modifyGroupAlias as modifyGroupAlias };
export { modifyGroupInfo as modifyGroupInfo };
export { modifyGroupMemberAlias as modifyGroupMemberAlias };
export { modifyGroupMemberExtra as modifyGroupMemberExtra };
export { modifyMyInfo as modifyMyInfo };
export { muteGroupMember as muteGroupMember };
export { quitChatroom as quitChatroom };
export { quitGroup as quitGroup };
export { quitGroupEx as quitGroupEx };
export { recall as recall };
export { removeConversation as removeConversation };
export { searchChannel as searchChannel };
export { searchConversation as searchConversation };
export { searchFiles as searchFiles };
export { searchFriends as searchFriends };
export { searchGroups as searchGroups };
export { searchMessage as searchMessage };
export { searchMessageByTypes as searchMessageByTypes };
export { searchMessageByTypesAndTimes as searchMessageByTypesAndTimes };
export { searchMessageEx as searchMessageEx };
export { searchMessageEx2 as searchMessageEx2 };
export { searchMyFiles as searchMyFiles };
export { searchUser as searchUser };
export { sendConferenceRequest as sendConferenceRequest };
export { sendFriendRequest as sendFriendRequest };
export { sendMessage as sendMessage };
export { setBackupAddress as setBackupAddress };
export { setBackupAddressStrategy as setBackupAddressStrategy };
export { setBlackList as setBlackList };
export { setConversationDraft as setConversationDraft };
export { setConversationSlient as setConversationSlient };
export { setConversationTimestamp as setConversationTimestamp };
export { setConversationTop as setConversationTop };
export { setDeviceToken as setDeviceToken };
export { setFavGroup as setFavGroup };
export { setFavUser as setFavUser };
export { setFriendAlias as setFriendAlias };
export { setGlobalSlient as setGlobalSlient };
export { setGroupManager as setGroupManager };
export { setHiddenNotificationDetail as setHiddenNotificationDetail };
export { setLastReceivedMessageUnRead as setLastReceivedMessageUnRead };
export { setMediaMessagePlayed as setMediaMessagePlayed };
export { setMessageLocalExtra as setMessageLocalExtra };
export { setUserAgent as setUserAgent };
export { setUserReceiptEnable as setUserReceiptEnable };
export { setUserSetting as setUserSetting };
export { transferGroup as transferGroup };
export { unwatchOnlineState as unwatchOnlineState };
export { updateMessage as updateMessage };
export { updateMessageStatus as updateMessageStatus };
export { updateRemoteMessageContent as updateRemoteMessageContent };
export { uploadMedia as uploadMedia };
export { getMessage as getMessage };
export { getMessageByUid as getMessageByUid };
export { getGroupMember as getGroupMember };
export { getGroupInfoEx as getGroupInfoEx };
