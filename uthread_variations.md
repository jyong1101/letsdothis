# Uthread (User-Level Threading) — Coded Variations

> **Lab**: Uthread (Week 5) — Cooperative user-level threads with context switching.
> **Mechanism**: `thread_yield()` sets state to `RUNNABLE`, calls `thread_schedule()`, which picks the next thread and calls `thread_switch(old_ctx, new_ctx)`.
> **Registers saved**: `ra, sp, s0-s11` (14 callee-saved registers × 8 bytes = 112 bytes).
> **Source files**: `user/uthread.c`, `user/uthread_switch.S`

---

## Context Switch Flow

```
         ┌──────────────────────────────┐
         │  thread_yield()              │
         │    state = RUNNABLE          │
         │    thread_schedule()         │
         └──────────────┬───────────────┘
                        ▼
         ┌──────────────────────────────┐
         │  thread_schedule()           │
         │    Find next RUNNABLE thread │
         │    next->state = RUNNING     │
         │    current_thread = next     │
         └──────────────┬───────────────┘
                        ▼
         ┌──────────────────────────────┐
         │  thread_switch(&old, &new)   │
         │    sd ra,sp,s0-s11 → old     │  ← SAVE 14 regs
         │    ld ra,sp,s0-s11 ← new     │  ← RESTORE 14 regs
         │    ret                       │  ← jumps to new ra
         └──────────────────────────────┘
```

> ⚠️ **Key insight**: `ra` is set to the thread function on first switch (brand-new thread jumps to `thread_a`/`b`/`c`). On subsequent switches, `ra` points back into `thread_schedule()` where the old thread was paused.

---

## Assembly Reference: `uthread_switch.S`

```asm
thread_switch:
    # SAVE old context (a0 = &old_thread->context)
    sd ra,  0(a0)
    sd sp,  8(a0)
    sd s0,  16(a0)
    sd s1,  24(a0)
    sd s2,  32(a0)
    sd s3,  40(a0)
    sd s4,  48(a0)
    sd s5,  56(a0)
    sd s6,  64(a0)
    sd s7,  72(a0)
    sd s8,  80(a0)
    sd s9,  88(a0)
    sd s10, 96(a0)
    sd s11, 104(a0)

    # RESTORE new context (a1 = &new_thread->context)
    ld ra,  0(a1)
    ld sp,  8(a1)
    ld s0,  16(a1)
    ld s1,  24(a1)
    ld s2,  32(a1)
    ld s3,  40(a1)
    ld s4,  48(a1)
    ld s5,  56(a1)
    ld s6,  64(a1)
    ld s7,  72(a1)
    ld s8,  80(a1)
    ld s9,  88(a1)
    ld s10, 96(a1)
    ld s11, 104(a1)

    ret    # jump to new ra
```

| Offset | Register | Purpose |
|--------|----------|---------|
| 0 | ra | Return address (where thread resumes) |
| 8 | sp | Stack pointer (thread's private stack) |
| 16 | s0/fp | Frame pointer |
| 24-104 | s1-s11 | Callee-saved general purpose |

---

## Core Boilerplate

```c
#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"

/* Possible states of a thread: */
#define FREE        0x0
#define RUNNING     0x1
#define RUNNABLE    0x2

#define STACK_SIZE  8192
#define MAX_THREAD  4

// ════════════════════════════════════════════════════════
// ════════ MODIFY HERE [EXTRA FUNCTIONS - GLOBALS] ══════
// (Global variables: counters, locks, queues, etc.)
// ════════════════════════════════════════════════════════

struct thread_context {
  uint64 ra;
  uint64 sp;
  uint64 s0;
  uint64 s1;
  uint64 s2;
  uint64 s3;
  uint64 s4;
  uint64 s5;
  uint64 s6;
  uint64 s7;
  uint64 s8;
  uint64 s9;
  uint64 s10;
  uint64 s11;
};

struct thread {
  char       stack[STACK_SIZE];
  int        state;
  struct thread_context context;

  // ════════════════════════════════════════════
  // ════════ MODIFY HERE [THREAD STRUCT] ═══════
  // (Add: priority, ticks, name, tid, etc.)
  // ════════════════════════════════════════════
};

struct thread all_thread[MAX_THREAD];
struct thread *current_thread;
extern void thread_switch(uint64, uint64);

void
thread_init(void)
{
  current_thread = &all_thread[0];
  current_thread->state = RUNNING;
}

void
thread_schedule(void)
{
  struct thread *t, *next_thread;

  next_thread = 0;

  // ════════════════════════════════════════════════════════
  // ════════ MODIFY HERE [SCHEDULER LOGIC] ═════════════════
  // Baseline: round-robin starting from current_thread + 1
  // ════════════════════════════════════════════════════════
  t = current_thread + 1;
  for(int i = 0; i < MAX_THREAD; i++){
    if(t >= all_thread + MAX_THREAD)
      t = all_thread;
    if(t->state == RUNNABLE) {
      next_thread = t;
      break;
    }
    t = t + 1;
  }
  // ════════ END SCHEDULER LOGIC ═══════════════════════════

  if (next_thread == 0) {
    printf("thread_schedule: no runnable threads\n");
    exit(-1);
  }

  if (current_thread != next_thread) {
    next_thread->state = RUNNING;
    t = current_thread;
    current_thread = next_thread;
    thread_switch((uint64)&t->context, (uint64)&next_thread->context);
  } else
    next_thread = 0;
}

void
thread_create(void (*func)())
{
  struct thread *t;
  for (t = all_thread; t < all_thread + MAX_THREAD; t++) {
    if (t->state == FREE) {
      t->state = RUNNABLE;
      t->context.sp = (uint64)t->stack + STACK_SIZE;
      t->context.ra = (uint64)func;

      // ════════════════════════════════════════════
      // ════════ MODIFY HERE [THREAD CREATE] ═══════
      // (Initialize: priority=0, ticks=0, name, etc.)
      // ════════════════════════════════════════════

      break;
    }
  }
}

void
thread_yield(void)
{
  current_thread->state = RUNNABLE;
  thread_schedule();
}

// ════════════════════════════════════════════════════════
// ════════ MODIFY HERE [EXTRA FUNCTIONS] ════════════════
// (New APIs: thread_exit, semaphores, yield_to, etc.)
// ════════════════════════════════════════════════════════

// --- Thread exit pattern (standard) ---
// Inside a thread function:
//   current_thread->state = FREE;
//   thread_schedule();
```

### Drop Zone Guide

| Zone | Location | What goes here |
|------|----------|---------------|
| `[THREAD STRUCT]` | Inside `struct thread` | Extra fields (priority, name, tid, ticks, tls) |
| `[THREAD CREATE]` | Inside `thread_create()` | Initialize new fields after setting ra/sp |
| `[SCHEDULER LOGIC]` | Inside `thread_schedule()` | Replace round-robin with custom selection |
| `[EXTRA FUNCTIONS]` | After `thread_yield()` | New APIs, helper functions, data structures |
| `[EXTRA - GLOBALS]` | Before `struct thread_context` | Global variables, counters, queues |

---

## Thread Lifecycle

```
FREE → thread_create() → RUNNABLE → scheduled → RUNNING → yield() → RUNNABLE → ...
                                                         → exit (state=FREE) → done
```

---
---

# Pattern A — Logic Twists (U1–U12)

> **Scope**: Modify scheduling **selection logic** inside `thread_schedule()`.
> **Rule**: Only the specified drop zones change.

---

## U1: LIFO Scheduling (Most Recently Yielded First)

> Schedule the thread that **most recently called yield()**. Uses a global timestamp counter; each yield records the time. Scheduler picks the highest timestamp.

**Thread Struct:**
```c
int yield_time;                    // when this thread last yielded
```

**Extra - Globals:**
```c
int global_time = 0;               // monotonic timestamp
```

**Thread Create:**
```c
t->yield_time = 0;
```

**Scheduler Logic:**
```c
// LIFO: pick thread with HIGHEST yield_time
next_thread = 0;
int max_time = -1;
for (int i = 0; i < MAX_THREAD; i++) {
    if (all_thread[i].state == RUNNABLE && all_thread[i].yield_time > max_time) {
        max_time = all_thread[i].yield_time;
        next_thread = &all_thread[i];
    }
}
```

**Override thread_yield:**
```c
void thread_yield(void) {
    current_thread->state = RUNNABLE;
    current_thread->yield_time = global_time++;
    thread_schedule();
}
```

---

## U2: Random Scheduling

> Select a **random RUNNABLE thread**. Uses a simple xorshift PRNG seeded with a global state.

**Extra - Globals:**
```c
uint64 rng_state = 12345;

uint64 xorshift(void) {
    rng_state ^= rng_state << 13;
    rng_state ^= rng_state >> 7;
    rng_state ^= rng_state << 17;
    return rng_state;
}
```

**Scheduler Logic:**
```c
// Gather all RUNNABLE threads
struct thread *runnable[MAX_THREAD];
int count = 0;
for (int i = 0; i < MAX_THREAD; i++) {
    if (all_thread[i].state == RUNNABLE)
        runnable[count++] = &all_thread[i];
}
if (count > 0)
    next_thread = runnable[xorshift() % count];
```

---

## U3: Shortest-Burst-First

> Declare an **expected iteration count** at creation. Scheduler picks the thread with the fewest expected remaining iterations.

**Thread Struct:**
```c
int burst;                         // expected remaining iterations
```

**Thread Create (modified signature):**
```c
// thread_create(thread_a, 100);   ← pass expected burst
void thread_create(void (*func)(), int expected_burst) {
    // ... existing code ...
    t->burst = expected_burst;
}
```

**Scheduler Logic:**
```c
// SJF: pick RUNNABLE thread with smallest burst
next_thread = 0;
int min_burst = 999999;
for (int i = 0; i < MAX_THREAD; i++) {
    if (all_thread[i].state == RUNNABLE && all_thread[i].burst < min_burst) {
        min_burst = all_thread[i].burst;
        next_thread = &all_thread[i];
    }
}
```

> 💡 Decrease `burst` in `thread_yield()` if you want it to reflect remaining work: `current_thread->burst--;`

---

## U4: Aging Scheduler

> Threads have a **base priority**. Every time a thread is skipped (not selected), its **effective priority** increases by 1. Once selected, age resets to 0. Prevents starvation.

**Thread Struct:**
```c
int priority;                      // base priority (0 = lowest)
int age;                           // incremented when skipped
```

**Thread Create:**
```c
t->priority = 0;
t->age = 0;
```

**Scheduler Logic:**
```c
// Pick highest (priority + age), then reset winner's age
next_thread = 0;
int best_score = -1;
for (int i = 0; i < MAX_THREAD; i++) {
    if (all_thread[i].state == RUNNABLE) {
        int score = all_thread[i].priority + all_thread[i].age;
        if (score > best_score) {
            best_score = score;
            next_thread = &all_thread[i];
        }
    }
}
// Age all RUNNABLE threads, reset winner
for (int i = 0; i < MAX_THREAD; i++) {
    if (all_thread[i].state == RUNNABLE)
        all_thread[i].age++;
}
if (next_thread)
    next_thread->age = 0;
```

---

## U5: Time-Sliced Scheduling

> Each thread gets **K consecutive yields** (quantum) before forced to switch. Keeps a `yields_remaining` counter.

**Thread Struct:**
```c
int yields_remaining;              // how many more yields before forced switch
```

**Extra - Globals:**
```c
#define QUANTUM 3                  // K yields per time slice
```

**Thread Create:**
```c
t->yields_remaining = QUANTUM;
```

**Scheduler Logic:**
```c
// If current thread still has quantum left, don't switch
if (current_thread->state == RUNNABLE && current_thread->yields_remaining > 0) {
    current_thread->yields_remaining--;
    next_thread = current_thread;
} else {
    // Reset quantum, find next via round-robin
    current_thread->yields_remaining = QUANTUM;
    t = current_thread + 1;
    for (int i = 0; i < MAX_THREAD; i++) {
        if (t >= all_thread + MAX_THREAD) t = all_thread;
        if (t->state == RUNNABLE) { next_thread = t; break; }
        t = t + 1;
    }
    if (next_thread) next_thread->yields_remaining = QUANTUM;
}
```

---

## U6: Two-Queue Scheduler

> Threads have a **priority** (0=low, 1=high). Scheduler checks the high queue first; only runs low-priority threads when no high-priority ones are RUNNABLE.

**Thread Struct:**
```c
int priority;                      // 0 = low, 1 = high
```

**Thread Create (modified):**
```c
void thread_create(void (*func)(), int prio) {
    // ... existing code ...
    t->priority = prio;
}
```

**Scheduler Logic:**
```c
// Pass 1: check high-priority threads
next_thread = 0;
for (int i = 0; i < MAX_THREAD; i++) {
    if (all_thread[i].state == RUNNABLE && all_thread[i].priority == 1) {
        next_thread = &all_thread[i];
        break;
    }
}
// Pass 2: fall back to low-priority
if (!next_thread) {
    for (int i = 0; i < MAX_THREAD; i++) {
        if (all_thread[i].state == RUNNABLE && all_thread[i].priority == 0) {
            next_thread = &all_thread[i];
            break;
        }
    }
}
```

---

## U7: Reverse Round-Robin

> Same as baseline but traverse the thread table **backwards** (current-1, wrapping from 0 to MAX_THREAD-1).

**Scheduler Logic:**
```c
// Reverse: start from current - 1, go backwards
if (current_thread == all_thread)
    t = &all_thread[MAX_THREAD - 1];
else
    t = current_thread - 1;

for (int i = 0; i < MAX_THREAD; i++) {
    if (t < all_thread)
        t = &all_thread[MAX_THREAD - 1];
    if (t->state == RUNNABLE) {
        next_thread = t;
        break;
    }
    t = t - 1;
}
```

---

## U8: Weighted Round-Robin

> Each thread has a **weight W**. It runs for W consecutive yields before the scheduler moves on. Uses a `weight_remaining` counter.

**Thread Struct:**
```c
int weight;                        // total weight (how many turns per round)
int weight_remaining;              // remaining turns in current round
```

**Thread Create (modified):**
```c
void thread_create(void (*func)(), int w) {
    // ... existing code ...
    t->weight = w;
    t->weight_remaining = w;
}
```

**Scheduler Logic:**
```c
// If current thread still has weight remaining, re-run it
if (current_thread->state == RUNNABLE && current_thread->weight_remaining > 0) {
    current_thread->weight_remaining--;
    next_thread = current_thread;
} else {
    // Reset weight, find next via round-robin
    current_thread->weight_remaining = current_thread->weight;
    t = current_thread + 1;
    for (int i = 0; i < MAX_THREAD; i++) {
        if (t >= all_thread + MAX_THREAD) t = all_thread;
        if (t->state == RUNNABLE) {
            next_thread = t;
            next_thread->weight_remaining = next_thread->weight;
            break;
        }
        t = t + 1;
    }
}
```

---

## U9: Cooperative Watchdog

> Print a **warning** if a thread has yielded more than 100 times total. Detects threads stuck in infinite yield loops.

**Thread Struct:**
```c
int yield_count;                   // total yields by this thread
```

**Thread Create:**
```c
t->yield_count = 0;
```

**Override thread_yield:**
```c
void thread_yield(void) {
    current_thread->yield_count++;
    if (current_thread->yield_count > 100)
        printf("WATCHDOG: thread %d exceeded 100 yields!\n",
               (int)(current_thread - all_thread));
    current_thread->state = RUNNABLE;
    thread_schedule();
}
```

---

## U10: Thread Affinity

> Each thread has a **preferred slot** (index in `all_thread`). Scheduler prefers threads whose preferred slot matches their actual index.

**Thread Struct:**
```c
int preferred_slot;                // preferred index in all_thread[]
```

**Thread Create:**
```c
t->preferred_slot = (int)(t - all_thread);  // default: own slot
```

**Scheduler Logic:**
```c
// Pass 1: look for RUNNABLE thread in its preferred slot
next_thread = 0;
for (int i = 0; i < MAX_THREAD; i++) {
    if (all_thread[i].state == RUNNABLE && all_thread[i].preferred_slot == i) {
        next_thread = &all_thread[i];
        break;
    }
}
// Pass 2: fallback to any RUNNABLE
if (!next_thread) {
    for (int i = 0; i < MAX_THREAD; i++) {
        if (all_thread[i].state == RUNNABLE) {
            next_thread = &all_thread[i];
            break;
        }
    }
}
```

---

## U11: Lottery Scheduling

> Each thread has **N tickets**. Scheduler draws a random number and walks through threads, accumulating ticket counts until the winner is found.

**Thread Struct:**
```c
int tickets;                       // lottery tickets (higher = more likely)
```

**Thread Create (modified):**
```c
void thread_create(void (*func)(), int tix) {
    // ... existing code ...
    t->tickets = tix;
}
```

**Scheduler Logic (uses xorshift from U2):**
```c
// Sum all RUNNABLE tickets
int total_tickets = 0;
for (int i = 0; i < MAX_THREAD; i++) {
    if (all_thread[i].state == RUNNABLE)
        total_tickets += all_thread[i].tickets;
}
if (total_tickets > 0) {
    int winner = xorshift() % total_tickets;
    int cumulative = 0;
    for (int i = 0; i < MAX_THREAD; i++) {
        if (all_thread[i].state == RUNNABLE) {
            cumulative += all_thread[i].tickets;
            if (cumulative > winner) {
                next_thread = &all_thread[i];
                break;
            }
        }
    }
}
```

---

## U12: FIFO (Non-Preemptive)

> Threads run **to completion**. `thread_yield()` is a no-op — it returns without switching. Threads must explicitly set `state = FREE` to finish.

**Override thread_yield:**
```c
void thread_yield(void) {
    // FIFO: yield is a no-op
    // Thread continues running until it explicitly exits
    return;
}
```

> ⚠️ With FIFO, threads run one at a time. thread_a runs 100 iterations, exits, then thread_b starts. No interleaving.

---

## Pattern A Quick Reference

| # | Name | Zone(s) Modified | Key Change | Complexity |
|---|------|-----------------|------------|------------|
| U1 | LIFO | Struct+Globals+Create+Yield | `yield_time = global_time++`, pick max | Medium |
| U2 | Random | Globals+Scheduler | `xorshift() % count` | Medium |
| U3 | SJF | Struct+Create+Scheduler | `burst` field, pick min | Medium |
| U4 | Aging | Struct+Create+Scheduler | `priority + age`, age++ for skipped | Medium |
| U5 | Time-slice | Struct+Globals+Create+Scheduler | `yields_remaining` countdown | Medium |
| U6 | Two-queue | Struct+Create+Scheduler | High (1) before low (0) | Medium |
| U7 | Reverse RR | Scheduler only | `t = current - 1`, backward | Simple |
| U8 | Weighted RR | Struct+Create+Scheduler | `weight_remaining` countdown | Medium |
| U9 | Watchdog | Struct+Create+Yield | `yield_count > 100` warning | Simple |
| U10 | Affinity | Struct+Create+Scheduler | `preferred_slot == i` check | Medium |
| U11 | Lottery | Struct+Create+Scheduler+Globals | Tickets, cumulative draw | Hard |
| U12 | FIFO | Yield only | `return;` (no-op) | Simple |

---
---

# Pattern B — Feature Extensions (U13–U25)

> **Scope**: Add new capabilities to the threading system — names, IDs, TLS, synchronization, pool, targeted yield.
> **Rule**: Only the specified drop zones change.

---

## U13: Thread Create with Name

> Add a `char name[16]` to each thread. `thread_create` takes a name argument. Useful for debugging output.

**Thread Struct:**
```c
char name[16];
```

**Thread Create (modified):**
```c
void thread_create(void (*func)(), char *tname) {
    // ... existing code (find FREE, set sp, ra) ...
    // Copy name
    int i;
    for (i = 0; tname[i] && i < 15; i++)
        t->name[i] = tname[i];
    t->name[i] = 0;
}
```

**Usage:**
```c
thread_create(thread_a, "worker-A");
thread_create(thread_b, "worker-B");
// Print in thread: printf("%s running\n", current_thread->name);
```

---

## U14: Thread Exit with Return Value

> Add `thread_exit(int val)` and `thread_join(tid)` that returns the exit value. Uses `exit_val` and `EXITED` state.

**Extra - Globals:**
```c
#define EXITED 0x3                 // new state: finished with return value
```

**Thread Struct:**
```c
int exit_val;                      // return value from thread_exit
int tid;                           // thread ID for join
```

**Thread Create:**
```c
static int next_tid = 1;
t->tid = next_tid++;
t->exit_val = 0;
```

**Extra Functions:**
```c
void thread_exit(int val) {
    current_thread->exit_val = val;
    current_thread->state = EXITED;
    thread_schedule();
}

int thread_join(int tid) {
    // Busy-wait for thread with matching tid to become EXITED
    while (1) {
        for (int i = 0; i < MAX_THREAD; i++) {
            if (all_thread[i].tid == tid && all_thread[i].state == EXITED) {
                int val = all_thread[i].exit_val;
                all_thread[i].state = FREE;  // reclaim slot
                return val;
            }
        }
        thread_yield();  // keep yielding while waiting
    }
}
```

> 💡 Scheduler must NOT pick EXITED threads — add `&& t->state != EXITED` to scheduler checks if needed.

---

## U15: Thread-Local Storage (TLS)

> Each thread has a small **key-value store** (4 slots). Provides `tls_set(key, val)` and `tls_get(key)`.

**Thread Struct:**
```c
uint64 tls[4];                     // thread-local storage, 4 slots
```

**Thread Create:**
```c
for (int j = 0; j < 4; j++) t->tls[j] = 0;
```

**Extra Functions:**
```c
void tls_set(int key, uint64 val) {
    if (key >= 0 && key < 4)
        current_thread->tls[key] = val;
}

uint64 tls_get(int key) {
    if (key >= 0 && key < 4)
        return current_thread->tls[key];
    return 0;
}
```

**Usage in thread function:**
```c
tls_set(0, 42);       // store value
uint64 v = tls_get(0); // retrieve: v = 42
// Each thread has INDEPENDENT values — no sharing
```

---

## U16: Thread ID Tracking

> `thread_create` returns a **unique thread ID**. `thread_self()` returns the current thread's ID.

**Thread Struct:**
```c
int tid;
```

**Extra - Globals:**
```c
int next_tid = 1;
```

**Thread Create (modified to return int):**
```c
int thread_create(void (*func)()) {
    struct thread *t;
    for (t = all_thread; t < all_thread + MAX_THREAD; t++) {
        if (t->state == FREE) {
            t->state = RUNNABLE;
            t->context.sp = (uint64)t->stack + STACK_SIZE;
            t->context.ra = (uint64)func;
            t->tid = next_tid++;
            return t->tid;
        }
    }
    return -1;  // no free slots
}
```

**Extra Functions:**
```c
int thread_self(void) {
    return current_thread->tid;
}
```

---

## U17: Stack Guard (Overflow Detection)

> Write a **magic pattern** `0xDEADBEEF` at the bottom of the stack during creation. Check it on every yield to detect stack overflow.

**Thread Create (add after setting sp):**
```c
// Write guard pattern at bottom of stack (stack[0..3])
*(uint32*)t->stack = 0xDEADBEEF;
```

**Override thread_yield:**
```c
void thread_yield(void) {
    // Check stack guard
    uint32 guard = *(uint32*)current_thread->stack;
    if (guard != 0xDEADBEEF) {
        printf("STACK OVERFLOW detected in thread %d!\n",
               (int)(current_thread - all_thread));
        current_thread->state = FREE;
        thread_schedule();
        return;
    }
    current_thread->state = RUNNABLE;
    thread_schedule();
}
```

> 💡 Stack grows downward (high → low). The guard at `stack[0]` (lowest address) will be overwritten if the stack grows too far. 8192 bytes = 8KB per thread.

---

## U18: Semaphore for Threads

> Implement a **counting semaphore** using busy-wait. `sem_wait` decrements (or yields if 0), `sem_post` increments.

**Extra Functions:**
```c
struct sem {
    int value;
};

void sem_init(struct sem *s, int val) {
    s->value = val;
}

void sem_wait(struct sem *s) {
    while (s->value <= 0)
        thread_yield();       // busy-wait via cooperative yield
    s->value--;
}

void sem_post(struct sem *s) {
    s->value++;
}
```

**Usage:**
```c
struct sem mutex;
sem_init(&mutex, 1);         // binary semaphore

void thread_a(void) {
    sem_wait(&mutex);
    // critical section
    printf("thread_a in CS\n");
    sem_post(&mutex);
    // ...
}
```

> 💡 This works because uthread is **cooperative** (single-core, no preemption). `sem_wait` yields until value > 0.

---

## U19: Condition Variable for Threads

> Implement `cond_wait` (yield until signaled) and `cond_signal` (wake one waiting thread). Adds `SLEEPING` state.

**Extra - Globals:**
```c
#define SLEEPING 0x4               // new state: waiting on condition

struct cond {
    int waiting_count;
};
```

**Extra Functions:**
```c
void cond_init(struct cond *c) {
    c->waiting_count = 0;
}

void cond_wait(struct cond *c) {
    c->waiting_count++;
    current_thread->state = SLEEPING;
    thread_schedule();
    // execution resumes here after being signaled
}

void cond_signal(struct cond *c) {
    if (c->waiting_count > 0) {
        // Wake one SLEEPING thread
        for (int i = 0; i < MAX_THREAD; i++) {
            if (all_thread[i].state == SLEEPING) {
                all_thread[i].state = RUNNABLE;
                c->waiting_count--;
                break;
            }
        }
    }
}
```

> ⚠️ Scheduler must skip `SLEEPING` threads — the default check `t->state == RUNNABLE` already does this.

---

## U20: Thread Cancel

> Mark a thread as **cancelled**. The thread checks its `cancelled` flag on the next yield and exits if set.

**Thread Struct:**
```c
int cancelled;                     // 0 = normal, 1 = cancel requested
```

**Thread Create:**
```c
t->cancelled = 0;
```

**Extra Functions:**
```c
void thread_cancel(int idx) {
    if (idx >= 0 && idx < MAX_THREAD)
        all_thread[idx].cancelled = 1;
}
```

**Override thread_yield:**
```c
void thread_yield(void) {
    if (current_thread->cancelled) {
        printf("thread %d: cancelled\n",
               (int)(current_thread - all_thread));
        current_thread->state = FREE;
        thread_schedule();
        return;
    }
    current_thread->state = RUNNABLE;
    thread_schedule();
}
```

---

## U21: Multiple Schedulers (Partitioned)

> Partition threads into **two groups**: group A (indices 0-1) and group B (indices 2-3). Each group has its own independent round-robin.

**Scheduler Logic:**
```c
// Determine which group the current thread belongs to
int group_start, group_end;
int cur_idx = (int)(current_thread - all_thread);
if (cur_idx < 2) {
    group_start = 0; group_end = 2;   // group A: slots 0,1
} else {
    group_start = 2; group_end = 4;   // group B: slots 2,3
}

next_thread = 0;
for (int i = group_start; i < group_end; i++) {
    if (i == cur_idx) continue;
    if (all_thread[i].state == RUNNABLE) {
        next_thread = &all_thread[i];
        break;
    }
}
// If no thread in group, fall back to any RUNNABLE
if (!next_thread) {
    for (int i = 0; i < MAX_THREAD; i++) {
        if (all_thread[i].state == RUNNABLE) {
            next_thread = &all_thread[i];
            break;
        }
    }
}
```

---

## U22: Thread Run Count (Statistics)

> Track **how many times** each thread is scheduled. Print stats when all threads finish.

**Thread Struct:**
```c
int run_count;                     // times this thread was scheduled
```

**Thread Create:**
```c
t->run_count = 0;
```

**Scheduler Logic (add after setting RUNNING):**
```c
// In thread_schedule, after: next_thread->state = RUNNING;
next_thread->run_count++;
```

**Extra Functions (call from main before exit):**
```c
void print_thread_stats(void) {
    printf("=== Thread Run Statistics ===\n");
    for (int i = 0; i < MAX_THREAD; i++) {
        printf("  thread[%d]: scheduled %d times\n",
               i, all_thread[i].run_count);
    }
}
```

**Usage in main:**
```c
// After all threads finish (before exit):
print_thread_stats();
```

---

## U23: Dynamic Thread Creation

> Thread A creates **Thread D mid-execution**. Shows that `thread_create` can be called from any running thread, not just main.

**No code changes needed — just a demonstration:**
```c
void thread_d(void) {
    printf("thread_d: dynamically created!\n");
    for (int i = 0; i < 50; i++) {
        printf("thread_d %d\n", i);
        thread_yield();
    }
    current_thread->state = FREE;
    thread_schedule();
}

void thread_a(void) {
    printf("thread_a started\n");

    // Dynamically create thread D from thread A!
    thread_create(thread_d);
    printf("thread_a: created thread_d\n");

    for (int i = 0; i < 100; i++) {
        printf("thread_a %d\n", i);
        thread_yield();
    }
    current_thread->state = FREE;
    thread_schedule();
}
```

> 💡 `thread_create` scans `all_thread[]` for a FREE slot and fills it. Works from any thread — no restriction to main.

---

## U24: Thread Pool

> A fixed pool of **N worker threads** pulling work items from a shared queue. Workers loop, pulling and executing jobs.

**Extra - Globals:**
```c
#define POOL_SIZE 2
#define QUEUE_SIZE 8

typedef void (*work_func)(int);

struct work_item {
    work_func func;
    int arg;
    int valid;                     // 1 = has work, 0 = empty
};

struct work_item work_queue[QUEUE_SIZE];
int queue_head = 0;
int queue_tail = 0;
int pool_shutdown = 0;
```

**Extra Functions:**
```c
void pool_submit(work_func f, int arg) {
    work_queue[queue_tail].func = f;
    work_queue[queue_tail].arg = arg;
    work_queue[queue_tail].valid = 1;
    queue_tail = (queue_tail + 1) % QUEUE_SIZE;
}

void worker_thread(void) {
    while (!pool_shutdown) {
        if (work_queue[queue_head].valid) {
            struct work_item item = work_queue[queue_head];
            work_queue[queue_head].valid = 0;
            queue_head = (queue_head + 1) % QUEUE_SIZE;
            item.func(item.arg);
        }
        thread_yield();
    }
    current_thread->state = FREE;
    thread_schedule();
}
```

**Usage:**
```c
void my_job(int n) {
    printf("job %d running\n", n);
}

// In main:
thread_create(worker_thread);   // worker 1
thread_create(worker_thread);   // worker 2
pool_submit(my_job, 1);
pool_submit(my_job, 2);
pool_submit(my_job, 3);
// Workers will pick up and execute jobs
```

---

## U25: Yield-To (Targeted Thread Switch)

> `thread_yield_to(tid)` yields directly to a **specific thread** by its ID. Bypasses the scheduler's selection logic.

**Thread Struct:**
```c
int tid;
```

**Thread Create:**
```c
static int next_tid = 1;
t->tid = next_tid++;
```

**Extra Functions:**
```c
void thread_yield_to(int target_tid) {
    struct thread *target = 0;
    for (int i = 0; i < MAX_THREAD; i++) {
        if (all_thread[i].tid == target_tid &&
            all_thread[i].state == RUNNABLE) {
            target = &all_thread[i];
            break;
        }
    }
    if (target) {
        current_thread->state = RUNNABLE;
        target->state = RUNNING;
        struct thread *old = current_thread;
        current_thread = target;
        thread_switch((uint64)&old->context, (uint64)&target->context);
    } else {
        // Target not runnable, fall back to normal yield
        thread_yield();
    }
}
```

**Usage:**
```c
int tid_b = thread_create(thread_b);  // returns tid
// Later, from thread_a:
thread_yield_to(tid_b);  // directly switch to thread_b
```

> 💡 This bypasses the scheduler entirely — a direct switch. If the target thread is not RUNNABLE, falls back to normal yield.

---

## Pattern B Quick Reference

| # | Name | Zone(s) Modified | Key Change | Complexity |
|---|------|-----------------|------------|------------|
| U13 | Named threads | Struct+Create | `name[16]`, copy in create | Simple |
| U14 | thread_exit + join | Struct+Create+Extra | `exit_val`, EXITED state, busy-wait join | Hard |
| U15 | TLS | Struct+Create+Extra | `tls[4]` array, set/get API | Simple |
| U16 | Thread ID | Struct+Globals+Create+Extra | `tid = next_tid++`, `thread_self()` | Simple |
| U17 | Stack guard | Create+Yield | `0xDEADBEEF` at stack base, check on yield | Medium |
| U18 | Semaphore | Extra only | `sem_wait` (yield loop), `sem_post` | Medium |
| U19 | Condition var | Globals+Extra | SLEEPING state, `cond_wait/signal` | Hard |
| U20 | Thread cancel | Struct+Create+Yield | `cancelled` flag, check in yield | Simple |
| U21 | Multi-scheduler | Scheduler only | Partition 0-1 vs 2-3 | Medium |
| U22 | Run count | Struct+Create+Scheduler+Extra | `run_count++`, `print_thread_stats()` | Simple |
| U23 | Dynamic create | Extra (demo) | Call `thread_create()` from thread function | Simple |
| U24 | Thread pool | Globals+Extra | `work_queue[]`, `worker_thread`, `pool_submit` | Hard |
| U25 | Yield-to | Struct+Create+Extra | `thread_yield_to(tid)`, direct switch | Medium |

---
---

# Pattern C — Combo Tasks (U26–U33)

> **Scope**: Combine user-level threads with other xv6 features like pipes, sbrk, fork, or signals.
> **Rule**: Uses **Drop Zones** for user-space changes, and **Two-Part Structure** if kernel changes are required.

---

## U26: Uthread + pipe

> **User Code Only.** Threads in the *same process* share file descriptors. Main creates a pipe; Thread A writes, Thread B reads.

**Extra - Globals:**
```c
int p[2];
```

**Extra Functions (Thread Logic for A & B):**
```c
void thread_a(void) {
    char msg[] = "hello from A\n";
    write(p[1], msg, sizeof(msg));
    current_thread->state = FREE;
    thread_schedule();
}

void thread_b(void) {
    char buf[32];
    int n = read(p[0], buf, sizeof(buf));
    if (n > 0) {
        printf("Thread B received: %s", buf);
    }
    current_thread->state = FREE;
    thread_schedule();
}

// In main():
// pipe(p);
// thread_create(thread_a);
// thread_create(thread_b);
```

---

## U27: Uthread + sbrk

> **User Code Only.** All threads share the same process heap. Thread A calls `sbrk()` to allocate memory; Thread B writes to it.

**Extra - Globals:**
```c
char *shared_heap_ptr;
```

**Extra Functions:**
```c
void thread_A(void) {
    // Expand process heap by 4096 bytes
    shared_heap_ptr = sbrk(4096);
    printf("A allocated memory\n");
    current_thread->state = FREE;
    thread_schedule();
}

void thread_B(void) {
    // Wait until A has allocated (polling)
    while (shared_heap_ptr == 0) {
        thread_yield();
    }
    strcpy(shared_heap_ptr, "Data from B");
    printf("B wrote to heap: %s\n", shared_heap_ptr);
    current_thread->state = FREE;
    thread_schedule();
}
```

---

## U28: Uthread + monitor

> **Kernel + User Code.** Use a `monitor` system call to trace process-wide `sbrk` calls, even though multiple user threads are causing them.

**Kernel Code (sys_sbrk in sysproc.c):**
```c
uint64 sys_sbrk(void) {
    int addr;
    int n;
    if(argint(0, &n) < 0) return -1;
    addr = myproc()->sz;

    if (myproc()->is_monitored) {
        printf("[MONITOR] process %d (uthread) called sbrk(%d)\n", myproc()->pid, n);
    }

    if(growproc(n) < 0) return -1;
    return addr;
}
```

**User Code (Extra Functions):**
```c
void sbrk_thread(void) {
    sbrk(10); // Will trigger monitor trace in kernel for the whole process
    current_thread->state = FREE;
    thread_schedule();
}

// In main():
// monitor(1); // Turn on tracing
// thread_create(sbrk_thread);
// thread_create(sbrk_thread);
```

---

## U29: Uthread + fork

> **User Code Only.** A user thread calls `fork()`. The child process gets an exact duplicate of the thread states, but only the thread that called fork is actually executing in the child. 

**Extra Functions:**
```c
void fork_thread(void) {
    printf("Thread calling fork...\n");
    int pid = fork();
    if (pid == 0) {
        // Child process
        printf("Hello from child process thread!\n");
        // Only THIS thread is running in the child. 
        // Other threads' stacks were copied, but the scheduler loop was only 
        // duplicated where this thread called fork.
        exit(0); 
    } else {
        wait(0);
        printf("Parent thread done.\n");
    }
    current_thread->state = FREE;
    thread_schedule();
}
```

---

## U30: Signal Emulation

> **User Space Only.** A thread can "signal" another. The target checks a flag during `thread_yield()` and runs a handler before yielding.

**Thread Struct:**
```c
int pending_signal;
void (*signal_handler)(void);
```

**Thread Create:**
```c
t->pending_signal = 0;
t->signal_handler = 0; // null by default
```

**Override thread_yield:**
```c
void thread_yield(void) {
    if (current_thread->pending_signal && current_thread->signal_handler) {
        current_thread->pending_signal = 0;
        current_thread->signal_handler(); // Execute handler
    }
    current_thread->state = RUNNABLE;
    thread_schedule();
}
```

**Extra Functions:**
```c
void thread_kill(int target_idx) { // send signal
    all_thread[target_idx].pending_signal = 1;
}
```

---

## U31: MLFQ (Multi-Level Feedback Queue)

> **User Space Only.** Threads start at priority 2. If they complete their quantum without finishing, they demote to 1, then 0. 

**Thread Struct:**
```c
int priority;      // 0, 1, or 2 (highest)
int ticks_used;
```

**Thread Create:**
```c
t->priority = 2;
t->ticks_used = 0;
```

**Scheduler Logic:**
```c
// Search P=2, then P=1, then P=0
next_thread = 0;
for (int p = 2; p >= 0 && !next_thread; p--) {
    for (int i = 0; i < MAX_THREAD; i++) {
        if (all_thread[i].state == RUNNABLE && all_thread[i].priority == p) {
            next_thread = &all_thread[i];
            break;
        }
    }
}
```

**Override thread_yield:**
```c
void thread_yield(void) {
    current_thread->ticks_used++;
    // Demote if it uses its quantum
    if (current_thread->priority > 0 && current_thread->ticks_used >= 3) {
        current_thread->priority--;
        current_thread->ticks_used = 0;
    }
    current_thread->state = RUNNABLE;
    thread_schedule();
}
```

---

## U32: Preemption via Alarm

> **Kernel + User Code.** Use the `alarm` system call to force a user-space context switch. Threads no longer need to call `thread_yield()` manually!

**Kernel Code (sys_alarm setup):**
> *(Assume standard week 4 alarm lab is implemented in the kernel)*

**User Code (Extra Functions - Globals):**
```c
void preempt_handler(void) {
    // Called automatically by the kernel every N ticks!
    // Force a cooperative yield on behalf of the running thread.
    thread_yield();
    sigreturn(); // restore context from alarm
}

// In main():
// alarm(10, preempt_handler); // Preempt every 10 ticks
// thread_init(); ...
```

---

## U33: Barrier

> **User Space Only.** `thread_barrier_wait()` blocks a thread until N threads have arrived at the barrier.

**Extra - Globals:**
```c
int barrier_count = 0;
int barrier_target = 3;
int barrier_generation = 0;
```

**Extra Functions:**
```c
void thread_barrier_wait(void) {
    barrier_count++;
    int my_gen = barrier_generation;

    if (barrier_count == barrier_target) {
        // Last thread arrived! Release all.
        barrier_generation++; 
        barrier_count = 0;
    } else {
        // Wait for generation to change
        while (my_gen == barrier_generation) {
            thread_yield();
        }
    }
}
```

---
---

# Pattern D — Mutation Dimensions (U34–U52)

> **Scope**: Edge cases, assembly changes, boundary conditions, and breaking the model.
> **Rule**: Uses strict Drop Zone modifications. **New Drop Zone: `[UTHREAD_SWITCH.S]`** for assembly modifications.

---

## U34: a0 in Context (Pass Arguments)
> Pass an argument to a new thread via `thread_create(func, arg)`. Requires saving/loading `a0` in assembly.

**UTHREAD_SWITCH.S:**
```asm
# Add `sd a0, 112(a0)` to SAVE block
# Add `ld a0, 112(a1)` to RESTORE block
```
**Thread Struct:**
```c
uint64 a0; // inside struct thread_context
```
**Thread Create (modified signature):**
```c
void thread_create(void (*func)(), void *arg) {
    // ...
    t->context.a0 = (uint64)arg;
    t->context.ra = (uint64)func;
}
```

---

## U35: Misaligned Stack
> RISC-V requires a 16-byte aligned stack. Intentionally misalign it during creation and fix it via bitmask.

**Thread Create:**
```c
t->context.sp = (uint64)t->stack + STACK_SIZE;
t->context.sp -= 4; // Intentionally misaligned by 4 bytes!
// Fix it:
t->context.sp &= ~15; // Align strictly down to nearest 16-byte boundary
```

---

## U36: Stack Size Variation
> Change STACK_SIZE to test minimum functionality.

**Extra - Globals:**
```c
#undef STACK_SIZE
#define STACK_SIZE 256  // Very small stack
```
> *Explanation: 256 bytes is enough for basic functions, but deep calls or large local variables will overflow into the adjacent `state` or `context` structs.*

---

## U37: MAX_THREAD Exhaustion
> Limit MAX_THREAD to exactly 1. 

**Extra - Globals:**
```c
#undef MAX_THREAD
#define MAX_THREAD 1
```
> *Explanation: Test thread_create() bounds. `main` takes thread 0. Any `thread_create` call will fail to find a `FREE` slot and should gracefully handle it.*

---

## U38: Thread That Never Yields
> A thread runs an infinite loop without `thread_yield()`.

**Extra Functions:**
```c
void bad_thread(void) {
    while(1) { /* CPU Hog! */ }
}
```
> *Explanation: Because Uthread is strictly cooperative, execution never returns to `thread_schedule`. All other threads starve immediately.*

---

## U39: Double thread_schedule Call
> Scheduler re-entrancy edge case.

**Override thread_yield:**
```c
void thread_yield(void) {
    current_thread->state = RUNNABLE;
    thread_schedule();  // normal
    thread_schedule();  // WRONG: second call immediately switches to another thread again!
}
```
> *Explanation: The context saved after the first switch will point directly into the middle of `thread_yield()`. Chaos ensues.*

---

## U40: Context Size Mismatch
> Deliberately mess up the stack offsets in assembly but leave C intact.

**UTHREAD_SWITCH.S:**
```asm
# Instead of sd ra, 0(a0) and sd sp, 8(a0)
# sd sp, 0(a0) 
# sd ra, 8(a0) 
```
> *Explanation: Total system crash. The return address `ra` gets loaded with the stack pointer value, immediately jumping into data/stack memory and raising an Instruction Page Fault.*

---

## U41: Free Running Thread
> Thread sets its state to FREE but doesn't yield.

**Extra Functions:**
```c
void ghost_thread(void) {
    current_thread->state = FREE;
    while(1) {
        printf("I am a ghost executing in a FREE slot!\n");
    }
}
```
> *Explanation: Scheduler thinks slot is empty, `thread_create` can overwrite it, corrupting its stack mid-execution.*

---

## U42: Scheduler Scalability
> Test with 50 threads.

**Extra - Globals:**
```c
#undef MAX_THREAD
#define MAX_THREAD 50
```
> *Explanation: Checks if round-robin search (`O(N)`) becomes noticeable. In a user-space loop, `N=50` is still imperceptibly fast.*

---

## U43: Zero-Iteration Thread
> A thread function that returns immediately.

**Extra Functions:**
```c
void empty_func(void) {
    current_thread->state = FREE;
    thread_schedule();
}
```
> *Explanation: Fast lifecycle test. Tests allocator re-use mechanism instantly.*

---

## U44: Thread with printf Interaction
> Printf relies on write() syscall.

**Extra Functions:**
```c
void standard_thread(void) {
    printf("A");
    thread_yield();
    printf("B");
    current_thread->state = FREE;
    thread_schedule();
}
```
> *Explanation: Output streams are buffered globally by the standard library. Mixing threads with `printf` can sometimes cause intertwined characters unless flushed.*

---

## U45: Stack Usage Measurement
> Paint the stack array to find true usage later.

**Thread Create:**
```c
for (int i=0; i < STACK_SIZE; i++) t->stack[i] = 0xAB;
```
**Extra Functions:**
```c
void measure_stack(struct thread *t) {
    int unused = 0;
    while(unused < STACK_SIZE && t->stack[unused] == (char)0xAB) unused++;
    printf("Used: %d bytes\n", STACK_SIZE - unused);
}
```

---

## U46: Thread Migration Simulation
> A thread modifies its own scheduling parameters mid-execution.

**Extra Functions:**
```c
void fickle_thread(void) {
    current_thread->priority = 1; // Start high priority
    thread_yield();
    
    current_thread->priority = 0; // Demote self
    thread_yield();
    
    current_thread->state = FREE;
    thread_schedule();
}
```

---

## U47: Yield Counter Tracking
> Count exact yields per thread.

**Thread Struct:**
```c
int yield_count;
```
**Thread Create:**
```c
t->yield_count = 0;
```
**Override thread_yield:**
```c
void thread_yield(void) {
    current_thread->yield_count++;
    current_thread->state = RUNNABLE;
    thread_schedule();
}
```

---

## U48: FP Registers Context Switch
> Save and restore callee-saved Floating Point registers (`fs0-fs11` / `f8-f9, f18-f27`).

**Thread Struct:**
```c
// Inside struct thread_context
uint64 fs0, fs1, fs2, fs3, fs4, fs5, fs6, fs7, fs8, fs9, fs10, fs11;
```
**UTHREAD_SWITCH.S:**
```asm
# Add block (using offset 112-200)
    fsd fs0, 112(a0)
    # ... up to fsd fs11, 200(a0)
# And in restore:
    fld fs0, 112(a1)
```

---

## U49: Cooperative I/O
> A thread blocked on a read effectively hangs the whole user process.

**Extra Functions:**
```c
void reader_thread(void) {
    char c;
    // Standard blocking read() will freeze ALL user threads!
    // Must implement cooperative yield polling:
    // while (read(0, &c, 1) == 0) { thread_yield(); }
    read(0, &c, 1);
    current_thread->state = FREE;
    thread_schedule();
}
```

---

## U50: Fairness Test
> Record execution history inside thread payloads.

**Extra - Globals:**
```c
int history[100];
int h_idx = 0;
```
**Extra Functions:**
```c
void t1(void) { history[h_idx++] = 1; thread_yield(); }
void t2(void) { history[h_idx++] = 2; thread_yield(); }
// Verifiable output: 1, 2, 1, 2, 1, 2
```

---

## U51: Recursive Function Depth Limit
> Purposefully trigger a stack overflow using a deep recursive call inside a thread.

**Extra Functions:**
```c
void recurse(int depth) {
    int local_buf[128]; // Consume chunk of stack
    local_buf[0] = depth;
    if (depth < 100) recurse(depth + 1);
}
void recursive_thread(void) {
    recurse(0); // Will overflow the 8KB stack rapidly
    current_thread->state = FREE;
    thread_schedule();
}
```

---

## U52: State Machine
> Threads represent state machines (INIT → WORKING → WAITING → DONE).

**Thread Struct:**
```c
int p_state; // custom app state
```
**Extra Functions:**
```c
void state_machine_thread(void) {
    current_thread->p_state = 1; // WORKING
    thread_yield();
    current_thread->p_state = 2; // WAITING
    thread_yield();
    current_thread->state = FREE; // System scheduler state
    thread_schedule();
}
```

---

## Pattern C & D Quick Reference

| # | Name | Key Concept | Complexity |
|---|------|------------|------------|
| U26 | Uthread + pipe | Share FDs across threads | Medium |
| U27 | Uthread + sbrk | Process-wide heap sharing | Simple |
| U28 | Monitor tracing | Kernel `sys_sbrk` tracks process PID | Medium |
| U29 | Uthread + fork | Snapshot cloning of user threads | Medium |
| U30 | Signal emulation | Deferred execution on `yield()` | Hard |
| U31 | MLFQ | Priority arrays with aging | Medium |
| U32 | Alarm Preemption| `alarm()` handler forces `yield()` | Hard |
| U33 | Barrier | Thread sync without kernel sleep | Hard |
| U34 | a0 args context | `ld a0` in assembly, `arg` in `create` | Medium |
| U35 | Misaligned stack| Bitwise masking `& ~15` | Simple |
| U36 | Stack sizes | Overflow bounds testing | Simple |
| U37 | MAX_THREAD=1 | Boundary exhaustion | Simple |
| U38 | Never yields | Cooperative starvation demo | Simple |
| U39 | Double schedule | Context corruption / Re-entrancy | Simple |
| U40 | Size mismatch | Assembly `sd` vs `ld` swapped | Medium |
| U41 | Free running | Illegal state execution | Simple |
| U42 | 50 threads | Overhead timing | Simple |
| U43 | Zero-iteration | Fast reclamation | Simple |
| U44 | Printf overlap | Global libc buffer sharing | Simple |
| U45 | Stack painting | Hex masking to track usage | Medium |
| U46 | Self-migration | Priority change mid-run | Simple |
| U47 | Yield tracks | Metric collection | Simple |
| U48 | FP context | `fsd` / `fld` float save/restore | Medium |
| U49 | Cooperative I/O | Blocking VS polling `read()` | Medium |
| U50 | Fairness test | Deterministic array logging | Simple |
| U51 | Recursive limit | Intentional stack explosion | Simple |
| U52 | State machine | Custom enums overriding flow | Simple |
