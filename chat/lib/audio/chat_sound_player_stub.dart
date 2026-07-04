import 'package:flutter/foundation.dart';

abstract class ChatSoundPlayer {
  Future<void> openPlayer();
  Future<void> closePlayer();
  Future<void> startPlayer({required String fromURI, required VoidCallback? whenFinished});
  Future<void> stopPlayer();
  bool get isPlaying;
}

class ChatSoundPlayerFactory {
  static ChatSoundPlayer create() {
    return _ChatSoundPlayerStub();
  }
}

class _ChatSoundPlayerStub implements ChatSoundPlayer {
  @override
  Future<void> openPlayer() async {}

  @override
  Future<void> closePlayer() async {}

  @override
  Future<void> startPlayer({required String fromURI, required VoidCallback? whenFinished}) async {}

  @override
  Future<void> stopPlayer() async {}

  @override
  bool get isPlaying => false;
}
