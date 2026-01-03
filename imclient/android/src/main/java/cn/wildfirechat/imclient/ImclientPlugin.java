package cn.wildfirechat.imclient;

import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.text.TextUtils;
import android.util.Base64;
import android.util.Log;
import android.util.Pair;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.RequiresApi;
import androidx.lifecycle.Lifecycle;
import androidx.lifecycle.LifecycleObserver;
import androidx.lifecycle.OnLifecycleEvent;
import androidx.lifecycle.ProcessLifecycleOwner;

import java.lang.reflect.InvocationHandler;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import cn.wildfirechat.client.ConnectionStatus;
import cn.wildfirechat.client.NotInitializedExecption;
import cn.wildfirechat.message.AddParticipantsMessageContent;
import cn.wildfirechat.message.CallStartMessageContent;
import cn.wildfirechat.message.Message;
import cn.wildfirechat.message.MessageContent;
import cn.wildfirechat.message.MessageContentMediaType;
import cn.wildfirechat.message.core.MessageDirection;
import cn.wildfirechat.message.core.MessagePayload;
import cn.wildfirechat.message.core.MessageStatus;
import cn.wildfirechat.message.core.PersistFlag;
import cn.wildfirechat.model.ChannelInfo;
import cn.wildfirechat.model.ChannelMenu;
import cn.wildfirechat.model.ChatRoomInfo;
import cn.wildfirechat.model.ChatRoomMembersInfo;
import cn.wildfirechat.model.ClientState;
import cn.wildfirechat.model.Conversation;
import cn.wildfirechat.model.ConversationInfo;
import cn.wildfirechat.model.ConversationSearchResult;
import cn.wildfirechat.model.FileRecord;
import cn.wildfirechat.model.FileRecordOrder;
import cn.wildfirechat.model.Friend;
import cn.wildfirechat.model.FriendRequest;
import cn.wildfirechat.model.GroupInfo;
import cn.wildfirechat.model.GroupMember;
import cn.wildfirechat.model.GroupSearchResult;
import cn.wildfirechat.model.ModifyChannelInfoType;
import cn.wildfirechat.model.ModifyGroupInfoType;
import cn.wildfirechat.model.ModifyMyInfoEntry;
import cn.wildfirechat.model.ModifyMyInfoType;
import cn.wildfirechat.model.PCOnlineInfo;
import cn.wildfirechat.model.ReadEntry;
import cn.wildfirechat.model.Socks5ProxyInfo;
import cn.wildfirechat.model.UnreadCount;
import cn.wildfirechat.model.UserInfo;
import cn.wildfirechat.model.UserOnlineState;
import cn.wildfirechat.remote.ChatManager;
import cn.wildfirechat.remote.GeneralCallback;
import cn.wildfirechat.remote.GeneralCallback2;
import cn.wildfirechat.remote.GeneralCallback3;
import cn.wildfirechat.remote.GetAuthorizedMediaUrlCallback;
import cn.wildfirechat.remote.GetChatRoomInfoCallback;
import cn.wildfirechat.remote.GetChatRoomMembersInfoCallback;
import cn.wildfirechat.remote.GetFileRecordCallback;
import cn.wildfirechat.remote.GetGroupInfoCallback;
import cn.wildfirechat.remote.GetGroupMembersCallback;
import cn.wildfirechat.remote.GetGroupsCallback;
import cn.wildfirechat.remote.GetMessageCallback;
import cn.wildfirechat.remote.GetOneRemoteMessageCallback;
import cn.wildfirechat.remote.GetRemoteMessageCallback;
import cn.wildfirechat.remote.GetUploadUrlCallback;
import cn.wildfirechat.remote.GetUserInfoCallback;
import cn.wildfirechat.remote.SearchChannelCallback;
import cn.wildfirechat.remote.SearchUserCallback;
import cn.wildfirechat.remote.SendMessageCallback;
import cn.wildfirechat.remote.StringListCallback;
import cn.wildfirechat.remote.UploadMediaCallback;
import cn.wildfirechat.remote.UserSettingScope;
import cn.wildfirechat.remote.WatchOnlineStateCallback;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/**
 * FlutterImclientPlugin
 */
public class ImclientPlugin implements FlutterPlugin, MethodCallHandler {
    private static final String TAG = "ImclientPlugin";
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private static MethodChannel channel;
    private static Handler handler;

    private static boolean isWfcIMClientInitialized = false;

    public ImclientPlugin() {
        super();
    }


    private void addWfcListeners() {
        ChatManager chatManager = ChatManager.Instance();
        handler = new Handler(Looper.getMainLooper());
        Log.i(TAG, "初始化事件监听");
        try {
            Class<?> ChatManagerClazz = chatManager.getClass();
            Method[] ChatManagerMethods = ChatManagerClazz.getDeclaredMethods();

            Pattern pattern = Pattern.compile("add(.*)Listener");

            for (Method method : ChatManagerMethods) {
                Matcher matcher = pattern.matcher(method.getName());
                if (matcher.find()) {
                    Class[] paramTypes = method.getParameterTypes();
                    Log.i(TAG, paramTypes[0].getDeclaredMethods()[0].getName());
                    WildfireListenerHandler wildfireListenerHandler = new WildfireListenerHandler();
                    Object listener = Proxy.newProxyInstance(
                        ImclientPlugin.class.getClassLoader(),
                        new Class[]{paramTypes[0]},
                        wildfireListenerHandler);
                    method.invoke(chatManager, listener);
                }
            }
        } catch (IllegalAccessException | InvocationTargetException e) {
            e.printStackTrace();
        }
    }

    private boolean isWfcUIKitEnable() {
        String uikitClazz = "cn.wildfire.chat.kit.WfcUIKit";
        try {
            Class clazz = Class.forName(uikitClazz);
            return true;
        } catch (ClassNotFoundException e) {
            e.printStackTrace();
        } catch (Exception e) {
            e.printStackTrace();
        }
        return false;
    }

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        Log.d(TAG, "onAttachedToEngine");
        if (channel == null) {
            channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "imclient");
            channel.setMethodCallHandler(this);
        }

        if (isWfcIMClientInitialized) {
            return;
        }
        isWfcIMClientInitialized = true;

        ChatManager.init(flutterPluginBinding.getApplicationContext(), null);
        addWfcListeners();

        ProcessLifecycleOwner.get().getLifecycle().addObserver(new LifecycleObserver() {
            @OnLifecycleEvent(Lifecycle.Event.ON_START)
            public void onForeground() {

            }

            @OnLifecycleEvent(Lifecycle.Event.ON_STOP)
            public void onBackground() {

            }
        });
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        Log.d(TAG, "onDetachedFromEngine");
        if (channel != null) {
            channel.setMethodCallHandler(null);
            channel = null;
        }
        ChatManager.Instance().disconnect(false, false);
    }

    private List<Conversation.ConversationType> conversationTypesFromArgument(@NonNull MethodCall call) {
        List<Integer> types = call.argument("types");
        List<Conversation.ConversationType> cts = new ArrayList<>();
        for (Integer type : types) {
            Conversation.ConversationType t = Conversation.ConversationType.type(type);
            cts.add(t);
        }
        return cts;
    }

    private Conversation conversationFromArgument(@NonNull MethodCall call, boolean root) {
        Conversation.ConversationType type;
        String target;
        int line;

        if (root) {
            type = Conversation.ConversationType.type((int) call.argument("type"));
            target = (String) call.argument("target");
            line = (int) call.argument("line");
        } else {
            Map conversation = call.argument("conversation");
            if(conversation == null){
                return null;
            }
            type = Conversation.ConversationType.type((int) conversation.get("type"));
            target = (String) conversation.get("target");
            line = (int) conversation.get("line");
        }

        return new Conversation(type, target, line);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        try {
            Method method = this.getClass().getDeclaredMethod(call.method, MethodCall.class, Result.class);
            method.invoke(this, call, result);
            return;
        } catch (NoSuchMethodException e) {
            result.notImplemented();
        } catch (InvocationTargetException e) {
            e.printStackTrace();
        } catch (IllegalAccessException e) {
            e.printStackTrace();
        }
    }

    private void initProto(@NonNull MethodCall call, @NonNull Result result) {
        ChatManager.Instance().setSendLogCommand("*#marslog#");
        ChatManager.Instance().useRawMsg();
    }

    private void isLogined(@NonNull MethodCall call, @NonNull Result result) {
        result.success(ChatManager.Instance().getUserId() != null);
    }

    private void connect(@NonNull MethodCall call, @NonNull Result result) {
        String host = call.argument("host");
        String token = call.argument("token");
        String userId = call.argument("userId");
        ChatManager.Instance().setIMServerHost(host);
        long lastConnectTime = ChatManager.Instance().connect(userId, token);
        result.success(lastConnectTime);
    }

    private void currentUserId(@NonNull MethodCall call, @NonNull Result result) {
        result.success(ChatManager.Instance().getUserId());
    }

    private void connectionStatus(@NonNull MethodCall call, @NonNull Result result) {
        result.success(ChatManager.Instance().getConnectionStatus());
    }

    private void getClientId(@NonNull MethodCall call, @NonNull Result result) {
        result.success(ChatManager.Instance().getClientId());
    }

    private void serverDeltaTime(@NonNull MethodCall call, @NonNull Result result) {
        result.success(ChatManager.Instance().getServerDeltaTime());
    }

    public void registerMessage(@NonNull MethodCall call, @NonNull Result result) {
        int type = call.argument("type");
        int flag = call.argument("flag");
        ChatManager.Instance().registerMessageFlag(type, PersistFlag.flag(flag));
    }

    private void disconnect(@NonNull MethodCall call, @NonNull Result result) {
        boolean disablePush = call.argument("disablePush");
        boolean clearSession = call.argument("clearSession");
        ChatManager.Instance().disconnect(disablePush, clearSession);
        result.success(null);
    }

    private void startLog(@NonNull MethodCall call, @NonNull Result result) {
        ChatManager.Instance().startLog();
        result.success(null);
    }

    private void stopLog(@NonNull MethodCall call, @NonNull Result result) {
        ChatManager.Instance().stopLog();
        result.success(null);
    }

    private void setSendLogCommand(@NonNull MethodCall call, @NonNull Result result) {
        String cmd = call.argument("cmd");
        ChatManager.Instance().setSendLogCommand(cmd);
        result.success(null);
    }

    private void useSM4(@NonNull MethodCall call, @NonNull Result result) {
        ChatManager.Instance().useSM4();
        result.success(null);
    }

    private void setLiteMode(@NonNull MethodCall call, @NonNull Result result) {
        boolean liteMode = call.argument("liteMode");
        ChatManager.Instance().setLiteMode(liteMode);
        result.success(null);
    }

    private void setDeviceToken(@NonNull MethodCall call, @NonNull Result result) {
        String deviceToken = call.argument("deviceToken");
        int pushType = call.argument("pushType");
        ChatManager.Instance().setDeviceToken(deviceToken, pushType);
        result.success(null);
    }

    private void setVoipDeviceToken(@NonNull MethodCall call, @NonNull Result result) {
        result.success(null);
    }

    private void setBackupAddressStrategy(@NonNull MethodCall call, @NonNull Result result) {
        int strategy = call.argument("strategy");
        ChatManager.Instance().setBackupAddressStrategy(strategy);
        result.success(null);
    }

    private void setBackupAddress(@NonNull MethodCall call, @NonNull Result result) {
        String host = call.argument("host");
        int port = call.argument("port");
        ChatManager.Instance().setBackupAddress(host, port);
        result.success(null);
    }

    private void setProtoUserAgent(@NonNull MethodCall call, @NonNull Result result) {
        String agent = call.argument("agent");
        ChatManager.Instance().setProtoUserAgent(agent);
        result.success(null);
    }

    private void addHttpHeader(@NonNull MethodCall call, @NonNull Result result) {
        String header = call.argument("header");
        String value = call.argument("value");
        ChatManager.Instance().addHttpHeader(header, value);
        result.success(null);
    }

    private void setProxyInfo(@NonNull MethodCall call, @NonNull Result result) {
        String host = call.argument("host");
        String ip = call.argument("ip");
        int port = call.argument("port");
        String userName = call.argument("userName");
        String password = call.argument("password");
        Socks5ProxyInfo socks5ProxyInfo = new Socks5ProxyInfo(host, ip, port, userName, password);
        ChatManager.Instance().setProxyInfo(socks5ProxyInfo);
        result.success(null);
    }

    private void getProtoRevision(@NonNull MethodCall call, @NonNull Result result) {
        String revision = ChatManager.Instance().getProtoRevision();
        result.success(revision);
    }

    private void getLogFilesPath(@NonNull MethodCall call, @NonNull Result result) {
        result.success(ChatManager.Instance().getLogFilesPath());
    }

    private void getConversationInfos(@NonNull MethodCall call, @NonNull Result result) {
        List<Integer> lines = call.argument("lines");
        List<Conversation.ConversationType> cts = conversationTypesFromArgument(call);
        List<ConversationInfo> protoDatas = ChatManager.Instance().getConversationList(cts, lines);
        result.success(convertConversationInfoList(protoDatas));
    }

    private void getConversationInfo(@NonNull MethodCall call, @NonNull Result result) {
        Conversation conversation = conversationFromArgument(call, true);
        result.success(convertConversationInfo(ChatManager.Instance().getConversation(conversation)));
    }

    private void searchConversation(@NonNull MethodCall call, @NonNull Result result) {
        List<Conversation.ConversationType> cts = conversationTypesFromArgument(call);
        List<Integer> lines = call.argument("lines");
        String keyword = call.argument("keyword");

        result.success(convertConversationSearchInfoList(ChatManager.Instance().searchConversation(keyword, cts, lines)));
    }

    private void removeConversation(@NonNull MethodCall call, @NonNull Result result) {
        boolean clearMessage = call.argument("clearMessage");
        Conversation conversation = conversationFromArgument(call, false);
        ChatManager.Instance().removeConversation(conversation, clearMessage);
        result.success(null);
    }

    private void setConversationTop(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        int top = (int) call.argument("isTop");
        Conversation conversation = conversationFromArgument(call, false);
        ChatManager.Instance().setConversationTop(conversation, top, new GeneralVoidCallback(requestId));
    }

    private void setConversationSilent(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        boolean isSilent = (boolean) call.argument("isSilent");
        Conversation conversation = conversationFromArgument(call, false);
        ChatManager.Instance().setConversationSilent(conversation, isSilent, new GeneralVoidCallback(requestId));
    }

    private void setConversationDraft(@NonNull MethodCall call, @NonNull Result result) {
        String draft = (String) call.argument("draft");
        Conversation conversation = conversationFromArgument(call, false);
        ChatManager.Instance().setConversationDraft(conversation, draft);
        result.success(null);
    }

    private void setConversationTimestamp(@NonNull MethodCall call, @NonNull Result result) {
        long timestamp = getLongPara(call, "timestamp");
        Conversation conversation = conversationFromArgument(call, false);
        ChatManager.Instance().setConversationTimestamp(conversation, timestamp);
        result.success(null);
    }

    private void getFirstUnreadMessageId(@NonNull MethodCall call, @NonNull Result result) {
        Conversation conversation = conversationFromArgument(call, false);
        long messageId = ChatManager.Instance().getFirstUnreadMessageId(conversation);
        result.success(messageId);
    }

    private void getConversationUnreadCount(@NonNull MethodCall call, @NonNull Result result) {
        Conversation conversation = conversationFromArgument(call, false);
        UnreadCount unreadCount = ChatManager.Instance().getUnreadCount(conversation);
        result.success(convertUnreadCount(unreadCount));
    }

    private void getConversationsUnreadCount(@NonNull MethodCall call, @NonNull Result result) {
        List<Integer> lines = call.argument("lines");
        List<Conversation.ConversationType> cts = conversationTypesFromArgument(call);

        UnreadCount unreadCount = ChatManager.Instance().getUnreadCountEx(cts, lines);
        result.success(convertUnreadCount(unreadCount));
    }

    private void clearConversationUnreadStatus(@NonNull MethodCall call, @NonNull Result result) {
        Conversation conversation = conversationFromArgument(call, false);
        boolean ret = ChatManager.Instance().clearUnreadStatus(conversation);
        result.success(ret);
    }

    private void clearConversationsUnreadStatus(@NonNull MethodCall call, @NonNull Result result) {
        List<Conversation.ConversationType> types = conversationTypesFromArgument(call);
        List<Integer> lines = call.argument("lines");
        boolean ret = ChatManager.Instance().clearUnreadStatusEx(types, lines);
        result.success(ret);
    }

    private void clearMessageUnreadStatusBefore(@NonNull MethodCall call, @NonNull Result result) {
        Conversation conversation = conversationFromArgument(call, false);
        long messageId = call.argument("messageId");
        boolean ret = ChatManager.Instance().clearUnreadStatusBeforeMessage(messageId, conversation);
        result.success(ret);
    }

    private void clearMessageUnreadStatus(@NonNull MethodCall call, @NonNull Result result) {
        long messageId = getLongPara(call, "messageId");
        boolean ret = ChatManager.Instance().clearMessageUnreadStatus(messageId);
        result.success(ret);
    }

    private void markAsUnRead(@NonNull MethodCall call, @NonNull Result result) {
        Conversation conversation = conversationFromArgument(call, false);
        boolean sync = call.argument("sync");
        boolean ret = ChatManager.Instance().markAsUnRead(conversation, sync);
        result.success(ret);
    }

    private void getConversationRead(@NonNull MethodCall call, @NonNull Result result) {
        Conversation conversation = conversationFromArgument(call, false);
        Map<String, Long> map = ChatManager.Instance().getConversationRead(conversation);
        result.success(map);
    }

    private void getMessageDelivery(@NonNull MethodCall call, @NonNull Result result) {
        Conversation conversation = conversationFromArgument(call, false);
        Map<String, Long> map = ChatManager.Instance().getMessageDelivery(conversation);
        result.success(map);
    }

    private void getMessages(@NonNull MethodCall call, @NonNull Result result) {
        Conversation conversation = conversationFromArgument(call, false);
        List<Integer> contentTypes = call.argument("contentTypes");
        String withUser = call.argument("withUser");
        long fromIndex = getLongPara(call, "fromIndex");
        int count = call.argument("count");
        List<Message> messageList = new ArrayList<>();
        ChatManager.Instance().getMessages(conversation, contentTypes, fromIndex, count > 0, count > 0 ? count : -count, withUser, new GetMessageCallback() {
            @Override
            public void onSuccess(List<Message> list, boolean b) {
                messageList.addAll(list);
                result.success(convertMessageList(messageList, true));
            }

            @Override
            public void onFail(int i) {
                result.success(new ArrayList());
            }
        });
    }

    private void getMessagesByStatus(@NonNull MethodCall call, @NonNull Result result) {
        Conversation conversation = conversationFromArgument(call, false);
        List<Integer> messageStatus = call.argument("messageStatus");
        String withUser = call.argument("withUser");
        long fromIndex = getLongPara(call, "fromIndex");
        int count = call.argument("count");
        boolean isDesc = false;
        if (count < 0) {
            isDesc = true;
            count = -count;
        }
        List<Message> messageList = new ArrayList<>();
        ChatManager.Instance().getMessagesByMessageStatus(conversation, messageStatus, fromIndex, isDesc, count, withUser, new GetMessageCallback() {
            @Override
            public void onSuccess(List<Message> list, boolean b) {
                messageList.addAll(list);
                if (!b) {
                    result.success(convertMessageList(messageList, true));
                }
            }

            @Override
            public void onFail(int i) {
                result.success(new ArrayList());
            }
        });
    }

    private void getConversationsMessages(@NonNull MethodCall call, @NonNull Result result) {
        List<Conversation.ConversationType> types = conversationTypesFromArgument(call);
        List<Integer> lines = call.argument("lines");
        List<Integer> contentTypes = call.argument("contentTypes");
        String withUser = call.argument("withUser");
        long fromIndex = getLongPara(call, "fromIndex");
        int count = call.argument("count");
        boolean isDesc = false;
        if (count < 0) {
            isDesc = true;
            count = -count;
        }


        List<Message> messageList = new ArrayList<>();
        ChatManager.Instance().getMessagesEx(types, lines, contentTypes, fromIndex, isDesc, count, withUser, new GetMessageCallback() {
            @Override
            public void onSuccess(List<Message> list, boolean b) {
                messageList.addAll(list);
                if (!b) {
                    result.success(convertMessageList(messageList, true));
                }
            }

            @Override
            public void onFail(int i) {
                result.success(new ArrayList());
            }
        });
    }

    private void getConversationsMessageByStatus(@NonNull MethodCall call, @NonNull Result result) {
        List<Conversation.ConversationType> types = conversationTypesFromArgument(call);
        List<Integer> lines = call.argument("lines");
        List<Integer> messageStatus = call.argument("messageStatus");
        List<MessageStatus> mss = new ArrayList<>();
        for (Integer status : messageStatus) {
            mss.add(MessageStatus.status(status));
        }
        String withUser = call.argument("withUser");
        long fromIndex = getLongPara(call, "fromIndex");
        int count = call.argument("count");
        boolean isDesc = false;
        if (count < 0) {
            isDesc = true;
            count = -count;
        }


        List<Message> messageList = new ArrayList<>();
        ChatManager.Instance().getMessagesEx2(types, lines, mss, fromIndex, isDesc, count, withUser, new GetMessageCallback() {
            @Override
            public void onSuccess(List<Message> list, boolean b) {
                messageList.addAll(list);
                if (!b) {
                    result.success(convertMessageList(messageList, true));
                }
            }

            @Override
            public void onFail(int i) {
                result.success(new ArrayList());
            }
        });
    }

    private void getRemoteMessages(@NonNull MethodCall call, @NonNull Result result) {
        final int requestId = call.argument("requestId");
        Conversation conversation = conversationFromArgument(call, false);
        long beforeMessageUid = getLongPara(call, "beforeMessageUid");
        int count = call.argument("count");
        List<Integer> contentTypes = new ArrayList<>();
        ChatManager.Instance().getRemoteMessages(conversation, contentTypes, beforeMessageUid, count, new GetRemoteMessageCallback() {
            @Override
            public void onSuccess(List<Message> list) {
                callbackBuilder(requestId).put("messages", convertMessageList(list, false)).success("onMessagesCallback");
            }

            @Override
            public void onFail(int i) {
                callbackFailure(requestId, i);
            }
        });
    }

    private void getRemoteMessage(@NonNull MethodCall call, @NonNull Result result) {
        final int requestId = call.argument("requestId");
        long messageUid = getLongPara(call, "messageUid");

        ChatManager.Instance().getRemoteMessage(messageUid, new GetOneRemoteMessageCallback() {
            @Override
            public void onSuccess(Message message) {
                callbackBuilder(requestId).put("message", convertMessage(message)).success("onMessageCallback");
            }

            @Override
            public void onFail(int i) {
                callbackFailure(requestId, i);
            }
        });
    }

    private void getMessage(@NonNull MethodCall call, @NonNull Result result) {
        long messageId = getLongPara(call, "messageId");
        result.success(convertMessage(ChatManager.Instance().getMessage(messageId)));
    }

    private void getMessageByUid(@NonNull MethodCall call, @NonNull Result result) {
        long messageUid = getLongPara(call, "messageUid");
        result.success(convertMessage(ChatManager.Instance().getMessageByUid(messageUid)));
    }

    private void searchMessages(@NonNull MethodCall call, @NonNull Result result) {
        Conversation conversation = conversationFromArgument(call, false);
        String keyword = call.argument("keyword");
        boolean order = call.argument("order");
        int limit = call.argument("limit");
        int offset = call.argument("offset");
        String withUser = call.argument("withUser");
        List<Message> list = ChatManager.Instance().searchMessage(conversation, keyword, order, limit, offset, withUser);
        result.success(convertMessageList(list, true));
    }

    private void searchConversationsMessages(@NonNull MethodCall call, @NonNull Result result) {
        List<Conversation.ConversationType> types = conversationTypesFromArgument(call);
        List<Integer> lines = call.argument("lines");
        String keyword = call.argument("keyword");
        String withUser = call.argument("withUser");
        List<Integer> contentTypes = call.argument("contentTypes");
        long fromIndex = getLongPara(call, "fromIndex");
        int count = call.argument("count");
        boolean desc = false;
        if (count < 0) {
            desc = true;
            count = -count;
        }

        List<Message> messageList = new ArrayList<>();

        ChatManager.Instance().searchMessagesEx(types, lines, contentTypes, keyword, fromIndex, desc, count, withUser, new GetMessageCallback() {
            @Override
            public void onSuccess(List<Message> list, boolean b) {
                messageList.addAll(list);
                if (!b) {
                    result.success(convertMessageList(messageList, false));
                }
            }

            @Override
            public void onFail(int i) {
            }
        });
    }

    private MessageContent messageContentFromMaps(Map map) {
        MessagePayload protoData = new MessagePayload();
        if (map == null || map.isEmpty() || !map.containsKey("type")) {
            return null;
        }

        protoData.type = ((int) map.get("type"));
        protoData.searchableContent = ((String) map.get("searchableContent"));
        protoData.pushContent = ((String) map.get("pushContent"));
        protoData.pushData = ((String) map.get("pushData"));
        protoData.content = ((String) map.get("content"));
        protoData.binaryContent = ((byte[]) map.get("binaryContent"));
        protoData.localContent = ((String) map.get("localContent"));
        protoData.mediaType = MessageContentMediaType.mediaType((int) map.get("mediaType"));
        protoData.remoteMediaUrl = ((String) map.get("remoteMediaUrl"));
        protoData.localMediaPath = ((String) map.get("localMediaPath"));
        protoData.mentionedType = ((int) map.get("mentionedType"));
        if (map.get("mentionedTargets") != null) {
            List<String> ts = (List<String>) map.get("mentionedTargets");
            if (!ts.isEmpty()) {
                protoData.mentionedTargets = new ArrayList<>();
                for (int i = 0; i < ts.size(); i++) {
                    protoData.mentionedTargets.add(ts.get(i));
                }
            }
        }
        protoData.extra = ((String) map.get("extra"));

        return ChatManager.Instance().messageContentFromPayload(protoData, ChatManager.Instance().getUserId());
    }

    private void sendMessage(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        Conversation conversation = conversationFromArgument(call, false);
        Map content = call.argument("content");
        MessageContent messageContent = messageContentFromMaps(content);
        List<String> toUsers = call.argument("toUsers");
        int expireDuration = call.argument("expireDuration") == null ? 0 : (Integer) call.argument("expireDuration");


        Message msg = new Message();
        msg.conversation = conversation;
        msg.content = messageContent;
        msg.status = MessageStatus.Sending;
        msg.direction = MessageDirection.Send;
        msg.sender = ChatManager.Instance().getUserId();
        if (toUsers != null) {
            msg.toUsers = toUsers.toArray(new String[0]);
        }

        long[] idArray = new long[1];
        ChatManager.Instance().sendMessage(conversation, messageContent, toUsers != null ? toUsers.toArray(new String[0]) : null, expireDuration, new SendMessageCallback() {
            @Override
            public void onSuccess(long l, long l1) {
                callbackBuilder(requestId).put("messageId", idArray[0]).put("messageUid", l).put("timestamp", l1).success("onSendMessageSuccess");
            }

            @Override
            public void onFail(int i) {
                callbackBuilder(requestId).put("messageId", idArray[0]).put("errorCode", i).success("onSendMessageFailure");
            }

            @Override
            public void onPrepare(long l, long l1) {
                idArray[0] = l;
                msg.messageId = l;
                msg.serverTime = l1;
                result.success(convertMessage(msg));
                callbackBuilder(requestId).put("messageId", idArray[0]).put("message", convertMessage(msg)).success("onSendMessageStart");
            }

            @Override
            public void onProgress(long uploaded, long total) {
                callbackBuilder(requestId).put("messageId", idArray[0]).put("uploaded", uploaded).put("total", total).success("onSendMediaMessageProgress");
            }

            @Override
            public void onMediaUpload(String remoteUrl) {
                callbackBuilder(requestId).put("messageId", idArray[0]).put("remoteUrl", remoteUrl).success("onSendMediaMessageUploaded");
            }
        });
    }

    protected CallbackBuilder callbackBuilder(int requestId) {
        return new CallbackBuilder(requestId);
    }

    protected class CallbackBuilder {
        Map args = new HashMap();
        int requestId;

        private CallbackBuilder(int requestId) {
            this.requestId = requestId;
            args.put("requestId", requestId);
        }

        public CallbackBuilder put(String key, Object value) {
            args.put(key, value);
            return this;
        }

        public CallbackBuilder put(String key, int value) {
            args.put(key, value);
            return this;
        }

        public CallbackBuilder put(String key, long value) {
            args.put(key, value);
            return this;
        }

        public CallbackBuilder put(String key, boolean value) {
            args.put(key, value);
            return this;
        }

        public void success(String event) {
            callback2UI(event, args);
        }

        public void fail(int errorcode) {
            callbackFailure(requestId, errorcode);
        }
    }

    private void sendSavedMessage(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        long messageId = getLongPara(call, "messageId");
        int expireDuration = call.argument("expireDuration");
        Message msg = ChatManager.Instance().getMessage(messageId);
        if (msg != null) {
            ChatManager.Instance().sendSavedMessage(msg, expireDuration, new SendMessageCallback() {
                @Override
                public void onSuccess(long l, long l1) {
                    callbackBuilder(requestId).put("messageId", messageId).put("messageUid", l).put("timestamp", l1).success("onSendMessageSuccess");
                }

                @Override
                public void onFail(int i) {
                    callbackBuilder(requestId).put("messageId", messageId).put("errorCode", i).success("onSendMessageFailure");
                }

                @Override
                public void onPrepare(long l, long l1) {
                    msg.messageId = l;
                    msg.serverTime = l1;
                    callbackBuilder(requestId).put("messageId", messageId).put("message", convertMessage(msg)).success("onSendMessageStart");
                }

                @Override
                public void onProgress(long uploaded, long total) {
                    callbackBuilder(requestId).put("messageId", messageId).put("uploaded", uploaded).put("total", total).success("onSendMediaMessageProgress");
                }

                @Override
                public void onMediaUpload(String remoteUrl) {
                    callbackBuilder(requestId).put("messageId", messageId).put("remoteUrl", remoteUrl).success("onSendMediaMessageUploaded");
                }
            });
        }
    }

    private void cancelSendingMessage(@NonNull MethodCall call, @NonNull Result result) {
        long messageId = getLongPara(call, "messageId");
        boolean ret = ChatManager.Instance().cancelSendingMessage(messageId);
        result.success(ret);
    }

    private void recallMessage(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        long messageUid = getLongPara(call, "messageUid");
        Message msg = ChatManager.Instance().getMessageByUid(messageUid);
        if (msg != null) {
            ChatManager.Instance().recallMessage(msg, new cn.wildfirechat.remote.GeneralCallback() {
                @Override
                public void onSuccess() {
                    callbackBuilder(requestId).success("onOperationVoidSuccess");
                    Map<String, Object> data = new HashMap<>();
                    data.put("messageUid", messageUid);
                    callback2UI("onRecallMessage", data);
                }

                @Override
                public void onFail(int i) {
                    callbackBuilder(requestId).fail(i);
                }
            });
        }
    }

    private void uploadMedia(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        String fileName = call.argument("fileName");
        int mediaType = call.argument("mediaType");
        byte[] mediaData = call.argument("mediaData");

        ChatManager.Instance().uploadMedia2(fileName, mediaData, mediaType, new UploadMediaCallback() {
            @Override
            public void onSuccess(String s) {
                callbackBuilder(requestId)
                    .put("remoteUrl", s)
                    .success("onUploadMediaUploaded");
            }

            @Override
            public void onProgress(long l, long l1) {
                callbackBuilder(requestId)
                    .put("uploaded", l)
                    .put("total", l1)
                    .success("onUploadMediaProgress");
            }

            @Override
            public void onFail(int i) {
                callbackBuilder(requestId).fail(i);
            }
        });
    }

    private void uploadMediaFile(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        String filePath = call.argument("filePath");
        int mediaType = call.argument("mediaType");

        ChatManager.Instance().uploadMediaFile(filePath, mediaType, new UploadMediaCallback() {
            @Override
            public void onSuccess(String s) {
                callbackBuilder(requestId)
                        .put("remoteUrl", s)
                        .success("onUploadMediaUploaded");
            }

            @Override
            public void onProgress(long l, long l1) {
                callbackBuilder(requestId)
                        .put("uploaded", l)
                        .put("total", l1)
                        .success("onUploadMediaProgress");
            }

            @Override
            public void onFail(int i) {
                callbackBuilder(requestId).fail(i);
            }
        });
    }

    private void getMediaUploadUrl(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        String fileName = call.argument("fileName");
        int mediaType = call.argument("mediaType");
        String contentType = call.argument("contentType");

        ChatManager.Instance().getUploadUrl(fileName, MessageContentMediaType.mediaType(mediaType), contentType, new GetUploadUrlCallback() {
            @Override
            public void onSuccess(String s, String s1, String s2, int i) {
                callbackBuilder(requestId)
                    .put("uploadUrl", s)
                    .put("downloadUrl", s1)
                    .put("backupUploadUrl", s2)
                    .put("type", i)
                    .success("onGetUploadUrl");
            }

            @Override
            public void onFail(int i) {
                callbackBuilder(requestId).fail(i);
            }
        });
    }

    private void isSupportBigFilesUpload(@NonNull MethodCall call, @NonNull Result result) {
        boolean ret = ChatManager.Instance().isSupportBigFilesUpload();
        result.success(ret);
    }

    private void deleteMessage(@NonNull MethodCall call, @NonNull Result result) {
        long messageId = getLongPara(call, "messageId");
        Message msg = ChatManager.Instance().getMessage(messageId);
        boolean ret = false;
        if (msg != null) {
            ret = ChatManager.Instance().deleteMessage(msg);
        }
        result.success(ret);
    }

    private void batchDeleteMessages(@NonNull MethodCall call, @NonNull Result result) {
        List<Long> messageUids = call.argument("messageUids");
        boolean ret = ChatManager.Instance().batchDeleteMessages(messageUids);
        result.success(ret);
    }

    private void deleteRemoteMessage(@NonNull MethodCall call, @NonNull Result result) {
        long messageUid = getLongPara(call, "messageUid");
        final int requestId = call.argument("requestId");
        ChatManager.Instance().deleteRemoteMessage(messageUid, new GeneralVoidCallback(requestId));
    }

    private void clearMessages(@NonNull MethodCall call, @NonNull Result result) {
        Conversation conversation = conversationFromArgument(call, false);
        long before = getLongPara(call, "before");
        if (before > 0)
            ChatManager.Instance().clearMessages(conversation, before);
        else
            ChatManager.Instance().clearMessages(conversation);
        result.success(true);
    }

    private void clearMessagesKeepLatest(@NonNull MethodCall call, @NonNull Result result) {
        Conversation conversation = conversationFromArgument(call, false);
        int keepCount = call.argument("keepCount");
        ChatManager.Instance().clearMessagesKeepLatest(conversation, keepCount);
        result.success(true);
    }

    private void clearRemoteConversationMessage(@NonNull MethodCall call, @NonNull Result result) {
        Conversation conversation = conversationFromArgument(call, false);
        final int requestId = call.argument("requestId");
        ChatManager.Instance().clearRemoteConversationMessage(conversation, new GeneralVoidCallback(requestId));
    }

    private void setMediaMessagePlayed(@NonNull MethodCall call, @NonNull Result result) {
        long messageId = getLongPara(call, "messageId");
        ChatManager.Instance().setMediaMessagePlayed(messageId);
        result.success(null);
    }

    private void setMessageLocalExtra(@NonNull MethodCall call, @NonNull Result result) {
        long messageId = getLongPara(call, "messageId");
        String localExtra = call.argument("localExtra");
        ChatManager.Instance().setMessageLocalExtra(messageId, localExtra);
    }

    private void insertMessage(@NonNull MethodCall call, @NonNull Result result) {
        Conversation conversation = conversationFromArgument(call, false);
        Map content = call.argument("content");
        MessageContent messageContent = messageContentFromMaps(content);
        int status = call.argument("status");
        long serverTime = getLongPara(call, "serverTime");
        if(serverTime == 0) {
            serverTime = System.currentTimeMillis();
        }
        List<String> toUsers = call.argument("toUsers");
        String sender = call.argument("sender");
        if(TextUtils.isEmpty(sender)) {
            sender = ChatManager.Instance().getUserId();
        }

        String[] tos = null;
        if (toUsers != null) {
            tos = toUsers.toArray(new String[0]);
        }

        Message msg = ChatManager.Instance().insertMessage(conversation, sender, messageContent, MessageStatus.status(status), false, tos, serverTime);
        result.success(convertMessage(msg));
    }

    private void updateMessage(@NonNull MethodCall call, @NonNull Result result) {
        long messageId = getLongPara(call, "messageId");
        Map content = call.argument("content");
        MessageContent messageContent = messageContentFromMaps(content);
        boolean ret = ChatManager.Instance().updateMessage(messageId, messageContent);
        result.success(ret);
    }

    private void updateRemoteMessageContent(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        long messageUid = getLongPara(call, "messageUid");
        Map content = call.argument("content");
        MessageContent messageContent = messageContentFromMaps(content);
        boolean distribute = call.argument("distribute");
        boolean updateLocal = call.argument("updateLocal");
        ChatManager.Instance().updateRemoteMessageContent(messageUid, messageContent, distribute, updateLocal, new GeneralVoidCallback(requestId));
    }

    private void updateMessageStatus(@NonNull MethodCall call, @NonNull Result result) {
        long messageId = getLongPara(call, "messageId");
        int status = call.argument("status");
        boolean ret = ChatManager.Instance().updateMessage(messageId, MessageStatus.status(status));
        result.success(ret);
    }

    private void getMessageCount(@NonNull MethodCall call, @NonNull Result result) {
        Conversation conversation = conversationFromArgument(call, false);
        int count = ChatManager.Instance().getMessageCount(conversation);
        result.success(count);
    }

    private void getUserInfo(@NonNull MethodCall call, @NonNull Result result) {
        String userId = call.argument("userId");
        boolean refresh = call.argument("refresh");
        String groupId = call.argument("groupId");
        UserInfo userInfo = ChatManager.Instance().getUserInfo(userId, groupId, refresh);
        result.success(convertUserInfo(userInfo));
    }

    private void getUserInfos(@NonNull MethodCall call, @NonNull Result result) {
        List<String> userIds = call.argument("userIds");
        String groupId = call.argument("groupId");
        List<UserInfo> userInfos = ChatManager.Instance().getUserInfos(userIds, groupId);
        result.success(convertUserInfoList(userInfos));
    }

    private void searchUser(@NonNull MethodCall call, @NonNull Result result) {
        final int requestId = call.argument("requestId");
        String keyword = call.argument("keyword");
        int searchType = call.argument("searchType");
        int page = call.argument("page");
        ChatManager.Instance().searchUser(keyword, ChatManager.SearchUserType.type(searchType), page, new SearchUserCallback() {
            @Override
            public void onSuccess(List<UserInfo> list) {
                callbackBuilder(requestId).put("users", convertUserInfoList(list)).success("onSearchUserResult");
            }

            @Override
            public void onFail(int i) {
                callbackBuilder(requestId).fail(i);
            }
        });
    }

    private void getUserInfoAsync(@NonNull MethodCall call, @NonNull Result result) {
        final int requestId = call.argument("requestId");
        String userId = call.argument("userId");
        String groupId = call.argument("groupId");
        boolean refresh = call.argument("refresh");

        ChatManager.Instance().getUserInfo(userId, groupId, refresh, new GetUserInfoCallback() {
            @Override
            public void onSuccess(UserInfo userInfo) {
                callbackBuilder(requestId).put("user", convertUserInfo(userInfo)).success("getUserInfoAsyncCallback");
            }

            @Override
            public void onFail(int i) {
                callbackBuilder(requestId).fail(i);
            }
        });
    }

    private void isMyFriend(@NonNull MethodCall call, @NonNull Result result) {
        String userId = call.argument("userId");
        boolean ret = ChatManager.Instance().isMyFriend(userId);
        result.success(ret);
    }

    private void getMyFriendList(@NonNull MethodCall call, @NonNull Result result) {
        boolean refresh = call.argument("refresh");
        result.success(ChatManager.Instance().getMyFriendList(refresh));
    }

    private void searchFriends(@NonNull MethodCall call, @NonNull Result result) {
        String keyword = call.argument("keyword");
        result.success(convertUserInfoList(ChatManager.Instance().searchFriends(keyword)));
    }

    private void getFriends(@NonNull MethodCall call, @NonNull Result result) {
        boolean refresh = call.argument("refresh");
        result.success(convertFriendList(ChatManager.Instance().getFriendList(refresh)));
    }

    private void searchGroups(@NonNull MethodCall call, @NonNull Result result) {
        String keyword = call.argument("keyword");
        result.success(convertGroupSearchResultList(ChatManager.Instance().searchGroups(keyword)));
    }

    private void getIncommingFriendRequest(@NonNull MethodCall call, @NonNull Result result) {
        result.success(convertProtoFriendRequestList(ChatManager.Instance().getFriendRequest(true)));
    }

    private void getOutgoingFriendRequest(@NonNull MethodCall call, @NonNull Result result) {
        result.success(convertProtoFriendRequestList(ChatManager.Instance().getFriendRequest(false)));
    }

    private void getFriendRequest(@NonNull MethodCall call, @NonNull Result result) {
        String userId = call.argument("userId");
        int direction = call.argument("direction");
        result.success(convertFriendRequest(ChatManager.Instance().getFriendRequest(userId, direction > 0)));
    }

    private void loadFriendRequestFromRemote(@NonNull MethodCall call, @NonNull Result result) {
        ChatManager.Instance().loadFriendRequestFromRemote();
        result.success(null);
    }

    private void getUnreadFriendRequestStatus(@NonNull MethodCall call, @NonNull Result result) {
        result.success(ChatManager.Instance().getUnreadFriendRequestStatus());
    }

    private void clearUnreadFriendRequestStatus(@NonNull MethodCall call, @NonNull Result result) {
        ChatManager.Instance().clearUnreadFriendRequestStatus();
        result.success(true);
    }

    private void clearFriendRequest(@NonNull MethodCall call, @NonNull Result result) {
        int direction = call.argument("direction");
        long beforeTime = getLongPara(call, "beforeTime");
        result.success(ChatManager.Instance().clearFriendRequest(direction == 1, beforeTime));
    }

    private void deleteFriendRequest(@NonNull MethodCall call, @NonNull Result result) {
        String userId = call.argument("userId");
        int direction = call.argument("direction");
        result.success(ChatManager.Instance().deleteFriendRequest(userId, direction == 1));
    }

    private void deleteFriend(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        String userId = call.argument("userId");
        ChatManager.Instance().deleteFriend(userId, new GeneralVoidCallback(requestId));
    }

    private void sendFriendRequest(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        String userId = call.argument("userId");
        String reason = call.argument("reason");
        String extra = call.argument("extra");
        ChatManager.Instance().sendFriendRequest(userId, reason, extra, new GeneralVoidCallback(requestId));
    }

    private void handleFriendRequest(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        String userId = call.argument("userId");
        String extra = call.argument("extra");
        boolean accept = call.argument("accept");
        ChatManager.Instance().handleFriendRequest(userId, accept, extra, new GeneralVoidCallback(requestId));
    }

    private void getFriendAlias(@NonNull MethodCall call, @NonNull Result result) {
        String friendId = call.argument("friendId");
        result.success(ChatManager.Instance().getFriendAlias(friendId));
    }

    private void setFriendAlias(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        String friendId = call.argument("friendId");
        String alias = call.argument("alias");

        ChatManager.Instance().setFriendAlias(friendId, alias, new GeneralVoidCallback(requestId));
    }

    private void getFriendExtra(@NonNull MethodCall call, @NonNull Result result) {
        String friendId = call.argument("friendId");
        result.success(ChatManager.Instance().getFriendExtra(friendId));
    }

    private void isBlackListed(@NonNull MethodCall call, @NonNull Result result) {
        String userId = call.argument("userId");
        result.success(ChatManager.Instance().isBlackListed(userId));
    }

    private void getBlackList(@NonNull MethodCall call, @NonNull Result result) {
        boolean refresh = call.argument("refresh");
        result.success(ChatManager.Instance().getBlackList(refresh));
    }

    private void setBlackList(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        String userId = call.argument("userId");
        boolean isBlackListed = call.argument("isBlackListed");

        ChatManager.Instance().setBlackList(userId, isBlackListed, new GeneralVoidCallback(requestId));
    }

    private void getGroupMembers(@NonNull MethodCall call, @NonNull Result result) {
        String groupId = call.argument("groupId");
        boolean refresh = call.argument("refresh");
        result.success(convertGroupMemberList(ChatManager.Instance().getGroupMembers(groupId, refresh)));
    }

    private void getGroupMembersByCount(@NonNull MethodCall call, @NonNull Result result) {
        String groupId = call.argument("groupId");
        int count = call.argument("count");
        result.success(convertGroupMemberList(ChatManager.Instance().getGroupMembersByCount(groupId, count)));
    }

    private void getGroupMembersByTypes(@NonNull MethodCall call, @NonNull Result result) {
        String groupId = call.argument("groupId");
        int memberType = call.argument("memberType");
        result.success(convertGroupMemberList(ChatManager.Instance().getGroupMembersByType(groupId, GroupMember.GroupMemberType.type(memberType))));
    }

    private void getGroupMembersAsync(@NonNull MethodCall call, @NonNull Result result) {
        final int requestId = call.argument("requestId");
        final String groupId = call.argument("groupId");
        boolean refresh = call.argument("refresh");

        ChatManager.Instance().getGroupMembers(groupId, refresh, new GetGroupMembersCallback() {
            @Override
            public void onSuccess(List<GroupMember> list) {
                callbackBuilder(requestId).put("groupId", groupId).put("members", convertGroupMemberList(list)).success("getGroupMembersAsyncCallback");
            }

            @Override
            public void onFail(int i) {
                callbackBuilder(requestId).fail(i);
            }
        });
    }

    private void getGroupInfo(@NonNull MethodCall call, @NonNull Result result) {
        String groupId = call.argument("groupId");
        boolean refresh = call.argument("refresh");
        result.success(convertGroupInfo(ChatManager.Instance().getGroupInfo(groupId, refresh)));
    }

    private void getGroupInfos(@NonNull MethodCall call, @NonNull Result result) {
        List<String> groupIds = call.argument("groupIds");
        boolean refresh = call.argument("refresh");
        result.success(convertGroupInfoList(ChatManager.Instance().getGroupInfos(groupIds, refresh)));
    }

    private void getGroupInfoAsync(@NonNull MethodCall call, @NonNull Result result) {
        final int requestId = call.argument("requestId");
        String groupId = call.argument("groupId");
        boolean refresh = call.argument("refresh");

        ChatManager.Instance().getGroupInfo(groupId, refresh, new GetGroupInfoCallback() {
            @Override
            public void onSuccess(GroupInfo groupInfo) {
                callbackBuilder(requestId).put("groupInfo", convertGroupInfo(groupInfo)).success("getGroupInfoAsyncCallback");
            }

            @Override
            public void onFail(int i) {
                callbackBuilder(requestId).fail(i);
            }
        });
    }

    private void getGroupMember(@NonNull MethodCall call, @NonNull Result result) {
        String groupId = call.argument("groupId");
        String memberId = call.argument("memberId");
        result.success(convertGroupMember(ChatManager.Instance().getGroupMember(groupId, memberId)));
    }

    private void createGroup(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        String groupId = call.argument("groupId");
        String groupName = call.argument("groupName");
        String groupExtra = call.argument("groupExtra");
        String groupPortrait = call.argument("groupPortrait");
        int groupType = call.argument("type");
        String memberExtra = call.argument("memberExtra");
        List<String> groupMembers = call.argument("groupMembers");
        List<Integer> notifyLines = call.argument("notifyLines");
        if (notifyLines == null) {
            notifyLines = new ArrayList<>();
        }
        if (notifyLines.isEmpty()) {
            notifyLines.add(0);
        }
        Map notifyContent = call.argument("notifyContent");
        MessageContent messageContent = messageContentFromMaps(notifyContent);
        ChatManager.Instance().createGroup(groupId, groupName, groupPortrait, GroupInfo.GroupType.type(groupType), groupExtra, groupMembers, memberExtra, notifyLines, messageContent, new GeneralStringCallback(requestId));
    }

    private void addGroupMembers(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        String groupId = call.argument("groupId");
        String extra = call.argument("extra");
        List<String> groupMembers = call.argument("groupMembers");
        List<Integer> notifyLines = call.argument("notifyLines");
        if (notifyLines == null) {
            notifyLines = new ArrayList<>();
        }
        if (notifyLines.isEmpty()) {
            notifyLines.add(0);
        }
        Map notifyContent = call.argument("notifyContent");
        MessageContent messageContent = messageContentFromMaps(notifyContent);

        ChatManager.Instance().addGroupMembers(groupId, groupMembers, extra, notifyLines, messageContent, new GeneralVoidCallback(requestId));
    }

    private void kickoffGroupMembers(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        String groupId = call.argument("groupId");
        List<String> groupMembers = call.argument("groupMembers");
        List<Integer> notifyLines = call.argument("notifyLines");
        if (notifyLines == null) {
            notifyLines = new ArrayList<>();
        }
        if (notifyLines.isEmpty()) {
            notifyLines.add(0);
        }
        Map notifyContent = call.argument("notifyContent");
        MessageContent messageContent = messageContentFromMaps(notifyContent);

        ChatManager.Instance().removeGroupMembers(groupId, groupMembers, notifyLines, messageContent, new GeneralVoidCallback(requestId));
    }

    private void quitGroup(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        String groupId = call.argument("groupId");
        List<Integer> notifyLines = call.argument("notifyLines");
        if (notifyLines == null) {
            notifyLines = new ArrayList<>();
        }
        if (notifyLines.isEmpty()) {
            notifyLines.add(0);
        }
        Map notifyContent = call.argument("notifyContent");
        MessageContent messageContent = messageContentFromMaps(notifyContent);

        ChatManager.Instance().quitGroup(groupId, notifyLines, messageContent, new GeneralVoidCallback(requestId));
    }

    private void quitGroupEx(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        boolean keepMessage = call.argument("keepMessage");
        String groupId = call.argument("groupId");
        List<Integer> notifyLines = call.argument("notifyLines");
        if (notifyLines == null) {
            notifyLines = new ArrayList<>();
        }
        if (notifyLines.isEmpty()) {
            notifyLines.add(0);
        }
        Map notifyContent = call.argument("notifyContent");
        MessageContent messageContent = messageContentFromMaps(notifyContent);

        ChatManager.Instance().quitGroup(groupId, keepMessage, notifyLines, messageContent, new GeneralVoidCallback(requestId));
    }

    private void dismissGroup(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        String groupId = call.argument("groupId");
        List<Integer> notifyLines = call.argument("notifyLines");
        if (notifyLines == null) {
            notifyLines = new ArrayList<>();
        }
        if (notifyLines.isEmpty()) {
            notifyLines.add(0);
        }
        Map notifyContent = call.argument("notifyContent");
        MessageContent messageContent = messageContentFromMaps(notifyContent);

        ChatManager.Instance().dismissGroup(groupId, notifyLines, messageContent, new GeneralVoidCallback(requestId));
    }

    private void modifyGroupInfo(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        String groupId = call.argument("groupId");
        int modifyType = call.argument("modifyType");
        String value = call.argument("value");
        List<Integer> notifyLines = call.argument("notifyLines");
        if (notifyLines == null) {
            notifyLines = new ArrayList<>();
        }
        if (notifyLines.isEmpty()) {
            notifyLines.add(0);
        }
        Map notifyContent = call.argument("notifyContent");
        MessageContent messageContent = messageContentFromMaps(notifyContent);

        ChatManager.Instance().modifyGroupInfo(groupId, ModifyGroupInfoType.type(modifyType), value, notifyLines, messageContent, new GeneralVoidCallback(requestId));
    }

    private void modifyGroupAlias(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        String groupId = call.argument("groupId");
        String newAlias = call.argument("newAlias");
        List<Integer> notifyLines = call.argument("notifyLines");
        if (notifyLines == null) {
            notifyLines = new ArrayList<>();
        }
        if (notifyLines.isEmpty()) {
            notifyLines.add(0);
        }
        Map notifyContent = call.argument("notifyContent");
        MessageContent messageContent = messageContentFromMaps(notifyContent);

        ChatManager.Instance().modifyGroupAlias(groupId, newAlias, notifyLines, messageContent, new GeneralVoidCallback(requestId));
    }

    private void modifyGroupMemberAlias(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        String groupId = call.argument("groupId");
        String memberId = call.argument("memberId");
        String newAlias = call.argument("newAlias");
        List<Integer> notifyLines = call.argument("notifyLines");
        if (notifyLines == null) {
            notifyLines = new ArrayList<>();
        }
        if (notifyLines.isEmpty()) {
            notifyLines.add(0);
        }
        Map notifyContent = call.argument("notifyContent");
        MessageContent messageContent = messageContentFromMaps(notifyContent);

        ChatManager.Instance().modifyGroupMemberAlias(groupId, memberId, newAlias, notifyLines, messageContent, new GeneralVoidCallback(requestId));
    }

    private void transferGroup(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        String groupId = call.argument("groupId");
        String newOwner = call.argument("newOwner");
        List<Integer> notifyLines = call.argument("notifyLines");
        if (notifyLines == null) {
            notifyLines = new ArrayList<>();
        }
        if (notifyLines.isEmpty()) {
            notifyLines.add(0);
        }
        Map notifyContent = call.argument("notifyContent");
        MessageContent messageContent = messageContentFromMaps(notifyContent);

        ChatManager.Instance().transferGroup(groupId, newOwner, notifyLines, messageContent, new GeneralVoidCallback(requestId));
    }

    private void setGroupManager(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        String groupId = call.argument("groupId");
        boolean isSet = call.argument("isSet");
        List<String> memberIds = call.argument("memberIds");
        List<Integer> notifyLines = call.argument("notifyLines");
        if (notifyLines == null) {
            notifyLines = new ArrayList<>();
        }
        if (notifyLines.isEmpty()) {
            notifyLines.add(0);
        }
        Map notifyContent = call.argument("notifyContent");
        MessageContent messageContent = messageContentFromMaps(notifyContent);

        ChatManager.Instance().setGroupManager(groupId, isSet, memberIds, notifyLines, messageContent, new GeneralVoidCallback(requestId));
    }

    private void muteGroupMember(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        String groupId = call.argument("groupId");
        boolean isSet = call.argument("isSet");
        List<String> memberIds = call.argument("memberIds");
        List<Integer> notifyLines = call.argument("notifyLines");
        if (notifyLines == null) {
            notifyLines = new ArrayList<>();
        }
        if (notifyLines.isEmpty()) {
            notifyLines.add(0);
        }
        Map notifyContent = call.argument("notifyContent");
        MessageContent messageContent = messageContentFromMaps(notifyContent);

        ChatManager.Instance().muteGroupMember(groupId, isSet, memberIds, notifyLines, messageContent, new GeneralVoidCallback(requestId));
    }

    private void allowGroupMember(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        String groupId = call.argument("groupId");
        boolean isSet = call.argument("isSet");
        List<String> memberIds = call.argument("memberIds");
        List<Integer> notifyLines = call.argument("notifyLines");
        if (notifyLines == null) {
            notifyLines = new ArrayList<>();
        }
        if (notifyLines.isEmpty()) {
            notifyLines.add(0);
        }
        Map notifyContent = call.argument("notifyContent");
        MessageContent messageContent = messageContentFromMaps(notifyContent);

        ChatManager.Instance().allowGroupMember(groupId, isSet, memberIds, notifyLines, messageContent, new GeneralVoidCallback(requestId));
    }

    private void getGroupRemark(@NonNull MethodCall call, @NonNull Result result) {
        String groupId = call.argument("groupId");
        result.success(ChatManager.Instance().getGroupRemark(groupId));
    }

    private void setGroupRemark(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        String groupId = call.argument("groupId");
        String remark = call.argument("remark");

        ChatManager.Instance().setGroupRemark(groupId, remark, new GeneralVoidCallback(requestId));
    }

    private void getFavGroups(@NonNull MethodCall call, @NonNull Result result) {
        ChatManager.Instance().getFavGroups(new GetGroupsCallback() {
            @Override
            public void onSuccess(List<GroupInfo> list) {
                List<String> outlist = new ArrayList<>();
                if (list != null) {
                    for (GroupInfo groupInfo : list) {
                        outlist.add(groupInfo.target);
                    }
                }
                result.success(outlist);
            }

            @Override
            public void onFail(int i) {
                result.success("");
            }
        });
    }

    private void isFavGroup(@NonNull MethodCall call, @NonNull Result result) {
        String groupId = call.argument("groupId");
        result.success(ChatManager.Instance().isFavGroup(groupId));
    }

    private void setFavGroup(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        String groupId = call.argument("groupId");
        boolean isFav = call.argument("isFav");

        ChatManager.Instance().setFavGroup(groupId, isFav, new GeneralVoidCallback(requestId));
    }

    private void getUserSetting(@NonNull MethodCall call, @NonNull Result result) {
        int scope = call.argument("scope");
        String key = call.argument("key");
        result.success(ChatManager.Instance().getUserSetting(scope, key));
    }

    private void getUserSettings(@NonNull MethodCall call, @NonNull Result result) {
        int scope = call.argument("scope");
        result.success(ChatManager.Instance().getUserSettings(scope));
    }

    private void setUserSetting(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        int scope = call.argument("scope");
        String key = call.argument("key");
        String value = call.argument("value");

        ChatManager.Instance().setUserSetting(scope, key, value, new GeneralVoidCallback(requestId));
    }

    private void modifyMyInfo(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        Map values = call.argument("values");

        List<ModifyMyInfoEntry> list = new ArrayList<>();
        for (Object o : values.keySet()) {
            ModifyMyInfoEntry entry = new ModifyMyInfoEntry();
            entry.type = ModifyMyInfoType.type((Integer) o);
            entry.value = (String) values.get(o);
            list.add(entry);
        }
        ChatManager.Instance().modifyMyInfo(list, new GeneralVoidCallback(requestId));
    }

    private void isGlobalSilent(@NonNull MethodCall call, @NonNull Result result) {
        result.success(ChatManager.Instance().isGlobalSilent());
    }

    private void setGlobalSilent(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        boolean isSilent = call.argument("isSilent");
        ChatManager.Instance().setGlobalSilent(isSilent, new GeneralVoidCallback(requestId));
    }

    private void isVoipNotificationSilent(@NonNull MethodCall call, @NonNull Result result) {
        result.success(ChatManager.Instance().isVoipSilent());
    }

    private void setVoipNotificationSilent(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        boolean isSilent = call.argument("isSilent");
        ChatManager.Instance().setVoipSilent(isSilent, new GeneralVoidCallback(requestId));
    }

    private void isEnableSyncDraft(@NonNull MethodCall call, @NonNull Result result) {
        result.success(!ChatManager.Instance().isDisableSyncDraft());
    }

    private void setEnableSyncDraft(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        boolean enable = call.argument("enable");
        ChatManager.Instance().setDisableSyncDraft(!enable, new GeneralVoidCallback(requestId));
    }

    private void getNoDisturbingTimes(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        ChatManager.Instance().getNoDisturbingTimes(new ChatManager.GetNoDisturbingTimesCallback() {
            @Override
            public void onResult(boolean b, int i, int i1) {
                if (b) {
                    callbackBuilder(requestId).put("first", i).put("second", i1).success("onOperationVoidSuccess");
                } else {
                    callbackBuilder(requestId).fail(-1);
                }
            }
        });
    }

    private void setNoDisturbingTimes(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        int startMins = call.argument("startMins");
        int endMins = call.argument("endMins");
        ChatManager.Instance().setNoDisturbingTimes(startMins, endMins, new GeneralVoidCallback(requestId));
    }

    private void clearNoDisturbingTimes(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        ChatManager.Instance().clearNoDisturbingTimes(new GeneralVoidCallback(requestId));
    }

    private void isNoDisturbing(@NonNull MethodCall call, @NonNull Result result) {
        result.success(ChatManager.Instance().isNoDisturbing());
    }

    private void isHiddenNotificationDetail(@NonNull MethodCall call, @NonNull Result result) {
        result.success(ChatManager.Instance().isHiddenNotificationDetail());
    }

    private void setHiddenNotificationDetail(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        boolean isHidden = call.argument("isHidden");
        ChatManager.Instance().setHiddenNotificationDetail(isHidden, new GeneralVoidCallback(requestId));
    }

    private void isHiddenGroupMemberName(@NonNull MethodCall call, @NonNull Result result) {
        String groupId = call.argument("groupId");
        String value = ChatManager.Instance().getUserSetting(UserSettingScope.GroupHideNickname, groupId);
        result.success("1".equals(value));
    }

    private void setHiddenGroupMemberName(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        String groupId = call.argument("groupId");
        boolean isHidden = call.argument("isHidden");

        ChatManager.Instance().setHiddenGroupMemberName(groupId, isHidden, new GeneralVoidCallback(requestId));
    }

    private void getMyGroups(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        ChatManager.Instance().getMyGroups(new StringListCallback() {
            @Override
            public void onSuccess(List<String> list) {
                callbackBuilder(requestId).put("strings", list).success("onOperationStringListSuccess");
            }

            @Override
            public void onFail(int i) {
                callbackFailure(requestId, i);
            }
        });
    }

    private void getCommonGroups(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        String userId = call.argument("userId");
        ChatManager.Instance().getCommonGroups(userId, new StringListCallback() {
            @Override
            public void onSuccess(List<String> list) {
                callbackBuilder(requestId).put("strings", list).success("onOperationStringListSuccess");
            }

            @Override
            public void onFail(int i) {
                callbackFailure(requestId, i);
            }
        });
    }

    private void isUserEnableReceipt(@NonNull MethodCall call, @NonNull Result result) {
        result.success(ChatManager.Instance().isUserEnableReceipt());
    }

    private void setUserEnableReceipt(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        boolean isEnable = call.argument("isEnable");
        ChatManager.Instance().setUserEnableReceipt(isEnable, new GeneralVoidCallback(requestId));
    }

    private void getFavUsers(@NonNull MethodCall call, @NonNull Result result) {
        ChatManager.Instance().getFavUsers(new StringListCallback() {
            @Override
            public void onSuccess(List<String> list) {
                result.success(list);
            }

            @Override
            public void onFail(int i) {
                result.success(null);
            }
        });
    }

    private void isFavUser(@NonNull MethodCall call, @NonNull Result result) {
        String userId = call.argument("userId");
        result.success(ChatManager.Instance().isFavUser(userId));
    }

    private void setFavUser(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        String userId = call.argument("userId");
        boolean isFav = call.argument("isFav");

        ChatManager.Instance().setFavUser(userId, isFav, new GeneralVoidCallback(requestId));
    }

    private void joinChatroom(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        String chatroomId = call.argument("chatroomId");
        ChatManager.Instance().joinChatRoom(chatroomId, new GeneralVoidCallback(requestId));
    }

    private void quitChatroom(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        String chatroomId = call.argument("chatroomId");
        ChatManager.Instance().quitChatRoom(chatroomId, new GeneralVoidCallback(requestId));
    }

    private void getChatroomInfo(@NonNull MethodCall call, @NonNull Result result) {
        final int requestId = call.argument("requestId");
        final String chatroomId = call.argument("chatroomId");
        long updateDt = getLongPara(call, "updateDt");

        ChatManager.Instance().getChatRoomInfo(chatroomId, updateDt, new GetChatRoomInfoCallback() {
            @Override
            public void onSuccess(ChatRoomInfo chatRoomInfo) {
                callbackBuilder(requestId).put("chatroomInfo", convertChatroomInfo(chatRoomInfo)).success("onGetChatroomInfoResult");
            }

            @Override
            public void onFail(int i) {
                callbackBuilder(requestId).fail(i);
            }
        });
    }

    private void getChatroomMemberInfo(@NonNull MethodCall call, @NonNull Result result) {
        final int requestId = call.argument("requestId");
        final String chatroomId = call.argument("chatroomId");
        int maxCount = call.argument("maxCount");

        ChatManager.Instance().getChatRoomMembersInfo(chatroomId, maxCount, new GetChatRoomMembersInfoCallback() {
            @Override
            public void onSuccess(ChatRoomMembersInfo chatRoomMembersInfo) {
                callbackBuilder(requestId).put("chatroomMemberInfo", convertChatroomMemberInfo(chatRoomMembersInfo)).success("onGetChatroomMemberInfoResult");
            }

            @Override
            public void onFail(int i) {
                callbackBuilder(requestId).fail(i);
            }
        });
    }

    private void getJoinedChatroomId(@NonNull MethodCall call, @NonNull Result result) {
        String chatroomId = ChatManager.Instance().getJoinedChatroom();
        result.success(chatroomId);
    }

    private void createChannel(@NonNull MethodCall call, @NonNull Result result) {
        final int requestId = call.argument("requestId");
        String channelName = call.argument("name");
        String channelPortrait = call.argument("portrait");
        String desc = call.argument("desc");
        String extra = call.argument("extra");

        ChatManager.Instance().createChannel("", channelName, channelPortrait, desc, extra, new GeneralCallback2(){
            @Override
            public void onSuccess(String channelId) {
                Map<String, Object> stringObjectMap = convertChannelInfo(ChatManager.Instance().getChannelInfo(channelId, false));
                callbackBuilder(requestId).put("channelInfo", stringObjectMap).success("onCreateChannelSuccess");
            }

            @Override
            public void onFail(int i) {
                callbackFailure(requestId, i);
            }
        } );
    }

    private void getChannelInfo(@NonNull MethodCall call, @NonNull Result result) {
        String channelId = call.argument("channelId");
        boolean refresh = call.argument("refresh");
        result.success(convertChannelInfo(ChatManager.Instance().getChannelInfo(channelId, refresh)));
    }

    private void modifyChannelInfo(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        String channelId = call.argument("channelId");
        int type = call.argument("type");
        String newValue = call.argument("newValue");

        ChatManager.Instance().modifyChannelInfo(channelId, ModifyChannelInfoType.type(type), newValue, new GeneralVoidCallback(requestId));
    }

    private void searchChannel(@NonNull MethodCall call, @NonNull Result result) {
        final int requestId = call.argument("requestId");
        String keyword = call.argument("keyword");
        ChatManager.Instance().searchChannel(keyword, new SearchChannelCallback() {
            @Override
            public void onSuccess(List<ChannelInfo> list) {
                callbackBuilder(requestId).put("channelInfos", convertChannelInfoList(list)).success("onSearchChannelResult");
            }

            @Override
            public void onFail(int i) {
                callbackBuilder(requestId).fail(i);
            }
        });
    }

    private void isListenedChannel(@NonNull MethodCall call, @NonNull Result result) {
        String channelId = call.argument("channelId");
        result.success(ChatManager.Instance().isListenedChannel(channelId));
    }

    private void listenChannel(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        String channelId = call.argument("channelId");
        boolean listen = call.argument("listen");

        ChatManager.Instance().listenChannel(channelId, listen, new GeneralVoidCallback(requestId));
    }

    private void getRemoteListenedChannels(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        ChatManager.Instance().getRemoteListenedChannels(new GeneralCallback3() {
            @Override
            public void onSuccess(List<String> list) {
                callbackBuilder(requestId).put("strings", list).success("onOperationStringListSuccess");
            }

            @Override
            public void onFail(int i) {
                callbackFailure(requestId, i);
            }
        });
    }

    private void destroyChannel(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        String channelId = call.argument("channelId");
        ChatManager.Instance().destoryChannel(channelId, new GeneralVoidCallback(requestId));
    }

    private void getMyChannels(@NonNull MethodCall call, @NonNull Result result) {
        result.success(ChatManager.Instance().getMyChannels());
    }

    private void getOnlineInfos(@NonNull MethodCall call, @NonNull Result result) {
        List<PCOnlineInfo> list = ChatManager.Instance().getPCOnlineInfos();
        result.success(convertOnlineInfoList(list));
    }

    private void kickoffPCClient(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        String clientId = call.argument("clientId");
        ChatManager.Instance().kickoffPCClient(clientId, new GeneralVoidCallback(requestId));
    }

    private void isMuteNotificationWhenPcOnline(@NonNull MethodCall call, @NonNull Result result) {
        result.success(ChatManager.Instance().isMuteNotificationWhenPcOnline());
    }

    private void setDefaultSilentWhenPcOnline(@NonNull MethodCall call, @NonNull Result result) {
        boolean silent = call.argument("silent");
        ChatManager.Instance().setDefaultSilentWhenPcOnline(silent);
    }

    private void muteNotificationWhenPcOnline(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        boolean isMute = call.argument("isMute");

        ChatManager.Instance().muteNotificationWhenPcOnline(isMute, new GeneralVoidCallback(requestId));
    }

    private void getConversationFiles(@NonNull MethodCall call, @NonNull Result result) {
        final int requestId = call.argument("requestId");
        String userId = call.argument("userId");
        int order = call.argument("order");
        Conversation conversation = conversationFromArgument(call, false);
        long beforeMessageUid = getLongPara(call, "beforeMessageUid");
        int count = call.argument("count");

        ChatManager.Instance().getConversationFileRecords(conversation, userId, beforeMessageUid, FileRecordOrder.type(order), count, new GetFileRecordCallback() {
            @Override
            public void onSuccess(List<FileRecord> list) {
                callbackBuilder(requestId).put("files", convertFileRecordList(list)).success("onFilesResult");
            }

            @Override
            public void onFail(int i) {
                callbackBuilder(requestId).fail(i);
            }
        });
    }

    private void getMyFiles(@NonNull MethodCall call, @NonNull Result result) {
        final int requestId = call.argument("requestId");
        int order = call.argument("order");
        long beforeMessageUid = getLongPara(call, "beforeMessageUid");
        int count = call.argument("count");
        ChatManager.Instance().getMyFileRecords(beforeMessageUid, FileRecordOrder.type(order), count, new GetFileRecordCallback() {
            @Override
            public void onSuccess(List<FileRecord> list) {
                callbackBuilder(requestId).put("files", convertFileRecordList(list)).success("onFilesResult");
            }

            @Override
            public void onFail(int i) {
                callbackBuilder(requestId).fail(i);
            }
        });
    }

    private void deleteFileRecord(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        long messageUid = getLongPara(call, "messageUid");
        ChatManager.Instance().deleteFileRecord(messageUid, new GeneralVoidCallback(requestId));
    }

    private void searchFiles(@NonNull MethodCall call, @NonNull Result result) {
        final int requestId = call.argument("requestId");
        int order = call.argument("order");
        String keyword = call.argument("keyword");
        String userId = call.argument("userId");
        Conversation conversation = conversationFromArgument(call, false);
        long beforeMessageUid = getLongPara(call, "beforeMessageUid");
        int count = call.argument("count");

        ChatManager.Instance().searchFileRecords(keyword, conversation, userId, beforeMessageUid, FileRecordOrder.type(order), count, new GetFileRecordCallback() {
            @Override
            public void onSuccess(List<FileRecord> list) {
                callbackBuilder(requestId).put("files", convertFileRecordList(list)).success("onFilesResult");
            }

            @Override
            public void onFail(int i) {
                callbackBuilder(requestId).fail(i);
            }
        });
    }

    private void searchMyFiles(@NonNull MethodCall call, @NonNull Result result) {
        final int requestId = call.argument("requestId");
        String keyword = call.argument("keyword");
        long beforeMessageUid = getLongPara(call, "beforeMessageUid");
        int count = call.argument("count");
        int order = call.argument("order");

        ChatManager.Instance().searchMyFileRecords(keyword, beforeMessageUid, FileRecordOrder.type(order), count, new GetFileRecordCallback() {
            @Override
            public void onSuccess(List<FileRecord> list) {
                callbackBuilder(requestId).put("files", convertFileRecordList(list)).success("onFilesResult");
            }

            @Override
            public void onFail(int i) {
                callbackBuilder(requestId).fail(i);
            }
        });
    }

    private void getAuthorizedMediaUrl(@NonNull MethodCall call, @NonNull Result result) {
        final int requestId = call.argument("requestId");
        final String mediaPath = call.argument("mediaPath");
        long messageUid = getLongPara(call, "messageUid");
        int mediaType = call.argument("mediaType");

        ChatManager.Instance().getAuthorizedMediaUrl(messageUid, MessageContentMediaType.mediaType(mediaType), mediaPath, new GetAuthorizedMediaUrlCallback() {
            @Override
            public void onSuccess(String s, String s1) {
                callbackBuilder(requestId).put("string", s).put("string2", s1).success("onOperationStringSuccess");
            }

            @Override
            public void onFail(int i) {
                callbackBuilder(requestId).fail(i);
            }
        });
    }

    private void getAuthCode(@NonNull MethodCall call, @NonNull Result result) {
        final int requestId = call.argument("requestId");
        String applicationId = call.argument("applicationId");
        int type = call.argument("type");
        String host = call.argument("host");

        ChatManager.Instance().getAuthCode(applicationId, type, host, new GeneralStringCallback(requestId));
    }

    private void configApplication(@NonNull MethodCall call, @NonNull Result result) {
        final int requestId = call.argument("requestId");
        String applicationId = call.argument("applicationId");
        int type = call.argument("type");
        long timestamp = getLongPara(call, "timestamp");
        String signature = call.argument("signature");
        String nonce = call.argument("nonce");

        ChatManager.Instance().configApplication(applicationId, type, timestamp, nonce, signature, new GeneralVoidCallback(requestId));
    }

    private void getWavData(@NonNull MethodCall call, @NonNull Result result) {
        result.success(null);
    }

    private void beginTransaction(@NonNull MethodCall call, @NonNull Result result) {
        result.success(ChatManager.Instance().beginTransaction());
    }

    private void commitTransaction(@NonNull MethodCall call, @NonNull Result result) {
        result.success(ChatManager.Instance().commitTransaction());
    }

    private void rollbackTransaction(@NonNull MethodCall call, @NonNull Result result) {
        result.success(ChatManager.Instance().rollbackTransaction());
    }

    private void isCommercialServer(@NonNull MethodCall call, @NonNull Result result) {
        result.success(ChatManager.Instance().isCommercialServer());
    }

    private void isReceiptEnabled(@NonNull MethodCall call, @NonNull Result result) {
        result.success(ChatManager.Instance().isReceiptEnabled());
    }

    private void isGroupReceiptEnabled(@NonNull MethodCall call, @NonNull Result result) {
        result.success(ChatManager.Instance().isGroupReceiptEnabled());
    }

    private void isGlobalDisableSyncDraft(@NonNull MethodCall call, @NonNull Result result) {
        result.success(ChatManager.Instance().isGlobalDisableSyncDraft());
    }

    private void getUserOnlineState(@NonNull MethodCall call, @NonNull Result result) {
        String userId = call.argument("userId");
        UserOnlineState userOnlineState = ChatManager.Instance().getUserOnlineState(userId);
        result.success(convertUserOnlineState(userOnlineState));
    }

    private void getMyCustomState(@NonNull MethodCall call, @NonNull Result result) {
        Pair<Integer, String> pair = ChatManager.Instance().getMyCustomState();
        Map<String, Object> map = new HashMap<>();
        map.put("state", pair.first);
        map.put("text", pair.second);
        result.success(map);
    }

    private void setMyCustomState(@NonNull MethodCall call, @NonNull Result result) {
        final int requestId = call.argument("requestId");
        String customText = call.argument("customText");
        int customState = call.argument("customState");
        ChatManager.Instance().setMyCustomState(customState, customText, new GeneralVoidCallback(requestId));
    }

    private void watchOnlineState(@NonNull MethodCall call, @NonNull Result result) {
        final int requestId = call.argument("requestId");
        List<String> targets = call.argument("targets");
        int conversationType = call.argument("conversationType");
        int watchDuration = call.argument("watchDuration");
        ChatManager.Instance().watchOnlineState(conversationType, targets.toArray(new String[0]), watchDuration, new WatchOnlineStateCallback() {
            @Override
            public void onSuccess(UserOnlineState[] userOnlineStates) {
                List list = new ArrayList();
                for (UserOnlineState userOnlineState : userOnlineStates) {
                    list.add(convertUserOnlineState(userOnlineState));
                }
                callbackBuilder(requestId).put("states", list).success("onWatchOnlineStateSuccess");
            }

            @Override
            public void onFail(int i) {
                callbackBuilder(requestId).fail(i);
            }
        });
    }

    private void unwatchOnlineState(@NonNull MethodCall call, @NonNull Result result) {
        final int requestId = call.argument("requestId");
        List<String> targets = call.argument("targets");
        int conversationType = call.argument("conversationType");
        ChatManager.Instance().unWatchOnlineState(conversationType, targets.toArray(new String[0]), new GeneralVoidCallback(requestId));
    }

    private void isEnableUserOnlineState(@NonNull MethodCall call, @NonNull Result result) {
        result.success(ChatManager.Instance().isEnableUserOnlineState());
    }

    private void sendConferenceRequest(@NonNull MethodCall call, @NonNull Result result) {
        int requestId = call.argument("requestId");
        long sessionId = getLongPara(call, "sessionId");
        String roomId = call.argument("roomId");
        String request = call.argument("request");
        boolean advanced = call.argument("advanced") != null && (Boolean) call.argument("advanced");
        String data = call.argument("data");

        ChatManager.Instance().sendConferenceRequest(sessionId, roomId, request, advanced, data, new GeneralCallback2() {
            @Override
            public void onSuccess(String s) {
                callbackBuilder(requestId).put("result", s).success("onSendConferenceRequestSuccess");
            }

            @Override
            public void onFail(int i) {
                callbackBuilder(requestId).put("errorCode", i).success("onSendConferenceRequestFailure");
            }
        });
        result.success(null);
    }
    //- (void)isEnableUserOnlineState:(NSDictionary *)dict result:(FlutterResult)result {
//        WFCCUserCustomState *customState = [[WFCCIMService sharedWFCIMService] getMyCustomState];
//        result(@([[WFCCIMService sharedWFCIMService] isEnableUserOnlineState]));
//    }
    private static void callback2UI(@NonNull final String method, @Nullable final Object arguments) {
        handler.post(new Runnable() {
            @Override
            public void run() {
                if (channel != null) {
                    try {
                        channel.invokeMethod(method, arguments);
                    } catch (Exception e) {
                        Log.e(TAG, "Callback failure!!!");
                        e.printStackTrace();
                    }
                } else {
                    Log.e(TAG, "Unable callback to UI, because engine is deattached");
                }
            }
        });
    }

    private int[] convertIntegerList(List<Integer> ints) {
        if (ints == null || ints.size() == 0) {
            int[] arr = new int[1];
            arr[0] = 0;
            return arr;
        }

        int[] arr = new int[ints.size()];
        for (int i = 0; i < ints.size(); i++) {
            arr[i] = ints.get(i);
        }
        return arr;
    }

    private long getLongPara(MethodCall call, String key) {
        Object obj = call.argument(key);
        if (obj instanceof Long) {
            Long l = (Long) obj;
            return l;
        } else if (obj instanceof Integer) {
            int i = (Integer) obj;
            return i;
        } else if (obj instanceof Float) {
            float f = (Float) obj;
            return (long) f;
        } else if (obj instanceof Double) {
            double d = (Double) obj;
            return (long) d;
        } else {
            return Long.valueOf(call.argument(key).toString());
        }
    }

    private static List<Map<String, Object>> convertConversationInfos(ConversationInfo[] protoDatas) {
        List<Map<String, Object>> output = new ArrayList<>();
        if (protoDatas == null) {
            return output;
        }
        for (ConversationInfo protoData : protoDatas) {
            output.add(convertConversationInfo(protoData));
        }
        return output;
    }

    private static List<Map<String, Object>> convertConversationInfoList(List<ConversationInfo> protoDatas) {
        List<Map<String, Object>> output = new ArrayList<>();
        if (protoDatas == null) {
            return output;
        }
        for (ConversationInfo protoData : protoDatas) {
            output.add(convertConversationInfo(protoData));
        }
        return output;
    }

    private static Map<String, Object> convertConversationInfo(ConversationInfo protoData) {
        Map<String, Object> map = new HashMap<>();

        map.put("conversation", convertConversation(protoData.conversation));
        Map lastMsg = convertMessage(protoData.lastMessage);
        if (lastMsg != null)
            map.put("lastMessage", lastMsg);

        if (!TextUtils.isEmpty(protoData.draft))
            map.put("draft", protoData.draft);

        map.put("timestamp", protoData.timestamp);

        Map unread = convertUnreadCount(protoData.unreadCount);
        if (unread != null)
            map.put("unreadCount", unread);

        map.put("isTop", protoData.top);
        map.put("isSilent", protoData.isSilent);

        return map;
    }

    private static Map<String, Object> convertConversation(Conversation protoData) {
        Map<String, Object> conversation = new HashMap<>();
        conversation.put("type", protoData.type.getValue());
        conversation.put("target", protoData.target);
        conversation.put("line", protoData.line);
        return conversation;
    }

    private static Map<String, Object> convertUnreadCount(UnreadCount protoData) {
        if (protoData == null) {
            return null;
        }
        Map<String, Object> map = new HashMap<>();
        map.put("unread", protoData.unread);
        map.put("unreadMention", protoData.unreadMention);
        map.put("unreadMentionAll", protoData.unreadMentionAll);
        return map;
    }

    private static List<Map<String, Object>> convertUnreadCountList(List<UnreadCount> protoDatas) {
        if (protoDatas == null) {
            return null;
        }

        List<Map<String, Object>> maps = new ArrayList<>();
        for (UnreadCount protoData : protoDatas) {
            Map<String, Object> map = new HashMap<>();
            map.put("unread", protoData.unread);
            map.put("unreadMention", protoData.unreadMention);
            map.put("unreadMentionAll", protoData.unreadMentionAll);
            maps.add(map);
        }

        return maps;
    }

    private static Map<String, Object> convertMessage(Message protoData) {
        if (protoData == null) {
            return null;
        }
        Map<String, Object> map = new HashMap<>();

        map.put("sender", protoData.sender);
        map.put("conversation", convertConversation(protoData.conversation));
        map.put("messageId", protoData.messageId);
        if (protoData.messageUid > 0)
            map.put("messageUid", protoData.messageUid);
        if (protoData.serverTime > 0)
            map.put("serverTime", protoData.serverTime);

        if (protoData.toUsers != null && protoData.toUsers.length > 0) {
            map.put("toUsers", convertProtoStringArray(protoData.toUsers));
        }

        map.put("direction", protoData.direction.value());
        map.put("status", protoData.status.value());
        map.put("content", convertMessageContent(protoData.content.encode()));
        return map;
    }

    private static List<Map<String, Object>> convertMessages(Message[] protoDatas) {
        List output = new ArrayList();
        for (Message protoData : protoDatas) {
            output.add(convertMessage(protoData));
        }
        return output;
    }

    private static List<Map<String, Object>> convertMessageList(List<Message> protoDatas, boolean reverse) {
        ArrayList output = new ArrayList();
        for (Message protoData : protoDatas) {
            if (reverse)
                output.add(0, convertMessage(protoData));
            else
                output.add(convertMessage(protoData));
        }
        return output;
    }

    private static List<String> convertProtoStringArray(String[] arr) {
        List output = new ArrayList();
        for (String a : arr) {
            output.add(a);
        }
        return output;
    }

    private static Map<String, Object> convertMessageContent(MessagePayload protoData) {
        Map<String, Object> map = new HashMap<>();
        map.put("type", protoData.type);

        if (!TextUtils.isEmpty(protoData.searchableContent))
            map.put("searchableContent", protoData.searchableContent);
        if (!TextUtils.isEmpty(protoData.pushContent))
            map.put("pushContent", protoData.pushContent);
        if (!TextUtils.isEmpty(protoData.pushData))
            map.put("pushData", protoData.pushData);
        if (!TextUtils.isEmpty(protoData.content))
            map.put("content", protoData.content);
        if (protoData.binaryContent != null && protoData.binaryContent.length > 0)
            map.put("binaryContent", Base64.encodeToString(protoData.binaryContent, Base64.NO_WRAP));
        if (!TextUtils.isEmpty(protoData.localContent))
            map.put("localContent", protoData.localContent);
        if (protoData.mediaType != null)
            map.put("mediaType", protoData.mediaType.getValue());
        if (!TextUtils.isEmpty(protoData.remoteMediaUrl))
            map.put("remoteMediaUrl", protoData.remoteMediaUrl);
        if (!TextUtils.isEmpty(protoData.localMediaPath))
            map.put("localMediaPath", protoData.localMediaPath);
        if (protoData.mentionedType > 0)
            map.put("mentionedType", protoData.mentionedType);
        if (protoData.mentionedTargets != null && protoData.mentionedTargets.size() > 0)
            map.put("mentionedTargets", protoData.mentionedTargets);
        if (!TextUtils.isEmpty(protoData.extra))
            map.put("extra", protoData.extra);

        return map;
    }

    private static Map<String, Object> convertReadEntry(ReadEntry protoData) {
        Map<String, Object> map = new HashMap<>();

        map.put("conversation", convertConversation(protoData.conversation));
        map.put("userId", protoData.userId);
        map.put("timestamp", protoData.readDt);
        return map;
    }

    private static List<Map<String, Object>> convertReadEntryList(List<ReadEntry> protoDatas) {
        List output = new ArrayList();
        for (ReadEntry protoData : protoDatas) {
            output.add(convertReadEntry(protoData));
        }
        return output;
    }

    private Map<String, Object> convertFriend(Friend protoData) {
        if (protoData == null) return null;
        Map<String, Object> map = new HashMap<>();
        map.put("userId", protoData.userId);
        map.put("alias", protoData.alias);
        map.put("extra", protoData.extra);
        map.put("timestamp", protoData.timestamp);
        return map;
    }

    private List<Map<String, Object>> convertFriendList(List<Friend> protoDatas) {
        List output = new ArrayList();
        for (Friend protoData : protoDatas) {
            output.add(convertFriend(protoData));
        }
        return output;
    }

    private static Map<String, Object> convertUserInfo(UserInfo protoData) {
        if (protoData == null) return null;

        Map<String, Object> map = new HashMap<>();
        map.put("uid", protoData.uid);
        map.put("name", protoData.name);
        if (!TextUtils.isEmpty(protoData.portrait))
            map.put("portrait", protoData.portrait);
        if (protoData.deleted > 0) {
            map.put("deleted", protoData.deleted);
            map.put("displayName", "已删除用户");
        } else {
            if (!TextUtils.isEmpty(protoData.displayName))
                map.put("displayName", protoData.displayName);
            map.put("gender", protoData.gender);
            //Todo convert more data


            if (!TextUtils.isEmpty(protoData.friendAlias))
                map.put("friendAlias", protoData.friendAlias);
            if (!TextUtils.isEmpty(protoData.groupAlias))
                map.put("groupAlias", protoData.groupAlias);
            if (!TextUtils.isEmpty(protoData.mobile))
                map.put("mobile", protoData.mobile);
            if (!TextUtils.isEmpty(protoData.email))
                map.put("email", protoData.email);
            if (!TextUtils.isEmpty(protoData.address))
                map.put("address", protoData.address);
            if (!TextUtils.isEmpty(protoData.company))
                map.put("company", protoData.company);
            if (!TextUtils.isEmpty(protoData.social))
                map.put("social", protoData.social);
            if (!TextUtils.isEmpty(protoData.extra))
                map.put("extra", protoData.extra);
            if (protoData.updateDt > 0)
                map.put("updateDt", protoData.updateDt);
            if (protoData.type > 0)
                map.put("type", protoData.type);
        }
        return map;
    }

    private static List<Map<String, Object>> convertUserInfoList(List<UserInfo> protoDatas) {
        List output = new ArrayList();
        if (protoDatas != null) {
            for (UserInfo protoData : protoDatas) {
                output.add(convertUserInfo(protoData));
            }
        }
        return output;
    }

    private List<Map<String, Object>> convertUserInfos(UserInfo[] protoDatas) {
        List output = new ArrayList();
        for (UserInfo protoData : protoDatas) {
            output.add(convertUserInfo(protoData));
        }
        return output;
    }

    private static Map<String, Object> convertGroupInfo(GroupInfo protoData) {
        if (protoData == null) return null;

        Map<String, Object> map = new HashMap<>();
        map.put("type", protoData.type.value());
        map.put("target", protoData.target);
        if (!TextUtils.isEmpty(protoData.name))
            map.put("name", protoData.name);
        if (!TextUtils.isEmpty(protoData.extra))
            map.put("extra", protoData.extra);
        if (!TextUtils.isEmpty(protoData.portrait))
            map.put("portrait", protoData.portrait);
        if (!TextUtils.isEmpty(protoData.owner))
            map.put("owner", protoData.owner);
        if (!TextUtils.isEmpty(protoData.remark))
            map.put("remark", protoData.remark);
        map.put("memberCount", protoData.memberCount);
        map.put("mute", protoData.mute);
        map.put("joinType", protoData.joinType);
        map.put("privateChat", protoData.privateChat);
        map.put("searchable", protoData.searchable);
        map.put("historyMessage", protoData.historyMessage);
        map.put("memberDt", protoData.memberDt);
        map.put("updateDt", protoData.updateDt);
        map.put("maxMemberCount", protoData.maxMemberCount);
        map.put("superGroup", protoData.superGroup);
        map.put("deleted", protoData.deleted);
        return map;
    }

    private static List<Map<String, Object>> convertGroupInfoList(List<GroupInfo> protoDatas) {
        List output = new ArrayList();
        for (GroupInfo protoData : protoDatas) {
            output.add(convertGroupInfo(protoData));
        }
        return output;
    }

    private List<Map<String, Object>> convertGroupInfos(GroupInfo[] protoDatas) {
        List output = new ArrayList();
        for (GroupInfo protoData : protoDatas) {
            output.add(convertGroupInfo(protoData));
        }
        return output;
    }

    private static Map<String, Object> convertGroupMember(GroupMember protoData) {
        Map<String, Object> map = new HashMap<>();
        map.put("groupId", protoData.groupId);
        map.put("memberId", protoData.memberId);
        if (!TextUtils.isEmpty(protoData.alias))
            map.put("alias", protoData.alias);
        if (!TextUtils.isEmpty(protoData.extra))
            map.put("extra", protoData.extra);
        map.put("type", protoData.type.value());
        if (protoData.createDt > 0)
            map.put("createDt", protoData.createDt);
        if (protoData.updateDt > 0)
            map.put("updateDt", protoData.updateDt);
        return map;
    }

    private static List<Map<String, Object>> convertGroupMemberList(List<GroupMember> protoDatas) {
        List output = new ArrayList();
        for (GroupMember protoData : protoDatas) {
            output.add(convertGroupMember(protoData));
        }
        return output;
    }

    private List<Map<String, Object>> convertGroupMembers(GroupMember[] protoDatas) {
        List output = new ArrayList();
        for (GroupMember protoData : protoDatas) {
            output.add(convertGroupMember(protoData));
        }
        return output;
    }

    private Map<String, Object> convertGroupSearchResult(GroupSearchResult protoData) {
        Map<String, Object> map = new HashMap<>();
        map.put("groupInfo", convertGroupInfo(protoData.groupInfo));
        map.put("marchType", protoData.marchedType);
        if (protoData.marchedMembers != null && protoData.marchedMembers.size() > 0) {
            map.put("marchedMemberNames", protoData.marchedMembers);
        }
        return map;
    }

    private List<Map<String, Object>> convertGroupSearchResults(GroupSearchResult[] protoDatas) {
        List output = new ArrayList();
        for (GroupSearchResult protoData : protoDatas) {
            output.add(convertGroupSearchResult(protoData));
        }
        return output;
    }

    private List<Map<String, Object>> convertGroupSearchResultList(List<GroupSearchResult> protoDatas) {
        List output = new ArrayList();
        for (GroupSearchResult protoData : protoDatas) {
            output.add(convertGroupSearchResult(protoData));
        }
        return output;
    }

    private static Map<String, Object> convertChannelMenu(ChannelMenu menu) {
        Map<String, Object> map = new HashMap<>();
        map.put("menuId", menu.menuId);
        map.put("type", menu.type);
        map.put("name", menu.name);
        map.put("key", menu.key);
        map.put("url", menu.url);
        map.put("mediaId", menu.mediaId);
        map.put("articleId", menu.articleId);
        map.put("appId", menu.appId);
        map.put("appPage", menu.appPage);
        map.put("extra", menu.extra);
        if (menu.subMenus != null) {
            List<Map<String, Object>> subMenus = new ArrayList<>();
            for (ChannelMenu subMenu : menu.subMenus) {
                subMenus.add(convertChannelMenu(subMenu));
            }
            map.put("subMenus", subMenus);
        }
        return map;
    }

    private static Map<String, Object> convertChannelInfo(ChannelInfo protoData) {
        Map<String, Object> map = new HashMap<>();
        map.put("channelId", protoData.channelId);
        if (!TextUtils.isEmpty(protoData.desc))
            map.put("desc", protoData.desc);
        if (!TextUtils.isEmpty(protoData.name))
            map.put("name", protoData.name);
        if (!TextUtils.isEmpty(protoData.extra))
            map.put("extra", protoData.extra);
        if (!TextUtils.isEmpty(protoData.portrait))
            map.put("portrait", protoData.portrait);
        if (!TextUtils.isEmpty(protoData.owner))
            map.put("owner", protoData.owner);
        if (protoData.status > 0)
            map.put("status", protoData.status);
        if (protoData.updateDt > 0)
            map.put("updateDt", protoData.updateDt);

        if (protoData.menus != null) {
            List<Map<String, Object>> menus = new ArrayList<>();
            for (ChannelMenu menu : protoData.menus) {
                menus.add(convertChannelMenu(menu));
            }
            map.put("menus", menus);
        }
        return map;
    }

    private static List<Map<String, Object>> convertChannelInfoList(List<ChannelInfo> protoDatas) {
        List output = new ArrayList();
        for (ChannelInfo protoData : protoDatas) {
            output.add(convertChannelInfo(protoData));
        }
        return output;
    }

    private List<Map<String, Object>> convertProtoChannelInfos(ChannelInfo[] protoDatas) {
        List output = new ArrayList();
        for (ChannelInfo protoData : protoDatas) {
            output.add(convertChannelInfo(protoData));
        }
        return output;
    }

    private Map<String, Object> convertConversationSearchInfo(ConversationSearchResult protoData) {
        Map<String, Object> map = new HashMap<>();

        map.put("conversation", convertConversation(protoData.conversation));

        Map lastMsg = convertMessage(protoData.marchedMessage);
        if (lastMsg != null)
            map.put("marchedMessage", lastMsg);

        map.put("marchedCount", protoData.marchedCount);
        map.put("timestamp", protoData.timestamp);

        return map;
    }

    private List<Map<String, Object>> convertConversationSearchInfos(ConversationSearchResult[] protoDatas) {
        List output = new ArrayList();
        for (ConversationSearchResult protoData : protoDatas) {
            output.add(convertConversationSearchInfo(protoData));
        }
        return output;
    }

    private List<Map<String, Object>> convertConversationSearchInfoList(List<ConversationSearchResult> protoDatas) {
        List output = new ArrayList();
        for (ConversationSearchResult protoData : protoDatas) {
            output.add(convertConversationSearchInfo(protoData));
        }
        return output;
    }

    private Map<String, Object> convertFriendRequest(FriendRequest protoData) {
        Map<String, Object> map = new HashMap<>();
        map.put("direction", protoData.direction);
        map.put("target", protoData.target);
        if (!TextUtils.isEmpty(protoData.reason))
            map.put("reason", protoData.reason);
        map.put("status", protoData.status);
        map.put("readStatus", protoData.readStatus);
        map.put("timestamp", protoData.timestamp);
        return map;
    }

    private List<Map<String, Object>> convertProtoFriendRequests(FriendRequest[] protoDatas) {
        List output = new ArrayList();
        for (FriendRequest protoData : protoDatas) {
            output.add(convertFriendRequest(protoData));
        }
        return output;
    }

    private List<Map<String, Object>> convertProtoFriendRequestList(List<FriendRequest> protoDatas) {
        List output = new ArrayList();
        for (FriendRequest protoData : protoDatas) {
            output.add(convertFriendRequest(protoData));
        }
        return output;
    }

    private Map<String, Object> convertFileRecord(FileRecord protoData) {
        Map<String, Object> map = new HashMap<>();

        map.put("conversation", convertConversation(protoData.conversation));
        map.put("messageUid", protoData.messageUid);
        map.put("userId", protoData.userId);
        map.put("name", protoData.name);
        map.put("url", protoData.url);
        map.put("size", protoData.size);
        map.put("downloadCount", protoData.downloadCount);
        map.put("timestamp", protoData.timestamp);
        return map;
    }

    private List<Map<String, Object>> convertFileRecords(FileRecord[] protoDatas) {
        List output = new ArrayList();
        for (FileRecord protoData : protoDatas) {
            output.add(convertFileRecord(protoData));
        }
        return output;
    }

    private List<Map<String, Object>> convertFileRecordList(List<FileRecord> protoDatas) {
        List output = new ArrayList();
        for (FileRecord protoData : protoDatas) {
            output.add(convertFileRecord(protoData));
        }
        return output;
    }

    private Map<String, Object> convertChatroomInfo(ChatRoomInfo protoData) {
        Map<String, Object> map = new HashMap<>();
        map.put("chatroomId", protoData.chatRoomId);
        map.put("title", protoData.title);
        map.put("desc", protoData.desc);
        map.put("portrait", protoData.portrait);
        map.put("extra", protoData.extra);
        map.put("state", protoData.state.getValue());
        map.put("memberCount", protoData.memberCount);
        map.put("createDt", protoData.createDt);
        map.put("updateDt", protoData.updateDt);
        return map;
    }

    private Map<String, Object> convertChatroomMemberInfo(ChatRoomMembersInfo protoData) {
        Map<String, Object> map = new HashMap<>();
        map.put("memberCount", protoData.memberCount);
        if (protoData.members != null)
            map.put("members", protoData.members);
        return map;
    }

    private Map<String, Object> pcOnlineInfo(PCOnlineInfo onlineInfo) {
        Map map = new HashMap();
        map.put("type", onlineInfo.getType().ordinal());
        map.put("isOnline", onlineInfo.isOnline());
        if (onlineInfo.isOnline()) {
            map.put("timestamp", onlineInfo.getTimestamp());
            map.put("platform", onlineInfo.getPlatform().ordinal());
            map.put("clientId", onlineInfo.getClientId());
            map.put("clientName", onlineInfo.getClientName());
        }
        return map;
    }

    private List<Map<String, Object>> convertOnlineInfoList(List<PCOnlineInfo> onlineInfoList) {
        List out = new ArrayList();
        for (PCOnlineInfo pcOnlineInfo : onlineInfoList) {
            out.add(pcOnlineInfo(pcOnlineInfo));
        }
        return out;
    }

    private String[] convertStringList(List<String> list) {
        if (list == null || list.isEmpty())
            return null;

        String[] arr = new String[list.size()];
        for (int i = 0; i < list.size(); i++) {
            arr[i] = list.get(i);
        }
        return arr;
    }

    private MessagePayload convertMessageContent(Map<String, Object> map) {
        MessagePayload protoData = new MessagePayload();
        if (map == null || map.isEmpty() || !map.containsKey("type")) {
            return null;
        }

        protoData.type = ((int) map.get("type"));
        protoData.searchableContent = ((String) map.get("searchableContent"));
        protoData.pushContent = ((String) map.get("pushContent"));
        protoData.pushData = ((String) map.get("pushData"));
        protoData.content = ((String) map.get("content"));
        protoData.binaryContent = ((byte[]) map.get("binaryContent"));
        protoData.localContent = ((String) map.get("localContent"));
        protoData.mediaType = MessageContentMediaType.mediaType((int) map.get("mediaType"));
        protoData.remoteMediaUrl = ((String) map.get("remoteMediaUrl"));
        protoData.localMediaPath = ((String) map.get("localMediaPath"));
        protoData.mentionedType = ((int) map.get("mentionedType"));
        if (map.get("mentionedTargets") != null) {
            List<String> ts = (List<String>) map.get("mentionedTargets");
            if (!ts.isEmpty()) {
                protoData.mentionedTargets = new ArrayList<>();
                for (int i = 0; i < ts.size(); i++) {
                    protoData.mentionedTargets.add(ts.get(i));
                }
            }
        }
        protoData.extra = ((String) map.get("extra"));

        return protoData;
    }

    private void callbackFailure(int requestId, int errorCode) {
        Map args = new HashMap();
        args.put("requestId", requestId);
        args.put("errorCode", errorCode);
        callback2UI("onOperationFailure", args);
    }

    private class GeneralVoidCallback implements GeneralCallback {
        private int requestId;

        public GeneralVoidCallback(int requestId) {
            this.requestId = requestId;
        }

        @Override
        public void onSuccess() {
            callbackBuilder(requestId).success("onOperationVoidSuccess");
        }

        @Override
        public void onFail(int i) {
            callbackBuilder(requestId).fail(i);
        }
    }

    private class GeneralStringCallback implements GeneralCallback2 {
        private int requestId;

        public GeneralStringCallback(int requestId) {
            this.requestId = requestId;
        }

        @Override
        public void onSuccess(String string) {
            callbackBuilder(requestId).put("string", string).success("onOperationStringSuccess");
        }

        @Override
        public void onFail(int i) {
            callbackFailure(requestId, i);
        }
    }

    private static Map<String, Object> convertUserOnlineState(UserOnlineState userOnlineState) {
        Map<String, Object> state = new HashMap<>();
        if (userOnlineState == null) {
            return null;
        }
        state.put("userId", userOnlineState.getUserId());
        Map<String, Object> customState = new HashMap<>();
        state.put("customState", customState);
        customState.put("state", userOnlineState.getCustomState());
        if (!TextUtils.isEmpty(userOnlineState.getCustomText())) {
            customState.put("text", userOnlineState.getCustomText());
        }
        if (userOnlineState.getClientStates() != null && userOnlineState.getClientStates().length > 0) {
            List clientStates = new ArrayList();
            state.put("clientStates", clientStates);
            for (ClientState clientState : userOnlineState.getClientStates()) {
                Map<String, Object> cs = new HashMap<>();
                cs.put("state", clientState.getState());
                cs.put("platform", clientState.getPlatform());
                cs.put("lastSeen", clientState.getLastSeen());
                clientStates.add(cs);
            }
        }
        return state;
    }

    private static List convertUserOnlineMap(Map<String, UserOnlineState> map) {
        List array = new ArrayList();
        for (Map.Entry<String, UserOnlineState> entry : map.entrySet()) {
            Map<String, Object> state = convertUserOnlineState(entry.getValue());
            array.add(state);
        }
        return array;
    }

    static class WildfireListenerHandler implements InvocationHandler {
        private static final String TAG = "WildfireListenerHandler";

        /**
         * @param proxy  所代理的那个真实对象
         * @param method 我们所要调用真实对象的某个方法的Method对象
         * @param args   调用真实对象某个方法时接受的参数
         * @return 代理执行完方法所返回的对象
         * @throws Throwable 执行过程抛出的各种异常
         */
        @RequiresApi(Build.VERSION_CODES.O)
        @Override
        public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
            try {
                if (channel == null) {
                    return null;
                }

                String methodName = method.getName();
                int status = ChatManager.Instance().getConnectionStatus();
                // 回调 js 层时，好像有大小限制，先规避一下
                if ("onReceiveMessage".equals(methodName) && status == ConnectionStatus.ConnectionStatusReceiveing) {
                    List list = (List) args[0];
                    if (list.size() > 100) {
                        return null;
                    }
                }
                String jsonStr = null;
                if (args != null || "onSettingUpdate".equals(methodName)) {
                    switch (methodName) {
                        case "onChannelInfoUpdate": {
                            List<ChannelInfo> channelInfos = (List<ChannelInfo>) args[0];
                            Map data = new HashMap();
                            data.put("channels", convertChannelInfoList(channelInfos));
                            callback2UI("onChannelInfoUpdated", data);
                            break;
                        }
//                        @Override
//                        public void onChannelInfoUpdated(List<ProtoChannelInfo> list) {
//                            Map args = new HashMap();
//                            args.put("channels", convertProtoChannelInfoList(list));
//                            callback2UI("onChannelInfoUpdated", args);
//                        }

                        case "onUserOnlineEvent": {
                            List events = convertUserOnlineMap((Map<String, UserOnlineState>) args[0]);
                            Map data = new HashMap();
                            data.put("states", events);
                            callback2UI("onUserOnlineEvent", data);
                            break;
                        }

                        case "onConferenceEvent": {
                            String confEvent = (String) args[0];
                            Map data = new HashMap();
                            data.put("event", confEvent);
                            callback2UI("onConferenceEvent", data);
                            break;
                        }
//                        @Override
//                        public void onConferenceEvent(String s) {
//
//                        }
//
                        case "onConnectionStatusChange": {
                            int newStatus = (int) args[0];
                            callback2UI("onConnectionStatusChanged", status);
                            break;
                        }
//                        @Override
//                        public void onConnectionStatusChanged(int i) {
//                            updateConnectionStatus(i);
//                        }
//
                        case "onFriendListUpdate": {
                            List<String> strings = (List<String>) args[0];
                            Map data = new HashMap();
                            data.put("friends", strings);
                            callback2UI("onFriendListUpdated", data);
                            break;
                        }
//                        @Override
//                        public void onFriendListUpdated(String[] strings) {
//                            Map args = new HashMap();
//                            args.put("friends", convertProtoStringArray(strings));
//                            callback2UI("onFriendListUpdated", args);
//                        }
//
                        case "onFriendRequestUpdate": {
                            List<String> strings = (List<String>) args[0];
                            Map data = new HashMap();
                            data.put("requests", strings);
                            callback2UI("onFriendRequestUpdated", data);
                            break;
                        }
//                        @Override
//                        public void onFriendRequestUpdated(String[] strings) {
//                            Map args = new HashMap();
//                            args.put("requests", convertProtoStringArray(strings));
//                            callback2UI("onFriendRequestUpdated", args);
//                        }
//
                        case "onGroupInfoUpdate": {
                            List<GroupInfo> groupInfos = (List<GroupInfo>) args[0];
                            Map data = new HashMap();
                            data.put("groups", convertGroupInfoList(groupInfos));
                            callback2UI("onGroupInfoUpdated", data);
                            break;
                        }
//                        @Override
//                        public void onGroupInfoUpdated(List<ProtoGroupInfo> list) {
//                            Map args = new HashMap();
//                            args.put("groups", convertProtoGroupInfoList(list));
//                            callback2UI("onGroupInfoUpdated", args);
//                        }
//
                        case "onGroupMembersUpdate": {
                            String s = (String) args[0];
                            List<GroupMember> list = (List<GroupMember>) args[1];
                            Map data = new HashMap();
                            data.put("groupId", s);
                            data.put("members", convertGroupMemberList(list));
                            callback2UI("onGroupMemberUpdated", data);
                            break;
                        }
//                        @Override
//                        public void onGroupMembersUpdated(String s, List<ProtoGroupMember> list) {
//                            Map args = new HashMap();
//                            args.put("groupId", s);
//                            args.put("members", convertProtoGroupMemberList(list));
//                            callback2UI("onGroupMemberUpdated", args);
//                        }
//
                        case "onReceiveMessage": {
                            List<Message> list = (List<Message>) args[0];
                            List<Map<String, Object>> msgs = convertMessageList(list, true);
                            boolean b = (boolean) args[1];
                            int batchSize = 500;
                            while (!msgs.isEmpty()) {
                                Map<String, Object> data = new HashMap<>();
                                data.put("messages", msgs.subList(0, Math.min(batchSize, msgs.size())));
                                if (msgs.size() <= batchSize) {
                                    data.put("hasMore", b);
                                    msgs = new ArrayList<>();
                                } else {
                                    msgs = msgs.subList(batchSize, msgs.size());
                                    data.put("hasMore", true);
                                }
                                callback2UI("onReceiveMessage", data);
                            }
                            break;
                        }
//                        @Override
//                        public void onReceiveMessage(List<ProtoMessage> list, boolean b) {
//                            Map<String, Object> args = new HashMap<>();
//                            args.put("messages", convertProtoMessageList(list));
//                            args.put("hasMore", b);
//                            callback2UI("onReceiveMessage", args);
//                        }
//
                        case "onRecallMessage": {
                            Message message = (Message) args[0];
                            Map<String, Object> data = new HashMap<>();
                            data.put("messageUid", message.messageUid);
                            callback2UI("onRecallMessage", data);
                            break;
                        }
//                        @Override
//                        public void onRecallMessage(long l) {
//                            Map<String, Object> args = new HashMap<>();
//                            args.put("messageUid", l);
//                            callback2UI("onRecallMessage", args);
//                        }
//
                        case "onDeleteMessage": {
                            Message message = (Message) args[0];
                            Map<String, Object> data = new HashMap<>();
                            data.put("messageUid", message.messageUid);
                            callback2UI("onDeleteMessage", data);
                            break;
                        }
//                        @Override
//                        public void onDeleteMessage(long l) {
//                            Map<String, Object> args = new HashMap<>();
//                            args.put("messageUid", l);
//                            callback2UI("onDeleteMessage", args);
//                        }
                        case "onMessageDelivered": {
                            Map<String, Long> map = (Map<String, Long>) args[0];
                            callback2UI("onMessageDelivered", map);
                            break;
                        }
//                        @Override
//                        public void onUserReceivedMessage(Map<String, Long> map) {
//                            callback2UI("onMessageDelivered", map);
//                        }
//
                        case "onMessageRead": {
                            List<ReadEntry> list = (List<ReadEntry>) args[0];
                            Map<String, Object> data = new HashMap<>();
                            data.put("readeds", convertReadEntryList(list));
                            callback2UI("onMessageReaded", data);
                            break;
                        }
//                        @Override
//                        public void onUserReadedMessage(List<ProtoReadEntry> list) {
//                            Map<String, Object> args = new HashMap<>();
//                            args.put("readeds", convertProtoReadEntryList(list));
//                            callback2UI("onMessageReaded", args);
//                        }
//
                        case "onSettingUpdate": {
                            callback2UI("onSettingUpdated", null);
                            break;
                        }
//                        @Override
//                        public void onSettingUpdated() {
//                            callback2UI("onSettingUpdated", null);
//                        }
//
                        case "onUserInfoUpdate": {
                            List<UserInfo> list = (List<UserInfo>) args[0];
                            Map<String, Object> data = new HashMap<>();
                            data.put("users", convertUserInfoList(list));
                            callback2UI("onUserInfoUpdated", data);
                            break;
                        }
//                        @Override
//                        public void onUserInfoUpdated(List<ProtoUserInfo> list) {
//                            Map<String, Object> args = new HashMap<>();
//                            args.put("users", convertProtoUserInfoList(list));
//                            callback2UI("onUserInfoUpdated", args);
//                        }
                        case "onTrafficData":
                            //ignore traffic statistics
                            break;

                        case "onMessageUpdate": {
                            Message message = (Message) args[0];
                            Map<String, Object> data = new HashMap<>();
                            data.put("messageId", message.messageId);
                            callback2UI("onMessageUpdated", data);
                        }
                        break;
                        case "onSendPrepare": {
                            Message message = (Message) args[0];
                            if(message.content instanceof CallStartMessageContent || message.content instanceof AddParticipantsMessageContent) {
                                Map<String, Object> data = new HashMap<>();
                                data.put("requestId", 0);
                                data.put("messageId", message.messageId);
                                data.put("message", convertMessage(message));
                                callback2UI("onSendMessageStart", data);
                            }
                        }
                        break;
                        case "onConversationTopUpdate":
                        case "onConversationSilentUpdate":
                        case "onClearMessage":
                        case "onProgress":
                        case "onMediaUpload":
                        case "onSendSuccess":
                            //ignore these event
                            break;
                        default: {
                            Log.e(TAG, "not handled event " + methodName);
                            break;
                        }

                    }
                }
            } catch (Exception e) {
                Log.e(TAG, "call js error:" + method.getName());
                e.printStackTrace();
            }
            return null;
        }
    }

}
