//
//  ConversationCell.m
//  ShareExtension
//

#import "ConversationCell.h"

@interface ConversationCell ()
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UILabel *nameLabel;
@end

@implementation ConversationCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.avatarView = [[UIImageView alloc] init];
    self.avatarView.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarView.layer.cornerRadius = 4;
    self.avatarView.clipsToBounds = YES;
    self.avatarView.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarView.backgroundColor = [UIColor systemGray5Color];
    [self.contentView addSubview:self.avatarView];
    
    self.nameLabel = [[UILabel alloc] init];
    self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.nameLabel.font = [UIFont systemFontOfSize:16];
    [self.contentView addSubview:self.nameLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.avatarView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.avatarView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.avatarView.widthAnchor constraintEqualToConstant:40],
        [self.avatarView.heightAnchor constraintEqualToConstant:40],
        [self.nameLabel.leadingAnchor constraintEqualToAnchor:self.avatarView.trailingAnchor constant:12],
        [self.nameLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.nameLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.contentView.trailingAnchor constant:-16]
    ]];
}

- (void)configureWithConversation:(SharedConversation *)conversation {
    self.nameLabel.text = conversation.title.length ? conversation.title : conversation.target;
    
    UIImage *placeholder = [self placeholderImageWithName:conversation.type == 1 ? @"群聊" : @""];
    self.avatarView.image = placeholder;
    
    if (conversation.portraitUrl.length) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:conversation.portraitUrl]];
            if (data) {
                UIImage *image = [UIImage imageWithData:data];
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.avatarView.image = image;
                });
            }
        });
    }
}

- (UIImage *)placeholderImageWithName:(NSString *)name {
    CGSize size = CGSizeMake(40, 40);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    [[UIColor systemGray4Color] setFill];
    UIRectFill(CGRectMake(0, 0, size.width, size.height));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@end
