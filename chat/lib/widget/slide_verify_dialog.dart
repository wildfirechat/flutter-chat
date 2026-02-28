import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app_server.dart';

/// 滑动验证对话框回调
abstract class SlideVerifyListener {
  /// 验证成功
  void onVerifySuccess(String token);

  /// 验证失败（滑动位置不对），不关闭窗口
  void onVerifyFailed();

  /// 加载验证码失败，需要关闭窗口
  void onLoadFailed();
}

/// 滑动验证数据模型
class SlideVerifyData {
  final String token;
  final Uint8List backgroundImageBytes;
  final Uint8List sliderImageBytes;
  final double y;

  SlideVerifyData({
    required this.token,
    required this.backgroundImageBytes,
    required this.sliderImageBytes,
    required this.y,
  });
}

/// 滑动验证对话框
///
/// 使用方法:
/// ```dart
/// SlideVerifyDialog.show(
///   context: context,
///   listener: MySlideVerifyListener(),
/// );
/// ```
class SlideVerifyDialog extends StatefulWidget {
  final SlideVerifyListener listener;

  const SlideVerifyDialog({
    super.key,
    required this.listener,
  });

  /// 显示滑动验证对话框
  static Future<void> show({
    required BuildContext context,
    required SlideVerifyListener listener,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => SlideVerifyDialog(listener: listener),
    );
  }

  @override
  State<SlideVerifyDialog> createState() => _SlideVerifyDialogState();
}

class _SlideVerifyDialogState extends State<SlideVerifyDialog>
    with TickerProviderStateMixin {
  // 状态
  bool _isLoading = true;
  bool _isVerifying = false;
  String? _errorMessage;

  // 验证数据
  SlideVerifyData? _verifyData;

  // 滑动相关
  double _sliderPosition = 0;
  double _maxSliderPosition = 0;
  double _imageScaleX = 1.0;
  double _imageScaleY = 1.0;

  // UI 相关
  final double _sliderButtonWidth = 48;
  final double _trackHeight = 48;
  final double _backgroundImageHeight = 150; // 服务器返回的图片高度参考值
  final double _backgroundImageWidth = 300; // 服务器返回的图片宽度参考值

  // 动画控制器
  AnimationController? _resetAnimationController;

  // 拖动开始位置
  double _dragStartX = 0;
  double _sliderStartPosition = 0;

  // 提示文字状态
  String _hintText = '向右滑动完成验证';
  Color _hintColor = const Color(0xFF999999);
  Color _sliderButtonColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _loadVerifyCode();
  }

  @override
  void dispose() {
    _resetAnimationController?.dispose();
    super.dispose();
  }

  /// 加载验证码
  Future<void> _loadVerifyCode() async {
    if (_isVerifying) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    AppServer.generateSlideVerifyCode(
      onSuccess: (data) {
        if (!mounted) return;
        setState(() {
          _verifyData = data;
          _isLoading = false;
          _sliderPosition = 0;
          _hintText = '向右滑动完成验证';
          _hintColor = const Color(0xFF999999);
          _sliderButtonColor = Colors.white;
        });
      },
      onError: (msg) {
        if (!mounted) return;
        setState(() {
          _errorMessage = msg;
          _isLoading = false;
        });
        // 延迟关闭对话框
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pop();
            widget.listener.onLoadFailed();
          }
        });
      },
    );
  }

  /// 验证滑动位置
  Future<void> _verifySlidePosition() async {
    if (_isVerifying || _verifyData == null) return;

    // 滑动距离太短，重置位置
    if (_sliderPosition < 10) {
      _resetSliderPosition();
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    // 计算原始 x 位置（基于图片缩放比例）
    final originalX = (_sliderPosition / _imageScaleX).round();

    AppServer.verifySlideCode(
      token: _verifyData!.token,
      x: originalX,
      onSuccess: () {
        _onVerifySuccess();
      },
      onError: () {
        _onVerifyFailed();
      },
    );
  }

  /// 验证成功处理
  void _onVerifySuccess() {
    if (!mounted) return;

    setState(() {
      _sliderButtonColor = const Color(0xFF4CAF50);
      _hintText = '验证成功';
      _hintColor = const Color(0xFF4CAF50);
      _isVerifying = false;
    });

    // 延迟关闭并回调
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.of(context).pop();
        widget.listener.onVerifySuccess(_verifyData!.token);
      }
    });
  }

  /// 验证失败处理
  void _onVerifyFailed() {
    if (!mounted) return;

    setState(() {
      _isVerifying = false;
      _hintText = '验证失败，请重试';
      _hintColor = const Color(0xFFF44336);
    });

    // 重置滑块位置
    _resetSliderPosition();

    // 延迟后刷新验证码
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _hintText = '向右滑动完成验证';
          _hintColor = const Color(0xFF999999);
        });
        _loadVerifyCode();
      }
    });

    widget.listener.onVerifyFailed();
  }

  /// 重置滑块位置
  void _resetSliderPosition() {
    _resetAnimationController?.dispose();
    _resetAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    final animation = Tween<double>(
      begin: _sliderPosition,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _resetAnimationController!,
      curve: Curves.easeOut,
    ));

    animation.addListener(() {
      if (mounted) {
        setState(() {
          _sliderPosition = animation.value;
        });
      }
    });

    _resetAnimationController!.forward();
  }

  /// 计算滑块图片的位置和大小
  ({double top, double width}) _calculateSliderImagePosition(
    BoxConstraints constraints,
  ) {
    final backgroundWidth = constraints.maxWidth;
    final backgroundHeight =
        constraints.maxWidth * (_backgroundImageHeight / _backgroundImageWidth);

    _imageScaleY = backgroundHeight / _backgroundImageHeight;
    _imageScaleX = backgroundWidth / _backgroundImageWidth;

    final top = _verifyData!.y * _imageScaleY;

    // 滑块图片宽度需要根据原始宽度计算
    const sliderOriginalWidth = 50.0;
    final width = sliderOriginalWidth * _imageScaleX;

    return (top: top, width: width);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            const Text(
              '安全验证',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // 验证图片区域
            _buildImageArea(),
            const SizedBox(height: 16),
            // 滑动轨道
            _buildSliderTrack(),
          ],
        ),
      ),
    );
  }

  /// 构建图片验证区域
  Widget _buildImageArea() {
    if (_isLoading) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 8),
            Text(_errorMessage!),
          ],
        ),
      );
    }

    if (_verifyData == null) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final position = _calculateSliderImagePosition(constraints);

        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxWidth *
              (_backgroundImageHeight / _backgroundImageWidth),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 背景图
              Image.memory(
                _verifyData!.backgroundImageBytes,
                width: constraints.maxWidth,
                fit: BoxFit.fitWidth,
              ),
              // 滑块图
              Positioned(
                left: _sliderPosition,
                top: position.top,
                child: Image.memory(
                  _verifyData!.sliderImageBytes,
                  width: position.width,
                  fit: BoxFit.fitWidth,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建滑动轨道
  Widget _buildSliderTrack() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 轨道宽度与背景图片宽度一致
        _maxSliderPosition = constraints.maxWidth - _sliderButtonWidth;

        return Container(
          height: _trackHeight,
          width: constraints.maxWidth,
          decoration: BoxDecoration(
            color: const Color(0xFFE8E8E8),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 提示文字
              Text(
                _hintText,
                style: TextStyle(
                  fontSize: 14,
                  color: _hintColor,
                ),
              ),
              // 滑块按钮
              Positioned(
                left: _sliderPosition,
                child: GestureDetector(
                  onHorizontalDragStart: (details) {
                    if (_isLoading || _isVerifying) return;
                    _dragStartX = details.globalPosition.dx;
                    _sliderStartPosition = _sliderPosition;
                  },
                  onHorizontalDragUpdate: (details) {
                    if (_isLoading || _isVerifying) return;

                    final delta = details.globalPosition.dx - _dragStartX;
                    final newPosition =
                        (_sliderStartPosition + delta).clamp(0.0, _maxSliderPosition);

                    setState(() {
                      _sliderPosition = newPosition;
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (_isLoading || _isVerifying) return;
                    _verifySlidePosition();
                  },
                  onHorizontalDragCancel: () {
                    if (_isLoading || _isVerifying) return;
                    _resetSliderPosition();
                  },
                  child: Container(
                    width: _sliderButtonWidth,
                    height: _trackHeight,
                    decoration: BoxDecoration(
                      color: _sliderButtonColor,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      _sliderButtonColor == const Color(0xFF4CAF50)
                          ? Icons.check
                          : Icons.chevron_right,
                      color: _sliderButtonColor == const Color(0xFF4CAF50)
                          ? Colors.white
                          : Colors.grey,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
