
import 'group_info.dart';

enum GroupSearchResultType { MatchedGroupName, MatchedGroupMember, Both }

class GroupSearchInfo {
  GroupInfo groupInfo;
  GroupSearchResultType marchType;
  List<String> marchedMemberNames;
}
