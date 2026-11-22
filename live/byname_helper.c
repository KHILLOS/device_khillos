/*
 * Copyright (C) 2026 KhillOS
 * SPDX-License-Identifier: Apache-2.0
 *
 * Restore live-media block nodes after Android first-stage init mounts its
 * fresh /dev tmpfs. This is a single static process: it must not depend on any
 * executable or library path while Android switches roots.
 */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/sysmacros.h>
#include <time.h>
#include <unistd.h>

static const char* const kLabels[] = {
        "boot_a", "boot_b", "init_boot_a", "init_boot_b",
        "vendor_boot_a", "vendor_boot_b", "vbmeta_a", "vbmeta_b",
        "vbmeta_system_a", "vbmeta_system_b", "vbmeta_vendor_dlkm_a",
        "vbmeta_vendor_dlkm_b", "vbmeta_system_dlkm_a",
        "vbmeta_system_dlkm_b", "super",
};

static void log_message(const char* format, ...) {
    char message[512];
    va_list arguments;
    va_start(arguments, format);
    int length = vsnprintf(message, sizeof(message), format, arguments);
    va_end(arguments);
    if (length < 0) return;
    if ((size_t)length >= sizeof(message)) length = (int)sizeof(message) - 1;
    int fd = open("/dev/kmsg", O_WRONLY | O_CLOEXEC);
    if (fd < 0) return;
    ssize_t written = write(fd, message, (size_t)length);
    (void)written;
    close(fd);
}

static int make_node(const char* label, const char* source) {
    char path[256];
    if (snprintf(path, sizeof(path), "/proc/1/root/dev/block/by-name/%s", label) >=
        (int)sizeof(path)) {
        return -1;
    }
    struct stat existing;
    if (lstat(path, &existing) == 0) return 0;

    char sysfs[256];
    if (snprintf(sysfs, sizeof(sysfs), "/sys/class/block/%s/dev", source) >=
        (int)sizeof(sysfs)) {
        return -1;
    }
    int fd = open(sysfs, O_RDONLY | O_CLOEXEC);
    if (fd < 0) {
        log_message("khillos-live-helper: open %s failed: %s\n", sysfs, strerror(errno));
        return -1;
    }
    char numbers[64];
    ssize_t count = read(fd, numbers, sizeof(numbers) - 1);
    int saved_errno = errno;
    close(fd);
    if (count <= 0) {
        log_message("khillos-live-helper: read %s failed: %s\n", sysfs,
                    count < 0 ? strerror(saved_errno) : "empty device number");
        return -1;
    }
    numbers[count] = '\0';
    unsigned int major_number = 0;
    unsigned int minor_number = 0;
    if (sscanf(numbers, "%u:%u", &major_number, &minor_number) != 2) {
        log_message("khillos-live-helper: invalid device number in %s\n", sysfs);
        return -1;
    }
    if (mknod(path, S_IFBLK | 0600, makedev(major_number, minor_number)) != 0 &&
        errno != EEXIST) {
        log_message("khillos-live-helper: mknod %s failed: %s\n", path, strerror(errno));
        return -1;
    }
    return 0;
}

int main(int argc, char** argv) {
    if (argc != 2 || strncmp(argv[1], "loop", 4) != 0) return 2;

    // /dev/dm-user is created immediately after Android's fresh /dev tmpfs.
    // Polling is event-anchored; Android's remaining module loads provide time
    // for these few synchronous syscalls before first-stage partition mounting.
    bool ready = false;
    for (int attempt = 0; attempt < 3000; ++attempt) {
        struct stat status;
        if (stat("/proc/1/root/dev/dm-user", &status) == 0 && S_ISDIR(status.st_mode)) {
            ready = true;
            break;
        }
        const struct timespec delay = {.tv_sec = 0, .tv_nsec = 20000000};
        nanosleep(&delay, NULL);
    }
    if (!ready) {
        log_message("khillos-live-helper: timed out waiting for /proc/1/root/dev/dm-user\n");
        return 1;
    }

    if ((mkdir("/proc/1/root/dev/block", 0755) != 0 && errno != EEXIST) ||
        (mkdir("/proc/1/root/dev/block/by-name", 0755) != 0 && errno != EEXIST)) {
        log_message("khillos-live-helper: create by-name directory failed: %s\n",
                    strerror(errno));
        return 1;
    }

    for (size_t index = 0; index < sizeof(kLabels) / sizeof(kLabels[0]); ++index) {
        char source[64];
        if (snprintf(source, sizeof(source), "%sp%zu", argv[1], index + 1) >=
            (int)sizeof(source)) {
            return 1;
        }
        if (make_node(kLabels[index], source) != 0) return 1;
    }
    if (make_node("userdata", "vda1") != 0 || make_node("metadata", "vda2") != 0 ||
        make_node("misc", "vda3") != 0) {
        return 1;
    }

    log_message("khillos-live-helper: restored live by-name block nodes\n");
    return 0;
}
