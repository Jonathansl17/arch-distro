/* mem.c - memory, swap, zram and process sections of ad-info. */
#include "fmt.h"
#include "procfs.h"
#include "sections.h"

#include <ctype.h>
#include <dirent.h>
#include <stdio.h>

#define ZRAM_MM_STAT "/sys/block/zram0/mm_stat"
#define BYTES_PER_KIB 1024

void ad_section_memory(void)
{
    static char mi[1 << 13];
    if (ad_read_file("/proc/meminfo", mi, sizeof(mi)) < 0) {
        perror("/proc/meminfo");
        return;
    }
    long long total = ad_meminfo_value(mi, "MemTotal");
    long long avail = ad_meminfo_value(mi, "MemAvailable");
    long long stotal = ad_meminfo_value(mi, "SwapTotal");
    long long sfree = ad_meminfo_value(mi, "SwapFree");
    char a[32], b[32];
    ad_fmt_kib(total - avail, a, sizeof(a));
    ad_fmt_kib(total, b, sizeof(b));
    AD_ROW("RAM", "%s used / %s", a, b);
    ad_fmt_kib(stotal - sfree, a, sizeof(a));
    ad_fmt_kib(stotal, b, sizeof(b));
    AD_ROW("Swap", "%s used / %s", a, b);

    /* /proc/swaps: Filename Type Size Used Priority (sizes in KiB). */
    FILE *f = fopen("/proc/swaps", "r");
    char line[AD_LINE_MAX], name[AD_PATH_MAX], type[AD_COMM_MAX];
    long long size, used;
    int prio;
    while (f && fgets(line, sizeof(line), f))
        if (sscanf(line, "%511s %63s %lld %lld %d", name, type, &size, &used,
                   &prio) == 5) {
            ad_fmt_kib(size, a, sizeof(a));
            AD_ROW("  device", "%s (%s, %s, prio %d)", name, type, a, prio);
        }
    if (f)
        fclose(f);

    /* mm_stat: orig_data_size compr_data_size mem_used_total ... (bytes) */
    unsigned long long orig, compr, used_total;
    if (ad_read_line(ZRAM_MM_STAT, line, sizeof(line)) == 0 &&
        sscanf(line, "%llu %llu %llu", &orig, &compr, &used_total) == 3) {
        ad_fmt_kib((long long)(orig / BYTES_PER_KIB), a, sizeof(a));
        ad_fmt_kib((long long)(used_total / BYTES_PER_KIB), b, sizeof(b));
        AD_ROW("zram0", "%s stored in %s RAM, ratio %.2f:1", a, b,
               compr ? (double)orig / (double)compr : 0.0);
    } else {
        AD_ROW("zram0", "not active");
    }
}

void ad_section_processes(void)
{
    char load[AD_LINE_MAX];
    DIR *d = opendir("/proc");
    int count = 0;
    struct dirent *e;
    while (d && (e = readdir(d)))
        if (isdigit((unsigned char)e->d_name[0]))
            count++;
    if (d)
        closedir(d);
    AD_ROW("Total", "%d", count);
    /* loadavg: 1m 5m 15m running/total last_pid */
    if (ad_read_line("/proc/loadavg", load, sizeof(load)) == 0)
        AD_ROW("Loadavg", "%s", load);
}
