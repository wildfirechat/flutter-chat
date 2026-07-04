// 复用三平台共享的 C 垫片源码（Flutter FFI 插件模板的标准做法：
// 通过相对 include 把 src/ 下的共享实现纳入本平台的编译单元）。
#include "../../src/dart_include/dart_api_dl.c"
#include "../../src/wfc_dart_bridge.c"
