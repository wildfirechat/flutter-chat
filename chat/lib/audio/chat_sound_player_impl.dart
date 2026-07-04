import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:logger/logger.dart' show Level;

import 'chat_sound_player.dart';

class ChatSoundPlayerImpl implements ChatSoundPlayer {
  final FlutterSoundPlayer _player = FlutterSoundPlayer(logLevel: Level.error);

  @override
  Future<void> openPlayer() => _player.openPlayer();

  @override
  Future<void> closePlayer() => _player.closePlayer();

  @override
  Future<void> startPlayer({required String fromURI, required VoidCallback? whenFinished}) {
    return _player.startPlayer(fromURI: fromURI, whenFinished: whenFinished);
  }

  @override
  Future<void> stopPlayer() => _player.stopPlayer();

  @override
  bool get isPlaying => _player.isPlaying;
}

class ChatSoundPlayerFactory {
  static ChatSoundPlayer create() {
    return ChatSoundPlayerImpl();
  }
}
