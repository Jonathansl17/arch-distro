/*
 * ad-ps - process table and scheduler control (theme 1).
 *
 *   ad-ps [-n ROWS] [-i MS] [-s pid|cpu] [-p PID]...   list processes
 *   ad-ps nice PID VALUE                               setpriority(2)
 *   ad-ps policy PID other|batch|idle|fifo|rr [PRIO]   sched_setscheduler(2)
 */
#include "ps.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define EXIT_USAGE 2

static int usage(void)
{
    fputs("usage: ad-ps [-n ROWS|0=all] [-i MS] [-s pid|cpu] [-p PID]...\n"
          "       ad-ps nice PID VALUE\n"
          "       ad-ps policy PID other|batch|idle|fifo|rr [RT_PRIO]\n",
          stderr);
    return EXIT_USAGE;
}

static int parse_list(int argc, char **argv, struct ad_ps_options *o)
{
    int c;
    while ((c = getopt(argc, argv, "n:i:s:p:h")) != -1) {
        switch (c) {
        case 'n': o->rows = atoi(optarg); break;
        case 'i': o->interval_ms = atoi(optarg); break;
        case 's': o->sort_by_pid = strcmp(optarg, "pid") == 0; break;
        case 'p':
            if (o->n_filter == AD_PS_MAX_FILTER)
                return -1;
            o->filter[o->n_filter++] = (pid_t)atoi(optarg);
            break;
        default: return -1;
        }
    }
    return o->interval_ms > 0 && o->rows >= 0 ? 0 : -1;
}

int main(int argc, char **argv)
{
    if (argc >= 2 && strcmp(argv[1], "nice") == 0)
        return argc == 4 ? ad_ps_set_nice(atoi(argv[2]), atoi(argv[3]))
                         : usage();
    if (argc >= 2 && strcmp(argv[1], "policy") == 0) {
        if (argc != 4 && argc != 5)
            return usage();
        return ad_ps_set_policy(atoi(argv[2]), argv[3],
                                argc == 5 ? atoi(argv[4]) : 0);
    }
    struct ad_ps_options o = {
        .rows = AD_PS_DEFAULT_ROWS,
        .interval_ms = AD_PS_DEFAULT_INTERVAL_MS,
    };
    if (parse_list(argc, argv, &o) != 0)
        return usage();
    return ad_ps_list(&o);
}
