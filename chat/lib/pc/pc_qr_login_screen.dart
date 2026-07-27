import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/imclient_platform.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chat/app_server.dart';
import 'package:chat/app_theme.dart';
import 'package:chat/config.dart';
import 'package:chat/login/login_form_controller.dart';
import 'package:chat/main.dart';
import 'package:chat/pc/pc_home.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/pc_window_manager.dart';
import 'package:chat/pc/widgets/pc_window_caption.dart';
import 'package:chat/utilities.dart';
import 'package:chat/utils/show_toast.dart';
import 'package:chat/utils/media_url_redirector.dart';
import 'package:chat/wfc_scheme.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';

enum _PCLoginView { qr, form }

/// 桌面端登录页:默认二维码登录,可切换到验证码/密码表单。
/// 二维码流程:
/// 1. AppServer.createPcSession 获取 token;
/// 2. 展示 wildfirechat://pcsession/{token} 二维码;
/// 3. 轮询 pollPcSessionLogin,扫码后展示用户头像并支持取消;
/// 4. 确认后保存 userId/token 并连接 IM,进入 [PCHome]。
/// 表单登录逻辑在共享的 [LoginFormController](与移动端 LoginScreen 同一套)。
class PCQRLoginScreen extends StatefulWidget {
  const PCQRLoginScreen({super.key});

  @override
  State<PCQRLoginScreen> createState() => _PCQRLoginScreenState();
}

class _PCQRLoginScreenState extends State<PCQRLoginScreen> {
  // ===== QR 模式状态 =====
  String? _token;
  String? _error;
  bool _isPolling = false;
  // 慢响应时上一次轮询可能还没返回,in-flight 守卫避免请求叠加
  bool _pollInFlight = false;
  Timer? _pollTimer;
  bool _loginSuccess = false;
  bool _isScanned = false;
  String? _scannedUserPortrait;
  String? _scannedUserName;

  // ===== 视图模式 =====
  _PCLoginView _currentView = _PCLoginView.qr;

  // 协议链接手势:build 中创建会泄漏,作为 State 字段统一在 dispose 释放
  late final TapGestureRecognizer _userAgreementRecognizer;
  late final TapGestureRecognizer _privacyPolicyRecognizer;

  // ===== 表单模式(共享控制器) =====
  final LoginFormController _form = LoginFormController();

  @override
  void initState() {
    super.initState();
    // 登录页一律用固定小窗。启动时未登录由 PCWindowManager.setupWindow 直接设好
    // (要赶在窗口第一次 show 之前,免得闪一下主界面尺寸);登出、被踢下线、token
    // 失效等回到登录页的路径都收在这里,不再逐个调用点去改窗口。重复调用无副作用。
    PCWindowManager().applyLoginWindow();
    _userAgreementRecognizer = TapGestureRecognizer()
      ..onTap = () => Utilities.openLink(context, Config.USER_AGREEMENT_URL);
    _privacyPolicyRecognizer = TapGestureRecognizer()
      ..onTap = () => Utilities.openLink(context, Config.PRIVACY_AGREEMENT_URL);
    _createSession();
    _form.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _userAgreementRecognizer.dispose();
    _privacyPolicyRecognizer.dispose();
    _form.removeListener(_onFormChanged);
    _form.dispose();
    super.dispose();
  }

  void _onFormChanged() => setState(() {});

  // ==================== QR 模式逻辑 ====================

  Future<void> _createSession() async {
    if (!isDesktopShell) {
      setState(() {
        _error = AppLocalizations.of(context)!.desktopOnly;
      });
      return;
    }

    final platform = _detectPlatform();
    AppServer.createPcSession(platform, (token) {
      if (mounted) {
        setState(() {
          _token = token;
          _error = null;
          _isScanned = false;
          _scannedUserPortrait = null;
          _scannedUserName = null;
        });
        _startPolling(token);
      }
    }, (errorMsg) {
      if (mounted) {
        setState(() {
          _error = errorMsg;
        });
      }
    });
  }

  /// WFC 平台编号:Windows 3 / macOS 4 / Linux 7 / 鸿蒙手机 10 / 平板 11 / 电脑 12。
  int _detectPlatform() {
    return WfcPlatform.clientPlatformCode;
  }

  void _startPolling(String token) {
    if (_isPolling) {
      return;
    }
    _isPolling = true;

    _doPoll();
    _startPollTimer();
  }

  void _startPollTimer() {
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted && !_loginSuccess) {
        _doPoll();
      }
    });
  }

  void _doPoll() {
    final token = _token;
    if (token == null || _pollInFlight || _loginSuccess) {
      return;
    }
    _pollInFlight = true;
    AppServer.pollPcSessionLogin(
      token,
      (userId, imToken) async {
        _pollInFlight = false;
        // 登录成功
        _pollTimer?.cancel();
        _pollTimer = null;
        if (!mounted || _loginSuccess) {
          return;
        }
        _loginSuccess = true;
        await _saveAndConnect(userId, imToken);
      },
      (scannedUser) {
        _pollInFlight = false;
        // 扫码但未确认: 服务端 LoginResponse 中 userName 实际是 displayName, portrait 是头像URL
        if (mounted && !_loginSuccess) {
          setState(() {
            _isScanned = true;
            _scannedUserPortrait = scannedUser['portrait'];
            _scannedUserName = scannedUser['userName'];
          });
        }
      },
      (errorMsg) {
        _pollInFlight = false;
        debugPrint('pollPcSessionLogin: $errorMsg');
      },
    );
  }

  /// 切换二维码/表单视图。切到表单时暂停轮询 Timer,切回二维码时恢复。
  void _switchView(_PCLoginView view) {
    if (_currentView == view) {
      return;
    }
    setState(() => _currentView = view);
    if (view == _PCLoginView.form) {
      _pollTimer?.cancel();
      _pollTimer = null;
    } else if (_isPolling && _pollTimer == null && _token != null && !_loginSuccess) {
      _doPoll();
      _startPollTimer();
    }
  }

  Future<void> _cancelScan() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    _isPolling = false;

    // 调用取消接口
    if (_token != null) {
      AppServer.cancelPCLogin(_token!, () {}, (error) {
        debugPrint('cancelPCLogin error: $error');
      });
    }

    // 重置到扫码状态
    setState(() {
      _token = null;
      _error = null;
      _isScanned = false;
      _scannedUserPortrait = null;
      _scannedUserName = null;
    });
    _createSession();
  }

  Future<void> _saveAndConnect(String userId, String imToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', userId);
    await prefs.setString('token', imToken);

    Imclient.connect(Config.IM_Host, userId, imToken);

    if (mounted) {
      MyApp.of(context)?.onLoginSuccess(userId);
    }

    if (mounted) {
      showToast(msg: AppLocalizations.of(context)!.loginSuccess);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PCHome()),
      );
    }
  }

  void _refresh() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _isPolling = false;
    _loginSuccess = false;
    setState(() {
      _token = null;
      _error = null;
      _isScanned = false;
      _scannedUserPortrait = null;
      _scannedUserName = null;
    });
    _createSession();
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    if (_currentView == _PCLoginView.form) {
      return _buildFormView();
    }
    return _buildQrView();
  }

  /// 登录窗外壳,QR 与表单视图共用。
  /// 登录窗本身就是一张固定小窗(见 PCWindowManager 的登录形态),所以内容直接
  /// 铺满整窗、用一种面色到底,不再做"浮在背景上的卡片"——小窗里再套卡片只会
  /// 剩下一圈无意义的留白。
  Widget _buildShell({required Widget child}) {
    return Column(
      children: [
        // Windows 自绘标题栏(系统标题栏已隐藏,见 PCWindowManager.setupWindow)。
        // 登录窗是固定尺寸,不给最大化入口。
        if (Platform.isWindows) const PcWindowCaption(canMaximize: false),
        Expanded(
          child: Scaffold(
            backgroundColor: context.colors.surface,
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Center(child: child),
            ),
          ),
        ),
      ],
    );
  }

  // ===== QR 视图 =====
  Widget _buildQrView() {
    final l10n = AppLocalizations.of(context)!;
    final qrData = _token != null ? '${WfcScheme.qrCodePrefixPcSession}$_token' : '';

    // 登录窗是固定小窗,最大字号档 + 出错重试文案时卡片会顶到高度上限,
    // 这里跟表单视图一样套一层滚动,避免溢出。
    return _buildShell(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.appTitle,
              style: AppText.xxl.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _isScanned ? l10n.scanned : l10n.pcLoginQrHint,
              style: AppText.base.copyWith(color: context.colors.textSecondary),
            ),
            const SizedBox(height: 32),
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                // 二维码必须白底黑码才扫得出来,暗色下也钉死白色,做成卡片上的一块白板
                color: Colors.white,
                border: Border.all(color: context.colors.hairline),
                borderRadius: BorderRadius.circular(4),
              ),
              child: _buildQrContent(qrData),
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              Text(
                _error!,
                style: AppText.sm.copyWith(color: context.colors.danger),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _refresh,
                child: Text(l10n.retry),
              ),
            ],
            const SizedBox(height: 16),
            if (_isScanned)
              // 已扫码：显示取消按钮
              TextButton(
                onPressed: _cancelScan,
                child: Text(l10n.cancel, style: TextStyle(color: context.colors.danger)),
              )
            else
              // 未扫码：显示验证码/密码登录按钮
              TextButton(
                onPressed: () => _switchView(_PCLoginView.form),
                child: Text(l10n.loginWithCodeOrPassword),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrContent(String qrData) {
    if (_isScanned && _scannedUserPortrait != null) {
      // 已扫码：显示扫码用户头像
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipOval(
            child: _scannedUserPortrait!.startsWith('http')
                ? Image.network(
                    MediaUrlRedirector.redirect(_scannedUserPortrait!),
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 80, color: Color(0xFFCCCCCC)),
                  )
                : const Icon(Icons.person, size: 80, color: Color(0xFFCCCCCC)),
          ),
          if (_scannedUserName != null) ...[
            const SizedBox(height: 8),
            Text(
              _scannedUserName!,
              // QR 白板之上,固定深色字
              style: AppText.base.copyWith(color: Color(0xFF333333)),
            ),
          ],
        ],
      );
    }
    if (_error != null && _token == null) {
      return Center(child: Icon(Icons.error_outline, color: context.colors.danger, size: 48));
    }
    if (qrData.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return QrImageView(
      data: qrData,
      version: QrVersions.auto,
      size: 200,
      backgroundColor: Colors.white,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Colors.black,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Colors.black,
      ),
    );
  }

  // ===== 表单视图(状态与流程在 LoginFormController) =====
  Widget _buildFormView() {
    final l10n = AppLocalizations.of(context)!;

    return _buildShell(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部留白,避开 macOS 沉浸式标题栏区域的交通灯按钮。
            SizedBox(height: Platform.isMacOS ? 52 : 12),
            Center(
              child: Text(
                _form.isPasswordLogin ? l10n.loginWithPassword : l10n.loginCodeTitle,
                style: AppText.xl.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),
            // 手机号输入
            TextField(
              controller: _form.phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: l10n.phoneNumberHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            // 验证码或密码输入行
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _form.codeOrPwdController,
                    obscureText: _form.isPasswordLogin,
                    decoration: InputDecoration(
                      hintText: _form.isPasswordLogin ? l10n.inputPassword : l10n.inputVerificationCode,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
                if (!_form.isPasswordLogin) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 46,
                    child: FilledButton(
                      onPressed: _form.canSendCode ? () => _form.sendCode(context) : null,
                      child: _form.isSentCode ? Text('${_form.waitResendCount}s') : Text(l10n.sendCode),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            // 协议勾选
            Row(
              children: [
                Checkbox(
                  value: _form.agreementChecked,
                  onChanged: (bool? value) {
                    _form.agreementChecked = value!;
                  },
                ),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      text: l10n.readAndAgree,
                      style: TextStyle(color: context.colors.textPrimary),
                      children: <TextSpan>[
                        TextSpan(
                          text: l10n.userAgreement,
                          style: TextStyle(color: context.colors.link),
                          recognizer: _userAgreementRecognizer,
                        ),
                        TextSpan(text: l10n.and),
                        TextSpan(
                          text: l10n.privacyPolicy,
                          style: TextStyle(color: context.colors.link),
                          recognizer: _privacyPolicyRecognizer,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 登录按钮
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                onPressed: _form.canSubmit ? () => _form.submit(context) : null,
                // 整页唯一主行动,叠大档(高度由外层 46 钉死,与上方输入框等高)。
                style: AppTheme.largeButtonStyle(),
                child: Text(l10n.login),
              ),
            ),
            const SizedBox(height: 8),
            // 切换验证码/密码登录
            Center(
              child: TextButton(
                onPressed: _form.toggleLoginMode,
                child: Text(_form.isPasswordLogin ? l10n.loginWithPhoneCode : l10n.loginWithPassword),
              ),
            ),
            // 回二维码登录。原先是页面左上角的返回箭头,不如和上面的登录方式切换
            // 放在一起更好找,也不用为它单独留一行返回栏的高度。
            Center(
              child: TextButton(
                onPressed: () => _switchView(_PCLoginView.qr),
                child: Text(l10n.loginWithQrCode),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
