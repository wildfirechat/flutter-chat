import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chat/widget/drag_to_dismiss.dart';

class VideoPlayerView extends StatefulWidget {
  final String remoteUrl;

  const VideoPlayerView(this.remoteUrl, {Key? key}) : super(key: key);
  @override
  State<StatefulWidget> createState() => VideoPlayerViewState();
}

class VideoPlayerViewState extends State<VideoPlayerView> {
  late VideoPlayerController _controller;
  bool _showControls = false; // Hide controls initially or on tap
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.remoteUrl));
    _controller.initialize().then((value) {
      _controller.play().then((value) {
        setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Replace Scaffold with DragToDismiss -> Stack for transparency
    return DragToDismiss(
      onDismiss: () {
        Navigator.pop(context);
      },
      onDragStart: () {
        setState(() {
          _isDragging = true;
        });
      },
      onDragEnd: () {
        setState(() {
          _isDragging = false;
        });
      },
      child: Material(
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video
            GestureDetector(
              onTap: () {
                setState(() {
                  _showControls = !_showControls;
                });
              },
              child: Center(
                child: _controller.value.isInitialized
                    ? AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      )
                    : const CircularProgressIndicator(color: Colors.white),
              ),
            ),
            // Play/Pause Button (only if controls shown)
            if (!_isDragging && (_showControls || !_controller.value.isPlaying))
              Center(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_controller.value.isPlaying) {
                        _controller.pause();
                      } else {
                        _controller.play();
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _controller.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
            // Back Button (custom, instead of AppBar)
            if (!_isDragging)
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 10,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
