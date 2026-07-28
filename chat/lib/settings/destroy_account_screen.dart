import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chat/app_navigator.dart';
import 'package:chat/app_server.dart';
import 'package:chat/app_theme.dart';
import 'package:chat/config.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/organization/organization_service.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/widgets/pc_page_header.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/utils/show_toast.dart';
import 'package:chat/widget/slide_verify_dialog.dart';

/// 注销账号流程页(App Store 审核指南 5.1.1(v) 要求)。
/// 交互对齐原生 iOS WFCDestroyAccountViewController:发送短信验证码(可过滑块验证)
/// → 输入验证码 → 确认注销 → 服务端销毁账号 → 清理本地登录态并回到登录页。
class DestroyAccountScreen extends StatefulWidget {
  const DestroyAccountScreen({super.key});

  @override
  State<DestroyAccountScreen> createState() => _DestroyAccountScreenState();
}

class _DestroyAccountScreenState extends State<DestroyAccountScreen> {
  final TextEditingController _codeController = TextEditingController();

  bool _isSentCode = false;
  int _waitResendCount = 0;
  Timer? _resendTimer;
  bool _destroying = false;

  bool get _canSendCode => !_isSentCode && !_destroying;
  bool get _canSubmit => _codeController.text.length >= 4 && !_destroying;

  @override
  void initState() {
    super.initState();
    _codeController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  /// 发送注销验证码:开启滑块验证时先验证,通过后携带 token 请求服务端发码。
  void _sendCode() {
    final l10n = AppLocalizations.of(context)!;
    if (!Config.ENABLE_SLIDE_VERIFY) {
      AppServer.sendDestroyAccountCode(() {
        showToast(msg: l10n.sendCodeSuccess);
        _startResendCountdown();
      }, (msg) => showToast(msg: l10n.sendCodeFailWithError(msg)));
      return;
    }
    SlideVerifyDialog.show(
      context: context,
      listener: _DestroyCodeSlideVerifyListener(
        onSent: () {
          showToast(msg: l10n.sendCodeSuccess);
          _startResendCountdown();
        },
        onError: (msg) => showToast(msg: l10n.sendCodeFailWithError(msg)),
      ),
    );
  }

  void _startResendCountdown() {
    _waitResendCount = 0;
    _isSentCode = true;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _waitResendCount++;
      if (_waitResendCount >= 60) {
        _isSentCode = false;
        timer.cancel();
      }
      setState(() {});
    });
    setState(() {});
  }

  /// 确认注销:服务端销毁成功后清理本地登录态(SharedPreferences 凭证、
  /// 组织服务鉴权信息),断开 IM 并回到登录页,与原生销毁成功后的处理一致。
  void _destroy() {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _destroying = true);
    AppServer.destroyAccount(_codeController.text, () async {
      final prefs = await SharedPreferences.getInstance();
      prefs.remove('userId');
      prefs.remove('token');
      prefs.remove('app_server_auth_token');
      OrganizationService.instance.clearOrgServiceAuthInfos();
      // 服务端已删除账号所有信息,断开时不再与 IM 服务交互推送/会话标记。
      Imclient.disconnect(disablePush: false, clearSession: false);
      if (mounted) {
        navigateToLogin(Navigator.of(context, rootNavigator: true));
      }
    }, (msg) {
      showToast(msg: l10n.destroyAccountFail(msg));
      if (mounted) {
        setState(() => _destroying = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: isDesktopShell
          ? PcPageHeader(title: l10n.destroyAccount)
          : AppBar(title: Text(l10n.destroyAccount)),
      backgroundColor: isDesktopShell ? context.colors.chatBgDesktop : context.colors.primaryBackground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 40, 8, 10),
              child: Text(
                l10n.destroyAccountTitle,
                style: AppText.lg,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      placeholder: l10n.inputVerificationCode,
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      clearButtonMode: OverlayVisibilityMode.editing,
                      autocorrect: false,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _canSendCode ? _sendCode : null,
                    child: _isSentCode ? Text('${60 - _waitResendCount} s') : Text(l10n.sendCode),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _canSubmit ? _destroy : null,
              // 整页唯一主行动,叠大档。
              style: AppTheme.largeButtonStyle(),
              child: Text(l10n.destroyAccount),
            ),
          ],
        ),
      ),
    );
  }
}

/// 注销发码的滑动验证监听:验证通过 → 携带 token 请求服务端发码。
class _DestroyCodeSlideVerifyListener implements SlideVerifyListener {
  final VoidCallback onSent;
  final void Function(String msg) onError;

  _DestroyCodeSlideVerifyListener({required this.onSent, required this.onError});

  @override
  void onVerifySuccess(String token) {
    AppServer.sendDestroyAccountCode(onSent, onError, slideVerifyToken: token);
  }

  @override
  void onVerifyFailed() {}

  @override
  void onLoadFailed() {}
}
