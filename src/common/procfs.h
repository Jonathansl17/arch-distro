/*
 * procfs.h - small readers for /proc and /sys shared by every ad-* command.
 * No external tools are spawned: everything is open()/read() on kernel files.
 */
#ifndef AD_PROCFS_H
#define AD_PROCFS_H

#include <stddef.h>
#include <sys/types.h>

#define AD_COMM_MAX 64
#define AD_PATH_MAX 512
#define AD_LINE_MAX 1024

/* Subset of /proc/<pid>/stat (proc(5) field numbers in comments). */
struct ad_proc_stat {
    pid_t pid;                     /* 1  */
    char comm[AD_COMM_MAX];        /* 2  */
    char state;                    /* 3  */
    pid_t ppid;                    /* 4  */
    unsigned long minflt;          /* 10 */
    unsigned long majflt;          /* 12 */
    unsigned long long utime;      /* 14 (clock ticks) */
    unsigned long long stime;      /* 15 (clock ticks) */
    long priority;                 /* 18 */
    long nice;                     /* 19 */
    long num_threads;              /* 20 */
    long rss_pages;                /* 24 */
    int processor;                 /* 39 */
    unsigned rt_priority;          /* 40 */
    unsigned policy;               /* 41 */
};

/* Reads a whole small file into buf (NUL terminated). Returns bytes or -1. */
ssize_t ad_read_file(const char *path, char *buf, size_t size);

/* Reads the first line of path without the trailing newline. 0 ok, -1 error. */
int ad_read_line(const char *path, char *buf, size_t size);

/* Parses the content of /proc/<pid>/stat. 0 ok, -1 malformed. */
int ad_parse_stat(const char *text, struct ad_proc_stat *out);

/* Reads and parses /proc/<pid>/stat. 0 ok, -1 if the process vanished. */
int ad_read_proc_stat(pid_t pid, struct ad_proc_stat *out);

/* Looks up "Key:" in /proc/meminfo-formatted text. Returns kB or -1. */
long long ad_meminfo_value(const char *text, const char *key);

/* Total jiffies of the "cpu " line of /proc/stat text, or 0 on error. */
unsigned long long ad_cpu_total_jiffies(const char *text);

/* Name of a scheduling policy number without the SCHED_ prefix (OTHER, ...). */
const char *ad_policy_name(unsigned policy);

/* Parses a policy name, case-insensitive (other|fifo|rr|batch|idle). -1 if unknown. */
int ad_policy_from_name(const char *name);

#endif
