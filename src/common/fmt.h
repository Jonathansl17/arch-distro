/* fmt.h - human-readable formatting shared by ad-* commands. */
#ifndef AD_FMT_H
#define AD_FMT_H

#include <stddef.h>

/* Writes kib as "512 KiB", "3.4 MiB", "1.2 GiB" into buf. */
void ad_fmt_kib(long long kib, char *buf, size_t size);

/* Writes seconds as "2d 3h 4m" / "3h 4m" / "4m 5s" into buf. */
void ad_fmt_duration(long long seconds, char *buf, size_t size);

#endif
