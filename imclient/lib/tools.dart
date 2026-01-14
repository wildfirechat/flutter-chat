import 'dart:ui';
import 'dart:math' as math;

class Tools {

  static List<String> convertDynamicList(List<dynamic>? datas) {
    if (datas == null || datas.isEmpty) {
      return [];
    }
    List<String> list = [];
    for (var element in datas) {
      list.add(element);
    }
    return list;
  }

  /// 模仿微信图片缩放逻辑，计算适当的显示宽高
  static Size getImageSizeByOrgSizeToWeChat(int orgWidth, int orgHeight) {
    int imageWidth = 300;
    int imageHeight = 300;
    int maxWidth = 400;
    int maxHeight = 400;
    int minWidth = 300;
    int minHeight = 250;

    // 处理 0 的情况，防止除零异常
    if (orgWidth == 0 || orgHeight == 0) {
      return Size(imageWidth.toDouble(), imageHeight.toDouble());
    }

    // Java 中 int/int 是整除，Dart 中需使用 ~/ 模拟该行为
    if (orgWidth ~/ maxWidth > orgHeight ~/ maxHeight) {
      if (orgWidth >= maxWidth) {
        imageWidth = maxWidth;
        imageHeight = (orgHeight * maxWidth) ~/ orgWidth;
      } else {
        imageWidth = orgWidth;
        imageHeight = orgHeight;
      }

      if (imageHeight < minHeight) {
        imageHeight = minHeight;
        int width = (orgWidth * minHeight) ~/ orgHeight;
        if (width > maxWidth) {
          imageWidth = maxWidth;
        } else {
          imageWidth = width;
        }
      }
    } else {
      if (orgHeight >= maxHeight) {
        imageHeight = maxHeight;
        // 模拟 Java 的整除逻辑 outHeight / maxHeight
        if (orgHeight ~/ maxHeight > 10) {
          imageWidth = (orgWidth * 5 * maxHeight) ~/ orgHeight;
        } else {
          imageWidth = (orgWidth * maxHeight) ~/ orgHeight;
        }
      } else {
        imageHeight = orgHeight;
        imageWidth = orgWidth;
      }

      if (orgWidth < minWidth) {
        imageWidth = minWidth;
        int height = (orgHeight * minWidth) ~/ orgWidth;
        if (height > maxHeight) {
          imageHeight = maxHeight;
        } else {
          imageHeight = height;
        }
      }
    }

    // 返回最终计算结果
    // return Size(imageWidth.toDouble(), imageHeight.toDouble());
    return Size( math.min(imageWidth, maxWidth).toDouble(), math.min(imageHeight, maxHeight).toDouble()
    );
  }

}