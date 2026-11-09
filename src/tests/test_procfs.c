/* Unit tests for common/procfs.c and common/fmt.c. Run: make test */
#include "fmt.h"
#include "procfs.h"

#include <sched.h>
#include <stdio.h>
#include <string.h>

static int failures;

#define CHECK(cond)                                                     \
    do {                                                                \
        if (!(cond)) {                                                  \
            fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond); \
            failures++;                                                 \
        }                                                               \
    } while (0)

/* Real /proc/<pid>/stat line, comm with spaces and a ')' inside. */
static const char *STAT_LINE =
    "4242 (my (weird) proc) R 1 4242 4242 0 -1 4194304 150 0 7 0 "
    "120 30 0 0 20 -5 3 0 9000 123456 789 18446744073709551615 "
    "1 1 0 0 0 0 0 0 0 0 0 0 17 2 0 0 0 0 0\n";

static void test_parse_stat(void)
{
    struct ad_proc_stat s;
    CHECK(ad_parse_stat(STAT_LINE, &s) == 0);
    CHECK(s.pid == 4242);
    CHECK(strcmp(s.comm, "my (weird) proc") == 0);
    CHECK(s.state == 'R');
    CHECK(s.ppid == 1);
    CHECK(s.minflt == 150);
    CHECK(s.majflt == 7);
    CHECK(s.utime == 120 && s.stime == 30);
    CHECK(s.nice == -5);
    CHECK(s.num_threads == 3);
    CHECK(s.rss_pages == 789);
    CHECK(s.processor == 2);
    CHECK(s.policy == SCHED_OTHER);
}

static void test_parse_stat_rejects_garbage(void)
{
    struct ad_proc_stat s;
    CHECK(ad_parse_stat("not a stat line", &s) == -1);
    CHECK(ad_parse_stat("1 (short) S 0 1", &s) == -1);
}

static void test_meminfo(void)
{
    const char *mi = "MemTotal:  8000 kB\nMemFree:  100 kB\nSwapTotal: 0 kB\n";
    CHECK(ad_meminfo_value(mi, "MemTotal") == 8000);
    CHECK(ad_meminfo_value(mi, "MemFree") == 100);
    CHECK(ad_meminfo_value(mi, "SwapTotal") == 0);
    CHECK(ad_meminfo_value(mi, "Mem") == -1);
    CHECK(ad_meminfo_value(mi, "Missing") == -1);
}

static void test_cpu_jiffies(void)
{
    CHECK(ad_cpu_total_jiffies("cpu  1 2 3 4\ncpu0 9 9\n") == 10);
    CHECK(ad_cpu_total_jiffies("intr 1 2\n") == 0);
}

static void test_policies(void)
{
    CHECK(ad_policy_from_name("fifo") == SCHED_FIFO);
    CHECK(ad_policy_from_name("idle") == SCHED_IDLE);
    CHECK(ad_policy_from_name("RR") == SCHED_RR);
    CHECK(ad_policy_from_name("nope") == -1);
    CHECK(strcmp(ad_policy_name(SCHED_RR), "RR") == 0);
    CHECK(strcmp(ad_policy_name(99), "unknown") == 0);
}

static void test_fmt(void)
{
    char buf[32];
    ad_fmt_kib(512, buf, sizeof(buf));
    CHECK(strcmp(buf, "512 KiB") == 0);
    ad_fmt_kib(2048, buf, sizeof(buf));
    CHECK(strcmp(buf, "2.0 MiB") == 0);
    ad_fmt_kib(-1, buf, sizeof(buf));
    CHECK(strcmp(buf, "n/a") == 0);
    ad_fmt_duration(90061, buf, sizeof(buf));
    CHECK(strcmp(buf, "1d 1h 1m") == 0);
    ad_fmt_duration(65, buf, sizeof(buf));
    CHECK(strcmp(buf, "1m 5s") == 0);
}

int main(void)
{
    test_parse_stat();
    test_parse_stat_rejects_garbage();
    test_meminfo();
    test_cpu_jiffies();
    test_policies();
    test_fmt();
    if (failures) {
        fprintf(stderr, "%d check(s) failed\n", failures);
        return 1;
    }
    puts("test-procfs: all checks passed");
    return 0;
}
