import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:chat/app_server.dart';

class PCLoginScreen extends StatefulWidget {
  final String token;

  const PCLoginScreen({super.key, required this.token});

  @override
  State<PCLoginScreen> createState() => _PCLoginScreenState();
}

class _PCLoginScreenState extends State<PCLoginScreen> {
  bool _isLoading = true;
  bool _canConfirm = false;

  @override
  void initState() {
    super.initState();
    _scanPCLogin();
  }

  void _scanPCLogin() {
    AppServer.scanPCLogin(widget.token, (status) {
      if (mounted) {
        if (status == 1) {
          setState(() {
            _isLoading = false;
            _canConfirm = true;
          });
        } else {
          Fluttertoast.showToast(msg: "PC端状态异常: $status");
          Navigator.of(context).pop();
        }
      }
    }, (error) {
      if (mounted) {
        Fluttertoast.showToast(msg: "网络错误: $error");
        Navigator.of(context).pop();
      }
    });
  }

  void _confirmPCLogin() {
    setState(() {
      _isLoading = true;
    });
    AppServer.confirmPCLogin(widget.token, Imclient.currentUserId, () {
      if (mounted) {
        Fluttertoast.showToast(msg: "登录成功");
        Navigator.of(context).pop();
      }
    }, (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        Fluttertoast.showToast(msg: "登录失败: $error");
      }
    });
  }

  void _cancelPCLogin() {
    AppServer.cancelPCLogin(widget.token, () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }, (error) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("登录确认"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.computer, size: 100, color: Colors.grey),
            const SizedBox(height: 20),
            const Text(
              "Windows/Mac 电脑登录确认",
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 40),
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_canConfirm)
              Column(
                children: [
                  ElevatedButton(
                    onPressed: _confirmPCLogin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    ),
                    child: const Text("登录"),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _cancelPCLogin,
                    child: const Text("取消登录"),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
