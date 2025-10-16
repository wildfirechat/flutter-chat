import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/user_info.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

class Utilities {
  static String formatTime(int timestamp) {
    var now = DateTime.now();
    var date = DateTime.fromMicrosecondsSinceEpoch(timestamp * 1000);
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
    var date = DateTime.fromMicrosecondsSinceEpoch(timestamp * 1000);
    var diff = now.difference(date);
    var time = '';

    var format = DateFormat('HH:mm');
    time = format.format(date);
    if (diff.inSeconds <= 0 || diff.inSeconds > 0 && diff.inMinutes == 0 || diff.inMinutes > 0 && diff.inHours == 0 || diff.inHours > 0 && diff.inDays == 0) {
    } else {
      if (diff.inDays == 1) {
        var day = '昨天';
        time = '$day $time';
      } else if (diff.inDays < 365) {
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

  static String formatSize(int size) {
    if (size < 1024) {
      return '${size}B';
    } else if (size < 1024 * 1024) {
      int k = size ~/ 1024;
      return '${k}KB';
    } else if (size < 1024 * 1024 * 1024) {
      int m = (size / 1024 / 1024).toInt();
      return '${m}MB';
    } else {
      double g = size / 1024 / 1024;
      String s = g.toStringAsFixed(2);
      return '${s}GB';
    }
  }

  static String fileType(String fileName) {
    var ext = p.extension(fileName);

    if (ext == ".doc" || ext == ".docx" || ext == ".pages") {
      return "word";
    } else if (ext == ".xls" || ext == ".xlsx" || ext == ".numbers") {
      return "xls";
    } else if (ext == ".ppt" || ext == ".pptx" || ext == ".keynote") {
      return "ppt";
    } else if (ext == ".pdf") {
      return "pdf";
    } else if (ext == ".html" || ext == ".htm") {
      return "html";
    } else if (ext == ".txt") {
      return "text";
    } else if (ext == ".jpg" || ext == ".png" || ext == ".jpeg") {
      return "image";
    } else if (ext == ".mp3" || ext == ".amr" || ext == ".acm" || ext == ".aif") {
      return "audio";
    } else if (ext == ".mp4" ||
        ext == ".avi" ||
        ext == ".mov" ||
        ext == ".asf" ||
        ext == ".wmv" ||
        ext == ".mpeg" ||
        ext == ".ogg" ||
        ext == ".mkv" ||
        ext == ".rmvb" ||
        ext == ".f4v") {
      return "video";
    } else if (ext == ".exe") {
      return "exe";
    } else if (ext == ".xml") {
      return "xml";
    } else if (ext == ".zip" || ext == ".rar" || ext == ".gzip" || ext == ".gz" || ext == ".xz") {
      return "zip";
    }

    return "unknown";
  }

  static String formatCallTime(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int remainingSeconds = seconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    }
  }

  static String conversationTitle(Conversation conversation, UserInfo? userInfo, GroupInfo? groupInfo, ChannelInfo? channelInfo) {
    String title = '';
    switch (conversation.conversationType) {
      case ConversationType.Single:
        title = userInfo?.getReadableName() ?? '单聊<${userInfo?.userId}>';
        break;
      case ConversationType.Group:
        title = groupInfo?.remark ?? groupInfo?.name ?? '群聊<${groupInfo?.target}>';
        break;
      case ConversationType.Channel:
        title = channelInfo?.name ?? '频道<${channelInfo?.name}>';
        break;
      case ConversationType.Chatroom:
        title = '聊天室-<${conversation.target}>';
        break;
      case _:
        break;
    }
    return title;
  }
}
