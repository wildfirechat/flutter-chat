// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'WildFire Chat';

  @override
  String get appTitle => 'WildFire Chat';

  @override
  String get tabChat => 'Chats';

  @override
  String get tabContact => 'Contacts';

  @override
  String get tabWork => 'Work';

  @override
  String get tabDiscovery => 'Discover';

  @override
  String get tabMe => 'Me';

  @override
  String get startChat => 'Start Chat';

  @override
  String get addFriend => 'Add Friend';

  @override
  String get scanQrCode => 'Scan QR Code';

  @override
  String scanResult(Object result) {
    return 'Scan Result: $result';
  }

  @override
  String scanFail(Object error) {
    return 'Scan Failed: $error';
  }

  @override
  String invalidQrCode(Object qrcode) {
    return 'Invalid QR Code: $qrcode';
  }

  @override
  String get pcLoginNotSupport => 'PC Login not supported yet';

  @override
  String get pcLoginQrHint => 'Scan with WildFire Chat mobile app to login';

  @override
  String get retry => 'Retry';

  @override
  String get channelNotSupport => 'Channel not supported yet';

  @override
  String get conferenceNotSupport => 'Conference not supported yet';

  @override
  String get groupInfo => 'Group Info';

  @override
  String get joinGroup => 'Join Group';

  @override
  String get enterGroup => 'Enter Group';

  @override
  String joinFail(Object error) {
    return 'Join Failed: $error';
  }

  @override
  String get groupName => 'Group Name';

  @override
  String get groupQrCode => 'Group QR Code';

  @override
  String get groupNotice => 'Group Notice';

  @override
  String get clickToCheck => 'Click to check';

  @override
  String get groupRemark => 'Group Remark';

  @override
  String get groupManage => 'Manage Group';

  @override
  String get searchChatHistory => 'Search History';

  @override
  String get chatFiles => 'Chat Files';

  @override
  String get muteNotification => 'Mute Notifications';

  @override
  String get stickTop => 'Sticky on Top';

  @override
  String get saveToContact => 'Save to Contacts';

  @override
  String get myAliasInGroup => 'My Alias in Group';

  @override
  String get showMemberName => 'Show Member Name';

  @override
  String get clearChatHistory => 'Clear Chat History';

  @override
  String get transferGroup => 'Transfer Group';

  @override
  String get dismissGroup => 'Dissolve Group';

  @override
  String get quitGroup => 'Quit Group';

  @override
  String get clearLocalHistory => 'Clear Local History';

  @override
  String get clearRemoteHistory => 'Clear Remote History';

  @override
  String get clearLocalHistorySuccess => 'Local history cleared';

  @override
  String get clearRemoteHistorySuccess => 'Remote history cleared';

  @override
  String clearRemoteHistoryFail(Object error) {
    return 'Failed to clear remote history: $error';
  }

  @override
  String get kickMember => 'Remove Member';

  @override
  String get addMember => 'Add Member';

  @override
  String get pickContact => 'Pick Contact';

  @override
  String get networkError => 'Network Error';

  @override
  String get modifyGroupName => 'Modify Group Name';

  @override
  String modifyFail(Object error) {
    return 'Modify Failed: $error';
  }

  @override
  String get onlyOwnerManagerCanModify =>
      'Only owner and manager can modify group name';

  @override
  String get modifyGroupRemark => 'Modify Group Remark';

  @override
  String get modifyGroupAlias => 'Modify Group Alias';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get close => 'Close';

  @override
  String get loginConfirm => 'Login Confirm';

  @override
  String get pcLoginConfirmDesc => 'Windows/Mac Login Confirm';

  @override
  String get login => 'Login';

  @override
  String get cancelLogin => 'Cancel Login';

  @override
  String get loginWithCodeOrPassword => 'Code/Password Login';

  @override
  String get loginCodeTitle => 'Verification Code';

  @override
  String get scanned => 'Scanned, please confirm on your phone';

  @override
  String scannedUser(Object user) {
    return 'Scanned by: $user';
  }

  @override
  String get loggingIn => 'Logging in...';

  @override
  String get scanAgain => 'Scan Again';

  @override
  String pcStatusError(Object status) {
    return 'PC Status Error: $status';
  }

  @override
  String get loginSuccess => 'Login Success';

  @override
  String loginFail(Object error) {
    return 'Login Failed: $error';
  }

  @override
  String get loading => 'Loading...';

  @override
  String get userInfo => 'User Info';

  @override
  String get sendMsg => 'Send Message';

  @override
  String get videoCall => 'Video Call';

  @override
  String get modifyAlias => 'Modify Alias';

  @override
  String get setAlias => 'Set Alias';

  @override
  String get moreInfo => 'More Info';

  @override
  String get methodNotImpl => 'Method not implemented';

  @override
  String get inputAlias => 'Input alias';

  @override
  String get inputNickname => 'Input nickname';

  @override
  String get modifySuccess => 'Modify success';

  @override
  String get setSuccess => 'Set success';

  @override
  String setFail(Object error) {
    return 'Set failed: $error';
  }

  @override
  String get loginPageTitle => 'Login';

  @override
  String get loginWithPhoneNumber => 'Login with Phone Number';

  @override
  String get phoneNumberHint => 'Please enter your phone number';

  @override
  String get superCodeHint => 'Please enter Super code';

  @override
  String get sendCodeSuccess =>
      'Verification code sent successfully. Please verify within 5 minutes!';

  @override
  String get sendCodeFail => 'Failed to send verification code!';

  @override
  String get sendCode => 'Send Code';

  @override
  String get newFriend => 'New Friend';

  @override
  String get favGroup => 'Favorite Groups';

  @override
  String get subscribedChannel => 'Channels';

  @override
  String get organization => 'Organization';

  @override
  String get fileTransfer => 'File Transfer';

  @override
  String get joinChatroomFail => 'Network error! Failed to join chatroom!';

  @override
  String userLeftChatroom(Object userName) {
    return '$userName left the chatroom';
  }

  @override
  String get selectMessage => 'Please select a message';

  @override
  String get deleteMessage => 'Delete Message';

  @override
  String get deleteLocalMessage => 'Delete Local Message';

  @override
  String get deleteRemoteMessage => 'Delete Remote Message';

  @override
  String deleteRemoteMessageFail(Object error) {
    return 'Failed to delete remote message: $error';
  }

  @override
  String get forward => 'Forward';

  @override
  String get forwardOneByOne => 'Forward One by One';

  @override
  String get forwardCombined => 'Forward Combined';

  @override
  String get sendFail => 'Send failed!';

  @override
  String get sent => 'Sent';

  @override
  String get chatHistory => 'Chat History';

  @override
  String get allMembers => 'All';

  @override
  String get messageNotification => 'Message Notification';

  @override
  String get favorites => 'Favorites';

  @override
  String get files => 'Files';

  @override
  String get accountSafety => 'Account Safety';

  @override
  String get settings => 'Settings';

  @override
  String get modifyPortraitSuccess => 'Portrait modified successfully';

  @override
  String modifyPortraitFail(Object error) {
    return 'Failed to modify portrait: $error';
  }

  @override
  String uploadPortraitFail(Object error) {
    return 'Failed to upload portrait: $error';
  }

  @override
  String get takePhoto => 'Take Photo';

  @override
  String get selectFromAlbum => 'Select from Album';

  @override
  String wildfireId(Object id) {
    return 'Wildfire ID: $id';
  }

  @override
  String get backup_and_restore => 'Backup & Restore';

  @override
  String get language => 'Language';

  @override
  String get chinese => '中文';

  @override
  String get english => 'English';

  @override
  String get followSystem => 'Follow System';

  @override
  String get privacySettings => 'Privacy Settings';

  @override
  String get theme => 'Theme';

  @override
  String get currentVersion => 'Current Version';

  @override
  String get feedback => 'Feedback';

  @override
  String get about => 'About Wildfire';

  @override
  String get userAgreement => 'User Agreement';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get complaints => 'Complaints';

  @override
  String get diagnostics => 'Diagnostics';

  @override
  String get logout => 'Logout';

  @override
  String get logoutConfirm => 'Account will logout';

  @override
  String get albumPicker => 'Album';

  @override
  String get emoji => 'Emoji';

  @override
  String get image => 'Image';

  @override
  String get accountLabel => 'ID: ';

  @override
  String get tips => 'Tips';

  @override
  String get gotIt => 'Got it';

  @override
  String get addFriendSearchHint =>
      'Type a keyword in the search box at the top left to find users and add them as friends';

  @override
  String get friendRequestAccept => 'Accept';

  @override
  String get friendRequestAccepted => 'Accepted';

  @override
  String get friendRequestRejected => 'Rejected';

  @override
  String get enterToSendHint => 'Enter to send, Shift + Enter for new line';

  @override
  String get cameraCapture => 'Take Photo';

  @override
  String get voiceCall => 'Call';

  @override
  String get location => 'Location';

  @override
  String get filePicker => 'File';

  @override
  String get businessCard => 'Card';

  @override
  String get screenshotTool => 'Screenshot';

  @override
  String get screenshotToolNotAvailable => 'Screenshot tool unavailable';

  @override
  String get notSupportedOnCurrentPlatform =>
      'Not supported on current platform';

  @override
  String get notSupported => 'Not supported';

  @override
  String get singleConversationDetails => 'Single Conversation Details';

  @override
  String get searchChatContents => 'Search Chat Contents';

  @override
  String get clearLocalMessages => 'Clear Local Messages';

  @override
  String get clearRemoteMessages => 'Clear Remote Messages';

  @override
  String get clearLocalMessagesSuccess => 'Local messages cleared successfully';

  @override
  String get clearRemoteMessagesSuccess =>
      'Remote messages cleared successfully';

  @override
  String clearRemoteMessagesFailed(Object error) {
    return 'Failed to clear remote messages: $error';
  }

  @override
  String get groupConversationDetails => 'Group Conversation Details';

  @override
  String get groupMemberList => 'Member List';

  @override
  String get groupNameLabel => 'Group Name';

  @override
  String get groupAnnouncement => 'Group Announcement';

  @override
  String get groupRemarkLabel => 'Group Remark';

  @override
  String get groupManagement => 'Group Management';

  @override
  String get favoriteGroup => 'Save to Contacts';

  @override
  String get myAliasInGroupLabel => 'My Alias in Group';

  @override
  String get showGroupMemberNames => 'Show Group Member Names';

  @override
  String get quitGroupChat => 'Quit Group';

  @override
  String get removeGroupMembers => 'Remove Group Members';

  @override
  String get addGroupMembers => 'Add Group Members';

  @override
  String get selectContacts => 'Select Contacts';

  @override
  String get modifyGroupNameDialog => 'Modify Group Name';

  @override
  String get modifyGroupRemarkDialog => 'Modify Group Remark';

  @override
  String get modifyGroupAliasDialog => 'Modify Group Alias';

  @override
  String get channelDetails => 'Channel Details';

  @override
  String get unsubscribeChannel => 'Unsubscribe';

  @override
  String modifyFailedWithCode(Object code) {
    return 'Modification failed: $code';
  }

  @override
  String get chatroom => 'Chatroom';

  @override
  String get robot => 'Robot';

  @override
  String get channels => 'Channels';

  @override
  String get developmentDocumentation => 'Development Documentation';

  @override
  String get sendTo => 'Send to:';

  @override
  String get leaveMessage => 'Leave a message';

  @override
  String get send => 'Send';

  @override
  String totalMessages(Object count) {
    return 'Total $count messages';
  }

  @override
  String get messageTag => '[Message]';

  @override
  String get open => 'Open';

  @override
  String get exit => 'Exit';

  @override
  String get unsubscribeChannelSuccess => 'Unsubscribe successfully';

  @override
  String get pickRemindUser => 'Pick user to remind';

  @override
  String get slideUpToCancel => 'Slide up to cancel';

  @override
  String get releaseToSend => 'Release to send';

  @override
  String get holdToTalk => 'Hold to Talk';

  @override
  String get noMicrophonePermission =>
      'No permission, please enable microphone access!';

  @override
  String recordFailed(Object error) {
    return 'Recording failed: $error';
  }

  @override
  String get recordTooShort => 'Recording too short';

  @override
  String get releaseToCancel => 'Release to cancel';

  @override
  String get wfcNotificationTitle => 'WildfireChat Notification';

  @override
  String get wfcNotificationDesc => 'WildfireChat Message Notification';

  @override
  String get newMessage => 'New Message';

  @override
  String get groupChat => 'Group Chat';

  @override
  String get channelNewMessage => 'Channel Message';

  @override
  String get andOthers => ' and others';

  @override
  String get requestAddFriend => ' requested to add you as friend';

  @override
  String get friendRequest => 'Friend Request';

  @override
  String get kickedOffline => 'Kicked offline';

  @override
  String operateFail(Object error) {
    return 'Operation failed: $error';
  }

  @override
  String get pcClient => 'PC Client';

  @override
  String get webClient => 'Web Client';

  @override
  String get miniProgram => 'Mini Program';

  @override
  String get unknownDevice => 'Unknown Device';

  @override
  String get pcOnlineDevices => 'PC Online Devices';

  @override
  String get noPcOnline => 'No other devices logged in';

  @override
  String pcOnlineDeviceCount(Object count) {
    return '$count devices logged in';
  }

  @override
  String get mobileMute => 'Mute Mobile';

  @override
  String get mobileMuteDesc => 'Mute mobile notifications when PC is online';

  @override
  String get loginTime => 'Login Time: ';

  @override
  String get backupConversations => 'Backing up conversations...';

  @override
  String get creatingLocalBackup => 'Creating local backup...';

  @override
  String get uploadingToPC => 'Uploading to PC...';

  @override
  String get restoringConversations => 'Restoring conversations...';

  @override
  String get downloadingFiles => 'Downloading files...';

  @override
  String backupFailed(Object error) {
    return 'Backup failed: $error';
  }

  @override
  String get passwordRequired => 'Password required';

  @override
  String restoreFailed(Object error) {
    return 'Restore failed: $error';
  }

  @override
  String get notLoggedIn => 'Not logged in';

  @override
  String get pcResponseTimeout => 'Timeout waiting for PC response';

  @override
  String fetchBackupListFailed(Object error) {
    return 'Failed to fetch backup list: $error';
  }

  @override
  String get createLocalBackupFailed => 'Failed to create local backup';

  @override
  String uploadFailed(Object error) {
    return 'Upload failed: $error';
  }

  @override
  String getMetadataFailed(Object error) {
    return 'Failed to get metadata $error';
  }

  @override
  String get invalidMetadata => 'Invalid metadata';

  @override
  String get passwordRequiredForEncrypted =>
      'Password required for encrypted backup';

  @override
  String get aiRobot => 'AI Robot';

  @override
  String get audioCallAction => 'Audio Call';

  @override
  String get videoCallAction => 'Video Call';

  @override
  String get pickGroupMember => 'Select Group Member';

  @override
  String get selectMemberToCall => 'Please select one or more members to call';

  @override
  String get callInProgress => 'Call in progress, cannot start new call!';

  @override
  String get cannotOpen => 'Cannot open';

  @override
  String get copy => 'Copy';

  @override
  String get delete => 'Delete';

  @override
  String get speechToText => 'Speech to Text';

  @override
  String get recall => 'Recall';

  @override
  String get reedit => 'Re-edit';

  @override
  String get recalledMessageNoContent =>
      'The original message content is no longer available';

  @override
  String get multiSelect => 'Multi Select';

  @override
  String get quote => 'Quote';

  @override
  String get favoriteAction => 'Favorite';

  @override
  String get favoriteSuccess => 'Favorite success';

  @override
  String favoriteFail(Object error) {
    return 'Favorite failed: $error';
  }

  @override
  String get audioFileNotAvailable => 'Audio file not available';

  @override
  String get convertFail => 'Convert failed';

  @override
  String get speechToTextFail => 'Speech to text failed';

  @override
  String get speechToTextSuccess => 'Speech to text success';

  @override
  String speechToTextError(Object error) {
    return 'Speech to text error: $error';
  }

  @override
  String get convertingToText => 'Converting...';

  @override
  String get inviteReasonHint => 'Please enter reason, wait for approval';

  @override
  String get inputReason => 'Please enter reason';

  @override
  String get requestSent => 'Request sent!';

  @override
  String networkErrorWithCode(Object code) {
    return 'Network error: $code';
  }

  @override
  String get messageNotExist => 'Message does not exist';

  @override
  String get loginWithPassword => 'Password Login';

  @override
  String get loginWithPhone => 'Phone Login';

  @override
  String get inputPassword => 'Password';

  @override
  String get inputVerificationCode => 'Verification Code';

  @override
  String get readAndAgree => 'I agree to ';

  @override
  String get and => ' and ';

  @override
  String get agreePolicyFirst => 'Please agree to Policy first';

  @override
  String get loginWithPhoneCode => 'Code Login';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get monthDayFormat => 'MM/dd';

  @override
  String get yearMonthDayFormat => 'yyyy/MM/dd';

  @override
  String singleChat(Object target) {
    return 'Chat <$target>';
  }

  @override
  String groupChatWithTarget(Object target) {
    return 'Group <$target>';
  }

  @override
  String channelWithTarget(Object target) {
    return 'Channel <$target>';
  }

  @override
  String chatroomWithTarget(Object target) {
    return 'Chatroom <$target>';
  }

  @override
  String get cannotOpenLink => 'Cannot open link';

  @override
  String get pickMultipleChats => 'Select Multiple Chats';

  @override
  String get pickOneChat => 'Select a Chat';

  @override
  String get singleSelect => 'Single Select';

  @override
  String get search => 'Search';

  @override
  String get recentChats => 'Recent Chats';

  @override
  String get contacts => 'Contacts';

  @override
  String get friends => 'Friends';

  @override
  String get groups => 'Groups';

  @override
  String get noSearchResult => 'No result found';

  @override
  String selectedChatsCount(Object count) {
    return 'Selected $count chats';
  }

  @override
  String sendWithCount(Object count) {
    return 'Send($count)';
  }

  @override
  String get connecting => 'Connecting...';

  @override
  String get connectionFailed => 'Connection Failed';

  @override
  String pcLoggedIn(Object status) {
    return '$status logged in';
  }

  @override
  String get deleteConversation => 'Delete Conversation';

  @override
  String get untop => 'Unpin';

  @override
  String get top => 'Pin';

  @override
  String get clearUnread => 'Clear Unread';

  @override
  String get setUnread => 'Mark as Unread';

  @override
  String get draftTag => '[Draft]';

  @override
  String get user => 'User';

  @override
  String get contact => 'Contact';

  @override
  String get group => 'Group';

  @override
  String get channel => 'Channel';

  @override
  String get others => 'Others';

  @override
  String matchedMessageCount(Object count) {
    return '$count messages';
  }

  @override
  String get noFiles => 'No files';

  @override
  String get unknownFile => 'Unknown File';

  @override
  String get deleteSuccess => 'Delete success';

  @override
  String get deleteFailed => 'Delete failed';

  @override
  String get imageTag => '[Image]';

  @override
  String get videoTag => '[Video]';

  @override
  String get voiceTag => '[Voice]';

  @override
  String get chatHistoryTag => '[Chat History]';

  @override
  String get fileTag => '[File]';

  @override
  String get linkTag => '[Link]';

  @override
  String get deleteFavorite => 'Delete Favorite';

  @override
  String get deleteFavoriteConfirm => 'Are you sure to delete this favorite?';

  @override
  String get myFavorites => 'My Favorites';

  @override
  String get noFavorites => 'No favorites';

  @override
  String get fileLabel => 'File: ';

  @override
  String get linkLabel => 'Link: ';

  @override
  String get favoritesAll => 'All';

  @override
  String get favoritesFile => 'File';

  @override
  String get favoritesMedia => 'Media';

  @override
  String get favoritesComposite => 'Chat History';

  @override
  String get unsupportedMessageType => 'Unsupported message type';

  @override
  String get fileRecords => 'File Records';

  @override
  String get allFiles => 'All Files';

  @override
  String get myFiles => 'My Files';

  @override
  String get userFiles => 'User Files';

  @override
  String get searchHint => 'Type to search';

  @override
  String get searchPrompt => 'Enter content to search';

  @override
  String get readReceiptDetail => 'Read Receipt Detail';

  @override
  String readCount(Object count) {
    return 'Read ($count)';
  }

  @override
  String unreadCount(Object count) {
    return 'Unread ($count)';
  }

  @override
  String get success => 'Success';

  @override
  String get failed => 'Failed';

  @override
  String get addToBlacklist => 'Add to Blacklist';

  @override
  String get removeFromBlacklist => 'Remove from Blacklist';

  @override
  String get deleteFriend => 'Delete Friend';

  @override
  String get deleteFriendConfirm =>
      'Deleting a friend will also delete the chat history with that friend.';

  @override
  String get setStarredFriend => 'Set as Starred Friend';

  @override
  String get cancelStarredFriend => 'Cancel Starred Friend';

  @override
  String get friendRequestSent => 'Friend Request Sent';

  @override
  String get viewAllFriendRequests => 'View All Friend Requests';

  @override
  String get remark => 'Remark';

  @override
  String get favFriend => 'Starred Friends';

  @override
  String get contactCategory => 'Contacts';

  @override
  String get starredContact => 'Starred Contacts';

  @override
  String doneWithCount(Object count) {
    return 'Done($count)';
  }

  @override
  String get maxUserLimit => 'Max user limit reached';

  @override
  String get selectFromOrganization => 'Select from Organization';

  @override
  String pickedCount(Object count) {
    return 'Selected: $count';
  }

  @override
  String get pickContactHint => 'Pick contacts on the left';

  @override
  String get collection => 'Collection';

  @override
  String get createCollection => 'Create Collection';

  @override
  String get collectionTitle => 'Title';

  @override
  String get collectionTitleHint => 'Enter collection title';

  @override
  String get collectionDesc => 'Description';

  @override
  String get collectionDescHint => 'Enter description (optional)';

  @override
  String get collectionTemplate => 'Template';

  @override
  String get collectionTemplateLabel => 'Template: ';

  @override
  String get collectionTemplateHint => 'Set a template for participants';

  @override
  String get collectionTemplateExample => 'e.g. Name-Phone';

  @override
  String get expireSetting => 'Expiration';

  @override
  String get noExpire => 'No expiration';

  @override
  String get setExpire => 'Set expiration';

  @override
  String get expireDate => 'Date';

  @override
  String get expireTime => 'Time';

  @override
  String get pleaseSelect => 'Select';

  @override
  String get expireTimeInvalid => 'Expiration time must be in the future';

  @override
  String get collectionTag => 'Collection';

  @override
  String get collectionPeopleCount => ' participants';

  @override
  String get collectionStatusActive => 'Active';

  @override
  String get collectionStatusEnded => 'Ended';

  @override
  String get collectionStatusCancelled => 'Cancelled';

  @override
  String get collectionJoinAction => 'Join Collection';

  @override
  String get collectionEmptyHint => 'No participants yet, be the first!';

  @override
  String collectionMoreParticipants(Object count) {
    return 'and $count others';
  }

  @override
  String get collectionClickToView => 'Tap to view';

  @override
  String get collectionDetail => 'Collection Detail';

  @override
  String get collectionCreator => 'Creator';

  @override
  String get collectionCreatorSuffix => 'created this collection';

  @override
  String get collectionJoinHint => 'Enter your response';

  @override
  String get submit => 'Submit';

  @override
  String get done => 'Done';

  @override
  String get confirmDeleteEntry => 'Delete your entry?';

  @override
  String get collectionServiceNotConfigured =>
      'Collection service not configured';

  @override
  String get collectionLoadFailed => 'Failed to load collection';

  @override
  String get collectionJoinSuccess => 'Joined successfully';

  @override
  String get collectionJoinFailed => 'Failed to join';

  @override
  String get collectionUpdateSuccess => 'Updated successfully';

  @override
  String get collectionUpdateFailed => 'Failed to update';

  @override
  String get collectionDeleteSuccess => 'Deleted successfully';

  @override
  String get collectionNotInGroup => 'You are not in this group';

  @override
  String get collectionCreateSuccess => 'Collection created';

  @override
  String get collectionCreateFailed => 'Failed to create collection';

  @override
  String get collectionEndTime => 'End Time';

  @override
  String get collectionNoEndTime => 'No deadline';

  @override
  String get poll => 'Poll';

  @override
  String get createPoll => 'Create Poll';

  @override
  String get createPollSubtitle => 'Create a new group poll';

  @override
  String get myPollsSubtitle => 'View my polls';

  @override
  String get pollEmptyList => 'No polls yet';

  @override
  String get pollHasVoted => 'Voted';

  @override
  String get pollDeleteConfirm => 'Are you sure to delete this poll?';

  @override
  String get myPolls => 'My Polls';

  @override
  String get pollTitleHint => 'Enter poll title';

  @override
  String get pollDescHint => 'Enter description (optional)';

  @override
  String get pollOption => 'Option';

  @override
  String get pollAddOption => 'Add option';

  @override
  String get pollType => 'Poll type';

  @override
  String get pollSingleChoice => 'Single choice';

  @override
  String get pollMultiChoice => 'Multiple choice';

  @override
  String get pollMaxSelect => 'Max selections';

  @override
  String get pollOptions => 'options';

  @override
  String get pollAnonymousVote => 'Anonymous vote';

  @override
  String get pollAnonymous => 'Anonymous';

  @override
  String get pollShowResult => 'Always show results';

  @override
  String get pollEndTime => 'End time';

  @override
  String get pollNoEndTime => 'No end time';

  @override
  String pollMaxOptionsLimit(Object count) {
    return 'Maximum $count options allowed';
  }

  @override
  String pollMinOptionsRequired(Object count) {
    return 'At least $count options required';
  }

  @override
  String get pollSelectOption => 'Please select at least one option';

  @override
  String get pollSubmitVote => 'Submit vote';

  @override
  String get pollVotesCount => 'votes';

  @override
  String get pollPeopleCount => ' participants';

  @override
  String get pollStatusActive => 'Active';

  @override
  String get pollStatusEnded => 'Ended';

  @override
  String get pollStatusCancelled => 'Cancelled';

  @override
  String get pollJoinAction => 'Vote now';

  @override
  String get pollViewResult => 'View results';

  @override
  String get pollCreatorSuffix => 'created this poll';

  @override
  String get pollTotalVotes => 'Total votes';

  @override
  String get pollVotes => 'votes';

  @override
  String get pollDetail => 'Poll Detail';

  @override
  String get pollLoadFailed => 'Failed to load poll';

  @override
  String get pollServiceNotConfigured => 'Poll service not configured';

  @override
  String get pollVoteSuccess => 'Vote submitted';

  @override
  String get pollVoteFailed => 'Failed to vote';

  @override
  String get pollCloseConfirm =>
      'Are you sure to close this poll? No more votes will be accepted.';

  @override
  String get pollCloseSuccess => 'Poll closed';

  @override
  String get pollCloseFailed => 'Failed to close poll';

  @override
  String get pollCreateSuccess => 'Poll created';

  @override
  String get pollCreateFailed => 'Failed to create poll';

  @override
  String pollMaxSelectLimit(Object count) {
    return 'Maximum $count options can be selected';
  }

  @override
  String get pollClose => 'Close Poll';

  @override
  String get pollDelete => 'Delete Poll';

  @override
  String get pollExport => 'Export Details';

  @override
  String get pollNamed => 'Named';

  @override
  String pollVoterCount(Object count) {
    return '$count participants';
  }

  @override
  String get pollAlreadyVoted => 'Voted';

  @override
  String get pollOptionsTitle => 'Options';

  @override
  String pollSelectedCount(Object count, Object max) {
    return 'Selected $count/$max';
  }

  @override
  String get pollDeleteSuccess => 'Poll deleted';

  @override
  String get pollDeleteFailed => 'Failed to delete poll';

  @override
  String get pollExportFailed => 'Export failed';

  @override
  String get pollNoVoterDetails => 'No voter details';

  @override
  String get pollShareDetails => 'Poll details';

  @override
  String get pollCsvOption => 'Option';

  @override
  String get pollCsvUser => 'User';

  @override
  String get pollCsvTime => 'Time';

  @override
  String get pollDetailsSuffix => 'details';

  @override
  String get pollDefaultFileName => 'poll';

  @override
  String pollCreatorFormat(Object creatorName) {
    return 'Created by $creatorName';
  }

  @override
  String pollDaysLeft(Object count) {
    return '$count days left';
  }

  @override
  String pollHoursLeft(Object count) {
    return '$count hours left';
  }

  @override
  String pollMinutesLeft(Object count) {
    return '$count minutes left';
  }

  @override
  String get pollNoDeadline => 'No deadline';

  @override
  String get publish => 'Publish';

  @override
  String get pickFriendsToStartChat =>
      'Select one or more friends to start a chat';

  @override
  String get creatingGroup => 'Creating group...';

  @override
  String get createGroupChat => 'Create Group Chat';

  @override
  String get createAndSend => 'Create and Send';

  @override
  String get forwardSendSeparately => 'Send separately to';

  @override
  String get forwardSendMerged => 'Send merged to';

  @override
  String get pickTargetsFromLeft => 'Select a contact or group on the left';

  @override
  String selectedContactsCount(Object count) {
    return '$count contacts selected';
  }

  @override
  String get pickContactsToCreateGroup => 'Select group members';

  @override
  String createGroupFail(Object error) {
    return 'Failed to create: $error';
  }

  @override
  String groupNameEtc(Object names) {
    return '$names etc.';
  }

  @override
  String get audioVideoCall => 'Voice & Video Call';

  @override
  String get callOngoingClickRestore => 'Ongoing call - click to restore';

  @override
  String get sendFile => 'Send File';

  @override
  String confirmSendFile(Object fileName) {
    return 'Send \"$fileName\"?';
  }

  @override
  String get desktopOnly => 'This page is only available on desktop';

  @override
  String sendCodeFailWithError(Object error) {
    return 'Failed to send verification code: $error';
  }

  @override
  String get showWindow => 'Show Window';

  @override
  String trayUnreadTooltip(Object count) {
    return 'WildFire IM: $count unread messages';
  }

  @override
  String get previousImage => 'Previous (←)';

  @override
  String get nextImage => 'Next (→)';

  @override
  String get rotateLeft => 'Rotate left';

  @override
  String get rotateRight => 'Rotate right';

  @override
  String get saveAs => 'Save as...';

  @override
  String get saveFile => 'Save file';

  @override
  String get saveSuccess => 'Saved';

  @override
  String get saveFailSourceMissing =>
      'Save failed: source file or URL not found';

  @override
  String saveFail(Object error) {
    return 'Save failed: $error';
  }

  @override
  String get callStatusEnded => 'Call ended';

  @override
  String get callStatusCalling => 'Calling...';

  @override
  String get callIncomingInvite => 'invites you to a call';

  @override
  String get callStatusConnecting => 'Connecting...';

  @override
  String get callDecline => 'Decline';

  @override
  String get callAnswer => 'Answer';

  @override
  String get callAnswerAudio => 'Audio';

  @override
  String get callAnswerVideo => 'Video';

  @override
  String get callMute => 'Mute';

  @override
  String get callHangup => 'Hang Up';

  @override
  String get callSwitchCamera => 'Flip';

  @override
  String get callSpeaker => 'Speaker';

  @override
  String get callCameraOn => 'Camera On';

  @override
  String get callCameraOff => 'Camera Off';

  @override
  String get openFile => 'Open File';

  @override
  String get deleteFileRecordConfirm =>
      'Are you sure to delete this file record?';

  @override
  String get fileRecordDeleted => 'File record deleted';

  @override
  String get deleteFileRecordFailed => 'Failed to delete file record';

  @override
  String get searchFiles => 'Search Files';

  @override
  String get fontSize => 'Font Size';

  @override
  String get fontSizeSmall => 'Small';

  @override
  String get fontSizeNormal => 'Standard';

  @override
  String get fontSizeMedium => 'Medium';

  @override
  String get fontSizeLarge => 'Large';

  @override
  String get fontSizeExtraLarge => 'Extra Large';

  @override
  String get fontSizePreviewIncoming => 'Preview font size';

  @override
  String get fontSizePreviewOutgoing =>
      'Drag the slider below to set the font size';

  @override
  String get fontSizePreviewHint =>
      'Messages, contact lists and more will be displayed at this size.';
}
