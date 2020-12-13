import 'package:flutter_imclient/message/message.dart';

class MessageModel {

  Message message;
  bool showTimeLabel;
  bool showNameLabel;
  bool mediaDownloading;
  int mediaDownloadProgress;
  bool voicePlaying;
  bool highlighted;
  bool lastReadMessage;
  Map<String, int> deliveryDict;
  Map<String, int> readDict;
  double deliveryRate;
  double readRate;
  bool selecting;
  bool selected;

  MessageModel(
  this.message,
      {
        this.showTimeLabel = false,
    this.showNameLabel = false,
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
        other is MessageModel &&
            runtimeType == other.runtimeType &&
            message == other.message &&
            showTimeLabel == other.showTimeLabel &&
            showNameLabel == other.showNameLabel &&
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
      showNameLabel.hashCode ^
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