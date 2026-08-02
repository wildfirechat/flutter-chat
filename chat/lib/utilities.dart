import 'package:flutter/material.dart';
import 'package:imclient/model/channel_info.dart';
import 'package:imclient/model/conversation.dart';
import 'package:imclient/model/group_info.dart';
import 'package:imclient/model/user_info.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:chat/workspace/wf_webview_screen.dart';
import 'package:chat/workspace/webview_support.dart';
import 'package:chat/utils/media_url_redirector.dart';
import 'package:chat/utils/mesh_user_display.dart';
import 'package:chat/utils/show_toast.dart';
import 'package:chat/l10n/app_localizations.dart';
import 'package:chat/pc/pc_platform.dart';

extension EmptyStringToNull on String? {
  String? get emptyToNull {
    if (this == null || this!.isEmpty) {
      return null;
    }
    return this;
  }
}

class Utilities {
  /// 固定格式 DateFormat 缓存:消息列表每 cell 都会调 formatMessageTime,避免重复构造
  static final DateFormat _hourMinuteFormat = DateFormat('HH:mm');

  /// 含 locale 或动态 pattern 的 DateFormat,按 "pattern@locale" 缓存
  static final Map<String, DateFormat> _dateFormatCache = {};

  static DateFormat _cachedDateFormat(String pattern, [String? locale]) {
    final key = locale == null ? pattern : '$pattern@$locale';
    return _dateFormatCache.putIfAbsent(key, () => DateFormat(pattern, locale));
  }

  static String formatTime(BuildContext context, int timestamp) {
    var now = DateTime.now();
    var date = DateTime.fromMicrosecondsSinceEpoch(timestamp * 1000);
    var diff = now.difference(date);
    var time = '';

    // 会话列表每行每次重建都会调到,DateFormat 一律走缓存,不再逐次构造。
    if (diff.inSeconds <= 0 ||
        diff.inSeconds > 0 && diff.inMinutes == 0 ||
        diff.inMinutes > 0 && diff.inHours == 0 ||
        diff.inHours > 0 && diff.inDays == 0) {
      time = _hourMinuteFormat.format(date);
    } else {
      if (diff.inDays == 1) {
        time = AppLocalizations.of(context)!.yesterday;
      } else if (diff.inDays < 365) {
        time = _cachedDateFormat(AppLocalizations.of(context)!.monthDayFormat)
            .format(date);
      } else {
        time =
            _cachedDateFormat(AppLocalizations.of(context)!.yearMonthDayFormat)
                .format(date);
      }
    }

    return time;
  }

  static String formatMessageTime(BuildContext context, int timestamp) {
    var now = DateTime.now();
    var date = DateTime.fromMicrosecondsSinceEpoch(timestamp * 1000);
    var diff = now.difference(date);
    var time = '';

    var format = _hourMinuteFormat;
    time = format.format(date);
    if (diff.inSeconds <= 0 ||
        diff.inSeconds > 0 && diff.inMinutes == 0 ||
        diff.inMinutes > 0 && diff.inHours == 0 ||
        diff.inHours > 0 && diff.inDays == 0) {
    } else {
      if (diff.inDays == 1) {
        var day = AppLocalizations.of(context)!.yesterday;
        time = '$day $time';
      } else if (diff.inDays < 7) {
        // 前天及之前一周内：星期几 小时:分钟（对齐微信）
        var weekday = _cachedDateFormat(
                'EEEE', Localizations.localeOf(context).toString())
            .format(date);
        time = '$weekday $time';
      } else if (diff.inDays < 365) {
        var dayformat =
            _cachedDateFormat(AppLocalizations.of(context)!.monthDayFormat);
        var day = dayformat.format(date);
        time = '$day $time';
      } else {
        var dayformat =
            _cachedDateFormat(AppLocalizations.of(context)!.yearMonthDayFormat);
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
    } else if (ext == ".mp3" ||
        ext == ".amr" ||
        ext == ".acm" ||
        ext == ".aif") {
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
    } else if (ext == ".zip" ||
        ext == ".rar" ||
        ext == ".gzip" ||
        ext == ".gz" ||
        ext == ".xz") {
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

  static String conversationTitle(
      BuildContext context,
      Conversation conversation,
      UserInfo? userInfo,
      GroupInfo? groupInfo,
      ChannelInfo? channelInfo) {
    String title = '';
    switch (conversation.conversationType) {
      case ConversationType.Single:
        if (userInfo != null) {
          title = MeshUserDisplay.getReadableName(userInfo);
        }
        title = title.emptyToNull ??
            AppLocalizations.of(context)!.singleChat(conversation.target);
        break;
      case ConversationType.Group:
        title = groupInfo?.remark.emptyToNull ??
            groupInfo?.name.emptyToNull ??
            AppLocalizations.of(context)!.groupChat;
        break;
      case ConversationType.Channel:
        title = channelInfo?.name.emptyToNull ??
            AppLocalizations.of(context)!
                .channelWithTarget(conversation.target);
        break;
      case ConversationType.Chatroom:
        title = AppLocalizations.of(context)!
            .chatroomWithTarget(conversation.target);
        break;
      case _:
        break;
    }
    return title;
  }

  static Future<void> openLink(BuildContext context, String url) async {
    var resolvedUrl = url;
    if (!resolvedUrl.contains('://') && resolvedUrl.startsWith('www.')) {
      resolvedUrl = 'https://$resolvedUrl';
    }
    final uri = Uri.parse(MediaUrlRedirector.redirect(resolvedUrl));
    // PC 端统一交给系统默认浏览器打开,不使用内置浏览页;移动端保持原有内嵌 WebView 行为。
    if (!isDesktopShell &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        isInlineWebViewSupported) {
      if (!context.mounted) {
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => WFWebViewScreen(resolvedUrl)),
      );
      return;
    }

    final failMessage = AppLocalizations.of(context)!.cannotOpenLink;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      showToast(msg: failMessage);
    }
  }
}
