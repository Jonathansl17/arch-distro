/* procfs.c - see procfs.h. */
#include "procfs.h"

#include <fcntl.h>
#include <sched.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <unistd.h>

/* proc(5) field numbers of the values kept in struct ad_proc_stat. */
enum {
    F_STATE = 3, F_PPID = 4, F_MINFLT = 10, F_MAJFLT = 12, F_UTIME = 14,
    F_STIME = 15, F_PRIORITY = 18, F_NICE = 19, F_THREADS = 20, F_RSS = 24,
    F_PROCESSOR = 39, F_RTPRIO = 40, F_POLICY = 41
};

ssize_t ad_read_file(const char *path, char *buf, size_t size)
{
    int fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0)
        return -1;
    ssize_t total = 0, n = 0;
    while ((size_t)total < size - 1 &&
           (n = read(fd, buf + total, size - 1 - total)) > 0)
        total += n;
    close(fd);
    if (n < 0)
        return -1;
    buf[total] = '\0';
    return total;
}

int ad_read_line(const char *path, char *buf, size_t size)
{
    if (ad_read_file(path, buf, size) < 0)
        return -1;
    buf[strcspn(buf, "\n")] = '\0';
    return 0;
}

static void store_field(struct ad_proc_stat *o, int field, const char *tok)
{
    switch (field) {
    case F_STATE:     o->state = tok[0]; break;
    case F_PPID:      o->ppid = (pid_t)atol(tok); break;
    case F_MINFLT:    o->minflt = strtoul(tok, NULL, 10); break;
    case F_MAJFLT:    o->majflt = strtoul(tok, NULL, 10); break;
    case F_UTIME:     o->utime = strtoull(tok, NULL, 10); break;
    case F_STIME:     o->stime = strtoull(tok, NULL, 10); break;
    case F_PRIORITY:  o->priority = atol(tok); break;
    case F_NICE:      o->nice = atol(tok); break;
    case F_THREADS:   o->num_threads = atol(tok); break;
    case F_RSS:       o->rss_pages = atol(tok); break;
    case F_PROCESSOR: o->processor = atoi(tok); break;
    case F_RTPRIO:    o->rt_priority = (unsigned)strtoul(tok, NULL, 10); break;
    case F_POLICY:    o->policy = (unsigned)strtoul(tok, NULL, 10); break;
    default: break;
    }
}

int ad_parse_stat(const char *text, struct ad_proc_stat *out)
{
    /* comm may contain spaces and ')': it ends at the LAST ')'. */
    const char *open_paren = strchr(text, '(');
    const char *close_paren = strrchr(text, ')');
    if (!open_paren || !close_paren || close_paren < open_paren)
        return -1;
    memset(out, 0, sizeof(*out));
    out->pid = (pid_t)atol(text);
    size_t len = (size_t)(close_paren - open_paren - 1);
    if (len >= sizeof(out->comm))
        len = sizeof(out->comm) - 1;
    memcpy(out->comm, open_paren + 1, len);

    char rest[AD_LINE_MAX];
    snprintf(rest, sizeof(rest), "%s", close_paren + 1);
    int field = F_STATE;
    char *save = NULL;
    for (char *tok = strtok_r(rest, " \n", &save); tok;
         tok = strtok_r(NULL, " \n", &save), field++)
        store_field(out, field, tok);
    return field > F_POLICY ? 0 : -1;
}

int ad_read_proc_stat(pid_t pid, struct ad_proc_stat *out)
{
    char path[AD_PATH_MAX], buf[AD_LINE_MAX];
    snprintf(path, sizeof(path), "/proc/%d/stat", (int)pid);
    if (ad_read_file(path, buf, sizeof(buf)) < 0)
        return -1;
    return ad_parse_stat(buf, out);
}

long long ad_meminfo_value(const char *text, const char *key)
{
    size_t klen = strlen(key);
    for (const char *p = text; p && *p; p = strchr(p, '\n')) {
        if (*p == '\n')
            p++;
        if (strncmp(p, key, klen) == 0 && p[klen] == ':')
            return strtoll(p + klen + 1, NULL, 10);
    }
    return -1;
}

unsigned long long ad_cpu_total_jiffies(const char *text)
{
    if (strncmp(text, "cpu ", 4) != 0)
        return 0;
    unsigned long long total = 0;
    char *end;
    const char *p = text + 4;
    const char *eol = strchr(text, '\n');
    while (!eol || p < eol) {
        unsigned long long v = strtoull(p, &end, 10);
        if (end == p)
            break;
        total += v;
        p = end;
    }
    return total;
}

static const struct { unsigned num; const char *name; } POLICIES[] = {
    { SCHED_OTHER, "OTHER" }, { SCHED_FIFO, "FIFO" }, { SCHED_RR, "RR" },
    { SCHED_BATCH, "BATCH" }, { SCHED_IDLE, "IDLE" },
};
#define N_POLICIES (sizeof(POLICIES) / sizeof(POLICIES[0]))

const char *ad_policy_name(unsigned policy)
{
    for (size_t i = 0; i < N_POLICIES; i++)
        if (POLICIES[i].num == policy)
            return POLICIES[i].name;
    return "unknown";
}

int ad_policy_from_name(const char *name)
{
    for (size_t i = 0; i < N_POLICIES; i++)
        if (strcasecmp(POLICIES[i].name, name) == 0)
            return (int)POLICIES[i].num;
    return -1;
}
