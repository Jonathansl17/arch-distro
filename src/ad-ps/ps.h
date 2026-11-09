/* ps.h - shared declarations of ad-ps (theme 1: processes and scheduling). */
#ifndef AD_PS_H
#define AD_PS_H

#include <sys/types.h>

#define AD_PS_DEFAULT_ROWS 20
#define AD_PS_DEFAULT_INTERVAL_MS 1000
#define AD_PS_MAX_FILTER 16

struct ad_ps_options {
    int rows;                          /* 0 = all */
    int interval_ms;                   /* CPU% sampling window */
    int sort_by_pid;                   /* default: by CPU% desc */
    int n_filter;                      /* only these PIDs when > 0 */
    pid_t filter[AD_PS_MAX_FILTER];
};

/* list.c: prints the process table. Returns process exit code. */
int ad_ps_list(const struct ad_ps_options *opt);

/* set.c: changes nice value (setpriority). Returns exit code. */
int ad_ps_set_nice(pid_t pid, int nice_value);

/* set.c: changes policy (sched_setscheduler). Returns exit code. */
int ad_ps_set_policy(pid_t pid, const char *policy, int rt_priority);

#endif
