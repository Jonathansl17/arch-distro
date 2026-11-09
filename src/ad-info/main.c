/*
 * ad-info - mandatory system report of arch-distro (Capa 3).
 * Every value comes from /proc, /sys or a system call (uname, sysinfo,
 * statvfs, sched_getscheduler); no external program is executed.
 */
#include "sections.h"

#include <stdio.h>
#include <string.h>

#define AD_DISTRO_NAME "arch-distro"

static void header(const char *title)
{
    printf("\033[1;36m%s\033[0m\n", title);
}

static void usage(const char *prog)
{
    printf("usage: %s [-h]\n"
           "System report read from /proc, /sys and system calls.\n", prog);
}

int main(int argc, char **argv)
{
    if (argc > 1) {
        usage(argv[0]);
        return strcmp(argv[1], "-h") == 0 ? 0 : 2;
    }
    printf("\033[1;35m%s\033[0m\n", AD_DISTRO_NAME);
    header("System");
    ad_section_system();
    header("CPU");
    ad_section_cpu();
    header("Accelerators");
    ad_section_devices();
    header("Memory");
    ad_section_memory();
    header("Processes");
    ad_section_processes();
    header("Root file system");
    ad_section_rootfs();
    return 0;
}
