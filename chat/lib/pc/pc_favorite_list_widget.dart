import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/imclient.dart';
import 'package:imclient/message/composite_message_content.dart';
import 'package:imclient/message/file_message_content.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/link_message_content.dart';
import 'package:imclient/message/message.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/message/sound_message_content.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:imclient/message/unknown_message_content.dart';
import 'package:imclient/message/video_message_content.dart';
import 'package:imclient/model/conversation.dart';
import 'package:chat/app_server.dart';
import 'package:chat/conversation/composite_message_detail_screen.dart';
import 'package:chat/conversation/forward/show_pick_forward_target.dart';
import 'package:chat/conversation/mm_preview_view.dart';
import 'package:chat/model/favorite_item.dart';
import 'package:chat/pc/pc_platform.dart';
import 'package:chat/pc/widgets/pc_page_header.dart';
import 'package:chat/utilities.dart';
import 'package:chat/utils/media_url_redirector.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/app_navigator.dart';
import 'package:chat/theme/app_colors.dart';

/// 收藏分类。
///
/// 对应 vue-pc-chat 的 `FavPage` 分类:
/// `all`, `file`, `media`, `composite`。
enum FavoriteCategory {
  all,
  file,
  media,
  composite,
}

/// PC 中栏使用的收藏分类入口,以及可在右栏复用的收藏列表。
///
/// [category] 控制显示哪类收藏; [isEmbedded] 为 true 时用于中栏入口列表,
/// 为 false 时作为独立列表页(带标题/搜索)放到右栏或移动端。
class FavoriteListWidget extends StatefulWidget {
  final FavoriteCategory category;
  final bool isEmbedded;

  const FavoriteListWidget({
    super.key,
    this.category = FavoriteCategory.all,
    this.isEmbedded = true,
  });

  @override
  State<FavoriteListWidget> createState() => _FavoriteListWidgetState();
}

class _FavoriteListWidgetState extends State<FavoriteListWidget> {
  List<FavoriteItem> _items = [];
  bool _hasMore = false;
  bool _isLoading = false;
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(FavoriteListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.category != oldWidget.category) {
      _refresh();
    }
  }

  void _refresh() {
    setState(() {
      _items.clear();
      _hasMore = true;
      _nextId = 0;
      _isLoading = false;
    });
    _loadData();
  }

  void _loadData() {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    AppServer.getFavoriteItems(_nextId, 20, (items, hasMore) {
      if (!mounted) return;
      final filtered = _filterByCategory(items);
      setState(() {
        if (_nextId == 0) {
          _items = filtered;
        } else {
          _items.addAll(filtered);
        }
        _hasMore = hasMore;
        if (items.isNotEmpty) {
          _nextId = items.last.favId;
        }
        _isLoading = false;
      });

      // 如果当前这一页没有命中目标分类且还有更多,继续加载。
      if (filtered.isEmpty && hasMore && items.isNotEmpty) {
        _loadData();
      }
    }, (msg) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        Fluttertoast.showToast(msg: msg);
      }
    });
  }

  List<FavoriteItem> _filterByCategory(List<FavoriteItem> items) {
    switch (widget.category) {
      case FavoriteCategory.file:
        return items.where((fi) => fi.favType == MESSAGE_CONTENT_TYPE_FILE).toList();
      case FavoriteCategory.media:
        return items
            .where((fi) =>
                fi.favType == MESSAGE_CONTENT_TYPE_IMAGE ||
                fi.favType == MESSAGE_CONTENT_TYPE_VIDEO)
            .toList();
      case FavoriteCategory.composite:
        return items
            .where((fi) => fi.favType == MESSAGE_CONTENT_TYPE_COMPOSITE_MESSAGE)
            .toList();
      case FavoriteCategory.all:
        return items;
    }
  }

  void _deleteItem(FavoriteItem item) {
    AppServer.removeFavoriteItem(item.favId, () {
      setState(() {
        _items.remove(item);
      });
      Fluttertoast.showToast(msg: AppLocalizations.of(context)!.deleteSuccess);
    }, (msg) {
      Fluttertoast.showToast(msg: msg);
    });
  }

  void _showFavoriteItemMenu(FavoriteItem item) {
    final l10n = AppLocalizations.of(context)!;
    final message = item.toMessage();
    final content = message.content;
    final canDownload = item.url.isNotEmpty &&
        (content is ImageMessageContent ||
            content is VideoMessageContent ||
            content is FileMessageContent ||
            content is SoundMessageContent);

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new_outlined),
              title: Text(l10n.open),
              onTap: () {
                Navigator.pop(ctx);
                _openItem(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: Text(l10n.forward),
              onTap: () {
                Navigator.pop(ctx);
                _forwardItem(item);
              },
            ),
            if (canDownload)
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: Text(l10n.download),
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadItem(item);
                },
              ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: context.colors.danger),
              title: Text(l10n.delete, style: TextStyle(color: context.colors.danger)),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteConfirm(item);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _forwardItem(FavoriteItem item) {
    final message = item.toMessage();
    if (message.content is UnknownMessageContent) {
      Fluttertoast.showToast(msg: AppLocalizations.of(context)!.unsupportedMessageType);
      return;
    }
    showPickForwardTarget(
      context,
      messages: [message],
      onSelected: (targets, comment) {
        _sendForwardMessages(targets, [message], comment);
      },
    );
  }

  void _sendForwardMessages(List<Conversation> targets, List<Message> messages, String? comment) {
    final l10n = AppLocalizations.of(context)!;
    final total = targets.length * messages.length + (comment != null && comment.isNotEmpty ? targets.length : 0);
    int successCount = 0;
    int failCount = 0;

    void checkComplete() {
      if (successCount + failCount >= total) {
        if (failCount == 0) {
          Fluttertoast.showToast(msg: '${l10n.forward}${l10n.success}');
        } else {
          Fluttertoast.showToast(msg: '${l10n.send}${l10n.success}: $successCount, ${l10n.setFail}$failCount');
        }
      }
    }

    if (comment != null && comment.isNotEmpty) {
      for (final target in targets) {
        Imclient.sendMessage(
          target,
          TextMessageContent(comment),
          successCallback: (_, __) {
            successCount++;
            checkComplete();
          },
          errorCallback: (_) {
            failCount++;
            checkComplete();
          },
        );
      }
    }
    for (final target in targets) {
      for (final msg in messages) {
        Imclient.sendMessage(
          target,
          msg.content,
          successCallback: (_, __) {
            successCount++;
            checkComplete();
          },
          errorCallback: (_) {
            failCount++;
            checkComplete();
          },
        );
      }
    }
  }

  Future<void> _downloadItem(FavoriteItem item) async {
    final l10n = AppLocalizations.of(context)!;
    final fileName = item.title.isNotEmpty
        ? item.title
        : (item.favType == MESSAGE_CONTENT_TYPE_IMAGE
            ? 'image_${item.favId}.jpg'
            : item.favType == MESSAGE_CONTENT_TYPE_VIDEO
                ? 'video_${item.favId}.mp4'
                : item.favType == MESSAGE_CONTENT_TYPE_SOUND
                    ? 'voice_${item.favId}.aac'
                    : 'file_${item.favId}');
    try {
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: l10n.saveFile,
        fileName: fileName,
      );
      if (outputFile == null) return;

      final url = item.url;
      if (url.isEmpty) {
        Fluttertoast.showToast(msg: l10n.saveFailSourceMissing);
        return;
      }

      Imclient.getAuthorizedMediaUrl(
        url,
        item.messageUid,
        _mediaTypeForFavType(item.favType).index,
        (authorizedUrl) async {
          try {
            final client = HttpClient();
            final request = await client.getUrl(Uri.parse(MediaUrlRedirector.redirect(authorizedUrl)));
            final response = await request.close();
            final bytes = await response.fold<List<int>>([], (prev, element) => prev..addAll(element));
            await File(outputFile).writeAsBytes(bytes);
            Fluttertoast.showToast(msg: l10n.saveSuccess);
          } catch (e) {
            Fluttertoast.showToast(msg: l10n.saveFail('$e'));
          }
        },
        (errorCode) {
          Fluttertoast.showToast(msg: l10n.saveFailSourceMissing);
        },
      );
    } catch (e) {
      Fluttertoast.showToast(msg: l10n.saveFail('$e'));
    }
  }

  MediaType _mediaTypeForFavType(int favType) {
    switch (favType) {
      case MESSAGE_CONTENT_TYPE_IMAGE:
        return MediaType.Media_Type_IMAGE;
      case MESSAGE_CONTENT_TYPE_VIDEO:
        return MediaType.Media_Type_VIDEO;
      case MESSAGE_CONTENT_TYPE_SOUND:
        return MediaType.Media_Type_VOICE;
      case MESSAGE_CONTENT_TYPE_FILE:
      default:
        return MediaType.Media_Type_FILE;
    }
  }

  void _showDeleteConfirm(FavoriteItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteFavorite),
        content: Text(AppLocalizations.of(context)!.deleteFavoriteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteItem(item);
            },
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
  }

  void _openItem(FavoriteItem item) {
    final message = item.toMessage();
    final content = message.content;
    if (content is ImageMessageContent || content is VideoMessageContent) {
      final preview = MMPreviewView(
        [message],
        defaultIndex: 0,
        pageToEnd: (fromIndex, tail) {},
      );
      if (isDesktopShell) {
        showDialog(
          context: context,
          barrierColor: Colors.black,
          useSafeArea: false,
          builder: (_) => preview,
        );
      } else {
        Navigator.push(
          context,
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (context, animation, secondaryAnimation) => preview,
          ),
        );
      }
    } else if (content is FileMessageContent) {
      Fluttertoast.showToast(
          msg: '${AppLocalizations.of(context)!.fileLabel}${content.name}');
    } else if (content is CompositeMessageContent) {
      pushPage(context, CompositeMessageDetailScreen(content));
    } else if (content is TextMessageContent) {
      Fluttertoast.showToast(msg: content.text);
    } else if (content is LinkMessageContent) {
      Fluttertoast.showToast(
          msg: '${AppLocalizations.of(context)!.linkLabel}${content.url}');
    } else {
      Fluttertoast.showToast(
          msg: AppLocalizations.of(context)!.unsupportedMessageType);
    }
  }

  Widget _buildIcon(FavoriteItem item) {
    if (item.favType == MESSAGE_CONTENT_TYPE_IMAGE ||
        item.favType == MESSAGE_CONTENT_TYPE_VIDEO) {
      if (item.thumbUrl.isNotEmpty) {
        return Image.network(
          MediaUrlRedirector.redirect(item.thumbUrl),
          width: 50,
          height: 50,
          fit: BoxFit.cover,
        );
      } else if (item.data.isNotEmpty) {
        try {
          var map = json.decode(item.data);
          var thumb = map['thumb'];
          if (thumb != null && thumb is String && thumb.isNotEmpty) {
            Uint8List bytes = base64Decode(thumb);
            if (item.favType == MESSAGE_CONTENT_TYPE_VIDEO) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  Image(
                    image: MemoryImage(bytes),
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                  const Icon(Icons.play_circle_outline,
                      color: Colors.white, size: 20),
                ],
              );
            } else {
              return Image(
                image: MemoryImage(bytes),
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              );
            }
          }
        } catch (e) {
          // ignore
        }
      }
      return Container(
        width: 50,
        height: 50,
        color: context.colors.inputBg,
        child: const Icon(Icons.image),
      );
    } else if (item.favType == MESSAGE_CONTENT_TYPE_FILE) {
      return Container(
        width: 50,
        height: 50,
        color: Colors.orange[100],
        child: const Icon(Icons.insert_drive_file, color: Colors.orange),
      );
    } else if (item.favType == MESSAGE_CONTENT_TYPE_SOUND) {
      return Container(
        width: 50,
        height: 50,
        color: Colors.green[100],
        child: const Icon(Icons.mic, color: Colors.green),
      );
    } else if (item.favType == MESSAGE_CONTENT_TYPE_LINK) {
      if (item.thumbUrl.isNotEmpty) {
        return Image.network(
          MediaUrlRedirector.redirect(item.thumbUrl),
          width: 50,
          height: 50,
          fit: BoxFit.cover,
        );
      }
      return Container(
        width: 50,
        height: 50,
        color: Colors.blue[100],
        child: const Icon(Icons.link, color: Colors.blue),
      );
    } else if (item.favType == MESSAGE_CONTENT_TYPE_COMPOSITE_MESSAGE) {
      return Container(
        width: 50,
        height: 50,
        color: Colors.purple[100],
        child: const Icon(Icons.chat, color: Colors.purple),
      );
    }
    return const SizedBox(width: 0, height: 0);
  }

  String _getDefaultTitle(FavoriteItem item) {
    switch (item.favType) {
      case MESSAGE_CONTENT_TYPE_IMAGE:
        return AppLocalizations.of(context)!.imageTag;
      case MESSAGE_CONTENT_TYPE_VIDEO:
        return AppLocalizations.of(context)!.videoTag;
      case MESSAGE_CONTENT_TYPE_SOUND:
        return AppLocalizations.of(context)!.voiceTag;
      case MESSAGE_CONTENT_TYPE_COMPOSITE_MESSAGE:
        return '${AppLocalizations.of(context)!.chatHistoryTag} ${item.title}';
      case MESSAGE_CONTENT_TYPE_FILE:
        return '${AppLocalizations.of(context)!.fileTag} ${item.title}';
      case MESSAGE_CONTENT_TYPE_LINK:
        return '${AppLocalizations.of(context)!.linkTag} ${item.title}';
      default:
        return item.title;
    }
  }

  Widget _buildItem(FavoriteItem item) {
    return InkWell(
      onTap: () => _showFavoriteItemMenu(item),
      onLongPress: () => _showFavoriteItemMenu(item),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: context.colors.hairlineSoft, width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIcon(item),
            if (item.favType != MESSAGE_CONTENT_TYPE_TEXT)
              const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title.isNotEmpty ? item.title : _getDefaultTitle(item),
                    style: TextStyle(fontSize: 16, color: context.colors.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        item.origin,
                        style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        Utilities.formatTime(context, item.timestamp),
                        style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEmbedded) {
      return _buildBody();
    }
    return Scaffold(
      appBar: isDesktopShell
          ? PcPageHeader(title: _pageTitle(context))
          : AppBar(title: Text(_pageTitle(context))),
      backgroundColor: isDesktopShell ? context.colors.chatBgDesktop : null,
      body: _buildBody(),
    );
  }

  String _pageTitle(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (widget.category) {
      case FavoriteCategory.file:
        return l10n.favoritesFile;
      case FavoriteCategory.media:
        return l10n.favoritesMedia;
      case FavoriteCategory.composite:
        return l10n.favoritesComposite;
      case FavoriteCategory.all:
        return l10n.myFavorites;
    }
  }

  Widget _buildBody() {
    if (_items.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noFavorites));
    }
    return ListView.builder(
      itemCount: _items.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          _loadData();
          return const Padding(
            padding: EdgeInsets.all(10.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildItem(_items[index]);
      },
    );
  }
}
