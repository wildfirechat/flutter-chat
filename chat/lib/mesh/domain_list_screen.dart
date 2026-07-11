import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/domain_info.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/widgets/pc_page_header.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/app_navigator.dart';

import 'domain_profile_screen.dart';

/// Mesh 外部单位/域列表页。
///
/// - 移动端：push 全屏页
/// - PC 端：可通过 [selectMode] 作为选择器，选中后回调 [onSelected]
class DomainListScreen extends StatefulWidget {
  final bool selectMode;
  final ValueChanged<String>? onSelected;

  const DomainListScreen({
    super.key,
    this.selectMode = false,
    this.onSelected,
  });

  @override
  State<DomainListScreen> createState() => _DomainListScreenState();
}

class _DomainListScreenState extends State<DomainListScreen> {
  List<DomainInfo> _domains = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDomains();
  }

  Future<void> _loadDomains() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final domains = await Imclient.getRemoteDomains();
      if (mounted) {
        setState(() {
          _domains = domains;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _onDomainTap(DomainInfo domain) {
    if (widget.selectMode && widget.onSelected != null) {
      widget.onSelected!(domain.domainId);
      return;
    }
    pushPage(context, DomainProfileScreen(domainId: domain.domainId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final body = _buildBody(context, l10n);
    if (isDesktopShell) {
      return Scaffold(
        backgroundColor: context.colors.chatBgDesktop,
        appBar: PcPageHeader(title: l10n.mesh),
        body: body,
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mesh)),
      body: body,
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.loadDomainFail(_error!)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadDomains,
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }
    if (_domains.isEmpty) {
      return Center(child: Text(l10n.noOrganizationData));
    }
    return RefreshIndicator(
      onRefresh: _loadDomains,
      child: ListView.separated(
        itemCount: _domains.length,
        separatorBuilder: (_, __) => const Divider(height: 0.5, indent: 16),
        itemBuilder: (context, index) {
          final domain = _domains[index];
          return ListTile(
            leading: const Icon(Icons.domain),
            title: Text(domain.name),
            subtitle: domain.desc != null && domain.desc!.isNotEmpty
                ? Text(domain.desc!, maxLines: 1, overflow: TextOverflow.ellipsis)
                : null,
            trailing: widget.selectMode ? const Icon(Icons.chevron_right) : null,
            onTap: () => _onDomainTap(domain),
          );
        },
      ),
    );
  }
}
