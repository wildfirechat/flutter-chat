import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:file_picker/file_picker.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/file_message_content.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:chat/utilities.dart';
import 'package:chat/conversation/forward/show_pick_forward_target.dart';
import 'pan_service.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/widgets/pc_page_header.dart';

/// 云盘/网盘主页面
///
/// 展示网盘空间列表和空间内文件列表。
class PanHomeScreen extends StatefulWidget {
  final bool isMoveMode;
  final bool isCopyMode;
  final PanFile? fileToMove;
  final PanSpace? sourceSpace;
  final int? sourceParentId;
  final PanFile? fileToCopy;
  final PanSpace? sourceCopySpace;
  final int? sourceCopyParentId;

  const PanHomeScreen({
    super.key,
    this.isMoveMode = false,
    this.isCopyMode = false,
    this.fileToMove,
    this.sourceSpace,
    this.sourceParentId,
    this.fileToCopy,
    this.sourceCopySpace,
    this.sourceCopyParentId,
  });

  /// 选择移动/复制的目标位置
  static Widget pickDestination({
    PanFile? fileToMove,
    PanSpace? sourceSpace,
    int? sourceParentId,
    PanFile? fileToCopy,
    PanSpace? sourceCopySpace,
    int? sourceCopyParentId,
  }) {
    return PanHomeScreen(
      isMoveMode: fileToMove != null,
      isCopyMode: fileToCopy != null,
      fileToMove: fileToMove,
      sourceSpace: sourceSpace,
      sourceParentId: sourceParentId,
      fileToCopy: fileToCopy,
      sourceCopySpace: sourceCopySpace,
      sourceCopyParentId: sourceCopyParentId,
    );
  }

  @override
  State<PanHomeScreen> createState() => _PanHomeScreenState();
}

class _PanHomeScreenState extends State<PanHomeScreen> {
  List<PanSpace> _spaces = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSpaces();
  }

  Future<void> _loadSpaces() async {
    if (!PanService.isAvailable) {
      setState(() {
        _loading = false;
        _error = '网盘服务未配置';
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final currentUserId = Imclient.currentUserId;
      final allSpaces = await PanService.getSpaces();
      debugPrint('Pan getSpaces returned ${allSpaces.length} spaces, currentUserId=$currentUserId');
      for (final space in allSpaces) {
        debugPrint('Pan space raw: id=${space.spaceId}, type=${space.spaceType}, ownerId=${space.ownerId}, name=${space.name}');
      }
      _spaces = allSpaces.where((space) {
        if (space.spaceType == PanSpaceType.globalPublic) {
          return true;
        }
        return space.ownerId == currentUserId;
      }).toList();
      debugPrint('Pan filtered spaces count: ${_spaces.length}');
      _error = null;
    } catch (e, s) {
      debugPrint('Pan load spaces error: $e\n$s');
      _error = '加载失败，请稍后重试';
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isDesktopShell
          ? PcPageHeader(
              title: _appBarTitle,
              actions: _buildActions(),
            )
          : AppBar(
              title: Text(_appBarTitle),
              actions: _buildActions(),
            ),
      body: _buildBody(),
    );
  }

  String get _appBarTitle {
    if (widget.isMoveMode || widget.isCopyMode) {
      return '选择目标位置';
    }
    return '云盘';
  }

  List<Widget> _buildActions() {
    if (widget.isMoveMode || widget.isCopyMode) {
      return [
        TextButton(
          onPressed: _cancelMoveCopy,
          child: const Text('取消', style: TextStyle(color: Colors.white)),
        ),
      ];
    }
    return [];
  }

  void _cancelMoveCopy() {
    _returnToOriginalView();
  }

  void _returnToOriginalView() {
    Navigator.popUntil(context, (route) {
      if (route.settings.name != null) return true;
      if (route.isFirst) return true;
      return false;
    });
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadSpaces,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_spaces.isEmpty) {
      return const Center(child: Text('暂无云盘空间'));
    }
    return RefreshIndicator(
      onRefresh: _loadSpaces,
      child: ListView.builder(
        itemCount: _spaces.length,
        itemBuilder: (context, index) => _buildSpaceCard(_spaces[index]),
      ),
    );
  }

  Widget _buildSpaceCard(PanSpace space) {
    final usagePercent = space.totalQuota > 0 ? space.usedQuota / space.totalQuota : 0.0;
    final displayName = _spaceDisplayName(space);
    return Card(
      margin: const EdgeInsets.all(12),
      child: InkWell(
        onTap: () => _openSpace(space),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Image.asset(
                    _spaceIconAsset,
                    width: 40,
                    height: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      displayName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    '${space.fileCount} 个文件',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF999999)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: usagePercent,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF576b95)),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_formatSize(space.usedQuota)} / ${_formatSize(space.totalQuota)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _spaceDisplayName(PanSpace space) {
    switch (space.spaceType) {
      case PanSpaceType.globalPublic:
        return '全局公共空间';
      case PanSpaceType.userPublic:
        return '我的公共空间';
      case PanSpaceType.userPrivate:
        return '我的私有空间';
    }
  }

  String get _spaceIconAsset => 'assets/images/file_folder.png';

  void _openSpace(PanSpace space) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PanFileListScreen(
          space: space,
          isMoveMode: widget.isMoveMode,
          isCopyMode: widget.isCopyMode,
          fileToMove: widget.fileToMove,
          sourceSpace: widget.sourceSpace,
          sourceParentId: widget.sourceParentId,
          fileToCopy: widget.fileToCopy,
          sourceCopySpace: widget.sourceCopySpace,
          sourceCopyParentId: widget.sourceCopyParentId,
        ),
      ),
    );
  }


  String _formatSize(int bytes) {
    if (bytes >= 1073741824) return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }
}

/// 空间文件列表页面
class PanFileListScreen extends StatefulWidget {
  final PanSpace space;
  final int parentId;
  final String? title;
  final bool isMoveMode;
  final bool isCopyMode;
  final PanFile? fileToMove;
  final PanSpace? sourceSpace;
  final int? sourceParentId;
  final PanFile? fileToCopy;
  final PanSpace? sourceCopySpace;
  final int? sourceCopyParentId;

  const PanFileListScreen({
    super.key,
    required this.space,
    this.parentId = 0,
    this.title,
    this.isMoveMode = false,
    this.isCopyMode = false,
    this.fileToMove,
    this.sourceSpace,
    this.sourceParentId,
    this.fileToCopy,
    this.sourceCopySpace,
    this.sourceCopyParentId,
  });

  @override
  State<PanFileListScreen> createState() => _PanFileListScreenState();
}

class _PanFileListScreenState extends State<PanFileListScreen> {
  List<PanFile> _files = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _loading = true);
    try {
      _files = await PanService.getSpaceFiles(
        widget.space.spaceId,
        parentId: widget.parentId,
      );
      _error = null;
    } catch (e, s) {
      debugPrint('Pan load files error: $e\n$s');
      _error = '加载失败，请稍后重试';
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isDesktopShell
          ? PcPageHeader(
              title: _appBarTitle,
              onBack: () => Navigator.of(context).maybePop(),
              actions: _buildActions(),
            )
          : AppBar(
              title: Text(_appBarTitle),
              actions: _buildActions(),
            ),
      body: _buildBody(),
    );
  }

  String get _appBarTitle {
    if (widget.isMoveMode || widget.isCopyMode) {
      return '选择目标位置';
    }
    return widget.title ?? widget.space.name;
  }

  List<Widget> _buildActions() {
    if (widget.isMoveMode) {
      final isSameLocation = widget.sourceSpace?.spaceId == widget.space.spaceId &&
          (widget.sourceParentId ?? 0) == widget.parentId;
      return [
        TextButton(
          onPressed: isSameLocation ? null : _executeMove,
          child: const Text('粘贴', style: TextStyle(color: Colors.white)),
        ),
        TextButton(
          onPressed: _cancelMoveCopy,
          child: const Text('取消', style: TextStyle(color: Colors.white)),
        ),
      ];
    }

    if (widget.isCopyMode) {
      final isSameLocation = widget.sourceCopySpace?.spaceId == widget.space.spaceId &&
          (widget.sourceCopyParentId ?? 0) == widget.parentId;
      return [
        TextButton(
          onPressed: isSameLocation ? null : _executeCopy,
          child: const Text('粘贴', style: TextStyle(color: Colors.white)),
        ),
        TextButton(
          onPressed: _cancelMoveCopy,
          child: const Text('取消', style: TextStyle(color: Colors.white)),
        ),
      ];
    }

    if (!_shouldShowAddButton) return [];

    return [
      IconButton(
        icon: const Icon(Icons.create_new_folder),
        onPressed: _createFolder,
      ),
      IconButton(
        icon: const Icon(Icons.file_upload),
        onPressed: _uploadFile,
      ),
    ];
  }

  bool get _shouldShowAddButton {
    if (widget.space.spaceType == PanSpaceType.userPublic) {
      return widget.space.ownerId == Imclient.currentUserId;
    }
    return true;
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadFiles,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_files.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadFiles,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Container(
              height: constraints.maxHeight,
              alignment: Alignment.center,
              child: const Text('暂无文件'),
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadFiles,
      child: ListView.separated(
        itemCount: _files.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final file = _files[index];
          return _buildFileItem(file);
        },
      ),
    );
  }

  Widget _buildFileItem(PanFile file) {
    return ListTile(
      leading: _buildFileIcon(file),
      title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        file.isFolder
            ? '${file.childCount} 项'
            : '${file.sizeText}  ${file.creatorName ?? file.creatorId}',
        style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.more_horiz, size: 20),
        onPressed: () => _showFileMenu(file),
      ),
      onTap: () {
        if (file.isFolder) {
          _openFolder(file);
        } else {
          _openFile(file);
        }
      },
    );
  }

  Widget _buildFileIcon(PanFile file) {
    String asset;
    if (file.isFolder) {
      asset = 'assets/images/file_folder.png';
    } else {
      switch (file.iconType) {
        case PanIconType.image:
          asset = 'assets/images/file_type/image.png';
        case PanIconType.video:
          asset = 'assets/images/file_type/video.png';
        case PanIconType.audio:
          asset = 'assets/images/file_type/audio.png';
        case PanIconType.pdf:
          asset = 'assets/images/file_type/pdf.png';
        case PanIconType.word:
          asset = 'assets/images/file_type/word.png';
        case PanIconType.excel:
          asset = 'assets/images/file_type/xls.png';
        case PanIconType.ppt:
          asset = 'assets/images/file_type/ppt.png';
        case PanIconType.html:
          asset = 'assets/images/file_type/html.png';
        case PanIconType.text:
          asset = 'assets/images/file_type/text.png';
        case PanIconType.exe:
          asset = 'assets/images/file_type/exe.png';
        case PanIconType.xml:
          asset = 'assets/images/file_type/xml.png';
        case PanIconType.archive:
          asset = 'assets/images/file_type/zip.png';
        case PanIconType.file:
        default:
          asset = 'assets/images/file_type/unknown.png';
      }
    }
    return Image.asset(asset, width: 40, height: 40);
  }

  void _openFolder(PanFile file) {
    if (widget.isMoveMode && widget.fileToMove != null &&
        widget.fileToMove!.isFolder && widget.fileToMove!.fileId == file.fileId) {
      Fluttertoast.showToast(msg: '不能将文件夹移动到自身');
      return;
    }
    if (widget.isCopyMode && widget.fileToCopy != null &&
        widget.fileToCopy!.isFolder && widget.fileToCopy!.fileId == file.fileId) {
      Fluttertoast.showToast(msg: '不能将文件夹复制到自身');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PanFileListScreen(
          space: widget.space,
          parentId: file.fileId,
          title: file.name,
          isMoveMode: widget.isMoveMode,
          isCopyMode: widget.isCopyMode,
          fileToMove: widget.fileToMove,
          sourceSpace: widget.sourceSpace,
          sourceParentId: widget.sourceParentId,
          fileToCopy: widget.fileToCopy,
          sourceCopySpace: widget.sourceCopySpace,
          sourceCopyParentId: widget.sourceCopyParentId,
        ),
      ),
    );
  }

  Future<void> _openFile(PanFile file) async {
    try {
      final url = await PanService.getFileDownloadUrl(file.fileId);
      if (url.isNotEmpty) {
        if (mounted) Utilities.openLink(context, url);
      }
    } catch (e, s) {
      debugPrint('Pan open file error: $e\n$s');
      Fluttertoast.showToast(msg: '获取下载链接失败');
    }
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withReadStream: false,
    );
    if (result == null || result.files.isEmpty) return;

    final localPath = result.files.single.path;
    if (localPath == null) return;

    final progressNotifier = ValueNotifier<double>(0.0);
    final cancelToken = PanUploadCancelToken();

    if (!mounted) return;
    final dialogContextCompleter = Completer<BuildContext>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        if (!dialogContextCompleter.isCompleted) {
          dialogContextCompleter.complete(ctx);
        }
        return AlertDialog(
          contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('上传中...', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 16),
                ValueListenableBuilder<double>(
                  valueListenable: progressNotifier,
                  builder: (_, progress, __) {
                    return Column(
                      children: [
                        LinearProgressIndicator(value: progress),
                        const SizedBox(height: 8),
                        Text('${(progress * 100).toStringAsFixed(1)}%'),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    cancelToken.cancel();
                  },
                  child: const Text('取消上传'),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      await PanService.uploadFileToSpace(
        localPath: localPath,
        space: widget.space,
        parentId: widget.parentId,
        onProgress: (progress) => progressNotifier.value = progress,
        cancelToken: cancelToken,
      );
      final dialogContext = await dialogContextCompleter.future;
      if (dialogContext.mounted) Navigator.pop(dialogContext);
      Fluttertoast.showToast(msg: '上传成功');
      _loadFiles();
    } on PanException catch (e) {
      final dialogContext = await dialogContextCompleter.future;
      if (dialogContext.mounted) Navigator.pop(dialogContext);
      if (e.code == -2) {
        Fluttertoast.showToast(msg: '上传已取消');
      } else {
        debugPrint('Pan upload error: $e');
        Fluttertoast.showToast(msg: '上传失败');
      }
    } catch (e, s) {
      final dialogContext = await dialogContextCompleter.future;
      if (dialogContext.mounted) Navigator.pop(dialogContext);
      debugPrint('Pan upload error: $e\n$s');
      Fluttertoast.showToast(msg: '上传失败');
    }
  }

  Future<void> _createFolder() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('新建文件夹'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: '文件夹名称'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
    if (name == null || name.isEmpty || !mounted) return;

    try {
      await PanService.createFolder(
        widget.space.spaceId,
        name,
        parentId: widget.parentId,
      );
      Fluttertoast.showToast(msg: '创建成功');
      _loadFiles();
    } catch (e, s) {
      debugPrint('Pan create folder error: $e\n$s');
      Fluttertoast.showToast(msg: '创建失败');
    }
  }

  Future<void> _renameFile(PanFile file) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: file.name);
        return AlertDialog(
          title: const Text('重命名'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: '新名称'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
    if (name == null || name.isEmpty || name == file.name || !mounted) return;

    try {
      await PanService.renameFile(file.fileId, name);
      Fluttertoast.showToast(msg: '重命名成功');
      _loadFiles();
    } catch (e, s) {
      debugPrint('Pan rename error: $e\n$s');
      Fluttertoast.showToast(msg: '重命名失败');
    }
  }

  Future<void> _shareFile(PanFile file) async {
    try {
      final url = await PanService.getFileDownloadUrl(file.fileId);
      if (!mounted) return;
      final content = FileMessageContent();
      content.name = file.name;
      content.size = file.size;
      content.remoteUrl = url;

      final message = Message();
      message.content = content;

      showPickForwardTarget(
        context,
        messages: [message],
        onSelected: (conversations, comment) {
          for (var conversation in conversations) {
            _performForward(conversation, message, comment ?? '');
          }
        },
      );
    } catch (e, s) {
      debugPrint('Pan share file error: $e\n$s');
      Fluttertoast.showToast(msg: '获取下载链接失败');
    }
  }

  void _performForward(Conversation target, Message message, String extraText) {
    Imclient.sendMessage(target, message.content,
        successCallback: (messageUid, timestamp) {},
        errorCallback: (errorCode) {});
    if (extraText.isNotEmpty) {
      final textContent = TextMessageContent(extraText);
      Imclient.sendMessage(target, textContent,
          successCallback: (messageUid, timestamp) {},
          errorCallback: (errorCode) {});
    }
  }

  void _startMoveFile(PanFile file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PanHomeScreen.pickDestination(
          fileToMove: file,
          sourceSpace: widget.space,
          sourceParentId: widget.parentId,
        ),
      ),
    );
  }

  void _startCopyFile(PanFile file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PanHomeScreen.pickDestination(
          fileToCopy: file,
          sourceCopySpace: widget.space,
          sourceCopyParentId: widget.parentId,
        ),
      ),
    );
  }

  void _duplicateFile(PanFile file) {
    _pickDuplicateSpace(file);
  }

  Future<void> _pickDuplicateSpace(PanFile file) async {
    try {
      final spaces = await PanService.getMySpaces();
      if (!mounted) return;

      PanSpace? publicSpace;
      PanSpace? privateSpace;
      for (final space in spaces) {
        if (space.spaceType == PanSpaceType.userPublic) publicSpace = space;
        if (space.spaceType == PanSpaceType.userPrivate) privateSpace = space;
      }

      if (publicSpace == null && privateSpace == null) {
        Fluttertoast.showToast(msg: '没有可转存的空间');
        return;
      }

      showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (publicSpace != null)
                ListTile(
                  leading: const Icon(Icons.folder_shared),
                  title: Text(publicSpace.name),
                  onTap: () {
                    Navigator.pop(ctx);
                    _doDuplicate(file, publicSpace!);
                  },
                ),
              if (privateSpace != null)
                ListTile(
                  leading: const Icon(Icons.folder),
                  title: Text(privateSpace.name),
                  onTap: () {
                    Navigator.pop(ctx);
                    _doDuplicate(file, privateSpace!);
                  },
                ),
            ],
          ),
        ),
      );
    } catch (e, s) {
      debugPrint('Pan duplicate load spaces error: $e\n$s');
      Fluttertoast.showToast(msg: '加载空间失败');
    }
  }

  Future<void> _doDuplicate(PanFile file, PanSpace targetSpace) async {
    try {
      await PanService.copyFile(file.fileId, targetSpace.spaceId);
      Fluttertoast.showToast(msg: '转存成功');
    } catch (e, s) {
      debugPrint('Pan duplicate error: $e\n$s');
      Fluttertoast.showToast(msg: '转存失败');
    }
  }

  Future<void> _executeMove() async {
    final file = widget.fileToMove;
    if (file == null || widget.sourceSpace == null) return;

    final isSameLocation = widget.sourceSpace!.spaceId == widget.space.spaceId &&
        (widget.sourceParentId ?? 0) == widget.parentId;
    if (isSameLocation) {
      Fluttertoast.showToast(msg: '不能将文件移动到原位置');
      return;
    }

    try {
      await PanService.moveFile(file.fileId, widget.space.spaceId,
          targetParentId: widget.parentId);
      Fluttertoast.showToast(msg: '移动成功');
      _returnToOriginalView();
    } catch (e, s) {
      debugPrint('Pan move error: $e\n$s');
      Fluttertoast.showToast(msg: '移动失败');
    }
  }

  Future<void> _executeCopy() async {
    final file = widget.fileToCopy;
    if (file == null || widget.sourceCopySpace == null) return;

    final isSameLocation = widget.sourceCopySpace!.spaceId == widget.space.spaceId &&
        (widget.sourceCopyParentId ?? 0) == widget.parentId;
    if (isSameLocation) {
      Fluttertoast.showToast(msg: '不能将文件复制到原位置');
      return;
    }

    try {
      await PanService.copyFile(file.fileId, widget.space.spaceId,
          targetParentId: widget.parentId);
      Fluttertoast.showToast(msg: '复制成功');
      _returnToOriginalView();
    } catch (e, s) {
      debugPrint('Pan copy error: $e\n$s');
      Fluttertoast.showToast(msg: '复制失败');
    }
  }

  void _cancelMoveCopy() {
    _returnToOriginalView();
  }

  void _returnToOriginalView() {
    Navigator.popUntil(context, (route) {
      if (route.settings.name != null) return true;
      if (route.isFirst) return true;
      return false;
    });
  }

  Future<void> _deleteFile(PanFile file) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text('确定要删除 "${file.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await PanService.deleteFile(file.fileId);
      Fluttertoast.showToast(msg: '删除成功');
      _loadFiles();
    } catch (e, s) {
      debugPrint('Pan delete error: $e\n$s');
      Fluttertoast.showToast(msg: '删除失败');
    }
  }

  void _showFileMenu(PanFile file) {
    final canManage = widget.space.canManage;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!file.isFolder)
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('下载/打开'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openFile(file);
                },
              ),
            if (canManage) ...[
              if (!file.isFolder)
                ListTile(
                  leading: const Icon(Icons.share),
                  title: const Text('分享'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _shareFile(file);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.drive_file_move_outline),
                title: const Text('移动'),
                onTap: () {
                  Navigator.pop(ctx);
                  _startMoveFile(file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_copy_outlined),
                title: const Text('复制'),
                onTap: () {
                  Navigator.pop(ctx);
                  _startCopyFile(file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('重命名'),
                onTap: () {
                  Navigator.pop(ctx);
                  _renameFile(file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('删除', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteFile(file);
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.file_copy_outlined),
                title: const Text('转存'),
                onTap: () {
                  Navigator.pop(ctx);
                  _duplicateFile(file);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
