
import 'group_info.dart';

///群组搜索批评类型Mask，比如搜索群组时同时批评到了群组的名称和群组成员的名称，那么marchType就是0x01&0x02 = 3
const int GroupSearchMarchTypeMask_Group_Name = 0x01;
const int GroupSearchMarchTypeMask_Member_Name = 0x02;
const int GroupSearchMarchTypeMask_Member_Alias = 0x04;
const int GroupSearchMarchTypeMask_Group_Remark = 0x08;

class GroupSearchInfo {
  GroupInfo? groupInfo;
  late int marchType;
  List<String>? marchedMemberNames;
}
