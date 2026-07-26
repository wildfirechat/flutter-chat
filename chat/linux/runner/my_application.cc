#include "my_application.h"

#include <errno.h>
#include <fcntl.h>
#include <flutter_linux/flutter_linux.h>
#if defined(GDK_WINDOWING_X11) && defined(HAVE_X11)
#include <X11/Xlib.h>
#include <gdk/gdkx.h>
#define CHAT_X11_ERROR_HANDLER 1
#elif defined(GDK_WINDOWING_X11)
#include <gdk/gdkx.h>
#endif
#include <sys/file.h>  // flock() 与 LOCK_EX/LOCK_NB;不引入则 flock 会被解析成 <fcntl.h> 里的 struct flock
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#include "flutter/generated_plugin_registrant.h"

#include <desktop_multi_window/desktop_multi_window_plugin.h>
#include <flutter_webrtc/flutter_web_r_t_c_plugin.h>
#include <window_manager/window_manager_plugin.h>
#include <screen_retriever_linux/screen_retriever_linux_plugin.h>
#include <url_launcher_linux/url_launcher_plugin.h>

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// 单实例文件锁路径
static const char* kSingleInstanceLockPath = "/tmp/wildfirechat_flutter_desktop.lock";

static int _tryAcquireSingleInstanceLock() {
  int fd = open(kSingleInstanceLockPath, O_RDWR | O_CREAT, 0666);
  if (fd < 0) return -1;
  int rc = flock(fd, LOCK_EX | LOCK_NB);
  if (rc < 0) {
    close(fd);
    return -1;
  }
  return fd;
}

static int _singleInstanceLockFd = -1;

#ifdef CHAT_X11_ERROR_HANDLER
// GLX 协议里 glXMakeCurrent / glXMakeContextCurrent 的 minor opcode。
static const int kGlxMakeCurrentOpcode = 5;
static const int kGlxMakeContextCurrentOpcode = 26;

static int (*_defaultXErrorHandler)(Display*, XErrorEvent*) = nullptr;
static int _glxMajorOpcode = -1;

// GDK 自带的 X 错误处理器(gdk_x_error)对任何未被 trap 的 X error 都会打印
// "received an X Window System error" 然后 exit(1) —— 整个应用直接没了。
//
// 本项目用 desktop_multi_window 开子窗口,每个子窗口是一个独立的 Flutter 引擎,
// 各自有一份 GL context。Flutter 的 Linux embedder 在正常出帧时会把 GL context
// 在光栅线程和平台线程之间来回交接(fl_compositor_opengl.cc:present_layers_task_cb
// 会先阻塞光栅线程再在平台线程 make_current);但窗口销毁走的 unrealize 路径
// (fl_view.cc: unrealize_cb → fl_opengl_manager_make_current)没有这层同步,
// 引擎还活着、光栅线程可能正持有同一个 context。GLX 规定:context 已在别的线程
// current 时再 make current,服务端回 BadAccess:
//
//   error_code 10 request_code 150 (GLX) minor_code 26
//
// 子窗口关闭越频繁越容易撞上;LIBGL_ALWAYS_SOFTWARE=1 也一样,因为这是 GLX 协议
// 层面的错误,不是驱动实现问题。
//
// 这一帧本来就是要丢弃的(窗口正在销毁),没有理由让整个进程退出。这里只吞掉
// GLX make-current 这一类错误并打日志,其余 X 错误仍交回 GDK 原处理器,保持默认
// 行为(也不影响 GDK 自己的 error trap,因为 trap 判定在原处理器里)。
static int _onXError(Display* xdisplay, XErrorEvent* error) {
  if (_glxMajorOpcode > 0 && error->request_code == _glxMajorOpcode &&
      (error->minor_code == kGlxMakeContextCurrentOpcode ||
       error->minor_code == kGlxMakeCurrentOpcode)) {
    // 错误处理器可能在任意线程被调到;万一变成每帧都报,也不能让日志把应用拖死。
    static volatile gint ignored_count = 0;
    gint count = g_atomic_int_add(&ignored_count, 1) + 1;
    if (count <= 5 || count % 100 == 0) {
      g_warning(
          "忽略 GLX make-current 错误(第 %d 次,error_code=%d minor_code=%d "
          "serial=%lu):窗口销毁与光栅线程抢同一个 GL context,该帧作废,"
          "进程继续运行。",
          count, error->error_code, error->minor_code, error->serial);
    }
    return 0;
  }
  return _defaultXErrorHandler != nullptr
             ? _defaultXErrorHandler(xdisplay, error)
             : 0;
}

static void _installXErrorHandler() {
  static gboolean installed = FALSE;
  if (installed) {
    return;
  }
  GdkDisplay* display = gdk_display_get_default();
  if (display == nullptr || !GDK_IS_X11_DISPLAY(display)) {
    return;  // Wayland 下没有这条路径
  }
  Display* xdisplay = GDK_DISPLAY_XDISPLAY(display);
  int first_event = 0;
  int first_error = 0;
  if (!XQueryExtension(xdisplay, "GLX", &_glxMajorOpcode, &first_event,
                       &first_error)) {
    _glxMajorOpcode = -1;
  }
  _defaultXErrorHandler = XSetErrorHandler(_onXError);
  installed = TRUE;
}
#endif  // CHAT_X11_ERROR_HANDLER

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
#ifdef CHAT_X11_ERROR_HANDLER
  // 必须在 GDK 打开 display(gtk_init)之后装,才能盖住 GDK 自己的处理器。
  _installXErrorHandler();
#endif
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "野火IM");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "野火IM");
  }

  gtk_window_set_default_size(window, 1280, 720);
  gtk_widget_show(GTK_WIDGET(window));

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  desktop_multi_window_plugin_set_window_created_callback([](FlPluginRegistry* registry){
    g_autoptr(FlPluginRegistrar) flutter_webrtc_registrar =
        fl_plugin_registry_get_registrar_for_plugin(registry, "FlutterWebRTCPlugin");
    flutter_web_r_t_c_plugin_register_with_registrar(flutter_webrtc_registrar);
    g_autoptr(FlPluginRegistrar) window_manager_registrar =
        fl_plugin_registry_get_registrar_for_plugin(registry, "WindowManagerPlugin");
    window_manager_plugin_register_with_registrar(window_manager_registrar);
    // 子窗口无托盘用途,不注册 TrayManagerPlugin(托盘归主窗口独占,与 macOS 一致)。
    // tray_manager 的 Linux 实现用一个进程级全局 plugin_instance 记录最后一次注册的
    // 插件对象,子窗口注册会把它顶掉;子窗口关闭时该对象随引擎释放,之后点击托盘菜单
    // 就会用已释放的指针发 onTrayMenuItemClick,崩溃。
    g_autoptr(FlPluginRegistrar) screen_retriever_registrar =
        fl_plugin_registry_get_registrar_for_plugin(registry, "ScreenRetrieverLinuxPlugin");
    screen_retriever_linux_plugin_register_with_registrar(screen_retriever_registrar);
    // 媒体预览窗口:视频降级用系统播放器打开。
    g_autoptr(FlPluginRegistrar) url_launcher_registrar =
        fl_plugin_registry_get_registrar_for_plugin(registry, "UrlLauncherPlugin");
    url_launcher_plugin_register_with_registrar(url_launcher_registrar);
    // 统一清单中其余插件(shared_preferences / path_provider /
    // device_info_plus / file_picker / sqflite / 视频播放)在本项目的
    // Linux 依赖集中没有原生实现(见 linux/flutter/
    // generated_plugin_registrant.cc,符号不可链接),保留现状不注册。
  });

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  // 单实例检查
  _singleInstanceLockFd = _tryAcquireSingleInstanceLock();
  if (_singleInstanceLockFd < 0) {
    g_warning("Another instance is already running.");
    *exit_status = 0;
    return TRUE;
  }

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
     g_warning("Failed to register: %s", error->message);
     *exit_status = 1;
     return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     // 移除 G_APPLICATION_NON_UNIQUE,让 GApplication 自己再拦一道
                                     nullptr));
}
