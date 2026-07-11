import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/user_info.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/config.dart';
import 'package:chat/utils/mesh_user_name.dart';
import 'package:chat/mesh/mesh_cache.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:chat/theme/app_typography.dart';

/// 黑名单管理页面
///
/// 显示黑名单用户列表，支持移出黑名单
class BlacklistScreen extends StatefulWidget {
  const BlacklistScreen({super.key});

  @override
  State<BlacklistScreen> createState() => _BlacklistScreenState();
}

class _BlacklistScreenState extends State<BlacklistScreen> {
  List<String> _blacklist = [];
  final Map<String, UserInfo?> _userInfoCache = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBlacklist();
  }

  Future<void> _loadBlacklist() async {
    setState(() => _loading = true);
    try {
      final list = await Imclient.getBlackList(refresh: true);
      _blacklist = list;

      // 批量获取用户信息
      if (list.isNotEmpty) {
        final users = await Imclient.getUserInfos(list, groupId: '');
        for (final user in users) {
          _userInfoCache[user.userId] = user;
        }
      }
    } catch (e) {
      debugPrint('Blacklist load error: $e');
    }
    setState(() => _loading = false);
  }

  Future<void> _removeFromBlacklist(String userId) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.removeFromBlacklist),
        content: Text(l10n.removeFromBlacklistConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      Imclient.setBlackList(userId, false, () {
        _loadBlacklist();
        Fluttertoast.showToast(msg: l10n.removedFromBlacklist);
      }, (code) {
        Fluttertoast.showToast(msg: l10n.operateFail('$code'));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.blacklist),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _blacklist.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadBlacklist,
                  child: ListView.separated(
                    itemCount: _blacklist.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                    itemBuilder: (context, index) {
                      final userId = _blacklist[index];
                      final userInfo = _userInfoCache[userId];
                      return _buildUserItem(userId, userInfo);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.block, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context)!.blacklistEmpty,
              style: AppText.lg.copyWith(color: Color(0xFF999999))),
        ],
      ),
    );
  }

  Widget _buildUserItem(String userId, UserInfo? userInfo) {
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
          return userInfo != null ? MeshUserName(userInfo) : Text(userId);
        },
      ),
      subtitle: Text(userId, style: AppText.xs.copyWith(color: Color(0xFF999999))),
      trailing: TextButton(
        onPressed: () => _removeFromBlacklist(userId),
        child: Text(AppLocalizations.of(context)!.blacklistRemove,
            style: const TextStyle(color: Colors.red)),
      ),
    );
  }
}
