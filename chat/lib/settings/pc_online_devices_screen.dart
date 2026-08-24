import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/im_constant.dart';
import 'package:imclient/model/pc_online_info.dart';
import 'package:chat/app_navigator.dart';
import 'package:chat/config.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/utils/pc_online_util.dart';
import 'package:chat/viewmodel/status_notification_view_model.dart';
import 'package:chat/widget/app_switch.dart';

/// 已登录的设备页(微信风格,对齐 HarmonyOS PCSessionPage)。
///
/// 每台设备一张白色圆角卡片,第一张默认展开;点击卡片展开、其余收起(手风琴),
/// 再点已展开的卡片收起。
///
/// 卡片头部:小平台图标 + 设备名(加粗)/设备名小字(clientName)竖排 + 右侧箭头,
/// 点击展开/收起。展开区:大平台图标(约56)居中 + 设备名(大号加粗)/小字居中,
/// 下方依次为「手机通知」(全局开关,复用 _toggleMute)、「锁定」(仅桌面电脑类设备,
/// 通过 UserSettingScope.Lock_PC 写入,等价原生 lockPCClient)、「传文件」
/// (跳文件传输助手)、「退出登录」红色居中操作。
class PCOnlineDevicesScreen extends StatefulWidget {
  const PCOnlineDevicesScreen({super.key});

  @override
  State<PCOnlineDevicesScreen> createState() => _PCOnlineDevicesScreenState();
}

class _PCOnlineDevicesScreenState extends State<PCOnlineDevicesScreen> {
  List<PCOnlineInfo> _onlineInfos = [];
  bool _isMute = false;

  /// 当前展开的卡片下标,-1 表示全部收起;第一张默认展开。
  int _expandedIndex = -1;

  /// 每台设备的锁定状态,与 [_onlineInfos] 下标一一对应。
  List<bool> _lockStates = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    var onlineInfos = await Imclient.getPCOnlineInfos();
    var isMute = await Imclient.isMuteNotificationWhenPcOnline();
    if (mounted) {
      setState(() {
        _onlineInfos = onlineInfos;
        _isMute = isMute;
        if (_onlineInfos.isEmpty) {
          _expandedIndex = -1;
        } else if (_expandedIndex < 0 ||
            _expandedIndex >= _onlineInfos.length) {
          // 第一张默认展开;设备掉线导致下标越界时回退到第一张。
          _expandedIndex = 0;
        }
      });
    }
    await _loadLockStates();
  }

  Future<void> _loadLockStates() async {
    final states = <bool>[];
    for (final info in _onlineInfos) {
      var locked = false;
      try {
        locked = await Imclient.getUserSetting(
                UserSettingScope.Lock_PC, info.clientId) ==
            '1';
      } catch (_) {
        // 取锁定状态失败按未锁定处理,切换时仍可重试。
      }
      states.add(locked);
    }
    if (mounted) {
      setState(() {
        _lockStates = states;
      });
    }
  }

  void _kickClient(PCOnlineInfo info) {
    Imclient.kickoffPCClient(info.clientId, () {
      Fluttertoast.showToast(msg: AppLocalizations.of(context)!.deviceLoggedOut);
      _loadData();
      // 会话列表顶部那条多端登录条读的是共享的 ViewModel。手机端本来靠
      // 「本页被弹回」时刷新,两栏形态下本页在右栏里不会被弹回,所以在这里直接通知。
      if (mounted) {
        context.read<StatusNotificationViewModel>().refreshOnlineInfos();
      }
    }, (err) {
      Fluttertoast.showToast(
          msg: AppLocalizations.of(context)!.operateFail(err.toString()));
    });
  }

  void _toggleMute(bool value) {
    Imclient.muteNotificationWhenPcOnline(value, () {
      setState(() {
        _isMute = value;
      });
    }, (err) {
      Fluttertoast.showToast(
          msg: AppLocalizations.of(context)!.setFail(err.toString()));
      setState(() {
        _isMute = !_isMute;
      });
    });
  }

  /// 锁定/解锁桌面电脑类设备。开关只在成功后更新状态,失败提示且不 setState,即回滚。
  void _toggleLock(int index, PCOnlineInfo info, bool value) {
    Imclient.setUserSetting(
        UserSettingScope.Lock_PC, info.clientId, value ? '1' : '0', () {
      if (mounted) {
        setState(() {
          _lockStates[index] = value;
        });
      }
    }, (err) {
      Fluttertoast.showToast(
          msg: AppLocalizations.of(context)!.setFail(err.toString()));
    });
  }

  void _toggleExpand(int index) {
    setState(() {
      _expandedIndex = _expandedIndex == index ? -1 : index;
    });
  }

  /// 传文件:打开与「文件传输助手」的单聊会话。
  void _openFileTransfer() {
    openConversation(
      context,
      Conversation(
        conversationType: ConversationType.Single,
        target: Config.FILE_TRANSFER_ID,
        line: 0,
      ),
    );
  }

  /// clientName 为空(null/空串)或为 "unknown" 时不展示小字。
  String? _nonEmptyClientName(PCOnlineInfo info) {
    final name = info.clientName;
    if (name == null || name.isEmpty || name.toLowerCase() == 'unknown') {
      return null;
    }
    return name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.chatBg,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.pcOnlineDevices),
        elevation: 0,
      ),
      body: _onlineInfos.isEmpty
          ? Center(child: Text(AppLocalizations.of(context)!.noPcOnline))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _onlineInfos.length,
              itemBuilder: (context, index) =>
                  _buildDeviceCard(context, index),
            ),
    );
  }

  Widget _buildDeviceCard(BuildContext context, int index) {
    final info = _onlineInfos[index];
    final isExpanded = _expandedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // 卡片头部:小图标 + 设备名/小字竖排 + 右侧箭头,点击展开/收起
          _buildDeviceHeader(context, index, info, isExpanded),
          // 展开内容:大图标 + 功能列表(手机通知/锁定/传文件/退出登录)
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? _buildExpanded(context, index)
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  /// 卡片头部:左侧小平台图标(约24) + 设备名(加粗)/设备名小字 竖排 + 右侧箭头。
  /// 高度 64,整体可点击,展开时箭头旋转 180°。
  Widget _buildDeviceHeader(
      BuildContext context, int index, PCOnlineInfo info, bool isExpanded) {
    final String? clientName = _nonEmptyClientName(info);
    return InkWell(
      onTap: () => _toggleExpand(index),
      child: SizedBox(
        height: 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(PcOnlineUtil.icon(info),
                  size: 24, color: context.colors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      PcOnlineUtil.deviceName(context, info),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          AppText.lg.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (clientName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        clientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.xs
                            .copyWith(color: context.colors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down,
                    size: 20, color: context.colors.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 展开区:顶部大平台图标(约56)居中 + 设备名(大号加粗)/小字居中,
  /// 下方依次为「手机通知」「锁定(仅桌面电脑类)」「传文件」「退出登录」。
  Widget _buildExpanded(BuildContext context, int index) {
    final info = _onlineInfos[index];
    final isDesktop = PcOnlineUtil.isDesktopDevice(info);
    final String? clientName = _nonEmptyClientName(info);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 顶部:大图标 + 设备名 + 小字,居中
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            children: [
              Icon(PcOnlineUtil.icon(info),
                  size: 56, color: context.colors.textSecondary),
              const SizedBox(height: 12),
              Text(
                PcOnlineUtil.deviceName(context, info),
                textAlign: TextAlign.center,
                style: AppText.lg.copyWith(fontWeight: FontWeight.bold),
              ),
              if (clientName != null) ...[
                const SizedBox(height: 6),
                Text(
                  clientName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.sm
                      .copyWith(color: context.colors.textSecondary),
                ),
              ],
            ],
          ),
        ),
        _buildDivider(),
        // 手机通知(全局开关:其它端在线时关闭手机通知,复用 _toggleMute)
        _buildSwitchRow(
          '手机通知',
          value: _isMute,
          onChanged: _toggleMute,
        ),
        _buildDivider(indent: 16),
        // 锁定(仅桌面电脑类设备,复用 _toggleLock)
        if (isDesktop) ...[
          _buildSwitchRow(
            '锁定',
            value: index < _lockStates.length && _lockStates[index],
            onChanged: (value) => _toggleLock(index, info, value),
          ),
          _buildDivider(indent: 16),
        ],
        // 传文件:点击跳文件传输助手
        _buildActionRow('传文件', () => _openFileTransfer()),
        _buildDivider(indent: 16),
        // 退出登录(文字居中,红色)
        InkWell(
          onTap: () => _kickClient(info),
          child: Container(
            height: 52,
            alignment: Alignment.center,
            child: Text(
              '退出登录',
              style: AppText.lg.copyWith(color: context.colors.danger),
            ),
          ),
        ),
      ],
    );
  }

  /// 功能行:文字 + 开关。
  Widget _buildSwitchRow(String title,
      {required bool value, required ValueChanged<bool> onChanged}) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppText.lg)),
          AppSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  /// 功能行:文字 + 右侧箭头,整行可点击。
  Widget _buildActionRow(String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(child: Text(title, style: AppText.lg)),
            Icon(Icons.chevron_right,
                size: 20, color: context.colors.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider({double indent = 0}) {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: context.colors.hairlineSoft,
      indent: indent,
    );
  }
}
