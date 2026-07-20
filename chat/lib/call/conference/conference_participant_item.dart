import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:imclient/model/user_info.dart';

/// 会议参与者视图模型:界面展示所需的参与者状态。
/// renderer 随参与者创建/加入时 initialize、离开/结束时 dispose,
/// 生命周期由 ConferenceCallScreen 管理。
class ConferenceParticipantItem {
  final String userId;
  UserInfo? userInfo;
  RTCVideoRenderer renderer;
  bool videoMuted = false;
  bool audioMuted = false;
  bool isScreenSharing = false;
  bool isAudience = false;
  int volume = 0;

  ConferenceParticipantItem({required this.userId, required this.renderer});
}
