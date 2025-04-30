import 'package:imclient/imclient.dart';
import 'package:imclient/model/group_info.dart';

class GroupRepo {
  static final Map<String, GroupInfo> _groupMap = {};

  static Future<GroupInfo?> getGroupInfo(String groupId) async {
    var info = _groupMap[groupId];
    if (info == null) {
      info = await Imclient.getGroupInfo(groupId);
      if (info != null) {
        _groupMap[groupId] = info;
      }
    }
    return info;
  }

  static void putGroupInfo(GroupInfo groupInfo) {
    _groupMap[groupInfo.target] = groupInfo;
  }
}
