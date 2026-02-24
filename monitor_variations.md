# Monitor (Syscall Tracing) — Coded Variations

> **Lab**: Monitor (Week 3) — Trace syscall invocations by bitmask.
> **Mechanism**: `monitor(mask)` sets `p->monitor_mask`; `syscall()` dispatcher checks `(mask >> num) & 1` after execution; prints `PID: syscall NAME -> RETVAL`.
> **Inheritance**: `fork()` copies `np->monitor_mask = p->monitor_mask`.
> **Source files**: `user/monitor.c`, `kernel/sysproc.c`, `kernel/syscall.c`, `kernel/proc.h`

---

## Syscall Dispatcher Flow (kernel/syscall.c)

```
               ┌─────────────────────────────┐
               │    num = p->trapframe->a7    │ ← syscall number
               │    arg0 = p->trapframe->a0   │ ← first arg (OVERWRITTEN by retval)
               │    arg1 = p->trapframe->a1   │ ← second arg
               └──────────────┬──────────────┘
                              ▼
               ┌─────────────────────────────┐
               │ p->trapframe->a0 =          │
               │     syscalls[num]();         │ ← EXECUTE syscall
               └──────────────┬──────────────┘
                              ▼
               ┌─────────────────────────────┐
               │ if ((mask >> num) & 1)       │
               │   printf("%d: syscall %s     │
               │          -> %d\n", pid,      │
               │          name, retval);      │ ← TRACE output
               └─────────────────────────────┘
```

> ⚠️ **Critical**: `a0` holds the first argument BEFORE execution, but is **overwritten** with the return value AFTER. To capture args, save them BEFORE calling `syscalls[num]()`.

---

## Core Boilerplate

### 1. `kernel/proc.h` — struct proc additions

```c
struct proc {
  // ... existing fields ...

  // ════════════════════════════════════════════
  // ════════ MODIFY HERE [PROC STRUCT] ════════
  // ════════════════════════════════════════════
  uint32 monitor_mask;               // bitmask of syscalls to trace
  // ════════ END PROC STRUCT ═════════════════
};
```

### 2. `kernel/sysproc.c` — sys_monitor()

```c
uint64
sys_monitor(void)
{
  // ════════════════════════════════════════════
  // ════════ MODIFY HERE [SYS_MONITOR] ════════
  // ════════════════════════════════════════════
  int mask;
  argint(0, &mask);
  struct proc *p = myproc();
  p->monitor_mask = (uint32)mask;
  return 0;
  // ════════ END SYS_MONITOR ═════════════════
}
```

### 3. `kernel/syscall.c` — syscall() dispatcher

```c
// Names array (already defined)
static const char *syscall_names[] = {
  [SYS_fork] "fork", [SYS_exit] "exit", [SYS_wait] "wait",
  [SYS_pipe] "pipe", [SYS_read] "read", [SYS_kill] "kill",
  [SYS_exec] "exec", [SYS_fstat] "fstat", [SYS_chdir] "chdir",
  [SYS_dup] "dup", [SYS_getpid] "getpid", [SYS_sbrk] "sbrk",
  [SYS_pause] "pause", [SYS_uptime] "uptime", [SYS_open] "open",
  [SYS_write] "write", [SYS_mknod] "mknod", [SYS_unlink] "unlink",
  [SYS_link] "link", [SYS_mkdir] "mkdir", [SYS_close] "close",
  [SYS_monitor] "monitor",
};

void
syscall(void)
{
  int num;
  struct proc *p = myproc();

  num = p->trapframe->a7;
  if(num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    // ════════════════════════════════════════════════════════
    // ════════ MODIFY HERE [SYSCALL DISPATCHER] ══════════════
    // (BEFORE execution — capture args here if needed)
    // ════════════════════════════════════════════════════════

    p->trapframe->a0 = syscalls[num]();    // ← EXECUTE

    // (AFTER execution — tracing logic goes here)
    if ((p->monitor_mask >> num) & 1)
      printf("%d: syscall %s -> %d\n",
             p->pid, syscall_names[num], p->trapframe->a0);

    // ════════ END SYSCALL DISPATCHER ═══════════════════════
  } else {
    printf("%d %s: unknown sys call %d\n", p->pid, p->name, num);
    p->trapframe->a0 = -1;
  }
}
```

### 4. `user/monitor.c` — User-space test program

```c
#include "kernel/types.h"
#include "user/user.h"

int main(int argc, char *argv[]) {
  if (argc < 3) {
    fprintf(2, "Usage: monitor <mask> <command> [args...]\n");
    exit(1);
  }

  // ════════════════════════════════════════════
  // ════════ MODIFY HERE [USER SPACE] ═════════
  // ════════════════════════════════════════════
  if (monitor(atoi(argv[1])) < 0) {
    fprintf(2, "monitor: failed\n");
    exit(1);
  }
  exec(argv[2], &argv[2]);
  // ════════ END USER SPACE ══════════════════

  exit(0);
}
```

### 5. `kernel/proc.c` — fork() inheritance

```c
// Inside fork(), after copying other fields:
np->monitor_mask = p->monitor_mask;    // inherit tracing mask
```

### Drop Zone Guide

| Zone | File | What goes here |
|------|------|---------------|
| `[PROC STRUCT]` | kernel/proc.h | Extra fields (counters, ring buffers, flags) |
| `[SYS_MONITOR]` | kernel/sysproc.c | Argument parsing, mask storage, extra setup |
| `[SYSCALL DISPATCHER]` | kernel/syscall.c | Before/after execution: capture args, trace, filter |
| `[USER SPACE]` | user/monitor.c | Argument parsing, extra syscalls, output |
| `[FORK]` | kernel/proc.c | What to copy (or NOT copy) to child |
| `[EXIT]` | kernel/proc.c | Aggregate printing at process exit |
| `[EXEC]` | kernel/exec.c | Name change detection, flag reset |

---

## Output Format Reference

```
PID: syscall NAME -> RETVAL
```
Example: `3: syscall read -> 1023`

---
---

# Pattern A — Logic Twists (M1–M12)

> **Scope**: Modify tracing **conditions**, **output format**, or **filtering logic**.
> **Rule**: Only the specified drop zones change.

---

## M1: Inverted Mask

> Trace syscalls **NOT** in the mask. If mask has bit 5 set (read), trace everything EXCEPT read.

**Dispatcher:**
```c
p->trapframe->a0 = syscalls[num]();

// Inverted: trace if bit is NOT set
if (!((p->monitor_mask >> num) & 1) && p->monitor_mask != 0)
    printf("%d: syscall %s -> %d\n",
           p->pid, syscall_names[num], p->trapframe->a0);
```

> 💡 Need `p->monitor_mask != 0` guard — otherwise processes with mask=0 (no tracing) would trace everything.

---

## M2: Only Failures

> Only print trace output when the syscall **returns a negative value** (error).

**Dispatcher:**
```c
p->trapframe->a0 = syscalls[num]();

if ((p->monitor_mask >> num) & 1) {
    int retval = (int)p->trapframe->a0;
    if (retval < 0)
        printf("%d: syscall %s FAILED -> %d\n",
               p->pid, syscall_names[num], retval);
}
```

---

## M3: Silent Monitor + Exit Log

> Don't print per-call output. Instead, **count** each traced syscall and print an aggregate summary when the process calls `exit()`.

**Proc Struct:**
```c
uint32 monitor_mask;
int syscall_counts[32];            // one counter per syscall number
```

**Dispatcher:**
```c
p->trapframe->a0 = syscalls[num]();

// Silently count instead of printing
if ((p->monitor_mask >> num) & 1)
    p->syscall_counts[num]++;
```

**Exit** (`kernel/proc.c`, inside `exit()`):
```c
// Before setting state to ZOMBIE:
if (p->monitor_mask) {
    printf("=== Monitor exit log for pid %d ===\n", p->pid);
    for (int i = 1; i < 32; i++) {
        if (p->syscall_counts[i] > 0)
            printf("  %s: %d calls\n", syscall_names[i], p->syscall_counts[i]);
    }
}
```

> ⚠️ `syscall_names[]` is in `syscall.c`. Either declare `extern` or move the print to syscall.c.

---

## M4: Sequence Number

> Add an **increasing sequence number** `[N]` to each trace line. Useful for ordering events.

**Proc Struct:**
```c
uint32 monitor_mask;
int monitor_seq;                   // sequence counter (starts at 0)
```

**Dispatcher:**
```c
p->trapframe->a0 = syscalls[num]();

if ((p->monitor_mask >> num) & 1)
    printf("[%d] %d: syscall %s -> %d\n",
           p->monitor_seq++, p->pid,
           syscall_names[num], p->trapframe->a0);
```

---

## M5: Timestamped

> Add the **current tick count** to trace output. Uses the global `ticks` variable (from `trap.c`).

**Dispatcher:**
```c
// At top of syscall.c: extern uint ticks;

p->trapframe->a0 = syscalls[num]();

if ((p->monitor_mask >> num) & 1)
    printf("%d@%d: syscall %s -> %d\n",
           p->pid, ticks, syscall_names[num], p->trapframe->a0);
```

> 💡 `ticks` is a global in `kernel/trap.c`, incremented by clock interrupt. Declare `extern uint ticks;` at top of `syscall.c`.

---

## M6: Two Arguments (a0 + a1)

> Print the **first two arguments** (a0, a1) alongside the trace. Must capture a0 **BEFORE** execution since it gets overwritten by the return value.

**Dispatcher:**
```c
// BEFORE execution: save arguments
uint64 arg0 = p->trapframe->a0;
uint64 arg1 = p->trapframe->a1;

p->trapframe->a0 = syscalls[num]();  // a0 is NOW the retval

if ((p->monitor_mask >> num) & 1)
    printf("%d: syscall %s(0x%x, 0x%x) -> %d\n",
           p->pid, syscall_names[num],
           arg0, arg1, p->trapframe->a0);
```

> ⚠️ **This is the most commonly tested gotcha**: `a0` is BOTH the first argument AND the return value register. You MUST save it before calling `syscalls[num]()`.

---

## M7: Stack Depth

> Print **kernel stack depth**: how far the stack pointer has moved from the base of the kernel stack.

**Dispatcher:**
```c
p->trapframe->a0 = syscalls[num]();

if ((p->monitor_mask >> num) & 1) {
    uint64 sp = p->trapframe->sp;
    printf("%d: syscall %s -> %d [sp=0x%x]\n",
           p->pid, syscall_names[num],
           p->trapframe->a0, sp);
}
```

> 💡 `p->trapframe->sp` is the user-space stack pointer at the time of the syscall. For kernel stack depth, use `(uint64)p->kstack + PGSIZE - read_sp()` inside the kernel (but `read_sp()` is not trivially available — user sp is more practical for exam).

---

## M8: Return Value Suppression

> **Don't print** trace if the return value is exactly 0. Only print non-zero returns.

**Dispatcher:**
```c
p->trapframe->a0 = syscalls[num]();

if ((p->monitor_mask >> num) & 1) {
    int retval = (int)p->trapframe->a0;
    if (retval != 0)
        printf("%d: syscall %s -> %d\n",
               p->pid, syscall_names[num], retval);
}
```

---

## M9: PID Range Filter

> Extend `sys_monitor` to take **3 arguments**: mask, lo_pid, hi_pid. Only trace for processes whose PID falls in `[lo, hi]`.

**Proc Struct:**
```c
uint32 monitor_mask;
int monitor_pid_lo;
int monitor_pid_hi;
```

**Sys_monitor:**
```c
uint64
sys_monitor(void)
{
  int mask, lo, hi;
  argint(0, &mask);
  argint(1, &lo);
  argint(2, &hi);
  struct proc *p = myproc();
  p->monitor_mask = (uint32)mask;
  p->monitor_pid_lo = lo;
  p->monitor_pid_hi = hi;
  return 0;
}
```

**Dispatcher:**
```c
p->trapframe->a0 = syscalls[num]();

if ((p->monitor_mask >> num) & 1) {
    if (p->pid >= p->monitor_pid_lo && p->pid <= p->monitor_pid_hi)
        printf("%d: syscall %s -> %d\n",
               p->pid, syscall_names[num], p->trapframe->a0);
}
```

**Fork:**
```c
np->monitor_pid_lo = p->monitor_pid_lo;
np->monitor_pid_hi = p->monitor_pid_hi;
```

---

## M10: Call Count Limit

> Stop tracing after **N traced syscalls**. Sys_monitor takes mask and limit.

**Proc Struct:**
```c
uint32 monitor_mask;
int monitor_limit;                 // max traces allowed
int monitor_count;                 // current count
```

**Sys_monitor:**
```c
uint64
sys_monitor(void)
{
  int mask, limit;
  argint(0, &mask);
  argint(1, &limit);
  struct proc *p = myproc();
  p->monitor_mask = (uint32)mask;
  p->monitor_limit = limit;
  p->monitor_count = 0;
  return 0;
}
```

**Dispatcher:**
```c
p->trapframe->a0 = syscalls[num]();

if ((p->monitor_mask >> num) & 1) {
    if (p->monitor_count < p->monitor_limit) {
        printf("%d: syscall %s -> %d\n",
               p->pid, syscall_names[num], p->trapframe->a0);
        p->monitor_count++;
    }
}
```

---

## M11: Parent Only (No Fork Inheritance)

> Monitor mask is **NOT** inherited by children. Only the process that calls `monitor()` is traced.

**Fork** (`kernel/proc.c`):
```c
// REMOVE or comment out this line:
// np->monitor_mask = p->monitor_mask;

// Replace with:
np->monitor_mask = 0;             // children don't inherit
```

> 💡 All other zones stay the same. The only change is in `fork()`.

---

## M12: Bitmask Display

> When `monitor()` is called, **print the binary representation** of the mask to the console.

**Sys_monitor:**
```c
uint64
sys_monitor(void)
{
  int mask;
  argint(0, &mask);
  struct proc *p = myproc();
  p->monitor_mask = (uint32)mask;

  // Print binary representation
  printf("monitor mask: 0b");
  for (int i = 31; i >= 0; i--)
      printf("%d", (mask >> i) & 1);
  printf(" (0x%x)\n", mask);

  return 0;
}
```

---

## Pattern A Quick Reference

| # | Name | Zone(s) Modified | Key Change | Complexity |
|---|------|-----------------|------------|------------|
| M1 | Inverted mask | Dispatcher | `!((mask >> num) & 1)` | Simple |
| M2 | Only failures | Dispatcher | `retval < 0` | Simple |
| M3 | Silent + exit log | Proc+Dispatcher+Exit | `syscall_counts[num]++`, print in `exit()` | Medium |
| M4 | Sequence # | Proc+Dispatcher | `monitor_seq++` | Simple |
| M5 | Timestamped | Dispatcher | `extern uint ticks` | Simple |
| M6 | Two arguments | Dispatcher | Save a0,a1 **BEFORE** execution | Medium |
| M7 | Stack depth | Dispatcher | `p->trapframe->sp` | Simple |
| M8 | Return suppress | Dispatcher | `retval != 0` | Simple |
| M9 | PID range | Proc+SysMon+Dispatcher+Fork | `pid >= lo && pid <= hi` | Medium |
| M10 | Count limit | Proc+SysMon+Dispatcher | `count < limit` | Medium |
| M11 | Parent only | Fork | `np->monitor_mask = 0` | Simple |
| M12 | Bitmask display | SysMon | `(mask >> i) & 1` loop | Simple |

---
---

# Pattern B — Feature Extensions (M13–M24)

> **Scope**: More advanced mutations — ring buffers, file output, global masks, syscall denial, latency measurement.
> **Rule**: Only the specified drop zones change.

---

## M13: Exec-Aware (Old Name → New Name)

> When `exec()` is called, print the **old process name** before it's overwritten, then the new name after. Tests understanding of when `p->name` changes.

**Dispatcher:**
```c
// BEFORE execution: save old name if syscall is exec
char oldname[16];
if (num == SYS_exec)
    memmove(oldname, p->name, sizeof(p->name));

p->trapframe->a0 = syscalls[num]();

if ((p->monitor_mask >> num) & 1) {
    if (num == SYS_exec && (int)p->trapframe->a0 >= 0)
        printf("%d: EXEC %s -> %s (retval %d)\n",
               p->pid, oldname, p->name, p->trapframe->a0);
    else
        printf("%d: syscall %s -> %d\n",
               p->pid, syscall_names[num], p->trapframe->a0);
}
```

> 💡 `exec()` overwrites `p->name` with the new binary name. Must save BEFORE calling `syscalls[num]()`.

---

## M14: Per-Syscall Max Return Value

> Track the **maximum return value** for each traced syscall. Print the summary at `exit()`.

**Proc Struct:**
```c
uint32 monitor_mask;
int syscall_max[32];               // max retval per syscall
int syscall_max_valid[32];         // flag: has any call been made?
```

**Dispatcher:**
```c
p->trapframe->a0 = syscalls[num]();

if ((p->monitor_mask >> num) & 1) {
    int retval = (int)p->trapframe->a0;
    printf("%d: syscall %s -> %d\n",
           p->pid, syscall_names[num], retval);
    if (!p->syscall_max_valid[num] || retval > p->syscall_max[num]) {
        p->syscall_max[num] = retval;
        p->syscall_max_valid[num] = 1;
    }
}
```

**Exit:**
```c
if (p->monitor_mask) {
    printf("=== Max return values for pid %d ===\n", p->pid);
    for (int i = 1; i < 32; i++) {
        if (p->syscall_max_valid[i])
            printf("  %s: max=%d\n", syscall_names[i], p->syscall_max[i]);
    }
}
```

---

## M15: Ring Buffer (Last 16 Events)

> Store the **last 16 traced events** in a circular buffer inside `struct proc`. New syscall `monitordump()` prints the buffer.

**Proc Struct:**
```c
uint32 monitor_mask;

struct monitor_event {
    int pid;
    int syscall_num;
    int retval;
} monitor_ring[16];
int monitor_ring_idx;              // next write position (mod 16)
int monitor_ring_count;            // total events stored
```

**Dispatcher:**
```c
p->trapframe->a0 = syscalls[num]();

if ((p->monitor_mask >> num) & 1) {
    int idx = p->monitor_ring_idx % 16;
    p->monitor_ring[idx].pid = p->pid;
    p->monitor_ring[idx].syscall_num = num;
    p->monitor_ring[idx].retval = (int)p->trapframe->a0;
    p->monitor_ring_idx++;
    if (p->monitor_ring_count < 16)
        p->monitor_ring_count++;
    // NO printf — silent recording
}
```

**New syscall `sys_monitordump` (sysproc.c):**
```c
uint64
sys_monitordump(void)
{
  struct proc *p = myproc();
  int start = (p->monitor_ring_count < 16) ? 0
              : p->monitor_ring_idx % 16;
  int count = p->monitor_ring_count < 16
              ? p->monitor_ring_count : 16;

  printf("=== Last %d events ===\n", count);
  for (int i = 0; i < count; i++) {
      int idx = (start + i) % 16;
      printf("[%d] pid=%d %s -> %d\n", i,
             p->monitor_ring[idx].pid,
             syscall_names[p->monitor_ring[idx].syscall_num],
             p->monitor_ring[idx].retval);
  }
  return count;
}
```

---

## M16: File Output (Write to FD)

> Write trace output to a **file descriptor** stored in `proc` instead of using kernel `printf`.

**Proc Struct:**
```c
uint32 monitor_mask;
int monitor_fd;                    // fd to write trace output to (-1 = console)
```

**Sys_monitor:**
```c
uint64
sys_monitor(void)
{
  int mask, fd;
  argint(0, &mask);
  argint(1, &fd);
  struct proc *p = myproc();
  p->monitor_mask = (uint32)mask;
  p->monitor_fd = fd;              // -1 means console (default)
  return 0;
}
```

**Dispatcher:**
```c
p->trapframe->a0 = syscalls[num]();

if ((p->monitor_mask >> num) & 1) {
    char buf[64];
    int len = snprintf(buf, sizeof(buf), "%d: syscall %s -> %d\n",
                       p->pid, syscall_names[num], p->trapframe->a0);
    if (p->monitor_fd >= 0) {
        // Write to file — need filewrite
        struct file *f = p->ofile[p->monitor_fd];
        if (f)
            filewrite(f, (uint64)buf, len);
    } else {
        printf("%s", buf);         // fallback to console
    }
}
```

> ⚠️ xv6 has no `snprintf`. Use kernel `printf` to console or manually format with `itoa`-style logic. The above is pseudocode for understanding — in exam, prefer `printf` directly.

---

## M17: Monitor Toggle

> New syscall `monitortoggle()` that **flips tracing on/off** without changing the mask. Uses a boolean flag.

**Proc Struct:**
```c
uint32 monitor_mask;
int monitor_enabled;               // 1 = active, 0 = paused
```

**Sys_monitor:**
```c
uint64
sys_monitor(void)
{
  int mask;
  argint(0, &mask);
  struct proc *p = myproc();
  p->monitor_mask = (uint32)mask;
  p->monitor_enabled = 1;         // enable by default
  return 0;
}
```

**New `sys_monitortoggle` (sysproc.c):**
```c
uint64
sys_monitortoggle(void)
{
  struct proc *p = myproc();
  p->monitor_enabled = !p->monitor_enabled;
  return p->monitor_enabled;       // returns new state
}
```

**Dispatcher:**
```c
p->trapframe->a0 = syscalls[num]();

if (p->monitor_enabled && (p->monitor_mask >> num) & 1)
    printf("%d: syscall %s -> %d\n",
           p->pid, syscall_names[num], p->trapframe->a0);
```

---

## M18: Diff Mode (Print Only When Changed)

> Only print trace when the **return value differs** from the previous call of the SAME syscall.

**Proc Struct:**
```c
uint32 monitor_mask;
int prev_retval[32];               // previous retval per syscall
int prev_valid[32];                // has a previous value been recorded?
```

**Dispatcher:**
```c
p->trapframe->a0 = syscalls[num]();

if ((p->monitor_mask >> num) & 1) {
    int retval = (int)p->trapframe->a0;
    if (!p->prev_valid[num] || retval != p->prev_retval[num]) {
        printf("%d: syscall %s -> %d (prev: %d)\n",
               p->pid, syscall_names[num], retval,
               p->prev_valid[num] ? p->prev_retval[num] : 0);
    }
    p->prev_retval[num] = retval;
    p->prev_valid[num] = 1;
}
```

---

## M19: Argument Names (Known Syscall Formats)

> Print **human-readable argument descriptions** for well-known syscalls using hardcoded format strings.

**Dispatcher:**
```c
uint64 arg0 = p->trapframe->a0;   // save BEFORE execution
uint64 arg1 = p->trapframe->a1;

p->trapframe->a0 = syscalls[num]();

if ((p->monitor_mask >> num) & 1) {
    int retval = (int)p->trapframe->a0;
    switch (num) {
    case SYS_read:
    case SYS_write:
        printf("%d: %s(fd=%d, buf=0x%x, n=%d) -> %d\n",
               p->pid, syscall_names[num],
               (int)arg0, arg1, (int)p->trapframe->a2, retval);
        break;
    case SYS_open:
        printf("%d: open(path=0x%x, mode=%d) -> %d\n",
               p->pid, arg0, (int)arg1, retval);
        break;
    case SYS_fork:
        printf("%d: fork() -> %d\n", p->pid, retval);
        break;
    default:
        printf("%d: syscall %s -> %d\n",
               p->pid, syscall_names[num], retval);
        break;
    }
}
```

> ⚠️ Must save a0, a1, a2 BEFORE `syscalls[num]()` — a0 gets overwritten!

---

## M20: Latency Measurement

> Measure **ticks before and after** each traced syscall. Print the delta (cost in ticks).

**Dispatcher:**
```c
// extern uint ticks; at top of file

uint t_before = 0;
if ((p->monitor_mask >> num) & 1)
    t_before = ticks;

p->trapframe->a0 = syscalls[num]();

if ((p->monitor_mask >> num) & 1) {
    uint t_after = ticks;
    printf("%d: syscall %s -> %d [%d ticks]\n",
           p->pid, syscall_names[num],
           p->trapframe->a0, t_after - t_before);
}
```

> 💡 For fast syscalls, delta is often 0 (timer granularity). Disk or pipe I/O will show non-zero deltas.

---

## M21: Global Monitor (System-Wide Mask)

> A **single global mask** that traces ALL processes, not just the one that called `monitor()`.

**Dispatcher (global variable at top of syscall.c):**
```c
uint32 global_monitor_mask = 0;    // system-wide trace mask
```

**Sys_monitor:**
```c
uint64
sys_monitor(void)
{
  int mask;
  argint(0, &mask);
  // Set GLOBAL mask instead of per-process
  global_monitor_mask = (uint32)mask;
  return 0;
}
```

**Dispatcher:**
```c
p->trapframe->a0 = syscalls[num]();

uint32 effective_mask = p->monitor_mask | global_monitor_mask;
if ((effective_mask >> num) & 1)
    printf("%d: syscall %s -> %d\n",
           p->pid, syscall_names[num], p->trapframe->a0);
```

> 💡 Combines per-process and global masks with `|`. Any process can enable global tracing, and all processes see it.

---

## M22: Monitor with Deny (Syscall Blocking)

> Instead of tracing, **BLOCK** syscalls whose bit is set in a `deny_mask`. Return -1 without executing.

**Proc Struct:**
```c
uint32 monitor_mask;               // trace mask (normal)
uint32 deny_mask;                  // deny mask (block these)
```

**Sys_monitor:**
```c
uint64
sys_monitor(void)
{
  int mask, deny;
  argint(0, &mask);
  argint(1, &deny);
  struct proc *p = myproc();
  p->monitor_mask = (uint32)mask;
  p->deny_mask = (uint32)deny;
  return 0;
}
```

**Dispatcher:**
```c
// BEFORE execution: check deny mask
if ((p->deny_mask >> num) & 1) {
    printf("%d: syscall %s DENIED\n",
           p->pid, syscall_names[num]);
    p->trapframe->a0 = -1;        // fake failure
    return;                        // don't execute!
}

p->trapframe->a0 = syscalls[num]();

if ((p->monitor_mask >> num) & 1)
    printf("%d: syscall %s -> %d\n",
           p->pid, syscall_names[num], p->trapframe->a0);
```

> ⚠️ The deny check goes BEFORE `syscalls[num]()`. The `return;` skips syscall execution entirely.

---

## M23: Process Name After Exec

> Print `p->name` in the trace output. Verifies that **exec updates the process name** correctly.

**Dispatcher:**
```c
p->trapframe->a0 = syscalls[num]();

if ((p->monitor_mask >> num) & 1)
    printf("%d(%s): syscall %s -> %d\n",
           p->pid, p->name,
           syscall_names[num], p->trapframe->a0);
```

> 💡 `p->name` is set by `exec()` to the basename of the executable path. Before exec, it's the parent's name (e.g., "sh"). After exec, it changes to the new program name.

---

## M24: Color Codes (Error Prefix)

> Print a `[!]` prefix for **error returns** (negative) and `[ ]` for success. Quick visual scanning during debugging.

**Dispatcher:**
```c
p->trapframe->a0 = syscalls[num]();

if ((p->monitor_mask >> num) & 1) {
    int retval = (int)p->trapframe->a0;
    char *prefix = (retval < 0) ? "[!]" : "[ ]";
    printf("%s %d: syscall %s -> %d\n",
           prefix, p->pid, syscall_names[num], retval);
}
```

> 💡 xv6 console has no ANSI color support. Use text prefixes like `[!]`, `[ERR]`, `[OK]` instead.

---

## Pattern B Quick Reference

| # | Name | Zone(s) Modified | Key Change | Complexity |
|---|------|-----------------|------------|------------|
| M13 | Exec-aware | Dispatcher | Save `oldname` before exec, print old→new | Medium |
| M14 | Max retval | Proc+Dispatcher+Exit | `syscall_max[num]` tracking | Medium |
| M15 | Ring buffer | Proc+Dispatcher+NewSyscall | `monitor_ring[16]`, `monitordump()` | Hard |
| M16 | File output | Proc+SysMon+Dispatcher | `monitor_fd`, `filewrite()` | Hard |
| M17 | Toggle | Proc+NewSyscall+Dispatcher | `monitor_enabled` flip | Medium |
| M18 | Diff mode | Proc+Dispatcher | `prev_retval[num]` compare | Medium |
| M19 | Arg names | Dispatcher | Save a0/a1/a2, switch on `num` | Medium |
| M20 | Latency | Dispatcher | `ticks` before/after delta | Medium |
| M21 | Global mask | Global+SysMon+Dispatcher | `global_monitor_mask \| p->mask` | Medium |
| M22 | Deny | Proc+SysMon+Dispatcher | Block BEFORE execution, return -1 | Hard |
| M23 | Name in output | Dispatcher | `p->name` in printf | Simple |
| M24 | Error prefix | Dispatcher | `[!]` for retval < 0 | Simple |

---
---

# Pattern C — Combo Tasks (M25–M35)

> **Scope**: Each variation is a **two-part combo**: kernel code (new syscall in `sysproc.c` or modification in `proc.c`/`syscall.c`) + user-space test program.
> **Kernel structures verified from xv6-src-booklet**: `enum procstate { UNUSED, USED, SLEEPING, RUNNABLE, RUNNING, ZOMBIE }`, `struct proc proc[NPROC]`, `p->parent`, `safestrcpy`, `copyout`, `argstr`, `wait_lock`.

---

## M25: `getsyscallcount` — Total Syscalls Made

> Adds a **counter** to each process that increments on EVERY syscall. New syscall returns the total count.

**Proc Struct:**
```c
uint32 monitor_mask;
int total_syscalls;                // total syscalls made by this process
```

**Dispatcher (add to syscall(), always runs):**
```c
p->total_syscalls++;               // count ALL syscalls, not just traced

p->trapframe->a0 = syscalls[num]();

if ((p->monitor_mask >> num) & 1)
    printf("%d: syscall %s -> %d\n",
           p->pid, syscall_names[num], p->trapframe->a0);
```

**Kernel (`sysproc.c`):**
```c
uint64
sys_getsyscallcount(void)
{
  return myproc()->total_syscalls;
}
```

**User program:**
```c
#include "kernel/types.h"
#include "user/user.h"

int main() {
    // These syscalls increment the counter:
    getpid();
    getpid();
    getpid();
    int count = getsyscallcount();
    // count should be >= 4 (3 getpids + 1 getsyscallcount)
    printf("total syscalls: %d\n", count);
    exit(0);
}
```

---

## M26: `setprocname` — Change Process Name

> Syscall that copies a user-space string into `p->name`. Uses `argstr()` to safely fetch from user space.

**Kernel (`sysproc.c`):**
```c
uint64
sys_setprocname(void)
{
  char name[16];
  if (argstr(0, name, sizeof(name)) < 0)
      return -1;
  struct proc *p = myproc();
  safestrcpy(p->name, name, sizeof(p->name));
  return 0;
}
```

**User program:**
```c
#include "kernel/types.h"
#include "user/user.h"

int main() {
    printf("name before: (check with ctrl+p)\n");
    setprocname("mytest");
    printf("name after: (check with ctrl+p)\n");
    // p->name should now show "mytest" in process listing
    exit(0);
}
```

> 💡 `argstr(n, buf, max)` copies the n-th syscall argument (a user-space pointer) safely into `buf`. `safestrcpy` is null-terminating.

---

## M27: `procstate` — Get Current Process State

> Returns the calling process's **state as an integer** (0=UNUSED, 1=USED, 2=SLEEPING, 3=RUNNABLE, 4=RUNNING, 5=ZOMBIE).

**Kernel (`sysproc.c`):**
```c
uint64
sys_procstate(void)
{
  return myproc()->state;  // always RUNNING when in syscall handler
}
```

**User program:**
```c
#include "kernel/types.h"
#include "user/user.h"

int main() {
    int state = procstate();
    // Should always be 4 (RUNNING) — because we're executing!
    printf("my state: %d (RUNNING=4)\n", state);

    // States: 0=UNUSED 1=USED 2=SLEEPING 3=RUNNABLE 4=RUNNING 5=ZOMBIE
    char *names[] = {"UNUSED","USED","SLEEPING","RUNNABLE","RUNNING","ZOMBIE"};
    if (state >= 0 && state <= 5)
        printf("state name: %s\n", names[state]);
    exit(0);
}
```

> 💡 A process calling a syscall is always in RUNNING state. This is mostly useful when queried about OTHER processes.

---

## M28: `getchildren` — List Child PIDs

> Iterates the **proc table**, finds all processes whose `parent == myproc()`, and copies their PIDs to user space via `copyout`.

**Kernel (`sysproc.c`):**
```c
// extern struct proc proc[]; at top, or #include "proc.h"

uint64
sys_getchildren(void)
{
  uint64 addr;       // user buffer address
  int max;           // max children to return
  argaddr(0, &addr);
  argint(1, &max);

  struct proc *p = myproc();
  struct proc *pp;
  int pids[16];      // kernel-side buffer
  int count = 0;

  acquire(&wait_lock);  // required when accessing p->parent
  for (pp = proc; pp < &proc[NPROC]; pp++) {
      if (pp->parent == p && pp->state != UNUSED) {
          if (count < max && count < 16)
              pids[count++] = pp->pid;
      }
  }
  release(&wait_lock);

  // Copy to user space
  if (copyout(p->pagetable, addr, (char*)pids, count * sizeof(int)) < 0)
      return -1;
  return count;
}
```

**User program:**
```c
#include "kernel/types.h"
#include "user/user.h"

int main() {
    // Fork 3 children
    for (int i = 0; i < 3; i++) {
        int pid = fork();
        if (pid == 0) {
            sleep(10);  // child stays alive
            exit(0);
        }
    }
    sleep(1);  // let children start

    int pids[16];
    int n = getchildren(pids, 16);
    printf("found %d children:\n", n);
    for (int i = 0; i < n; i++)
        printf("  child pid: %d\n", pids[i]);

    // Wait for all children
    for (int i = 0; i < 3; i++) wait(0);
    exit(0);
}
```

> ⚠️ `wait_lock` must be held when reading `pp->parent`. `copyout(pagetable, user_va, kernel_src, len)` copies from kernel to user space.

---

## M29: Monitor + Sniffer Combo

> Set monitor mask to trace `sbrk` calls, then exec the sniffer. See every `sbrk` allocation as it happens during sniffing.

> ⚠️ **Standalone user program** — no kernel changes:
```c
#include "kernel/types.h"
#include "kernel/syscall.h"
#include "user/user.h"

int main() {
    // Trace sbrk (syscall #12)
    int mask = (1 << SYS_sbrk);
    monitor(mask);

    printf("== monitoring sbrk, running sniffer ==\n");

    char *argv[] = {"sniffer", 0};
    exec("sniffer", argv);

    // If exec fails:
    printf("exec failed\n");
    exit(1);
}
```

> 💡 Output will show every `sbrk` call made by the sniffer with its return value (the old break pointer).

---

## M30: Syscall Whitelist (`restrict`)

> New syscall `restrict(mask)` that **BLOCKS** any syscall whose bit is NOT set in the whitelist mask. Like M22 (deny) but inverted — only whitelisted syscalls execute.

**Proc Struct:**
```c
uint32 monitor_mask;
uint32 restrict_mask;              // whitelist: only these execute
```

**Kernel (`sysproc.c`):**
```c
uint64
sys_restrict(void)
{
  int mask;
  argint(0, &mask);
  struct proc *p = myproc();
  p->restrict_mask = (uint32)mask;
  return 0;
}
```

**Dispatcher:**
```c
// BEFORE execution: check whitelist
if (p->restrict_mask != 0 && !((p->restrict_mask >> num) & 1)) {
    printf("%d: syscall %s BLOCKED (not whitelisted)\n",
           p->pid, syscall_names[num]);
    p->trapframe->a0 = -1;
    return;
}

p->trapframe->a0 = syscalls[num]();

if ((p->monitor_mask >> num) & 1)
    printf("%d: syscall %s -> %d\n",
           p->pid, syscall_names[num], p->trapframe->a0);
```

**User program:**
```c
#include "kernel/types.h"
#include "kernel/syscall.h"
#include "user/user.h"

int main() {
    // Only allow: exit, write, getpid
    int whitelist = (1 << SYS_exit) | (1 << SYS_write) | (1 << SYS_getpid);
    restrict(whitelist);

    int pid = getpid();   // allowed
    printf("pid=%d\n", pid);  // write = allowed

    int fd = open("README", 0);  // BLOCKED!
    printf("open returned: %d (should be -1)\n", fd);
    exit(0);
}
```

> 💡 `restrict_mask != 0` guard ensures unset processes aren't blocked. Set to 0 to disable whitelist.

---

## M31: Syscall Renaming

> Add a **custom_names** array to proc. New `sysrename(num, name)` syscall changes the display name for a specific syscall in trace output.

**Proc Struct:**
```c
uint32 monitor_mask;
char custom_names[32][16];         // custom display names per syscall
int has_custom_name[32];           // flag: use custom name?
```

**Kernel (`sysproc.c`):**
```c
uint64
sys_sysrename(void)
{
  int num;
  char name[16];
  argint(0, &num);
  if (argstr(1, name, sizeof(name)) < 0)
      return -1;
  if (num < 1 || num >= 32)
      return -1;

  struct proc *p = myproc();
  safestrcpy(p->custom_names[num], name, 16);
  p->has_custom_name[num] = 1;
  return 0;
}
```

**Dispatcher:**
```c
p->trapframe->a0 = syscalls[num]();

if ((p->monitor_mask >> num) & 1) {
    char *name = p->has_custom_name[num]
                 ? p->custom_names[num]
                 : (char*)syscall_names[num];
    printf("%d: syscall %s -> %d\n", p->pid, name, p->trapframe->a0);
}
```

---

## M32: Monitored Exec Chain

> Verify that the monitor mask **persists through multiple exec() calls**. Program A execs B, B execs C, all traced.

> ⚠️ **Standalone user program** — no kernel changes:
```c
#include "kernel/types.h"
#include "kernel/syscall.h"
#include "user/user.h"

int main(int argc, char *argv[]) {
    if (argc >= 2 && argv[1][0] == 'C') {
        // Stage C — final program
        printf("stage C: mask still active!\n");
        getpid();  // should be traced
        exit(0);
    }
    if (argc >= 2 && argv[1][0] == 'B') {
        // Stage B — exec into C
        printf("stage B: exec -> C\n");
        char *args[] = {"execchain", "C", 0};
        exec("execchain", args);
        exit(1);
    }

    // Stage A — set mask, exec into B
    monitor((1 << SYS_exec) | (1 << SYS_getpid));
    printf("stage A: mask set, exec -> B\n");
    char *args[] = {"execchain", "B", 0};
    exec("execchain", args);
    exit(1);
}
```

> 💡 `exec()` replaces the process image but does NOT reset `p->monitor_mask` (it's in `struct proc`, not in the user-space binary). Mask persists across all exec calls.

---

## M33: Buffered Trace + `flushtrace`

> Instead of printing each trace immediately, **buffer** up to 32 events. New `flushtrace()` syscall prints them all at once.

**Proc Struct:**
```c
uint32 monitor_mask;
struct {
    int pid;
    int num;
    int retval;
} trace_buf[32];
int trace_buf_count;
```

**Dispatcher:**
```c
p->trapframe->a0 = syscalls[num]();

if ((p->monitor_mask >> num) & 1) {
    if (p->trace_buf_count < 32) {
        int idx = p->trace_buf_count++;
        p->trace_buf[idx].pid = p->pid;
        p->trace_buf[idx].num = num;
        p->trace_buf[idx].retval = (int)p->trapframe->a0;
    }
    // NO printf — silent buffering
}
```

**Kernel (`sysproc.c`):**
```c
uint64
sys_flushtrace(void)
{
  struct proc *p = myproc();
  printf("=== Buffered trace (%d events) ===\n", p->trace_buf_count);
  for (int i = 0; i < p->trace_buf_count; i++) {
      printf("[%d] %d: syscall %s -> %d\n", i,
             p->trace_buf[i].pid,
             syscall_names[p->trace_buf[i].num],
             p->trace_buf[i].retval);
  }
  int count = p->trace_buf_count;
  p->trace_buf_count = 0;  // clear buffer
  return count;
}
```

**User program:**
```c
#include "kernel/types.h"
#include "kernel/syscall.h"
#include "user/user.h"

int main() {
    monitor(0x7FFFFFFF);  // trace all
    getpid();
    getpid();
    uptime();
    int n = flushtrace();  // prints all buffered events
    printf("flushed %d events\n", n);
    exit(0);
}
```

---

## M34: Fork Counter

> Track the **number of forks** a process has performed. Increment in `kfork()`, read via new `getforkcount()` syscall.

**Proc Struct:**
```c
uint32 monitor_mask;
int fork_count;                    // number of times this proc forked
```

**Fork** (`kernel/proc.c`, inside `kfork()`, before return):
```c
p->fork_count++;                   // parent's counter
np->fork_count = 0;                // child starts at 0
```

**Kernel (`sysproc.c`):**
```c
uint64
sys_getforkcount(void)
{
  return myproc()->fork_count;
}
```

**User program:**
```c
#include "kernel/types.h"
#include "user/user.h"

int main() {
    for (int i = 0; i < 5; i++) {
        int pid = fork();
        if (pid == 0) exit(0);
        wait(0);
    }
    int count = getforkcount();
    printf("forked %d times (expected 5)\n", count);
    exit(0);
}
```

---

## M35: Monitor Exclusive (One at a Time)

> Only **one process globally** can hold a monitor mask at a time. Second call fails with -1.

**Global variable (top of `syscall.c`):**
```c
int monitor_owner_pid = -1;        // PID of sole monitor holder, -1 = none
```

**Sys_monitor:**
```c
uint64
sys_monitor(void)
{
  int mask;
  argint(0, &mask);
  struct proc *p = myproc();

  if (mask != 0) {
      // Try to acquire exclusive lock
      if (monitor_owner_pid != -1 && monitor_owner_pid != p->pid) {
          printf("monitor: pid %d denied (owned by %d)\n",
                 p->pid, monitor_owner_pid);
          return -1;
      }
      monitor_owner_pid = p->pid;
  } else {
      // Releasing: mask=0
      if (monitor_owner_pid == p->pid)
          monitor_owner_pid = -1;
  }

  p->monitor_mask = (uint32)mask;
  return 0;
}
```

**User program:**
```c
#include "kernel/types.h"
#include "user/user.h"

int main() {
    if (monitor(0x7FFFFFFF) < 0) {
        printf("monitor denied!\n");
        exit(1);
    }
    printf("monitor acquired\n");

    int pid = fork();
    if (pid == 0) {
        // Child tries to monitor — should fail
        int ret = monitor(0x7FFFFFFF);
        printf("child monitor returned: %d (expect -1)\n", ret);
        exit(0);
    }
    wait(0);
    monitor(0);  // release
    printf("monitor released\n");
    exit(0);
}
```

---

## Pattern C Quick Reference

| # | Name | Syscall | Key Concept |
|---|------|---------|-------------|
| M25 | getsyscallcount | `sys_getsyscallcount` | Counter in dispatcher, always increments |
| M26 | setprocname | `sys_setprocname` | `argstr()` + `safestrcpy(p->name)` |
| M27 | procstate | `sys_procstate` | Returns p->state (always RUNNING=4) |
| M28 | getchildren | `sys_getchildren` | `wait_lock` + proc iteration + `copyout` |
| M29 | monitor+sniffer | — (user only) | `monitor(1<<SYS_sbrk)` then exec sniffer |
| M30 | syscall whitelist | `sys_restrict` | Inverted deny: block if NOT in mask |
| M31 | syscall renaming | `sys_sysrename` | `custom_names[num]` per process |
| M32 | exec chain | — (user only) | Mask persists through exec (not reset) |
| M33 | buffered trace | `sys_flushtrace` | `trace_buf[32]`, print all at once |
| M34 | fork counter | `sys_getforkcount` | `p->fork_count++` in kfork() |
| M35 | exclusive monitor | — (modified sys_monitor) | Global `monitor_owner_pid` lock |

---
---

# Pattern D — Mutation Dimensions (M36–M51)

> **Scope**: Edge cases, stress tests, and behavioural verification for the monitor boilerplate.
> **Rule**: Only the specified drop zones change (unless noted as standalone).

---

## M36: Mask with SYS_exit

> Verify that `exit()` **is traced before the process terminates**. The trace print happens BEFORE the actual exit logic runs.

**User Space:**
```c
#include "kernel/types.h"
#include "kernel/syscall.h"
#include "user/user.h"

int main() {
    monitor(1 << SYS_exit);
    printf("about to exit...\n");
    exit(0);
    // Expected output: "PID: syscall exit -> 0" (printed by dispatcher)
}
```

> 💡 The trace fires inside `syscall()` AFTER `sys_exit()` is called. But `sys_exit()` calls `kexit()` which never returns — so the dispatcher trace actually runs BEFORE kexit's sched(). This works because `kexit()` doesn't return to `syscall()`.

> ⚠️ **Gotcha**: Actually, `kexit()` calls `sched()` and never returns. So the trace line after `syscalls[num]()` is actually NOT reached for exit. If the exam asks "does exit get traced?", answer: **NO** with the standard dispatcher — `sys_exit` never returns, so the printf after it never executes. To trace exit, you must print BEFORE execution.

---

## M37: Mask with SYS_monitor

> Trace the `monitor()` syscall itself. Creates a meta-trace.

**User Space:**
```c
#include "kernel/types.h"
#include "kernel/syscall.h"
#include "user/user.h"

int main() {
    // Trace all syscalls including monitor itself
    monitor(0x7FFFFFFF);
    // Expected: "PID: syscall monitor -> 0" appears in output
    printf("hello\n");
    exit(0);
}
```

> 💡 The monitor syscall's own trace appears because the mask is set before the trace check runs (it returns 0, then the dispatcher checks the mask bit for SYS_monitor).

---

## M38: Mask = 0 (No Output)

> With mask=0, **no syscall should be traced**. Verify silence.

**User Space:**
```c
monitor(0);
// Do many syscalls
getpid();
uptime();
printf("no trace output expected above\n");
exit(0);
```

> 💡 `(0 >> num) & 1` is always 0. No bits set = no tracing.

---

## M39: Mask = -1 (All Bits Set)

> Pass `-1` (0xFFFFFFFF) to trace **every possible syscall**. Stress test output.

**User Space:**
```c
monitor(-1);   // -1 as int = 0xFFFFFFFF as uint32
// Every syscall will be traced
getpid();
printf("traced\n");
exit(0);   // exit trace depends on dispatcher placement
```

> 💡 `(uint32)-1 == 0xFFFFFFFF`. All 32 bits set. Since `(0xFFFFFFFF >> num) & 1` is always 1 for any valid `num`, every syscall is traced.

---

## M40: Monitor After Exec

> Set mask in parent, exec a new program, verify the child program's syscalls are still traced.

> ⚠️ **Standalone** — no kernel changes:
```c
#include "kernel/types.h"
#include "kernel/syscall.h"
#include "user/user.h"

int main(int argc, char *argv[]) {
    if (argc > 1) {
        // After exec — just do some syscalls
        printf("post-exec: ");
        getpid();
        exit(0);
    }
    // Before exec — set mask
    monitor(0x7FFFFFFF);
    char *args[] = {"monexec", "child", 0};
    exec("monexec", args);
    exit(1);
}
```

> 💡 `monitor_mask` lives in `struct proc`, NOT in the executable. `exec()` replaces code+data but keeps the proc struct intact. Mask persists.

---

## M41: Monitor + Zombie Child

> Fork a child that exits immediately (becomes ZOMBIE). Parent traces `fork` and `wait`. Observe the lifecycle.

> ⚠️ **Standalone:**
```c
#include "kernel/types.h"
#include "kernel/syscall.h"
#include "user/user.h"

int main() {
    monitor((1 << SYS_fork) | (1 << SYS_wait) | (1 << SYS_exit));

    int pid = fork();
    if (pid == 0) {
        exit(42);  // child becomes ZOMBIE
    }

    sleep(5);      // let child become zombie
    int status;
    int w = wait(&status);
    printf("reaped child %d with status %d\n", w, status);
    exit(0);
}
```

> 💡 Expected trace: `fork -> child_pid`, then after sleep, `wait -> child_pid`. Child's `exit` may or may not trace (see M36).

---

## M42: Monitor + File Operations

> Trace the full lifecycle of a file: `open → read → write → close`.

**User Space:**
```c
#include "kernel/types.h"
#include "kernel/syscall.h"
#include "kernel/fcntl.h"
#include "user/user.h"

int main() {
    int mask = (1 << SYS_open) | (1 << SYS_read) |
               (1 << SYS_write) | (1 << SYS_close);
    monitor(mask);

    int fd = open("README", O_RDONLY);
    if (fd >= 0) {
        char buf[64];
        int n = read(fd, buf, sizeof(buf));
        write(1, buf, n);   // write to stdout (also traced)
        close(fd);
    }
    exit(0);
}
```

> 💡 Expected: `open -> 3`, `read -> 64`, `write -> 64`, `close -> 0`.

---

## M43: Double Monitor Call

> Call `monitor()` twice. The **second call overwrites** the first mask.

**User Space:**
```c
#include "kernel/types.h"
#include "kernel/syscall.h"
#include "user/user.h"

int main() {
    monitor(1 << SYS_read);   // trace read
    monitor(1 << SYS_write);  // OVERWRITES: now trace write only

    int fd = open("README", 0);
    char buf[32];
    read(fd, buf, 32);   // NOT traced (read bit no longer set)
    write(1, buf, 32);   // TRACED (write bit is set)
    close(fd);
    exit(0);
}
```

> 💡 `sys_monitor` does `p->monitor_mask = (uint32)mask` — a simple assignment, not OR. Second call replaces the first.

---

## M44: Monitor Thread-Aware (xv6 Limitation)

> xv6 has **no threads** and no `clone()` syscall. All "processes" are full processes with separate address spaces. This variation documents the limitation.

**Explanation:**
```c
// xv6 has NO thread support:
// - No clone() syscall
// - No shared address space between processes
// - fork() creates a FULL copy (COW not implemented in base xv6)
// - monitor_mask is per-process, which IS per-"thread" in xv6
//
// In Linux, strace traces per-thread because clone() shares struct task.
// In xv6, every "thread" is a separate process, so per-process tracing
// IS per-thread tracing. No special handling needed.
//
// If exam asks: "Does forked child inherit monitor mask?"
// Answer: YES, because fork() copies np->monitor_mask = p->monitor_mask
```

---

## M45: Negative Mask (Unsigned Interpretation)

> Pass a **negative integer** as mask. C stores it in two's complement; when cast to `uint32`, it becomes a large positive number with many bits set.

**User Space:**
```c
#include "kernel/types.h"
#include "user/user.h"

int main() {
    // -1 → 0xFFFFFFFF → all bits set
    monitor(-1);
    getpid();   // traced
    uptime();   // traced
    printf("negative mask = all bits\n");

    // -2 → 0xFFFFFFFE → all bits except bit 0
    monitor(-2);
    // bit 0 (unused) is clear, all others set
    exit(0);
}
```

> 💡 `sys_monitor` uses `argint(0, &mask)` which reads a signed int, then casts to `(uint32)mask`. The cast preserves the bit pattern. `-1` = `0xFFFFFFFF`.

---

## M46: Monitor Across 10 Children

> Fork **10 children**, all inheriting the mask. Verify each child traces independently.

> ⚠️ **Standalone:**
```c
#include "kernel/types.h"
#include "kernel/syscall.h"
#include "user/user.h"

int main() {
    monitor(1 << SYS_getpid);

    for (int i = 0; i < 10; i++) {
        int pid = fork();
        if (pid == 0) {
            getpid();  // each child traces this
            exit(0);
        }
    }
    // Parent waits for all
    for (int i = 0; i < 10; i++) wait(0);
    printf("all 10 children traced getpid\n");
    exit(0);
}
```

> 💡 Each child has its own `monitor_mask` copy, so each independently prints its trace line with its own PID.

---

## M47: Monitor with Killed Process

> Fork a child, set it monitoring, then **kill** it from the parent. Observe that tracing stops cleanly.

> ⚠️ **Standalone:**
```c
#include "kernel/types.h"
#include "kernel/syscall.h"
#include "user/user.h"

int main() {
    int pid = fork();
    if (pid == 0) {
        monitor(0x7FFFFFFF);
        while (1) {
            getpid();  // traced until killed
            sleep(1);
        }
    }
    sleep(5);          // let child run for 5 ticks
    kill(pid);         // send kill signal
    wait(0);           // reap
    printf("child killed and reaped\n");
    exit(0);
}
```

> 💡 When `killed` flag is set, the process will exit on next return to user space (checked in `usertrap()`). The trace simply stops appearing. No cleanup needed for `monitor_mask`.

---

## M48: a0 Before vs After (Definitive Test)

> Explicitly capture `a0` BEFORE and AFTER syscall execution. Print both to demonstrate the overwrite.

**Dispatcher:**
```c
// BEFORE: a0 = first argument
uint64 arg0_before = p->trapframe->a0;

p->trapframe->a0 = syscalls[num]();

// AFTER: a0 = return value (DIFFERENT!)
if ((p->monitor_mask >> num) & 1)
    printf("%d: %s arg0=0x%x -> ret=%d\n",
           p->pid, syscall_names[num],
           arg0_before, (int)p->trapframe->a0);
```

> ⚠️ **This is the #1 exam gotcha**. `a0` serves dual purpose: argument IN, return value OUT. Example: `read(fd=3, ...)` → `arg0_before=3`, `ret=1023`.

---

## M49: Human-Readable Args (Extended)

> Context-specific argument printing for **6 common syscalls**: fork, exit, read, write, open, close.

**Dispatcher:**
```c
uint64 a0 = p->trapframe->a0;
uint64 a1 = p->trapframe->a1;

p->trapframe->a0 = syscalls[num]();

if ((p->monitor_mask >> num) & 1) {
    int ret = (int)p->trapframe->a0;
    switch (num) {
    case SYS_fork:  printf("%d: fork() -> %d\n", p->pid, ret); break;
    case SYS_exit:  printf("%d: exit(%d)\n", p->pid, (int)a0); break;
    case SYS_read:  printf("%d: read(fd=%d, n=%d) -> %d\n",
                           p->pid, (int)a0, (int)p->trapframe->a2, ret); break;
    case SYS_write: printf("%d: write(fd=%d, n=%d) -> %d\n",
                           p->pid, (int)a0, (int)p->trapframe->a2, ret); break;
    case SYS_open:  printf("%d: open(mode=%d) -> fd=%d\n",
                           p->pid, (int)a1, ret); break;
    case SYS_close: printf("%d: close(fd=%d) -> %d\n",
                           p->pid, (int)a0, ret); break;
    default:
        printf("%d: syscall %s -> %d\n", p->pid, syscall_names[num], ret);
    }
}
```

> 💡 `a2` is NOT overwritten by the return value — only `a0` is. So `p->trapframe->a2` is safe to read after execution.

---

## M50: Statistical Summary at Exit

> Track **total calls**, **most frequent syscall**, and **sum of returns** per syscall. Print a statistical summary in `exit()`.

**Proc Struct:**
```c
uint32 monitor_mask;
int mon_counts[32];                // call count per syscall
int mon_retsum[32];                // sum of return values per syscall
int mon_total;                     // total traced calls
```

**Dispatcher:**
```c
p->trapframe->a0 = syscalls[num]();

if ((p->monitor_mask >> num) & 1) {
    p->mon_counts[num]++;
    p->mon_retsum[num] += (int)p->trapframe->a0;
    p->mon_total++;
}
```

**Exit** (`kernel/proc.c`):
```c
if (p->mon_total > 0) {
    printf("=== Monitor stats for pid %d ===\n", p->pid);
    printf("total traced: %d\n", p->mon_total);

    // Find most frequent
    int max_num = 1, max_count = 0;
    for (int i = 1; i < 32; i++) {
        if (p->mon_counts[i] > max_count) {
            max_count = p->mon_counts[i];
            max_num = i;
        }
    }
    printf("most frequent: %s (%d calls)\n",
           syscall_names[max_num], max_count);

    // Print per-syscall stats
    for (int i = 1; i < 32; i++) {
        if (p->mon_counts[i] > 0)
            printf("  %s: %d calls, avg_ret=%d\n",
                   syscall_names[i], p->mon_counts[i],
                   p->mon_retsum[i] / p->mon_counts[i]);
    }
}
```

---

## M51: Conditional Monitoring by Return Range

> Only trace if the return value falls between `[lo, hi]`. Sys_monitor takes mask, lo, and hi.

**Proc Struct:**
```c
uint32 monitor_mask;
int mon_ret_lo;
int mon_ret_hi;
```

**Sys_monitor:**
```c
uint64
sys_monitor(void)
{
  int mask, lo, hi;
  argint(0, &mask);
  argint(1, &lo);
  argint(2, &hi);
  struct proc *p = myproc();
  p->monitor_mask = (uint32)mask;
  p->mon_ret_lo = lo;
  p->mon_ret_hi = hi;
  return 0;
}
```

**Dispatcher:**
```c
p->trapframe->a0 = syscalls[num]();

if ((p->monitor_mask >> num) & 1) {
    int retval = (int)p->trapframe->a0;
    if (retval >= p->mon_ret_lo && retval <= p->mon_ret_hi)
        printf("%d: syscall %s -> %d [in range %d..%d]\n",
               p->pid, syscall_names[num], retval,
               p->mon_ret_lo, p->mon_ret_hi);
}
```

**User Space:**
```c
// Only trace if return value is positive and <= 1024
monitor(0x7FFFFFFF, 1, 1024);
// read -> 1023 will trace; read -> 0 won't
```

---

## Pattern D Quick Reference

| # | Name | Zone(s) Modified | Key Test | Complexity |
|---|------|-----------------|----------|------------|
| M36 | Trace exit | User | `sys_exit` never returns → trace may not fire | ⚠️ Tricky |
| M37 | Trace monitor | User | `monitor` traces itself (meta) | Simple |
| M38 | Mask = 0 | User | No output — `(0 >> num) & 1` = 0 | Simple |
| M39 | Mask = -1 | User | All traced — `(uint32)-1 = 0xFFFFFFFF` | Simple |
| M40 | Mask after exec | User | Mask persists (struct proc survives exec) | Simple |
| M41 | Zombie child | User | fork→exit→wait lifecycle tracing | Medium |
| M42 | File ops | User | Trace open/read/write/close sequence | Simple |
| M43 | Double monitor | User | Second call overwrites (assignment, not OR) | Simple |
| M44 | Thread-aware | Explanation | xv6 has no threads/clone | Concept |
| M45 | Negative mask | User | `-1` → `0xFFFFFFFF` unsigned cast | Simple |
| M46 | 10 children | User | Scalability: each child traces independently | Medium |
| M47 | Killed process | User | Tracing stops on kill (no cleanup needed) | Medium |
| M48 | a0 before/after | Dispatcher | `arg0_before` vs `p->trapframe->a0` | ⚠️ Key |
| M49 | Human args | Dispatcher | switch(num) for 6 syscalls | Medium |
| M50 | Stats at exit | Proc+Dispatcher+Exit | counts, retsum, most frequent | Hard |
| M51 | Return range | Proc+SysMon+Dispatcher | `lo <= retval <= hi` | Medium |
