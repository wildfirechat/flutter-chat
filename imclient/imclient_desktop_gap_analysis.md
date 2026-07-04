# imclient desktop gap analysis

Generated from `imclient/scripts/dart_methods.txt` vs macOS / Linux / Windows native plugins.

## Legend

- **Implemented** — handler is registered and calls the WFClient SDK.
- **Stub (NotImplemented)** — handler is registered but returns `NotImplemented` / `FlutterMethodNotImplemented`.
- **Stub (dummy)** — handler is registered but returns a hard-coded value (`nil`/`false`/`[]`/``) without calling the SDK.
- **Missing** — no dispatch entry (none found in this scan).

## Totals

- Dart methods analyzed: **188**
- All desktop platforms missing/stubbed: **60**
- At least one desktop platform implemented (includes fully/partially implemented): **128**
- macOS implemented: 126, stub/dummy: 62
- Linux implemented: 128, stub/dummy/missing: 60
- Windows implemented: 128, stub/dummy/missing: 60

## A. All desktop platforms missing or stubbed

| Method | macOS status | Linux status | Windows status | iOS / Android reference summary |
|---|---|---|---|---|
| `batchDeleteMessages` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService batchDeleteMessages:…]; Android: ChatManager.batchDeleteMessages(messageUids) |
| `clearFriendRequest` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService clearFriendRequest:…]; Android: ChatManager.clearFriendRequest(direction == 1, beforeTime) |
| `clearMessagesKeepLatest` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService clearMessages:…]; Android: ChatManager.clearMessagesKeepLatest(conversation, keepCount) |
| `clearNoDisturbingTimes` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService clearNoDisturbingTimes:…]; Android: ChatManager.clearNoDisturbingTimes(new GeneralVoidCallback(requestId)) |
| `clearRemoteConversationMessage` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService clearRemoteConversationMessage:…]; Android: ChatManager.clearRemoteConversationMessage(conversation, new GeneralVoidCallback(requestId)) |
| `configApplication` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService configApplication:…]; Android: ChatManager.configApplication(applicationId, type, timestamp, nonce, signature, new Gen…) |
| `deleteFileRecord` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService deleteFileRecord:…]; Android: ChatManager.deleteFileRecord(messageUid, new GeneralVoidCallback(requestId)) |
| `deleteFriendRequest` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService deleteFriendRequest:…]; Android: ChatManager.deleteFriendRequest(userId, direction == 1) |
| `deleteRemoteMessage` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService deleteRemoteMessage:…]; Android: ChatManager.deleteRemoteMessage(messageUid, new GeneralVoidCallback(requestId)) |
| `getAuthCode` | Stub (dummy) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService getAuthCode:…]; Android: ChatManager.getAuthCode(applicationId, type, host, new GeneralStringCallback(requ…) |
| `getCommonGroups` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService getCommonGroups:…]; Android: ChatManager.getCommonGroups(userId, new StringListCallback() { @Override public void …) |
| `getConversationFiles` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService getConversationFiles:…]; Android: ChatManager.getConversationFileRecords(conversation, userId, beforeMessageUid, FileRecordOrder.t…) |
| `getFriends` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService getFriendList:…]; Android: ChatManager.getFriendList(refresh) |
| `getGroupRemark` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService getGroupRemark:…]; Android: ChatManager.getGroupRemark(groupId) |
| `getJoinedChatroomId` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService getJoinedChatroomId:…]; Android: ChatManager.getJoinedChatroom() |
| `getLogFilesPath` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCNetworkService getLogFilesPath:…]; Android: ChatManager.getLogFilesPath() |
| `getMessageCount` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService getMessageCount:…]; Android: ChatManager.getMessageCount(conversation) |
| `getMyCustomState` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService getMyCustomState:…]; Android: ChatManager.getMyCustomState() |
| `getMyFiles` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService getMyFiles:…]; Android: ChatManager.getMyFileRecords(beforeMessageUid, FileRecordOrder.type(order), count, new…) |
| `getMyGroups` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService getMyGroups:…]; Android: ChatManager.getMyGroups(new StringListCallback() { @Override public void onSucces…) |
| `getNoDisturbingTimes` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService getNoDisturbingTimes:…]; Android: ChatManager.getNoDisturbingTimes(new ChatManager.GetNoDisturbingTimesCallback() { @Overrid…) |
| `getOnlineInfos` | Stub (dummy) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService getPCOnlineInfos:…]; Android: ChatManager.getPCOnlineInfos() |
| `getRemoteMessage` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService getRemoteMessage:…]; Android: ChatManager.getRemoteMessage(messageUid, new GetOneRemoteMessageCallback() { @Override…) |
| `getUploadUrl` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: not implemented; Android: not implemented |
| `getUserOnlineState` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService getUserOnlineState:…]; Android: ChatManager.getUserOnlineState(userId) |
| `getWavData` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService getWavData:…]; Android: result.success(null) |
| `isCommercialServer` | Stub (dummy) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService isCommercialServer:…]; Android: ChatManager.isCommercialServer() |
| `isEnableSyncDraft` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService isEnableSyncDraft:…]; Android: ChatManager.isDisableSyncDraft() |
| `isEnableUserOnlineState` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService isEnableUserOnlineState:…]; Android: ChatManager.isEnableUserOnlineState() |
| `isGlobalDisableSyncDraft` | Stub (dummy) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService isGlobalDisableSyncDraft:…]; Android: ChatManager.isGlobalDisableSyncDraft() |
| `isGroupReceiptEnabled` | Stub (dummy) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService isGroupReceiptEnabled:…]; Android: ChatManager.isGroupReceiptEnabled() |
| `isMuteNotificationWhenPcOnline` | Stub (dummy) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService isMuteNotificationWhenPcOnline:…]; Android: ChatManager.isMuteNotificationWhenPcOnline() |
| `isNoDisturbing` | Stub (dummy) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService isNoDisturbing:…]; Android: ChatManager.isNoDisturbing() |
| `isReceiptEnabled` | Stub (dummy) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService isReceiptEnabled:…]; Android: ChatManager.isReceiptEnabled() |
| `isSupportBigFilesUpload` | Stub (dummy) | Stub (dummy) | Stub (dummy) | iOS: not implemented; Android: ChatManager.isSupportBigFilesUpload() |
| `isUserEnableReceipt` | Stub (dummy) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService isUserEnableReceipt:…]; Android: ChatManager.isUserEnableReceipt() |
| `isVoipNotificationSilent` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService isVoipNotificationSilent:…]; Android: ChatManager.isVoipSilent() |
| `kickoffPCClient` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService kickoffPCClient:…]; Android: ChatManager.kickoffPCClient(clientId, new GeneralVoidCallback(requestId)) |
| `muteNotificationWhenPcOnline` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService muteNotificationWhenPcOnline:…]; Android: ChatManager.muteNotificationWhenPcOnline(isMute, new GeneralVoidCallback(requestId)) |
| `quitGroupEx` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService quitGroup:…]; Android: ChatManager.quitGroup(groupId, keepMessage, notifyLines, messageContent, new Ge…) |
| `searchConversationsMessages` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService searchMessage:…]; Android: ChatManager.searchMessagesEx(types, lines, contentTypes, keyword, fromIndex, desc, cou…) |
| `searchFiles` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService searchFiles:…]; Android: ChatManager.searchFileRecords(keyword, conversation, userId, beforeMessageUid, FileReco…) |
| `searchMyFiles` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService searchMyFiles:…]; Android: ChatManager.searchMyFileRecords(keyword, beforeMessageUid, FileRecordOrder.type(order), c…) |
| `sendConferenceRequest` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: not implemented; Android: ChatManager.sendConferenceRequest(sessionId, roomId, request, advanced, data, new GeneralCa…) |
| `setDefaultSilentWhenPcOnline` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService setDefaultSilentWhenPcOnline:…]; Android: ChatManager.setDefaultSilentWhenPcOnline(silent) |
| `setDeviceToken` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCNetworkService setDeviceToken:…]; Android: ChatManager.setDeviceToken(deviceToken, pushType) |
| `setEnableSyncDraft` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService setEnableSyncDraft:…]; Android: ChatManager.setDisableSyncDraft(!enable, new GeneralVoidCallback(requestId)) |
| `setGroupRemark` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService setGroup:…]; Android: ChatManager.setGroupRemark(groupId, remark, new GeneralVoidCallback(requestId)) |
| `setMyCustomState` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService setMyCustomState:…]; Android: ChatManager.setMyCustomState(customState, customText, new GeneralVoidCallback(requestId)) |
| `setNoDisturbingTimes` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService setNoDisturbingTimes:…]; Android: ChatManager.setNoDisturbingTimes(startMins, endMins, new GeneralVoidCallback(requestId)) |
| `setSendLogCommand` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCNetworkService sendLogCommand:…]; Android: ChatManager.setSendLogCommand(cmd) |
| `setUserEnableReceipt` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService setUserEnableReceipt:…]; Android: ChatManager.setUserEnableReceipt(isEnable, new GeneralVoidCallback(requestId)) |
| `setVoipDeviceToken` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCNetworkService setVoipDeviceToken:…]; Android: result.success(null) |
| `setVoipNotificationSilent` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService setVoipNotificationSilent:…]; Android: ChatManager.setVoipSilent(isSilent, new GeneralVoidCallback(requestId)) |
| `startLog` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCNetworkService startLog:…]; Android: ChatManager.startLog() |
| `stopLog` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCNetworkService stopLog:…]; Android: ChatManager.stopLog() |
| `unwatchOnlineState` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService unwatchOnlineState:…]; Android: ChatManager.unWatchOnlineState(conversationType, targets.toArray(new String[0]), new Gen…) |
| `updateRemoteMessageContent` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService updateRemoteMessage:…]; Android: ChatManager.updateRemoteMessageContent(messageUid, messageContent, distribute, updateLocal, new …) |
| `uploadMediaFile` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService uploadMediaFile:…]; Android: ChatManager.uploadMediaFile(filePath, mediaType, new UploadMediaCallback() { @Overrid…) |
| `watchOnlineState` | Stub (NotImplemented) | Stub (NotImplemented) | Stub (NotImplemented) | iOS: [WFCCIMService watchOnlineState:…]; Android: ChatManager.watchOnlineState(conversationType, targets.toArray(new String[0]), watchDu…) |

## B. At least one desktop platform implemented

| Method | macOS status | Linux status | Windows status | iOS / Android reference summary |
|---|---|---|---|---|
| `addGroupMembers` | Implemented | Implemented | Implemented | iOS: [WFCCIMService addMembers:…]; Android: ChatManager.addGroupMembers(groupId, groupMembers, extra, notifyLines, messageContent…) |
| `addHttpHeader` | Implemented | Implemented | Implemented | iOS: [WFCCNetworkService addHttpHeader:…]; Android: ChatManager.addHttpHeader(header, value) |
| `allowGroupMember` | Implemented | Implemented | Implemented | iOS: [WFCCIMService allowGroupMember:…]; Android: ChatManager.allowGroupMember(groupId, isSet, memberIds, notifyLines, messageContent, n…) |
| `beginTransaction` | Implemented | Implemented | Implemented | iOS: [WFCCIMService beginTransaction:…]; Android: ChatManager.beginTransaction() |
| `cancelSendingMessage` | Implemented | Implemented | Implemented | iOS: [WFCCIMService cancelSendingMessage:…]; Android: ChatManager.cancelSendingMessage(messageId) |
| `clearConversationUnreadStatus` | Implemented | Implemented | Implemented | iOS: [WFCCIMService clearUnreadStatus:…]; Android: ChatManager.clearUnreadStatus(conversation) |
| `clearConversationsUnreadStatus` | Implemented | Implemented | Implemented | iOS: [WFCCIMService clearUnreadStatus:…]; Android: ChatManager.clearUnreadStatusEx(types, lines) |
| `clearMessageUnreadStatus` | Implemented | Implemented | Implemented | iOS: [WFCCIMService clearMessageUnreadStatus:…]; Android: ChatManager.clearMessageUnreadStatus(messageId) |
| `clearMessages` | Implemented | Implemented | Implemented | iOS: [WFCCIMService clearMessages:…]; Android: ChatManager.clearMessages(conversation, before) |
| `clearUnreadFriendRequestStatus` | Implemented | Implemented | Implemented | iOS: [WFCCIMService clearUnreadFriendRequestStatus:…]; Android: ChatManager.clearUnreadFriendRequestStatus() |
| `commitTransaction` | Implemented | Implemented | Implemented | iOS: [WFCCIMService commitTransaction:…]; Android: ChatManager.commitTransaction() |
| `connect` | Implemented | Implemented | Implemented | iOS: [WFCCNetworkService connect:…]; Android: ChatManager.connect(userId, token) |
| `connectionStatus` | Implemented | Implemented | Implemented | iOS: [WFCCNetworkService currentConnectionStatus:…]; Android: ChatManager.getConnectionStatus() |
| `createChannel` | Implemented | Implemented | Implemented | iOS: [WFCCIMService createChannel:…]; Android: ChatManager.createChannel("", channelName, channelPortrait, desc, extra, new Genera…) |
| `createGroup` | Implemented | Implemented | Implemented | iOS: [WFCCIMService createGroup:…]; Android: ChatManager.createGroup(groupId, groupName, groupPortrait, GroupInfo.GroupType.ty…) |
| `deleteFriend` | Implemented | Implemented | Implemented | iOS: [WFCCIMService deleteFriend:…]; Android: ChatManager.deleteFriend(userId, new GeneralVoidCallback(requestId)) |
| `deleteMessage` | Implemented | Implemented | Implemented | iOS: [WFCCIMService deleteMessage:…]; Android: ChatManager.deleteMessage(msg) |
| `destroyChannel` | Implemented | Implemented | Implemented | iOS: [WFCCIMService destoryChannel:…]; Android: ChatManager.destoryChannel(channelId, new GeneralVoidCallback(requestId)) |
| `disconnect` | Implemented | Implemented | Implemented | iOS: [WFCCNetworkService disconnect:…]; Android: ChatManager.disconnect(disablePush, clearSession) |
| `dismissGroup` | Implemented | Implemented | Implemented | iOS: [WFCCIMService dismissGroup:…]; Android: ChatManager.dismissGroup(groupId, notifyLines, messageContent, new GeneralVoidCall…) |
| `getAuthorizedMediaUrl` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getAuthorizedMediaUrl:…]; Android: ChatManager.getAuthorizedMediaUrl(messageUid, MessageContentMediaType.mediaType(mediaType),…) |
| `getBlackList` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getBlackList:…]; Android: ChatManager.getBlackList(refresh) |
| `getChannelInfo` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getChannelInfo:…]; Android: ChatManager.getChannelInfo(channelId, refresh) |
| `getChatroomInfo` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getChatroomInfo:…]; Android: ChatManager.getChatRoomInfo(chatroomId, updateDt, new GetChatRoomInfoCallback() { @Ov…) |
| `getChatroomMemberInfo` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getChatroomMemberInfo:…]; Android: ChatManager.getChatRoomMembersInfo(chatroomId, maxCount, new GetChatRoomMembersInfoCallback(…) |
| `getClientId` | Implemented | Implemented | Implemented | iOS: [WFCCNetworkService getClientId:…]; Android: ChatManager.getClientId() |
| `getConversationInfo` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getConversationInfo:…]; Android: ChatManager.getConversation(conversation) |
| `getConversationInfos` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getConversationInfos:…]; Android: ChatManager.getConversationList(cts, lines) |
| `getConversationRead` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getConversationRead:…]; Android: ChatManager.getConversationRead(conversation) |
| `getConversationUnreadCount` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getUnreadCount:…]; Android: ChatManager.getUnreadCount(conversation) |
| `getConversationsMessageByStatus` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getMessagesV2:…]; Android: ChatManager.getMessagesEx2(types, lines, mss, fromIndex, isDesc, count, withUser, ne…) |
| `getConversationsMessages` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getMessagesV2:…]; Android: ChatManager.getMessagesEx(types, lines, contentTypes, fromIndex, isDesc, count, wit…) |
| `getConversationsUnreadCount` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getUnreadCount:…]; Android: ChatManager.getUnreadCountEx(cts, lines) |
| `getFavGroups` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getFavGroups:…]; Android: ChatManager.getFavGroups(new GetGroupsCallback() { @Override public void onSuccess…) |
| `getFavUsers` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getFavUsers:…]; Android: ChatManager.getFavUsers(new StringListCallback() { @Override public void onSucces…) |
| `getFirstUnreadMessageId` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getFirstUnreadMessageId:…]; Android: ChatManager.getFirstUnreadMessageId(conversation) |
| `getFriendAlias` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getFriendAlias:…]; Android: ChatManager.getFriendAlias(friendId) |
| `getFriendExtra` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getFriendExtra:…]; Android: ChatManager.getFriendExtra(friendId) |
| `getFriendRequest` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getFriendRequest:…]; Android: ChatManager.getFriendRequest(userId, direction > 0) |
| `getGroupInfo` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getGroupInfo:…]; Android: ChatManager.getGroupInfo(groupId, refresh) |
| `getGroupInfoAsync` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getGroupInfo:…]; Android: ChatManager.getGroupInfo(groupId, refresh, new GetGroupInfoCallback() { @Override …) |
| `getGroupInfos` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getGroupInfos:…]; Android: ChatManager.getGroupInfos(groupIds, refresh) |
| `getGroupMember` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getGroupMember:…]; Android: ChatManager.getGroupMember(groupId, memberId) |
| `getGroupMembers` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getGroupMembers:…]; Android: ChatManager.getGroupMembers(groupId, refresh) |
| `getGroupMembersAsync` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getGroupMembers:…]; Android: ChatManager.getGroupMembers(groupId, refresh, new GetGroupMembersCallback() { @Overri…) |
| `getGroupMembersByCount` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getGroupMembers:…]; Android: ChatManager.getGroupMembersByCount(groupId, count) |
| `getGroupMembersByTypes` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getGroupMembers:…]; Android: ChatManager.getGroupMembersByType(groupId, GroupMember.GroupMemberType.type(memberType)) |
| `getIncommingFriendRequest` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getIncommingFriendRequest:…]; Android: ChatManager.getFriendRequest(true) |
| `getMessage` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getMessage:…]; Android: ChatManager.getMessage(messageId) |
| `getMessageByUid` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getMessageByUid:…]; Android: ChatManager.getMessageByUid(messageUid) |
| `getMessageDelivery` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getMessageDelivery:…]; Android: ChatManager.getMessageDelivery(conversation) |
| `getMessages` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getMessagesV2:…]; Android: ChatManager.getMessages(conversation, contentTypes, fromIndex, count > 0, count >…) |
| `getMessagesByStatus` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getMessagesV2:…]; Android: ChatManager.getMessagesByMessageStatus(conversation, messageStatus, fromIndex, isDesc, count, wi…) |
| `getMyChannels` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getMyChannels:…]; Android: ChatManager.getMyChannels() |
| `getMyFriendList` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getMyFriendList:…]; Android: ChatManager.getMyFriendList(refresh) |
| `getOutgoingFriendRequest` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getOutgoingFriendRequest:…]; Android: ChatManager.getFriendRequest(false) |
| `getProtoRevision` | Stub (dummy) | Implemented | Implemented | iOS: [WFCCNetworkService getProtoRevision:…]; Android: ChatManager.getProtoRevision() |
| `getRemoteListenedChannels` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getRemoteListenedChannels:…]; Android: ChatManager.getRemoteListenedChannels(new GeneralCallback3() { @Override public void onSuccess(…) |
| `getRemoteMessages` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getRemoteMessages:…]; Android: ChatManager.getRemoteMessages(conversation, contentTypes, beforeMessageUid, count, new …) |
| `getUnreadFriendRequestStatus` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getUnreadFriendRequestStatus:…]; Android: ChatManager.getUnreadFriendRequestStatus() |
| `getUserInfo` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getUserInfo:…]; Android: ChatManager.getUserInfo(userId, groupId, refresh) |
| `getUserInfoAsync` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getUserInfo:…]; Android: ChatManager.getUserInfo(userId, groupId, refresh, new GetUserInfoCallback() { @Ov…) |
| `getUserInfos` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getUserInfos:…]; Android: ChatManager.getUserInfos(userIds, groupId) |
| `getUserSetting` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getUserSetting:…]; Android: ChatManager.getUserSetting(scope, key) |
| `getUserSettings` | Implemented | Implemented | Implemented | iOS: [WFCCIMService getUserSettings:…]; Android: ChatManager.getUserSettings(scope) |
| `handleFriendRequest` | Implemented | Implemented | Implemented | iOS: [WFCCIMService handleFriendRequest:…]; Android: ChatManager.handleFriendRequest(userId, accept, extra, new GeneralVoidCallback(requestId)) |
| `insertMessage` | Implemented | Implemented | Implemented | iOS: [WFCCIMService insert:…]; Android: ChatManager.insertMessage(conversation, sender, messageContent, MessageStatus.statu…) |
| `isBlackListed` | Implemented | Implemented | Implemented | iOS: [WFCCIMService isBlackListed:…]; Android: ChatManager.isBlackListed(userId) |
| `isFavGroup` | Implemented | Implemented | Implemented | iOS: [WFCCIMService isFavGroup:…]; Android: ChatManager.isFavGroup(groupId) |
| `isFavUser` | Implemented | Implemented | Implemented | iOS: [WFCCIMService isFavUser:…]; Android: ChatManager.isFavUser(userId) |
| `isGlobalSilent` | Implemented | Implemented | Implemented | iOS: [WFCCIMService isGlobalSilent:…]; Android: ChatManager.isGlobalSilent() |
| `isHiddenGroupMemberName` | Implemented | Implemented | Implemented | iOS: [WFCCIMService isHiddenGroupMemberName:…]; Android: ChatManager.getUserSetting(UserSettingScope.GroupHideNickname, groupId) |
| `isHiddenNotificationDetail` | Implemented | Implemented | Implemented | iOS: [WFCCIMService isHiddenNotificationDetail:…]; Android: ChatManager.isHiddenNotificationDetail() |
| `isListenedChannel` | Implemented | Implemented | Implemented | iOS: [WFCCIMService isListenedChannel:…]; Android: ChatManager.isListenedChannel(channelId) |
| `isLogined` | Implemented | Implemented | Implemented | iOS: [WFCCNetworkService isLogined:…]; Android: ChatManager.getUserId() |
| `isMyFriend` | Implemented | Implemented | Implemented | iOS: [WFCCIMService isMyFriend:…]; Android: ChatManager.isMyFriend(userId) |
| `joinChatroom` | Implemented | Implemented | Implemented | iOS: [WFCCIMService joinChatroom:…]; Android: ChatManager.joinChatRoom(chatroomId, new GeneralVoidCallback(requestId)) |
| `kickoffGroupMembers` | Implemented | Implemented | Implemented | iOS: [WFCCIMService kickoffMembers:…]; Android: ChatManager.removeGroupMembers(groupId, groupMembers, notifyLines, messageContent, new G…) |
| `listenChannel` | Implemented | Implemented | Implemented | iOS: [WFCCIMService listenChannel:…]; Android: ChatManager.listenChannel(channelId, listen, new GeneralVoidCallback(requestId)) |
| `loadFriendRequestFromRemote` | Implemented | Implemented | Implemented | iOS: [WFCCIMService loadFriendRequestFromRemote:…]; Android: ChatManager.loadFriendRequestFromRemote() |
| `markAsUnRead` | Implemented | Implemented | Implemented | iOS: [WFCCIMService markAsUnRead:…]; Android: ChatManager.markAsUnRead(conversation, sync) |
| `modifyChannelInfo` | Implemented | Implemented | Implemented | iOS: [WFCCIMService modifyChannelInfo:…]; Android: ChatManager.modifyChannelInfo(channelId, ModifyChannelInfoType.type(type), newValue, ne…) |
| `modifyGroupAlias` | Implemented | Implemented | Implemented | iOS: [WFCCIMService modifyGroupAlias:…]; Android: ChatManager.modifyGroupAlias(groupId, newAlias, notifyLines, messageContent, new Gener…) |
| `modifyGroupInfo` | Implemented | Implemented | Implemented | iOS: [WFCCIMService modifyGroupInfo:…]; Android: ChatManager.modifyGroupInfo(groupId, ModifyGroupInfoType.type(modifyType), value, not…) |
| `modifyGroupMemberAlias` | Implemented | Implemented | Implemented | iOS: [WFCCIMService modifyGroupMemberAlias:…]; Android: ChatManager.modifyGroupMemberAlias(groupId, memberId, newAlias, notifyLines, messageContent,…) |
| `modifyMyInfo` | Implemented | Implemented | Implemented | iOS: [WFCCIMService modifyMyInfo:…]; Android: ChatManager.modifyMyInfo(list, new GeneralVoidCallback(requestId)) |
| `muteGroupMember` | Implemented | Implemented | Implemented | iOS: [WFCCIMService muteGroupMember:…]; Android: ChatManager.muteGroupMember(groupId, isSet, memberIds, notifyLines, messageContent, n…) |
| `quitChatroom` | Implemented | Implemented | Implemented | iOS: [WFCCIMService quitChatroom:…]; Android: ChatManager.quitChatRoom(chatroomId, new GeneralVoidCallback(requestId)) |
| `quitGroup` | Implemented | Implemented | Implemented | iOS: [WFCCIMService quitGroup:…]; Android: ChatManager.quitGroup(groupId, notifyLines, messageContent, new GeneralVoidCall…) |
| `recallMessage` | Implemented | Implemented | Implemented | iOS: [WFCCIMService recall:…]; Android: ChatManager.recallMessage(msg, new cn.wildfirechat.remote.GeneralCallback() { @Over…) |
| `registerMessage` | Implemented | Implemented | Implemented | iOS: [WFCCIMService registerMessageFlag:…]; Android: not implemented |
| `removeConversation` | Implemented | Implemented | Implemented | iOS: [WFCCIMService removeConversation:…]; Android: ChatManager.removeConversation(conversation, clearMessage) |
| `rollbackTransaction` | Implemented | Implemented | Implemented | iOS: not implemented; Android: ChatManager.rollbackTransaction() |
| `searchChannel` | Implemented | Implemented | Implemented | iOS: [WFCCIMService searchChannel:…]; Android: ChatManager.searchChannel(keyword, new SearchChannelCallback() { @Override public v…) |
| `searchConversation` | Implemented | Implemented | Implemented | iOS: [WFCCIMService searchConversation:…]; Android: ChatManager.searchConversation(keyword, cts, lines) |
| `searchFriends` | Implemented | Implemented | Implemented | iOS: [WFCCIMService searchFriends:…]; Android: ChatManager.searchFriends(keyword) |
| `searchGroups` | Implemented | Implemented | Implemented | iOS: [WFCCIMService searchGroups:…]; Android: ChatManager.searchGroups(keyword) |
| `searchMessages` | Implemented | Implemented | Implemented | iOS: [WFCCIMService searchMessage:…]; Android: ChatManager.searchMessage(conversation, keyword, order, limit, offset, withUser) |
| `searchUser` | Implemented | Implemented | Implemented | iOS: [WFCCIMService searchUser:…]; Android: ChatManager.searchUser(keyword, ChatManager.SearchUserType.type(searchType), pag…) |
| `sendFriendRequest` | Implemented | Implemented | Implemented | iOS: [WFCCIMService sendFriendRequest:…]; Android: ChatManager.sendFriendRequest(userId, reason, extra, new GeneralVoidCallback(requestId)) |
| `sendMessage` | Implemented | Implemented | Implemented | iOS: [WFCCIMService sendMedia:…]; Android: ChatManager.sendMessage(conversation, messageContent, toUsers != null ? toUsers.t…) |
| `sendSavedMessage` | Implemented | Implemented | Implemented | iOS: [WFCCIMService sendSavedMessage:…]; Android: ChatManager.sendSavedMessage(msg, expireDuration, new SendMessageCallback() { @Overrid…) |
| `serverDeltaTime` | Implemented | Implemented | Implemented | iOS: [WFCCNetworkService serverDeltaTime:…]; Android: ChatManager.getServerDeltaTime() |
| `setBackupAddress` | Implemented | Implemented | Implemented | iOS: [WFCCNetworkService setBackupAddress:…]; Android: ChatManager.setBackupAddress(host, port) |
| `setBackupAddressStrategy` | Implemented | Implemented | Implemented | iOS: [WFCCNetworkService setBackupAddressStrategy:…]; Android: ChatManager.setBackupAddressStrategy(strategy) |
| `setBlackList` | Implemented | Implemented | Implemented | iOS: [WFCCIMService setBlackList:…]; Android: ChatManager.setBlackList(userId, isBlackListed, new GeneralVoidCallback(requestId)) |
| `setConversationDraft` | Implemented | Implemented | Implemented | iOS: [WFCCIMService setConversation:…]; Android: ChatManager.setConversationDraft(conversation, draft) |
| `setConversationSilent` | Implemented | Implemented | Implemented | iOS: [WFCCIMService setConversation:…]; Android: ChatManager.setConversationSilent(conversation, isSilent, new GeneralVoidCallback(requestId)) |
| `setConversationTimestamp` | Implemented | Implemented | Implemented | iOS: [WFCCIMService setConversation:…]; Android: ChatManager.setConversationTimestamp(conversation, timestamp) |
| `setConversationTop` | Implemented | Implemented | Implemented | iOS: [WFCCIMService setConversation:…]; Android: ChatManager.setConversationTop(conversation, top, new GeneralVoidCallback(requestId)) |
| `setFavGroup` | Implemented | Implemented | Implemented | iOS: [WFCCIMService setFavGroup:…]; Android: ChatManager.setFavGroup(groupId, isFav, new GeneralVoidCallback(requestId)) |
| `setFavUser` | Stub (dummy) | Implemented | Implemented | iOS: [WFCCIMService setFavUser:…]; Android: ChatManager.setFavUser(userId, isFav, new GeneralVoidCallback(requestId)) |
| `setFriendAlias` | Implemented | Implemented | Implemented | iOS: [WFCCIMService setFriend:…]; Android: ChatManager.setFriendAlias(friendId, alias, new GeneralVoidCallback(requestId)) |
| `setGlobalSilent` | Implemented | Implemented | Implemented | iOS: [WFCCIMService setGlobalSilent:…]; Android: ChatManager.setGlobalSilent(isSilent, new GeneralVoidCallback(requestId)) |
| `setGroupManager` | Implemented | Implemented | Implemented | iOS: [WFCCIMService setGroupManager:…]; Android: ChatManager.setGroupManager(groupId, isSet, memberIds, notifyLines, messageContent, n…) |
| `setHiddenGroupMemberName` | Implemented | Implemented | Implemented | iOS: [WFCCIMService setHiddenGroupMemberName:…]; Android: ChatManager.setHiddenGroupMemberName(groupId, isHidden, new GeneralVoidCallback(requestId)) |
| `setHiddenNotificationDetail` | Implemented | Implemented | Implemented | iOS: [WFCCIMService setHiddenNotificationDetail:…]; Android: ChatManager.setHiddenNotificationDetail(isHidden, new GeneralVoidCallback(requestId)) |
| `setLiteMode` | Implemented | Implemented | Implemented | iOS: [WFCCNetworkService setLiteMode:…]; Android: ChatManager.setLiteMode(liteMode) |
| `setMediaMessagePlayed` | Implemented | Implemented | Implemented | iOS: [WFCCIMService setMediaMessagePlayed:…]; Android: ChatManager.setMediaMessagePlayed(messageId) |
| `setMessageLocalExtra` | Implemented | Implemented | Implemented | iOS: [WFCCIMService setMessage:…]; Android: ChatManager.setMessageLocalExtra(messageId, localExtra) |
| `setProtoUserAgent` | Implemented | Implemented | Implemented | iOS: [WFCCNetworkService setProtoUserAgent:…]; Android: ChatManager.setProtoUserAgent(agent) |
| `setProxyInfo` | Implemented | Implemented | Implemented | iOS: [WFCCNetworkService setProxyInfo:…]; Android: ChatManager.setProxyInfo(socks5ProxyInfo) |
| `setUserSetting` | Implemented | Implemented | Implemented | iOS: [WFCCIMService setUserSetting:…]; Android: ChatManager.setUserSetting(scope, key, value, new GeneralVoidCallback(requestId)) |
| `transferGroup` | Implemented | Implemented | Implemented | iOS: [WFCCIMService transferGroup:…]; Android: ChatManager.transferGroup(groupId, newOwner, notifyLines, messageContent, new Gener…) |
| `updateMessage` | Implemented | Implemented | Implemented | iOS: [WFCCIMService updateMessage:…]; Android: ChatManager.updateMessage(messageId, messageContent) |
| `updateMessageStatus` | Implemented | Implemented | Implemented | iOS: [WFCCIMService updateMessage:…]; Android: ChatManager.updateMessage(messageId, MessageStatus.status(status)) |
| `uploadMedia` | Implemented | Implemented | Implemented | iOS: [WFCCIMService uploadMedia:…]; Android: ChatManager.uploadMedia2(fileName, mediaData, mediaType, new UploadMediaCallback()…) |
| `useSM4` | Implemented | Implemented | Implemented | iOS: [WFCCNetworkService useSM4:…]; Android: ChatManager.useSM4() |

