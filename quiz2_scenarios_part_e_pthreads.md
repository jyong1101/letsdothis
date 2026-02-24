# Quiz 2 Predicted Scenarios — Part E: Pthreads Hash Table Modifications

> **Based on**: Lab5 `ph-with-mutex-locks.c` / `ph-without-locks.c` — Concurrent hash table
> **Quiz 1 Pattern Applied**: Extend synchronization with different primitives or data structures

---

## Scenario E1: "ph-rwlock" — Read-Write Locks

**Difficulty**: ★★★★☆ (Moderate-Hard)
**Concept Tested**: Read-write lock semantics — concurrent reads, exclusive writes

**Task Description**: Replace per-bucket mutex with `pthread_rwlock_t`. The `put()` function takes a write lock, and `get()` takes a read lock, allowing concurrent lookups.

### Code: `notxv6/ph-rwlock.c`

```c
#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include <assert.h>
#include <pthread.h>
#include <sys/time.h>

#define NBUCKET 5
#define NKEYS 100000

struct entry {
  int key;
  int value;
  struct entry *next;
};

struct entry *table[NBUCKET];
int keys[NKEYS];
int nthread = 1;

// Read-Write locks instead of mutex
pthread_rwlock_t locks[NBUCKET];

double now() {
  struct timeval tv;
  gettimeofday(&tv, 0);
  return tv.tv_sec + tv.tv_usec / 1000000.0;
}

static void insert(int key, int value, struct entry **p, struct entry *n) {
  struct entry *e = malloc(sizeof(struct entry));
  e->key = key;
  e->value = value;
  e->next = n;
  *p = e;
}

static void put(int key, int value) {
  int i = key % NBUCKET;

  // WRITE lock for modifications
  pthread_rwlock_wrlock(&locks[i]);

  struct entry *e = 0;
  for (e = table[i]; e != 0; e = e->next) {
    if (e->key == key) break;
  }
  if (e) {
    e->value = value;
  } else {
    insert(key, value, &table[i], table[i]);
  }

  pthread_rwlock_unlock(&locks[i]);
}

static struct entry* get(int key) {
  int i = key % NBUCKET;

  // READ lock for lookups — allows concurrent reads
  pthread_rwlock_rdlock(&locks[i]);

  struct entry *e = 0;
  for (e = table[i]; e != 0; e = e->next) {
    if (e->key == key) break;
  }

  pthread_rwlock_unlock(&locks[i]);
  return e;
}

static void *put_thread(void *xa) {
  int n = (int)(long)xa;
  int b = NKEYS / nthread;
  for (int i = 0; i < b; i++) {
    put(keys[b * n + i], n);
  }
  return NULL;
}

static void *get_thread(void *xa) {
  int n = (int)(long)xa;
  int missing = 0;
  for (int i = 0; i < NKEYS; i++) {
    struct entry *e = get(keys[i]);
    if (e == 0) missing++;
  }
  printf("%d: %d keys missing\n", n, missing);
  return NULL;
}

int main(int argc, char *argv[]) {
  pthread_t *tha;
  void *value;
  double t1, t0;

  if (argc < 2) {
    fprintf(stderr, "Usage: %s nthreads\n", argv[0]);
    exit(-1);
  }
  nthread = atoi(argv[1]);
  tha = malloc(sizeof(pthread_t) * nthread);

  // Initialize rwlocks
  for (int i = 0; i < NBUCKET; i++) {
    pthread_rwlock_init(&locks[i], NULL);
  }

  srandom(0);
  assert(NKEYS % nthread == 0);
  for (int i = 0; i < NKEYS; i++) {
    keys[i] = random();
  }

  t0 = now();
  for (int i = 0; i < nthread; i++) {
    assert(pthread_create(&tha[i], NULL, put_thread, (void *)(long)i) == 0);
  }
  for (int i = 0; i < nthread; i++) {
    assert(pthread_join(tha[i], &value) == 0);
  }
  t1 = now();
  printf("%d puts, %.3f seconds, %.0f puts/second\n", NKEYS, t1 - t0, NKEYS / (t1 - t0));

  for (int i = 0; i < nthread; i++) {
    assert(pthread_create(&tha[i], NULL, get_thread, (void *)(long)i) == 0);
  }
  for (int i = 0; i < nthread; i++) {
    assert(pthread_join(tha[i], &value) == 0);
  }

  for (int i = 0; i < NBUCKET; i++) {
    pthread_rwlock_destroy(&locks[i]);
  }

  return 0;
}
```

---

## Scenario E2: "ph-delete" — Thread-Safe Delete Operation

**Difficulty**: ★★★★☆ (Moderate-Hard)
**Concept Tested**: Linked list deletion under concurrency, lock granularity

**Task Description**: Add a thread-safe `delete(int key)` function to the hash table that removes an entry. Add a delete phase between put and get.

### Key Code Addition

```c
static int delete(int key) {
  int i = key % NBUCKET;

  pthread_mutex_lock(&locks[i]);

  struct entry **pp = &table[i];  // pointer to pointer for easy deletion
  struct entry *e;

  for (e = table[i]; e != 0; e = e->next) {
    if (e->key == key) {
      *pp = e->next;  // unlink the entry
      pthread_mutex_unlock(&locks[i]);
      free(e);
      return 0;  // success
    }
    pp = &e->next;
  }

  pthread_mutex_unlock(&locks[i]);
  return -1;  // key not found
}

static void *delete_thread(void *xa) {
  int n = (int)(long)xa;
  int b = NKEYS / nthread;
  int deleted = 0;

  // Delete every other key assigned to this thread
  for (int i = 0; i < b; i += 2) {
    if (delete(keys[b * n + i]) == 0)
      deleted++;
  }
  printf("%d: deleted %d keys\n", n, deleted);
  return NULL;
}
```

#### Modified `main()` — Add delete phase

```c
// Phase 2: Concurrent Deletes
t0 = now();
for (int i = 0; i < nthread; i++) {
  assert(pthread_create(&tha[i], NULL, delete_thread, (void *)(long)i) == 0);
}
for (int i = 0; i < nthread; i++) {
  assert(pthread_join(tha[i], &value) == 0);
}
t1 = now();
printf("delete phase: %.3f seconds\n", t1 - t0);

// Phase 3: Gets (verify some are missing)
for (int i = 0; i < nthread; i++) {
  assert(pthread_create(&tha[i], NULL, get_thread, (void *)(long)i) == 0);
}
for (int i = 0; i < nthread; i++) {
  assert(pthread_join(tha[i], &value) == 0);
}
```

---

## Scenario E3: "ph-condvar" — Producer-Consumer with Condition Variables

**Difficulty**: ★★★★★ (Hard)
**Concept Tested**: Condition variables, producer-consumer pattern, bounded buffer

**Task Description**: Implement a bounded buffer of size B between producer and consumer threads using `pthread_cond_t`. Producers insert keys, consumers retrieve and process them.

### Code

```c
#include <stdlib.h>
#include <stdio.h>
#include <assert.h>
#include <pthread.h>

#define BUFSIZE 10
#define NITEMS 100000

int buffer[BUFSIZE];
int count = 0;  // number of items in buffer
int in = 0;     // next write position
int out = 0;    // next read position

pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t not_full = PTHREAD_COND_INITIALIZER;
pthread_cond_t not_empty = PTHREAD_COND_INITIALIZER;

void *producer(void *arg) {
  for (int i = 0; i < NITEMS; i++) {
    pthread_mutex_lock(&mutex);

    // Wait until buffer is not full
    while (count == BUFSIZE) {
      pthread_cond_wait(&not_full, &mutex);
    }

    buffer[in] = i;
    in = (in + 1) % BUFSIZE;
    count++;

    pthread_cond_signal(&not_empty);
    pthread_mutex_unlock(&mutex);
  }
  return NULL;
}

void *consumer(void *arg) {
  int total = 0;
  for (int i = 0; i < NITEMS; i++) {
    pthread_mutex_lock(&mutex);

    // Wait until buffer is not empty
    while (count == 0) {
      pthread_cond_wait(&not_empty, &mutex);
    }

    int val = buffer[out];
    out = (out + 1) % BUFSIZE;
    count--;
    total += val;

    pthread_cond_signal(&not_full);
    pthread_mutex_unlock(&mutex);
  }
  printf("consumer total: %d\n", total);
  return NULL;
}

int main(void) {
  pthread_t prod, cons;
  pthread_create(&prod, NULL, producer, NULL);
  pthread_create(&cons, NULL, consumer, NULL);
  pthread_join(prod, NULL);
  pthread_join(cons, NULL);

  pthread_mutex_destroy(&mutex);
  pthread_cond_destroy(&not_full);
  pthread_cond_destroy(&not_empty);
  return 0;
}
```

---

## Scenario E4: "ph-barrier" — Barrier Synchronization

**Difficulty**: ★★★★☆ (Moderate-Hard)
**Concept Tested**: Barrier synchronization primitive, all threads must reach barrier before any proceed

**Task Description**: Implement a reusable barrier using `pthread_cond_t` and `pthread_mutex_t`. All threads must complete the put phase before any thread begins the get phase.

### Code

```c
struct barrier {
  pthread_mutex_t mutex;
  pthread_cond_t cond;
  int nthread;       // number of threads to wait for
  int count;         // number of threads that have arrived
  int round;         // barrier round (for reuse)
};

void
barrier_init(struct barrier *b, int nthread)
{
  pthread_mutex_init(&b->mutex, NULL);
  pthread_cond_init(&b->cond, NULL);
  b->nthread = nthread;
  b->count = 0;
  b->round = 0;
}

void
barrier_wait(struct barrier *b)
{
  pthread_mutex_lock(&b->mutex);
  int my_round = b->round;
  b->count++;

  if (b->count == b->nthread) {
    // Last thread to arrive: reset and wake all
    b->count = 0;
    b->round++;
    pthread_cond_broadcast(&b->cond);
  } else {
    // Wait until this round is over
    while (b->round == my_round) {
      pthread_cond_wait(&b->cond, &b->mutex);
    }
  }

  pthread_mutex_unlock(&b->mutex);
}

void
barrier_destroy(struct barrier *b)
{
  pthread_mutex_destroy(&b->mutex);
  pthread_cond_destroy(&b->cond);
}
```

#### Usage in Hash Table

```c
struct barrier bar;

static void *worker_thread(void *xa) {
  int n = (int)(long)xa;
  int b = NKEYS / nthread;

  // Phase 1: Puts
  for (int i = 0; i < b; i++) {
    put(keys[b * n + i], n);
  }

  // Barrier: wait for all threads to finish putting
  barrier_wait(&bar);

  // Phase 2: Gets
  int missing = 0;
  for (int i = 0; i < NKEYS; i++) {
    struct entry *e = get(keys[i]);
    if (e == 0) missing++;
  }
  printf("%d: %d keys missing\n", n, missing);
  return NULL;
}

int main(int argc, char *argv[]) {
  // ...
  barrier_init(&bar, nthread);

  for (int i = 0; i < nthread; i++) {
    pthread_create(&tha[i], NULL, worker_thread, (void *)(long)i);
  }
  for (int i = 0; i < nthread; i++) {
    pthread_join(tha[i], NULL);
  }

  barrier_destroy(&bar);
  return 0;
}
```

---

## Scenario E5: "ph-global-lock" — Single Global Lock (Baseline)

**Difficulty**: ★★☆☆☆ (Easy)
**Concept Tested**: Simplest correct synchronization (but poor parallelism)

**Task Description**: Fix the race condition using a SINGLE global mutex instead of per-bucket locks. This is simpler but slower.

### Code

```c
// Single global lock
pthread_mutex_t global_lock;

static void put(int key, int value) {
  int i = key % NBUCKET;

  // Lock the entire table
  pthread_mutex_lock(&global_lock);

  struct entry *e = 0;
  for (e = table[i]; e != 0; e = e->next) {
    if (e->key == key) break;
  }
  if (e) {
    e->value = value;
  } else {
    insert(key, value, &table[i], table[i]);
  }

  pthread_mutex_unlock(&global_lock);
}

int main(int argc, char *argv[]) {
  // ...
  pthread_mutex_init(&global_lock, NULL);
  // ... create threads, join, etc.
  pthread_mutex_destroy(&global_lock);
  return 0;
}
```

> **Discussion point**: This will pass the safety test (0 missing keys) but will FAIL the speed test (ph_fast) because it serializes all put operations, preventing any parallelism.
