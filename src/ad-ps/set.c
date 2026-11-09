/* set.c - nice and scheduling-policy changes for ad-ps. */
#include "procfs.h"
#include "ps.h"

#include <errno.h>
#include <sched.h>
#include <stdio.h>
#include <string.h>
#include <sys/resource.h>

static int report(pid_t pid)
{
    struct ad_proc_stat s;
    if (ad_read_proc_stat(pid, &s) != 0) {
        fprintf(stderr, "ad-ps: process %d vanished\n", (int)pid);
        return 1;
    }
    printf("%d %s: nice=%ld policy=SCHED_%s rt_priority=%u\n", (int)s.pid,
           s.comm, s.nice, ad_policy_name(s.policy), s.rt_priority);
    return 0;
}

int ad_ps_set_nice(pid_t pid, int nice_value)
{
    if (setpriority(PRIO_PROCESS, (id_t)pid, nice_value) != 0) {
        fprintf(stderr, "ad-ps: setpriority(%d, %d): %s%s\n", (int)pid,
                nice_value, strerror(errno),
                errno == EACCES ? " (lowering nice needs root)" : "");
        return 1;
    }
    return report(pid);
}

int ad_ps_set_policy(pid_t pid, const char *name, int rt_priority)
{
    int policy = ad_policy_from_name(name);
    if (policy < 0) {
        fprintf(stderr, "ad-ps: unknown policy '%s'\n", name);
        return 2;
    }
    int is_rt = policy == SCHED_FIFO || policy == SCHED_RR;
    int lo = sched_get_priority_min(policy), hi = sched_get_priority_max(policy);
    if (is_rt && (rt_priority < lo || rt_priority > hi)) {
        fprintf(stderr, "ad-ps: real-time priority must be %d..%d\n", lo, hi);
        return 2;
    }
    struct sched_param p = { .sched_priority = is_rt ? rt_priority : 0 };
    if (sched_setscheduler(pid, policy, &p) != 0) {
        fprintf(stderr, "ad-ps: sched_setscheduler(%d, %s): %s\n", (int)pid,
                name, strerror(errno));
        return 1;
    }
    return report(pid);
}
