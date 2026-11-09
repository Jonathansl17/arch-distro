/* fs.c - root file system section of ad-info (statfs + /proc/self/mounts). */
#include "fmt.h"
#include "procfs.h"
#include "sections.h"

#include <mntent.h>
#include <stdio.h>
#include <string.h>
#include <sys/statvfs.h>

#define BYTES_PER_KIB 1024ULL

static void mount_entry(void)
{
    FILE *f = setmntent("/proc/self/mounts", "r");
    if (!f) {
        perror("/proc/self/mounts");
        return;
    }
    struct mntent *m;
    char dev[AD_PATH_MAX] = "", type[AD_COMM_MAX] = "", opts[AD_LINE_MAX] = "";
    /* The last "/" entry wins: it is the one stacked on top. */
    while ((m = getmntent(f)))
        if (strcmp(m->mnt_dir, "/") == 0) {
            snprintf(dev, sizeof(dev), "%s", m->mnt_fsname);
            snprintf(type, sizeof(type), "%s", m->mnt_type);
            snprintf(opts, sizeof(opts), "%s", m->mnt_opts);
        }
    endmntent(f);
    AD_ROW("Type", "%s on %s", type, dev);
    AD_ROW("Options", "%s", opts);
}

void ad_section_rootfs(void)
{
    struct statvfs s;
    mount_entry();
    if (statvfs("/", &s) != 0) {
        perror("statvfs /");
        return;
    }
    unsigned long long total = s.f_blocks * s.f_frsize / BYTES_PER_KIB;
    unsigned long long avail = s.f_bavail * s.f_frsize / BYTES_PER_KIB;
    char a[32], b[32];
    ad_fmt_kib((long long)(total - avail), a, sizeof(a));
    ad_fmt_kib((long long)total, b, sizeof(b));
    AD_ROW("Usage", "%s used / %s", a, b);
}
