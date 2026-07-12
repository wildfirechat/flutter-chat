//
//  SharedConversation.h
//  ShareExtension
//

#import <Foundation/Foundation.h>

@interface SharedConversation : NSObject <NSSecureCoding>

@property (nonatomic, assign) int type;
@property (nonatomic, copy) NSString *target;
@property (nonatomic, assign) int line;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *portraitUrl;

- (instancetype)initWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)toDictionary;

@end
