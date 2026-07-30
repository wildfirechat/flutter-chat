import 'dart:async';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:imclient/model/conversation.dart';
import 'package:logger/logger.dart' show Level, Logger;
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../conversation_controller.dart';
import 'package:chat/theme/app_colors.dart';
import 'package:chat/theme/app_typography.dart';

class RecordWidget extends StatefulWidget {
  RecordWidget(this.conversation, {super.key});
  Conversation conversation;

  @override
  State<StatefulWidget> createState() => RecordState();
}

class RecordState extends State<RecordWidget> {
  FlutterSoundRecorder? _recorder;
  StreamSubscription? _recorderSubscription;
  bool _isRecording = false;
  bool _isReleaseCancel = false;
  int _recordStartTime = 0;
  int _audioLevel = 1;

  OverlayEntry? overlayEntry;
  String soundTipsText = "手指上滑，取消发送";

  late ConversationController conversationController;

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    soundTipsText = AppLocalizations.of(context)!.slideUpToCancel;
  }

  Future<void> _initRecorder() async {
    _recorder = FlutterSoundRecorder(logLevel: Level.warning);
    await _recorder!.openRecorder();
  }

  @override
  void dispose() {
    _recorder!.closeRecorder();
    _recorder = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    conversationController =
        Provider.of<ConversationController>(context, listen: false);
    final colors = context.colors;
    final l10n = AppLocalizations.of(context)!;

    // 三态:静止时对齐它替换掉的文字输入框的观感(surface 底 + 发丝描边),
    // 录音中转品牌蓝,上滑待取消转危险红,文字始终居中。
    final String label;
    final Color background;
    final Color foreground;
    Border? border;
    if (!_isRecording) {
      label = l10n.holdToTalk;
      background = colors.surface;
      foreground = colors.textPrimary;
      border = Border.all(color: colors.hairline);
    } else if (_isReleaseCancel) {
      label = l10n.releaseToCancel;
      background = colors.danger;
      foreground = colors.onAccent;
    } else {
      label = l10n.releaseToSend;
      background = colors.accent;
      foreground = colors.onAccent;
    }

    // 这不是可点击的按钮,而是长按录音面,交互全在 GestureDetector 上,
    // 所以用 Container 画形态,不再拿 OutlinedButton 当外壳。
    return GestureDetector(
      onLongPressDown: (details) => _onVoiceLongPressDown(),
      onLongPressStart: (details) => _onVoiceLongPressStart(context),
      onLongPressUp: () => _onVoiceLongPressUp(),
      onLongPressCancel: () => _onVoiceLongPressCancel(),
      onLongPressMoveUpdate: (LongPressMoveUpdateDetails details) =>
          _onVoicePressMove(details),
      child: Container(
        height: 40,
        margin: const EdgeInsets.fromLTRB(0, 5, 5, 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          border: border,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: AppText.lg
                .copyWith(fontWeight: FontWeight.w500, color: foreground)),
      ),
    );
  }

  String? _recordPath;

  void _startRecord(BuildContext context) async {
    var status = await Permission.microphone.request();
    if (!status.isGranted) {
      Fluttertoast.showToast(
          msg: AppLocalizations.of(context)!.noMicrophonePermission);
      return;
    }

    if (_recorder == null) {
      await _initRecorder();
    }

    if (_recorder == null) {
      return;
    }

    var direction = await getTemporaryDirectory();
    _recordPath =
        '${direction.path}/record-${DateTime.now().millisecondsSinceEpoch}.aac';
    setState(() {
      _isRecording = true;
    });

    try {
      await _recorder!.startRecorder(
        codec: Codec.aacADTS,
        sampleRate: 16000,
        numChannels: 1,
        toFile: _recordPath,
      );
      _recordStartTime = DateTime.now().millisecondsSinceEpoch;
      _recorder?.setSubscriptionDuration(const Duration(milliseconds: 100));
      _recorderSubscription =
          _recorder!.onProgress?.listen((RecordingDisposition event) {
        if (event.decibels != null) {
          _audioLevel = event.decibels! ~/ 16;
          if (_audioLevel > 6) {
            _audioLevel = 6;
          }
          if (overlayEntry != null) {
            overlayEntry!.markNeedsBuild();
          }
        }
      });
      buildOverLayView(context);
    } catch (e) {
      _isRecording = false;
      if (mounted) setState(() {});
      Fluttertoast.showToast(
          msg: AppLocalizations.of(context)!.recordFailed(e.toString()));
    }
  }

  void _stopRecord(bool send) async {
    if (_recorder == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _isRecording = false;
      });
    } else {
      _isRecording = false;
    }

    try {
      if (_recorder!.isRecording) {
        await _recorder!.stopRecorder();
      }
      _recorderSubscription?.cancel();
      _recorderSubscription = null;

      if (send && !_isReleaseCancel) {
        int duration =
            (DateTime.now().millisecondsSinceEpoch - _recordStartTime + 500) ~/
                1000;
        if (duration < 1) {
          Fluttertoast.showToast(
              msg: AppLocalizations.of(context)!.recordTooShort);
        } else {
          conversationController.onSoundRecorded(
              widget.conversation, _recordPath!, duration);
        }
      }
    } catch (e) {
      debugPrint("stop record error: $e");
    }

    if (overlayEntry != null) {
      overlayEntry!.remove();
      overlayEntry = null;
    }
  }

  buildOverLayView(BuildContext context) {
    if (overlayEntry == null) {
      overlayEntry = OverlayEntry(builder: (content) {
        return Positioned(
          top: 0,
          left: 0,
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: Material(
            color: Colors.transparent,
            type: MaterialType.canvas,
            child: Center(
              child: Opacity(
                opacity: 0.8,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: const BoxDecoration(
                    color: Color(0xff77797A),
                    borderRadius: BorderRadius.all(Radius.circular(20.0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      const SizedBox(
                        height: 20,
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 10),
                            child: SizedBox(
                              width: 50,
                              height: 60,
                              child: Image.asset(
                                "assets/images/input/voice/voice_${_audioLevel + 1}.png",
                                width: 50,
                                height: 60,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      Text(
                        soundTipsText,
                        style: AppText.base.copyWith(
                            fontStyle: FontStyle.normal, color: Colors.white),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      });
      Overlay.of(context).insert(overlayEntry!);
    }
  }

  void _onVoiceLongPressDown() {}

  void _onVoiceLongPressStart(BuildContext context) {
    _startRecord(context);
  }

  void _onVoiceLongPressUp() {
    _stopRecord(true);
  }

  void _onVoiceLongPressCancel() {
    _stopRecord(false);
  }

  void _onVoicePressMove(LongPressMoveUpdateDetails details) {
    double height = 25;
    double dy = details.localPosition.dy - 25;
    if (dy.abs() > height) {
      if (mounted && !_isReleaseCancel) {
        setState(() {
          soundTipsText = AppLocalizations.of(context)!.releaseToCancel;
          _isReleaseCancel = true;
        });
        overlayEntry?.markNeedsBuild();
      }
    } else {
      if (mounted && _isReleaseCancel) {
        setState(() {
          soundTipsText = AppLocalizations.of(context)!.slideUpToCancel;
          _isReleaseCancel = false;
        });
        overlayEntry?.markNeedsBuild();
      }
    }
  }
}
