import 'package:imclient/imclient.dart';
import 'package:imclient/model/group_info.dart';

class GroupRepo {
  static final Map<String, GroupInfo> _groupMap = {};
  static bool _conversationGroupInfosLoaded = false;

  static void clear() {
    _groupMap.clear();
    _conversationGroupInfosLoaded = false;
  }

  static void loadConversationGroupInfos(List<String> groupIds) async {
    if (_conversationGroupInfosLoaded) {
      return;
    }
    List<GroupInfo> groupInfos = await Imclient.getGroupInfos(groupIds);
    updateGroupInfos(groupInfos);
    _conversationGroupInfosLoaded = true;
  }

  static GroupInfo? getGroupInfo(String groupId) {
    var info = _groupMap[groupId];
    return info;
  }

  static void putGroupInfo(GroupInfo groupInfo) {
    _groupMap[groupInfo.target] = groupInfo;
  }

  static void updateGroupInfos(List<GroupInfo> groupInfos) {
    for (var info in groupInfos) {
      if (info.updateDt > 0) {
        _groupMap[info.target] = info;
      }
    }
  }
}
