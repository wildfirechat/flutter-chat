enum FriendRequestDirection { Send, Receive }

enum FriendRequestStatus { WaitingAccept, Accepted, Denied }

enum FriendRequestReadStatus { unread, read }

class FriendRequest {
  FriendRequest(
      {this.direction = FriendRequestDirection.Send,
      this.status = FriendRequestStatus.WaitingAccept,
      this.readStatus = FriendRequestReadStatus.unread});
  //放向
  FriendRequestDirection direction;
  //ID
  String target;
  //请求说明
  String reason;
  //接受状态
  FriendRequestStatus status;
  //已读
  FriendRequestReadStatus readStatus;
  //发起时间
  int timestamp;
}
