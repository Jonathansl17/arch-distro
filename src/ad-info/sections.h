/* sections.h - each function prints one block of ad-info output. */
#ifndef AD_INFO_SECTIONS_H
#define AD_INFO_SECTIONS_H

/* Label column width shared by every section so values line up. */
#define AD_LABEL_WIDTH 12
#define AD_ROW(label, ...)                                   \
    do {                                                     \
        printf("  %-*s ", AD_LABEL_WIDTH, label);            \
        printf(__VA_ARGS__);                                 \
        putchar('\n');                                       \
    } while (0)

void ad_section_system(void);     /* sys.c:   kernel, uptime, scheduler */
void ad_section_cpu(void);        /* sys.c:   model, cores */
void ad_section_devices(void);    /* pci.c:   GPU and NPU with driver */
void ad_section_memory(void);     /* mem.c:   RAM, swap devices, zram */
void ad_section_processes(void);  /* mem.c:   process counts */
void ad_section_rootfs(void);     /* fs.c:    root file system */

#endif
