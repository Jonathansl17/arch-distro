/* worker.c - producer and consumer loops of ad-ipc. */
#include "ipc.h"

#include <fcntl.h>
#include <ftw.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define READ_CHUNK 65536
#define NFTW_OPEN_FDS 16
#define MS_PER_SEC 1000
#define NS_PER_MS 1000000L

static struct ring *g_ring;  /* nftw callbacks take no user pointer */

static int push_file(const char *path, const struct stat *sb, int type,
                     struct FTW *ftw)
{
    (void)ftw;
    if (type != FTW_F || strlen(path) >= SLOT_PATH_MAX || access(path, R_OK) != 0)
        return 0;  /* skip dirs, unreadable files and paths too long for a slot */
    if (ring_push(g_ring, path) != 0)
        return 1;  /* SIGTERM: stop the walk */
    g_ring->expected_files++;
    g_ring->expected_bytes += sb->st_size;
    return 0;
}

void run_producer(struct ring *r, const char *dir, int consumers)
{
    g_ring = r;
    if (nftw(dir, push_file, NFTW_OPEN_FDS, FTW_PHYS) < 0)
        perror(dir);
    /* One empty path per consumer = "no more work" (poison pill). */
    for (int i = 0; i < consumers && !g_stop; i++)
        ring_push(r, "");
    r->producer_done = 1;
}

static int count_file(const char *path, long *lines, long *bytes)
{
    static char buf[READ_CHUNK];
    int fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0)
        return -1;
    ssize_t n;
    *lines = *bytes = 0;
    while ((n = read(fd, buf, sizeof(buf))) > 0) {
        *bytes += n;
        for (ssize_t i = 0; i < n; i++)
            *lines += buf[i] == '\n';
    }
    close(fd);
    return n < 0 ? -1 : 0;
}

static void simulate_work(int ms)
{
    if (ms <= 0)
        return;
    struct timespec ts = { ms / MS_PER_SEC, (ms % MS_PER_SEC) * NS_PER_MS };
    nanosleep(&ts, NULL);
}

void run_consumer(struct ring *r, int result_fd)
{
    char path[SLOT_PATH_MAX], line[PIPE_BUF];
    while (!g_stop && ring_pop(r, path) == 0) {
        if (path[0] == '\0')
            break;  /* poison pill */
        long lines = -1, bytes = -1;  /* -1 -1 = file vanished meanwhile */
        count_file(path, &lines, &bytes);
        simulate_work(r->slow_ms);
        /* One write < PIPE_BUF is atomic: lines from several consumers never
         * interleave inside the pipe. */
        int len = snprintf(line, sizeof(line), "%ld %ld %s\n", lines, bytes, path);
        if (write(result_fd, line, (size_t)len) != len)
            break;
    }
}
