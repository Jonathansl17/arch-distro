/* ring.c - bounded buffer in POSIX shared memory (classic producer/consumer). */
#include "ipc.h"

#include <errno.h>
#include <fcntl.h>
#include <sched.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

#define SEM_SHARED_BETWEEN_PROCESSES 1

struct ring *ring_create(const char *name, int unsafe, int slow_ms)
{
    int fd = shm_open(name, O_CREAT | O_EXCL | O_RDWR, 0600);
    if (fd < 0) {
        perror("shm_open");
        return NULL;
    }
    if (ftruncate(fd, sizeof(struct ring)) != 0) {
        perror("ftruncate");
        close(fd);
        shm_unlink(name);
        return NULL;
    }
    struct ring *r = mmap(NULL, sizeof(*r), PROT_READ | PROT_WRITE,
                          MAP_SHARED, fd, 0);
    close(fd);  /* the mapping keeps the object alive */
    if (r == MAP_FAILED) {
        perror("mmap");
        shm_unlink(name);
        return NULL;
    }
    memset(r, 0, sizeof(*r));
    sem_init(&r->mutex, SEM_SHARED_BETWEEN_PROCESSES, 1);
    sem_init(&r->empty, SEM_SHARED_BETWEEN_PROCESSES, RING_SLOTS);
    sem_init(&r->full, SEM_SHARED_BETWEEN_PROCESSES, 0);
    r->unsafe = unsafe;
    r->slow_ms = slow_ms;
    return r;
}

void ring_destroy(struct ring *r, const char *name)
{
    sem_destroy(&r->mutex);
    sem_destroy(&r->empty);
    sem_destroy(&r->full);
    munmap(r, sizeof(*r));
    shm_unlink(name);
}

#define NS_PER_MS 1000000L
#define NS_PER_SEC 1000000000L

static struct timespec deadline_in(int ms)
{
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    ts.tv_nsec += (long)ms * NS_PER_MS;
    ts.tv_sec += ts.tv_nsec / NS_PER_SEC;
    ts.tv_nsec %= NS_PER_SEC;
    return ts;
}

/* sem_wait that gives up on SIGTERM (EINTR + g_stop) or, for consumers,
 * when the producer is done and nothing arrives within IDLE_TIMEOUT_MS. */
static int wait_or_stop(struct ring *r, sem_t *s)
{
    for (;;) {
        struct timespec ts = deadline_in(IDLE_TIMEOUT_MS);
        if (sem_timedwait(s, &ts) == 0)
            return 0;
        if (g_stop || (errno != EINTR && errno != ETIMEDOUT))
            return -1;
        if (errno == ETIMEDOUT && r->producer_done && s == &r->full)
            return -1;
    }
}

static void lock(struct ring *r)
{
    if (!r->unsafe)
        while (sem_wait(&r->mutex) != 0 && errno == EINTR)
            ;  /* the critical section is short: always finish it */
}

static void unlock(struct ring *r)
{
    if (!r->unsafe)
        sem_post(&r->mutex);
}

int ring_push(struct ring *r, const char *path)
{
    if (wait_or_stop(r, &r->empty) != 0)
        return -1;
    lock(r);
    snprintf(r->slots[r->head], SLOT_PATH_MAX, "%s", path);
    r->head = (r->head + 1) % RING_SLOTS;
    r->produced++;
    unlock(r);
    sem_post(&r->full);
    return 0;
}

int ring_pop(struct ring *r, char *out)
{
    if (wait_or_stop(r, &r->full) != 0)
        return -1;
    lock(r);
    unsigned t = r->tail;
    if (r->unsafe)
        sched_yield();  /* widen the window so the race shows up */
    memcpy(out, r->slots[t], SLOT_PATH_MAX);
    r->tail = (t + 1) % RING_SLOTS;
    r->consumed++;
    unlock(r);
    sem_post(&r->empty);
    return 0;
}
