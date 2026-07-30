import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';
import 'package:moment/client/momentclient.dart';
import 'package:moment/moment.dart';
import 'package:chat/config.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/mesh/mesh_cache.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/widgets/pc_card.dart';
import 'package:chat/pc/widgets/pc_page_header.dart';
import 'package:chat/pc/widgets/pc_pane_content.dart';
import 'package:chat/pc/widgets/pc_settings_row.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/utils/mesh_user_name.dart';
import 'package:chat/widget/option_item.dart';
import 'package:chat/widget/portrait.dart';

/// 朋友圈设置页面
///
/// 提供「不让他(她)看」「不看他(她)」名单管理、陌生人可见条数、
/// 朋友可见范围等朋友圈隐私设置,数据来自 MomentClient.getUserProfile。
class MomentPrivacySettingsScreen extends StatefulWidget {
  const MomentPrivacySettingsScreen({super.key});

  @override
  State<MomentPrivacySettingsScreen> createState() =>
      _MomentPrivacySettingsScreenState();
}

class _MomentPrivacySettingsScreenState
    extends State<MomentPrivacySettingsScreen> {
  MomentProfiles? _profiles;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  void _loadProfiles() {
    MomentClient.getUserProfile((profiles) {
      if (mounted) {
        setState(() {
          _profiles = profiles;
          _loading = false;
        });
      }
    }, (errorCode) {
      if (mounted) {
        setState(() => _loading = false);
        Fluttertoast.showToast(msg: AppLocalizations.of(context)!.networkError);
      }
    });
  }

  /// 陌生人可见条数开关:on=10 条,off=0 条
  void _onStrangerChanged(bool enable) {
    final l10n = AppLocalizations.of(context)!;
    final oldCount = _profiles?.strangerVisiableCount ?? 0;
    setState(() {
      _profiles?.strangerVisiableCount = enable ? 10 : 0;
    });
    MomentClient.updateMyProfile(
        WFMUpdateUserProfileType.WFMUpdateUserProfileType_StrangerVisiableCount,
        null,
        enable ? 10 : 0,
        () {}, (errorCode) {
      if (mounted) {
        setState(() {
          _profiles?.strangerVisiableCount = oldCount;
        });
      }
      Fluttertoast.showToast(msg: l10n.operateFail('$errorCode'));
    });
  }

  String _rangeText(AppLocalizations l10n, WFMVisiableScope? scope) {
    switch (scope) {
      case WFMVisiableScope.WFMVisiableScope_3Days:
        return l10n.range3Days;
      case WFMVisiableScope.WFMVisiableScope_1Month:
        return l10n.range1Month;
      case WFMVisiableScope.WFMVisiableScope_6Months:
        return l10n.range6Months;
      case WFMVisiableScope.WFMVisiableScope_NoLimit:
      case null:
        return l10n.rangeNoLimit;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // PC 端与隐私设置主页一致的行样式(字体/开关大小对齐)
    if (isDesktopShell) {
      return Scaffold(
        backgroundColor: context.colors.chatBgDesktop,
        appBar: PcPageHeader(title: l10n.momentWindowTitle),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: PcPaneContent.defaultPadding,
                child: PcPaneContent(
                  child: PcCard(children: [
                    PcSettingsClickableRow(
                      title: l10n.blockThem,
                      subtitle: '',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MomentBlockListScreen(
                              isBlock: true,
                              title: l10n.blockThem,
                              userIds: _profiles?.blockList ?? const [],
                            ),
                          ),
                        ).then((_) => _loadProfiles());
                      },
                    ),
                    const Divider(),
                    PcSettingsClickableRow(
                      title: l10n.hideThem,
                      subtitle: '',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MomentBlockListScreen(
                              isBlock: false,
                              title: l10n.hideThem,
                              userIds: _profiles?.blackList ?? const [],
                            ),
                          ),
                        ).then((_) => _loadProfiles());
                      },
                    ),
                    const Divider(),
                    PcSettingsSwitchRow(
                      title: l10n.strangerTen,
                      subtitle: '',
                      value: (_profiles?.strangerVisiableCount ?? 0) > 0,
                      onChanged: _onStrangerChanged,
                    ),
                    const Divider(),
                    PcSettingsClickableRow(
                      title: l10n.visibleRange,
                      subtitle: _rangeText(l10n, _profiles?.visiableScope),
                      onTap: () async {
                        final scope = await Navigator.push<WFMVisiableScope>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MomentVisibleRangeScreen(
                              current: _profiles?.visiableScope ??
                                  WFMVisiableScope.WFMVisiableScope_NoLimit,
                            ),
                          ),
                        );
                        if (scope != null && mounted) {
                          setState(() {
                            _profiles?.visiableScope = scope;
                          });
                        }
                      },
                    ),
                  ]),
                ),
              ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.momentWindowTitle),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    OptionItem(
                      l10n.blockThem,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MomentBlockListScreen(
                              isBlock: true,
                              title: l10n.blockThem,
                              userIds: _profiles?.blockList ?? const [],
                            ),
                          ),
                        ).then((_) => _loadProfiles());
                      },
                    ),
                    OptionItem(
                      l10n.hideThem,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MomentBlockListScreen(
                              isBlock: false,
                              title: l10n.hideThem,
                              userIds: _profiles?.blackList ?? const [],
                            ),
                          ),
                        ).then((_) => _loadProfiles());
                      },
                    ),
                    SwitchListTile(
                      title: Text(l10n.strangerTen),
                      value: (_profiles?.strangerVisiableCount ?? 0) > 0,
                      onChanged: _onStrangerChanged,
                    ),
                    OptionItem(
                      l10n.visibleRange,
                      desc: _rangeText(l10n, _profiles?.visiableScope),
                      onTap: () async {
                        final scope = await Navigator.push<WFMVisiableScope>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MomentVisibleRangeScreen(
                              current: _profiles?.visiableScope ??
                                  WFMVisiableScope.WFMVisiableScope_NoLimit,
                            ),
                          ),
                        );
                        if (scope != null && mounted) {
                          setState(() {
                            _profiles?.visiableScope = scope;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// 允许朋友查看朋友圈的范围选择页
class MomentVisibleRangeScreen extends StatelessWidget {
  final WFMVisiableScope current;

  const MomentVisibleRangeScreen({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final options = <(WFMVisiableScope, String)>[
      (WFMVisiableScope.WFMVisiableScope_NoLimit, l10n.rangeNoLimit),
      (WFMVisiableScope.WFMVisiableScope_3Days, l10n.range3Days),
      (WFMVisiableScope.WFMVisiableScope_1Month, l10n.range1Month),
      (WFMVisiableScope.WFMVisiableScope_6Months, l10n.range6Months),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.visibleRange),
      ),
      body: SafeArea(
        child: ListView(
          children: [
            for (final (scope, text) in options)
              ListTile(
                title: Text(text),
                trailing: scope == current
                    ? const Icon(Icons.check, color: Color(0xFF576b95))
                    : null,
                onTap: () {
                  MomentClient.updateMyProfile(
                      WFMUpdateUserProfileType
                          .WFMUpdateUserProfileType_VisiableScope,
                      null,
                      scope.index, () {
                    Navigator.pop(context, scope);
                  }, (errorCode) {
                    Fluttertoast.showToast(msg: l10n.operateFail('$errorCode'));
                  });
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// 朋友圈名单管理页(「不让他(她)看」/「不看他(她)」通用)
///
/// isBlock=true 操作 blockList(不让他看),false 操作 blackList(不看他)。
/// 联系人选择器未注入(MomentKit.contactPicker 为 null)时隐藏添加按钮,只读展示。
class MomentBlockListScreen extends StatefulWidget {
  final bool isBlock;
  final String title;
  final List<String> userIds;

  const MomentBlockListScreen({
    super.key,
    required this.isBlock,
    required this.title,
    required this.userIds,
  });

  @override
  State<MomentBlockListScreen> createState() => _MomentBlockListScreenState();
}

class _MomentBlockListScreenState extends State<MomentBlockListScreen> {
  late List<String> _userIds;
  final Map<String, UserInfo?> _userInfoCache = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _userIds = List.of(widget.userIds);
    _loadUserInfos();
  }

  Future<void> _loadUserInfos() async {
    if (_userIds.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final users = await Imclient.getUserInfos(_userIds, groupId: '');
      for (final user in users) {
        _userInfoCache[user.userId] = user;
      }
    } catch (e) {
      debugPrint('MomentBlockList load error: $e');
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _addMembers() async {
    final l10n = AppLocalizations.of(context)!;
    final picker = MomentKit.contactPicker;
    if (picker == null) return;
    final selected = await picker(context, _userIds);
    if (!mounted) return;
    // 只提交新增的 userId
    final addList = selected.where((id) => !_userIds.contains(id)).toList();
    if (addList.isEmpty) return;
    MomentClient.updateBlackOrBlockList(widget.isBlock, addList, null, () {
      setState(() {
        _userIds.addAll(addList);
        _loading = true;
      });
      _loadUserInfos();
    }, (errorCode) {
      Fluttertoast.showToast(msg: l10n.operateFail('$errorCode'));
    });
  }

  void _removeMember(String userId) {
    final l10n = AppLocalizations.of(context)!;
    MomentClient.updateBlackOrBlockList(widget.isBlock, null, [userId], () {
      setState(() {
        _userIds.remove(userId);
      });
    }, (errorCode) {
      Fluttertoast.showToast(msg: l10n.operateFail('$errorCode'));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (MomentKit.contactPicker != null)
            TextButton(
              onPressed: _addMembers,
              child: Text(l10n.add),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _userIds.isEmpty
              // 空名单占位,文案与 moment 包现有风格保持一致
              ? const Center(
                  child:
                      Text('暂无成员', style: TextStyle(color: Color(0xFF999999))))
              : ListView.separated(
                  itemCount: _userIds.length,
                  separatorBuilder: (_, __) => const Divider(indent: 72),
                  itemBuilder: (context, index) {
                    final userId = _userIds[index];
                    final userInfo = _userInfoCache[userId];
                    return ListTile(
                      leading: Portrait(
                        userInfo?.portrait ?? Config.defaultUserPortrait,
                        Config.defaultUserPortrait,
                        width: 48,
                        height: 48,
                        borderRadius: 6,
                      ),
                      title: AnimatedBuilder(
                        animation: MeshCache.instance,
                        builder: (context, child) {
                          return userInfo != null
                              ? MeshUserName(userInfo)
                              : Text(userId);
                        },
                      ),
                      subtitle: Text(userId,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF999999))),
                      trailing: TextButton(
                        onPressed: () => _removeMember(userId),
                        child: Text(l10n.blacklistRemove,
                            style: const TextStyle(color: Colors.red)),
                      ),
                    );
                  },
                ),
    );
  }
}
