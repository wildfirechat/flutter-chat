import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:imclient/message/composite_message_content.dart';
import 'package:imclient/message/file_message_content.dart';
import 'package:imclient/message/image_message_content.dart';
import 'package:imclient/message/link_message_content.dart';
import 'package:imclient/message/message_content.dart';
import 'package:imclient/message/sound_message_content.dart';
import 'package:imclient/message/text_message_content.dart';
import 'package:imclient/message/video_message_content.dart';
import 'package:chat/app_server.dart';
import 'package:chat/conversation/composite_message_detail_screen.dart';
import 'package:chat/conversation/mm_preview_view.dart';
import 'package:chat/model/favorite_item.dart';
import 'package:chat/utilities.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class FavoriteListScreen extends StatefulWidget {
  const FavoriteListScreen({Key? key}) : super(key: key);

  @override
  State<FavoriteListScreen> createState() => _FavoriteListScreenState();
}

class _FavoriteListScreenState extends State<FavoriteListScreen> {
  List<FavoriteItem> _items = [];
  bool _hasMore = false;
  bool _isLoading = false;
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    AppServer.getFavoriteItems(_nextId, 20, (items, hasMore) {
      if (mounted) {
        setState(() {
          if (_nextId == 0) {
            _items = items;
          } else {
            _items.addAll(items);
          }
          _hasMore = hasMore;
          if (items.isNotEmpty) {
            _nextId = items.last.favId;
          }
          _isLoading = false;
        });
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

  void _onTapItem(FavoriteItem item) {
    var message = item.toMessage();
    if (message.content is ImageMessageContent) {
      Navigator.push(
        context,
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (context, animation, secondaryAnimation) =>
              MMPreviewView(
            [message],
            defaultIndex: 0,
            pageToEnd: (fromIndex, tail) {},
          ),
        ),
      );
    } else if (message.content is VideoMessageContent) {
      Navigator.push(
        context,
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (context, animation, secondaryAnimation) =>
              MMPreviewView(
                  [message],
                  defaultIndex: 0,
                  pageToEnd: (fromIndex, tail) {},
              ),
        ),
      );
    } else if (message.content is FileMessageContent) {
      // TODO: Open file
      Fluttertoast.showToast(msg: "${AppLocalizations.of(context)!.fileLabel}${(message.content as FileMessageContent).name}");
    } else if (message.content is CompositeMessageContent) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CompositeMessageDetailScreen(message.content as CompositeMessageContent),
        ),
      );
    } else if (message.content is TextMessageContent) {
      // TODO: Show text detail
      Fluttertoast.showToast(msg: (message.content as TextMessageContent).text);
    } else if (message.content is LinkMessageContent) {
      // TODO: Open link
      Fluttertoast.showToast(msg: "${AppLocalizations.of(context)!.linkLabel}${(message.content as LinkMessageContent).url}");
    } else {
      Fluttertoast.showToast(msg: AppLocalizations.of(context)!.unsupportedMessageType);
    }
  }

  Widget _buildIcon(FavoriteItem item) {
    if (item.favType == MESSAGE_CONTENT_TYPE_IMAGE || item.favType == MESSAGE_CONTENT_TYPE_VIDEO) {
      if (item.thumbUrl.isNotEmpty) {
        return Image.network(item.thumbUrl, width: 50, height: 50, fit: BoxFit.cover);
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
                  Image(image: MemoryImage(bytes), width: 50, height: 50, fit: BoxFit.cover),
                  const Icon(Icons.play_circle_outline, color: Colors.white, size: 20),
                ],
              );
            } else {
              return Image(image: MemoryImage(bytes), width: 50, height: 50, fit: BoxFit.cover);
            }
          }
        } catch (e) {
          // ignore
        }
      }
      return Container(width: 50, height: 50, color: Colors.grey[300], child: const Icon(Icons.image));
    } else if (item.favType == MESSAGE_CONTENT_TYPE_FILE) {
      return Container(width: 50, height: 50, color: Colors.orange[100], child: const Icon(Icons.insert_drive_file, color: Colors.orange));
    } else if (item.favType == MESSAGE_CONTENT_TYPE_SOUND) {
      return Container(width: 50, height: 50, color: Colors.green[100], child: const Icon(Icons.mic, color: Colors.green));
    } else if (item.favType == MESSAGE_CONTENT_TYPE_LINK) {
      if (item.thumbUrl.isNotEmpty) {
        return Image.network(item.thumbUrl, width: 50, height: 50, fit: BoxFit.cover);
      }
      return Container(width: 50, height: 50, color: Colors.blue[100], child: const Icon(Icons.link, color: Colors.blue));
    } else if (item.favType == MESSAGE_CONTENT_TYPE_COMPOSITE_MESSAGE) {
      return Container(width: 50, height: 50, color: Colors.purple[100], child: const Icon(Icons.chat, color: Colors.purple));
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
      onTap: () => _onTapItem(item),
      onLongPress: () {
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
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE5E5E5), width: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIcon(item),
            if (item.favType != MESSAGE_CONTENT_TYPE_TEXT) const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title.isNotEmpty ? item.title : _getDefaultTitle(item),
                    style: const TextStyle(fontSize: 16, color: Colors.black),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        item.origin,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        Utilities.formatTime(context, item.timestamp),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.myFavorites),
      ),
      body: _buildBody(),
    );
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
