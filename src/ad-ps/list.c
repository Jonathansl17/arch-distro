/*
 * list.c - process table of ad-ps.
 * CPU% = delta(utime+stime) of the process over the sampling window divided
 * by the window length in clock ticks, so 100% = one full core.
 */
#include "procfs.h"
#include "ps.h"

#include <ctype.h>
#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define MS_PER_SEC 1000
#define NS_PER_MS 1000000L
#define PERCENT 100.0

struct row {
    struct ad_proc_stat st;
    unsigned long long ticks0;
    double cpu;
};

static int wanted(const struct ad_ps_options *o, pid_t pid)
{
    if (o->n_filter == 0)
        return 1;
    for (int i = 0; i < o->n_filter; i++)
        if (o->filter[i] == pid)
            return 1;
    return 0;
}

/* First pass: one row per live process. Caller frees *out. */
static int snapshot(const struct ad_ps_options *o, struct row **out)
{
    DIR *d = opendir("/proc");
    if (!d) {
        perror("/proc");
        return -1;
    }
    int n = 0, cap = 0;
    struct row *rows = NULL;
    struct dirent *e;
    while ((e = readdir(d))) {
        if (!isdigit((unsigned char)e->d_name[0]))
            continue;
        pid_t pid = (pid_t)atoi(e->d_name);
        struct ad_proc_stat s;
        if (!wanted(o, pid) || ad_read_proc_stat(pid, &s) != 0)
            continue;
        if (n == cap) {
            cap = cap ? cap * 2 : 256;
            struct row *grown = realloc(rows, (size_t)cap * sizeof(*rows));
            if (!grown) {
                free(rows);
                closedir(d);
                return -1;
            }
            rows = grown;
        }
        rows[n].st = s;
        rows[n].ticks0 = s.utime + s.stime;
        n++;
    }
    closedir(d);
    *out = rows;
    return n;
}

static void sample(struct row *rows, int n, int interval_ms)
{
    struct timespec ts = { interval_ms / MS_PER_SEC,
                           (interval_ms % MS_PER_SEC) * NS_PER_MS };
    nanosleep(&ts, NULL);
    double window_ticks = sysconf(_SC_CLK_TCK) * interval_ms / (double)MS_PER_SEC;
    for (int i = 0; i < n; i++) {
        struct ad_proc_stat s;
        if (ad_read_proc_stat(rows[i].st.pid, &s) != 0) {
            rows[i].cpu = -1;  /* exited during the window */
            continue;
        }
        rows[i].cpu = (s.utime + s.stime - rows[i].ticks0) * PERCENT / window_ticks;
        rows[i].st = s;
    }
}

static int by_cpu(const void *a, const void *b)
{
    double d = ((const struct row *)b)->cpu - ((const struct row *)a)->cpu;
    return (d > 0) - (d < 0);
}

static int by_pid(const void *a, const void *b)
{
    return ((const struct row *)a)->st.pid - ((const struct row *)b)->st.pid;
}

static void print_rows(const struct row *rows, int n, int limit)
{
    printf("%7s %7s %s %4s %-6s %4s %4s %6s  %s\n", "PID", "PPID", "S", "NI",
           "POLICY", "RTPR", "CORE", "CPU%", "COMMAND");
    for (int i = 0, shown = 0; i < n && (limit == 0 || shown < limit); i++) {
        const struct ad_proc_stat *s = &rows[i].st;
        if (rows[i].cpu < 0)
            continue;
        printf("%7d %7d %c %4ld %-6s %4u %4d %6.1f  %s\n", (int)s->pid,
               (int)s->ppid, s->state, s->nice, ad_policy_name(s->policy),
               s->rt_priority, s->processor, rows[i].cpu, s->comm);
        shown++;
    }
}

int ad_ps_list(const struct ad_ps_options *o)
{
    struct row *rows = NULL;
    int n = snapshot(o, &rows);
    if (n < 0)
        return 1;
    sample(rows, n, o->interval_ms);
    qsort(rows, (size_t)n, sizeof(*rows), o->sort_by_pid ? by_pid : by_cpu);
    print_rows(rows, n, o->rows);
    free(rows);
    return 0;
}
