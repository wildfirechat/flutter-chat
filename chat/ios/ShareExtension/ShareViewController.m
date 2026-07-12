//
//  ShareViewController.m
//  ShareExtension
//

#import "ShareViewController.h"
#import "ConversationListViewController.h"
#import "ShareAppService.h"
#import "SharedConversation.h"
#import "ShareUtility.h"
#import "MBProgressHUD.h"
#import <MobileCoreServices/MobileCoreServices.h>

static NSString * const kFileTransferId = @"wfc_file_transfer";

@interface ShareViewController () <UITableViewDataSource, UITableViewDelegate>
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, assign) BOOL dataLoaded;

// 文本
@property(nonatomic, strong) NSString *textMessageContent;

// 链接
@property(nonatomic, strong) NSString *urlTitle;
@property(nonatomic, strong) NSString *url;
@property(nonatomic, strong) NSString *urlThumbnail;

// 图片
@property(nonatomic, assign) BOOL fullImage;
@property(nonatomic, strong) NSMutableArray<NSString *> *imageUrls;
@property(nonatomic, strong) UIImage *image;

// 文件
@property(nonatomic, strong) NSString *fileUrl;
@end

@implementation ShareViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = @"野火IM";
    
    if (![[ShareAppService sharedService] isLogin]) {
        __weak typeof(self) ws = self;
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"未登录" message:@"请先登录野火IM" preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            [ws.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
        }];
        [alertController addAction:cancel];
        [ws presentViewController:alertController animated:YES completion:nil];
        return;
    }
    
    self.dataLoaded = NO;
    self.fullImage = NO;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"取消" style:UIBarButtonItemStyleDone target:self action:@selector(onLeftBarBtn:)];
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    if (@available(iOS 15, *)) {
        self.tableView.sectionHeaderTopPadding = 0;
    }
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
    
    self.tableView.tableHeaderView = [self loadTableViewHeader];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    [self.tableView reloadData];
}

- (UIView *)loadTableViewHeader {
    CGFloat width = self.view.bounds.size.width;
    UIView *header = [[UIView alloc] initWithFrame:CGRectZero];
    
    if (self.extensionContext.inputItems.count) {
        NSExtensionItem *item = self.extensionContext.inputItems[0];
        if (item.attachments.count) {
            __weak typeof(self) ws = self;
            for (NSItemProvider *provider in item.attachments) {
                header.frame = CGRectMake(0, 0, width, 40);
                UILabel *fileLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, 8, width - 32, 24)];
                [header addSubview:fileLabel];
                
                if ([provider hasItemConformingToTypeIdentifier:(NSString *)kUTTypeFileURL]) {
                    [provider loadItemForTypeIdentifier:(NSString *)kUTTypeFileURL options:nil completionHandler:^(NSURL *url, NSError *error) {
                        NSString *fileName = url.lastPathComponent;
                        ws.fileUrl = url.absoluteString;
                        dispatch_async(dispatch_get_main_queue(), ^{
                            fileLabel.text = fileName;
                            ws.dataLoaded = YES;
                        });
                    }];
                } else if ([provider hasItemConformingToTypeIdentifier:(NSString *)kUTTypeURL]) {
                    header.frame = CGRectMake(0, 0, width, 132);
                    UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectMake(16, 16, 100, 100)];
                    iconView.contentMode = UIViewContentModeScaleAspectFit;
                    [header addSubview:iconView];
                    
                    UILabel *titleLabel = [[UILabel alloc] init];
                    titleLabel.text = item.attributedContentText.string;
                    titleLabel.font = [UIFont systemFontOfSize:18];
                    titleLabel.numberOfLines = 0;
                    CGSize titleSize = [self getTextDrawingSize:item.attributedContentText.string font:titleLabel.font constrainedSize:CGSizeMake(width - 132 - 32, 48)];
                    titleLabel.frame = CGRectMake(132, 16, width - 132 - 32, titleSize.height);
                    [header addSubview:titleLabel];
                    
                    UILabel *contentLabel = [[UILabel alloc] initWithFrame:CGRectMake(132, titleSize.height + 24, width - 132 - 32, 0)];
                    contentLabel.numberOfLines = 0;
                    contentLabel.textColor = [UIColor grayColor];
                    contentLabel.font = [UIFont systemFontOfSize:16];
                    [header addSubview:contentLabel];
                    
                    self.urlTitle = item.attributedContentText.string;
                    
                    [provider loadItemForTypeIdentifier:(NSString *)kUTTypeURL options:nil completionHandler:^(NSURL *url, NSError *error) {
                        if ([url.scheme isEqualToString:@"http"] || [url.scheme isEqualToString:@"https"]) {
                            NSString *favIcon = [NSString stringWithFormat:@"%@://%@/favicon.ico", url.scheme, url.host];
                            dispatch_async(dispatch_get_main_queue(), ^{
                                contentLabel.text = url.absoluteString;
                                CGSize size = [ws getTextDrawingSize:url.absoluteString font:contentLabel.font constrainedSize:CGSizeMake(width - 132 - 32, 132 - 16 - titleSize.height - 16)];
                                CGRect frame = contentLabel.frame;
                                frame.size.height = size.height;
                                contentLabel.frame = frame;
                                ws.url = url.absoluteString;
                                ws.dataLoaded = YES;
                                iconView.image = [UIImage imageNamed:@"DefaultLink"];
                            });
                            
                            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                                UIImage *portrait = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:favIcon]]];
                                if (portrait) {
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        iconView.image = portrait;
                                        ws.urlThumbnail = favIcon;
                                    });
                                }
                            });
                        }
                    }];
                } else if ([provider hasItemConformingToTypeIdentifier:(NSString *)kUTTypeImage]) {
                    header.frame = CGRectMake(0, 0, width, 400);
                    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, width, 400)];
                    imageView.contentMode = UIViewContentModeScaleAspectFit;
                    [header addSubview:imageView];
                    
                    self.imageUrls = [[NSMutableArray alloc] init];
                    [provider loadItemForTypeIdentifier:(NSString *)kUTTypeImage options:nil completionHandler:^(id item, NSError *error) {
                        UIImage *image = nil;
                        if ([item isKindOfClass:[UIImage class]]) {
                            image = (UIImage *)item;
                            ws.dataLoaded = YES;
                            ws.image = image;
                        } else if ([item isKindOfClass:[NSURL class]]) {
                            NSURL *url = (NSURL *)item;
                            if ([url.scheme isEqualToString:@"file"]) {
                                ws.dataLoaded = YES;
                                [ws.imageUrls addObject:url.absoluteString];
                                image = [UIImage imageWithData:[NSData dataWithContentsOfURL:url]];
                            }
                        }
                        dispatch_async(dispatch_get_main_queue(), ^{
                            imageView.image = image;
                            [ws.tableView reloadData];
                        });
                    }];
                    break;
                } else if ([provider hasItemConformingToTypeIdentifier:(NSString *)kUTTypePlainText]) {
                    self.textMessageContent = item.attributedContentText.string;
                    header.frame = CGRectMake(0, 0, width, 132);
                    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(16, 16, width - 32, 100)];
                    label.numberOfLines = 0;
                    label.text = item.attributedContentText.string;
                    [header addSubview:label];
                    self.dataLoaded = YES;
                }
            }
        }
    }
    return header;
}

- (void)setDataLoaded:(BOOL)dataLoaded {
    _dataLoaded = dataLoaded;
    [self.tableView reloadData];
}

- (void)onLeftBarBtn:(id)sender {
    [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
}

- (CGSize)getTextDrawingSize:(NSString *)text
                        font:(UIFont *)font
             constrainedSize:(CGSize)constrainedSize {
    if (text.length <= 0) {
        return CGSizeZero;
    }
    return [text boundingRectWithSize:constrainedSize
                              options:(NSStringDrawingTruncatesLastVisibleLine |
                                       NSStringDrawingUsesLineFragmentOrigin |
                                       NSStringDrawingUsesFontLeading)
                           attributes:@{NSFontAttributeName: font}
                              context:nil].size;
}

- (void)sendTo:(SharedConversation *)conversation {
    __weak typeof(self) ws = self;
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"确认发送给" message:conversation.title preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *action = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [ws doSendTo:conversation];
    }];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    
    [alertController addAction:cancel];
    [alertController addAction:action];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)doSendTo:(SharedConversation *)conversation {
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

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (!self.dataLoaded) {
        return 0;
    }
    if (kFileTransferId.length) {
        return 2;
    }
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    if (indexPath.row == 0) {
        cell.textLabel.text = @"发给朋友";
    } else if (indexPath.row == 1) {
        cell.textLabel.text = @"发给自己";
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row == 0) {
        ConversationListViewController *vc = [[ConversationListViewController alloc] init];
        vc.url = self.url;
        vc.urlThumbnail = self.urlThumbnail;
        vc.urlTitle = self.urlTitle;
        vc.textMessageContent = self.textMessageContent;
        vc.imageUrls = self.imageUrls;
        vc.fullImage = self.fullImage;
        vc.fileUrl = self.fileUrl;
        vc.image = self.image;
        [self.navigationController pushViewController:vc animated:YES];
    } else if (indexPath.row == 1) {
        SharedConversation *conversation = [[SharedConversation alloc] init];
        conversation.type = 0;
        conversation.target = kFileTransferId;
        conversation.line = 0;
        conversation.title = @"自己";
        [self sendTo:conversation];
    }
}

@end
