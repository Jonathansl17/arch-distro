/*
 * ipc.h - ad-ipc (theme 5): parallel line/byte counter over a directory tree.
 *
 * Processes and IPC mechanisms:
 *   producer (1 child)   walks DIR, pushes file paths into the ring
 *   consumers (N kids)   pop paths, count lines/bytes, write results to a pipe
 *   parent               reads the pipe, aggregates totals, reaps children
 *
 *   1. POSIX shared memory (shm_open + mmap): bounded ring buffer of paths
 *   2. Process-shared semaphores inside that memory: empty / full / mutex
 *   3. Anonymous pipe: consumers -> parent results (writes < PIPE_BUF are atomic)
 *   4. Signals: SIGTERM = orderly shutdown, SIGCHLD = reap, no zombies
 */
#ifndef AD_IPC_H
#define AD_IPC_H

#include <semaphore.h>
#include <signal.h>

#define RING_SLOTS 16
#define SLOT_PATH_MAX 256
#define DEFAULT_CONSUMERS 3
#define SHM_NAME_FMT "/ad-ipc-%d"
/* A consumer that waits this long after the producer finished gives up:
 * in --unsafe mode a poison pill can be lost and it would block forever. */
#define IDLE_TIMEOUT_MS 500

struct ring {
    sem_t mutex;          /* guards head/tail/counters */
    sem_t empty;          /* free slots */
    sem_t full;           /* filled slots */
    unsigned head, tail;
    unsigned produced, consumed;
    unsigned expected_files;       /* written only by the single producer */
    long long expected_bytes;      /* sum of st_size of pushed files */
    volatile int producer_done;    /* set after the poison pills */
    int unsafe;           /* 1 = skip the mutex to show the race */
    int slow_ms;          /* artificial work per item (for demos) */
    char slots[RING_SLOTS][SLOT_PATH_MAX];
};

/* Set by the SIGTERM handler in every process. */
extern volatile sig_atomic_t g_stop;

/* ring.c */
struct ring *ring_create(const char *name, int unsafe, int slow_ms);
void ring_destroy(struct ring *r, const char *name);
int ring_push(struct ring *r, const char *path);  /* 0 ok, -1 stopped */
int ring_pop(struct ring *r, char *out);           /* 0 ok, -1 stopped */

/* worker.c */
void run_producer(struct ring *r, const char *dir, int consumers);
void run_consumer(struct ring *r, int result_fd);

#endif
