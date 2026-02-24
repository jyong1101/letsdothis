# Quiz 2 Predicted Scenarios — Part D: Uthread Modifications

> **Based on**: Lab5 `uthread.c` + `uthread_switch.S` — User-level cooperative threading
> **Quiz 1 Pattern Applied**: Extend thread library with new features

---

## Scenario D1: "uthread_arg" — Thread Create with Arguments

**Difficulty**: ★★★★☆ (Moderate-Hard)
**Concept Tested**: RISC-V calling convention (a0 register), context initialization

**Task Description**: Modify `thread_create` to accept a `void *arg` argument that is passed to the thread function. The thread function signature changes to `void (*func)(void *arg)`.

```
$ uthread_arg
thread 0 received arg: 10
thread 1 received arg: 20
thread 2 received arg: 30
```

### Implementation

#### Modified `thread_create` in `uthread.c`

```c
void 
thread_create(void (*func)(void *), void *arg)
{
  struct thread *t;

  for (t = all_thread; t < all_thread + MAX_THREAD; t++) {
    if (t->state == FREE) {
      t->state = RUNNABLE;
      
      t->context.sp = (uint64)t->stack + STACK_SIZE;
      t->context.ra = (uint64)func;
      
      // Pass argument via s0 register (will be moved to a0 by a wrapper)
      // Alternative: use a trampoline that loads arg into a0 before calling func
      t->context.s0 = (uint64)arg;
      
      break;
    }
  }
}
```

**Better approach using a trampoline**:

```c
struct thread_start_info {
  void (*func)(void *);
  void *arg;
};

// Global storage for start info (one per thread slot)
struct thread_start_info start_info[MAX_THREAD];

void
thread_trampoline(void)
{
  // current_thread points to us
  int idx = current_thread - all_thread;
  start_info[idx].func(start_info[idx].arg);
  
  // Thread finished
  current_thread->state = FREE;
  thread_schedule();
}

void 
thread_create(void (*func)(void *), void *arg)
{
  struct thread *t;

  for (t = all_thread; t < all_thread + MAX_THREAD; t++) {
    if (t->state == FREE) {
      t->state = RUNNABLE;
      
      int idx = t - all_thread;
      start_info[idx].func = func;
      start_info[idx].arg = arg;
      
      t->context.sp = (uint64)t->stack + STACK_SIZE;
      t->context.ra = (uint64)thread_trampoline;
      
      break;
    }
  }
}
```

#### Test Code

```c
void
worker(void *arg)
{
  int val = (int)(uint64)arg;
  printf("thread received arg: %d\n", val);
  for (int i = 0; i < 50; i++) {
    printf("worker(%d) iteration %d\n", val, i);
    thread_yield();
  }
  printf("worker(%d): done\n", val);
  current_thread->state = FREE;
  thread_schedule();
}

int
main(int argc, char *argv[])
{
  thread_init();
  thread_create(worker, (void *)10);
  thread_create(worker, (void *)20);
  thread_create(worker, (void *)30);
  current_thread->state = FREE;
  thread_schedule();
  exit(0);
}
```

---

## Scenario D2: "uthread_priority" — Priority-Based Scheduling

**Difficulty**: ★★★★★ (Hard)
**Concept Tested**: Scheduling algorithms, thread state management

**Task Description**: Add priority levels (0=low, 1=medium, 2=high) to threads. `thread_schedule` always picks the highest-priority runnable thread. Threads of equal priority use round-robin.

### Implementation

#### Modified `thread` struct

```c
struct thread {
  char       stack[STACK_SIZE]; 
  int        state;             
  int        priority;          // NEW: 0=low, 1=med, 2=high
  struct thread_context context;
};
```

#### Modified `thread_create`

```c
void 
thread_create(void (*func)(), int priority)
{
  struct thread *t;

  for (t = all_thread; t < all_thread + MAX_THREAD; t++) {
    if (t->state == FREE) {
      t->state = RUNNABLE;
      t->priority = priority;
      t->context.sp = (uint64)t->stack + STACK_SIZE;
      t->context.ra = (uint64)func;
      break;
    }
  }
}
```

#### Modified `thread_schedule`

```c
void 
thread_schedule(void)
{
  struct thread *t, *next_thread;

  // Find the highest-priority runnable thread
  next_thread = 0;
  int best_prio = -1;

  // Start from after current thread for round-robin within same priority
  t = current_thread + 1;
  for (int i = 0; i < MAX_THREAD; i++) {
    if (t >= all_thread + MAX_THREAD)
      t = all_thread;
    if (t->state == RUNNABLE && t->priority > best_prio) {
      next_thread = t;
      best_prio = t->priority;
    }
    t = t + 1;
  }

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
```

#### Test Code

```c
void thread_high(void) {
  for (int i = 0; i < 5; i++) {
    printf("HIGH %d\n", i);
    thread_yield();
  }
  current_thread->state = FREE;
  thread_schedule();
}

void thread_low(void) {
  for (int i = 0; i < 5; i++) {
    printf("LOW %d\n", i);
    thread_yield();
  }
  current_thread->state = FREE;
  thread_schedule();
}

int main(int argc, char *argv[]) {
  thread_init();
  thread_create(thread_low, 0);    // low priority
  thread_create(thread_high, 2);   // high priority
  thread_create(thread_low, 0);    // low priority
  current_thread->state = FREE;
  thread_schedule();
  exit(0);
}
```

---

## Scenario D3: "uthread_join" — Thread Join

**Difficulty**: ★★★★☆ (Moderate-Hard)
**Concept Tested**: Thread synchronization, blocking/busy-waiting, thread IDs

**Task Description**: Add `thread_join(int tid)` that blocks the calling thread until thread `tid` finishes (transitions to FREE).

### Implementation

```c
#define MAX_THREAD  4

// Return the thread ID (index in all_thread array)
int
thread_id(void)
{
  return current_thread - all_thread;
}

// Modified thread_create to return thread ID
int
thread_create(void (*func)())
{
  struct thread *t;

  for (t = all_thread; t < all_thread + MAX_THREAD; t++) {
    if (t->state == FREE) {
      t->state = RUNNABLE;
      t->context.sp = (uint64)t->stack + STACK_SIZE;
      t->context.ra = (uint64)func;
      return t - all_thread;  // return thread ID
    }
  }
  return -1; // no free thread slot
}

// Thread join — busy-wait + yield until target thread is FREE
void
thread_join(int tid)
{
  if (tid < 0 || tid >= MAX_THREAD)
    return;
    
  while (all_thread[tid].state != FREE) {
    thread_yield();
  }
}
```

#### Test Code

```c
void worker(void) {
  for (int i = 0; i < 50; i++) {
    printf("worker %d\n", i);
    thread_yield();
  }
  printf("worker done\n");
  current_thread->state = FREE;
  thread_schedule();
}

void main_thread(void) {
  int tid = thread_create(worker);
  printf("main: waiting for thread %d\n", tid);
  thread_join(tid);
  printf("main: thread %d finished!\n", tid);
  current_thread->state = FREE;
  thread_schedule();
}
```

---

## Scenario D4: "uthread_mutex" — User-Space Mutex

**Difficulty**: ★★★★★ (Hard)
**Concept Tested**: Mutual exclusion in cooperative threading, spin-yield lock

**Task Description**: Implement a simple mutex for the user-level threading library. Since there's only one CPU running the threads cooperatively, a yield-based lock suffices.

### Implementation

```c
struct thread_mutex {
  int locked;
  int owner;  // thread ID of owner, -1 if unlocked
};

void
thread_mutex_init(struct thread_mutex *m)
{
  m->locked = 0;
  m->owner = -1;
}

void
thread_mutex_lock(struct thread_mutex *m)
{
  while (m->locked) {
    thread_yield();  // yield until the lock is free
  }
  m->locked = 1;
  m->owner = current_thread - all_thread;
}

void
thread_mutex_unlock(struct thread_mutex *m)
{
  m->locked = 0;
  m->owner = -1;
}
```

#### Test Code — Shared Counter

```c
volatile int shared_counter = 0;
struct thread_mutex mtx;

void counter_thread(void) {
  for (int i = 0; i < 1000; i++) {
    thread_mutex_lock(&mtx);
    shared_counter++;
    thread_mutex_unlock(&mtx);
    if (i % 100 == 0)
      thread_yield();
  }
  printf("thread done, counter = %d\n", shared_counter);
  current_thread->state = FREE;
  thread_schedule();
}

int main(int argc, char *argv[]) {
  thread_mutex_init(&mtx);
  thread_init();
  thread_create(counter_thread);
  thread_create(counter_thread);
  thread_create(counter_thread);
  current_thread->state = FREE;
  thread_schedule();
  exit(0);
}
```

---

## Scenario D5: "uthread_sleep" — Thread Sleep with Tick Count

**Difficulty**: ★★★★☆ (Moderate-Hard)
**Concept Tested**: Time-based scheduling, cooperative sleep/wakeup

**Task Description**: Add `thread_sleep(int ticks)` that suspends the current thread for approximately N scheduling rounds (not real ticks, but yield iterations).

### Implementation

```c
#define SLEEPING    0x3  // New state

struct thread {
  char       stack[STACK_SIZE]; 
  int        state;             
  int        sleep_ticks;       // NEW: ticks remaining before wakeup
  struct thread_context context;
};

void
thread_sleep(int ticks)
{
  current_thread->state = SLEEPING;
  current_thread->sleep_ticks = ticks;
  thread_schedule();
}

// Modified thread_schedule to handle sleeping threads
void 
thread_schedule(void)
{
  struct thread *t, *next_thread;

  // First pass: decrement sleep counters and wake up threads
  for (t = all_thread; t < all_thread + MAX_THREAD; t++) {
    if (t->state == SLEEPING) {
      t->sleep_ticks--;
      if (t->sleep_ticks <= 0) {
        t->state = RUNNABLE;
      }
    }
  }

  // Find next runnable thread
  next_thread = 0;
  t = current_thread + 1;
  for (int i = 0; i < MAX_THREAD; i++) {
    if (t >= all_thread + MAX_THREAD)
      t = all_thread;
    if (t->state == RUNNABLE) {
      next_thread = t;
      break;
    }
    t = t + 1;
  }

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
```

---

## Scenario D6: "uthread_extra_regs" — Extended Context Save

**Difficulty**: ★★★★★ (Hard)
**Concept Tested**: RISC-V register file, assembly programming, ABI understanding

**Task Description**: Modify `uthread_switch.S` to also save/restore the `t0-t6` (temporary) registers, not just callee-saved. Modify `thread_context` accordingly.

### Implementation

#### Modified `thread_context` in `uthread.c`
```c
struct thread_context {
  uint64 ra;
  uint64 sp;
  // callee-saved
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
  // temporary registers (NEW)
  uint64 t0;
  uint64 t1;
  uint64 t2;
  uint64 t3;
  uint64 t4;
  uint64 t5;
  uint64 t6;
};
```

#### Modified `uthread_switch.S`
```asm
	.text
	.globl thread_switch
thread_switch:
    # SAVE current context (a0)
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
    # Save temporaries (NEW)
    sd t0,  112(a0)
    sd t1,  120(a0)
    sd t2,  128(a0)
    sd t3,  136(a0)
    sd t4,  144(a0)
    sd t5,  152(a0)
    sd t6,  160(a0)

    # LOAD new context (a1)
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
    # Load temporaries (NEW)
    ld t0,  112(a1)
    ld t1,  120(a1)
    ld t2,  128(a1)
    ld t3,  136(a1)
    ld t4,  144(a1)
    ld t5,  152(a1)
    ld t6,  160(a1)

    ret
```
