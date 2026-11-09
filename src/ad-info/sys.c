/* sys.c - kernel, uptime, scheduler and CPU sections of ad-info. */
#include "fmt.h"
#include "procfs.h"
#include "sections.h"

#include <sched.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/utsname.h>
#include <unistd.h>

/* EEVDF replaced CFS as the fair scheduler in Linux 6.6. */
#define EEVDF_MAJOR 6
#define EEVDF_MINOR 6
#define SCHED_EXT_STATE "/sys/kernel/sched_ext/state"
#define SCHED_EXT_OPS   "/sys/kernel/sched_ext/root/ops"
#define AUTOGROUP_PATH  "/proc/sys/kernel/sched_autogroup_enabled"

static const char *fair_scheduler(const char *release)
{
    int major = 0, minor = 0;
    if (sscanf(release, "%d.%d", &major, &minor) != 2)
        return "unknown";
    if (major > EEVDF_MAJOR || (major == EEVDF_MAJOR && minor >= EEVDF_MINOR))
        return "EEVDF";
    return "CFS";
}

static void print_scheduler(const char *release)
{
    char state[AD_COMM_MAX] = "", ops[AD_COMM_MAX] = "", autogroup[8] = "?";
    ad_read_line(AUTOGROUP_PATH, autogroup, sizeof(autogroup));
    if (ad_read_line(SCHED_EXT_STATE, state, sizeof(state)) == 0 &&
        strcmp(state, "enabled") == 0) {
        ad_read_line(SCHED_EXT_OPS, ops, sizeof(ops));
        AD_ROW("Scheduler", "sched_ext (%s) over %s", ops,
               fair_scheduler(release));
    } else {
        AD_ROW("Scheduler", "%s, autogroup=%s, this shell: SCHED_%s",
               fair_scheduler(release), autogroup,
               ad_policy_name((unsigned)sched_getscheduler(0)));
    }
}

void ad_section_system(void)
{
    struct utsname u;
    char buf[AD_LINE_MAX], up[AD_COMM_MAX];
    if (uname(&u) != 0) {
        perror("uname");
        return;
    }
    AD_ROW("Host", "%s", u.nodename);
    AD_ROW("Kernel", "%s %s (%s)", u.sysname, u.release, u.machine);
    if (ad_read_line("/proc/uptime", buf, sizeof(buf)) == 0) {
        ad_fmt_duration(atoll(buf), up, sizeof(up));
        AD_ROW("Uptime", "%s", up);
    }
    print_scheduler(u.release);
}

static void cpu_model(char *out, size_t size)
{
    static char text[1 << 16];
    snprintf(out, size, "unknown");
    if (ad_read_file("/proc/cpuinfo", text, sizeof(text)) < 0)
        return;
    char *line = strstr(text, "model name");
    if (!line)
        return;
    char *colon = strchr(line, ':');
    if (!colon)
        return;
    snprintf(out, size, "%s", colon + 2);
    out[strcspn(out, "\n")] = '\0';
}

void ad_section_cpu(void)
{
    char model[AD_LINE_MAX], gov[AD_COMM_MAX] = "n/a";
    cpu_model(model, sizeof(model));
    ad_read_line("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor",
                 gov, sizeof(gov));
    AD_ROW("Model", "%s", model);
    AD_ROW("Cores", "%ld online / %ld configured",
           sysconf(_SC_NPROCESSORS_ONLN), sysconf(_SC_NPROCESSORS_CONF));
    AD_ROW("Governor", "%s", gov);
}
