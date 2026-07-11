import 'package:flutter/material.dart';
import 'package:imclient/model/domain_info.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/widgets/pc_page_header.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/utils/show_toast.dart';

import '../contact/search_user.dart';
import 'mesh_cache.dart';
import 'package:chat/theme/app_typography.dart';

/// Mesh 外部单位/域详情页。
class DomainProfileScreen extends StatefulWidget {
  final String domainId;

  const DomainProfileScreen({
    super.key,
    required this.domainId,
  });

  @override
  State<DomainProfileScreen> createState() => _DomainProfileScreenState();
}

class _DomainProfileScreenState extends State<DomainProfileScreen> {
  DomainInfo? _domainInfo;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDomainInfo();
  }

  Future<void> _loadDomainInfo() async {
    setState(() => _loading = true);
    try {
      final info = await MeshCache.instance.loadDomainInfo(widget.domainId, refresh: true);
      if (mounted) {
        setState(() {
          _domainInfo = info;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showToast(msg: e.toString());
      }
    }
  }

  void _searchUsersInDomain() {
    final delegate = SearchUserDelegate(domainId: widget.domainId);
    showSearch(context: context, delegate: delegate);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final body = _buildBody(context, l10n);
    if (isDesktopShell) {
      return Scaffold(
        backgroundColor: context.colors.chatBgDesktop,
        appBar: PcPageHeader(title: _domainInfo?.name ?? l10n.domainInfo),
        body: body,
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(_domainInfo?.name ?? l10n.domainInfo)),
      body: body,
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final info = _domainInfo;
    if (info == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.loadDomainFail('')),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadDomainInfo,
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoTile(l10n.domainName, info.name),
          if (info.desc != null && info.desc!.isNotEmpty)
            _buildInfoTile(l10n.domainDesc, info.desc!),
          if (info.email != null && info.email!.isNotEmpty)
            _buildInfoTile(l10n.domainEmail, info.email!),
          if (info.tel != null && info.tel!.isNotEmpty)
            _buildInfoTile(l10n.domainTel, info.tel!),
          if (info.address != null && info.address!.isNotEmpty)
            _buildInfoTile(l10n.domainAddress, info.address!),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _searchUsersInDomain,
                child: Text(l10n.searchUserInDomain),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.xs.copyWith(color: context.colors.textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: AppText.lg.copyWith(color: context.colors.textPrimary)),
        ],
      ),
    );
  }
}
