import 'package:flutter/material.dart';

import 'widgets/moment_page_scaffold.dart';

/// 可见范围选择结果。
class VisibleScopeResult {
  /// 0 公开 / 1 私密 / 2 部分可见 / 3 不给谁看。
  final int mode;
  final List<String> users;

  const VisibleScopeResult(this.mode, this.users);
}

/// 可见范围选择页（公开/私密/部分可见/不给谁看）。
class VisibleScopePage extends StatefulWidget {
  final int mode;
  final List<String> users;

  /// 选择“部分可见/不给谁看”时的选人回调，返回选中的 userId 列表。
  final Future<List<String>> Function(int mode)? onPickUsers;

  const VisibleScopePage({
    super.key,
    this.mode = 0,
    this.users = const [],
    this.onPickUsers,
  });

  @override
  State<VisibleScopePage> createState() => _VisibleScopePageState();
}

class _VisibleScopePageState extends State<VisibleScopePage> {
  late int _mode = widget.mode;
  late List<String> _users = [...widget.users];

  static const _options = [
    (0, '公开', '所有人可见'),
    (1, '私密', '仅自己可见'),
    (2, '部分可见', '选中的朋友可见'),
    (3, '不给谁看', '选中的朋友不可见'),
  ];

  Future<void> _select(int mode) async {
    if ((mode == 2 || mode == 3) && widget.onPickUsers != null) {
      final selected = await widget.onPickUsers!(mode);
      if (!mounted) return;
      setState(() {
        _mode = mode;
        _users = selected;
      });
    } else {
      setState(() => _mode = mode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MomentPageScaffold(
      appBar: AppBar(
        title: const Text('谁可以看'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(VisibleScopeResult(_mode, _users));
            },
            child: const Text('完成'),
          ),
        ],
      ),
      body: RadioGroup<int>(
        groupValue: _mode,
        onChanged: (v) {
          if (v != null) _select(v);
        },
        child: ListView(
          children: [
            for (final (mode, title, subtitle) in _options)
              RadioListTile<int>(
                value: mode,
                title: Text(title),
                subtitle: Text(subtitle),
              ),
          ],
        ),
      ),
    );
  }
}
