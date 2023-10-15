//
//  AppService.m
//  WildFireChat
//
//  Created by Heavyrain Lee on 2019/10/22.
//  Copyright © 2019 WildFireChat. All rights reserved.
//

#import "AppService.h"
#import <WFChatUIKit/WFChatUIKit.h>
#import "AFNetworking.h"
#import <WebKit/WebKit.h>

static AppService *sharedSingleton = nil;

#define WFC_APPSERVER_AUTH_TOKEN  @"WFC_APPSERVER_AUTH_TOKEN"
#define WFC_APPSERVER_ADDRESS  @"WFC_APPSERVER_ADDRESS"

#define AUTHORIZATION_HEADER @"authToken"

@interface AppService ()
@property(nonatomic, strong)NSString *appServerAddress;
@end

@implementation AppService 
+ (AppService *)sharedAppService {
    if (sharedSingleton == nil) {
        @synchronized (self) {
            if (sharedSingleton == nil) {
                sharedSingleton = [[AppService alloc] init];
                sharedSingleton.appServerAddress = [[NSUserDefaults standardUserDefaults] objectForKey:WFC_APPSERVER_ADDRESS];
            }
        }
    }

    return sharedSingleton;
}

- (void)setServerAddress:(NSString *)appServerAddress {
    self.appServerAddress = appServerAddress;
    [[NSUserDefaults standardUserDefaults] setObject:appServerAddress forKey:WFC_APPSERVER_ADDRESS];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)getGroupAnnouncement:(NSString *)groupId
                     success:(void(^)(WFCUGroupAnnouncement *))successBlock
                      error:(void(^)(int error_code))errorBlock {
    if (successBlock) {
        NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"wfc_group_an_%@", groupId]];
    
        WFCUGroupAnnouncement *an = [[WFCUGroupAnnouncement alloc] init];
        an.data = data;
        an.groupId = groupId;
        
        successBlock(an);
    }
    
    NSString *path = @"/get_group_announcement";
    NSDictionary *param = @{@"groupId":groupId};
    [self post:path data:param isLogin:NO success:^(NSDictionary *dict) {
        if([dict[@"code"] intValue] == 0 || [dict[@"code"] intValue] == 12) {
            WFCUGroupAnnouncement *an = [[WFCUGroupAnnouncement alloc] init];
            an.groupId = groupId;
            if ([dict[@"code"] intValue] == 0) {
                an.author = dict[@"result"][@"author"];
                an.text = dict[@"result"][@"text"];
                an.timestamp = [dict[@"result"][@"timestamp"] longValue];
            }
            
            [[NSUserDefaults standardUserDefaults] setValue:an.data forKey:[NSString stringWithFormat:@"wfc_group_an_%@", groupId]];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            if(successBlock) successBlock(an);
        } else {
            if(errorBlock) errorBlock([dict[@"code"] intValue]);
        }
    } error:^(NSError * _Nonnull error) {
        if(errorBlock) errorBlock(-1);
    }];
}

- (void)updateGroup:(NSString *)groupId
       announcement:(NSString *)announcement
            success:(void(^)(long timestamp))successBlock
              error:(void(^)(int error_code))errorBlock {
//    
//    NSString *path = @"/put_group_announcement";
//    NSDictionary *param = @{@"groupId":groupId, @"author":[WFCCNetworkService sharedInstance].userId, @"text":announcement};
//    [self post:path data:param isLogin:NO success:^(NSDictionary *dict) {
//        if([dict[@"code"] intValue] == 0) {
//            WFCUGroupAnnouncement *an = [[WFCUGroupAnnouncement alloc] init];
//            an.groupId = groupId;
//            an.author = [WFCCNetworkService sharedInstance].userId;
//            an.text = announcement;
//            an.timestamp = [dict[@"result"][@"timestamp"] longValue];
//            
//            
//            [[NSUserDefaults standardUserDefaults] setValue:an.data forKey:[NSString stringWithFormat:@"wfc_group_an_%@", groupId]];
//            [[NSUserDefaults standardUserDefaults] synchronize];
//            
//            if(successBlock) successBlock(an.timestamp);
//        } else {
//            if(errorBlock) errorBlock([dict[@"code"] intValue]);
//        }
//    } error:^(NSError * _Nonnull error) {
//        if(errorBlock) errorBlock(-1);
//    }];
}

- (void)getGroupMembersForPortrait:(NSString *)groupId
                           success:(void(^)(NSArray<NSDictionary<NSString *, NSString *> *> *groupMembers))successBlock
                             error:(void(^)(int error_code))errorBlock {
    NSString *path = @"/group/members_for_portrait";
    [self post:path data:@{@"groupId":groupId} isLogin:NO success:^(NSDictionary *dict) {
        if([dict[@"code"] intValue] == 0) {
            if([dict[@"result"] isKindOfClass:NSArray.class]) {
                NSArray *arr = (NSArray *)dict[@"result"];
                if(successBlock) successBlock(arr);
            }
        } else {
            if(errorBlock) errorBlock([dict[@"code"] intValue]);
        }
    } error:^(NSError * _Nonnull error) {
        if(errorBlock) errorBlock(-1);
    }];
}

- (void)post:(NSString *)path data:(id)data isLogin:(BOOL)isLogin success:(void(^)(NSDictionary *dict))successBlock error:(void(^)(NSError * _Nonnull error))errorBlock {
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    manager.responseSerializer.acceptableContentTypes = [NSSet setWithObject:@"application/json"];
    
    //在调用其他接口时需要把cookie传给后台，也就是设置cookie的过程
    NSString *authToken = [self getAppServiceAuthToken];
    if(authToken.length) {
        [manager.requestSerializer setValue:authToken forHTTPHeaderField:AUTHORIZATION_HEADER];
    } else {
        NSLog(@"No authtoken avaible! Are you sure called setAppAuthToken method?");
    }
    
    [manager POST:[self.appServerAddress stringByAppendingPathComponent:path]
       parameters:data
         progress:nil
          success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            NSDictionary *dict = responseObject;
            dispatch_async(dispatch_get_main_queue(), ^{
              successBlock(dict);
            });
          }
          failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                errorBlock(error);
            });
          }];
}

- (void)uploadLogs:(void(^)(void))successBlock error:(void(^)(NSString *errorMsg))errorBlock {
//    dispatch_async(dispatch_get_global_queue(0, 0), ^{
//        NSMutableArray<NSString *> *logFiles = [[WFCCNetworkService getLogFilesPath]  mutableCopy];
//        
//        NSMutableArray *uploadedFiles = [[[[NSUserDefaults standardUserDefaults] objectForKey:@"mars_uploaded_files"] sortedArrayUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) {
//            return [obj1 compare:obj2];
//        }] mutableCopy];
//        
//        //日志文件列表需要删除掉已上传记录，避免重复上传。
//        //但需要上传最后一条已经上传日志，因为那个日志文件可能在上传之后继续写入了，所以需要继续上传
//        if (uploadedFiles.count) {
//            [uploadedFiles removeLastObject];
//        } else {
//            uploadedFiles = [[NSMutableArray alloc] init];
//        }
//        for (NSString *file in [logFiles copy]) {
//            NSString *name = [file componentsSeparatedByString:@"/"].lastObject;
//            if ([uploadedFiles containsObject:name]) {
//                [logFiles removeObject:file];
//            }
//        }
//        
//        
//        __block NSString *errorMsg = nil;
//        
//        for (NSString *logFile in logFiles) {
//            AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
//            manager.responseSerializer.acceptableContentTypes = [NSSet setWithObject:@"application/json"];
//            
//            NSString *url = [self.appServerAddress stringByAppendingFormat:@"/logs/%@/upload", [WFCCNetworkService sharedInstance].userId];
//            
//             dispatch_semaphore_t sema = dispatch_semaphore_create(0);
//            
//            __block BOOL success = NO;
//
//            [manager POST:url parameters:nil constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
//                NSData *logData = [NSData dataWithContentsOfFile:logFile];
//                if (!logData.length) {
//                    logData = [@"empty" dataUsingEncoding:NSUTF8StringEncoding];
//                }
//                
//                NSString *fileName = [[NSURL URLWithString:logFile] lastPathComponent];
//                [formData appendPartWithFileData:logData name:@"file" fileName:fileName mimeType:@"application/octet-stream"];
//            } progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
//                if ([responseObject isKindOfClass:[NSDictionary class]]) {
//                    NSDictionary *dict = (NSDictionary *)responseObject;
//                    if([dict[@"code"] intValue] == 0) {
//                        NSLog(@"上传成功");
//                        success = YES;
//                        NSString *name = [logFile componentsSeparatedByString:@"/"].lastObject;
//                        [uploadedFiles removeObject:name];
//                        [uploadedFiles addObject:name];
//                        [[NSUserDefaults standardUserDefaults] setObject:uploadedFiles forKey:@"mars_uploaded_files"];
//                        [[NSUserDefaults standardUserDefaults] synchronize];
//                    }
//                }
//                if (!success) {
//                    errorMsg = @"服务器响应错误";
//                }
//                dispatch_semaphore_signal(sema);
//            } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
//                NSLog(@"上传失败：%@", error);
//                dispatch_semaphore_signal(sema);
//                errorMsg = error.localizedFailureReason;
//            }];
//            
//            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
//            
//            if (!success) {
//                errorBlock(errorMsg);
//                return;
//            }
//        }
//        
//        successBlock();
//    });
    
}

- (void)getMyPrivateConferenceId:(void(^)(NSString *conferenceId))successBlock error:(void(^)(int errorCode, NSString *message))errorBlock {
    [self post:@"/conference/get_my_id" data:nil isLogin:NO success:^(NSDictionary *dict) {
        int code = [dict[@"code"] intValue];
        if(code == 0) {
            NSString *conferenceId = dict[@"result"];
            successBlock(conferenceId);
        } else {
            errorBlock(code, dict[@"message"]);
        }
    } error:^(NSError * _Nonnull error) {
        errorBlock(-1, error.localizedDescription);
    }];
}

- (void)createConference:(WFZConferenceInfo *)conferenceInfo success:(void(^)(NSString *conferenceId))successBlock error:(void(^)(int errorCode, NSString *message))errorBlock {
    [self post:@"/conference/create" data:[conferenceInfo toDictionary] isLogin:NO success:^(NSDictionary *dict) {
        int code = [dict[@"code"] intValue];
        if(code == 0) {
            NSString *conferenceId = dict[@"result"];
            conferenceInfo.conferenceId = conferenceId;
            successBlock(conferenceId);
        } else {
            errorBlock(code, dict[@"message"]);
        }
    } error:^(NSError * _Nonnull error) {
        errorBlock(-1, error.localizedDescription);
    }];
}

- (void)updateConference:(WFZConferenceInfo *)conferenceInfo success:(void(^)(void))successBlock error:(void(^)(int errorCode, NSString *message))errorBlock {
    [self post:@"/conference/put_info" data:[conferenceInfo toDictionary] isLogin:NO success:^(NSDictionary *dict) {
        int code = [dict[@"code"] intValue];
        if(code == 0) {
            successBlock();
        } else {
            errorBlock(code, dict[@"message"]);
        }
    } error:^(NSError * _Nonnull error) {
        errorBlock(-1, error.localizedDescription);
    }];
}

- (void)recordConference:(NSString *)conferenceId record:(BOOL)record success:(void(^)(void))successBlock error:(void(^)(int errorCode, NSString *message))errorBlock {
    [self post:[NSString stringWithFormat:@"/conference/recording/%@", conferenceId] data:@{@"recording":@(record)} isLogin:NO success:^(NSDictionary *dict) {
        int code = [dict[@"code"] intValue];
        if(code == 0) {
            successBlock();
        } else {
            errorBlock(code, dict[@"message"]);
        }
    } error:^(NSError * _Nonnull error) {
        errorBlock(-1, error.localizedDescription);
    }];
}

- (void)focusConference:(NSString *)conferenceId userId:(NSString *)focusUserId success:(void(^)(void))successBlock error:(void(^)(int errorCode, NSString *message))errorBlock {
    [self post:[NSString stringWithFormat:@"/conference/focus/%@", conferenceId] data:@{@"userId":(focusUserId?focusUserId:@"")} isLogin:NO success:^(NSDictionary *dict) {
        int code = [dict[@"code"] intValue];
        if(code == 0) {
            successBlock();
        } else {
            errorBlock(code, dict[@"message"]);
        }
    } error:^(NSError * _Nonnull error) {
        errorBlock(-1, error.localizedDescription);
    }];
}

- (void)queryConferenceInfo:(NSString *)conferenceId password:(NSString *)password success:(void(^)(WFZConferenceInfo *conferenceInfo))successBlock error:(void(^)(int errorCode, NSString *message))errorBlock {
    NSDictionary *data;
    if(password.length) {
        data = @{@"conferenceId":conferenceId, @"password":password};
    } else {
        data = @{@"conferenceId":conferenceId};
    }
    
    [self post:@"/conference/info" data:data isLogin:NO success:^(NSDictionary *dict) {
        int code = [dict[@"code"] intValue];
        if(code == 0) {
            WFZConferenceInfo *info = [WFZConferenceInfo fromDictionary:dict[@"result"]];
            successBlock(info);
        } else {
            errorBlock(code, dict[@"message"]);
        }
    } error:^(NSError * _Nonnull error) {
        errorBlock(-1, error.localizedDescription);
    }];
}

- (void)destroyConference:(NSString *)conferenceId success:(void(^)(void))successBlock error:(void(^)(int errorCode, NSString *message))errorBlock {
    [self post:[NSString stringWithFormat:@"/conference/destroy/%@", conferenceId] data:nil isLogin:NO success:^(NSDictionary *dict) {
        int code = [dict[@"code"] intValue];
        if(code == 0) {
            [[NSNotificationCenter defaultCenter] postNotificationName:kCONFERENCE_DESTROYED object:nil];
            successBlock();
        } else {
            errorBlock(code, dict[@"message"]);
        }
    } error:^(NSError * _Nonnull error) {
        errorBlock(-1, error.localizedDescription);
    }];
}

- (void)favConference:(NSString *)conferenceId success:(void(^)(void))successBlock error:(void(^)(int errorCode, NSString *message))errorBlock {
    [self post:[NSString stringWithFormat:@"/conference/fav/%@", conferenceId] data:nil isLogin:NO success:^(NSDictionary *dict) {
        int code = [dict[@"code"] intValue];
        if(code == 0) {
            successBlock();
        } else {
            errorBlock(code, dict[@"message"]);
        }
    } error:^(NSError * _Nonnull error) {
        errorBlock(-1, error.localizedDescription);
    }];
}

- (void)unfavConference:(NSString *)conferenceId success:(void(^)(void))successBlock error:(void(^)(int errorCode, NSString *message))errorBlock {
    [self post:[NSString stringWithFormat:@"/conference/unfav/%@", conferenceId] data:nil isLogin:NO success:^(NSDictionary *dict) {
        int code = [dict[@"code"] intValue];
        if(code == 0) {
            successBlock();
        } else {
            errorBlock(code, dict[@"message"]);
        }
    } error:^(NSError * _Nonnull error) {
        errorBlock(-1, error.localizedDescription);
    }];
}

- (void)isFavConference:(NSString *)conferenceId success:(void(^)(BOOL isFav))successBlock error:(void(^)(int errorCode, NSString *message))errorBlock {
    [self post:[NSString stringWithFormat:@"/conference/is_fav/%@", conferenceId] data:nil isLogin:NO success:^(NSDictionary *dict) {
        int code = [dict[@"code"] intValue];
        if(code == 0) {
            successBlock(YES);
        } else if(code == 16) {
            successBlock(NO);
        } else {
            errorBlock(code, dict[@"message"]);
        }
    } error:^(NSError * _Nonnull error) {
        errorBlock(-1, error.localizedDescription);
    }];
}

- (void)getFavConferences:(void(^)(NSArray<WFZConferenceInfo *> *))successBlock error:(void(^)(int errorCode, NSString *message))errorBlock {
    [self post:@"/conference/fav_conferences" data:nil isLogin:NO success:^(NSDictionary *dict) {
        int code = [dict[@"code"] intValue];
        if(code == 0) {
            NSArray<NSDictionary *> *ls = dict[@"result"];
            NSMutableArray *output = [[NSMutableArray alloc] init];
            [ls enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [output addObject:[WFZConferenceInfo fromDictionary:obj]];
            }];
            successBlock(output);
        } else {
            errorBlock(code, dict[@"message"]);
        }
    } error:^(NSError * _Nonnull error) {
        errorBlock(-1, error.localizedDescription);
    }];
}


- (void)getFavoriteItems:(int )startId
                   count:(int)count
                 success:(void(^)(NSArray<WFCUFavoriteItem *> *items, BOOL hasMore))successBlock
                   error:(void(^)(int error_code))errorBlock {
//    NSString *path = @"/fav/list";
//    NSDictionary *param = @{@"id":@(startId), @"count":@(count)};
//    [self post:path data:param isLogin:NO success:^(NSDictionary *dict) {
//        if([dict[@"code"] intValue] == 0) {
//            NSDictionary *result = dict[@"result"];
//            BOOL hasMore = [result[@"hasMore"] boolValue];
//            NSArray<NSDictionary *> *arrs = (NSArray *)result[@"items"];
//            NSMutableArray<WFCUFavoriteItem *> *output = [[NSMutableArray alloc] init];
//            for (NSDictionary *d in arrs) {
//                WFCUFavoriteItem *item = [[WFCUFavoriteItem alloc] init];
//                item.conversation = [WFCCConversation conversationWithType:[d[@"convType"] intValue] target:d[@"convTarget"] line:[d[@"convLine"] intValue]];
//                item.favId = [d[@"id"] intValue];
//                if(![d[@"messageUid"] isEqual:[NSNull null]])
//                    item.messageUid = [d[@"messageUid"] longLongValue];
//                item.timestamp = [d[@"timestamp"] longLongValue];
//                item.url = d[@"url"];
//                item.favType = [d[@"type"] intValue];
//                item.title = d[@"title"];
//                item.data = d[@"data"];
//                item.origin = d[@"origin"];
//                item.thumbUrl = d[@"thumbUrl"];
//                item.sender = d[@"sender"];
//                
//                [output addObject:item];
//            }
//            if(successBlock) successBlock(output, hasMore);
//        } else {
//            errorBlock([dict[@"code"] intValue]);
//        }
//    } error:^(NSError * _Nonnull error) {
//        if(errorBlock) errorBlock(-1);
//    }];
}

- (void)addFavoriteItem:(WFCUFavoriteItem *)item
                success:(void(^)(void))successBlock
                  error:(void(^)(int error_code))errorBlock {
//    NSString *path = @"/fav/add";
//    NSDictionary *param = @{@"type":@(item.favType),
//                            @"messageUid":@(item.messageUid),
//                            @"convType":@(item.conversation.type),
//                            @"convLine":@(item.conversation.line),
//                            @"convTarget":item.conversation.target?item.conversation.target:@"",
//                            @"origin":item.origin?item.origin:@"",
//                            @"sender":item.sender?item.sender:@"",
//                            @"title":item.title?item.title:@"",
//                            @"url":item.url?item.url:@"",
//                            @"thumbUrl":item.thumbUrl?item.thumbUrl:@"",
//                            @"data":item.data?item.data:@""
//    };
//    
//    [self post:path data:param isLogin:NO success:^(NSDictionary *dict) {
//        if([dict[@"code"] intValue] == 0) {
//            if(successBlock) successBlock();
//        } else {
//            if(errorBlock) errorBlock([dict[@"code"] intValue]);
//        }
//    } error:^(NSError * _Nonnull error) {
//        if(errorBlock) errorBlock(-1);
//    }];
}

- (void)removeFavoriteItem:(int)favId
                   success:(void(^)(void))successBlock
                     error:(void(^)(int error_code))errorBlock {
    NSString *path = [NSString stringWithFormat:@"/fav/del/%d", favId];
    
    [self post:path data:nil isLogin:NO success:^(NSDictionary *dict) {
        if([dict[@"code"] intValue] == 0) {
            if(successBlock) successBlock();
        } else {
            if(errorBlock) errorBlock([dict[@"code"] intValue]);
        }
    } error:^(NSError * _Nonnull error) {
        if(errorBlock) errorBlock(-1);
    }];
}

- (void)changeName:(nonnull NSString *)newName success:(nonnull void (^)(void))successBlock error:(nonnull void (^)(int, NSString * _Nonnull))errorBlock {
    
}


- (void)showPCSessionViewController:(nonnull UIViewController *)baseController pcClient:(nonnull WFCCPCOnlineInfo *)clientInfo {
    
}

- (void)setAppAuthToken:(NSString *)authToken {
    [[NSUserDefaults standardUserDefaults] setObject:authToken forKey:WFC_APPSERVER_AUTH_TOKEN];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)getAppServiceAuthToken {
    return [[NSUserDefaults standardUserDefaults] objectForKey:WFC_APPSERVER_AUTH_TOKEN];
}

- (void)clearAppServiceAuthInfos {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:WFC_APPSERVER_AUTH_TOKEN];
}

@end
