//
//  ConversationListViewController.m
//  ShareExtension
//

#import "ConversationListViewController.h"
#import "ConversationCell.h"
#import "SharedConversation.h"
#import "ShareAppService.h"
#import "ShareUtility.h"
#import "MBProgressHUD.h"

static NSString * const kShareAppGroupId = @"group.cn.wildfirechat.messangerEx";
static NSString * const kSharedConversationsKey = @"wfc_share_conversation_list";

@interface ConversationListViewController ()
@property (nonatomic, strong) NSArray<SharedConversation *> *conversations;
@end

@implementation ConversationListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"选择一个聊天";
    self.tableView.rowHeight = 56;
    [self.tableView registerClass:[ConversationCell class] forCellReuseIdentifier:@"ConversationCell"];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"取消" style:UIBarButtonItemStylePlain target:self action:@selector(cancel)];
    
    [self loadConversations];
}

- (void)loadConversations {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kShareAppGroupId];
    NSArray<NSDictionary *> *rawList = [defaults objectForKey:kSharedConversationsKey];
    NSMutableArray<SharedConversation *> *list = [NSMutableArray array];
    for (NSDictionary *dict in rawList) {
        SharedConversation *conv = [[SharedConversation alloc] initWithDictionary:dict];
        [list addObject:conv];
    }
    self.conversations = [list copy];
    [self.tableView reloadData];
}

- (void)cancel {
    [self.extensionContext completeRequestReturningItems:nil completionHandler:nil];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.conversations.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ConversationCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ConversationCell" forIndexPath:indexPath];
    [cell configureWithConversation:self.conversations[indexPath.row]];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    SharedConversation *conversation = self.conversations[indexPath.row];
    
    __weak typeof(self) ws = self;
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"确认发送给" message:conversation.title preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *action = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [ws sendTo:conversation];
    }];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    
    [alertController addAction:cancel];
    [alertController addAction:action];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)sendTo:(SharedConversation *)conversation {
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    [MBProgressHUD HUDForView:self.view].mode = MBProgressHUDModeDeterminate;
    [MBProgressHUD HUDForView:self.view].label.text = @"发送中";
    
    __weak typeof(self) ws = self;
    if (self.textMessageContent.length) {
        [[ShareAppService sharedService] sendTextMessage:conversation text:self.textMessageContent success:^(NSDictionary *dict) {
            [ws showSuccess];
        } error:^(NSString *message) {
            [ws showFailure];
        }];
    } else if (self.url.length) {
        [[ShareAppService sharedService] sendLinkMessage:conversation link:self.url title:self.urlTitle thumbnailLink:self.urlThumbnail success:^(NSDictionary *dict) {
            [ws showSuccess];
        } error:^(NSString *message) {
            [ws showFailure];
        }];
    } else if (self.imageUrls.count) {
        [[ShareAppService sharedService] uploadFiles:self.imageUrls[0] mediaType:1 fullImage:self.fullImage progress:^(int sentcount, int dataSize) {
            [ws showProgress:sentcount total:dataSize];
        } success:^(NSString *url) {
            UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:ws.imageUrls[0]]]];
            UIImage *thumbnail = [ShareUtility generateThumbnail:image withWidth:120 withHeight:120];
            [[ShareAppService sharedService] sendImageMessage:conversation mediaUrl:url thumbnail:thumbnail success:^(NSDictionary *dict) {
                [ws showSuccess];
            } error:^(NSString *message) {
                [ws showFailure];
            }];
        } error:^(NSString *errorMsg) {
            [ws showFailure];
        }];
    } else if (self.fileUrl.length) {
        __block int size = 0;
        [[ShareAppService sharedService] uploadFiles:self.fileUrl mediaType:4 fullImage:YES progress:^(int sentcount, int total) {
            size = total;
            [ws showProgress:sentcount total:total];
        } success:^(NSString *url) {
            NSString *fileName = ws.fileUrl.lastPathComponent;
            [[ShareAppService sharedService] sendFileMessage:conversation mediaUrl:url fileName:fileName size:size success:^(NSDictionary *dict) {
                [ws showSuccess];
            } error:^(NSString *message) {
                [ws showFailure];
            }];
        } error:^(NSString *errorMsg) {
            [ws showFailure];
        }];
    } else if (self.image) {
        UIImage *image = [ShareUtility generateThumbnail:self.image withWidth:1024 withHeight:1024];
        NSData *imgData = UIImageJPEGRepresentation(image, 0.85);
        [[ShareAppService sharedService] uploadData:imgData mediaType:1 progress:^(int sentcount, int total) {
            [ws showProgress:sentcount total:total];
        } success:^(NSString *url) {
            UIImage *thumbnail = [ShareUtility generateThumbnail:ws.image withWidth:120 withHeight:120];
            [[ShareAppService sharedService] sendImageMessage:conversation mediaUrl:url thumbnail:thumbnail success:^(NSDictionary *dict) {
                [ws showSuccess];
            } error:^(NSString *message) {
                [ws showFailure];
            }];
        } error:^(NSString *errorMsg) {
            [ws showFailure];
        }];
    }
}

- (void)showProgress:(int)sent total:(int)total {
    NSLog(@"progress %d %d", sent, total);
    __weak typeof(self) ws = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (total > 0) {
            [MBProgressHUD HUDForView:ws.view].progress = (float)sent / total;
        }
    });
}

- (void)showSuccess {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    
    __weak typeof(self) ws = self;
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"已发送" message:@"请在野火IM中查看" preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *action = [UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [ws.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
    }];
    [alertController addAction:action];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)showFailure {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    
    __weak typeof(self) ws = self;
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"网络错误" message:@"发送失败，请检查网络后重试" preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *action = [UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [ws.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
    }];
    [alertController addAction:action];
    [self presentViewController:alertController animated:YES completion:nil];
}

@end
