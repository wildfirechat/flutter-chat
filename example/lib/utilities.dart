import 'package:intl/intl.dart';

class Utilities {
  static String formatTime(int timestamp) {
    var now = DateTime.now();
    var date = DateTime.fromMicrosecondsSinceEpoch(timestamp*1000);
    var diff = now.difference(date);
    var time = '';

    if (diff.inSeconds <= 0 || diff.inSeconds > 0 && diff.inMinutes == 0 || diff.inMinutes > 0 && diff.inHours == 0 || diff.inHours > 0 && diff.inDays == 0) {
      var format = DateFormat('HH:mm');
      time = format.format(date);
    } else {
      if (diff.inDays == 1) {
        time = '昨天';
      } else if (diff.inDays < 365) {
        var format = DateFormat('MM月dd日');
        time = format.format(date);
      } else {
        var format = DateFormat('yyyy年MM月dd日');
        time = format.format(date);
      }
    }

    return time;
  }

  static String formatMessageTime(int timestamp) {
    var now = DateTime.now();
    var date = DateTime.fromMicrosecondsSinceEpoch(timestamp*1000);
    var diff = now.difference(date);
    var time = '';

    var format = DateFormat('HH:mm');
    time = format.format(date);
    if (diff.inSeconds <= 0 || diff.inSeconds > 0 && diff.inMinutes == 0 || diff.inMinutes > 0 && diff.inHours == 0 || diff.inHours > 0 && diff.inDays == 0) {

    } else {
      if (diff.inDays == 1) {
        var day = '昨天';
        time = '$day $time';
      } else if(diff.inDays < 365) {
        var dayformat = DateFormat('MM月dd日');
        var day = dayformat.format(date);
        time = '$day $time';
      } else {
        var dayformat = DateFormat('yyyy年MM月dd日');
        var day = dayformat.format(date);
        time = '$day $time';
      }
    }

    return time;
  }
}