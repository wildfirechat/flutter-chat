#!/usr/bin/env python3
"""Parse WFClient.h and classify exported functions."""

import re
import json
from pathlib import Path

HEADER = Path('/Users/rain/Workspace/wfc_flutter_plugins/imclient/macos/include/WFClient.h').read_text()

# Match extern declarations spanning multiple lines
pattern = re.compile(
    r'extern\s+"C"\s+PROTOWRAPPER_API\s+(.*?)\s+WFCAPI\s+(\w+)\s*\((.*?)\)\s*;',
    re.DOTALL
)

# Normalize whitespace in captured groups
functions = []
for ret, name, args in pattern.findall(HEADER):
    ret = ' '.join(ret.split())
    args = ' '.join(args.split())
    functions.append({'return': ret, 'name': name, 'args': args})

# Categorize by name prefix/pattern
keywords = {
    'message': ['getMessages', 'sendMessage', 'insertMessage', 'deleteMessage', 'recallMessage',
                'updateMessage', 'clearMessage', 'getMessage', 'searchMessage', 'getMentioned',
                'searchMentioned', 'batchDeleteMessages', 'getFirstUnread', 'getUserMessages',
                'getConversationMessageCount', 'getMessageCount', 'sendSavedMessage'],
    'conversation': ['getConversation', 'searchConversation', 'removeConversation', 'clearRemoteConversation',
                     'setConversation', 'clearConversation'],
    'friend': ['getFriend', 'setFriend', 'searchFriend', 'deleteFriend', 'clearFriend'],
    'group': ['getGroup', 'setGroup', 'createGroup', 'modifyGroup', 'addGroup', 'quitGroup',
              'handleJoinGroup', 'getJoinGroup', 'setGroupRemark', 'getGroupRemark',
              'getCommonGroups', 'getMyGroups'],
    'user': ['getUserInfo', 'searchUser', 'getUserInfos', 'setUser', 'isUserEnable',
             'watchOnline', 'unwatchOnline', 'isEnableUserOnline', 'getUserOnline',
             'getMyCustomState', 'setMyCustomState'],
    'channel': ['getChannel', 'searchChannel', 'getRemoteListenedChannels'],
    'chatroom': ['getJoinedChatroomId', 'joinChatroom', 'quitChatroom'],
    'file': ['getConversationFiles', 'getMyFiles', 'deleteFileRecord', 'searchFiles', 'searchMyFiles',
             'getUploadUrl', 'getUploadMediaUrl', 'uploadMediaFile', 'getWavData', 'isSupportBigFilesUpload',
             'isForceBigFilesUpload', 'forcePresignedUrlUpload', 'getImageThumbPara'],
    'setting': ['setNoDisturbing', 'getNoDisturbing', 'isNoDisturbing', 'setEnableSyncDraft',
                'isEnableSyncDraft', 'isGlobalDisableSyncDraft', 'setDefaultSilentWhenPcOnline',
                'setLanguage'],
    'connection': ['setHeartBeat', 'useDataVerify', 'useEncrypt', 'setUseKcp', 'isUseKcp',
                   'useTls', 'useAES256', 'useTcpShortLink', 'isTcpShortLink', 'setTimeOffset',
                   'getRoutePort', 'getHost', 'onAppResume', 'onAppSuspend', 'getConnectedNetworkType',
                   'getCurrentUserId', 'getLogFilesPath'],
    'auth': ['getAuthCode', 'configApplication', 'isCommercialServer', 'isReceiptEnabled',
             'isGroupReceiptEnabled'],
    'online': ['watchOnlineState', 'unwatchOnlineState', 'isEnableUserOnlineState',
               'getUserOnlineState', 'getOnlineInfos'],
    'secret': ['createSecretChat', 'destroySecretChat', 'getSecretChatInfo', 'encodeSecretChat',
               'decodeSecretChat', 'setSecretChatBurnTime', 'isEnableSecretChat', 'isUserEnableSecretChat'],
    'misc': ['getAppPath', 'getDomainInfo', 'getRemoteDomains', 'releaseDllString', 'screenShot',
             'encodedCid', 'encodeData', 'decodeData', 'requireLock', 'releaseLock'],
}

def categorize(fn):
    name = fn['name']
    for cat, prefixes in keywords.items():
        for p in prefixes:
            if name.startswith(p):
                return cat
    return 'other'

by_cat = {}
for fn in functions:
    cat = categorize(fn)
    by_cat.setdefault(cat, []).append(fn)

print(json.dumps({k: len(v) for k, v in by_cat.items()}, indent=2))
print(f"\nTotal: {len(functions)}")

# Save full list
Path('/Users/rain/Workspace/wfc_flutter_plugins/imclient/scripts/wfc_functions.json').write_text(
    json.dumps(functions, indent=2)
)
Path('/Users/rain/Workspace/wfc_flutter_plugins/imclient/scripts/wfc_functions_by_category.json').write_text(
    json.dumps(by_cat, indent=2)
)
