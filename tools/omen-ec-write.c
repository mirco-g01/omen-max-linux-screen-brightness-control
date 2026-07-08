// SPDX-License-Identifier: MIT
/*
 * omen-ec-write - fixed-purpose helper for HP OMEN Max Linux brightness workaround
 *
 * This helper reads/writes one byte at the HP OMEN Max EC/PWM register found
 * during ACPI reverse engineering. It is intentionally narrow in scope and
 * accepts only brightness values in the configured safe range.
 */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

#define DEFAULT_REG 0xFD400CF5UL
#define DEFAULT_MIN 5
#define DEFAULT_MAX 100

static unsigned long parse_ulong_env(const char *name, unsigned long fallback) {
    const char *v = getenv(name);
    if (!v || !*v) return fallback;
    char *end = NULL;
    errno = 0;
    unsigned long out = strtoul(v, &end, 0);
    if (errno || !end || *end != '\0') return fallback;
    return out;
}

static int parse_int_arg(const char *s, int *out) {
    if (!s || !*s) return -1;
    char *end = NULL;
    errno = 0;
    long v = strtol(s, &end, 10);
    if (errno || !end || *end != '\0' || v < 0 || v > 255) return -1;
    *out = (int)v;
    return 0;
}

static int access_reg(unsigned long reg, int do_write, uint8_t value, uint8_t *readback) {
    long page_size = sysconf(_SC_PAGESIZE);
    if (page_size <= 0) {
        fprintf(stderr, "Could not determine page size\n");
        return 1;
    }

    unsigned long page_base = reg & ~((unsigned long)page_size - 1UL);
    unsigned long page_off = reg - page_base;

    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) {
        fprintf(stderr, "open(/dev/mem) failed: %s\n", strerror(errno));
        return 1;
    }

    void *map = mmap(NULL, (size_t)page_size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, (off_t)page_base);
    if (map == MAP_FAILED) {
        fprintf(stderr, "mmap failed: %s\n", strerror(errno));
        close(fd);
        return 1;
    }

    volatile uint8_t *ptr = (volatile uint8_t *)map + page_off;
    if (do_write) {
        *ptr = value;
        __sync_synchronize();
    }
    *readback = *ptr;

    munmap(map, (size_t)page_size);
    close(fd);
    return 0;
}

int main(int argc, char **argv) {
    unsigned long reg = DEFAULT_REG;
    const char *custom = getenv("OMEN_BACKLIGHT_REG");
    const char *allow_custom = getenv("OMEN_ALLOW_CUSTOM_REG");
    if (custom && *custom) {
        if (!allow_custom || strcmp(allow_custom, "1") != 0) {
            fprintf(stderr, "Custom register refused. Set OMEN_ALLOW_CUSTOM_REG=1 only after validating your ACPI tables.\n");
            return 2;
        }
        reg = parse_ulong_env("OMEN_BACKLIGHT_REG", DEFAULT_REG);
    }

    int min = (int)parse_ulong_env("OMEN_BACKLIGHT_MIN", DEFAULT_MIN);
    int max = (int)parse_ulong_env("OMEN_BACKLIGHT_MAX", DEFAULT_MAX);
    if (min < 0) min = DEFAULT_MIN;
    if (max > 100) max = DEFAULT_MAX;
    if (min > max) {
        min = DEFAULT_MIN;
        max = DEFAULT_MAX;
    }

    uint8_t readback = 0;

    if (argc == 1) {
        if (access_reg(reg, 0, 0, &readback)) return 1;
        printf("%u\n", (unsigned)readback);
        return 0;
    }

    if (argc != 2) {
        fprintf(stderr, "Usage: %s [brightness-%d-%d]\n", argv[0], min, max);
        return 2;
    }

    int value = 0;
    if (parse_int_arg(argv[1], &value)) {
        fprintf(stderr, "Invalid brightness value: %s\n", argv[1]);
        return 2;
    }

    if (value < min) value = min;
    if (value > max) value = max;

    if (access_reg(reg, 1, (uint8_t)value, &readback)) return 1;
    printf("%u\n", (unsigned)readback);
    return 0;
}
