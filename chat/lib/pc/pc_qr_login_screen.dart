import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:imclient/imclient.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chat/app_server.dart';
import 'package:chat/config.dart';
import 'package:chat/pc/pc_home.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/utilities.dart';
import 'package:chat/utils/show_toast.dart';
import 'package:chat/wfc_scheme.dart';
import 'package:chat/widget/slide_verify_dialog.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

enum _PCLoginView { qr, form }

/// 桌面端二维码登录页。
/// 流程:
/// 1. 调用 AppServer.createPcSession 获取 token;
/// 2. 用 qr_flutter 展示 wildfirechat://pcsession/{token} 二维码;
/// 3. 轮询 AppServer.pollPcSessionLogin, 扫码后展示用户头像并支持取消;
/// 4. 确认后保存 userId/token 并连接 IM,进入 [PCHome];
/// 5. 支持切换到验证码/密码登录表单。
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

  // ===== 表单模式状态 =====
  bool isSentCode = false;
  int waitResendCount = 0;
  Timer? _codeTimer;
  bool _isPhoneEmpty = true;
  bool _isCodeOrPwdEmpty = true;
  bool _agreementChecked = false;
  bool _isPasswordLogin = false;
  bool _hasSlideVerifiedForCode = false;
  String? _cachedSlideVerifyToken;

  final phoneFieldController = TextEditingController();
  final codeOrPwdFieldController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _createSession();
    phoneFieldController.addListener(_checkPhoneField);
    codeOrPwdFieldController.addListener(_checkCodeOrPwdField);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _codeTimer?.cancel();
    phoneFieldController.removeListener(_checkPhoneField);
    codeOrPwdFieldController.removeListener(_checkCodeOrPwdField);
    super.dispose();
  }

  // ==================== QR 模式逻辑 ====================

  Future<void> _createSession() async {
    if (!isDesktopShell) {
      setState(() {
        _error = '当前界面仅支持桌面端';
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

  // ==================== 表单模式逻辑 ====================

  void _checkPhoneField() {
    setState(() {
      _isPhoneEmpty = phoneFieldController.text.length != 11;
    });
  }

  void _checkCodeOrPwdField() {
    setState(() {
      _isCodeOrPwdEmpty = codeOrPwdFieldController.text.isEmpty;
    });
  }

  void _toggleLoginMode() {
    setState(() {
      _isPasswordLogin = !_isPasswordLogin;
      codeOrPwdFieldController.clear();
      _isCodeOrPwdEmpty = true;
      _hasSlideVerifiedForCode = false;
      _cachedSlideVerifyToken = null;
      if (_isPasswordLogin) {
        if (_codeTimer != null) {
          _codeTimer!.cancel();
          _codeTimer = null;
        }
        isSentCode = false;
        waitResendCount = 0;
      }
    });
  }

  void _switchToForm() {
    setState(() {
      _currentView = _PCLoginView.form;
    });
  }

  void _switchToQr() {
    setState(() {
      _currentView = _PCLoginView.qr;
    });
  }

  void _handleLoginSuccess(String userId, String token) {
    Imclient.connect(Config.IM_Host, userId, token);
    if (mounted) {
      showToast(msg: AppLocalizations.of(context)!.loginSuccess);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PCHome()),
      );
    }
    SharedPreferences.getInstance().then((value) {
      value.setString("userId", userId);
      value.setString("token", token);
    });
  }

  void _showSlideVerifyForSendCode() {
    SlideVerifyDialog.show(
      context: context,
      listener: _PcSendCodeSlideVerifyListener(
        phoneNumber: phoneFieldController.value.text,
        onStartCountdown: () {
          showToast(msg: "验证码发送成功，请在5分钟内进行验证!");
          const Duration duration = Duration(seconds: 1);
          _codeTimer = Timer.periodic(duration, (timer) {
            setState(() {
              waitResendCount = waitResendCount + 1;
              if (waitResendCount >= 60) {
                isSentCode = false;
                _codeTimer!.cancel();
              }
            });
          });
          setState(() {
            waitResendCount = 0;
            isSentCode = true;
          });
        },
        onError: (msg) => showToast(msg: "发送验证码失败: $msg"),
        onSetSlideVerified: (token) {
          setState(() {
            _hasSlideVerifiedForCode = true;
            _cachedSlideVerifyToken = token;
          });
        },
      ),
    );
  }

  void _showSlideVerifyForPasswordLogin(String phoneNum, String password) {
    SlideVerifyDialog.show(
      context: context,
      listener: _PcLoginSlideVerifyListener(
        isPasswordLogin: true,
        phoneNumber: phoneNum,
        password: password,
        onLoginSuccess: (userId, token) => _handleLoginSuccess(userId, token),
        onLoginError: (msg) => showToast(msg: "登录失败: $msg"),
      ),
    );
  }

  void _showSlideVerifyForSmsLogin(String phoneNum, String authCode) {
    if (_hasSlideVerifiedForCode && _cachedSlideVerifyToken != null) {
      _performSmsLogin(phoneNum, authCode, null);
      return;
    }

    SlideVerifyDialog.show(
      context: context,
      listener: _PcLoginSlideVerifyListener(
        isPasswordLogin: false,
        phoneNumber: phoneNum,
        authCode: authCode,
        onLoginSuccess: (userId, token) => _handleLoginSuccess(userId, token),
        onLoginError: (msg) {
          showToast(msg: "登录失败: $msg");
          setState(() {
            _hasSlideVerifiedForCode = false;
            _cachedSlideVerifyToken = null;
          });
        },
      ),
    );
  }

  void _performSmsLogin(String phoneNum, String authCode, String? slideVerifyToken) {
    AppServer.login(phoneNum, authCode,
        (userId, token, isNewUser) {
      _handleLoginSuccess(userId, token);
    }, (msg) {
      showToast(msg: "登录失败: $msg");
      setState(() {
        _hasSlideVerifiedForCode = false;
        _cachedSlideVerifyToken = null;
      });
    }, slideVerifyToken: slideVerifyToken);
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    if (_currentView == _PCLoginView.form) {
      return _buildFormView();
    }
    return _buildQrView();
  }

  // ===== QR 视图 =====
  Widget _buildQrView() {
    final l10n = AppLocalizations.of(context)!;
    final qrData =
        _token != null ? '${WfcScheme.qrCodePrefixPcSession}$_token' : '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.appTitle,
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                _isScanned ? l10n.scanned : l10n.pcLoginQrHint,
                style:
                    const TextStyle(fontSize: 14, color: Color(0xFF888888)),
              ),
              const SizedBox(height: 32),
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: _buildQrContent(qrData),
              ),
              const SizedBox(height: 24),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _refresh,
                  child: Text(l10n.retry),
                ),
              ],
              const SizedBox(height: 16),
              if (_isScanned) ...[
                // 已扫码：显示取消按钮
                TextButton(
                  onPressed: _cancelScan,
                  child: Text(l10n.cancel,
                      style: const TextStyle(color: Colors.red)),
                ),
              ] else ...[
                // 未扫码：显示验证码/密码登录按钮
                TextButton(
                  onPressed: _switchToForm,
                  child: Text(l10n.loginWithCodeOrPassword),
                ),
              ],
            ],
          ),
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
                    _scannedUserPortrait!,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.person,
                        size: 80, color: Color(0xFFCCCCCC)),
                  )
                : const Icon(Icons.person,
                    size: 80, color: Color(0xFFCCCCCC)),
          ),
          if (_scannedUserName != null) ...[
            const SizedBox(height: 8),
            Text(
              _scannedUserName!,
              style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
            ),
          ],
        ],
      );
    }
    if (_error != null && _token == null) {
      return const Center(
          child: Icon(Icons.error_outline, color: Colors.red, size: 48));
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

  // ===== 表单视图 =====
  Widget _buildFormView() {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Container(
          width: 400,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
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
                        onTap: _switchToQr,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_back_ios,
                                size: 16, color: Color(0xFF576B95)),
                            const SizedBox(width: 4),
                            Text(
                              l10n.loginCodeTitle,
                              style: const TextStyle(
                                  fontSize: 14, color: Color(0xFF576B95)),
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
                    _isPasswordLogin ? l10n.loginWithPassword : l10n.loginCodeTitle,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 24),
                // 手机号输入
                TextField(
                  controller: phoneFieldController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: l10n.phoneNumberHint,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                // 验证码或密码输入行
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: codeOrPwdFieldController,
                        obscureText: _isPasswordLogin,
                        decoration: InputDecoration(
                          hintText: _isPasswordLogin
                              ? l10n.inputPassword
                              : l10n.inputVerificationCode,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    if (!_isPasswordLogin) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          onPressed: _isPhoneEmpty || isSentCode
                              ? null
                              : _showSlideVerifyForSendCode,
                          child: isSentCode
                              ? Text('${waitResendCount}s')
                              : Text(l10n.sendCode),
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
                      value: _agreementChecked,
                      onChanged: (bool? value) {
                        setState(() {
                          _agreementChecked = value!;
                        });
                      },
                    ),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          text: l10n.readAndAgree,
                          style: const TextStyle(color: Colors.black),
                          children: <TextSpan>[
                            TextSpan(
                              text: l10n.userAgreement,
                              style: const TextStyle(color: Colors.blue),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  Utilities.openLink(
                                      context, Config.USER_AGREEMENT_URL);
                                },
                            ),
                            TextSpan(text: l10n.and),
                            TextSpan(
                              text: l10n.privacyPolicy,
                              style: const TextStyle(color: Colors.blue),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  Utilities.openLink(context,
                                      Config.PRIVACY_AGREEMENT_URL);
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
                    onPressed: (_isPhoneEmpty || _isCodeOrPwdEmpty)
                        ? null
                        : () {
                            if (!_agreementChecked) {
                              showToast(msg: l10n.agreePolicyFirst);
                              return;
                            }
                            String phoneNum =
                                phoneFieldController.value.text;
                            String codeOrPwd =
                                codeOrPwdFieldController.value.text;

                            if (_isPasswordLogin) {
                              _showSlideVerifyForPasswordLogin(
                                  phoneNum, codeOrPwd);
                            } else {
                              _showSlideVerifyForSmsLogin(
                                  phoneNum, codeOrPwd);
                            }
                          },
                    child: Text(l10n.login),
                  ),
                ),
                const SizedBox(height: 8),
                // 切换登录方式
                Center(
                  child: TextButton(
                    onPressed: _toggleLoginMode,
                    child: Text(_isPasswordLogin
                        ? l10n.loginWithPhoneCode
                        : l10n.loginWithPassword),
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

// ===== 滑动验证监听器 (PC 表单专用) =====

class _PcSendCodeSlideVerifyListener implements SlideVerifyListener {
  final String phoneNumber;
  final VoidCallback onStartCountdown;
  final Function(String) onError;
  final Function(String) onSetSlideVerified;

  _PcSendCodeSlideVerifyListener({
    required this.phoneNumber,
    required this.onStartCountdown,
    required this.onError,
    required this.onSetSlideVerified,
  });

  @override
  void onVerifySuccess(String token) {
    AppServer.sendCode(phoneNumber, () {
      onSetSlideVerified(token);
      onStartCountdown();
    }, (msg) {
      onError(msg);
    }, slideVerifyToken: token);
  }

  @override
  void onVerifyFailed() {}

  @override
  void onLoadFailed() {}
}

class _PcLoginSlideVerifyListener implements SlideVerifyListener {
  final bool isPasswordLogin;
  final String phoneNumber;
  final String? password;
  final String? authCode;
  final Function(String userId, String token) onLoginSuccess;
  final Function(String msg) onLoginError;

  _PcLoginSlideVerifyListener({
    required this.isPasswordLogin,
    required this.phoneNumber,
    this.password,
    this.authCode,
    required this.onLoginSuccess,
    required this.onLoginError,
  });

  @override
  void onVerifySuccess(String token) {
    if (isPasswordLogin) {
      AppServer.passwordLogin(phoneNumber, password!,
          (userId, token, isNewUser) {
        onLoginSuccess(userId, token);
      }, (msg) {
        onLoginError(msg);
      }, slideVerifyToken: token);
    } else {
      AppServer.login(phoneNumber, authCode!,
          (userId, token, isNewUser) {
        onLoginSuccess(userId, token);
      }, (msg) {
        onLoginError(msg);
      }, slideVerifyToken: token);
    }
  }

  @override
  void onVerifyFailed() {}

  @override
  void onLoadFailed() {}
}
