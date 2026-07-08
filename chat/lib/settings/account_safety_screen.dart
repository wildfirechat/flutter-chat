import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:chat/app_server.dart';
import 'package:chat/settings/blacklist_screen.dart';
import 'package:chat/widget/option_item.dart';

/// 账号与安全页面
///
/// 提供修改密码、黑名单管理等账号安全相关功能入口。
class AccountSafetyScreen extends StatelessWidget {
  const AccountSafetyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('账号与安全'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              OptionItem(
                '修改密码',
                leftImage: const Icon(Icons.lock_outline, color: Color(0xFF576b95), size: 20),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
                  );
                },
              ),
              const Divider(height: 1, indent: 56),
              OptionItem(
                '黑名单',
                leftImage: const Icon(Icons.block, color: Colors.red, size: 20),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const BlacklistScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 修改密码页面
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _oldController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final oldPassword = _oldController.text.trim();
    final newPassword = _newController.text.trim();
    final confirmPassword = _confirmController.text.trim();

    if (oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      Fluttertoast.showToast(msg: '请填写完整密码');
      return;
    }
    if (newPassword != confirmPassword) {
      Fluttertoast.showToast(msg: '两次输入的新密码不一致');
      return;
    }
    if (newPassword.length < 6) {
      Fluttertoast.showToast(msg: '新密码长度不能少于6位');
      return;
    }

    setState(() => _loading = true);
    AppServer.changePassword(
      oldPassword,
      newPassword,
      () {
        if (mounted) {
          setState(() => _loading = false);
          Fluttertoast.showToast(msg: '修改成功');
          Navigator.pop(context);
        }
      },
      (errorMsg) {
        if (mounted) {
          setState(() => _loading = false);
          Fluttertoast.showToast(msg: '修改失败: $errorMsg');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('修改密码'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _oldController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '原密码',
                hintText: '请输入原密码',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '新密码',
                hintText: '请输入新密码',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '确认新密码',
                hintText: '请再次输入新密码',
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _changePassword,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('确认修改'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
