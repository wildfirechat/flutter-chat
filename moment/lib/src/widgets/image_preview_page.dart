import 'package:flutter/material.dart';
import 'package:moment/client/momentclient.dart';
import 'package:video_player/video_player.dart';

import '../moment_media_picker.dart';
import 'moment_page_scaffold.dart';
import 'moment_widgets.dart';

/// 图片全屏预览（支持缩放）。
class ImagePreviewPage extends StatelessWidget {
  final List<FeedEntry> entries;
  final int initialIndex;

  const ImagePreviewPage({
    super.key,
    required this.entries,
    this.initialIndex = 0,
  });

  static void open(BuildContext context, List<FeedEntry> entries, int index) {
    final entry = entries[index];
    if (momentIsVideoFile(entry.mediaUrl)) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VideoPlayPage(url: entry.mediaUrl),
      ));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ImagePreviewPage(entries: entries, initialIndex: index),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return MomentPageScaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return InteractiveViewer(
            maxScale: 5,
            child: Center(
              child: MomentNetworkImage(entry.mediaUrl, fit: BoxFit.contain),
            ),
          );
        },
      ),
    );
  }
}

/// 简易视频播放页。
class VideoPlayPage extends StatefulWidget {
  final String url;

  const VideoPlayPage({super.key, required this.url});

  @override
  State<VideoPlayPage> createState() => _VideoPlayPageState();
}

class _VideoPlayPageState extends State<VideoPlayPage> {
  VideoPlayerController? _controller;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
      controller.play();
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return MomentPageScaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: _error
            ? const Text('视频播放失败',
                style: TextStyle(color: Colors.white70))
            : controller == null
                ? const CircularProgressIndicator(color: Colors.white)
                : GestureDetector(
                    onTap: () {
                      setState(() {
                        controller.value.isPlaying
                            ? controller.pause()
                            : controller.play();
                      });
                    },
                    child: AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: VideoPlayer(controller),
                    ),
                  ),
      ),
    );
  }
}
