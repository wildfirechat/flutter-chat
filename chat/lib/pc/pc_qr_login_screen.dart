import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chat/app_server.dart';
import 'package:chat/config.dart';
import 'package:chat/login/login_form_controller.dart';
import 'package:chat/main.dart';
import 'package:chat/pc/pc_home.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/utilities.dart';
import 'package:chat/utils/show_toast.dart';
import 'package:chat/utils/media_url_redirector.dart';
import 'package:chat/wfc_scheme.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/theme/app_colors.dart';

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
  Timer? _pollTimer;
  bool _loginSuccess = false;
  bool _isScanned = false;
  String? _scannedUserPortrait;
  String? _scannedUserName;

  // ===== 视图模式 =====
  _PCLoginView _currentView = _PCLoginView.qr;

  // ===== 表单模式(共享控制器) =====
  final LoginFormController _form = LoginFormController();

  @override
  void initState() {
    super.initState();
    _createSession();
    _form.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
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

  /// WFC 平台编号:Windows 3 / macOS 4 / Linux 7 / 其它 10。
  int _detectPlatform() {
    if (Platform.isWindows) return 3;
    if (Platform.isMacOS) return 4;
    if (Platform.isLinux) return 7;
    return 10;
  }

  void _startPolling(String token) {
    if (_isPolling) {
      return;
    }
    _isPolling = true;

    void doPoll() {
      AppServer.pollPcSessionLogin(
        token,
        (userId, imToken) async {
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
          debugPrint('pollPcSessionLogin: $errorMsg');
        },
      );
    }

    doPoll();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted && !_loginSuccess) {
        doPoll();
      }
    });
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

  /// 登录卡片外壳:圆角、投影,QR 与表单视图共用。
  /// 卡片与页面刻意取不同的面色 —— 暗色下投影看不见,只能靠明度差把卡片托起来。
  Widget _buildCard({required Widget child}) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.chatBgDesktop,
      body: Center(
        child: Container(
          width: 400,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  // ===== QR 视图 =====
  Widget _buildQrView() {
    final l10n = AppLocalizations.of(context)!;
    final qrData = _token != null ? '${WfcScheme.qrCodePrefixPcSession}$_token' : '';

    return _buildCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.appTitle,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            _isScanned ? l10n.scanned : l10n.pcLoginQrHint,
            style: TextStyle(fontSize: 14, color: context.colors.textSecondary),
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
              style: TextStyle(color: context.colors.danger, fontSize: 13),
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
              onPressed: () => setState(() => _currentView = _PCLoginView.form),
              child: Text(l10n.loginWithCodeOrPassword),
            ),
        ],
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
              style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
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
    );
  }

  // ===== 表单视图(状态与流程在 LoginFormController) =====
  Widget _buildFormView() {
    final l10n = AppLocalizations.of(context)!;

    return _buildCard(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 返回按钮 (放低以避开 macOS 窗口按钮,约 40px 区域)
            SizedBox(
              height: Platform.isMacOS ? 52 : 12,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _currentView = _PCLoginView.qr),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_ios, size: 16, color: context.colors.link),
                        const SizedBox(width: 4),
                        Text(
                          l10n.loginCodeTitle,
                          style: TextStyle(fontSize: 14, color: context.colors.link),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                _form.isPasswordLogin ? l10n.loginWithPassword : l10n.loginCodeTitle,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                    child: ElevatedButton(
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
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Utilities.openLink(context, Config.USER_AGREEMENT_URL);
                            },
                        ),
                        TextSpan(text: l10n.and),
                        TextSpan(
                          text: l10n.privacyPolicy,
                          style: TextStyle(color: context.colors.link),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Utilities.openLink(context, Config.PRIVACY_AGREEMENT_URL);
                            },
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
              child: ElevatedButton(
                onPressed: _form.canSubmit ? () => _form.submit(context) : null,
                child: Text(l10n.login),
              ),
            ),
            const SizedBox(height: 8),
            // 切换登录方式
            Center(
              child: TextButton(
                onPressed: _form.toggleLoginMode,
                child: Text(_form.isPasswordLogin ? l10n.loginWithPhoneCode : l10n.loginWithPassword),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
