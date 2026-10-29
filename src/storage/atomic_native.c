// Immutable snapshot commits. The index is a rebuildable cache.
#include "moonbit.h"
#include <errno.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#ifdef _WIN32
#include <windows.h>
#include <direct.h>
#include <io.h>
#include <fcntl.h>
#define MT_CLOSE _close
#define MT_SYNC _commit
#define MT_WRITE _write
static wchar_t *wide(const char *s) {
  int n = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, s, -1, NULL, 0);
  if (!n) return NULL;
  wchar_t *w = malloc((size_t)n * sizeof(wchar_t));
  if (w) MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, s, -1, w, n);
  return w;
}
static int make_dir(const char *p) {
  wchar_t *w = wide(p); if (!w) return -1;
  int r = _wmkdir(w); free(w); return r;
}
#else
#include <unistd.h>
#include <fcntl.h>
#define MT_CLOSE close
#define MT_SYNC fsync
#define MT_WRITE write
static int make_dir(const char *p) { return mkdir(p, 0700); }
#endif

MOONBIT_FFI_EXPORT int moontrace_mkdirs(moonbit_bytes_t path) {
  char *p = strdup((const char *)path);
  if (!p) return 2;
  for (size_t i = 1; p[i]; ++i) {
    if (p[i] != '/' && p[i] != '\\') continue;
#ifdef _WIN32
    if (i == 2 && p[1] == ':') continue;
#endif
    char sep = p[i]; p[i] = 0;
    if (make_dir(p) && errno != EEXIST) { free(p); return 2; }
    p[i] = sep;
  }
  int r = make_dir(p);
  int result = (r == 0 || errno == EEXIST) ? 0 : 2;
  free(p); return result;
}

MOONBIT_FFI_EXPORT int moontrace_write_atomic(moonbit_bytes_t path,
    moonbit_bytes_t temp, moonbit_bytes_t content, int size, int replace) {
#ifdef _WIN32
  wchar_t *wp = wide((const char *)path), *wt = wide((const char *)temp);
  if (!wp || !wt) { free(wp); free(wt); return 2; }
  int fd = _wopen(wt, _O_WRONLY | _O_CREAT | _O_EXCL | _O_BINARY, _S_IREAD | _S_IWRITE);
#else
  int fd = open((const char *)temp, O_WRONLY | O_CREAT | O_EXCL, 0600);
#endif
  if (fd < 0) {
#ifdef _WIN32
    free(wp); free(wt);
#endif
    return 2;
  }
  int result = 0, offset = 0;
  while (offset < size) {
    int n = (int)MT_WRITE(fd, content + offset, (size_t)(size - offset));
    if (n < 0 && errno == EINTR) continue;
    if (n <= 0) { result = 2; break; }
    offset += n;
  }
  if (!result && MT_SYNC(fd)) result = 2;
  if (MT_CLOSE(fd)) result = 2;
  if (!result) {
#ifdef _WIN32
    if (!MoveFileExW(wt, wp, MOVEFILE_WRITE_THROUGH | (replace ? MOVEFILE_REPLACE_EXISTING : 0))) {
      DWORD e = GetLastError();
      result = (e == ERROR_ALREADY_EXISTS || e == ERROR_FILE_EXISTS) ? 1 : 2;
    }
#else
    // Unlike rename, link cannot replace an existing trace.
    int r = replace ? rename((const char *)temp, (const char *)path)
                    : link((const char *)temp, (const char *)path);
    if (r) result = (errno == EEXIST) ? 1 : 2;
#endif
  }
#ifdef _WIN32
  _wunlink(wt); free(wp); free(wt);
#else
  unlink((const char *)temp);
#endif
  return result;
}
