import 'dart:math' as math;
import 'package:flutter/material.dart';

enum EmojiAnimationType {
  bounce, // Happy / jumping
  heartbeat, // Love / pulsing
  weep, // Sad / weeping
  tremble, // Angry / scared
  tilt, // Cool / party / sliding tilt
  breath, // Sleep / breathing
  pulse, // Default gentle pulsing
}

class AnimatedEmojiWidget extends StatefulWidget {
  final String emoji;
  final double size;
  final bool repeat;
  final bool animateOnMount;

  const AnimatedEmojiWidget({
    super.key,
    required this.emoji,
    this.size = 24.0,
    this.repeat = true,
    this.animateOnMount = true,
  });

  @override
  State<AnimatedEmojiWidget> createState() => _AnimatedEmojiWidgetState();
}

class _AnimatedEmojiWidgetState extends State<AnimatedEmojiWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late EmojiAnimationType _animationType;

  // Asset mapping for animated emojis (GIF, WebP, etc.)
  // Users can put GIF/WebP files under assets/images/animated_emoji/ and map them here.
  static const Map<String, String> _animatedEmojiAssets = {
    // '😊': 'assets/images/animated_emoji/smile.gif',
    // '😍': 'assets/images/animated_emoji/love.gif',
  };

  @override
  void initState() {
    super.initState();
    _animationType = _determineAnimationType(widget.emoji);

    Duration duration;
    switch (_animationType) {
      case EmojiAnimationType.tremble:
        duration = const Duration(milliseconds: 150);
        break;
      case EmojiAnimationType.heartbeat:
        duration = const Duration(milliseconds: 800);
        break;
      case EmojiAnimationType.bounce:
        duration = const Duration(milliseconds: 600);
        break;
      case EmojiAnimationType.tilt:
        duration = const Duration(milliseconds: 1000);
        break;
      case EmojiAnimationType.weep:
        duration = const Duration(milliseconds: 1200);
        break;
      case EmojiAnimationType.breath:
        duration = const Duration(milliseconds: 2000);
        break;
      case EmojiAnimationType.pulse:
        duration = const Duration(milliseconds: 1500);
        break;
    }

    _controller = AnimationController(vsync: this, duration: duration);
    if (widget.repeat) {
      _controller.repeat(reverse: _shouldReverse(_animationType));
    } else if (widget.animateOnMount) {
      _playAnimation();
    }
  }

  void _playAnimation() {
    _controller.forward(from: 0.0).then((_) {
      if (mounted && !widget.repeat) {
        if (_shouldReverse(_animationType)) {
          _controller.reverse();
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _shouldReverse(EmojiAnimationType type) {
    switch (type) {
      case EmojiAnimationType.tremble:
      case EmojiAnimationType.heartbeat:
        return false; // Loop continuously
      default:
        return true; // Yoyo back and forth
    }
  }

  EmojiAnimationType _determineAnimationType(String emoji) {
    // Group emojis into appropriate animation styles
    if (const ['😊', '😀', '😁', '😃', '😅', '😜', '😝', '😆', '☺', '😄', '😋']
        .contains(emoji)) {
      return EmojiAnimationType.bounce;
    } else if (const ['😍', '😘', '😚', '💋', '💔', '👼'].contains(emoji)) {
      return EmojiAnimationType.heartbeat;
    } else if (const [
      '😭',
      '😢',
      '😰',
      '😓',
      '😩',
      '😔',
      '😞',
      '😟',
      '😖',
      '😫',
      '😣'
    ].contains(emoji)) {
      return EmojiAnimationType.weep;
    } else if (const [
      '😡',
      '😤',
      '😨',
      '😱',
      '😬',
      '👿',
      '😈',
      '💣',
      '🔥',
      '💢'
    ].contains(emoji)) {
      return EmojiAnimationType.tremble;
    } else if (const ['😎', '😉', '😏', '🎩', '🎉', '🎁', '🎵', '🍻', '🚀']
        .contains(emoji)) {
      return EmojiAnimationType.tilt;
    } else if (const ['😴', '💤', '😌', '😶', '😑'].contains(emoji)) {
      return EmojiAnimationType.breath;
    }
    return EmojiAnimationType.pulse;
  }

  @override
  Widget build(BuildContext context) {
    final String? assetPath = _animatedEmojiAssets[widget.emoji];

    // If an asset path is mapped, render the local animated image (e.g. GIF)
    if (assetPath != null) {
      return GestureDetector(
        onTap: _playAnimation,
        child: Image.asset(
          assetPath,
          width: widget.size,
          height: widget.size,
          gaplessPlayback: true,
        ),
      );
    }

    // Procedural Fallback Animation
    return GestureDetector(
      onTap: _playAnimation,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final Widget animatedChild = Text(
            widget.emoji,
            style: TextStyle(
              fontSize: widget.size,
              // Keep height 1 to prevent text baseline alignment issues in WidgetSpan
              height: 1.0,
            ),
          );

          switch (_animationType) {
            case EmojiAnimationType.bounce:
              // Jumps up and down with squash and stretch at the bottom
              final double value = _controller.value;
              final double bounceY =
                  -math.sin(value * math.pi) * (widget.size * 0.25);
              // Squashes slightly when reaching the bottom (value near 0 or 1)
              final double scaleY = 1.0 + (math.cos(value * math.pi * 2) * 0.1);
              final double scaleX =
                  1.0 - (math.cos(value * math.pi * 2) * 0.08);

              return Transform.translate(
                offset: Offset(0, bounceY),
                child: Transform.scale(
                  scaleX: scaleX,
                  scaleY: scaleY,
                  alignment: Alignment.bottomCenter,
                  child: animatedChild,
                ),
              );

            case EmojiAnimationType.heartbeat:
              // Dual beat pulsing pattern (scale up fast twice, then reset)
              final double value = _controller.value;
              double scale = 1.0;
              if (value < 0.2) {
                scale = 1.0 + (value / 0.2) * 0.25; // First beat
              } else if (value < 0.4) {
                scale = 1.25 - ((value - 0.2) / 0.2) * 0.15; // First decay
              } else if (value < 0.6) {
                scale = 1.1 + ((value - 0.4) / 0.2) * 0.2; // Second beat
              } else {
                scale = 1.3 - ((value - 0.6) / 0.4) * 0.3; // Full decay
              }

              return Transform.scale(
                scale: scale,
                alignment: Alignment.center,
                child: animatedChild,
              );

            case EmojiAnimationType.weep:
              // Weeps / shakes vertically with slow breathing
              final double value = _controller.value;
              final double offsetY = math.sin(value * math.pi * 6) * 1.5;
              final double scale = 0.95 + (math.sin(value * math.pi) * 0.1);

              return Transform.translate(
                offset: Offset(0, offsetY),
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.center,
                  child: animatedChild,
                ),
              );

            case EmojiAnimationType.tremble:
              // Trembles rapidly in random directions (simulating anger or extreme fear)
              final double value = _controller.value;
              final double envelope = widget.repeat ? 1.0 : (1.0 - value);
              final double offsetX =
                  (math.sin(value * math.pi * 10) * 1.5) * envelope;
              final double offsetY =
                  (math.cos(value * math.pi * 8) * 1.0) * envelope;

              return Transform.translate(
                offset: Offset(offsetX, offsetY),
                child: animatedChild,
              );

            case EmojiAnimationType.tilt:
              // Cool tilt left and right (rotation)
              final double value = _controller.value;
              final double angle = (value - 0.5) * 0.35; // radians
              final double scale = 1.0 + (math.sin(value * math.pi) * 0.05);

              return Transform.rotate(
                angle: angle,
                alignment: Alignment.center,
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.center,
                  child: animatedChild,
                ),
              );

            case EmojiAnimationType.breath:
              // Slow, deep breathing scale and fade effect
              final double value = _controller.value;
              final double scale = 0.9 + (value * 0.18);
              final double opacity = 0.65 + (value * 0.35);

              return Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.bottomCenter,
                  child: animatedChild,
                ),
              );

            case EmojiAnimationType.pulse:
              // Default gentle pulse
              final double value = _controller.value;
              final double scale = 1.0 + (value * 0.12);

              return Transform.scale(
                scale: scale,
                alignment: Alignment.center,
                child: animatedChild,
              );
          }
        },
      ),
    );
  }
}
