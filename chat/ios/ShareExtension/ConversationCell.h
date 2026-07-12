//
//  ConversationCell.h
//  ShareExtension
//

#import <UIKit/UIKit.h>
#import "SharedConversation.h"

@interface ConversationCell : UITableViewCell

- (void)configureWithConversation:(SharedConversation *)conversation;

@end
