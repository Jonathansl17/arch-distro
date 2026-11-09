/*
 * pci.c - GPU and NPU section of ad-info.
 * Walks /sys/bus/pci/devices: the class file tells what each device is
 * (0x03xxxx display controller, 0x12xxxx processing accelerator = NPU) and
 * the "driver" symlink names the kernel module bound to it. Names come from
 * the hwdata pci.ids database (a plain file, not a program).
 */
#include "procfs.h"
#include "sections.h"

#include <dirent.h>
#include <libgen.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define PCI_ROOT        "/sys/bus/pci/devices"
#define PCI_IDS         "/usr/share/hwdata/pci.ids"
#define CLASS_SHIFT     16
#define CLASS_DISPLAY   0x03
#define CLASS_ACCEL     0x12

static void read_hex(const char *dev, const char *file, unsigned long *out)
{
    char path[AD_PATH_MAX], buf[AD_COMM_MAX];
    snprintf(path, sizeof(path), "%s/%s/%s", PCI_ROOT, dev, file);
    *out = ad_read_line(path, buf, sizeof(buf)) == 0 ? strtoul(buf, NULL, 16) : 0;
}

static void driver_of(const char *dev, char *out, size_t size)
{
    char path[AD_PATH_MAX], target[AD_PATH_MAX];
    snprintf(path, sizeof(path), "%s/%s/driver", PCI_ROOT, dev);
    ssize_t n = readlink(path, target, sizeof(target) - 1);
    if (n < 0) {
        snprintf(out, size, "none (no driver bound)");
        return;
    }
    target[n] = '\0';
    snprintf(out, size, "%s", basename(target));
}

/* Device name from pci.ids: vendor lines start at column 0, devices with
 * one tab. Falls back to the numeric ids. */
static void device_name(unsigned long vendor, unsigned long device,
                        char *out, size_t size)
{
    snprintf(out, size, "%04lx:%04lx", vendor, device);
    FILE *f = fopen(PCI_IDS, "r");
    if (!f)
        return;
    char line[AD_LINE_MAX], vkey[8], dkey[8];
    snprintf(vkey, sizeof(vkey), "%04lx ", vendor);
    snprintf(dkey, sizeof(dkey), "\t%04lx", device);
    int in_vendor = 0;
    while (fgets(line, sizeof(line), f)) {
        if (line[0] != '\t' && line[0] != '#')
            in_vendor = strncmp(line, vkey, strlen(vkey)) == 0;
        else if (in_vendor && strncmp(line, dkey, strlen(dkey)) == 0) {
            snprintf(out, size, "%s", line + strlen(dkey) + 2);
            out[strcspn(out, "\n")] = '\0';
            break;
        }
    }
    fclose(f);
}

static int report_device(const char *dev)
{
    unsigned long cls, vendor, device;
    read_hex(dev, "class", &cls);
    unsigned long base = cls >> CLASS_SHIFT;
    if (base != CLASS_DISPLAY && base != CLASS_ACCEL)
        return 0;
    read_hex(dev, "vendor", &vendor);
    read_hex(dev, "device", &device);
    char name[AD_LINE_MAX], drv[AD_COMM_MAX];
    device_name(vendor, device, name, sizeof(name));
    driver_of(dev, drv, sizeof(drv));
    AD_ROW(base == CLASS_DISPLAY ? "GPU" : "NPU", "%s", name);
    AD_ROW("  driver", "%s  [%s]", drv, dev);
    return base == CLASS_ACCEL;
}

void ad_section_devices(void)
{
    DIR *d = opendir(PCI_ROOT);
    if (!d) {
        perror(PCI_ROOT);
        return;
    }
    int npus = 0;
    struct dirent *e;
    while ((e = readdir(d)))
        if (e->d_name[0] != '.')
            npus += report_device(e->d_name);
    closedir(d);
    if (npus == 0)
        AD_ROW("NPU", "not present (no PCI class 0x12 device)");
}
