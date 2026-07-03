- (void)handleBatchdeletemessages:(NSDictionary *)args result:(FlutterResult)result {
    int64_t messageUids = GetInt(args, @"messageUids", 0);
    int64_t messageUids_len = GetInt(args, @"messageUids_len", 0);
    bool ret = WFClient::batchDeleteMessages(messageUids, messageUids_len);
    result(@(ret));
}

- (void)handleClearremoteconversationmessage:(NSDictionary *)args result:(FlutterResult)result {
    int conversationType = static_cast<int>(GetInt(args, @"conversationType", 0));
    std::string ctarget = GetString(args, @"ctarget");
    int line = static_cast<int>(GetInt(args, @"line", 0));
    int objectDataType = static_cast<int>(GetInt(args, @"objectDataType", 0));
    WFClient::clearRemoteConversationMessage(conversationType, ctarget.c_str(), ctarget.size(), line, objectDataType);
    result(nil);
}

- (void)handleDeleteremotemessage:(NSDictionary *)args result:(FlutterResult)result {
    int64_t messageUid = GetInt(args, @"messageUid", 0);
    int64_t request_id = GetInt(args, @"requestId", 0);
    int objectDataType = static_cast<int>(GetInt(args, @"objectDataType", 0));
    WFClient::deleteRemoteMessage(messageUid, OnGeneralVoidSuccess, OnGeneralError, reinterpret_cast<void*>(request_id), 0, objectDataType);
}

- (void)handleGetremotemessage:(NSDictionary *)args result:(FlutterResult)result {
    int64_t messageUid = GetInt(args, @"messageUid", 0);
    int64_t request_id = GetInt(args, @"requestId", 0);
    int objectDataType = static_cast<int>(GetInt(args, @"objectDataType", 0));
    WFClient::getRemoteMessage(messageUid, OnGeneralVoidSuccess, OnGeneralError, reinterpret_cast<void*>(request_id), 0, objectDataType);
}

- (void)handleGetmessagecount:(NSDictionary *)args result:(FlutterResult)result {
    int conversationType = static_cast<int>(GetInt(args, @"conversationType", 0));
    std::string ctarget = GetString(args, @"ctarget");
    int line = static_cast<int>(GetInt(args, @"line", 0));
    int64_t ret = WFClient::getMessageCount(conversationType, ctarget.c_str(), ctarget.size(), line);
    result(@(ret));
}