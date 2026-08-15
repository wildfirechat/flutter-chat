import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/group_info.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:chat/wfc_scheme.dart';
import 'package:chat/widget/portrait.dart';
import 'package:chat/pc/widgets/pc_page_header.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/app_shell.dart';

class GroupQrCodeScreen extends StatefulWidget {
  final GroupInfo groupInfo;

  const GroupQrCodeScreen({super.key, required this.groupInfo});

  @override
  State<StatefulWidget> createState() => _GroupQrCodeState();
}

class _GroupQrCodeState extends State<GroupQrCodeScreen> {
  GroupInfo? groupInfo;

  @override
  void initState() {
    super.initState();
    _fetchGroupInfo();
  }

  void _fetchGroupInfo() async {
    groupInfo = widget.groupInfo;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    String qrCodeValue = WfcScheme.buildGroupScheme(
        widget.groupInfo.target, Imclient.currentUserId);

    return Scaffold(
      appBar: AppShell.isDesktopStyle
          ? PcPageHeader(
              title: l10n.groupQrCode,
              onBack: () => Navigator.of(context).maybePop(),
            )
          : AppBar(
              title: Text(l10n.groupQrCode),
            ),
      backgroundColor: AppShell.isDesktopStyle
          ? context.colors.chatBgDesktop
          : context.colors.primaryBackground,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 250,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Portrait(
                      groupInfo?.portrait ?? '',
                      groupInfo?.name ?? '',
                      width: 60,
                      height: 60,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      groupInfo?.name ?? '',
                      style: AppText.xl.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.colors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SizedBox(
                  width: 226,
                  height: 226,
                  child: QrImageView(
                    data: qrCodeValue,
                    version: QrVersions.auto,
                    size: 226.0,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.scanQrCodeToJoinGroup,
                style:
                    AppText.base.copyWith(color: context.colors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
