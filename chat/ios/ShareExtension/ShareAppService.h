//
//  ShareAppService.h
//  ShareExtension
//

#import <UIKit/UIKit.h>
#import "SharedConversation.h"

@interface ShareAppService : NSObject

+ (instancetype)sharedService;

- (BOOL)isLogin;

- (void)sendTextMessage:(SharedConversation *)conversation
                   text:(NSString *)text
                success:(void(^)(NSDictionary *dict))successBlock
                  error:(void(^)(NSString *message))errorBlock;

- (void)sendLinkMessage:(SharedConversation *)conversation
                   link:(NSString *)link
                  title:(NSString *)title
           thumbnailLink:(NSString *)thumbnailLink
                success:(void(^)(NSDictionary *dict))successBlock
                  error:(void(^)(NSString *message))errorBlock;

- (void)sendImageMessage:(SharedConversation *)conversation
                mediaUrl:(NSString *)mediaUrl
               thumbnail:(UIImage *)thumbnail
                 success:(void(^)(NSDictionary *dict))successBlock
                   error:(void(^)(NSString *message))errorBlock;

- (void)sendFileMessage:(SharedConversation *)conversation
               mediaUrl:(NSString *)mediaUrl
               fileName:(NSString *)fileName
                   size:(long long)size
                success:(void(^)(NSDictionary *dict))successBlock
                  error:(void(^)(NSString *message))errorBlock;

- (void)uploadFiles:(NSString *)file
          mediaType:(int)mediaType
          fullImage:(BOOL)fullImage
           progress:(void(^)(int sentcount, int total))progressBlock
            success:(void(^)(NSString *url))successBlock
              error:(void(^)(NSString *errorMsg))errorBlock;

- (void)uploadData:(NSData *)data
         mediaType:(int)mediaType
          progress:(void(^)(int sentcount, int total))progressBlock
           success:(void(^)(NSString *url))successBlock
             error:(void(^)(NSString *errorMsg))errorBlock;

@end
