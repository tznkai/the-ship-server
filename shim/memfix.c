// SPDX-FileCopyrightText: 2026 K. Chen
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// LD_PRELOAD shim for the 2007 Source dedicated server. Its engine copies strings between
// overlapping buffers, which modern glibc's optimised memcpy/strcpy corrupt (garbled console
// commands, +map never runs). Route those calls through overlap-safe memmove.
#define _GNU_SOURCE
#include <string.h>

void *memcpy(void *dst, const void *src, size_t n) { return memmove(dst, src, n); }

char *strcpy(char *dst, const char *src) { return memmove(dst, src, strlen(src) + 1); }

char *strncpy(char *dst, const char *src, size_t n)
{
    size_t len = strnlen(src, n);
    memmove(dst, src, len);
    if (len < n)
        memset(dst + len, 0, n - len);
    return dst;
}

char *strcat(char *dst, const char *src) { strcpy(dst + strlen(dst), src); return dst; }

// The 2007 engine blocks its main thread on a TCP connect to Steam2 config/content servers
// (ports 27030-27039), which have been offline for years. Refuse those at once so it moves on.
#include <dlfcn.h>
#include <errno.h>
#include <netinet/in.h>
#include <sys/socket.h>

int connect(int fd, const struct sockaddr *addr, socklen_t len)
{
    static int (*real_connect)(int, const struct sockaddr *, socklen_t);
    if (addr && addr->sa_family == AF_INET) {
        int port = ntohs(((const struct sockaddr_in *)addr)->sin_port);
        if (port >= 27030 && port <= 27039) {
            errno = ECONNREFUSED;
            return -1;
        }
    }
    if (!real_connect)
        real_connect = (int (*)(int, const struct sockaddr *, socklen_t))dlsym(RTLD_NEXT, "connect");
    return real_connect(fd, addr, len);
}
