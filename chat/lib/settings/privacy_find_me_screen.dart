import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:chat/l10n/app_localizations.dart';

/// 找到我的方式页面
///
/// 通过用户设置(scope 27)的位掩码控制他人可通过哪些方式搜索到自己:
/// bit2(2)=禁止按账号搜索、bit3(4)=禁止按手机号搜索。
/// 位被置位表示禁止搜索(开关关闭),与 iOS 端逻辑保持一致。
class FindMeByScreen extends StatefulWidget {
  const FindMeByScreen({super.key});

  @override
  State<FindMeByScreen> createState() => _FindMeByScreenState();
}

class _FindMeByScreenState extends State<FindMeByScreen> {
  /// 禁止按账号搜索的掩码位
  static const int _maskAccount = 1 << 1;

  /// 禁止按手机号搜索的掩码位
  static const int _maskPhone = 1 << 2;

  bool _accountOn = true;
  bool _phoneOn = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    try {
      final value = await Imclient.getUserSetting(27, "");
      final mask = int.tryParse(value) ?? 0;
      if (mounted) {
        setState(() {
          _accountOn = mask & _maskAccount == 0;
          _phoneOn = mask & _maskPhone == 0;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('FindMeBy load error: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// 切换某一位:先读当前值,按位置位/清位后写回。开关 on=允许搜索(清位)。
  void _onChanged(int mask, bool allow) {
    final l10n = AppLocalizations.of(context)!;
    // 乐观更新,失败回滚
    setState(() {
      if (mask == _maskAccount) {
        _accountOn = allow;
      } else {
        _phoneOn = allow;
      }
    });
    Imclient.getUserSetting(27, "").then((value) {
      int current = int.tryParse(value) ?? 0;
      current = allow ? (current & ~mask) : (current | mask);
      Imclient.setUserSetting(27, "", current.toString(), () {}, (errorCode) {
        if (mounted) {
          setState(() {
            if (mask == _maskAccount) {
              _accountOn = !allow;
            } else {
              _phoneOn = !allow;
            }
          });
        }
        Fluttertoast.showToast(msg: l10n.operateFail('$errorCode'));
      });
    }).catchError((e) {
      debugPrint('FindMeBy toggle error: $e');
      if (mounted) {
        setState(() {
          if (mask == _maskAccount) {
            _accountOn = !allow;
          } else {
            _phoneOn = !allow;
          }
        });
      }
      Fluttertoast.showToast(msg: l10n.operateFail('$e'));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.findMeBy),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(l10n.account),
                    value: _accountOn,
                    onChanged: (value) => _onChanged(_maskAccount, value),
                  ),
                  SwitchListTile(
                    title: Text(l10n.phoneNumber),
                    value: _phoneOn,
                    onChanged: (value) => _onChanged(_maskPhone, value),
                  ),
                ],
              ),
            ),
    );
  }
}
