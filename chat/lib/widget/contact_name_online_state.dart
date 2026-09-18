import 'package:flutter/material.dart';
import 'package:imclient/model/user_info.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/utils/external_target_utils.dart';
import 'package:chat/utils/mesh_user_name.dart';
import 'package:chat/utils/online_state_builder.dart';
import 'package:chat/utils/online_state_formatter.dart';

/// 在线圆点的直径。它是图形记号、不承载文字,所以不跟字号缩放。
const double _kDotSize = 6;

/// 圆点与名字的间距。
const double _kDotGap = 6;

/// 名字与状态行之间的间距。
const double _kLineGap = 2;

/// 联系人行的「名字 + 在线状态」,两行结构(移动端联系人页与桌面中栏共用):
///
/// - 第一行:名字(外部域用户带域后缀)+ 在线绿点 —— 绿点只回答「在不在线」
/// - 第二行:在线状态详情 —— 「手机在线 / 电脑在线 / 忙碌」,离线则是「手机 5 分钟前在线」
///
/// 详情文案与会话页标题第二行同源([OnlineStateFormatter.statusText])。没有可展示的
/// 状态时(没登录过 / 对方隐身)第二行不占位,行退化成单行;两行都在调用方给定的固定
/// 行高内垂直居中 —— 联系人列表是固定 extent 的(索引条与滚动定位都按它算),
/// 这里不能把行撑高。
class ContactNameOnlineState extends StatelessWidget {
  final UserInfo userInfo;

  /// 名字样式。移动端给 [AppText.lg]、桌面给 `PcTheme.cellTitle`;
  /// 选中态等变化由调用方 copyWith 后传进来。
  final TextStyle nameStyle;

  /// 状态行样式,默认小一档的次要色文本(桌面选中行是深色底,由调用方传反白样式)。
  final TextStyle? statusStyle;

  const ContactNameOnlineState(
    this.userInfo, {
    super.key,
    required this.nameStyle,
    this.statusStyle,
  });

  @override
  Widget build(BuildContext context) {
    final name = MeshUserName(
      userInfo,
      style: nameStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    // 外部域用户跨域拿不到在线状态,只画名字。
    if (ExternalTargetUtils.isExternalTarget(userInfo.userId)) {
      return name;
    }
    return OnlineStateBuilder(
      userId: userInfo.userId,
      builder: (context, state) {
        final status = OnlineStateFormatter.statusText(
            state, AppLocalizations.of(context)!);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (OnlineStateFormatter.isOnline(state))
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 名字先省略,绿点不被挤掉
                  Flexible(child: name),
                  const SizedBox(width: _kDotGap),
                  Container(
                    width: _kDotSize,
                    height: _kDotSize,
                    decoration: BoxDecoration(
                      // 「在线」是语义色,选中行反白的是文字,绿点不跟着变
                      color: context.colors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              )
            else
              name,
            if (status != null && status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: _kLineGap),
                child: Text(
                  status,
                  style: statusStyle ??
                      AppText.xs.copyWith(color: context.colors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        );
      },
    );
  }
}
