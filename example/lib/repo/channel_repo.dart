import 'package:imclient/imclient.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/group_info.dart';

class ChannelRepo {
  static final Map<String, ChannelInfo> _channelMap = {};

  static Future<ChannelInfo?> getChannelInfo(String channelId) async {
    var info = _channelMap[channelId];
    if (info == null) {
      info = await Imclient.getChannelInfo(channelId);
      if (info != null) {
        _channelMap[channelId] = info;
      }
    }
    return info;
  }

  static void putChannelInfo(ChannelInfo groupInfo) {
    _channelMap[groupInfo.channelId] = groupInfo;
  }
}
