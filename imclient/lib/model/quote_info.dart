import '../message/message.dart';
import '../imclient.dart';
import '../model/conversation.dart';
import '../model/user_info.dart';

class QuoteInfo {
  QuoteInfo(this.messageUid);

  int messageUid;
  String? userId;
  String? userDisplayName;
  String? messageDigest;


  static Future<QuoteInfo> fromMessage(Message msg) async {
    QuoteInfo quoteInfo = QuoteInfo(msg.messageUid!);
    quoteInfo.userId = msg.fromUser;
    UserInfo? userInfo = await Imclient.getUserInfo(msg.fromUser, groupId: msg.conversation.conversationType == ConversationType.Group ? msg.conversation.target : "");
    if (userInfo != null) {
      quoteInfo.userDisplayName = userInfo.displayName;
    }
    quoteInfo.messageDigest = await msg.content.digest(msg);
    return quoteInfo;
  }

}
