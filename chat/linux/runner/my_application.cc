#include "my_application.h"

#include <errno.h>
#include <fcntl.h>
#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#include "flutter/generated_plugin_registrant.h"

#include <desktop_multi_window/desktop_multi_window_plugin.h>
#include <flutter_webrtc/flutter_web_r_t_c_plugin.h>
#include <window_manager/window_manager_plugin.h>
#include <tray_manager/tray_manager_plugin.h>
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

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
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
    gtk_header_bar_set_title(header_bar, "chat");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "chat");
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
    g_autoptr(FlPluginRegistrar) tray_manager_registrar =
        fl_plugin_registry_get_registrar_for_plugin(registry, "TrayManagerPlugin");
    tray_manager_plugin_register_with_registrar(tray_manager_registrar);
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
