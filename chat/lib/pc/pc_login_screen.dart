import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:chat/app_server.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
          Fluttertoast.showToast(msg: AppLocalizations.of(context)!.pcStatusError(status));
          Navigator.of(context).pop();
        }
      }
    }, (error) {
      if (mounted) {
        Fluttertoast.showToast(msg: AppLocalizations.of(context)!.networkError);
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
        Fluttertoast.showToast(msg: AppLocalizations.of(context)!.loginSuccess);
        Navigator.of(context).pop();
      }
    }, (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        Fluttertoast.showToast(msg: AppLocalizations.of(context)!.loginFail(error));
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
        title: Text(AppLocalizations.of(context)!.loginConfirm),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.computer, size: 100, color: Colors.grey),
            const SizedBox(height: 20),
             Text(
              AppLocalizations.of(context)!.pcLoginConfirmDesc,
              style: const TextStyle(fontSize: 18),
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
                    child: Text(AppLocalizations.of(context)!.login),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _cancelPCLogin,
                    child: Text(AppLocalizations.of(context)!.cancelLogin),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
