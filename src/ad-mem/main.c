/*
 * ad-mem - real-time memory monitor (theme 2).
 *
 *   ad-mem [-i MS] [-c COUNT] [-t TOP]   human view, refreshed every MS
 *   ad-mem --csv [-i MS] [-c COUNT]      one CSV row per tick (experiments)
 *
 * Shows RAM, swap, zram compression ratio, system-wide fault and swap rates
 * (/proc/vmstat) and the processes with most minor/major faults per tick.
 */
#include "fmt.h"
#include "mem.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define MS_PER_SEC 1000
#define NS_PER_MS 1000000L
#define BYTES_PER_KIB 1024
#define CLEAR_SCREEN "\033[H\033[2J"

struct options { int interval_ms, count, top, csv; };

static void sleep_ms(int ms)
{
    struct timespec ts = { ms / MS_PER_SEC, (ms % MS_PER_SEC) * NS_PER_MS };
    nanosleep(&ts, NULL);
}

static double rate(unsigned long long now, unsigned long long before, int ms)
{
    return (double)(now - before) * MS_PER_SEC / ms;
}

static void print_csv(const struct ad_mem_sample *a,
                      const struct ad_mem_sample *b, int ms)
{
    printf("%ld,%lld,%lld,%llu,%llu,%.0f,%.0f,%.0f,%.0f\n", (long)time(NULL),
           b->mem_avail_kib, b->swap_total_kib - b->swap_free_kib,
           b->zram_orig_bytes / BYTES_PER_KIB, b->zram_compr_bytes / BYTES_PER_KIB,
           rate(b->pgfault, a->pgfault, ms), rate(b->pgmajfault, a->pgmajfault, ms),
           rate(b->pswpin, a->pswpin, ms), rate(b->pswpout, a->pswpout, ms));
}

static void print_human(const struct ad_mem_sample *a,
                        const struct ad_mem_sample *b, int ms)
{
    char x[32], y[32];
    fputs(CLEAR_SCREEN, stdout);
    ad_fmt_kib(b->mem_total_kib - b->mem_avail_kib, x, sizeof(x));
    ad_fmt_kib(b->mem_total_kib, y, sizeof(y));
    printf("RAM   %s used / %s\n", x, y);
    ad_fmt_kib(b->swap_total_kib - b->swap_free_kib, x, sizeof(x));
    ad_fmt_kib(b->swap_total_kib, y, sizeof(y));
    printf("Swap  %s used / %s (all devices)\n", x, y);
    ad_fmt_kib((long long)(b->zram_orig_bytes / BYTES_PER_KIB), x, sizeof(x));
    ad_fmt_kib((long long)(b->zram_used_bytes / BYTES_PER_KIB), y, sizeof(y));
    printf("zram  %s data in %s RAM, ratio %.2f:1\n", x, y,
           b->zram_compr_bytes ? (double)b->zram_orig_bytes / b->zram_compr_bytes : 0.0);
    printf("Rates pgfault %.0f/s  pgmajfault %.0f/s  swap-in %.0f pg/s  "
           "swap-out %.0f pg/s\n\n", rate(b->pgfault, a->pgfault, ms),
           rate(b->pgmajfault, a->pgmajfault, ms), rate(b->pswpin, a->pswpin, ms),
           rate(b->pswpout, a->pswpout, ms));
}

static int parse(int argc, char **argv, struct options *o)
{
    for (int i = 1; i < argc; i++) {
        int more = i + 1 < argc;
        if (strcmp(argv[i], "--csv") == 0) o->csv = 1;
        else if (strcmp(argv[i], "-i") == 0 && more) o->interval_ms = atoi(argv[++i]);
        else if (strcmp(argv[i], "-c") == 0 && more) o->count = atoi(argv[++i]);
        else if (strcmp(argv[i], "-t") == 0 && more) o->top = atoi(argv[++i]);
        else return -1;
    }
    return o->interval_ms > 0 ? 0 : -1;
}

int main(int argc, char **argv)
{
    struct options o = { AD_MEM_DEFAULT_INTERVAL_MS, 0, AD_MEM_DEFAULT_TOP, 0 };
    if (parse(argc, argv, &o) != 0) {
        fputs("usage: ad-mem [--csv] [-i MS] [-c COUNT|0=forever] [-t TOP]\n", stderr);
        return 2;
    }
    struct ad_mem_sample prev, cur;
    struct ad_fault_table *faults = o.csv ? NULL : ad_faults_new();
    if (ad_mem_read_sample(&prev) != 0 || (!o.csv && !faults)) {
        perror("ad-mem");
        return 1;
    }
    if (o.csv)
        puts("epoch,mem_avail_kib,swap_used_kib,zram_orig_kib,zram_compr_kib,"
             "pgfault_s,pgmajfault_s,pswpin_s,pswpout_s");
    for (int tick = 0; o.count == 0 || tick < o.count; tick++) {
        sleep_ms(o.interval_ms);
        if (ad_mem_read_sample(&cur) != 0)
            break;
        if (o.csv) {
            print_csv(&prev, &cur, o.interval_ms);
        } else {
            print_human(&prev, &cur, o.interval_ms);
            ad_faults_print_top(faults, o.top);
        }
        fflush(stdout);
        prev = cur;
    }
    ad_faults_free(faults);
    return 0;
}
