/* mem.h - shared declarations of ad-mem (theme 2: memory). */
#ifndef AD_MEM_H
#define AD_MEM_H

#include <sys/types.h>

#define AD_MEM_DEFAULT_INTERVAL_MS 1000
#define AD_MEM_DEFAULT_TOP 5

/* One system-wide sample: /proc/meminfo, /proc/vmstat, zram mm_stat. */
struct ad_mem_sample {
    long long mem_total_kib, mem_avail_kib;
    long long swap_total_kib, swap_free_kib;
    unsigned long long zram_orig_bytes, zram_compr_bytes, zram_used_bytes;
    unsigned long long pgfault, pgmajfault, pswpin, pswpout;
};

/* sample.c: fills s. Returns 0 or -1 when /proc is unreadable. */
int ad_mem_read_sample(struct ad_mem_sample *s);

/* top.c: per-process fault counters, kept between ticks. */
struct ad_fault_table;
struct ad_fault_table *ad_faults_new(void);
void ad_faults_free(struct ad_fault_table *t);
/* Rescans /proc and prints the `top` processes with most faults this tick. */
void ad_faults_print_top(struct ad_fault_table *t, int top);

#endif
