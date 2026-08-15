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
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/pc/widgets/pc_page_header.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';
import 'package:chat/app_shell.dart';

/// 加载失败类型。build 时再映射为本地化文案
/// （initState 同步路径里不能做 InheritedWidget 查找）。
enum _PanLoadError { serviceNotConfigured, loadFailed }

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
  _PanLoadError? _error;

  @override
  void initState() {
    super.initState();
    _loadSpaces();
  }

  Future<void> _loadSpaces() async {
    if (!PanService.isAvailable) {
      setState(() {
        _loading = false;
        _error = _PanLoadError.serviceNotConfigured;
      });
      return;
    }

    setState(() => _loading = true);
    try {
      final currentUserId = Imclient.currentUserId;
      final allSpaces = await PanService.getSpaces();
      debugPrint(
          'Pan getSpaces returned ${allSpaces.length} spaces, currentUserId=$currentUserId');
      for (final space in allSpaces) {
        debugPrint(
            'Pan space raw: id=${space.spaceId}, type=${space.spaceType}, ownerId=${space.ownerId}, name=${space.name}');
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
      _error = _PanLoadError.loadFailed;
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppShell.isDesktopStyle
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
    final l10n = AppLocalizations.of(context)!;
    if (widget.isMoveMode || widget.isCopyMode) {
      return l10n.pickDestination;
    }
    return l10n.cloudDrive;
  }

  List<Widget> _buildActions() {
    if (widget.isMoveMode || widget.isCopyMode) {
      return [
        TextButton(
          onPressed: _cancelMoveCopy,
          child: Text(AppLocalizations.of(context)!.cancel),
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
      final l10n = AppLocalizations.of(context)!;
      final message = _error == _PanLoadError.serviceNotConfigured
          ? l10n.panServiceNotConfigured
          : l10n.loadFailedRetry;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: TextStyle(color: context.colors.danger)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loadSpaces,
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }
    if (_spaces.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noPanSpaces));
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
    final usagePercent =
        space.totalQuota > 0 ? space.usedQuota / space.totalQuota : 0.0;
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
                      style: AppText.lg.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)!.panFileCount(space.fileCount),
                    style: AppText.sm
                        .copyWith(color: context.colors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: usagePercent,
                  backgroundColor: context.colors.inputBg,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(context.colors.accent),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${formatPanSize(space.usedQuota)} / ${formatPanSize(space.totalQuota)}',
                style: AppText.xs.copyWith(color: context.colors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _spaceDisplayName(PanSpace space) {
    final l10n = AppLocalizations.of(context)!;
    switch (space.spaceType) {
      case PanSpaceType.globalPublic:
        return l10n.panGlobalPublicSpace;
      case PanSpaceType.userPublic:
        return l10n.panMyPublicSpace;
      case PanSpaceType.userPrivate:
        return l10n.panMyPrivateSpace;
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
  bool _loadFailed = false;

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
      _loadFailed = false;
    } catch (e, s) {
      debugPrint('Pan load files error: $e\n$s');
      _loadFailed = true;
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppShell.isDesktopStyle
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
      return AppLocalizations.of(context)!.pickDestination;
    }
    return widget.title ?? widget.space.name;
  }

  List<Widget> _buildActions() {
    final l10n = AppLocalizations.of(context)!;
    if (widget.isMoveMode) {
      final isSameLocation =
          widget.sourceSpace?.spaceId == widget.space.spaceId &&
              (widget.sourceParentId ?? 0) == widget.parentId;
      return [
        TextButton(
          onPressed: isSameLocation ? null : _executeMove,
          child: Text(l10n.paste),
        ),
        TextButton(
          onPressed: _cancelMoveCopy,
          child: Text(l10n.cancel),
        ),
      ];
    }

    if (widget.isCopyMode) {
      final isSameLocation =
          widget.sourceCopySpace?.spaceId == widget.space.spaceId &&
              (widget.sourceCopyParentId ?? 0) == widget.parentId;
      return [
        TextButton(
          onPressed: isSameLocation ? null : _executeCopy,
          child: Text(l10n.paste),
        ),
        TextButton(
          onPressed: _cancelMoveCopy,
          child: Text(l10n.cancel),
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
    if (_loadFailed) {
      final l10n = AppLocalizations.of(context)!;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.loadFailedRetry,
                style: TextStyle(color: context.colors.danger)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loadFiles,
              child: Text(l10n.retry),
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
              child: Text(AppLocalizations.of(context)!.noFilesYet),
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadFiles,
      child: ListView.separated(
        itemCount: _files.length,
        separatorBuilder: (_, __) => const Divider(),
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
            ? AppLocalizations.of(context)!.panItemCount(file.childCount)
            : '${file.sizeText}  ${file.creatorName ?? file.creatorId}',
        style: AppText.xs.copyWith(color: context.colors.textSecondary),
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
    final l10n = AppLocalizations.of(context)!;
    if (widget.isMoveMode &&
        widget.fileToMove != null &&
        widget.fileToMove!.isFolder &&
        widget.fileToMove!.fileId == file.fileId) {
      Fluttertoast.showToast(msg: l10n.panCannotMoveFolderIntoItself);
      return;
    }
    if (widget.isCopyMode &&
        widget.fileToCopy != null &&
        widget.fileToCopy!.isFolder &&
        widget.fileToCopy!.fileId == file.fileId) {
      Fluttertoast.showToast(msg: l10n.panCannotCopyFolderIntoItself);
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
    final l10n = AppLocalizations.of(context)!;
    try {
      final url = await PanService.getFileDownloadUrl(file.fileId);
      if (url.isNotEmpty) {
        if (mounted) Utilities.openLink(context, url);
      }
    } catch (e, s) {
      debugPrint('Pan open file error: $e\n$s');
      Fluttertoast.showToast(msg: l10n.panGetDownloadUrlFailed);
    }
  }

  Future<void> _uploadFile() async {
    final l10n = AppLocalizations.of(context)!;
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
                Text(l10n.uploading, style: AppText.lg),
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
                  child: Text(l10n.cancelUpload),
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
      Fluttertoast.showToast(msg: l10n.uploadSuccess);
      _loadFiles();
    } on PanException catch (e) {
      final dialogContext = await dialogContextCompleter.future;
      if (dialogContext.mounted) Navigator.pop(dialogContext);
      if (e.code == -2) {
        Fluttertoast.showToast(msg: l10n.uploadCancelled);
      } else {
        debugPrint('Pan upload error: $e');
        Fluttertoast.showToast(msg: l10n.uploadFail);
      }
    } catch (e, s) {
      final dialogContext = await dialogContextCompleter.future;
      if (dialogContext.mounted) Navigator.pop(dialogContext);
      debugPrint('Pan upload error: $e\n$s');
      Fluttertoast.showToast(msg: l10n.uploadFail);
    }
  }

  Future<void> _createFolder() async {
    final l10n = AppLocalizations.of(context)!;
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text(l10n.newFolder),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: l10n.folderName),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text(l10n.confirm),
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
      Fluttertoast.showToast(msg: l10n.createSuccess);
      _loadFiles();
    } catch (e, s) {
      debugPrint('Pan create folder error: $e\n$s');
      Fluttertoast.showToast(msg: l10n.createFail);
    }
  }

  Future<void> _renameFile(PanFile file) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: file.name);
        return AlertDialog(
          title: Text(l10n.rename),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: l10n.newName),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text(l10n.confirm),
            ),
          ],
        );
      },
    );
    if (name == null || name.isEmpty || name == file.name || !mounted) return;

    try {
      await PanService.renameFile(file.fileId, name);
      Fluttertoast.showToast(msg: l10n.renameSuccess);
      _loadFiles();
    } catch (e, s) {
      debugPrint('Pan rename error: $e\n$s');
      Fluttertoast.showToast(msg: l10n.renameFail);
    }
  }

  Future<void> _shareFile(PanFile file) async {
    final l10n = AppLocalizations.of(context)!;
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
      Fluttertoast.showToast(msg: l10n.panGetDownloadUrlFailed);
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
    final l10n = AppLocalizations.of(context)!;
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
        Fluttertoast.showToast(msg: l10n.panNoSpaceToSave);
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
      Fluttertoast.showToast(msg: l10n.panLoadSpacesFailed);
    }
  }

  Future<void> _doDuplicate(PanFile file, PanSpace targetSpace) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await PanService.copyFile(file.fileId, targetSpace.spaceId);
      Fluttertoast.showToast(msg: l10n.panDuplicateSuccess);
    } catch (e, s) {
      debugPrint('Pan duplicate error: $e\n$s');
      Fluttertoast.showToast(msg: l10n.panDuplicateFail);
    }
  }

  Future<void> _executeMove() async {
    final file = widget.fileToMove;
    if (file == null || widget.sourceSpace == null) return;

    final l10n = AppLocalizations.of(context)!;
    final isSameLocation =
        widget.sourceSpace!.spaceId == widget.space.spaceId &&
            (widget.sourceParentId ?? 0) == widget.parentId;
    if (isSameLocation) {
      Fluttertoast.showToast(msg: l10n.panCannotMoveToSameLocation);
      return;
    }

    try {
      await PanService.moveFile(file.fileId, widget.space.spaceId,
          targetParentId: widget.parentId);
      Fluttertoast.showToast(msg: l10n.moveSuccess);
      _returnToOriginalView();
    } catch (e, s) {
      debugPrint('Pan move error: $e\n$s');
      Fluttertoast.showToast(msg: l10n.moveFail);
    }
  }

  Future<void> _executeCopy() async {
    final file = widget.fileToCopy;
    if (file == null || widget.sourceCopySpace == null) return;

    final l10n = AppLocalizations.of(context)!;
    final isSameLocation =
        widget.sourceCopySpace!.spaceId == widget.space.spaceId &&
            (widget.sourceCopyParentId ?? 0) == widget.parentId;
    if (isSameLocation) {
      Fluttertoast.showToast(msg: l10n.panCannotCopyToSameLocation);
      return;
    }

    try {
      await PanService.copyFile(file.fileId, widget.space.spaceId,
          targetParentId: widget.parentId);
      Fluttertoast.showToast(msg: l10n.copySuccess);
      _returnToOriginalView();
    } catch (e, s) {
      debugPrint('Pan copy error: $e\n$s');
      Fluttertoast.showToast(msg: l10n.copyFail);
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
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.deleteFileConfirm(file.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete,
                style: TextStyle(color: context.colors.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await PanService.deleteFile(file.fileId);
      Fluttertoast.showToast(msg: l10n.deleteSuccess);
      _loadFiles();
    } catch (e, s) {
      debugPrint('Pan delete error: $e\n$s');
      Fluttertoast.showToast(msg: l10n.deleteFailed);
    }
  }

  void _showFileMenu(PanFile file) {
    final l10n = AppLocalizations.of(context)!;
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
                title: Text(l10n.downloadOrOpen),
                onTap: () {
                  Navigator.pop(ctx);
                  _openFile(file);
                },
              ),
            if (canManage) ...[
              if (!file.isFolder)
                ListTile(
                  leading: const Icon(Icons.share),
                  title: Text(l10n.share),
                  onTap: () {
                    Navigator.pop(ctx);
                    _shareFile(file);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.drive_file_move_outline),
                title: Text(l10n.move),
                onTap: () {
                  Navigator.pop(ctx);
                  _startMoveFile(file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.file_copy_outlined),
                title: Text(l10n.copy),
                onTap: () {
                  Navigator.pop(ctx);
                  _startCopyFile(file);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: Text(l10n.rename),
                onTap: () {
                  Navigator.pop(ctx);
                  _renameFile(file);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: ctx.colors.danger),
                title: Text(l10n.delete,
                    style: TextStyle(color: ctx.colors.danger)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteFile(file);
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.file_copy_outlined),
                title: Text(l10n.panDuplicate),
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
