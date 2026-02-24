# Quiz 2 Predicted Scenarios — Part C: Monitor Extensions

> **Based on**: Lab3 `monitor.c` + kernel `syscall.c`/`sysproc.c`/`proc.h` — Syscall tracing via bitmask
> **Quiz 1 Pattern Applied**: Extend existing kernel functionality with new tracing feature

---

## Scenario C1: "monitor_args" — Trace Syscall Arguments

**Difficulty**: ★★★★★ (Hard)
**Concept Tested**: Kernel trap frame register access, RISC-V calling convention (a0-a5)

**Task Description**: Extend monitor to also print the first argument of each traced syscall. Output format changes from:
`PID: syscall NAME -> RETVAL` to `PID: syscall NAME(ARG0) -> RETVAL`

```
$ monitor 32 grep hello README
3: syscall read(3) -> 1023
3: syscall read(3) -> 402
3: syscall read(3) -> 0
```

### Implementation Steps

#### Modify `kernel/syscall.c` — `syscall()` function

```c
void
syscall(void)
{
  int num;
  struct proc *p = myproc();

  num = p->trapframe->a7;
  if(num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    // Save arg0 BEFORE the syscall executes (it may modify a0)
    uint64 arg0 = p->trapframe->a0;

    p->trapframe->a0 = syscalls[num]();

    // Print trace with the first argument
    if ((1 << num) & p->monitor_mask) {
      printf("%d: syscall %s(%d) -> %d\n",
             p->pid, syscall_names[num], (int)arg0, (int)p->trapframe->a0);
    }
  } else {
    printf("%d %s: unknown sys call %d\n",
            p->pid, p->name, num);
    p->trapframe->a0 = -1;
  }
}
```

> **Key Insight**: We must capture `a0` (the first argument) BEFORE calling the syscall handler, because `a0` is also used for the return value and gets overwritten.

---

## Scenario C2: "monitor_count" — Syscall Counting

**Difficulty**: ★★★★☆ (Moderate-Hard)
**Concept Tested**: Per-process kernel state, array management in kernel, sys_exit hook

**Task Description**: Instead of printing each syscall invocation, count them. When the process exits, print a summary of how many times each monitored syscall was called.

```
$ monitor_count 2147483647 grep hello README
...
3: syscall summary:
3:   exec: 1
3:   open: 1
3:   read: 4
3:   write: 2
3:   close: 2
```

### Implementation Steps

#### 1. `kernel/proc.h` — Add counter array
```c
struct proc {
  struct spinlock lock;
  uint32 monitor_mask;
  int syscall_counts[24];      // count for each syscall number

  // ... rest unchanged
};
```

#### 2. `kernel/proc.c` — Initialize counters in `allocproc()`
```c
// In allocproc(), after setting monitor_mask = 0:
p->monitor_mask = 0;
memset(p->syscall_counts, 0, sizeof(p->syscall_counts));
```

#### 3. `kernel/syscall.c` — Increment counters instead of printing
```c
void
syscall(void)
{
  int num;
  struct proc *p = myproc();

  num = p->trapframe->a7;
  if(num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    p->trapframe->a0 = syscalls[num]();

    // Count instead of print
    if ((1 << num) & p->monitor_mask) {
      p->syscall_counts[num]++;
    }
  } else {
    printf("%d %s: unknown sys call %d\n",
            p->pid, p->name, num);
    p->trapframe->a0 = -1;
  }
}
```

#### 4. `kernel/proc.c` — Print summary in `kexit()` (before cleanup)
```c
// At the beginning of kexit() / exit():
void
kexit(int status)
{
  struct proc *p = myproc();

  // Print syscall summary if any monitoring was active
  if (p->monitor_mask != 0) {
    printf("%d: syscall summary:\n", p->pid);
    for (int i = 1; i < 24; i++) {
      if (p->syscall_counts[i] > 0 && ((1 << i) & p->monitor_mask)) {
        printf("%d:   %s: %d\n", p->pid, syscall_names[i], p->syscall_counts[i]);
      }
    }
  }

  // ... rest of exit() unchanged
}
```

> **Note**: The `syscall_names` array must be accessible from `proc.c`. Either declare it `extern` or move it to a header.

---

## Scenario C3: "monitor_filter" — Filtered Tracing by Return Value

**Difficulty**: ★★★★☆ (Moderate-Hard)
**Concept Tested**: Extended syscall interface with multiple arguments, conditional tracing

**Task Description**: Add a second argument to monitor: a threshold. Only trace syscalls whose return value is greater than the threshold.

`monitor <mask> <threshold> <command> [args]`

```
$ monitor_filter 32 100 grep hello README
3: syscall read -> 1023
3: syscall read -> 402
```
(Skips `read -> 0` because 0 ≤ 100)

### Implementation Steps

#### 1. `kernel/proc.h` — Add threshold field
```c
struct proc {
  struct spinlock lock;
  uint32 monitor_mask;
  int monitor_threshold;
  // ...
};
```

#### 2. `kernel/sysproc.c` — Modify sys_monitor to accept 2 args
```c
uint64
sys_monitor(void)
{
  int mask;
  int threshold;
  argint(0, &mask);
  argint(1, &threshold);
  struct proc *p = myproc();
  p->monitor_mask = (uint32)mask;
  p->monitor_threshold = threshold;
  return 0;
}
```

#### 3. `user/user.h` — Update declaration
```c
int monitor(int, int);
```

#### 4. `kernel/syscall.c` — Filter trace output
```c
// In syscall(), after the syscall handler returns:
if ((1 << num) & p->monitor_mask) {
  if ((int)p->trapframe->a0 > p->monitor_threshold) {
    printf("%d: syscall %s -> %d\n", p->pid, syscall_names[num], (int)p->trapframe->a0);
  }
}
```

#### 5. `user/monitor_filter.c` — Updated user program
```c
#include "kernel/types.h"
#include "user/user.h"

int main(int argc, char *argv[]) {
  if (argc < 4) {
    fprintf(2, "Usage: monitor_filter <mask> <threshold> <command> [args...]\n");
    exit(1);
  }
  if (monitor(atoi(argv[1]), atoi(argv[2])) < 0) {
    fprintf(2, "monitor: failed\n");
    exit(1);
  }
  exec(argv[3], &argv[3]);
  exit(0);
}
```

---

## Scenario C4: "monitor_name" — Print Process Name in Trace

**Difficulty**: ★★★☆☆ (Moderate)
**Concept Tested**: Accessing proc struct fields from kernel context

**Task Description**: Extend monitor trace output to include the process name from `p->name`.

Output format: `PID(NAME): syscall SYSNAME -> RETVAL`

```
$ monitor 32 grep hello README
3(grep): syscall read -> 1023
3(grep): syscall read -> 402
3(grep): syscall read -> 0
```

### Implementation

#### Modify `kernel/syscall.c` — `syscall()` function
```c
if ((1 << num) & p->monitor_mask) {
  printf("%d(%s): syscall %s -> %d\n",
         p->pid, p->name, syscall_names[num], (int)p->trapframe->a0);
}
```

> **Note**: This is intentionally simple but tests understanding that `p->name` holds the process name set by `exec()`.

---

## Scenario C5: "monitor_inherit" — Control Mask Inheritance

**Difficulty**: ★★★★☆ (Moderate-Hard)
**Concept Tested**: Process creation (fork), inheritance semantics in kernel

**Task Description**: Add a flag to monitor that controls whether the mask is inherited by child processes. The original lab always inherits; this adds `monitor <mask> <inherit_flag> <command>`.

### Implementation Steps

#### 1. `kernel/proc.h` — Add inherit flag
```c
struct proc {
  struct spinlock lock;
  uint32 monitor_mask;
  int monitor_inherit;    // 0 = don't inherit, 1 = inherit
  // ...
};
```

#### 2. `kernel/sysproc.c`
```c
uint64
sys_monitor(void)
{
  int mask, inherit;
  argint(0, &mask);
  argint(1, &inherit);
  struct proc *p = myproc();
  p->monitor_mask = (uint32)mask;
  p->monitor_inherit = inherit;
  return 0;
}
```

#### 3. `kernel/proc.c` — Modify `kfork()` to check inherit flag
```c
// In kfork(), where child's fields are copied from parent:
if (p->monitor_inherit) {
  np->monitor_mask = p->monitor_mask;
  np->monitor_inherit = p->monitor_inherit;
} else {
  np->monitor_mask = 0;
  np->monitor_inherit = 0;
}
```

#### 4. `user/user.h`
```c
int monitor(int, int);
```

#### 5. `user/monitor_inherit.c`
```c
#include "kernel/types.h"
#include "user/user.h"

int main(int argc, char *argv[]) {
  if (argc < 4) {
    fprintf(2, "Usage: monitor_inherit <mask> <inherit:0|1> <command> [args...]\n");
    exit(1);
  }
  if (monitor(atoi(argv[1]), atoi(argv[2])) < 0) {
    fprintf(2, "monitor: failed\n");
    exit(1);
  }
  exec(argv[3], &argv[3]);
  exit(0);
}
```

---

## Scenario C6: "sysinfo" — New Syscall to Report System Info

**Difficulty**: ★★★★★ (Hard)
**Concept Tested**: Full syscall pipeline (user→kernel), accessing kernel data structures

**Task Description**: Add a new system call `int sysinfo(int *)` that writes system information into a user-space buffer: number of active processes, number of free memory pages, and system uptime in ticks.

### Implementation Steps

#### 1. `kernel/syscall.h`
```c
#define SYS_sysinfo 23
```

#### 2. `kernel/syscall.c`
```c
extern uint64 sys_sysinfo(void);

// In syscalls[]:
[SYS_sysinfo] sys_sysinfo,

// In syscall_names[]:
[SYS_sysinfo] "sysinfo",
```

#### 3. `kernel/sysproc.c`
```c
uint64
sys_sysinfo(void)
{
  uint64 addr;
  argaddr(0, &addr);

  int info[3];
  info[0] = count_active_procs();  // from proc.c
  info[1] = count_free_pages();    // from kalloc.c
  
  acquire(&tickslock);
  info[2] = ticks;
  release(&tickslock);

  struct proc *p = myproc();
  if (copyout(p->pagetable, addr, (char *)info, sizeof(info)) < 0)
    return -1;
  return 0;
}
```

#### 4. `kernel/proc.c` — Add process counter
```c
int
count_active_procs(void)
{
  int count = 0;
  struct proc *p;
  for (p = proc; p < &proc[NPROC]; p++) {
    acquire(&p->lock);
    if (p->state != UNUSED)
      count++;
    release(&p->lock);
  }
  return count;
}
```

#### 5. `kernel/kalloc.c` — Add free page counter
```c
int
count_free_pages(void)
{
  int count = 0;
  struct run *r;

  acquire(&kmem.lock);
  r = kmem.freelist;
  while (r) {
    count++;
    r = r->next;
  }
  release(&kmem.lock);
  return count;
}
```

#### 6. `kernel/defs.h`
```c
// proc.c
int             count_active_procs(void);

// kalloc.c
int             count_free_pages(void);
```

#### 7. `user/usys.pl`
```perl
entry("sysinfo");
```

#### 8. `user/user.h`
```c
int sysinfo(int *);
```

#### 9. `user/sysinfo.c` — Test program
```c
#include "kernel/types.h"
#include "user/user.h"

int main(void) {
  int info[3];
  if (sysinfo(info) < 0) {
    fprintf(2, "sysinfo failed\n");
    exit(1);
  }
  printf("Active processes: %d\n", info[0]);
  printf("Free pages: %d\n", info[1]);
  printf("Uptime (ticks): %d\n", info[2]);
  exit(0);
}
```
