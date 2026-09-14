import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

/// 把按住说话录到的 PCM 编码成语音消息的 WAV 文件
///
/// 录音是 16kHz、16-bit、单声道 PCM。和 android-chat 的 PcmAmrEncoder 一样，先低通滤波再降采样到 8kHz
/// （语音消息是电话音质，文件小一半），需要时放大音量；不同的是封装成 WAV 而不是 AMR：
/// Dart 没有 AMR 编码器，iOS 和桌面端也播放不了 AMR。
class PcmWavEncoder {
  PcmWavEncoder._();

  static const int _outputSampleRate = 8000;
  static const int _headerBytes = 44;

  // 16kHz 降采样到 8kHz 前的低通滤波器，滤掉 4kHz 以上的声音，避免混叠
  static final Float64List _lowPassFilter = _createHalfBandFilter(31);

  /// 在后台 isolate 中编码并写入 [path]
  ///
  /// [pcm] 是 16kHz、16-bit、小端、单声道 PCM；[gain] 是音量放大倍数，1 表示不放大
  static Future<void> encodeToFile(Uint8List pcm, String path,
      {int gain = 1}) {
    return Isolate.run(() async {
      await File(path).writeAsBytes(encode(pcm, gain: gain), flush: true);
    });
  }

  /// 编码成 8kHz、16-bit、单声道 WAV 文件的内容
  static Uint8List encode(Uint8List pcm, {int gain = 1}) {
    final int inSamples = pcm.length ~/ 2;
    final int outSamples = (inSamples + 1) ~/ 2;
    final ByteData input = ByteData.sublistView(pcm);
    final ByteData output = ByteData(_headerBytes + outSamples * 2);
    _writeHeader(output, outSamples * 2);

    final Float64List filter = _lowPassFilter;
    final int halfTaps = filter.length ~/ 2;
    int offset = _headerBytes;
    // 滤波后每两个采样取一个，降到 8kHz
    for (int i = 0; i < inSamples; i += 2) {
      double sum = 0;
      for (int k = 0; k < filter.length; k++) {
        final int index =
            math.min(math.max(i + k - halfTaps, 0), inSamples - 1);
        sum += filter[k] * input.getInt16(index * 2, Endian.little);
      }
      output.setInt16(offset, _clamp(sum * gain), Endian.little);
      offset += 2;
    }
    return output.buffer.asUint8List();
  }

  static void _writeHeader(ByteData data, int dataBytes) {
    void writeTag(int offset, String tag) {
      for (int i = 0; i < tag.length; i++) {
        data.setUint8(offset + i, tag.codeUnitAt(i));
      }
    }

    writeTag(0, 'RIFF');
    data.setUint32(4, 36 + dataBytes, Endian.little);
    writeTag(8, 'WAVE');
    writeTag(12, 'fmt ');
    // fmt 块长度
    data.setUint32(16, 16, Endian.little);
    // PCM 格式
    data.setUint16(20, 1, Endian.little);
    // 单声道
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, _outputSampleRate, Endian.little);
    // 每秒字节数
    data.setUint32(28, _outputSampleRate * 2, Endian.little);
    // 每个采样的字节数
    data.setUint16(32, 2, Endian.little);
    // 位深
    data.setUint16(34, 16, Endian.little);
    writeTag(36, 'data');
    data.setUint32(40, dataBytes, Endian.little);
  }

  static int _clamp(double value) =>
      math.max(-32768, math.min(32767, value.round()));

  /// 截止频率为采样率 1/4 的加窗（Hamming）半带低通滤波器，系数和 android-chat 一致
  static Float64List _createHalfBandFilter(int taps) {
    final Float64List filter = Float64List(taps);
    final int center = taps ~/ 2;
    double sum = 0;
    for (int i = 0; i < taps; i++) {
      final int n = i - center;
      final double sinc =
          n == 0 ? 0.5 : math.sin(math.pi * n / 2) / (math.pi * n);
      final double window =
          0.54 - 0.46 * math.cos(2 * math.pi * i / (taps - 1));
      filter[i] = sinc * window;
      sum += filter[i];
    }
    for (int i = 0; i < taps; i++) {
      filter[i] /= sum;
    }
    return filter;
  }
}
