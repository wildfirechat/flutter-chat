import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:chat/app_server.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/widgets/pc_page_header.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/widget/app_bar_actions.dart';
import 'package:chat/l10n/app_localizations.dart';

class GroupAnnouncementScreen extends StatefulWidget {
  final String groupId;
  final bool canEdit;

  const GroupAnnouncementScreen({
    super.key,
    required this.groupId,
    required this.canEdit,
  });

  @override
  State<GroupAnnouncementScreen> createState() =>
      _GroupAnnouncementScreenState();
}

class _GroupAnnouncementScreenState extends State<GroupAnnouncementScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = true;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadAnnouncement();
  }

  void _loadAnnouncement() {
    AppServer.getGroupAnnouncement(widget.groupId, (text) {
      if (mounted) {
        setState(() {
          _controller.text = text;
          _isLoading = false;
        });
      }
    }, (msg) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        Fluttertoast.showToast(
            msg: AppLocalizations.of(context)!.getGroupAnnouncementFailed(msg));
      }
    });
  }

  void _saveAnnouncement() {
    final l10n = AppLocalizations.of(context)!;
    if (_controller.text.isEmpty) {
      Fluttertoast.showToast(msg: l10n.groupAnnouncementEmpty);
      return;
    }
    AppServer.updateGroupAnnouncement(widget.groupId, _controller.text, () {
      Fluttertoast.showToast(msg: l10n.updateGroupAnnouncementSuccess);
      if (mounted) {
        setState(() {
          _isEditing = false;
        });
      }
    }, (msg) {
      Fluttertoast.showToast(msg: l10n.updateGroupAnnouncementFailed(msg));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final actions = [
      if (widget.canEdit && !_isLoading)
        AppBarTextAction(
          label: _isEditing ? l10n.done : l10n.edit,
          onPressed: () {
            if (_isEditing) {
              _saveAnnouncement();
            } else {
              setState(() {
                _isEditing = true;
              });
            }
          },
        ),
    ];

    return Scaffold(
      appBar: isDesktopShell
          ? PcPageHeader(
              title: l10n.groupAnnouncement,
              onBack: () => Navigator.of(context).maybePop(),
              actions: actions,
            )
          : AppBar(
              title: Text(l10n.groupAnnouncement),
              actions: actions,
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _controller,
                enabled: _isEditing,
                maxLines: null,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: l10n.noGroupAnnouncementHint,
                ),
              ),
            ),
    );
  }
}
