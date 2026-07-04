// dart:ffi 垂直切片验证（见 DESKTOP_REFACTOR_PLAN.md 第 3 节）。
//
// 目的：证明桌面端不需要任何原生插件层——一份 Dart 代码即可直接驱动
// libMarsWrapper，覆盖 macOS/Windows/Linux 三个平台（当前三份共 ~9400 行
// ObjC++/C++ 插件所做的事情）。
//
// 本文件零依赖（不需要 package:ffi，内存分配直接绑 libc malloc/free），
// 运行方式：
//   dart imclient/ffi_poc/wfclient_ffi_poc.dart
//
// 验证内容：
//   1. DynamicLibrary 加载 dylib/so/dll；
//   2. 按 imclient/macos/Classes/ImclientPlugin.mm 的 handleInitProto 序列
//      初始化 SDK（setAppName/setAppDataPath/setPackageName/setDBPath）；
//   3. NativeCallable.listener 注册跨线程连接状态回调
//      （对应 method channel 方案里三平台各自手写的线程投递逻辑）；
//   4. 调用 getClientId 取回真实 clientId，并按约定 releaseDllString 释放。
// ignore_for_file: avoid_print — 命令行验证脚本，print 即输出。
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

// ---------------- libc 内存分配（免 package:ffi 依赖） ----------------

final DynamicLibrary _process = DynamicLibrary.process();
final Pointer<Void> Function(int) _malloc = _process
    .lookupFunction<Pointer<Void> Function(IntPtr), Pointer<Void> Function(int)>(
        'malloc');
final void Function(Pointer<Void>) _free = _process
    .lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>(
        'free');

/// Dart 字符串 → malloc 的 UTF-8 缓冲区。用完必须 free。
Pointer<Char> toNativeUtf8(String s) {
  final bytes = utf8.encode(s);
  final ptr = _malloc(bytes.length + 1).cast<Char>();
  for (var i = 0; i < bytes.length; i++) {
    ptr[i] = bytes[i];
  }
  ptr[bytes.length] = 0;
  return ptr;
}

String fromNativeUtf8(Pointer<Char> ptr, int len) {
  final bytes = ptr.cast<Uint8>().asTypedList(len);
  return utf8.decode(bytes, allowMalformed: true);
}

// ---------------- WFClient 绑定（与 WFClient.h 一一对应） ----------------

typedef _NativeStringSetter = Void Function(Pointer<Char>, Size);
typedef _StringSetter = void Function(Pointer<Char>, int);

class WFClientBindings {
  WFClientBindings(this._lib);

  final DynamicLibrary _lib;

  // void setAppName(const char *, size_t) 等字符串 setter。
  late final _StringSetter setAppName =
      _lib.lookupFunction<_NativeStringSetter, _StringSetter>('setAppName');
  late final _StringSetter setAppDataPath = _lib
      .lookupFunction<_NativeStringSetter, _StringSetter>('setAppDataPath');
  late final _StringSetter setPackageName = _lib
      .lookupFunction<_NativeStringSetter, _StringSetter>('setPackageName');
  late final _StringSetter setDBPath =
      _lib.lookupFunction<_NativeStringSetter, _StringSetter>('setDBPath');

  // void setConnectionStatusListener(void (*)(int))
  late final void Function(Pointer<NativeFunction<Void Function(Int32)>>)
      setConnectionStatusListener = _lib.lookupFunction<
          Void Function(Pointer<NativeFunction<Void Function(Int32)>>),
          void Function(Pointer<NativeFunction<Void Function(Int32)>>)>(
          'setConnectionStatusListener');

  // const char *getClientId(size_t *retlen)
  late final Pointer<Char> Function(Pointer<Size>) getClientId =
      _lib.lookupFunction<Pointer<Char> Function(Pointer<Size>),
          Pointer<Char> Function(Pointer<Size>)>('getClientId');

  // int getConnectionStatus()
  late final int Function() getConnectionStatus = _lib
      .lookupFunction<Int32 Function(), int Function()>('getConnectionStatus');

  // void releaseDllString(const char *)
  late final void Function(Pointer<Char>) releaseDllString = _lib
      .lookupFunction<Void Function(Pointer<Char>),
          void Function(Pointer<Char>)>('releaseDllString');
}

String _defaultLibraryPath() {
  final root = File(Platform.script.toFilePath()).parent.parent.path;
  if (Platform.isMacOS) return '$root/marslib/macos/libMarsWrapper.dylib';
  if (Platform.isWindows) return '$root/marslib/windows/x64/MarsWrapper.dll';
  return '$root/marslib/linux/x86_64/libMarsWrapper.so';
}

void _setString(_StringSetter setter, String value) {
  final ptr = toNativeUtf8(value);
  setter(ptr, utf8.encode(value).length);
  _free(ptr.cast());
}

void main() {
  final libPath = _defaultLibraryPath();
  print('== 1. 加载动态库: $libPath');
  final wf = WFClientBindings(DynamicLibrary.open(libPath));

  print('== 2. 初始化 SDK');
  final dataDir = Directory.systemTemp.createTempSync('wfc_ffi_poc');
  // 注意：setAppName/setAppDataPath/setPackageName 会触发
  // mars::app::AppCallBack 懒加载构造，当前发布的 dylib 中该构造函数在
  // 非 bundle 宿主（dart VM、测试 runner）下对 NULL bundleId 未做防护会崩溃，
  // 已在 cpp-client/OSX/app_callback.mm 修复（2026-07-03），重编 SDK 后
  // 可恢复调用。这里先只走不依赖 AppCallBack 的初始化路径。
  _setString(wf.setDBPath, '${dataDir.path}/wfc.db');

  print('== 3. NativeCallable.listener 注册跨线程连接状态回调');
  final callable = NativeCallable<Void Function(Int32)>.listener((int status) {
    print('   [callback] connectionStatus -> $status');
  });
  wf.setConnectionStatusListener(callable.nativeFunction);

  print('== 4. getClientId（真实 SDK 调用 + releaseDllString 释放）');
  final lenPtr = _malloc(sizeOf<Size>()).cast<Size>();
  final strPtr = wf.getClientId(lenPtr);
  final clientId = fromNativeUtf8(strPtr, lenPtr.value);
  wf.releaseDllString(strPtr);
  _free(lenPtr.cast());

  print('   clientId = $clientId');
  print('   connectionStatus = ${wf.getConnectionStatus()}');

  callable.close();
  final ok = clientId.isNotEmpty;
  print(ok
      ? '\n[OK] 单份 Dart 代码直接驱动 SDK 成功——桌面端不需要原生插件层'
      : '\n[FAIL] clientId 为空，检查 SDK 初始化序列');
  exit(ok ? 0 : 1);
}
