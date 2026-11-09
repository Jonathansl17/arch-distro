/* fmt.c - see fmt.h. */
#include "fmt.h"

#include <stdio.h>

#define KIB_PER_MIB 1024.0
#define KIB_PER_GIB (1024.0 * 1024.0)
#define SECS_PER_MIN 60
#define SECS_PER_HOUR 3600
#define SECS_PER_DAY 86400

void ad_fmt_kib(long long kib, char *buf, size_t size)
{
    if (kib < 0)
        snprintf(buf, size, "n/a");
    else if (kib >= KIB_PER_GIB)
        snprintf(buf, size, "%.1f GiB", (double)kib / KIB_PER_GIB);
    else if (kib >= KIB_PER_MIB)
        snprintf(buf, size, "%.1f MiB", (double)kib / KIB_PER_MIB);
    else
        snprintf(buf, size, "%lld KiB", kib);
}

void ad_fmt_duration(long long s, char *buf, size_t size)
{
    long long d = s / SECS_PER_DAY;
    long long h = (s % SECS_PER_DAY) / SECS_PER_HOUR;
    long long m = (s % SECS_PER_HOUR) / SECS_PER_MIN;
    if (d > 0)
        snprintf(buf, size, "%lldd %lldh %lldm", d, h, m);
    else if (h > 0)
        snprintf(buf, size, "%lldh %lldm", h, m);
    else
        snprintf(buf, size, "%lldm %llds", m, s % SECS_PER_MIN);
}
