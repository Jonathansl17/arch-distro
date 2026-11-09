/* sample.c - system-wide memory counters for ad-mem. */
#include "mem.h"
#include "procfs.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define ZRAM_MM_STAT "/sys/block/zram0/mm_stat"
#define BIG_FILE (1 << 14)

/* /proc/vmstat has "name value" lines (no colon, unlike meminfo). */
static unsigned long long vmstat_value(const char *text, const char *key)
{
    size_t klen = strlen(key);
    for (const char *p = text; p && *p; p = strchr(p, '\n')) {
        if (*p == '\n')
            p++;
        if (strncmp(p, key, klen) == 0 && p[klen] == ' ')
            return strtoull(p + klen + 1, NULL, 10);
    }
    return 0;
}

static void read_zram(struct ad_mem_sample *s)
{
    char line[AD_LINE_MAX];
    s->zram_orig_bytes = s->zram_compr_bytes = s->zram_used_bytes = 0;
    if (ad_read_line(ZRAM_MM_STAT, line, sizeof(line)) == 0)
        sscanf(line, "%llu %llu %llu", &s->zram_orig_bytes,
               &s->zram_compr_bytes, &s->zram_used_bytes);
}

int ad_mem_read_sample(struct ad_mem_sample *s)
{
    static char text[BIG_FILE];
    if (ad_read_file("/proc/meminfo", text, sizeof(text)) < 0)
        return -1;
    s->mem_total_kib = ad_meminfo_value(text, "MemTotal");
    s->mem_avail_kib = ad_meminfo_value(text, "MemAvailable");
    s->swap_total_kib = ad_meminfo_value(text, "SwapTotal");
    s->swap_free_kib = ad_meminfo_value(text, "SwapFree");
    if (ad_read_file("/proc/vmstat", text, sizeof(text)) < 0)
        return -1;
    s->pgfault = vmstat_value(text, "pgfault");
    s->pgmajfault = vmstat_value(text, "pgmajfault");
    s->pswpin = vmstat_value(text, "pswpin");
    s->pswpout = vmstat_value(text, "pswpout");
    read_zram(s);
    return 0;
}
