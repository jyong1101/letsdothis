# Quiz 2 Predicted Scenarios — Part F: Cross-Lab & New Challenge Scenarios

> **Quiz 1 Pattern Applied**: Completely new tasks combining multiple concepts (like swap32 which combined user program + kernel syscall)

---

## Scenario F1: "getprocinfo" — Syscall Returning Process Information

**Difficulty**: ★★★★★ (Hard — Most Likely New Task Type)
**Concept Tested**: System call with pointer argument, `copyout`, kernel struct access

**Task Description**: Implement a new system call `int getprocinfo(int pid, char *name, int *ppid)` that, given a PID, fills in the process name and parent PID. Write a user program `procinfo` to test it.

### Implementation Steps

#### 1. `kernel/syscall.h`
```c
#define SYS_getprocinfo 23
```

#### 2. `kernel/syscall.c`
```c
extern uint64 sys_getprocinfo(void);

[SYS_getprocinfo] sys_getprocinfo,

[SYS_getprocinfo] "getprocinfo",
```

#### 3. `kernel/sysproc.c`
```c
uint64
sys_getprocinfo(void)
{
  int target_pid;
  uint64 name_addr;
  uint64 ppid_addr;

  argint(0, &target_pid);
  argaddr(1, &name_addr);
  argaddr(2, &ppid_addr);

  // Find the process with the given PID
  struct proc *p;
  for (p = proc; p < &proc[NPROC]; p++) {
    acquire(&p->lock);
    if (p->pid == target_pid && p->state != UNUSED) {
      // Copy process name to user space
      struct proc *caller = myproc();
      if (copyout(caller->pagetable, name_addr, p->name, 16) < 0) {
        release(&p->lock);
        return -1;
      }

      // Copy parent PID to user space
      int ppid = 0;
      if (p->parent)
        ppid = p->parent->pid;
      if (copyout(caller->pagetable, ppid_addr, (char *)&ppid, sizeof(int)) < 0) {
        release(&p->lock);
        return -1;
      }

      release(&p->lock);
      return 0;
    }
    release(&p->lock);
  }

  return -1; // PID not found
}
```

#### 4. `kernel/defs.h`
```c
uint64 sys_getprocinfo(void);
```

#### 5. `user/usys.pl`
```perl
entry("getprocinfo");
```

#### 6. `user/user.h`
```c
int getprocinfo(int, char *, int *);
```

#### 7. `user/procinfo.c`
```c
#include "kernel/types.h"
#include "user/user.h"

int main(int argc, char *argv[]) {
  if (argc != 2) {
    fprintf(2, "Usage: procinfo <pid>\n");
    exit(1);
  }

  int pid = atoi(argv[1]);
  char name[16];
  int ppid;

  if (getprocinfo(pid, name, &ppid) < 0) {
    fprintf(2, "procinfo: process %d not found\n", pid);
    exit(1);
  }

  printf("PID: %d\n", pid);
  printf("Name: %s\n", name);
  printf("Parent PID: %d\n", ppid);
  exit(0);
}
```

---

## Scenario F2: "alarm" — System Call for Periodic Callbacks

**Difficulty**: ★★★★★ (Hard)
**Concept Tested**: Timer interrupts, trap handling, user/kernel boundary

**Task Description**: Implement `int alarm(int ticks, void (*handler)())`. After every N ticks of CPU time, the kernel calls the handler function in user space. This combines kernel timer logic with user-space function pointers.

### Implementation Steps

#### 1. `kernel/proc.h` — Add alarm fields
```c
struct proc {
  // ... existing fields
  int alarm_interval;          // how often to alarm (in ticks)
  int alarm_ticks_left;        // ticks until next alarm
  uint64 alarm_handler;        // user-space handler address
  int alarm_active;            // prevent re-entrant alarms
  struct trapframe *alarm_trapframe; // saved trapframe for alarm return
};
```

#### 2. `kernel/sysproc.c`
```c
uint64
sys_alarm(void)
{
  int interval;
  uint64 handler;

  argint(0, &interval);
  argaddr(1, &handler);

  struct proc *p = myproc();
  p->alarm_interval = interval;
  p->alarm_ticks_left = interval;
  p->alarm_handler = handler;
  p->alarm_active = 0;

  return 0;
}

uint64
sys_alarmret(void)
{
  struct proc *p = myproc();
  // Restore the saved trapframe
  memmove(p->trapframe, p->alarm_trapframe, sizeof(struct trapframe));
  p->alarm_active = 0;
  return p->trapframe->a0;
}
```

#### 3. `kernel/trap.c` — In `usertrap()`, handle timer
```c
// In usertrap(), after "which_dev == 2" (timer interrupt):
if (which_dev == 2) {
  struct proc *p = myproc();
  if (p->alarm_interval > 0 && !p->alarm_active) {
    p->alarm_ticks_left--;
    if (p->alarm_ticks_left <= 0) {
      p->alarm_ticks_left = p->alarm_interval;
      p->alarm_active = 1;
      // Save current trapframe
      memmove(p->alarm_trapframe, p->trapframe, sizeof(struct trapframe));
      // Set up return to user alarm handler
      p->trapframe->epc = p->alarm_handler;
    }
  }
  yield();
}
```

#### 4. `user/alarmtest.c`
```c
#include "kernel/types.h"
#include "user/user.h"

volatile int count = 0;

void periodic(void) {
  count++;
  printf("alarm! count=%d\n", count);
  alarmret();  // return to where we were interrupted
}

int main(void) {
  alarm(10, periodic);  // alarm every 10 ticks

  // Busy loop to generate timer interrupts
  for (int i = 0; i < 1000000000; i++) {
    if (count >= 5)
      break;
  }

  printf("total alarms: %d\n", count);
  exit(0);
}
```

---

## Scenario F3: "ps" — Process Listing Syscall

**Difficulty**: ★★★★☆ (Moderate-Hard)
**Concept Tested**: Iterating process table, copyout to user space, struct marshalling

**Task Description**: Implement a `ps` command that lists all active processes with PID, state, and name. Requires a new syscall `int listprocs(char *buf, int maxbuf)` that writes process info into user buffer.

### Implementation

#### `kernel/sysproc.c`
```c
// Returns number of processes written
uint64
sys_listprocs(void)
{
  uint64 addr;
  int maxbuf;
  argaddr(0, &addr);
  argint(1, &maxbuf);

  struct proc *caller = myproc();
  char buf[1024];
  int offset = 0;

  static const char *states[] = {
    "unused", "used", "sleep", "runble", "run", "zombie"
  };

  struct proc *p;
  for (p = proc; p < &proc[NPROC]; p++) {
    acquire(&p->lock);
    if (p->state != UNUSED) {
      int n = snprintf_simple(buf + offset, maxbuf - offset,
                              p->pid, states[p->state], p->name);
      offset += n;
    }
    release(&p->lock);
  }

  if (copyout(caller->pagetable, addr, buf, offset) < 0)
    return -1;
  return offset;
}

// Simple formatting helper (since xv6 lacks snprintf)
static int
snprintf_simple(char *buf, int max, int pid, const char *state, const char *name)
{
  // Format: "PID STATE NAME\n"
  int i = 0;
  // Write PID
  char tmp[16];
  int pidlen = 0;
  int p = pid;
  if (p == 0) tmp[pidlen++] = '0';
  while (p > 0 && pidlen < 15) {
    tmp[pidlen++] = '0' + (p % 10);
    p /= 10;
  }
  for (int j = pidlen - 1; j >= 0 && i < max; j--)
    buf[i++] = tmp[j];
  if (i < max) buf[i++] = ' ';
  while (*state && i < max) buf[i++] = *state++;
  if (i < max) buf[i++] = ' ';
  while (*name && i < max) buf[i++] = *name++;
  if (i < max) buf[i++] = '\n';
  return i;
}
```

#### Simpler alternative — use kernel printf directly
```c
uint64
sys_listprocs(void)
{
  static const char *states[] = {
    "unused", "used", "sleep", "runble", "run   ", "zombie"
  };

  printf("PID    STATE    NAME\n");
  struct proc *p;
  for (p = proc; p < &proc[NPROC]; p++) {
    acquire(&p->lock);
    if (p->state != UNUSED) {
      printf("%d      %s   %s\n", p->pid, states[p->state], p->name);
    }
    release(&p->lock);
  }
  return 0;
}
```

#### `user/ps.c`
```c
#include "kernel/types.h"
#include "user/user.h"

int main(void) {
  listprocs(); // syscall prints directly from kernel
  exit(0);
}
```

---

## Scenario F4: "pipestat" — Pipe Statistics Syscall

**Difficulty**: ★★★★★ (Hard)
**Concept Tested**: Kernel data structures (pipe struct), new syscall returning structured data

**Task Description**: Add a syscall `int pipestat(int fd, int *readbytes, int *writebytes)` that reports how many bytes have been read/written through a pipe.

### Implementation

#### 1. `kernel/pipe.c` — Add counters to pipe struct
```c
struct pipe {
  struct spinlock lock;
  char data[PIPESIZE];
  uint nread;     // number of bytes read
  uint nwrite;    // number of bytes written
  int readopen;   // read fd is still open
  int writeopen;  // write fd is still open
  uint total_read;   // NEW: total bytes read (cumulative)
  uint total_written; // NEW: total bytes written (cumulative)
};
```

#### 2. Modify `piperead()` and `pipewrite()` to track totals
```c
// In pipewrite(), after writing bytes:
pi->total_written += n;

// In piperead(), after reading bytes:
pi->total_read += n;
```

#### 3. `kernel/sysproc.c`
```c
uint64
sys_pipestat(void)
{
  int fd;
  uint64 raddr, waddr;

  argint(0, &fd);
  argaddr(1, &raddr);
  argaddr(2, &waddr);

  struct proc *p = myproc();
  struct file *f = p->ofile[fd];
  if (f == 0 || f->type != FD_PIPE)
    return -1;

  struct pipe *pi = f->pipe;
  acquire(&pi->lock);
  uint tr = pi->total_read;
  uint tw = pi->total_written;
  release(&pi->lock);

  if (copyout(p->pagetable, raddr, (char *)&tr, sizeof(uint)) < 0)
    return -1;
  if (copyout(p->pagetable, waddr, (char *)&tw, sizeof(uint)) < 0)
    return -1;

  return 0;
}
```

---

## Scenario F5: "waitpid" — Wait for Specific Child

**Difficulty**: ★★★★☆ (Moderate-Hard)
**Concept Tested**: Process management syscall, extending xv6's wait mechanism

**Task Description**: Implement `int waitpid(int pid, int *status)` that waits for a specific child process to exit, unlike `wait()` which waits for any child.

### `kernel/sysproc.c`
```c
uint64
sys_waitpid(void)
{
  int pid;
  uint64 addr;

  argint(0, &pid);
  argaddr(1, &addr);

  return kwaitpid(pid, addr);
}
```

### `kernel/proc.c`
```c
int
kwaitpid(int pid, uint64 addr)
{
  struct proc *pp;
  struct proc *p = myproc();

  acquire(&wait_lock);
  for (;;) {
    int found = 0;
    for (pp = proc; pp < &proc[NPROC]; pp++) {
      if (pp->parent != p || pp->pid != pid)
        continue;
      found = 1;

      acquire(&pp->lock);
      if (pp->state == ZOMBIE) {
        int xstate = pp->xstate;
        if (addr != 0 && copyout(p->pagetable, addr,
                                  (char *)&xstate, sizeof(xstate)) < 0) {
          release(&pp->lock);
          release(&wait_lock);
          return -1;
        }
        freeproc(pp);
        release(&pp->lock);
        release(&wait_lock);
        return pid;
      }
      release(&pp->lock);
    }

    if (!found) {
      release(&wait_lock);
      return -1; // no such child
    }

    // Sleep until child exits
    sleep(p, &wait_lock);
  }
}
```

### `user/user.h`
```c
int waitpid(int, int *);
```

### `user/waitpidtest.c`
```c
#include "kernel/types.h"
#include "user/user.h"

int main(void) {
  int pid1 = fork();
  if (pid1 == 0) {
    printf("child 1 running\n");
    pause(50);
    exit(42);
  }

  int pid2 = fork();
  if (pid2 == 0) {
    printf("child 2 running\n");
    pause(10);
    exit(99);
  }

  // Wait specifically for child 1 (even though child 2 exits first)
  int status;
  waitpid(pid1, &status);
  printf("child 1 exited with status %d\n", status);

  waitpid(pid2, &status);
  printf("child 2 exited with status %d\n", status);

  exit(0);
}
```

---

## Scenario F6: "threadcount" — Kernel Syscall + User Thread Integration

**Difficulty**: ★★★★★ (Hard)
**Concept Tested**: Combining kernel syscalls with user-level threading concepts

**Task Description**: Add a syscall `int nproc(void)` that returns the number of RUNNABLE/RUNNING processes. Write a user program that forks N children, uses `nproc()` to verify, and then waits.

### `kernel/sysproc.c`
```c
uint64
sys_nproc(void)
{
  int count = 0;
  struct proc *p;

  for (p = proc; p < &proc[NPROC]; p++) {
    acquire(&p->lock);
    if (p->state == RUNNING || p->state == RUNNABLE || p->state == SLEEPING)
      count++;
    release(&p->lock);
  }

  return count;
}
```

### `user/nproc.c`
```c
#include "kernel/types.h"
#include "user/user.h"

int main(int argc, char *argv[]) {
  int n = 3;
  if (argc >= 2)
    n = atoi(argv[1]);

  printf("Before fork: %d processes\n", nproc());

  for (int i = 0; i < n; i++) {
    int pid = fork();
    if (pid == 0) {
      pause(100); // child sleeps
      exit(0);
    }
  }

  printf("After %d forks: %d processes\n", n, nproc());

  for (int i = 0; i < n; i++) {
    wait(0);
  }

  printf("After wait: %d processes\n", nproc());
  exit(0);
}
```
