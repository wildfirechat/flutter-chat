import 'dart:async';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:logger/logger.dart' show Level;

import 'chat_sound_recorder.dart';

class ChatSoundRecorderImpl implements ChatSoundRecorder {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder(logLevel: Level.warning);

  @override
  Future<void> openRecorder() => _recorder.openRecorder();

  @override
  Future<void> closeRecorder() => _recorder.closeRecorder();

  @override
  Future<void> startRecorder({String? toFile}) {
    return _recorder.startRecorder(toFile: toFile);
  }

  @override
  Future<void> startRecorderWithConfig(RecorderConfig config) {
    return _recorder.startRecorder(
      codec: config.codec ?? Codec.aacADTS,
      sampleRate: config.sampleRate,
      numChannels: config.numChannels,
      toFile: config.toFile,
    );
  }

  @override
  Future<void> setSubscriptionDuration(Duration duration) {
    return _recorder.setSubscriptionDuration(duration);
  }

  @override
  Future<void> stopRecorder() => _recorder.stopRecorder();

  @override
  Stream? get onProgress => _recorder.onProgress;

  @override
  bool get isRecording => _recorder.isRecording;
}

class ChatSoundRecorderFactory {
  static ChatSoundRecorder create() {
    return ChatSoundRecorderImpl();
  }
}
