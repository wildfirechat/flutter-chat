import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/group_info.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:chat/wfc_scheme.dart';
import 'package:chat/widget/portrait.dart';

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
    String qrCodeValue = WfcScheme.buildGroupScheme(widget.groupInfo.target, Imclient.currentUserId);

    return Scaffold(
      appBar: AppBar(
        title: const Text("群二维码"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Portrait(
                      groupInfo?.portrait ?? '',
                      groupInfo?.name ?? '',
                      width: 60,
                      height: 60,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      groupInfo?.name ?? '',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 250,
                  height: 250,
                  child: QrImageView(
                    data: qrCodeValue,
                    version: QrVersions.auto,
                    size: 250.0,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "扫一扫上面的二维码，加入群聊",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
