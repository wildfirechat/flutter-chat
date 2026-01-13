
import 'package:flutter/widgets.dart';
import 'package:imclient/message/message.dart';

class UIMessage {
  Message message;
  bool showTimeLabel;
  bool mediaDownloading;
  int mediaDownloadProgress;
  bool voicePlaying;
  bool highlighted;
  bool lastReadMessage;
  Map<String, int>? deliveryDict;
  Map<String, int>? readDict;
  double deliveryRate;
  double readRate;
  bool selecting;
  bool selected;

  Image? thumbnailImage;

  UIMessage(this.message,
      {this.showTimeLabel = false,
      this.mediaDownloading = false,
      this.mediaDownloadProgress = 0,
      this.voicePlaying = false,
      this.highlighted = false,
      this.lastReadMessage = false,
      this.deliveryDict,
      this.readDict,
      this.deliveryRate = 0,
      this.readRate = 0,
      this.selecting = false,
      this.selected = false});

  @override
  bool operator ==(Object other) {
    bool equal = identical(this, other) ||
        other is UIMessage &&
            runtimeType == other.runtimeType &&
            message == other.message &&
            showTimeLabel == other.showTimeLabel &&
            mediaDownloading == other.mediaDownloading &&
            mediaDownloadProgress == other.mediaDownloadProgress &&
            voicePlaying == other.voicePlaying &&
            highlighted == other.highlighted &&
            lastReadMessage == other.lastReadMessage &&
            deliveryDict == other.deliveryDict &&
            readDict == other.readDict &&
            deliveryRate == other.deliveryRate &&
            readRate == other.readRate &&
            selecting == other.selecting &&
            selected == other.selected;
    return equal;
  }

  @override
  int get hashCode =>
      message.hashCode ^
      showTimeLabel.hashCode ^
      mediaDownloading.hashCode ^
      mediaDownloadProgress.hashCode ^
      voicePlaying.hashCode ^
      highlighted.hashCode ^
      lastReadMessage.hashCode ^
      deliveryDict.hashCode ^
      readDict.hashCode ^
      deliveryRate.hashCode ^
      readRate.hashCode ^
      selecting.hashCode ^
      selected.hashCode;
}
