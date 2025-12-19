import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:wfc_example/app_server.dart';

class GroupAnnouncementScreen extends StatefulWidget {
  final String groupId;
  final bool canEdit;

  const GroupAnnouncementScreen({
    super.key,
    required this.groupId,
    required this.canEdit,
  });

  @override
  State<GroupAnnouncementScreen> createState() => _GroupAnnouncementScreenState();
}

class _GroupAnnouncementScreenState extends State<GroupAnnouncementScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = true;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadAnnouncement();
  }

  void _loadAnnouncement() {
    AppServer.getGroupAnnouncement(widget.groupId, (text) {
      if (mounted) {
        setState(() {
          _controller.text = text;
          _isLoading = false;
        });
      }
    }, (msg) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        Fluttertoast.showToast(msg: "获取群公告失败: $msg");
      }
    });
  }

  void _saveAnnouncement() {
    if (_controller.text.isEmpty) {
      Fluttertoast.showToast(msg: "群公告不能为空");
      return;
    }
    AppServer.updateGroupAnnouncement(widget.groupId, _controller.text, () {
      Fluttertoast.showToast(msg: "更新群公告成功");
      if (mounted) {
        setState(() {
          _isEditing = false;
        });
      }
    }, (msg) {
      Fluttertoast.showToast(msg: "更新群公告失败: $msg");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('群公告'),
        actions: [
          if (widget.canEdit && !_isLoading)
            TextButton(
              onPressed: () {
                if (_isEditing) {
                  _saveAnnouncement();
                } else {
                  setState(() {
                    _isEditing = true;
                  });
                }
              },
              child: Text(
                _isEditing ? '完成' : '编辑',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _controller,
                enabled: _isEditing,
                maxLines: null,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '暂无群公告',
                ),
              ),
            ),
    );
  }
}
