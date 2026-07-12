//
//  ConversationListViewController.h
//  ShareExtension
//

#import <UIKit/UIKit.h>

@interface ConversationListViewController : UITableViewController

@property(nonatomic, strong) NSString *textMessageContent;
@property(nonatomic, strong) NSString *url;
@property(nonatomic, strong) NSString *urlTitle;
@property(nonatomic, strong) NSString *urlThumbnail;
@property(nonatomic, strong) NSMutableArray<NSString *> *imageUrls;
@property(nonatomic, assign) BOOL fullImage;
@property(nonatomic, strong) UIImage *image;
@property(nonatomic, strong) NSString *fileUrl;

@end
