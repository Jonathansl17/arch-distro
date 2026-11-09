/*
 * top.c - per-process minor/major page faults between two ticks.
 * minflt: page was already in RAM (or zero page) - no I/O.
 * majflt: page had to be read from disk or swap (zram counts here too).
 */
#include "mem.h"
#include "procfs.h"

#include <ctype.h>
#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>

#define INITIAL_CAP 4096  /* processes tracked per tick */

struct entry {
    pid_t pid;
    unsigned long minflt, majflt;   /* counters at last tick */
    unsigned long dmin, dmaj;       /* delta during this tick */
    char comm[AD_COMM_MAX];
};

struct ad_fault_table {
    struct entry *prev, *cur;
    int n_prev, n_cur, cap;
};

struct ad_fault_table *ad_faults_new(void)
{
    struct ad_fault_table *t = calloc(1, sizeof(*t));
    if (!t)
        return NULL;
    t->cap = INITIAL_CAP;
    t->prev = calloc((size_t)t->cap, sizeof(struct entry));
    t->cur = calloc((size_t)t->cap, sizeof(struct entry));
    if (!t->prev || !t->cur) {
        ad_faults_free(t);
        return NULL;
    }
    return t;
}

void ad_faults_free(struct ad_fault_table *t)
{
    if (!t)
        return;
    free(t->prev);
    free(t->cur);
    free(t);
}

static const struct entry *find_prev(const struct ad_fault_table *t, pid_t pid)
{
    for (int i = 0; i < t->n_prev; i++)
        if (t->prev[i].pid == pid)
            return &t->prev[i];
    return NULL;
}

static void add_current(struct ad_fault_table *t, const struct ad_proc_stat *s)
{
    if (t->n_cur == t->cap)
        return;  /* table full: extra processes ignored this tick */
    struct entry *e = &t->cur[t->n_cur++];
    const struct entry *old = find_prev(t, s->pid);
    e->pid = s->pid;
    e->minflt = s->minflt;
    e->majflt = s->majflt;
    e->dmin = old ? s->minflt - old->minflt : 0;
    e->dmaj = old ? s->majflt - old->majflt : 0;
    snprintf(e->comm, sizeof(e->comm), "%s", s->comm);
}

static void rescan(struct ad_fault_table *t)
{
    t->n_cur = 0;
    DIR *d = opendir("/proc");
    struct dirent *de;
    while (d && (de = readdir(d))) {
        struct ad_proc_stat s;
        if (isdigit((unsigned char)de->d_name[0]) &&
            ad_read_proc_stat((pid_t)atoi(de->d_name), &s) == 0)
            add_current(t, &s);
    }
    if (d)
        closedir(d);
}

static int by_faults(const void *a, const void *b)
{
    const struct entry *x = a, *y = b;
    if (x->dmaj != y->dmaj)
        return x->dmaj < y->dmaj ? 1 : -1;
    return (x->dmin < y->dmin) - (x->dmin > y->dmin);
}

void ad_faults_print_top(struct ad_fault_table *t, int top)
{
    rescan(t);
    struct entry *sorted = malloc((size_t)t->n_cur * sizeof(*sorted));
    if (!sorted)
        return;
    for (int i = 0; i < t->n_cur; i++)
        sorted[i] = t->cur[i];
    qsort(sorted, (size_t)t->n_cur, sizeof(*sorted), by_faults);
    printf("  %7s %10s %10s  %s\n", "PID", "minflt/t", "majflt/t", "COMMAND");
    for (int i = 0; i < t->n_cur && i < top; i++)
        printf("  %7d %10lu %10lu  %s\n", (int)sorted[i].pid, sorted[i].dmin,
               sorted[i].dmaj, sorted[i].comm);
    free(sorted);
    struct entry *swap = t->prev;  /* current tick becomes the baseline */
    t->prev = t->cur;
    t->cur = swap;
    t->n_prev = t->n_cur;
}
