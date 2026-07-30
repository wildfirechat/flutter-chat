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
  String get appTagline => 'Communication made simple!';

  @override
  String departmentFallback(Object id) {
    return 'Department $id';
  }

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
  String get conferenceTitle => 'Meeting';

  @override
  String get conferenceCreate => 'Create Meeting';

  @override
  String get conferenceJoin => 'Join Meeting';

  @override
  String get conferenceOrder => 'Schedule Meeting';

  @override
  String get conferenceMemberList => 'Participants';

  @override
  String get conferenceHandUp => 'Raise Hand';

  @override
  String get conferenceHandUpDone => 'Hand Raised';

  @override
  String conferenceHandUpMembersCount(Object count) {
    return 'Raised Hands ($count)';
  }

  @override
  String get conferenceNoHandUpMembers => 'No one has raised their hand';

  @override
  String get conferencePutDown => 'Lower Hand';

  @override
  String get conferencePutDownAll => 'Lower All Hands';

  @override
  String get conferenceApplyAudio => 'Unmute Requests';

  @override
  String get conferenceApplyVideo => 'Camera Requests';

  @override
  String conferenceApplyAudioCount(Object count) {
    return 'Unmute Requests ($count)';
  }

  @override
  String conferenceApplyVideoCount(Object count) {
    return 'Camera Requests ($count)';
  }

  @override
  String get conferenceNoApplications => 'No requests';

  @override
  String get conferenceApprove => 'Approve';

  @override
  String get conferenceReject => 'Reject';

  @override
  String get conferenceApproveAll => 'Approve All';

  @override
  String get conferenceRejectAll => 'Reject All';

  @override
  String get conferenceMuteAll => 'Mute All';

  @override
  String get conferenceUnmuteAll => 'Unmute All';

  @override
  String get conferenceFocus => 'Focus';

  @override
  String get conferenceSetFocus => 'Set as Focus';

  @override
  String get conferenceCancelFocus => 'Remove Focus';

  @override
  String get conferenceAudience => 'Audience';

  @override
  String get conferenceInviteStage => 'Invite to Speak';

  @override
  String get conferenceSetAudience => 'Move to Audience';

  @override
  String get conferenceKick => 'Remove from Meeting';

  @override
  String get conferenceHandUpMembersTitle => 'Raised Hands';

  @override
  String get conferenceUnmuteSelf => 'Unmute';

  @override
  String get conferenceSwitchToStage => 'Join Stage';

  @override
  String get conferenceSwitchToAudience => 'Leave Stage';

  @override
  String get conferenceAllowUnmuteAudio => 'Allow Unmute';

  @override
  String get conferenceAllowUnmuteVideo => 'Allow Video';

  @override
  String get conferenceCloseVideo => 'Turn Off Video';

  @override
  String conferenceHandUpTip(Object count) {
    return '$count raised their hand, tap to view';
  }

  @override
  String conferenceApplyAudioTip(Object count) {
    return '$count requested to unmute, tap to view';
  }

  @override
  String conferenceApplyVideoTip(Object count) {
    return '$count requested camera access, tap to view';
  }

  @override
  String get conferenceScreenShare => 'Share';

  @override
  String get conferenceSharingScreen => 'Sharing screen';

  @override
  String get conferenceStopSharing => 'Stop Sharing';

  @override
  String get conferenceScreenShareNotImplemented =>
      'Screen sharing is not implemented yet';

  @override
  String get conferenceInviteJoin => 'Invites you to join the meeting';

  @override
  String get conferenceHostInviteAudience =>
      'The host invites you to become an audience member';

  @override
  String get conferenceHostInviteStage =>
      'The host invites you to join the stage';

  @override
  String get conferenceIgnore => 'Ignore';

  @override
  String conferenceSpeakingLabel(Object name) {
    return 'Speaking: $name';
  }

  @override
  String get conferenceGridView => 'Grid View';

  @override
  String get conferenceSpeakerView => 'Speaker View';

  @override
  String get conferenceLayout => 'Layout';

  @override
  String get conferencePrevPage => 'Previous';

  @override
  String get conferenceNextPage => 'Next';

  @override
  String get conferenceJoinMeeting => 'Join Meeting';

  @override
  String get conferenceMeetingEnded => 'Meeting Ended';

  @override
  String get conferenceStatusNotStarted => 'Not Started';

  @override
  String get conferenceStatusOngoing => 'In Progress';

  @override
  String get conferenceStatusEnded => 'Ended';

  @override
  String get conferenceVideoConferenceTitle => 'Video Conference';

  @override
  String get conferenceJoinHint => 'Enter a meeting ID to join';

  @override
  String get conferenceCreateTitle => 'Start a Meeting';

  @override
  String get conferenceCreateHint => 'Start an audio/video meeting instantly';

  @override
  String get conferenceOrderHint => 'Schedule a future meeting';

  @override
  String conferenceDurationHours(Object h, Object m) {
    return '${h}h ${m}m';
  }

  @override
  String conferenceDurationMinutes(Object m, Object s) {
    return '${m}m ${s}s';
  }

  @override
  String conferenceDurationSeconds(Object s) {
    return '${s}s';
  }

  @override
  String get conferenceFavorites => 'Upcoming';

  @override
  String get conferenceHistory => 'History';

  @override
  String get conferenceNoFavorites => 'No favorite meetings';

  @override
  String get conferenceNoHistory => 'No meeting history';

  @override
  String get conferenceStartTime => 'Start Time';

  @override
  String get conferenceEndTime => 'End Time';

  @override
  String get conferenceEnableMic => 'Enable Microphone';

  @override
  String get conferenceEnableCamera => 'Enable Camera';

  @override
  String get conferenceFav => 'Favorite Meeting';

  @override
  String get conferenceDestroy => 'End Meeting';

  @override
  String get conferenceDestroyConfirm =>
      'Once ended, other participants will not be able to join. End this meeting?';

  @override
  String get conferenceCopied => 'Meeting ID copied';

  @override
  String get conferenceUntitled => 'Untitled Meeting';

  @override
  String conferenceOwnerLabel(Object name) {
    return 'Host: $name';
  }

  @override
  String get conferenceIdLabel => 'Meeting ID';

  @override
  String get conferenceDestroyAction => 'Destroy';

  @override
  String conferenceDestroyFailed(Object error) {
    return 'Failed to destroy meeting: $error';
  }

  @override
  String get conferenceRequestUnmuteAudio => 'Request to Unmute';

  @override
  String get conferenceRequestUnmuteVideo => 'Request to Turn On Camera';

  @override
  String get conferenceRequestUnmuteAudioDesc =>
      'The host has muted everyone. You can ask the host to unmute you.';

  @override
  String get conferenceRequestUnmuteVideoDesc =>
      'The host does not allow cameras. You can ask the host to turn on your camera.';

  @override
  String get conferenceHostFocusSet => 'The host has set a focus user';

  @override
  String get conferenceCreated => 'Meeting created';

  @override
  String get conferenceCreateFailed => 'Failed to create meeting';

  @override
  String conferenceCreateFailedWithError(Object error) {
    return 'Failed to create meeting: $error';
  }

  @override
  String get conferenceJoinFailed => 'Failed to join meeting';

  @override
  String conferenceJoinFailedWithError(Object error) {
    return 'Failed to join meeting: $error';
  }

  @override
  String get conferenceTitleLabel => 'Meeting Title';

  @override
  String get conferenceDescLabel => 'Meeting Description';

  @override
  String get conferenceOrdered => 'Meeting scheduled';

  @override
  String get conferenceOrderFailed => 'Failed to schedule meeting';

  @override
  String conferenceOrderFailedWithError(Object error) {
    return 'Failed to schedule meeting: $error';
  }

  @override
  String get conferenceOrderAction => 'Schedule';

  @override
  String get conferenceSelectStartAndEndTime =>
      'Please select a start and end time';

  @override
  String get conferenceInputTitle => 'Enter meeting title';

  @override
  String get conferenceOnlyCreate => 'Create Only';

  @override
  String get conferenceCreateAndJoin => 'Create and Join';

  @override
  String get conferenceAudioOnly => 'Audio Only';

  @override
  String get conferenceDefaultAudience => 'Join as Audience';

  @override
  String get conferenceAdvanced => 'Advanced Version';

  @override
  String get conferenceRecord => 'Record';

  @override
  String get conferenceAllowTurnOnMic => 'Allow members to unmute themselves';

  @override
  String get conferenceEnablePassword => 'Enable Password';

  @override
  String get conferencePassword => 'Meeting Password';

  @override
  String get conferenceIdInputLabel => 'Meeting ID';

  @override
  String get conferenceQuery => 'Find Meeting';

  @override
  String conferenceQueryFailedWithError(Object error) {
    return 'Failed to find meeting: $error';
  }

  @override
  String get conferenceEndTimeInvalid => 'End time cannot be earlier than now';

  @override
  String get conferenceTimeInvalid =>
      'End time cannot be earlier than start time';

  @override
  String get conferenceSelectStartTime => 'Select start time';

  @override
  String get conferenceSelectEndTime => 'Select end time';

  @override
  String get groupInfo => 'Group Info';

  @override
  String get joinGroup => 'Join Group';

  @override
  String get enterGroup => 'Enter Group';

  @override
  String get removeFromContacts => 'Remove from Contacts';

  @override
  String get removeFromContactsConfirm =>
      'This group chat will no longer be saved to your contacts after removal.';

  @override
  String joinFail(Object error) {
    return 'Join Failed: $error';
  }

  @override
  String get groupName => 'Group Name';

  @override
  String get groupQrCode => 'Group QR Code';

  @override
  String get scanQrCodeToJoinGroup =>
      'Scan the QR code above to join the group';

  @override
  String get groupNotice => 'Group Notice';

  @override
  String moreArticlesCount(Object count) {
    return '$count more articles';
  }

  @override
  String get articlesPlaceholder => '[Articles]';

  @override
  String get openWithSystemPlayer => 'Tap to open with the system player';

  @override
  String get edit => 'Edit';

  @override
  String getGroupAnnouncementFailed(Object msg) {
    return 'Failed to get group announcement: $msg';
  }

  @override
  String get groupAnnouncementEmpty => 'Group announcement cannot be empty';

  @override
  String get updateGroupAnnouncementSuccess => 'Group announcement updated';

  @override
  String updateGroupAnnouncementFailed(Object msg) {
    return 'Failed to update group announcement: $msg';
  }

  @override
  String get noGroupAnnouncementHint => 'No group announcement';

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
  String get searchByDate => 'Date';

  @override
  String get searchMedia => 'Photos & Videos';

  @override
  String get searchHistoryTitle => 'Search History';

  @override
  String get clearAll => 'Clear';

  @override
  String get tabAll => 'All';

  @override
  String get chatRecords => 'Chat History';

  @override
  String get locateToChatPosition => 'Locate in Chat';

  @override
  String get backToLatest => 'Back to Latest';

  @override
  String backToLatestWithCount(String count) {
    return '$count new messages';
  }

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
  String groupActionSuccess(Object action) {
    return '$action succeeded';
  }

  @override
  String groupActionFailedWithCode(Object action, Object code) {
    return '$action failed: $code';
  }

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
  String get loginWithQrCode => 'Scan to Login';

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
  String get nickname => 'Nickname';

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
  String get mesh => 'External';

  @override
  String get domainInfo => 'Organization Info';

  @override
  String get domainName => 'Name';

  @override
  String get domainDesc => 'Description';

  @override
  String get domainEmail => 'Email';

  @override
  String get domainTel => 'Phone';

  @override
  String get domainAddress => 'Address';

  @override
  String get searchUserFieldHint => 'Enter phone number or account';

  @override
  String get searchUserAddFriendHint => 'Search for a user to add as a friend!';

  @override
  String get searchUserNotFound =>
      'No user found. Please check the phone number or account.';

  @override
  String get searchInCurrentDomain => 'Search users in current organization';

  @override
  String get searchUserInDomain => 'Find users in this organization';

  @override
  String loadDomainFail(Object error) {
    return 'Failed to load external organization: $error';
  }

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
  String get reportTitle => 'Report';

  @override
  String get momentPermission => 'Moments Permission';

  @override
  String get momentPermissionDesc => 'Set the default visibility of your posts';

  @override
  String get reportDesc => 'Report inappropriate content';

  @override
  String get reportMessage =>
      'If you find any content that violates laws and morality, or your legitimate rights and interests have been infringed, please take a screenshot and send it to us. We will handle it within 24 hours. Actions include but are not limited to deleting content, warning the author, freezing the account, and even calling the police.';

  @override
  String get destroyAccount => 'Delete Account';

  @override
  String get destroyAccountTitle => 'Do you really want to leave us😭😭😭!';

  @override
  String destroyAccountFail(Object error) {
    return 'Failed to delete account: $error';
  }

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
  String get personalCardHint => 'Contact Card';

  @override
  String get groupCardHint => 'Group Card';

  @override
  String get channelCardHint => 'Channel Card';

  @override
  String get screenshotTool => 'Screenshot';

  @override
  String get screenshotHideWindow => 'Screenshot (hide window)';

  @override
  String get screenshotToolNotAvailable => 'Screenshot tool unavailable';

  @override
  String screenshotFailed(Object err) {
    return 'Screenshot failed: $err';
  }

  @override
  String screenshotToolLaunchFailed(Object err) {
    return 'Failed to launch the screenshot tool: $err';
  }

  @override
  String screenshotException(Object err) {
    return 'Screenshot error: $err';
  }

  @override
  String get notSupportedOnCurrentPlatform =>
      'Not supported on current platform';

  @override
  String get notSupported => 'Not supported';

  @override
  String get channelMenu => 'Channel Menu';

  @override
  String get switchToTextInput => 'Switch to text input';

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
  String get collapseGroupMembers => 'Collapse Members <';

  @override
  String get viewMoreGroupMembers => 'View More Members >';

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
  String get channelNotExist => 'Channel not found';

  @override
  String get channelIntro => 'Introduction';

  @override
  String get channelOwner => 'Owner';

  @override
  String get noIntro => 'No introduction';

  @override
  String get enterConversation => 'Enter Chat';

  @override
  String get subscribeChannel => 'Subscribe';

  @override
  String get subscribedChannelsTitle => 'Subscribed Channels';

  @override
  String get searchChannelHint => 'Enter channel name';

  @override
  String get searchChannelNotFound =>
      'No channel found. Please check the channel name.';

  @override
  String get searchChannelPrompt => 'Search for a channel!';

  @override
  String get clearHistoryMessages => 'Clear Chat History';

  @override
  String get channelNameLabel => 'Name:  ';

  @override
  String get channelOwnerLabel => 'Owner:  ';

  @override
  String get channelDescLabel => 'Description:  ';

  @override
  String get groupIdLabel => 'Group ID';

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
  String get callStatusDuration => 'Duration';

  @override
  String get callStatusCanceled => 'Canceled';

  @override
  String get callStatusRejected => 'Declined';

  @override
  String get callStatusRejectedByOther => 'Declined';

  @override
  String get callStatusCanceledByOther => 'Canceled';

  @override
  String get callStatusNoAnswer => 'No Answer';

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
  String containsMatchedMembers(Object names) {
    return 'Includes members: $names';
  }

  @override
  String get pleaseInput => 'Please enter';

  @override
  String get searchKeywordHint => 'Enter a keyword to search';

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
  String get selectUser => 'Select User';

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
  String get pollForwardComingSoon => 'Forwarding a poll isn\'t available yet';

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
  String get pickFriendsToSubmitReport =>
      'Select one or more friends to submit the report';

  @override
  String get creatingGroup => 'Creating group...';

  @override
  String groupNameTruncatedSuffix(Object name) {
    return '$name and others';
  }

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
  String filesCountLabel(Object count) {
    return '$count files';
  }

  @override
  String confirmSendFiles(Object name) {
    return 'Send $name?';
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
  String get zoomIn => 'Zoom in';

  @override
  String get zoomOut => 'Zoom out';

  @override
  String get rotateLeft => 'Rotate left';

  @override
  String get rotateRight => 'Rotate right';

  @override
  String get mediaPreviewTitle => 'Media Viewer';

  @override
  String get playbackSpeed => 'Speed';

  @override
  String get mute => 'Mute';

  @override
  String get unmute => 'Unmute';

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
  String get callSwitchToVoice => 'Switch to Voice';

  @override
  String get callMute => 'Mute';

  @override
  String get callHangup => 'Hang Up';

  @override
  String get callSwitchCamera => 'Flip';

  @override
  String get callSpeaker => 'Speaker';

  @override
  String get callInvite => 'Invite';

  @override
  String get callInviteMembers => 'Invite Members';

  @override
  String get callInviteNoCandidates => 'No members available to invite';

  @override
  String get meLabel => 'Me';

  @override
  String callParticipantCount(Object count) {
    return '$count in call';
  }

  @override
  String callSpeakingSuffix(Object name) {
    return ' · Speaking: $name';
  }

  @override
  String get callCameraOn => 'Camera On';

  @override
  String get callCameraOff => 'Camera Off';

  @override
  String get remoteCameraOff => 'Remote camera is off';

  @override
  String get waitingForRemoteVideo => 'Waiting for remote video';

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

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get chatLinks => 'Chat Links';

  @override
  String get noLinks => 'No links';

  @override
  String get joinGroupRequests => 'Join Group Requests';

  @override
  String get noJoinGroupRequests => 'No join group requests';

  @override
  String get joinGroupReason => 'Reason';

  @override
  String get agree => 'Agree';

  @override
  String get reject => 'Reject';

  @override
  String get clearJoinGroupRequests => 'Clear';

  @override
  String get accepted => 'Accepted';

  @override
  String get rejected => 'Rejected';

  @override
  String get expired => 'Expired';

  @override
  String newJoinGroupRequestCount(Object count) {
    return '$count new group join requests';
  }

  @override
  String get joinGroupRequestSent =>
      'Request sent to admin, please wait for approval';

  @override
  String get sendFailure => 'Send failed';

  @override
  String get joinGroupVerificationEnabled =>
      'Join group verification is enabled';

  @override
  String get pleaseInputJoinGroupReason => 'Please input join group reason';

  @override
  String requestJoinGroup(Object name) {
    return '$name requests to join group';
  }

  @override
  String inviteJoinGroup(Object inviter, Object member) {
    return '$inviter invites $member to join group';
  }

  @override
  String get deleteJoinGroupRequest => 'Delete';

  @override
  String get managerSetting => 'Managers';

  @override
  String get muteSetting => 'Mute Settings';

  @override
  String get allowTemporarySession => 'Allow Temporary Session';

  @override
  String get joinGroupPermission => 'Join Permission';

  @override
  String get freeToJoin => 'Free to Join';

  @override
  String get memberInviteOnly => 'Member Invite Only';

  @override
  String get managerInviteOnly => 'Manager Invite Only';

  @override
  String get needManagerVerify => 'Need Manager Approval';

  @override
  String get groupVisible => 'Group Visibility';

  @override
  String get searchable => 'Searchable';

  @override
  String get notSearchable => 'Not Searchable';

  @override
  String get groupHistoryMessage => 'History Message';

  @override
  String get groupMaxMember => 'Max Members';

  @override
  String get addManager => 'Add Manager';

  @override
  String get removeManager => 'Remove Manager';

  @override
  String get mutedMembers => 'Muted Members';

  @override
  String get allowedMembers => 'Allowed Members';

  @override
  String get addMutedMember => 'Add Muted Member';

  @override
  String get addAllowedMember => 'Add Allowed Member';

  @override
  String get remove => 'Remove';

  @override
  String get noCandidateForManager => 'No member can be set as manager';

  @override
  String get noCandidateForMute => 'No member available';

  @override
  String get unmuteSuccess => 'Unmuted';

  @override
  String get unallowSuccess => 'Removed from allow list';

  @override
  String get removeManagerSuccess => 'Manager removed';

  @override
  String get groupOwner => 'Owner';

  @override
  String get groupManager => 'Manager';

  @override
  String get muteAllMembers => 'Mute All Members';

  @override
  String get noOtherMembersToTransfer => 'No other member to transfer';

  @override
  String get transferGroupSuccess => 'Group transferred successfully';

  @override
  String get cloudDrive => 'Cloud Drive';

  @override
  String get pickDestination => 'Select Destination';

  @override
  String get panServiceNotConfigured => 'Cloud drive service is not configured';

  @override
  String get loadFailedRetry => 'Failed to load, please try again later';

  @override
  String get noPanSpaces => 'No cloud drive spaces';

  @override
  String panFileCount(Object count) {
    return '$count files';
  }

  @override
  String get panGlobalPublicSpace => 'Global Public Space';

  @override
  String get panMyPublicSpace => 'My Public Space';

  @override
  String get panMyPrivateSpace => 'My Private Space';

  @override
  String get paste => 'Paste';

  @override
  String get noFilesYet => 'No files yet';

  @override
  String panItemCount(Object count) {
    return '$count items';
  }

  @override
  String get panCannotMoveFolderIntoItself =>
      'Cannot move a folder into itself';

  @override
  String get panCannotCopyFolderIntoItself =>
      'Cannot copy a folder into itself';

  @override
  String get panGetDownloadUrlFailed => 'Failed to get download link';

  @override
  String get uploading => 'Uploading...';

  @override
  String get cancelUpload => 'Cancel Upload';

  @override
  String get uploadSuccess => 'Uploaded successfully';

  @override
  String get uploadCancelled => 'Upload cancelled';

  @override
  String get uploadFail => 'Upload failed';

  @override
  String get newFolder => 'New Folder';

  @override
  String get folderName => 'Folder name';

  @override
  String get createSuccess => 'Created successfully';

  @override
  String get createFail => 'Failed to create';

  @override
  String get rename => 'Rename';

  @override
  String get newName => 'New name';

  @override
  String get renameSuccess => 'Renamed successfully';

  @override
  String get renameFail => 'Failed to rename';

  @override
  String get panNoSpaceToSave => 'No space available to save to';

  @override
  String get panLoadSpacesFailed => 'Failed to load spaces';

  @override
  String get panDuplicate => 'Save a Copy';

  @override
  String get panDuplicateSuccess => 'Saved successfully';

  @override
  String get panDuplicateFail => 'Failed to save';

  @override
  String get panCannotMoveToSameLocation =>
      'Cannot move the file to its original location';

  @override
  String get moveSuccess => 'Moved successfully';

  @override
  String get moveFail => 'Failed to move';

  @override
  String get panCannotCopyToSameLocation =>
      'Cannot copy the file to its original location';

  @override
  String get copySuccess => 'Copied successfully';

  @override
  String get copyFail => 'Failed to copy';

  @override
  String deleteFileConfirm(Object name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get download => 'Download';

  @override
  String get downloadOrOpen => 'Download/Open';

  @override
  String get share => 'Share';

  @override
  String get move => 'Move';

  @override
  String get general => 'General';

  @override
  String get appearanceAndTheme => 'Appearance & Theme';

  @override
  String get notifications => 'Notifications';

  @override
  String get accountAndSecurity => 'Account & Security';

  @override
  String get chat => 'Chat';

  @override
  String get syncDraft => 'Sync Drafts';

  @override
  String get syncDraftDesc =>
      'Sync chat drafts both ways between mobile and desktop';

  @override
  String get startupAndWindow => 'Startup & Window';

  @override
  String get launchAtLoginTitle => 'Launch at Login';

  @override
  String get launchAtLoginDesc => 'Start the app automatically at login';

  @override
  String get setFailed => 'Failed to apply';

  @override
  String get closeToExitTitle =>
      'Quit the app when the window close button is clicked';

  @override
  String get closeToExitDesc =>
      'When off, the window minimizes to the system tray instead';

  @override
  String get minimizeToTaskbarTitle =>
      'Allow the main window to be minimized to the taskbar';

  @override
  String get minimizeToTaskbarDesc =>
      'When on, the window can be minimized; when off, it stays in the foreground';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get userAgreementDesc =>
      'Read the WildFire IM software license and service agreement';

  @override
  String get privacyPolicyDesc => 'Read the WildFire IM privacy guidelines';

  @override
  String get messageAlerts => 'Message Alerts';

  @override
  String get receiveNewMessageNotification =>
      'Receive new message notifications';

  @override
  String get receiveNewMessageNotificationDesc =>
      'Turn system sounds and banner notifications for new messages on or off';

  @override
  String get receiveCallNotification =>
      'Receive voice and video call notifications';

  @override
  String get receiveCallNotificationDesc =>
      'Turn the incoming call alert window on or off';

  @override
  String get showNotificationDetail => 'Show message details in notifications';

  @override
  String get showNotificationDetailDesc =>
      'When on, notifications show the sender and a message preview; when off, only \"You have a new message\" is shown';

  @override
  String get noDisturb => 'Do Not Disturb';

  @override
  String noDisturbPeriod(Object period) {
    return 'Current Do Not Disturb period: $period';
  }

  @override
  String get noDisturbDesc =>
      'When on, messages received during the set period will not play sounds or vibrate';

  @override
  String get simplifiedChinese => '简体中文';

  @override
  String get interfaceAppearance => 'Interface Appearance';

  @override
  String get interfaceLanguage => 'Interface Language';

  @override
  String get interfaceLanguageDesc =>
      'Change the interface language; restart the app for it to take effect';

  @override
  String get appearanceTheme => 'Theme';

  @override
  String get appearanceThemeDesc =>
      'Switch between dark and light themes, or follow the system appearance';

  @override
  String get fontSizeDesc => 'Adjust the text display size of the interface';

  @override
  String get setSuccessRestartToApply =>
      'Set successfully, restart the app for it to take effect';

  @override
  String get currentLoginAccount => 'Current Account';

  @override
  String accountName(Object name) {
    return 'Account: $name';
  }

  @override
  String get signOut => 'Sign Out';

  @override
  String get securityAndData => 'Security & Data';

  @override
  String get peerTyping => 'typing';

  @override
  String groupMembersTyping(Object count) {
    return '$count typing';
  }

  @override
  String namedUserTyping(Object name) {
    return '$name typing';
  }

  @override
  String get expandAll => 'Expand All';

  @override
  String get securityVerification => 'Security Verification';

  @override
  String get slideToVerifyHint => 'Slide right to verify';

  @override
  String get verifySuccess => 'Verification succeeded';

  @override
  String get verifyFailedRetry => 'Verification failed, please try again';

  @override
  String get securitySection => 'Security';

  @override
  String get dataSection => 'Data';

  @override
  String get changePassword => 'Change Password';

  @override
  String get changePasswordDesc =>
      'Change your login password by verifying the old password';

  @override
  String get blacklist => 'Blacklist';

  @override
  String get blacklistDesc => 'View and manage blocked contacts';

  @override
  String get backupAndRestoreDesc =>
      'Back up chat history to your computer, or restore a backup to your phone';

  @override
  String aboutVersion(Object version) {
    return 'Version $version';
  }

  @override
  String get aboutDescription =>
      'WildFire IM is a secure and reliable private instant messaging platform that is easy to integrate, simple to deploy and maintain, and convenient for secondary development and integration with existing systems.';

  @override
  String get officialWebsite => 'Official Website';

  @override
  String get githubRepo => 'GitHub Repository';

  @override
  String get issueFeedback => 'Report Issues';

  @override
  String get wechatContact => 'WeChat: wildfirechat or wfchat';

  @override
  String openLinkUrl(Object url) {
    return 'Open link: $url';
  }

  @override
  String get pleaseCompletePasswordFields =>
      'Please fill in all password fields';

  @override
  String get passwordNotMatch => 'The two new passwords do not match';

  @override
  String get passwordTooShort =>
      'The new password must be at least 6 characters';

  @override
  String get oldPassword => 'Old Password';

  @override
  String get inputOldPassword => 'Enter the old password';

  @override
  String get newPassword => 'New Password';

  @override
  String get inputNewPassword => 'Enter the new password';

  @override
  String get confirmNewPassword => 'Confirm New Password';

  @override
  String get inputNewPasswordAgain => 'Enter the new password again';

  @override
  String get confirmModify => 'Confirm';

  @override
  String get removeFromBlacklistConfirm =>
      'Are you sure you want to remove this user from the blacklist?';

  @override
  String get removedFromBlacklist => 'Removed from blacklist';

  @override
  String get blacklistEmpty => 'Blacklist is empty';

  @override
  String get blacklistRemove => 'Remove';

  @override
  String get privacy => 'Privacy';

  @override
  String get findMeBy => 'Ways to Find Me';

  @override
  String get findMeByDesc => 'Choose how others can search for you';

  @override
  String get msgReceipt => 'Message Receipt';

  @override
  String get msgReceiptDesc =>
      'When enabled, others can see the read status of your messages';

  @override
  String get onlineStatus => 'Online Status';

  @override
  String get onlineStatusDesc => 'Show my online status to contacts';

  @override
  String get friendVerify => 'Require Verification for Friend Requests';

  @override
  String get friendVerifyDesc =>
      'When enabled, others need your approval to add you as a friend';

  @override
  String get blockThem => 'Don\'t Let Them See';

  @override
  String get hideThem => 'Don\'t See Them';

  @override
  String get strangerTen => 'Allow Strangers to View 10 Moments';

  @override
  String get visibleRange => 'Moments Visible to Friends';

  @override
  String get momentsPrivacyDesc => 'Moments privacy and visibility settings';

  @override
  String get account => 'Account';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get rangeNoLimit => 'All';

  @override
  String get range3Days => 'Last 3 Days';

  @override
  String get range1Month => 'Last Month';

  @override
  String get range6Months => 'Last 6 Months';

  @override
  String get add => 'Add';

  @override
  String get searchOrgMembers => 'Search members';

  @override
  String maxSelectCount(Object count) {
    return 'Select up to $count people';
  }

  @override
  String maxImageSelectLimit(Object count) {
    return 'Select up to $count images';
  }

  @override
  String get albumPermissionDenied =>
      'Cannot access photo library. Please grant photo access in system settings.';

  @override
  String get noOrganizationData => 'No organization data available';

  @override
  String get orgNoSubOrgOrMembers =>
      'This department has no sub-departments or members';

  @override
  String get subDepartments => 'Sub-departments';

  @override
  String get members => 'Members';

  @override
  String get noMatchedMembers => 'No matching members found';

  @override
  String confirmWithCount(Object count, Object max) {
    return 'Confirm ($count/$max)';
  }

  @override
  String get reload => 'Reload';

  @override
  String searchFailed(Object error) {
    return 'Search failed: $error';
  }

  @override
  String get messageSettings => 'Message Settings';

  @override
  String get unknownMessageNotImplemented =>
      'This message type is not supported yet, please upgrade!';

  @override
  String get pcOnline => 'PC Online';

  @override
  String get padOnline => 'Pad Online';

  @override
  String get webOnline => 'Web Online';

  @override
  String get microAppOnline => 'Mini Program Online';

  @override
  String get mobileOnline => 'Mobile Online';

  @override
  String get busy => 'Busy';

  @override
  String get away => 'Away';

  @override
  String mobileOnlineDaysAgo(Object count) {
    return '$count days ago';
  }

  @override
  String mobileOnlineHoursAgo(Object count) {
    return '$count hours ago';
  }

  @override
  String mobileOnlineMinutesAgo(Object count) {
    return '$count mins ago';
  }

  @override
  String get mobileOnlineJustNow => 'just now';

  @override
  String get pcBackupMobileInteraction => 'Mobile Interaction';

  @override
  String get pcBackupMobileData => 'Back Up Mobile Data';

  @override
  String get pcBackupMobileDataDesc =>
      'When the mobile client chooses “Back Up to PC”, a confirmation dialog will pop up here to receive the uploaded backup.';

  @override
  String get pcRestoreToMobile => 'Restore Data to Mobile';

  @override
  String get pcRestoreToMobileDesc =>
      'When the mobile client chooses “Restore from PC”, a confirmation dialog will pop up here to provide a local backup.';

  @override
  String get pcBackupLocalData => 'Back Up Local Data';

  @override
  String get pcBackupLocalDataDesc =>
      'Select conversations and back up to the local backup folder';

  @override
  String get pcRestoreLocalData => 'Restore Local Data';

  @override
  String get pcRestoreLocalDataDesc =>
      'Restore data from the local backup folder';

  @override
  String get pcOpenBackupFolder => 'Open Backup Folder';

  @override
  String get pcOpenBackupFolderDesc => 'View backup files in file explorer';

  @override
  String get pcReceivedBackups => 'Received Backups';

  @override
  String get pcNoBackups => 'No backups';

  @override
  String get pcInvalidBackupFolder =>
      'The selected folder is not a valid backup';

  @override
  String get pcDeleteBackupConfirm =>
      'Are you sure you want to delete this backup?';

  @override
  String get pcBackupDeleted => 'Backup deleted';

  @override
  String pcDeleteBackupFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String get pcLocalBackup => 'Local Backup';

  @override
  String get pcBackupCompleted => 'Backup Completed';

  @override
  String get pcRestoreBackup => 'Restore Backup';

  @override
  String pcRestoreCompleted(String count) {
    return 'Restore Completed\nRestored $count messages';
  }

  @override
  String pcLoadBackupsFailed(String error) {
    return 'Failed to load backups: $error';
  }

  @override
  String get pcCannotOpenFolder => 'Cannot open folder';

  @override
  String pcOpenFolderFailed(String error) {
    return 'Failed to open folder: $error';
  }

  @override
  String get pcUnknownDate => 'Unknown';

  @override
  String get pcBackupRequestTitle => 'Backup Request';

  @override
  String pcBackupRequestContent(
      String conversationCount, String messageCount, String includeMedia) {
    return 'The mobile client requests to save the backup to this computer\n\nConversations: $conversationCount\nMessages: $messageCount\n$includeMedia media files\n\nStart backup?';
  }

  @override
  String get pcIncludeMedia => 'Include';

  @override
  String get pcExcludeMedia => 'Exclude';

  @override
  String get pcStartBackup => 'Start Backup';

  @override
  String get pcRestoreRequestTitle => 'Restore Request';

  @override
  String get pcRestoreRequestContent =>
      'The mobile client requests to restore a backup from this computer. Allow?';

  @override
  String get pcAllow => 'Allow';

  @override
  String get pcBackupReceivedTitle => 'Backup Complete';

  @override
  String pcBackupReceivedContent(String count, String path) {
    return 'Successfully received $count files\nSave location: $path';
  }

  @override
  String pcBackupReceivedFailed(String error) {
    return 'Backup failed: $error';
  }

  @override
  String pcStartBackupServerFailed(String error) {
    return 'Failed to start backup server: $error';
  }

  @override
  String get pcRestoreAllowed =>
      'Allowed mobile client to restore backup from this computer';

  @override
  String pcStartRestoreServerFailed(String error) {
    return 'Failed to start restore server: $error';
  }

  @override
  String get pcReceivingBackup => 'Receiving Backup';

  @override
  String get pcReceivedFiles => 'Received files:';

  @override
  String get pcCurrentFile => 'Current file:';

  @override
  String get pcSaveLocation => 'Save location:';

  @override
  String get pcPreparing => 'Preparing...';

  @override
  String get pcKeepWindowOpenHint =>
      'Please keep the window open, receiving backup data...';

  @override
  String get noBackupsFound => 'No backups found';

  @override
  String get createNewBackup => 'Create New Backup';

  @override
  String get restoreFromPC => 'Restore from PC';

  @override
  String get deleteBackup => 'Delete Backup';

  @override
  String get restoreBackup => 'Restore Backup';

  @override
  String get restoreBackupConfirm =>
      'Restoring will merge messages from the backup into your current chat history. Existing messages will NOT be overwritten unless they are duplicates.\n\nContinue?';

  @override
  String restoreCompleted(String messageCount, String mediaCount) {
    return 'Restored $messageCount messages and $mediaCount media files';
  }

  @override
  String get backupCompleted => 'Backup completed';

  @override
  String get selectConversations => 'Select Conversations';

  @override
  String get next => 'Next';

  @override
  String get selectAll => 'Select All';

  @override
  String get includeMedia => 'Include Media';

  @override
  String get includeMediaDesc => 'Images, videos, files, etc.';

  @override
  String get pleaseSelectConversation =>
      'Please select at least one conversation';

  @override
  String get backupDestination => 'Backup Destination';

  @override
  String get backupToLocalStorage => 'Back Up to Local Storage';

  @override
  String get backupToLocalStorageDesc => 'Save backup files to this device';

  @override
  String get backupToPC => 'Back Up to PC';

  @override
  String get backupToPCOnline => 'PC client is online. Click to start.';

  @override
  String get backupToPCOffline => 'Back Up to PC (Offline)';

  @override
  String get backupToPCOfflineDesc => 'Please log in to the PC client first';

  @override
  String get pcWaitingForConfirmation => 'Waiting for PC confirmation...';

  @override
  String get pcPleaseConfirmOnPC =>
      'Please confirm the backup request on your PC client';

  @override
  String get pcApproved => 'Approved';

  @override
  String pcConnectingTo(String ip, String port) {
    return 'Connecting to $ip:$port';
  }

  @override
  String get pcRequestRejected => 'Request Rejected';

  @override
  String get pcBackupRejectedDesc =>
      'The PC client rejected the backup request';

  @override
  String get pcBackupCompletedDesc =>
      'Your data has been successfully backed up to PC';

  @override
  String get pcBackupFailed => 'Backup Failed';

  @override
  String get pcClose => 'Close';

  @override
  String get pcFetchingBackupList => 'Fetching backup list...';

  @override
  String pcFoundBackups(String count) {
    return 'Found $count backups';
  }

  @override
  String get pcSelectBackup => 'Select Backup';

  @override
  String get pcPasswordRequired => 'Password Required';

  @override
  String pcRestoredMessages(String count) {
    return 'Restored $count messages';
  }

  @override
  String get deleteBackupConfirm =>
      'Are you sure you want to delete this backup?';

  @override
  String get password => 'Password';

  @override
  String pcRestoreFailed(String error) {
    return 'Restore failed: $error';
  }

  @override
  String backupListSubtitle(String conversationCount, String messageCount) {
    return '$conversationCount conversations, $messageCount messages';
  }

  @override
  String get pcBackupProgressTitle => 'PC Backup Progress';

  @override
  String get pcRestoreProgressTitle => 'PC Restore Progress';

  @override
  String get pcRestoringBackup => 'Downloading & Restoring...';

  @override
  String get pcPasswordEntryCancelled => 'Password entry cancelled';

  @override
  String get pcBackupDefaultName => 'PC Backup';

  @override
  String get conversationTypeSingle => 'Private';

  @override
  String get conversationTypeGroup => 'Group';

  @override
  String get conversationTypeChannel => 'Channel';

  @override
  String get pcMobileOperationHintTitle =>
      'Please operate on your mobile device';

  @override
  String get pcBackupMobileDataHint =>
      'On your phone, go to Backup & Restore and choose \"Back Up to PC\". A confirmation dialog will pop up here.';

  @override
  String get pcRestoreToMobileHint =>
      'On your phone, go to Backup & Restore and choose \"Restore from PC\". A confirmation dialog will pop up here.';

  @override
  String get multiCallWindowTitle => 'Group Call';

  @override
  String get momentWindowTitle => 'Moments';

  @override
  String get webViewNotSupport =>
      'Built-in web browsing is not supported on this platform';

  @override
  String get openInSystemBrowser => 'Open in system browser';
}
