# xv6 Lab 3 & Lab 5 Comprehensive Reference Guide

> **Purpose**: CLI AI reference document for xv6 RISC-V operating system labs.
> **Coverage**: Lab3 (handshake, sniffer, monitor), Lab5 (uthread, ph-with-mutex-locks)

---

## Table of Contents
1. [Environment Setup](#environment-setup)
2. [xv6 System Calls Reference](#xv6-system-calls-reference)
3. [Lab 3 Tasks](#lab-3-tasks)
4. [Lab 5 Tasks](#lab-5-tasks)
5. [Utility Functions Reference](#utility-functions-reference)
6. [Common Patterns & Templates](#common-patterns--templates)
7. [Syscall Addition Checklist](#syscall-addition-checklist)
8. [Testing & Grading](#testing--grading)

---

## Environment Setup

### Running xv6 on WSL Ubuntu
```bash
# Open Ubuntu WSL from Windows
wsl -d ubuntu

# Navigate to lab directory (Windows path)
cd /mnt/d/ICT1012/xv6labs-w3
# or for Lab 5:
cd /mnt/d/ICT1012/xv6labs-w5

# Build and run xv6
make qemu

# Clean build (recommended when modifying kernel/Makefile)
make clean && make qemu

# Exit xv6 shell
# Press: Ctrl + a, then x
```

### Adding New User Programs
1. Create source file in `user/` directory (e.g., `user/myprogram.c`)
2. Add to `UPROGS` in `Makefile`:
```makefile
UPROGS=\
    $U/_cat\
    $U/_echo\
    $U/_myprogram\   # Add your program with $U/_ prefix
```
3. Rebuild: `make clean && make qemu`

---

## xv6 System Calls Reference

### System Call Numbers (kernel/syscall.h)
| Number | Name | Description |
|--------|------|-------------|
| 1 | SYS_fork | Create child process |
| 2 | SYS_exit | Terminate process |
| 3 | SYS_wait | Wait for child process |
| 4 | SYS_pipe | Create pipe |
| 5 | SYS_read | Read from file descriptor |
| 6 | SYS_kill | Kill process |
| 7 | SYS_exec | Execute program |
| 8 | SYS_fstat | Get file status |
| 9 | SYS_chdir | Change directory |
| 10 | SYS_dup | Duplicate file descriptor |
| 11 | SYS_getpid | Get process ID |
| 12 | SYS_sbrk | Grow process memory |
| 13 | SYS_pause | Sleep for ticks |
| 14 | SYS_uptime | Get system uptime |
| 15 | SYS_open | Open file |
| 16 | SYS_write | Write to file descriptor |
| 17 | SYS_mknod | Create device file |
| 18 | SYS_unlink | Delete file |
| 19 | SYS_link | Create hard link |
| 20 | SYS_mkdir | Create directory |
| 21 | SYS_close | Close file descriptor |
| **22** | **SYS_monitor** | **Syscall tracing (Lab 3)** |

### User-Callable System Calls (user/user.h)
```c
// Process control
int fork(void);                    // Create child process, returns 0 in child, PID in parent
int exit(int status);              // Terminate with status
int wait(int *status);             // Wait for child, stores exit status
int getpid(void);                  // Get current process ID
int kill(int pid);                 // Kill process by PID
int exec(const char *path, char **argv);  // Execute program

// File I/O
int open(const char *path, int flags);     // Open file, returns fd
int read(int fd, void *buf, int n);        // Read n bytes into buf
int write(int fd, const void *buf, int n); // Write n bytes from buf
int close(int fd);                         // Close file descriptor
int dup(int fd);                           // Duplicate fd

// File system
int mkdir(const char *path);
int chdir(const char *path);
int link(const char *old, const char *new);
int unlink(const char *path);
int fstat(int fd, struct stat *st);

// Memory
char* sbrk(int n);                 // Grow memory by n bytes, returns OLD break

// Timing
int pause(int ticks);              // Sleep for ticks
int uptime(void);                  // Get ticks since boot

// Pipes
int pipe(int *fds);                // Create pipe, fds[0]=read, fds[1]=write

// Lab 3: Syscall tracing
int monitor(int mask);             // Set syscall trace bitmask
```

### Kernel Argument Fetching (kernel/syscall.c)
```c
// Use INSIDE sys_xxx() handlers to get user-space arguments
int argint(int n, int *ip);        // Get nth int arg  → argint(0, &mask)
int argaddr(int n, uint64 *ip);    // Get nth addr arg → argaddr(0, &ptr)
int argstr(int n, char *buf, int max); // Get nth string arg
int argfd(int n, int *pfd, struct file **pf); // Get nth file descriptor
```

---

## Lab 3 Tasks

### Task 1: handshake (IPC Basics)

**Objective**: Parent/child exchange a single byte via two pipes.

**File**: `user/handshake.c`

**Reference Implementation**:
```c
#include "kernel/types.h"
#include "user/user.h"

int main(int argc, char *argv[]) {
    int p1[2], p2[2]; // p1: parent→child, p2: child→parent

    if (pipe(p1) < 0 || pipe(p2) < 0) {
        fprintf(2, "pipe failed\n");
        exit(1);
    }

    int pid = fork();
    if (pid < 0) {
        fprintf(2, "fork failed\n");
        exit(1);
    }

    if (pid == 0) {
        // Child process
        close(p1[1]); // close write end of parent→child
        close(p2[0]); // close read end of child→parent

        char buf;
        if (read(p1[0], &buf, 1) == 1) {
            printf("%d: received %c\n", getpid(), buf);
            write(p2[1], &buf, 1);
        }

        close(p1[0]);
        close(p2[1]);
        exit(0);
    } else {
        // Parent process
        close(p1[0]); // close read end of parent→child
        close(p2[1]); // close write end of child→parent

        char msg = argv[1][0];
        write(p1[1], &msg, 1);

        char buf;
        if (read(p2[0], &buf, 1) == 1) {
            printf("%d: received %c\n", getpid(), buf);
        }

        close(p1[1]);
        close(p2[0]);
        wait(0);
        exit(0);
    }
}
```

**Key Concepts**:
- `pipe(int fd[2])`: `fd[0]` = read end, `fd[1]` = write end
- Always close unused pipe ends! A `read()` will block forever if the write end is still open somewhere.
- `read()` returns `0` on EOF (all write ends closed), `>0` on data, `-1` on error.
- `wait(0)` reaps the child process (prevents zombies).

---

### Task 2: sniffer & secret (Heap Memory Snooping)

**Objective**: `secret` stores a hidden string via `sbrk`. `sniffer` allocates heap and scans it for the marker.

**File**: `user/secret.c`

**Reference Implementation (secret.c)**:
```c
#include "kernel/types.h"
#include "kernel/fcntl.h"
#include "user/user.h"
#include "kernel/riscv.h"

#define DATASIZE (8*4096)
char data[DATASIZE];

int main(int argc, char *argv[]) {
    if (argc != 2) {
        printf("Usage: secret <secret_string>\n");
        exit(1);
    }
    strcpy(data, "This may help.");
    strcpy(data + 16, argv[1]);
    exit(0);
}
```

**File**: `user/sniffer.c`

**Reference Implementation (sniffer.c)**:
```c
#include "kernel/types.h"
#include "kernel/fcntl.h"
#include "user/user.h"
#include "kernel/riscv.h"

int main(int argc, char *argv[]) {
    int size = 10 * 4096; // 10 pages
    char *p = sbrk(size);

    if (p == (char*)-1) {
        printf("sniffer: sbrk failed\n");
        exit(1);
    }

    char *marker = "This may help.";
    int marker_len = strlen(marker);

    // Scan heap for the marker, prevent buffer overread
    for (int i = 0; i < size - marker_len - 64; i++) {
        if (memcmp(p + i, marker, marker_len) == 0) {
            printf("%s\n", p + i + 16); // secret is 16 bytes after marker
            exit(0);
        }
    }

    printf("sniffer: secret not found\n");
    exit(1);
}
```

**Key Concepts**:
- `sbrk(n)` returns old break address (start of new memory). Check for `(char*)-1` error.
- `memcmp(a, b, n)` returns 0 if equal. Used for byte-by-byte sliding window search.
- Secret data layout: `[marker string][padding to byte 16][secret string]`
- Bound the scan loop: `i < size - marker_len - max_secret_len` to prevent reading past allocated memory.

---

### Task 3: monitor (Kernel Syscall Tracing)

**Objective**: Add a new system call `monitor(int mask)` that enables per-process syscall tracing. When a syscall's bit is set in the mask, `syscall()` prints a trace line.

**File**: `user/monitor.c`

**Reference Implementation (user program)**:
```c
#include "kernel/types.h"
#include "user/user.h"

int main(int argc, char *argv[]) {
    if (argc < 3) {
        fprintf(2, "Usage: monitor <mask> <command> [args...]\n");
        exit(1);
    }
    if (monitor(atoi(argv[1])) < 0) {
        fprintf(2, "monitor failed\n");
        exit(1);
    }
    exec(argv[2], &argv[2]);
    fprintf(2, "exec failed\n");
    exit(1);
}
```

**File**: `kernel/proc.h` — Add field to struct proc

```c
struct proc {
  struct spinlock lock;
  uint32 monitor_mask;    // <-- ADD THIS FIELD

  // p->lock must be held when using these:
  enum procstate state;
  // ... remaining fields unchanged ...
};
```

**File**: `kernel/sysproc.c` — Implement sys_monitor

```c
uint64
sys_monitor(void)
{
  int mask;
  argint(0, &mask);
  struct proc *p = myproc();
  p->monitor_mask = (uint32)mask;
  return 0;
}
```

**File**: `kernel/syscall.c` — Add dispatch table entry and trace hook

```c
// Add at top:
extern uint64 sys_monitor(void);

// Add name for printing:
static const char *syscall_names[] = {
  [SYS_fork]    "fork",
  [SYS_exit]    "exit",
  [SYS_wait]    "wait",
  [SYS_pipe]    "pipe",
  [SYS_read]    "read",
  [SYS_kill]    "kill",
  [SYS_exec]    "exec",
  [SYS_fstat]   "fstat",
  [SYS_chdir]   "chdir",
  [SYS_dup]     "dup",
  [SYS_getpid]  "getpid",
  [SYS_sbrk]    "sbrk",
  [SYS_pause]   "pause",
  [SYS_uptime]  "uptime",
  [SYS_open]    "open",
  [SYS_write]   "write",
  [SYS_mknod]   "mknod",
  [SYS_unlink]  "unlink",
  [SYS_link]    "link",
  [SYS_mkdir]   "mkdir",
  [SYS_close]   "close",
  [SYS_monitor] "monitor",
};

// Add to syscalls[] table:
[SYS_monitor] sys_monitor,

// Modify syscall() function — add tracing after dispatch:
void
syscall(void)
{
  int num;
  struct proc *p = myproc();

  num = p->trapframe->a7;
  if(num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    p->trapframe->a0 = syscalls[num]();

    // Trace: if this syscall's bit is set in the mask, print info
    if ((1 << num) & p->monitor_mask) {
      printf("%d: syscall %s -> %d\n",
             p->pid, syscall_names[num], (int)p->trapframe->a0);
    }
  } else {
    printf("%d %s: unknown sys call %d\n", p->pid, p->name, num);
    p->trapframe->a0 = -1;
  }
}
```

**File**: `kernel/syscall.h`
```c
#define SYS_monitor  22
```

**File**: `kernel/proc.c` — Inherit mask on fork
```c
// Inside fork(), after copying process state:
np->monitor_mask = p->monitor_mask;
```

**File**: `user/usys.pl`
```perl
entry("monitor");
```

**File**: `user/user.h`
```c
int monitor(int);
```

**Key Concepts**:
- Bitmask: `(1 << SYS_read)` = bit 5 = `32`. To trace `read`, use `monitor 32 cmd`.
- `p->trapframe->a7` holds the syscall number.
- `p->trapframe->a0` holds the first argument BEFORE syscall, and the return value AFTER.
- Monitor mask is inherited by children on `fork()`.
- `2147483647` = `0x7FFFFFFF` = all 31 bits set = trace all syscalls.

**System Call Flow**:
```
User Space          |  Kernel Space
--------------------|------------------
monitor(mask)       |
        ↓           |
usys.S: ecall       | → trap handler
                    |        ↓
                    |  syscall() dispatcher
                    |        ↓
                    |  sys_monitor() in sysproc.c
                    |    myproc()->monitor_mask = mask
                    |        ↓
                    |  For EVERY subsequent syscall:
                    |    if ((1 << num) & mask) → printf trace
```

---

## Lab 5 Tasks

### Task 1: uthread (User-Level Threading)

**Objective**: Implement cooperative user-level threads with context switching.

**File**: `user/uthread.c`

**Reference Implementation (key parts)**:
```c
#include "kernel/types.h"
#include "user/user.h"

#define MAX_THREAD  4
#define STACK_SIZE  8192

// Must match the offsets in uthread_switch.S
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
  char       stack[STACK_SIZE]; // 8192-byte stack
  int        state;            // FREE, RUNNING, RUNNABLE
  struct thread_context context;
};

#define FREE      0x0
#define RUNNING   0x1
#define RUNNABLE  0x2

struct thread all_thread[MAX_THREAD];
struct thread *current_thread;

extern void thread_switch(uint64 old, uint64 new);

void thread_init(void) {
  current_thread = &all_thread[0];
  current_thread->state = RUNNING;
}

void thread_create(void (*func)()) {
  struct thread *t;
  for (t = all_thread; t < all_thread + MAX_THREAD; t++) {
    if (t->state == FREE) {
      t->state = RUNNABLE;
      // Stack grows downward: point to TOP of stack array
      t->context.sp = (uint64)t->stack + STACK_SIZE;
      // When thread_switch restores ra and does `ret`, execution jumps to func
      t->context.ra = (uint64)func;
      return;
    }
  }
  // Edge case: no free thread slots
  printf("thread_create: no free slots\n");
}

void thread_yield(void) {
  current_thread->state = RUNNABLE;
  thread_schedule();
}

void thread_schedule(void) {
  struct thread *t, *next_thread;

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
  }
}
```

**File**: `user/uthread_switch.S`

**Reference Implementation (assembly)**:
```asm
	.text
	.globl thread_switch
thread_switch:
        /* a0 = address of old context, a1 = address of new context */

        /* save old context registers */
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

        /* restore new context registers */
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

        ret
```

**Key Concepts**:
- `sp` (stack pointer), `ra` (return address), `s0-s11` (callee-saved) — these 14 registers are the thread context.
- `sd` = store doubleword (8 bytes). `ld` = load doubleword.
- A newly created thread has `ra = func`, so the first `ret` after `thread_switch` jumps to `func`.
- Stack grows downward: `sp = stack_base + STACK_SIZE`.
- Cooperative: threads MUST call `thread_yield()` voluntarily. No preemption.

**Thread Lifecycle**:
```
thread_create(func)
  → sets state = RUNNABLE
  → sets context.ra = func
  → sets context.sp = top of stack
  
thread_schedule()
  → finds next RUNNABLE thread
  → calls thread_switch(old_ctx, new_ctx)
  
thread_switch(old, new) [assembly]
  → saves s0-s11, ra, sp to old
  → loads s0-s11, ra, sp from new
  → ret (jumps to new thread's ra)
```

---

### Task 2: ph-with-mutex-locks (Pthreads Hash Table)

**Objective**: Make a concurrent hash table thread-safe using per-bucket mutex locks.

**File**: `notxv6/ph-with-mutex-locks.c`

**Reference Implementation (key parts)**:
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
pthread_mutex_t locks[NBUCKET]; // One lock per bucket

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

  pthread_mutex_lock(&locks[i]);

  struct entry *e = 0;
  for (e = table[i]; e != 0; e = e->next) {
    if (e->key == key) break;
  }
  if (e) {
    e->value = value; // update
  } else {
    insert(key, value, &table[i], table[i]); // insert at head
  }

  pthread_mutex_unlock(&locks[i]);
}

static struct entry* get(int key) {
  int i = key % NBUCKET;

  pthread_mutex_lock(&locks[i]);

  struct entry *e = 0;
  for (e = table[i]; e != 0; e = e->next) {
    if (e->key == key) break;
  }

  pthread_mutex_unlock(&locks[i]);
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

  // Initialize per-bucket locks
  for (int i = 0; i < NBUCKET; i++) {
    pthread_mutex_init(&locks[i], NULL);
  }

  srandom(0);
  assert(NKEYS % nthread == 0);
  for (int i = 0; i < NKEYS; i++) {
    keys[i] = random();
  }

  // PUT phase
  t0 = now();
  for (int i = 0; i < nthread; i++) {
    assert(pthread_create(&tha[i], NULL, put_thread, (void *)(long)i) == 0);
  }
  for (int i = 0; i < nthread; i++) {
    assert(pthread_join(tha[i], &value) == 0);
  }
  t1 = now();
  printf("%d puts, %.3f seconds, %.0f puts/second\n",
         NKEYS, t1 - t0, NKEYS / (t1 - t0));

  // GET phase
  for (int i = 0; i < nthread; i++) {
    assert(pthread_create(&tha[i], NULL, get_thread, (void *)(long)i) == 0);
  }
  for (int i = 0; i < nthread; i++) {
    assert(pthread_join(tha[i], &value) == 0);
  }

  // Cleanup
  for (int i = 0; i < NBUCKET; i++) {
    pthread_mutex_destroy(&locks[i]);
  }

  return 0;
}
```

**Key Concepts**:
- Without locks: concurrent `put()` calls to the same bucket cause lost updates (race condition).
- **Per-bucket locking**: `pthread_mutex_t locks[NBUCKET]` allows parallelism across different buckets.
- **Global lock** (single mutex for entire table): correct but slow — kills all parallelism.
- `pthread_mutex_init(&lock, NULL)` / `pthread_mutex_destroy(&lock)` for lifecycle.
- Grading requirement: per-bucket locks must achieve ≥1.25x speedup over single-threaded for `ph_fast` test.

---

## Utility Functions Reference

### String Functions (user/ulib.c)
```c
char* strcpy(char *dst, const char *src);
int strcmp(const char *p, const char *q);  // 0 = equal
uint strlen(const char *s);
char* strchr(const char *s, char c);       // Returns pointer or 0
int atoi(const char *s);
```

### Memory Functions (user/ulib.c)
```c
void* memset(void *dst, int c, uint n);
void* memmove(void *dst, const void *src, int n);
void* memcpy(void *dst, const void *src, uint n);
int memcmp(const void *s1, const void *s2, uint n);  // 0 = equal
```

### Memory Allocation (user/umalloc.c)
```c
void* malloc(uint nbytes);
void free(void *ptr);
```

### I/O Functions (user/printf.c)
```c
void printf(const char *fmt, ...);
void fprintf(int fd, const char *fmt, ...);
```

**Printf Format Specifiers**:
| Specifier | Type | Description |
|-----------|------|-------------|
| `%d` | int | Signed decimal |
| `%x` | int | Hexadecimal |
| `%p` | void* | Pointer (hex) |
| `%s` | char* | String |
| `%c` | char | Character |
| `%l` | uint64 | Long decimal (xv6 specific) |

---

## Common Patterns & Templates

### Basic User Program Template
```c
#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(2, "Usage: %s <arg>\n", argv[0]);
        exit(1);
    }
    // Your code here
    exit(0);
}
```

### Pipe Usage Pattern (Two-Way)
```c
int p1[2], p2[2]; // p1: parent→child, p2: child→parent
pipe(p1);
pipe(p2);

if (fork() == 0) {
    // Child
    close(p1[1]); close(p2[0]);
    char buf;
    read(p1[0], &buf, 1);
    write(p2[1], &buf, 1);
    close(p1[0]); close(p2[1]);
    exit(0);
} else {
    // Parent
    close(p1[0]); close(p2[1]);
    char msg = 'A';
    write(p1[1], &msg, 1);
    read(p2[0], &msg, 1);
    close(p1[1]); close(p2[0]);
    wait(0);
}
```

### Fork/Exec Pattern
```c
if (fork() == 0) {
    exec(command, arguments);
    exit(1);  // Only reached if exec fails
} else {
    wait(0);
}
```

### Heap Scanning Pattern
```c
char *p = sbrk(size);
if (p == (char*)-1) exit(1);
for (int i = 0; i < size - marker_len - 64; i++) {
    if (memcmp(p + i, marker, marker_len) == 0) {
        // Found!
    }
}
```

### Thread Function Template (uthread)
```c
void my_thread_func(void) {
    for (int i = 0; i < 100; i++) {
        printf("thread %d\n", i);
        thread_yield(); // MUST yield cooperatively
    }
    current_thread->state = FREE;
    thread_schedule(); // Switch away, never returns
}
```

### Pthreads Thread Function Template
```c
static void *worker(void *xa) {
    int id = (int)(long)xa;
    // ... do work ...
    return NULL;
}

// Create:
pthread_create(&tid, NULL, worker, (void*)(long)i);
// Join:
pthread_join(tid, NULL);
```

---

## Syscall Addition Checklist

When adding a brand-new system call, modify these **7 files** in order:

| # | File | Change |
|---|------|--------|
| 1 | `kernel/syscall.h` | `#define SYS_mysyscall 23` |
| 2 | `kernel/syscall.c` | `extern uint64 sys_mysyscall(void);` and add to `syscalls[]` table |
| 3 | `kernel/sysproc.c` | Implement `uint64 sys_mysyscall(void) { ... }` |
| 4 | `kernel/defs.h` | Add prototype if calling helper functions from other `.c` files |
| 5 | `user/usys.pl` | `entry("mysyscall");` |
| 6 | `user/user.h` | `int mysyscall(int);` |
| 7 | `Makefile` | Add `$U/_testprog\` to `UPROGS` |

**Template for sysproc.c handler:**
```c
uint64
sys_mysyscall(void)
{
  int arg0;
  uint64 addr;
  argint(0, &arg0);    // first int argument
  argaddr(1, &addr);   // second pointer argument
  
  struct proc *p = myproc();
  // ... implementation ...
  
  // To copy data OUT to user space:
  if (copyout(p->pagetable, addr, (char *)&data, sizeof(data)) < 0)
    return -1;
  
  return 0;
}
```

---

## Testing & Grading

### Running Individual Tests
```bash
# Lab 3 tests
./grade-lab-syscall handshake
./grade-lab-syscall sniffer
./grade-lab-syscall monitor

# Lab 5 tests
./grade-lab-thread uthread
./grade-lab-thread ph_safe
./grade-lab-thread ph_fast
```

### Full Grade
```bash
make grade
```

### Test Cases Overview

**handshake**:
- Parent sends byte, child receives and echoes back

**sniffer**:
- Run `secret <string>`, then `sniffer` must find and print it

**monitor tests** (bitmask examples):
| Mask | Binary | Traces |
|------|--------|--------|
| `32` | `...100000` | `read` only (bit 5) |
| `2097152` | bit 21 | `close` only |
| `32896` | bits 7+15 | `exec` + `open` |
| `2147483647` | all 31 bits | all syscalls |

**uthread**: Verifies interleaved execution of 3 threads (a, b, c)

**ph_safe**: `0 keys missing` with 2 threads (no race condition)

**ph_fast**: Per-bucket lock must achieve ≥1.25x speedup over single-threaded

---

## Quick Reference Card

### RISC-V Registers
| Register | ABI Name | Usage | Saved By |
|----------|----------|-------|----------|
| x1 | ra | Return address | Callee |
| x2 | sp | Stack pointer | Callee |
| x8-x9 | s0-s1 | Callee-saved | Callee |
| x10-x17 | a0-a7 | Function args / return | Caller |
| x18-x27 | s2-s11 | Callee-saved | Callee |
| x28-x31 | t3-t6 | Temporaries | Caller |

### Struct proc Key Fields (kernel/proc.h)
| Field | Type | Description |
|-------|------|-------------|
| `pid` | int | Process ID |
| `name` | char[16] | Process name (set by exec) |
| `state` | enum | UNUSED/USED/SLEEPING/RUNNABLE/RUNNING/ZOMBIE |
| `pagetable` | pagetable_t | User page table |
| `trapframe` | struct trapframe* | Saved user registers |
| `monitor_mask` | uint32 | Syscall trace bitmask (Lab 3) |

### Trapframe Key Fields (a0-a7 for args)
| Field | Offset | Usage |
|-------|--------|-------|
| `a0` | | 1st arg / return value |
| `a1` | | 2nd arg |
| `a7` | | Syscall number |
| `epc` | | User program counter |

### Common Errors
| Error | Cause | Fix |
|-------|-------|-----|
| Pipe hangs | Didn't close unused ends | Close write end in reader, read end in writer |
| Zombie process | Parent didn't wait | Add `wait(0)` |
| sniffer OOB | Scanning past allocation | Use `size - marker_len - 64` as bound |
| Thread crash | No stack space | Set `context.sp = stack + STACK_SIZE` |
| Hash race | Missing locks | Add `pthread_mutex_lock/unlock` per bucket |

### Size Reference
| Type | Bytes |
|------|-------|
| char | 1 |
| short | 2 |
| int | 4 |
| uint64 | 8 |
| pointer | 8 |

---

*Generated for ICT1012 Operating Systems - Lab 3 & Lab 5 Reference*
