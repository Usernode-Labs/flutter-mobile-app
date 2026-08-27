#include "my_application.h"

int main(int argc, char** argv) {
  // WebKitGTK's DMA-BUF renderer is unreliable with some NVIDIA drivers and
  // headless/remote displays. Preserve an explicit user override, otherwise
  // select the broadly compatible renderer before GTK/WebKit initializes.
  g_setenv("WEBKIT_DISABLE_DMABUF_RENDERER", "1", FALSE);

  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
