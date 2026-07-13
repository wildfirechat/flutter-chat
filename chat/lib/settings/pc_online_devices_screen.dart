import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/model/pc_online_info.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/widget/app_switch.dart';

class PCOnlineDevicesScreen extends StatefulWidget {
  const PCOnlineDevicesScreen({super.key});

  @override
  State<PCOnlineDevicesScreen> createState() => _PCOnlineDevicesScreenState();
}

class _PCOnlineDevicesScreenState extends State<PCOnlineDevicesScreen> {
  List<PCOnlineInfo> _onlineInfos = [];
  bool _isMute = false;

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
      });
    }
  }

  void _kickClient(PCOnlineInfo info) {
    Imclient.kickoffPCClient(info.clientId, () {
      Fluttertoast.showToast(msg: AppLocalizations.of(context)!.kickedOffline);
      _loadData();
    }, (err) {
      Fluttertoast.showToast(msg: AppLocalizations.of(context)!.operateFail(err.toString()));
    });
  }

  void _toggleMute(bool value) {
    Imclient.muteNotificationWhenPcOnline(value, () {
      setState(() {
        _isMute = value;
      });
    }, (err) {
      Fluttertoast.showToast(msg: AppLocalizations.of(context)!.setFail(err.toString()));
      setState(() {
        _isMute = !_isMute;
      });
    });
  }

  String _getPlatformName(int platform) {
    // 0 pc; 1 web; 2 micro app
    // But PCOnlineInfo definition says: 0 pc; 1 web; 2 micro app
    // Wait, platform type enum?
    // Let's just use the type field from PCOnlineInfo if it maps to that.
    // Actually PCOnlineInfo has `type` and `platform`.
    // In StatusNotificationHeader I used `type`.
    // Let's check PCOnlineInfo definition again.
    return "PC";
  }

  String _getDeviceName(PCOnlineInfo info) {
    if (info.type == 0) return AppLocalizations.of(context)!.pcClient;
    if (info.type == 1) return AppLocalizations.of(context)!.webClient;
    if (info.type == 2) return AppLocalizations.of(context)!.miniProgram;
    return AppLocalizations.of(context)!.unknownDevice;
  }

  IconData _getDeviceIcon(PCOnlineInfo info) {
    if (info.type == 0) return Icons.computer;
    if (info.type == 1) return Icons.web;
    if (info.type == 2) return Icons.smartphone;
    return Icons.device_unknown;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f5f5),
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.pcOnlineDevices),
        elevation: 0,
      ),
      body: _onlineInfos.isEmpty
          ? Center(child: Text(AppLocalizations.of(context)!.noPcOnline))
          : Column(
              children: [
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      const Icon(Icons.computer, size: 80, color: Colors.green),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.pcOnlineDeviceCount(_onlineInfos.length.toString()),
                        style: AppText.lg.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(
                          AppLocalizations.of(context)!.mobileMute,
                          style: AppText.lg,
                        ),
                        subtitle: Text(
                          AppLocalizations.of(context)!.mobileMuteDesc,
                          style: AppText.base.copyWith(color: context.colors.textSecondary),
                        ),
                        onTap: () => _toggleMute(!_isMute),
                        trailing: AppSwitch(
                          value: _isMute,
                          onChanged: _toggleMute,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    itemCount: _onlineInfos.length,
                    itemBuilder: (context, index) {
                      var info = _onlineInfos[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          leading: Icon(_getDeviceIcon(info), size: 36, color: Colors.grey),
                          title: Text(_getDeviceName(info)),
                          subtitle: Text("${AppLocalizations.of(context)!.loginTime}${DateTime.fromMillisecondsSinceEpoch(info.timestamp).toString().substring(0, 16)}"),
                          trailing: FilledButton.tonal(
                            onPressed: () => _kickClient(info),
                            // 危险次要:灰底无边框,只换前景色,形态走全局按钮主题。
                            style: FilledButton.styleFrom(foregroundColor: context.colors.danger),
                            child: Text(AppLocalizations.of(context)!.logout),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
