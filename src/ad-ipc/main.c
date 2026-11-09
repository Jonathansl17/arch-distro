/*
 * ad-ipc - parallel `wc -l -c` over a directory tree (theme 5).
 *
 *   ad-ipc [-w CONSUMERS] [-s SLOW_MS] [--unsafe] DIR
 *
 * Exit 0 when every produced path was consumed exactly once, 3 when the
 * counters disagree (expected with --unsafe), 1 on errors, 130 on SIGTERM.
 */
#include "ipc.h"

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#define EXIT_MISMATCH 3
#define EXIT_TERMINATED 130
#define NAME_LEN 64
#define MAX_CONSUMERS 64

volatile sig_atomic_t g_stop;
static volatile sig_atomic_t g_reaped;
static pid_t g_children[MAX_CONSUMERS + 1];
static int g_n_children;

static void on_term(int sig) { (void)sig; g_stop = 1; }

static void on_chld(int sig)
{
    (void)sig;
    int saved = errno;  /* waitpid may clobber errno of interrupted code */
    while (waitpid(-1, NULL, WNOHANG) > 0)
        g_reaped++;
    errno = saved;
}

static void install_handlers(void)
{
    struct sigaction sa = { 0 };
    sa.sa_handler = on_term;  /* no SA_RESTART: sem_wait must see EINTR */
    sigaction(SIGTERM, &sa, NULL);
    sigaction(SIGINT, &sa, NULL);
    sa.sa_handler = on_chld;
    sa.sa_flags = SA_RESTART | SA_NOCLDSTOP;
    sigaction(SIGCHLD, &sa, NULL);
}

/* Signals only our own children: kill(0, ...) would also hit the shell or
 * script that launched us, since it shares our process group. */
static void stop_children(void)
{
    for (int i = 0; i < g_n_children; i++)
        kill(g_children[i], SIGTERM);
}

static pid_t spawn(struct ring *r, int fds[2], const char *dir, int consumers)
{
    pid_t pid = fork();
    if (pid > 0)
        g_children[g_n_children++] = pid;
    if (pid != 0)
        return pid;  /* parent, or -1 on error */
    close(fds[0]);
    if (dir) {
        close(fds[1]);
        run_producer(r, dir, consumers);
    } else {
        run_consumer(r, fds[1]);
    }
    _exit(0);
}

/* Reads "lines bytes path" rows until every writer closed the pipe. */
static unsigned aggregate(int fd, long *lines, long *bytes)
{
    FILE *in = fdopen(fd, "r");
    char row[SLOT_PATH_MAX * 2];
    unsigned results = 0;
    long l, b;
    while (in && fgets(row, sizeof(row), in))
        if (sscanf(row, "%ld %ld", &l, &b) == 2) {
            results++;
            if (l >= 0) {
                *lines += l;
                *bytes += b;
            }
        }
    if (in)
        fclose(in);
    return results;
}

static int parse(int argc, char **argv, int *workers, int *slow, int *unsafe)
{
    int i = 1;
    for (; i < argc - 1; i++) {
        if (strcmp(argv[i], "-w") == 0) *workers = atoi(argv[++i]);
        else if (strcmp(argv[i], "-s") == 0) *slow = atoi(argv[++i]);
        else if (strcmp(argv[i], "--unsafe") == 0) *unsafe = 1;
        else return -1;
    }
    return i == argc - 1 && *workers > 0 && *workers <= MAX_CONSUMERS ? i : -1;
}

int main(int argc, char **argv)
{
    int workers = DEFAULT_CONSUMERS, slow = 0, unsafe = 0, fds[2];
    int dir_arg = parse(argc, argv, &workers, &slow, &unsafe);
    if (dir_arg < 0) {
        fputs("usage: ad-ipc [-w CONSUMERS] [-s SLOW_MS] [--unsafe] DIR\n", stderr);
        return 2;
    }
    char name[NAME_LEN];
    snprintf(name, sizeof(name), SHM_NAME_FMT, (int)getpid());
    struct ring *r = ring_create(name, unsafe, slow);
    if (!r || pipe(fds) != 0)
        return 1;
    install_handlers();
    for (int i = 0; i <= workers; i++)
        if (spawn(r, fds, i == 0 ? argv[dir_arg] : NULL, workers) < 0) {
            perror("fork");
            g_stop = 1;
            stop_children();
            break;
        }
    close(fds[1]);  /* parent only reads: EOF once all consumers exit */

    long lines = 0, bytes = 0;
    unsigned results = aggregate(fds[0], &lines, &bytes);
    if (g_stop)
        stop_children();
    while (waitpid(-1, NULL, 0) > 0 || errno == EINTR)
        g_reaped++;
    printf("files=%u results=%u bytes=%ld expected_bytes=%lld lines=%ld "
           "consumers=%d reaped=%d%s\n", r->expected_files, results, bytes,
           r->expected_bytes, lines, workers, (int)g_reaped,
           unsafe ? " (unsafe)" : "");
    int ok = results == r->expected_files && bytes == r->expected_bytes;
    ring_destroy(r, name);
    return g_stop ? EXIT_TERMINATED : ok ? 0 : EXIT_MISMATCH;
}
