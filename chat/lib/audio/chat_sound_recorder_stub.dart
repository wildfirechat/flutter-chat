import 'dart:async';
import 'dart:typed_data';

class RecorderConfig {
  final dynamic codec;
  final int sampleRate;
  final int numChannels;
  final String? toFile;
  final Duration? subscriptionDuration;

  RecorderConfig({
    this.codec,
    this.sampleRate = 16000,
    this.numChannels = 1,
    this.toFile,
    this.subscriptionDuration,
  });
}

abstract class ChatSoundRecorder {
  Future<void> openRecorder();
  Future<void> closeRecorder();
  Future<void> startRecorder({String? toFile});
  Future<void> startRecorderWithConfig(RecorderConfig config);
  Future<void> setSubscriptionDuration(Duration duration);
  Future<void> stopRecorder();
  Stream? get onProgress;
  bool get isRecording;
}

class ChatSoundRecorderFactory {
  static ChatSoundRecorder create() {
    return _ChatSoundRecorderStub();
  }
}

class _ChatSoundRecorderStub implements ChatSoundRecorder {
  @override
  Future<void> openRecorder() async {}

  @override
  Future<void> closeRecorder() async {}

  @override
  Future<void> startRecorder({String? toFile}) async {}

  @override
  Future<void> startRecorderWithConfig(RecorderConfig config) async {}

  @override
  Future<void> setSubscriptionDuration(Duration duration) async {}

  @override
  Future<void> stopRecorder() async {}

  @override
  Stream? get onProgress => null;

  @override
  bool get isRecording => false;
}
