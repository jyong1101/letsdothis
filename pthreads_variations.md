# Pthreads (Hash Table) Variations Reference
**Context:** ICT1012 OS Quiz 2 prep.
**Base File:** `notxv6/ph-with-mutex-locks.c`

## Table of Contents
1. [Context Switch Flow](#context-switch-flow-conceptual)
2. [Baseline Boilerplate: ph.c](#core-boilerplate-ph-with-mutex-locksc)
3. [Pattern A: Logic Twists (P1-P11)](#pattern-a--logic-twists-p1p11)
4. [Pattern B: Feature Extensions (P12-P22)](#pattern-b--feature-extensions-p12p22)

---

## Context Switch Flow (Conceptual)
Pthreads conceptually behave like multiple executions of the same code sharing a single process space.
```text
           [Global Heap/Data]                  
             /            \                    
    [Thread 1 Stack]    [Thread 2 Stack]       
          |                  |                 
pthread_mutex_lock()         |                 
          |          pthread_mutex_lock() <-- (Blocks!)
     modify bucket           |                 
pthread_mutex_unlock()       |                 
          |             (Unblocks)             
          |            modify bucket           
          |          pthread_mutex_unlock()    
```

---

## Core Boilerplate: ph-with-mutex-locks.c
> **Goal:** Copy-paste this strictly as the baseline. The variations will tell you exactly what to put into each `[DROP ZONE]`.

```c
#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include <assert.h>
#include <pthread.h>
#include <sys/time.h>

#define NBUCKET 5
#define NKEYS 100000

// ════════ MODIFY HERE [HASH TABLE STRUCT] ════════
struct entry {
  int key;
  int value;
  struct entry *next;
};

struct entry *table[NBUCKET];
int keys[NKEYS];
int nthread = 1;

pthread_mutex_t locks[NBUCKET];
// ═════════════════════════════════════════════════

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
  // ════════ MODIFY HERE [PUT FUNCTION] ════════
  int i = key % NBUCKET;
  
  pthread_mutex_lock(&locks[i]);

  struct entry *e = 0;
  for (e = table[i]; e != 0; e = e->next) {
    if (e->key == key) break;
  }
  if (e) {
    e->value = value; // update in place
  } else {
    insert(key, value, &table[i], table[i]);
  }

  pthread_mutex_unlock(&locks[i]);
  // ════════════════════════════════════════════
}

static struct entry* get(int key) {
  // ════════ MODIFY HERE [GET FUNCTION] ════════
  int i = key % NBUCKET;
  struct entry *e = 0;
  for (e = table[i]; e != 0; e = e->next) {
    if (e->key == key) break;
  }
  return e;
  // ════════════════════════════════════════════
}

static void *put_thread(void *xa) {
  int n = (int) (long) xa;
  int b = NKEYS/nthread;
  for (int i = 0; i < b; i++) {
    put(keys[b*n + i], n);
  }
  return NULL;
}

static void *get_thread(void *xa) {
  int n = (int) (long) xa;
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
  
  // ════════ MODIFY HERE [MAIN SETUP] ════════
  for (int i = 0; i < NBUCKET; i++) {
    pthread_mutex_init(&locks[i], NULL);
  }
  // ══════════════════════════════════════════

  srandom(0);
  assert(NKEYS % nthread == 0);
  for (int i = 0; i < NKEYS; i++) {
    keys[i] = random();
  }

  // Phase 1: Puts
  t0 = now();
  for(int i = 0; i < nthread; i++) {
    assert(pthread_create(&tha[i], NULL, put_thread, (void *) (long) i) == 0);
  }
  for(int i = 0; i < nthread; i++) {
    assert(pthread_join(tha[i], &value) == 0);
  }
  t1 = now();
  printf("%d puts, %.3f seconds, %.0f puts/second\n", NKEYS, t1 - t0, NKEYS / (t1 - t0));

  // Phase 2: Gets
  for(int i = 0; i < nthread; i++) {
    assert(pthread_create(&tha[i], NULL, get_thread, (void *) (long) i) == 0);
  }
  for(int i = 0; i < nthread; i++) {
    assert(pthread_join(tha[i], &value) == 0);
  }

  // [MAIN SETUP continued - cleanup]
  for (int i = 0; i < NBUCKET; i++) {
    pthread_mutex_destroy(&locks[i]);
  }
  // ══════════════════════════════════════════

  return 0;       
}
```

---
---

# Pattern A — Logic Twists (P1–P11)

> **Scope**: Changes to hashing algorithms, list management (sorted, LRU), and structural behaviors. 

---

## P1: Knuth Multiplicative Hash
> Use a stronger hash function for better distribution over the buckets to reduce collision chain lengths.

**[PUT FUNCTION] & [GET FUNCTION]:**
```c
// Replace int i = key % NBUCKET; with:
unsigned int hash = (unsigned int)key * 2654435761u;
int i = hash % NBUCKET;
```

---

## P2: Update-in-place
> Instead of inserting duplicates (which wastes memory), update the existing entry value. *Note: this is already the behavior in xv6's ph-with-mutex-locks.c baseline.*

**[PUT FUNCTION]:**
```c
  if (e) {
    e->value = value; // UPDATE IN PLACE
  } else {
    insert(key, value, &table[i], table[i]);
  }
```

---

## P3: Sorted Insertion
> Maintain the linked list in the bucket in ascending order by key. This speeds up misses in `get()`.

**[PUT FUNCTION]:**
```c
  int i = key % NBUCKET;
  pthread_mutex_lock(&locks[i]);

  struct entry **curr = &table[i];
  while (*curr != 0 && (*curr)->key < key) {
    curr = &(*curr)->next;
  }
  
  if (*curr != 0 && (*curr)->key == key) {
    (*curr)->value = value;
  } else {
    struct entry *e = malloc(sizeof(struct entry));
    e->key = key;
    e->value = value;
    e->next = *curr;
    *curr = e;
  }

  pthread_mutex_unlock(&locks[i]);
```

---

## P4: Hash Table Resize
> Track entries per bucket. If a bucket exceeds 100 entries, abort and print an error (or dynamically resize if requested, though resizing a concurrent hash table is extremely difficult under fine-grained locks). *This snippet shows detection without full rehash*.

**[HASH TABLE STRUCT]:**
```c
int bucket_counts[NBUCKET] = {0};
```

**[PUT FUNCTION]:**
```c
  if (!e) {
    insert(key, value, &table[i], table[i]);
    bucket_counts[i]++;
    if (bucket_counts[i] > 100) {
      printf("Warning LIMIT REACHED on bucket %d\n", i);
    }
  }
```

---

## P5: LRU Eviction
> When an item is accessed in `get()`, move it to the front of the bucket list. **Crucial:** `get()` is no longer read-only and requires bucket locks!

**[GET FUNCTION]:**
```c
  int i = key % NBUCKET;
  struct entry *e = 0;
  
  pthread_mutex_lock(&locks[i]); // MUST LOCK FOR LRU
  
  struct entry **curr = &table[i];
  while (*curr != 0) {
    if ((*curr)->key == key) {
      e = *curr;
      // Remove from current position
      *curr = e->next;
      // Insert at head
      e->next = table[i];
      table[i] = e;
      break;
    }
    curr = &(*curr)->next;
  }
  
  pthread_mutex_unlock(&locks[i]);
  return e;
```

---

## P6: Count-based Get
> Instead of mapping key→value, track how many times `put` is called for a given key. `get` returns that frequency count.

**[PUT FUNCTION]:**
```c
  if (e) {
    e->value++; // Increment insertion count
  } else {
    insert(key, 1, &table[i], table[i]);
  }
```

**[GET FUNCTION]:**
```c
// Change return type to int! `static int get_count(int key)`
  // ... loop logic
  if (e) return e->value;
  return 0; // 0 insertions
```

---

## P7: Batch Insert
> Add a new wrapper function to acquire a bucket lock once, insert multiple keys, and release. Limits lock overhead.

**[PUT FUNCTION] (Additional function):**
```c
static void put_batch(int *batch_keys, int *batch_values, int count, int target_bucket) {
  pthread_mutex_lock(&locks[target_bucket]);
  
  for (int k = 0; k < count; k++) {
    struct entry *e = 0;
    for (e = table[target_bucket]; e != 0; e = e->next) {
      if (e->key == batch_keys[k]) break;
    }
    if (e) e->value = batch_values[k];
    else insert(batch_keys[k], batch_values[k], &table[target_bucket], table[target_bucket]);
  }
  
  pthread_mutex_unlock(&locks[target_bucket]);
}
```

---

## P8: Open Addressing (Concept)
> Replace `struct entry* table[]` with a flat array of structs and use linear probing. 

**[HASH TABLE STRUCT]:**
```c
struct entry { int key; int value; int in_use; };
struct entry table[NBUCKET]; // Flat array
// Note: Requires a global lock or finer-grained index locking.
pthread_mutex_t global_lock = PTHREAD_MUTEX_INITIALIZER;
```

---

## P9: String Values
> Values are strings requiring `strcpy` inside the critical section.

**[HASH TABLE STRUCT]:**
```c
#include <string.h>
struct entry {
  int key;
  char value[32];
  struct entry *next;
};
```

**[PUT FUNCTION]:**
```c
  // passed parameter is `char *str_val`
  if (e) {
    strncpy(e->value, str_val, 31);
    e->value[31] = '\0';
  } else {
    struct entry *new_e = malloc(sizeof(struct entry));
    new_e->key = key;
    strncpy(new_e->value, str_val, 31);
    new_e->value[31] = '\0';
    new_e->next = table[i];
    table[i] = new_e;
  }
```

---

## P10: Consistent Hashing (Mock)
> Dynamic bucket assignment. Keys map to buckets in a cyclical ring array.

**[PUT FUNCTION]:**
```c
  // Assuming a ring[] array of ranges
  int i = 0;
  for (i = 0; i < NBUCKET; i++) {
     if (key <= ring_boundaries[i]) break;
  }
  if (i == NBUCKET) i = 0; // wrap around
  
  pthread_mutex_lock(&locks[i]);
  // ... proceed normally
```

---

## P11: Cuckoo Hashing (Concept)
> Use two hashes. If bucket 1 is full, kick the existing entry to its alternative hash location. Highly complex to implement properly with concurrent locks.

**[PUT FUNCTION]:**
```c
  int h1 = key % NBUCKET;
  int h2 = (key / NBUCKET) % NBUCKET;
  // Try h1, if full, swap out existing and push that one to h2.
```

---
---

# Pattern B — Feature Extensions (P12–P22)

> **Scope**: Advanced concurrency features like thread-local storage, barriers, memory pooling, and pthreads API extensions.

---

## P12: Thread-local Counters
> Each thread maintains its own count of puts instead of a contended global counter.

**[HASH TABLE STRUCT]:**
```c
// TLS variable
__thread int local_puts = 0;
```

**[PUT FUNCTION]:**
```c
  // Inside put_thread loop:
  put(keys[b*n + i], n);
  local_puts++;
```

---

## P13: Progress Reporting
> Print progress efficiently using the thread-local counter to avoid spamming `stdout` and slowing down execution.

**[PUT FUNCTION]:**
```c
  // Inside put_thread loop:
  put(keys[b*n + i], n);
  local_puts++;
  if (local_puts % 10000 == 0) {
     printf("Thread %d processed %d items\n", n, local_puts);
  }
```

---

## P14: Throughput Measurement
> Let each thread calculate its own independent throughput ops/sec.

**[MAIN SETUP] (Inside put_thread):**
```c
  double start = now();
  for (int i = 0; i < b; i++) {
    put(keys[b*n + i], n);
  }
  double end = now();
  printf("Thread %d throughput: %.0f ops/sec\n", n, b / (end - start));
```

---

## P15: Multiple Put+Get Phases (Barriers)
> Interleave puts and gets using `pthread_barrier_t` to ensure all threads finish put phase before any thread begins get phase.

**[HASH TABLE STRUCT]:**
```c
pthread_barrier_t sync_barrier;
```

**[MAIN SETUP]:**
```c
  // Initialize barrier for N threads
  pthread_barrier_init(&sync_barrier, NULL, nthread);
  
  // Clean up later
  pthread_barrier_destroy(&sync_barrier);
```

**[EXTRA FUNCTIONS] (Thread worker logic):**
```c
void *worker(void *xa) {
    // 1. Phase 1 put
    put_thread(xa);
    
    // 2. Wait for everyone to finish putting
    pthread_barrier_wait(&sync_barrier);
    
    // 3. Phase 2 get
    get_thread(xa);
    return NULL;
}
```

---

## P16: Error Injection
> Test data integrity by occasionally inserting a corrupted/mutated key under the lock, ensuring the `get()` phase fails.

**[PUT FUNCTION]:**
```c
  if (random() % 100 == 0) {
      key = key ^ 0xFFFFFFFF; // Corrupt 1% of keys
  }
  // proceed to insert...
```

---

## P17: Timestamps
> Store the time of insertion inside the struct. `get()` can return the age in seconds.

**[HASH TABLE STRUCT]:**
```c
struct entry {
  int key;
  int value;
  struct timeval ts;
  struct entry *next;
};
```

**[PUT FUNCTION]:**
```c
  struct entry *new_e = malloc(sizeof(struct entry));
  gettimeofday(&new_e->ts, NULL);
  // ... assign rest
```

---

## P18: Dynamic Thread Count
> Start 1 "manager" thread from `main`. The manager then spawns the worker threads.

**[MAIN SETUP]:**
```c
// Instead of creating multiple threads in main():
// main() creates 1 manager thread.
void *manager_thread(void *arg) {
    pthread_t workers[4];
    for (int i=0; i<4; i++) {
        pthread_create(&workers[i], NULL, put_thread, (void*)(long)i);
    }
    for (int i=0; i<4; i++) {
        pthread_join(workers[i], NULL);
    }
    return NULL;
}
```

---

## P19: Priority Threads
> Launch one specific thread with high priority (requires root/sudo and realtime scheduling policies usually).

**[MAIN SETUP]:**
```c
  pthread_attr_t attr;
  struct sched_param param;
  pthread_attr_init(&attr);
  pthread_attr_setschedpolicy(&attr, SCHED_FIFO);
  param.sched_priority = 99; // highest
  pthread_attr_setschedparam(&attr, &param);
  
  // Create thread 0 with high priority attributes
  pthread_create(&tha[0], &attr, put_thread, (void*)(long)0);
```

---

## P20: Stats Print
> After all threads join, print the size of each bucket chain.

**[MAIN SETUP] (Before returning from main):**
```c
  for (int i = 0; i < NBUCKET; i++) {
    int len = 0;
    struct entry *e = table[i];
    while(e) { len++; e = e->next; }
    printf("Bucket %d: %d entries\n", i, len);
  }
```

---

## P21: Memory Pool (Atomic Allocation)
> Replace thread-unsafe or slow `malloc` with a pre-allocated array and an atomic index. Fast, contiguous memory!

**[HASH TABLE STRUCT]:**
```c
#include <stdatomic.h>

struct entry pool[NKEYS];
atomic_int pool_idx = 0;
```

**[PUT FUNCTION] (Custom insert logic):**
```c
  // Inside the else block:
  int my_idx = atomic_fetch_add(&pool_idx, 1);
  struct entry *e = &pool[my_idx];
  e->key = key;
  e->value = value;
  e->next = table[i];
  table[i] = e;
```

---

## P22: Bounded Concurrent Puts
> Limit the maximum number of threads doing a `put()` at the *exact same time* to `K` using a global counting semaphore.

**[HASH TABLE STRUCT]:**
```c
#include <semaphore.h>
sem_t concurrency_limit;
```

**[MAIN SETUP]:**
```c
  // Allow at most 2 threads inserting simultaneously
  sem_init(&concurrency_limit, 0, 2); 
```

**[PUT FUNCTION]:**
```c
  sem_wait(&concurrency_limit); // Request permission
  
  int i = key % NBUCKET;
  pthread_mutex_lock(&locks[i]);
  // ... insert logic ...
  pthread_mutex_unlock(&locks[i]);
  
  sem_post(&concurrency_limit); // Release token
```

---

## Pattern A & B Quick Reference

| # | Name | Scope / Focus | Complexity |
|---|------|---------------|------------|
| P1 | Knuth Hash | Hash function collision reduction | Simple |
| P2 | Update-in-place | Efficiency (baseline standard) | Simple |
| P3 | Sorted Insert | Fast lookups / Read optimization | Medium |
| P4 | Resize trace | Detection of skewed distributions | Simple |
| P5 | LRU Eviction | Read-modify (Locks in `get()`) | Hard |
| P6 | Count Get | Value aggregation logic | Simple |
| P7 | Batch Insert | Lock amortization | Medium |
| P8 | Open Addressing | Arrays vs linked lists | Hard |
| P9 | String Values | Critical section memory copies | Simple |
| P10 | Consistent Hash | Virtual ring topology | Hard |
| P11 | Cuckoo Hash | Multi-table eviction | Hard |
| P12 | Thread-local keys | `__thread` reduction strategy | Simple |
| P13 | Progress print | Interval reporting | Simple |
| P14 | Throughput metrics| Independent timeval usage | Simple |
| P15 | Barriers | `pthread_barrier_t` phase syncing | Medium |
| P16 | Error Inject | Deliberate data corruption | Simple |
| P17 | Timestamps | Extra properties mapped | Simple |
| P18 | Dynamic Threads | Nested `pthread_create` spawns | Medium |
| P19 | Scheduling Policy | Attributes + `SCHED_FIFO` | Hard |
| P20 | Statistical Print | End-of-run state traversal | Simple |
| P21 | Memory Pooling | `stdatomic.h` array allocation | Hard |
| P22 | Bounded Puts | `sem_t` concurrency rate limiting | Medium |

---
---

# Pattern C — Advanced Sync Tasks (P23–P33)

> **Scope**: Custom synchronization primitives (rwlocks, spinlocks, semaphores built from cond vars) and structural locking changes.

---

## P23: Readers-Writers Lock (Custom)
> **Tests**: Building a custom rwlock using a standard mutex and condition variable. Multiple `get` threads can read simultaneously, but `put` requires exclusive access.

**[HASH TABLE STRUCT]:**
```c
struct rwlock {
  int readers;
  int writers; // 0 or 1
  int write_requests;
  pthread_mutex_t m;
  pthread_cond_t c;
};

struct rwlock rwl[NBUCKET];
```

**[MAIN SETUP] (Initialization):**
```c
  for (int i=0; i<NBUCKET; i++) {
    rwl[i].readers = 0; rwl[i].writers = 0; rwl[i].write_requests = 0;
    pthread_mutex_init(&rwl[i].m, NULL);
    pthread_cond_init(&rwl[i].c, NULL);
  }
```

**[GET FUNCTION] (Reader Lock):**
```c
  int i = key % NBUCKET;
  pthread_mutex_lock(&rwl[i].m);
  while (rwl[i].writers > 0 || rwl[i].write_requests > 0) {
    pthread_cond_wait(&rwl[i].c, &rwl[i].m);
  }
  rwl[i].readers++;
  pthread_mutex_unlock(&rwl[i].m);
  
  // -- PERFORM GET TRAVERSAL --

  pthread_mutex_lock(&rwl[i].m);
  rwl[i].readers--;
  if (rwl[i].readers == 0) pthread_cond_broadcast(&rwl[i].c);
  pthread_mutex_unlock(&rwl[i].m);
```

**[PUT FUNCTION] (Writer Lock):**
```c
  int i = key % NBUCKET;
  pthread_mutex_lock(&rwl[i].m);
  rwl[i].write_requests++;
  while (rwl[i].readers > 0 || rwl[i].writers > 0) {
    pthread_cond_wait(&rwl[i].c, &rwl[i].m);
  }
  rwl[i].write_requests--;
  rwl[i].writers = 1;
  pthread_mutex_unlock(&rwl[i].m);

  // -- PERFORM PUT INSERTION --

  pthread_mutex_lock(&rwl[i].m);
  rwl[i].writers = 0;
  pthread_cond_broadcast(&rwl[i].c);
  pthread_mutex_unlock(&rwl[i].m);
```

---

## P24: Producer-Consumer Hash Table
> **Tests**: Using condition variables to signal when buckets are empty or full, limiting chain lengths dynamically.

**[HASH TABLE STRUCT]:**
```c
pthread_mutex_t locks[NBUCKET];
pthread_cond_t not_empty[NBUCKET];
pthread_cond_t not_full[NBUCKET];
int sizes[NBUCKET] = {0};
#define MAX_CHAIN 10
```

**[PUT FUNCTION] (Producer):**
```c
  pthread_mutex_lock(&locks[i]);
  while (sizes[i] >= MAX_CHAIN) {
    pthread_cond_wait(&not_full[i], &locks[i]);
  }
  // -- insert logic --
  sizes[i]++;
  pthread_cond_signal(&not_empty[i]);
  pthread_mutex_unlock(&locks[i]);
```

---

## P25: Dining Philosophers with Buckets
> **Tests**: Deadlock-free sequential locking of two resources simultaneously. 

**[PUT FUNCTION]:**
```c
  // E.g., moving an item from bucket i to bucket j
  int min = i < j ? i : j;
  int max = i > j ? i : j;
  
  // ALWAYS lock in ascending order to prevent deadlocks
  pthread_mutex_lock(&locks[min]);
  pthread_mutex_lock(&locks[max]);
  
  // perform swap/move
  
  pthread_mutex_unlock(&locks[max]);
  pthread_mutex_unlock(&locks[min]);
```

---

## P26: Lock-Free Linked List (CAS)
> **Tests**: Replacing OS mutexes with hardware atomic `__sync_val_compare_and_swap`. Massive performance gain but risks ABA problems in complex systems.

**[HASH TABLE STRUCT]:**
```c
// Remove pthread_mutex_t locks[] entirely
```

**[PUT FUNCTION] (Insert only):**
```c
  struct entry *new_e = malloc(sizeof(struct entry));
  new_e->key = key; new_e->value = value;
  
  while (1) {
    new_e->next = table[i]; // Peek current head
    // Try to atomically swap the head to our new entry
    if (__sync_bool_compare_and_swap(&table[i], new_e->next, new_e)) {
      break; // Success!
    }
  } // Spin if another thread beat us
```

---

## P27: Hand-Over-Hand Locking
> **Tests**: Fine-grained locking at the node level instead of the bucket level.

**[HASH TABLE STRUCT]:**
```c
struct entry {
  int key; int value;
  pthread_mutex_t nlock;
  struct entry *next;
};
```

**[GET FUNCTION]:**
```c
  // Omitted complex initialization...
  pthread_mutex_lock(&bucket_lock[i]); // lock the head pointer first
  struct entry *curr = table[i];
  if (curr) pthread_mutex_lock(&curr->nlock);
  pthread_mutex_unlock(&bucket_lock[i]);
  
  while (curr) {
     if (curr->key == key) { pthread_mutex_unlock(&curr->nlock); return curr; }
     struct entry *next = curr->next;
     if (next) pthread_mutex_lock(&next->nlock);
     pthread_mutex_unlock(&curr->nlock);
     curr = next;
  }
```

---

## P28: Transactional Bulk Ops
> **Tests**: Absolute serializability for operations involving the *entire* table (like a global resize or flush).

**[EXTRA FUNCTIONS]:**
```c
void flush_table() {
  // Lock all strictly in order
  for(int i=0; i<NBUCKET; i++) pthread_mutex_lock(&locks[i]);
  
  // ZERO EVERYTHING
  for(int i=0; i<NBUCKET; i++) table[i] = NULL;
  
  for(int i=0; i<NBUCKET; i++) pthread_mutex_unlock(&locks[i]);
}
```

---

## P29: Monitor Pattern (Global)
> **Tests**: Abstracting the entire hash table behind ONE lock and generic condition variables. Very slow, but perfectly safe.

**[HASH TABLE STRUCT]:**
```c
pthread_mutex_t monitor_lock = PTHREAD_MUTEX_INITIALIZER;
```

**[PUT FUNCTION]:**
```c
  pthread_mutex_lock(&monitor_lock);
  // Do ALL dictionary operations internally
  // ...
  pthread_mutex_unlock(&monitor_lock);
```

---

## P30: Spinlock Implementation
> **Tests**: Using gcc built-ins to manually spin instead of context switching to the OS scheduler.

**[HASH TABLE STRUCT]:**
```c
int spinlocks[NBUCKET] = {0};
```

**[PUT FUNCTION]:**
```c
  // Replaces pthread_mutex_lock
  while (__sync_lock_test_and_set(&spinlocks[i], 1)) {
     // spin wildly burning CPU!
  }
  
  // ... modified code ...
  
  // Replaces pthread_mutex_unlock
  __sync_lock_release(&spinlocks[i]);
```

---

## P31: Recursive Lock Configuration
> **Tests**: Attempting to lock the exact same mutex twice from the same thread. Requires recursive attributes.

**[MAIN SETUP]:**
```c
  pthread_mutexattr_t attr;
  pthread_mutexattr_init(&attr);
  pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
  
  for (int i = 0; i < NBUCKET; i++) {
    pthread_mutex_init(&locks[i], &attr);
  }
```

---

## P32: Try-Lock Optimization
> **Tests**: Non-blocking lock attempts. Useful for "best-effort" aggregation without pausing threads.

**[PUT FUNCTION]:**
```c
  if (pthread_mutex_trylock(&locks[i]) == 0) {
      // We got the lock immediately!
      // ... insert ...
      pthread_mutex_unlock(&locks[i]);
  } else {
      // Print or skip or queue up for later
      printf("Bucket %d contended. Skipping.\n", i);
  }
```

---

## P33: Exponential Backoff Spinlock
> **Tests**: Spinning on custom atomic locks, but adding `usleep` delays to reduce memory bus traffic on high contention.

**[PUT FUNCTION]:**
```c
  int delay = 1;
  while (__sync_lock_test_and_set(&spinlocks[i], 1)) {
      usleep(delay);
      if (delay < 1024) delay *= 2; 
  }
```

---
---

# Pattern D — Mutation Dimensions & Edge Case Bugs (P34–P52)

> **Scope**: Intentional sabotage and boundary pushing to test OS behavior under incorrect synchronization handling.

---

## P34: 1 Bucket Only Stress Test
> **Code**: Change `#define NBUCKET 5` to `1`.
> **Effect**: Converts the hash table into a single, massive linked list. Serialization overhead goes to 100%. Ops/second drops drastically.

---

## P35: 100 Threads Stress Test
> **Code**: Pass `100` via `argv`.
> **Effect**: High context-switching overhead reduces total throughput (adds thrashing).

---

## P36: Lock Only Insert (The 'ph' Lab Bug)
> **Code**: Move `pthread_mutex_lock` AFTER the `for` loop traversal.
> **Effect**: `get` threads see partial states. Two `put` threads might both think the key is missing and insert duplicates. MISSING KEYS result.

---

## P37: Lock the Wrong Bucket
> **Code**: `pthread_mutex_lock(&locks[(i+1)%NBUCKET]);`
> **Effect**: Fails to protect the actual bucket being modified. Race conditions occur dynamically. Memory leaks and incorrect counts randomly happen.

---

## P38: Deadlock Creation Demonstration
> **Code**: In `put_thread`, if thread 0, lock 0 then 1. If thread 1, lock 1 then 0.
> **Effect**: Execution halts permanently. `pthread_join` blocks forever.

**[EXTRA FUNCTIONS] (Deadlock logic):**
```c
void *deadlocker(void *xa) {
   int n = (int)(long)xa;
   if (n == 0) {
       pthread_mutex_lock(&locks[0]);
       sleep(1); // guarantee overlap
       pthread_mutex_lock(&locks[1]); 
   } else {
       pthread_mutex_lock(&locks[1]);
       sleep(1);
       pthread_mutex_lock(&locks[0]);
   }
   return NULL;
}
```

---

## P39: Deadlock Resolution
> **Code**: Fix P38 by ensuring Lock 0 is always acquired before Lock 1, regardless of who is calling it.

---

## P40: Memory Leak Test
> **Code**: After `main` joins `get_thread`, write a loop to free all `e->value`. 
> **Effect**: Valgrind/address-sanitizer shows perfectly clean exit.

---

## P41: Destroyed Lock Usage
> **Code**: Call `pthread_mutex_destroy` immediately after `pthread_create`.
> **Effect**: The locks are destroyed while threads are running! Undefined behavior (often ignored by OS until it segfaults on heavy contention).

---

## P42: Double Lock (Self Deadlock)
> **Code**: Add `pthread_mutex_lock(&locks[i]);` back-to-back.
> **Effect**: Thread waits for itself to unlock. Fast failure.

---

## P43: Forgot to Unlock
> **Code**: Remove `pthread_mutex_unlock`.
> **Effect**: First thread finishes, subsequent threads pile up indefinitely waiting on the held lock.

---

## P44: Signal vs Broadcast Bug
> **Code**: Change a `pthread_cond_broadcast` in a reader/writer scheme to `pthread_cond_signal`. 
> **Effect**: "Lost wakeups". Multiple readers waiting, but only one is woken up when the writer leaves.

---

## P45: Spurious Wakeup Bug
> **Code**: Change `while (condition) wait()` to `if (condition) wait()`.
> **Effect**: The OS can wake up waiting threads randomly (spurious). Without the `while` loop re-checking the condition, the thread proceeds into the critical section while it is unsafe!

---

## P46: Static Initializer syntax
> **Code**: Replace `#define NBUCKET` arrays with static declarations: `pthread_mutex_t lck = PTHREAD_MUTEX_INITIALIZER;`
> **Effect**: Skips `pthread_mutex_init` in main. Clean initialization for singular globals.

---

## P47: Thread-Unsafe Memory (Concept)
> **Code**: Replace `malloc` with a global `char buffer[10MB]; int offset=0;` and use `offset += bytes`.
> **Effect**: If `offset += bytes` is unlocked, threads overwrite each other's pointers.

---

## P48: Atomic Counter Fetch
> **Code**: `__sync_fetch_and_add(&missing, 1);`
> **Effect**: Ensures accurate accounting for shared globals without needing a heavy mutex wrap.

---

## P49: False Sharing Hit
> **Code**: Thread 1 increments `stats[0]`. Thread 2 increments `stats[1]`.
> **Effect**: 100x slower. The CPU cache lines (64 bytes) invalidate each other continuously despite modifying "different" variables.

---

## P50: Thread-Specific Keys
> **Code**: `pthread_key_create(&k, NULL); pthread_setspecific(k, my_ptr);`
> **Effect**: Global variables that store different values on a per-thread basis underneath the hood via `fs` segment.

---

## P51: Barrier with Timeout 
> **Code**: Replace `pthread_barrier_wait` with `pthread_cond_timedwait`.
> **Effect**: Fails open. If a thread dies, the rest don't wait forever.

---

## P52: Monitor Bounded Buffer limit
> **Code**: Restricting total hash table items globally to 100 using a single cond variable pushing back on `put`.
