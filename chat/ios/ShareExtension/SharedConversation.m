//
//  SharedConversation.m
//  ShareExtension
//

#import "SharedConversation.h"

@implementation SharedConversation

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    self = [super init];
    if (self) {
        _type = [dict[@"type"] intValue];
        _target = dict[@"target"] ?: @"";
        _line = [dict[@"line"] intValue];
        _title = dict[@"title"] ?: @"";
        _portraitUrl = dict[@"portraitUrl"] ?: @"";
    }
    return self;
}

- (NSDictionary *)toDictionary {
    return @{
        @"type": @(_type),
        @"target": _target ?: @"",
        @"line": @(_line),
        @"title": _title ?: @"",
        @"portraitUrl": _portraitUrl ?: @""
    };
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInt:_type forKey:@"type"];
    [coder encodeObject:_target forKey:@"target"];
    [coder encodeInt:_line forKey:@"line"];
    [coder encodeObject:_title forKey:@"title"];
    [coder encodeObject:_portraitUrl forKey:@"portraitUrl"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _type = [coder decodeIntForKey:@"type"];
        _target = [coder decodeObjectOfClass:[NSString class] forKey:@"target"] ?: @"";
        _line = [coder decodeIntForKey:@"line"];
        _title = [coder decodeObjectOfClass:[NSString class] forKey:@"title"] ?: @"";
        _portraitUrl = [coder decodeObjectOfClass:[NSString class] forKey:@"portraitUrl"] ?: @"";
    }
    return self;
}

@end
