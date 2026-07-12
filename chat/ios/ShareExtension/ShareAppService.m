//
//  ShareAppService.m
//  ShareExtension
//

#import "ShareAppService.h"
#import "ShareUtility.h"

static NSString * const kShareAppGroupId = @"group.cn.wildfirechat.messangerEx";
static NSString * const kSharedAuthTokenKey = @"wfc_share_appservice_auth_token";
static NSString * const kSharedAppServerAddressKey = @"wfc_share_appserver_address";
static NSString * const kAuthorizationHeader = @"authToken";

@interface ShareUploadTaskInfo : NSObject
@property (nonatomic, copy) void(^progressBlock)(int sentcount, int total);
@property (nonatomic, copy) void(^successBlock)(NSString *url);
@property (nonatomic, copy) void(^errorBlock)(NSString *message);
@property (nonatomic, strong) NSMutableData *responseData;
@end

@implementation ShareUploadTaskInfo
@end

@interface ShareAppService () <NSURLSessionTaskDelegate, NSURLSessionDataDelegate>
@property (nonatomic, copy) NSString *authToken;
@property (nonatomic, copy) NSString *appServerAddress;
@property (nonatomic, strong) NSURLSession *uploadSession;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, ShareUploadTaskInfo *> *uploadTaskInfos;
@property (nonatomic, assign) NSInteger uploadTaskIdentifier;
@end

@implementation ShareAppService

+ (instancetype)sharedService {
    static ShareAppService *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ShareAppService alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self loadSharedData];
        self.uploadTaskInfos = [NSMutableDictionary dictionary];
        self.uploadTaskIdentifier = 0;
    }
    return self;
}

- (void)loadSharedData {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kShareAppGroupId];
    self.authToken = [defaults objectForKey:kSharedAuthTokenKey];
    self.appServerAddress = [defaults objectForKey:kSharedAppServerAddressKey];
}

- (BOOL)isLogin {
    [self loadSharedData];
    return self.authToken.length > 0;
}

- (NSString *)baseUrl {
    return self.appServerAddress.length ? self.appServerAddress : @"";
}

- (NSURLSession *)uploadSession {
    if (!_uploadSession) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        _uploadSession = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    }
    return _uploadSession;
}

- (void)sendTextMessage:(SharedConversation *)conversation
                   text:(NSString *)text
                success:(void(^)(NSDictionary *dict))successBlock
                  error:(void(^)(NSString *message))errorBlock {
    [self post:@"/messages/send"
          data:@{
              @"type": @(conversation.type),
              @"target": conversation.target,
              @"line": @(conversation.line),
              @"content_type": @(1),
              @"content_searchable": text ?: @""
          }
       success:successBlock
         error:errorBlock];
}

- (void)sendLinkMessage:(SharedConversation *)conversation
                   link:(NSString *)link
                  title:(NSString *)title
           thumbnailLink:(NSString *)thumbnailLink
                success:(void(^)(NSDictionary *dict))successBlock
                  error:(void(^)(NSString *message))errorBlock {
    NSDictionary *linkDict = @{
        @"u": link ?: @"",
        @"t": thumbnailLink ?: @""
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:linkDict options:kNilOptions error:nil];
    NSString *base64 = [data base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
    
    [self post:@"/messages/send"
          data:@{
              @"type": @(conversation.type),
              @"target": conversation.target,
              @"line": @(conversation.line),
              @"content_type": @(8),
              @"content_searchable": title.length ? title : link,
              @"content_binary": base64 ?: @""
          }
       success:successBlock
         error:errorBlock];
}

- (void)sendImageMessage:(SharedConversation *)conversation
                mediaUrl:(NSString *)mediaUrl
               thumbnail:(UIImage *)thumbnail
                 success:(void(^)(NSDictionary *dict))successBlock
                   error:(void(^)(NSString *message))errorBlock {
    NSData *thumbData = UIImageJPEGRepresentation(thumbnail, 0.4);
    NSString *base64 = [thumbData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
    
    [self post:@"/messages/send"
          data:@{
              @"type": @(conversation.type),
              @"target": conversation.target,
              @"line": @(conversation.line),
              @"content_type": @(3),
              @"content_media_type": @(1),
              @"content_remote_url": mediaUrl ?: @"",
              @"content_searchable": @"图片",
              @"content_binary": base64 ?: @""
          }
       success:successBlock
         error:errorBlock];
}

- (void)sendFileMessage:(SharedConversation *)conversation
               mediaUrl:(NSString *)mediaUrl
               fileName:(NSString *)fileName
                   size:(long long)size
                success:(void(^)(NSDictionary *dict))successBlock
                  error:(void(^)(NSString *message))errorBlock {
    [self post:@"/messages/send"
          data:@{
              @"type": @(conversation.type),
              @"target": conversation.target,
              @"line": @(conversation.line),
              @"content_type": @(5),
              @"content_media_type": @(4),
              @"content_remote_url": mediaUrl ?: @"",
              @"content_searchable": fileName ?: @"",
              @"content": [NSString stringWithFormat:@"%lld", size]
          }
       success:successBlock
         error:errorBlock];
}

- (void)uploadFiles:(NSString *)file
          mediaType:(int)mediaType
          fullImage:(BOOL)fullImage
           progress:(void(^)(int sentcount, int total))progressBlock
            success:(void(^)(NSString *url))successBlock
              error:(void(^)(NSString *errorMsg))errorBlock {
    if (!self.baseUrl.length) {
        if (errorBlock) errorBlock(@"未配置应用服务地址");
        return;
    }
    
    NSURL *fileURL = [NSURL URLWithString:file];
    if (!fileURL || !fileURL.isFileURL) {
        fileURL = [NSURL fileURLWithPath:file];
    }
    
    NSData *fileData = nil;
    NSString *fileName = fileURL.lastPathComponent ?: @"file";
    
    if (mediaType == 1 && !fullImage) {
        UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:fileURL]];
        if (image) {
            UIImage *scaled = [ShareUtility generateThumbnail:image withWidth:1024 withHeight:1024];
            fileData = UIImageJPEGRepresentation(scaled, 0.85);
        }
    }
    
    if (!fileData.length) {
        fileData = [NSData dataWithContentsOfURL:fileURL];
    }
    
    if (!fileData.length) {
        if (errorBlock) errorBlock(@"读取文件失败");
        return;
    }
    
    [self uploadData:fileData mediaType:mediaType progress:progressBlock success:successBlock error:errorBlock];
}

- (void)uploadData:(NSData *)data
         mediaType:(int)mediaType
          progress:(void(^)(int sentcount, int total))progressBlock
           success:(void(^)(NSString *url))successBlock
             error:(void(^)(NSString *errorMsg))errorBlock {
    if (!self.baseUrl.length) {
        if (errorBlock) errorBlock(@"未配置应用服务地址");
        return;
    }
    if (!data.length) {
        if (errorBlock) errorBlock(@"上传内容为空");
        return;
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@/media/upload/%d", self.baseUrl, mediaType];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    if (self.authToken.length) {
        [request setValue:self.authToken forHTTPHeaderField:kAuthorizationHeader];
    }
    
    NSString *boundary = [[NSUUID UUID] UUIDString];
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
    [request setValue:contentType forHTTPHeaderField:@"Content-Type"];
    
    NSString *fileName = [[NSUUID UUID] UUIDString];
    NSMutableData *body = [NSMutableData data];
    [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"file\"; filename=\"%@\"\r\n", fileName] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[@"Content-Type: application/octet-stream\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:data];
    [body appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    request.HTTPBody = body;
    
    NSURLSessionUploadTask *task = [self.uploadSession uploadTaskWithRequest:request fromData:body];
    ShareUploadTaskInfo *info = [[ShareUploadTaskInfo alloc] init];
    info.progressBlock = progressBlock;
    info.successBlock = successBlock;
    info.errorBlock = errorBlock;
    info.responseData = [NSMutableData data];
    
    @synchronized (self) {
        self.uploadTaskIdentifier++;
        task.taskDescription = [NSString stringWithFormat:@"%ld", (long)self.uploadTaskIdentifier];
        self.uploadTaskInfos[@(task.taskIdentifier)] = info;
    }
    
    [task resume];
}

- (ShareUploadTaskInfo *)uploadInfoForTask:(NSURLSessionTask *)task {
    @synchronized (self) {
        return self.uploadTaskInfos[@(task.taskIdentifier)];
    }
}

- (void)removeUploadInfoForTask:(NSURLSessionTask *)task {
    @synchronized (self) {
        [self.uploadTaskInfos removeObjectForKey:@(task.taskIdentifier)];
    }
}

#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    ShareUploadTaskInfo *info = [self uploadInfoForTask:task];
    if (!info || !info.progressBlock) return;
    
    info.progressBlock((int)totalBytesSent, (int)totalBytesExpectedToSend);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    ShareUploadTaskInfo *info = [self uploadInfoForTask:task];
    if (!info) return;
    
    if (error) {
        if (info.errorBlock) info.errorBlock(error.localizedDescription);
        [self removeUploadInfoForTask:task];
        return;
    }
    
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:info.responseData options:kNilOptions error:nil];
    if ([dict[@"code"] intValue] == 0) {
        NSString *url = dict[@"result"][@"url"];
        if (url.length && info.successBlock) {
            info.successBlock(url);
        } else if (info.errorBlock) {
            info.errorBlock(@"服务器返回数据异常");
        }
    } else {
        if (info.errorBlock) info.errorBlock(dict[@"message"] ?: @"上传失败");
    }
    [self removeUploadInfoForTask:task];
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    ShareUploadTaskInfo *info = [self uploadInfoForTask:dataTask];
    if (info && data.length) {
        [info.responseData appendData:data];
    }
}

#pragma mark - Private

- (void)post:(NSString *)path
        data:(NSDictionary *)data
     success:(void(^)(NSDictionary *dict))successBlock
       error:(void(^)(NSString *message))errorBlock {
    if (!self.baseUrl.length) {
        if (errorBlock) errorBlock(@"未配置应用服务地址");
        return;
    }
    
    NSString *urlString = [self.baseUrl stringByAppendingString:path];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    if (self.authToken.length) {
        [request setValue:self.authToken forHTTPHeaderField:kAuthorizationHeader];
    }
    
    NSData *body = [NSJSONSerialization dataWithJSONObject:data options:kNilOptions error:nil];
    request.HTTPBody = body;
    
    NSURLSessionTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                if (errorBlock) errorBlock(error.localizedDescription);
                return;
            }
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
            if ([dict[@"code"] intValue] == 0) {
                if (successBlock) successBlock(dict);
            } else {
                if (errorBlock) errorBlock(dict[@"message"] ?: @"发送失败");
            }
        });
    }];
    [task resume];
}

@end
