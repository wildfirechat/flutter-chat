import 'package:flutter/material.dart';
import 'package:chat/app_server.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/call/conference/conference_info_view.dart';
import 'package:chat/l10n/app_localizations.dart';

/// 加入会议页面
class JoinConferenceView extends StatefulWidget {
  final String? initialConferenceId;

  const JoinConferenceView({Key? key, this.initialConferenceId})
      : super(key: key);

  @override
  State<JoinConferenceView> createState() => _JoinConferenceViewState();
}

class _JoinConferenceViewState extends State<JoinConferenceView> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialConferenceId != null) {
      _idController.text = widget.initialConferenceId!;
    }
  }

  void _queryInfo() {
    if (_idController.text.isEmpty) return;
    setState(() => _loading = true);
    AppServer.queryConferenceInfo(_idController.text, _pinController.text,
        (info) {
      setState(() => _loading = false);
      _showConferenceInfo(info);
    }, (error) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!
                .conferenceQueryFailedWithError(error))),
      );
    });
  }

  void _showConferenceInfo(Map<String, dynamic> info) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.popupBg,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => ConferenceInfoView(
          conferenceInfo: info,
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.colors.primaryBackground,
      appBar: AppBar(
        title: Text(l10n.conferenceJoinMeeting),
        backgroundColor: context.colors.surface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _idController,
              style: TextStyle(color: context.colors.textPrimary),
              decoration:
                  InputDecoration(labelText: l10n.conferenceIdInputLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pinController,
              style: TextStyle(color: context.colors.textPrimary),
              decoration: InputDecoration(labelText: l10n.conferencePassword),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _queryInfo,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.conferenceQuery),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
