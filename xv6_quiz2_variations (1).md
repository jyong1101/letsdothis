# xv6 Quiz 2 Variations Cheatsheet (Handshake, Sniffer, Monitor, Uthread, PH)

## 📋 Contents

### HANDSHAKE (IPC/Pipes)
- [Core Algorithm](#handshake---core-algorithm)
- [Variations 1-14](#handshake-variations)

### SNIFFER (Memory/Heap)
- [Core Algorithm](#sniffer---core-algorithm)
- [Variations 1-14](#sniffer-variations)

### MONITOR (Syscall Tracing)
- [Core Algorithm](#monitor---core-algorithm)
- [Variations 1-14](#monitor-variations)

### UTHREAD (User Threading)
- [Core Algorithm](#uthread---core-algorithm)
- [Variations 1-14](#uthread-variations)

### PH (Pthreads/Locks)
- [Core Algorithm](#ph---core-algorithm)
- [Variations 1-14](#ph-variations)

### Reference
- [Common Exam Modifications Quick Reference](#common-exam-modifications-quick-reference)

---

## HANDSHAKE - Core Algorithm

```c
#include "kernel/types.h"
#include "user/user.h"

int main(int argc, char *argv[]) {
    int p1[2], p2[2];
    if (pipe(p1) < 0 || pipe(p2) < 0) { fprintf(2, "pipe failed\n"); exit(1); }
    int pid = fork();
    if (pid < 0) { fprintf(2, "fork failed\n"); exit(1); }

    if (pid == 0) {
        close(p1[1]); close(p2[0]);
        // ════════════════════════════════════════════
        // MODIFY HERE: Child processing logic
        char buf;
        if (read(p1[0], &buf, 1) == 1) {
            printf("%d: received %c\n", getpid(), buf);
            write(p2[1], &buf, 1);
        }
        // ════════════════════════════════════════════
        close(p1[0]); close(p2[1]);
        exit(0);
    } else {
        close(p1[0]); close(p2[1]);
        // ════════════════════════════════════════════
        // MODIFY HERE: Parent processing logic
        char msg = 'A';
        write(p1[1], &msg, 1);
        char buf;
        if (read(p2[0], &buf, 1) == 1) {
            printf("%d: received %c\n", getpid(), buf);
        }
        // ════════════════════════════════════════════
        close(p1[1]); close(p2[0]);
        wait(0);
        exit(0);
    }
}
```

---

## HANDSHAKE Variations

### V1: Send/Receive Arrays of Integers
```c
// Parent:
int arr[5] = {1,2,3,4,5};
write(p1[1], arr, sizeof(arr));
int resp; read(p2[0], &resp, sizeof(int));
// Child:
int rcv[5];
if (read(p1[0], rcv, sizeof(rcv)) > 0) {
    int sum = 0;
    for (int i=0; i<5; i++) sum += rcv[i];
    write(p2[1], &sum, sizeof(int));
}
```

### V2: Read Until EOF
```c
// Parent:
char *msg = "hello xv6\n";
write(p1[1], msg, strlen(msg));
close(p1[1]); // CRITICAL: triggers EOF
// Child:
char buf;
while (read(p1[0], &buf, 1) > 0) {
    if (buf == '\n') break;
    write(p2[1], &buf, 1);
}
```

### V3: Conditional Mutation (e.g., upper→lower)
```c
// Child:
char buf;
if (read(p1[0], &buf, 1) == 1) {
    if (buf >= 'A' && buf <= 'Z') buf += 32;
    else buf = '?';
    write(p2[1], &buf, 1);
}
```

### V4: Multi-Round Ping-Pong
```c
// Parent:
char buf = 'A';
for (int i=0; i<3; i++) {
    write(p1[1], &buf, 1);
    if (read(p2[0], &buf, 1) != 1) break;
}
// Child:
char buf;
while (read(p1[0], &buf, 1) == 1) { buf++; write(p2[1], &buf, 1); }
```

### V5: Fork-Exec Pipeline (cmd1 | cmd2)
```c
int p[2]; pipe(p);
if (fork() == 0) { close(p[0]); close(1); dup(p[1]); close(p[1]); exec(argv[1], &argv[1]); exit(1); }
if (fork() == 0) { close(p[1]); close(0); dup(p[0]); close(p[0]); exec(argv[sep+1], &argv[sep+1]); exit(1); }
close(p[0]); close(p[1]); wait(0); wait(0);
```

### V6: Dynamic Payload Sizing (send size, then data)
```c
// Parent:
char *msg = argv[1]; int len = strlen(msg);
write(p1[1], &len, sizeof(int));
write(p1[1], msg, len);
// Child:
int len; read(p1[0], &len, sizeof(int));
char buf[256]; read(p1[0], buf, len); buf[len] = 0;
printf("%s\n", buf);
```

### V7: Data Aggregation (send 5 ints, return sum)
```c
// Parent:
int vals[5] = {10,20,30,40,50};
write(p1[1], vals, sizeof(vals));
int sum; read(p2[0], &sum, sizeof(int));
printf("sum=%d\n", sum);
// Child:
int vals[5]; read(p1[0], vals, sizeof(vals));
int sum=0; for(int i=0;i<5;i++) sum+=vals[i];
write(p2[1], &sum, sizeof(int));
```

### V8: Timeout Loop via uptime()
```c
// Child: read with timeout
int start = uptime();
char buf;
while (uptime() - start < 100) { // 100 ticks timeout
    if (read(p1[0], &buf, 1) == 1) { write(p2[1], &buf, 1); break; }
}
```

### V9: Two-Way Struct Passing
```c
struct msg { int type; char data[32]; };
// Parent:
struct msg m = {1, "hello"}; write(p1[1], &m, sizeof(m));
struct msg reply; read(p2[0], &reply, sizeof(reply));
// Child:
struct msg m; read(p1[0], &m, sizeof(m));
m.type = 2; strcpy(m.data, "ack");
write(p2[1], &m, sizeof(m));
```

### V10: Sending File Contents Over Pipe
```c
// Parent:
int fd = open(argv[1], 0); char c;
while (read(fd, &c, 1) > 0) write(p1[1], &c, 1);
close(fd); close(p1[1]); // trigger EOF
// Child:
char c; int count = 0;
while (read(p1[0], &c, 1) > 0) count++;
printf("file has %d bytes\n", count);
```

### V11: Multi-Child Broadcast
```c
int pipes[3][2]; // one pipe per child
for (int i=0; i<3; i++) { pipe(pipes[i]);
    if (fork() == 0) { close(pipes[i][1]);
        char buf; read(pipes[i][0], &buf, 1);
        printf("child %d got %c\n", i, buf);
        close(pipes[i][0]); exit(0);
    } close(pipes[i][0]);
}
char msg = 'X';
for (int i=0; i<3; i++) { write(pipes[i][1], &msg, 1); close(pipes[i][1]); }
for (int i=0; i<3; i++) wait(0);
```

### V12: Pipe Capacity Tester
```c
// Parent: write until pipe blocks, count bytes
int p[2]; pipe(p);
if (fork() == 0) { close(p[1]); pause(200); /* sleep then drain */
    char buf[512]; while(read(p[0],buf,512)>0); close(p[0]); exit(0); }
close(p[0]); int count=0; char c='x';
while(1) { int r = write(p[1], &c, 1); if(r<=0) break; count++; }
printf("pipe capacity: %d bytes\n", count);
close(p[1]); wait(0);
```

### V13: Non-Blocking Read Polling (check-then-yield)
```c
// Child: poll-style read in a loop
char buf; int got = 0;
for (int i=0; i<100 && !got; i++) {
    if (read(p1[0], &buf, 1) == 1) { got = 1; }
    else pause(1); // yield time
}
if (got) write(p2[1], &buf, 1);
```

### V14: Parent-Child Sync Barrier via Pipes
```c
int ready[2], go[2]; pipe(ready); pipe(go);
if (fork() == 0) {
    close(ready[0]); close(go[1]);
    // do setup work...
    write(ready[1], "R", 1); close(ready[1]); // signal ready
    char g; read(go[0], &g, 1); close(go[0]); // wait for go
    // do main work...
    exit(0);
}
close(ready[1]); close(go[0]);
char r; read(ready[0], &r, 1); close(ready[0]); // wait for ready
write(go[1], "G", 1); close(go[1]); // send go
wait(0);
```

---

## SNIFFER - Core Algorithm

```c
#include "kernel/types.h"
#include "user/user.h"

int main(int argc, char *argv[]) {
    int size = 10 * 4096;
    char *p = sbrk(size);
    if (p == (char*)-1) { printf("sbrk failed\n"); exit(1); }

    char *marker = "This may help.";
    int marker_len = strlen(marker);

    for (int i = 0; i < size - marker_len - 64; i++) {
        // ════════════════════════════════════════════
        // MODIFY HERE: Matching & extraction logic
        if (memcmp(p + i, marker, marker_len) == 0) {
            printf("%s\n", p + i + 16);
            exit(0);
        }
        // ════════════════════════════════════════════
    }
    printf("sniffer: not found\n"); exit(1);
}
```

---

## SNIFFER Variations

### V1: Integer Array Marker
```c
int match[3] = {0xDEADBEEF, 0x12345678, 0x87654321};
if (memcmp(p+i, (char*)match, sizeof(match)) == 0) {
    printf("%s\n", p + i + sizeof(match)); exit(0);
}
```

### V2: Variable Offset Extraction
```c
if (memcmp(p+i, marker, marker_len) == 0) {
    int offset = *(int*)(p + i + marker_len); // read offset from data
    if (i+offset >= 0 && i+offset < size) { printf("%s\n", p+i+offset); exit(0); }
}
```

### V3: Backwards Heap Scanning
```c
for (int i = size - marker_len - 64; i >= 0; i--) {
    if (memcmp(p+i, marker, marker_len) == 0) { printf("%s\n", p+i+16); exit(0); }
}
```

### V4: XOR-Decrypted Pattern Match
```c
char dec[64]; char key = 0xAA;
for (int j=0; j<marker_len; j++) dec[j] = p[i+j] ^ key;
if (memcmp(dec, marker, marker_len) == 0) {
    char *s = p+i+16; for(int j=0; s[j] && j<64; j++) printf("%c", s[j]^key);
    printf("\n"); exit(0);
}
```

### V5: Find ALL Secrets in Heap
```c
int found = 0;
for (int i = 0; i < size - marker_len - 64; i++) {
    if (memcmp(p+i, marker, marker_len) == 0) {
        printf("%s\n", p+i+16); found++; i += 4096; // skip to next page
    }
}
if (!found) printf("none found\n");
```

### V6: Kernel Scrub (kalloc.c — zero free pages)
```c
// In kernel/kalloc.c:
void scrub_freelist(void) {
  struct run *r; acquire(&kmem.lock);
  for (r = kmem.freelist; r; r = r->next)
    memset((char*)r + sizeof(struct run), 0, PGSIZE - sizeof(struct run));
  release(&kmem.lock);
}
// In kernel/sysproc.c: uint64 sys_scrub(void) { scrub_freelist(); return 0; }
```

### V7: Struct Recovery
```c
struct record { int id; short age; char name[64]; };
if (memcmp(p+i, "RECORD_MARK", 11) == 0) {
    struct record *r = (struct record*)(p+i+16);
    printf("id=%d age=%d name=%s\n", r->id, (int)r->age, r->name); exit(0);
}
```

### V8: Hex Magic Number Sequence
```c
uint32 magic = 0xCAFEBABE;
if (memcmp(p+i, &magic, 4) == 0) { printf("%s\n", p+i+4); exit(0); }
```

### V9: Memory Patching (overwrite secret to 0)
```c
if (memcmp(p+i, marker, marker_len) == 0) {
    printf("found at offset %d, scrubbing...\n", i);
    memset(p+i, 0, 128); // zero out marker + secret
}
```

### V10: Wildcard Pattern (skip one unknown byte)
```c
// Match "This" + ANY_BYTE + "help."
if (memcmp(p+i, "This", 4)==0 && memcmp(p+i+5, "help.", 5)==0) {
    printf("wildcard match at %d\n", i); printf("%s\n", p+i+16); exit(0);
}
```

### V11: Struct Array Recovery
```c
struct item { int id; char label[16]; };
if (memcmp(p+i, "ITEMS", 5) == 0) {
    int count = *(int*)(p+i+8);
    struct item *arr = (struct item*)(p+i+16);
    for (int j=0; j<count && j<10; j++)
        printf("[%d] %s\n", arr[j].id, arr[j].label);
    exit(0);
}
```

### V12: Pointer Chasing (marker contains pointer to secret)
```c
if (memcmp(p+i, marker, marker_len) == 0) {
    uint64 ptr = *(uint64*)(p+i+16); // read embedded pointer
    // Validate pointer is within our heap range
    if (ptr >= (uint64)p && ptr < (uint64)(p+size))
        printf("%s\n", (char*)ptr);
    exit(0);
}
```

### V13: Page Boundary Crossing Detection
```c
// Check if marker is split across a 4096-byte page boundary
int page_offset = i % 4096;
if (page_offset + marker_len > 4096) {
    printf("WARNING: marker at offset %d crosses page boundary\n", i);
}
if (memcmp(p+i, marker, marker_len) == 0) { printf("%s\n", p+i+16); exit(0); }
```

### V14: Linked List Traversal in Heap
```c
struct node { int val; int next_offset; }; // offset from heap base, -1 = end
if (memcmp(p+i, "LIST_HEAD", 9)==0) {
    int off = i + 16;
    while (off >= 0 && off < size - (int)sizeof(struct node)) {
        struct node *n = (struct node*)(p + off);
        printf("val=%d\n", n->val);
        if (n->next_offset == -1) break;
        off = n->next_offset;
    }
    exit(0);
}
```

---

## MONITOR - Core Algorithm

```c
// kernel/syscall.c — syscall() function
void syscall(void) {
    int num;
    struct proc *p = myproc();
    num = p->trapframe->a7;

    if(num > 0 && num < NELEM(syscalls) && syscalls[num]) {
        // ════════════════════════════════════════════
        // MODIFY HERE (Pre-Exec): capture args before a0 is overwritten
        // ════════════════════════════════════════════

        p->trapframe->a0 = syscalls[num](); // execute syscall

        // ════════════════════════════════════════════
        // MODIFY HERE (Post-Exec): trace/log/count logic
        if ((1 << num) & p->monitor_mask) {
            printf("%d: syscall %s -> %d\n",
                   p->pid, syscall_names[num], (int)p->trapframe->a0);
        }
        // ════════════════════════════════════════════
    } else {
        printf("%d %s: unknown sys call %d\n", p->pid, p->name, num);
        p->trapframe->a0 = -1;
    }
}
```

---

## MONITOR Variations

### V1: Filter by Specific PID
```c
// proc.h: add `int monitor_target_pid;`
// sysproc.c: argint(1, &target_pid); p->monitor_target_pid = target_pid;
// Post-Exec:
if (((1<<num) & p->monitor_mask) && p->pid == p->monitor_target_pid)
    printf("%d: syscall %s -> %d\n", p->pid, syscall_names[num], (int)p->trapframe->a0);
```

### V2: Trace Only Failing Syscalls
```c
if ((1<<num) & p->monitor_mask) {
    int ret = (int)p->trapframe->a0;
    if (ret < 0) printf("FAIL %d: %s -> %d\n", p->pid, syscall_names[num], ret);
}
```

### V3: Argument Logging Before Execution
```c
// Pre-Exec:
uint64 arg0 = p->trapframe->a0; uint64 arg1 = p->trapframe->a1;
// Post-Exec:
if ((1<<num) & p->monitor_mask)
    printf("%d: %s(0x%lx, 0x%lx) -> %d\n", p->pid, syscall_names[num], arg0, arg1, (int)p->trapframe->a0);
```

### V4: Syscall Counting
```c
// proc.h: add `int syscall_counts[24];`  proc.c allocproc: memset(p->syscall_counts,0,...)
// Post-Exec:
if ((1<<num) & p->monitor_mask && num < 24) p->syscall_counts[num]++;
// In exit(): for(int i=1;i<24;i++) if(p->syscall_counts[i]) printf("%d: %s=%d\n",p->pid,syscall_names[i],p->syscall_counts[i]);
```

### V5: Threshold Filter (trace only if retval > threshold)
```c
// proc.h: add `int monitor_threshold;`  sysproc: argint(1,&threshold);
if ((1<<num) & p->monitor_mask && (int)p->trapframe->a0 > p->monitor_threshold)
    printf("%d: %s -> %d\n", p->pid, syscall_names[num], (int)p->trapframe->a0);
```

### V6: Process Name Printing
```c
if ((1<<num) & p->monitor_mask)
    printf("%d(%s): syscall %s -> %d\n", p->pid, p->name, syscall_names[num], (int)p->trapframe->a0);
```

### V7: Mask Inheritance Control on fork
```c
// proc.h: add `int monitor_inherit;`
// proc.c fork(): if(p->monitor_inherit) { np->monitor_mask=p->monitor_mask; np->monitor_inherit=1; }
//                else { np->monitor_mask=0; }
```

### V8: Sysinfo Syscall (new syscall returning system stats)
```c
// sysproc.c:
uint64 sys_sysinfo(void) {
  uint64 addr; argaddr(0, &addr);
  int info[3];
  info[0] = count_active_procs(); // iterate proc[], count non-UNUSED
  info[1] = count_free_pages();   // iterate kmem.freelist
  acquire(&tickslock); info[2] = ticks; release(&tickslock);
  if (copyout(myproc()->pagetable, addr, (char*)info, sizeof(info)) < 0) return -1;
  return 0;
}
```

### V9: Execution Time Tracking via Ticks
```c
// Pre-Exec:
acquire(&tickslock); uint t0 = ticks; release(&tickslock);
// Post-Exec:
acquire(&tickslock); uint t1 = ticks; release(&tickslock);
if ((1<<num) & p->monitor_mask)
    printf("%d: %s -> %d (%d ticks)\n", p->pid, syscall_names[num], (int)p->trapframe->a0, t1-t0);
```

### V10: File Logging (write trace to fd instead of console)
```c
// proc.h: add `int monitor_log_fd;`
// Post-Exec:
if ((1<<num) & p->monitor_mask) {
    char buf[128]; int len = snprintf_kern(buf, sizeof(buf), "%d: %s -> %d\n", ...);
    // Or simply: filewrite(p->ofile[p->monitor_log_fd], ...) — complex, prefer printf
    printf("%d: %s -> %d\n", p->pid, syscall_names[num], (int)p->trapframe->a0);
}
```

### V11: Trace on Specific Memory Address Arg
```c
// Pre-Exec: uint64 arg0 = p->trapframe->a0;
// Post-Exec: trace only if arg touches a target address range
if ((1<<num) & p->monitor_mask && arg0 >= p->monitor_watch_addr && arg0 < p->monitor_watch_addr + 4096)
    printf("%d: %s touched watched addr 0x%lx\n", p->pid, syscall_names[num], arg0);
```

### V12: Trace Specific FD Only
```c
// proc.h: add `int monitor_fd;`  sysproc: argint(1, &monitor_fd);
// Pre-Exec: uint64 arg0 = p->trapframe->a0;
if ((1<<num) & p->monitor_mask && (int)arg0 == p->monitor_fd)
    printf("%d: %s(fd=%d) -> %d\n", p->pid, syscall_names[num], (int)arg0, (int)p->trapframe->a0);
```

### V13: Syscall Rate Limiting
```c
// proc.h: add `int syscall_budget;` — initialized to N by monitor(mask, N) 
// Post-Exec:
if ((1<<num) & p->monitor_mask) {
    if (p->syscall_budget > 0) {
        printf("%d: %s -> %d\n", p->pid, syscall_names[num], (int)p->trapframe->a0);
        p->syscall_budget--;
    }
}
```

### V14: Monitor Call Depth (nested exec tracking)
```c
// proc.h: add `int call_depth;`  — increment on fork/exec, decrement on exit
// Post-Exec:
if ((1<<num) & p->monitor_mask)
    printf("[depth=%d] %d: %s -> %d\n", p->call_depth, p->pid, syscall_names[num], (int)p->trapframe->a0);
```

---

## UTHREAD - Core Algorithm

```c
void thread_create(void (*func)()) {
    struct thread *t;
    // ════════════════════════════════════════════
    // MODIFY HERE: Thread setup logic
    for (t = all_thread; t < all_thread + MAX_THREAD; t++) {
        if (t->state == FREE) {
            t->state = RUNNABLE;
            t->context.sp = (uint64)t->stack + STACK_SIZE;
            t->context.ra = (uint64)func;
            return;
        }
    }
    // ════════════════════════════════════════════
    printf("thread_create: no free slots\n");
}

void thread_schedule(void) {
    struct thread *t, *next_thread;
    // ════════════════════════════════════════════
    // MODIFY HERE: Scheduling selection algorithm
    next_thread = 0;
    t = current_thread + 1;
    for (int i = 0; i < MAX_THREAD; i++) {
        if (t >= all_thread + MAX_THREAD) t = all_thread;
        if (t->state == RUNNABLE) { next_thread = t; break; }
        t++;
    }
    // ════════════════════════════════════════════
    if (!next_thread) { printf("no runnable threads\n"); exit(-1); }
    if (current_thread != next_thread) {
        next_thread->state = RUNNING;
        t = current_thread; current_thread = next_thread;
        thread_switch((uint64)&t->context, (uint64)&next_thread->context);
    }
}
```

---

## UTHREAD Variations

### V1: Return Thread ID & Join
```c
// thread_create returns int:
int thread_create(void (*func)()) {
    for (t = all_thread; t < all_thread+MAX_THREAD; t++) {
        if (t->state == FREE) { /* setup */ return t - all_thread; }
    } return -1;
}
void thread_join(int tid) {
    if (tid<0||tid>=MAX_THREAD) return;
    while (all_thread[tid].state != FREE) thread_yield();
}
```

### V2: Thread Priorities
```c
// struct thread: add `int priority;`
// thread_create(func, prio): t->priority = prio;
// Scheduling:
next_thread=0; int best=-1;
for (int i=0; i<MAX_THREAD; i++) {
    if (t >= all_thread+MAX_THREAD) t=all_thread;
    if (t->state==RUNNABLE && t->priority > best) { next_thread=t; best=t->priority; }
    t++;
}
```

### V3: Thread Sleeping (tick-based)
```c
// struct thread: add `int sleep_ticks;`  new state: #define SLEEPING 0x3
void thread_sleep(int ticks) { current_thread->state=SLEEPING; current_thread->sleep_ticks=ticks; thread_schedule(); }
// In schedule(), before finding next: decrement all sleeping threads
for (t=all_thread; t<all_thread+MAX_THREAD; t++)
    if (t->state==SLEEPING && --t->sleep_ticks <= 0) t->state=RUNNABLE;
```

### V4: Extended Registers (save t0-t6)
```asm
    /* After s11 saves in thread_switch: */
    sd t0,  112(a0)
    sd t1,  120(a0)
    sd t2,  128(a0)
    sd t3,  136(a0)
    sd t4,  144(a0)
    sd t5,  152(a0)
    sd t6,  160(a0)
    /* Mirror ld for a1 */
```

### V5: Argument Passing via thread_create
```c
struct start_info { void (*func)(void*); void *arg; } info[MAX_THREAD];
void trampoline() { int idx=current_thread-all_thread; info[idx].func(info[idx].arg); current_thread->state=FREE; thread_schedule(); }
void thread_create(void (*func)(void*), void *arg) {
    /* find free t */ int idx=t-all_thread;
    info[idx].func=func; info[idx].arg=arg;
    t->context.ra=(uint64)trampoline; t->context.sp=(uint64)t->stack+STACK_SIZE;
}
```

### V6: User Mutex (yield-based)
```c
struct umutex { int locked; };
void umutex_lock(struct umutex *m) { while(m->locked) thread_yield(); m->locked=1; }
void umutex_unlock(struct umutex *m) { m->locked=0; }
```

### V7: Thread Cancellation
```c
void thread_cancel(int tid) {
    if (tid<0||tid>=MAX_THREAD) return;
    all_thread[tid].state = FREE; // mark as free, it won't be scheduled
}
```

### V8: Yield with Data Payload
```c
// struct thread: add `uint64 yield_data;`
void thread_yield_with(uint64 data) {
    current_thread->yield_data = data;
    current_thread->state = RUNNABLE; thread_schedule();
}
uint64 thread_get_data(int tid) { return all_thread[tid].yield_data; }
```

### V9: Thread Local Storage (TLS array)
```c
#define TLS_SIZE 4
// struct thread: add `uint64 tls[TLS_SIZE];`
void tls_set(int key, uint64 val) { if(key<TLS_SIZE) current_thread->tls[key]=val; }
uint64 tls_get(int key) { return key<TLS_SIZE ? current_thread->tls[key] : 0; }
```

### V10: String Names for Threads
```c
// struct thread: add `char name[16];`
void thread_create_named(void (*func)(), char *name) {
    /* find free t */ strcpy(t->name, name);
    /* rest of setup */
}
// In schedule: printf("switching to %s\n", next_thread->name);
```

### V11: Thread Detached State
```c
// struct thread: add `int detached;`
void thread_detach(int tid) { all_thread[tid].detached = 1; }
// In thread func exit: if (current_thread->detached) { current_thread->state=FREE; thread_schedule(); }
// thread_join: if (all_thread[tid].detached) return; // can't join detached
```

### V12: Simulated Round-Robin Quantum
```c
// struct thread: add `int quantum; int ticks_used;`
// thread_create: t->quantum = 5; t->ticks_used = 0;
void thread_tick() { // called periodically
    current_thread->ticks_used++;
    if (current_thread->ticks_used >= current_thread->quantum) {
        current_thread->ticks_used = 0; thread_yield();
    }
}
```

### V13: Suspend/Resume Specific Thread
```c
#define SUSPENDED 0x4
void thread_suspend(int tid) { if(tid>=0&&tid<MAX_THREAD) all_thread[tid].state=SUSPENDED; }
void thread_resume(int tid) { if(tid>=0&&tid<MAX_THREAD && all_thread[tid].state==SUSPENDED) all_thread[tid].state=RUNNABLE; }
// schedule() already skips non-RUNNABLE threads
```

### V14: Thread Exit Status (return value)
```c
// struct thread: add `int exit_status; int exited;`
void thread_exit(int status) {
    current_thread->exit_status = status; current_thread->exited = 1;
    current_thread->state = FREE; thread_schedule();
}
int thread_join_status(int tid) {
    while (!all_thread[tid].exited) thread_yield();
    return all_thread[tid].exit_status;
}
```

---

## PH - Core Algorithm

```c
static void put(int key, int value) {
    int i = key % NBUCKET;
    // ════════════════════════════════════════════
    // MODIFY HERE: Locking strategy
    pthread_mutex_lock(&locks[i]);
    struct entry *e = 0;
    for (e = table[i]; e != 0; e = e->next) { if (e->key == key) break; }
    if (e) { e->value = value; }
    else { insert(key, value, &table[i], table[i]); }
    pthread_mutex_unlock(&locks[i]);
    // ════════════════════════════════════════════
}
```

---

## PH Variations

### V1: Read-Write Locks
```c
pthread_rwlock_t locks[NBUCKET];
// put: pthread_rwlock_wrlock(&locks[i]); ... pthread_rwlock_unlock(&locks[i]);
// get: pthread_rwlock_rdlock(&locks[i]); ... pthread_rwlock_unlock(&locks[i]);
```

### V2: Thread-Safe Delete
```c
static int delete(int key) {
    int i = key % NBUCKET;
    pthread_mutex_lock(&locks[i]);
    struct entry **pp = &table[i];
    for (struct entry *e = table[i]; e; e = e->next) {
        if (e->key == key) { *pp = e->next; pthread_mutex_unlock(&locks[i]); free(e); return 0; }
        pp = &e->next;
    }
    pthread_mutex_unlock(&locks[i]); return -1;
}
```

### V3: Producer-Consumer (Condvar)
```c
pthread_mutex_t mtx = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t not_full = PTHREAD_COND_INITIALIZER;
pthread_cond_t not_empty = PTHREAD_COND_INITIALIZER;
int buf[BUFSIZE], count=0, in=0, out=0;
// Producer: lock; while(count==BUFSIZE) cond_wait(&not_full,&mtx); buf[in]=val; in=(in+1)%BUFSIZE; count++; signal(&not_empty); unlock;
// Consumer: lock; while(count==0) cond_wait(&not_empty,&mtx); val=buf[out]; out=(out+1)%BUFSIZE; count--; signal(&not_full); unlock;
```

### V4: Barrier Synchronization
```c
struct barrier { pthread_mutex_t m; pthread_cond_t c; int n, count, round; };
void barrier_wait(struct barrier *b) {
    pthread_mutex_lock(&b->m); int r=b->round; b->count++;
    if (b->count==b->n) { b->count=0; b->round++; pthread_cond_broadcast(&b->c); }
    else { while(b->round==r) pthread_cond_wait(&b->c,&b->m); }
    pthread_mutex_unlock(&b->m);
}
```

### V5: Single Global Lock (simplest, slowest)
```c
pthread_mutex_t global_lock;
// put: pthread_mutex_lock(&global_lock); ... pthread_mutex_unlock(&global_lock);
// NOTE: Passes ph_safe but FAILS ph_fast (no parallelism)
```

### V6: Multi-Key Lock (put_swap, deadlock-safe)
```c
void put_swap(int k1, int k2) {
    int i=k1%NBUCKET, j=k2%NBUCKET;
    if (i==j) { pthread_mutex_lock(&locks[i]); /* swap */ pthread_mutex_unlock(&locks[i]); }
    else {
        if (i<j) { pthread_mutex_lock(&locks[i]); pthread_mutex_lock(&locks[j]); }
        else     { pthread_mutex_lock(&locks[j]); pthread_mutex_lock(&locks[i]); }
        /* swap values */ pthread_mutex_unlock(&locks[i]); pthread_mutex_unlock(&locks[j]);
    }
}
```

### V7: Safe Table Iteration/Counting
```c
int count_all() {
    int total = 0;
    for (int i=0; i<NBUCKET; i++) {
        pthread_mutex_lock(&locks[i]);
        for (struct entry *e=table[i]; e; e=e->next) total++;
        pthread_mutex_unlock(&locks[i]);
    }
    return total;
}
```

### V8: Dynamic Table Resizing
```c
// Acquire ALL bucket locks before resize
void resize(int new_nbucket) {
    for (int i=0; i<NBUCKET; i++) pthread_mutex_lock(&locks[i]);
    // rehash all entries into new_table with new_nbucket
    for (int i=0; i<NBUCKET; i++) pthread_mutex_unlock(&locks[i]);
}
```

### V9: Lock-Free Read (atomic retry)
```c
// Optimistic read without lock, retry if table modified
static struct entry* get_lockfree(int key) {
    int i = key % NBUCKET;
    struct entry *e;
retry:
    e = table[i]; // volatile read
    while (e) { if (e->key == key) return e; e = e->next; }
    return 0;
}
```

### V10: Per-Thread Local Tables That Merge
```c
struct entry *local_table[MAX_THREADS][NBUCKET]; // no locks needed during local puts
void local_put(int tid, int key, int val) { int i=key%NBUCKET; insert(key,val,&local_table[tid][i],local_table[tid][i]); }
void merge_all() { // merge needs locks
    for (int t=0;t<nthread;t++) for (int i=0;i<NBUCKET;i++) {
        pthread_mutex_lock(&locks[i]);
        /* append local_table[t][i] to global table[i] */
        pthread_mutex_unlock(&locks[i]);
    }
}
```

### V11: Hand-Over-Hand Locking (linked list traversal)
```c
// Lock current node, lock next, unlock current, advance
static struct entry* get_hoh(int key) {
    int i = key % NBUCKET;
    pthread_mutex_lock(&locks[i]); // lock bucket head
    struct entry *prev=0, *e=table[i];
    while (e) {
        if (e->key == key) { pthread_mutex_unlock(&locks[i]); return e; }
        // In a real HOH with per-node locks: lock(e->next); unlock(e);
        e = e->next;
    }
    pthread_mutex_unlock(&locks[i]); return 0;
}
```

### V12: Spinlocks (busy-wait instead of sleep)
```c
volatile int spinlocks[NBUCKET] = {0};
void spin_lock(int i) { while(__sync_lock_test_and_set(&spinlocks[i], 1)); }
void spin_unlock(int i) { __sync_lock_release(&spinlocks[i]); }
// put: spin_lock(i); ... spin_unlock(i);
```

### V13: Custom RW Lock Using Condvars
```c
struct rwlock { pthread_mutex_t m; pthread_cond_t c; int readers; int writer; };
void rw_rlock(struct rwlock *l) { pthread_mutex_lock(&l->m); while(l->writer) pthread_cond_wait(&l->c,&l->m); l->readers++; pthread_mutex_unlock(&l->m); }
void rw_runlock(struct rwlock *l) { pthread_mutex_lock(&l->m); l->readers--; if(!l->readers) pthread_cond_broadcast(&l->c); pthread_mutex_unlock(&l->m); }
void rw_wlock(struct rwlock *l) { pthread_mutex_lock(&l->m); while(l->writer||l->readers) pthread_cond_wait(&l->c,&l->m); l->writer=1; pthread_mutex_unlock(&l->m); }
void rw_wunlock(struct rwlock *l) { pthread_mutex_lock(&l->m); l->writer=0; pthread_cond_broadcast(&l->c); pthread_mutex_unlock(&l->m); }
```

### V14: Thread-Safe Update (atomic read-modify-write)
```c
static void update(int key, int delta) {
    int i = key % NBUCKET;
    pthread_mutex_lock(&locks[i]);
    struct entry *e;
    for (e=table[i]; e; e=e->next) { if (e->key==key) { e->value += delta; break; } }
    pthread_mutex_unlock(&locks[i]);
}
```

---

## Common Exam Modifications Quick Reference

| Asked To | Variation | What to Change |
|----------|-----------|----------------|
| Send array over pipe | Handshake V1 | `write(p, arr, sizeof(arr))` |
| Read until EOF | Handshake V2 | `while(read()>0)` + parent `close()` |
| Multi-round exchange | Handshake V4 | `for` loop around read/write |
| Build pipe cmd1\|cmd2 | Handshake V5 | `dup()` + `close()` + `exec()` |
| Send size then data | Handshake V6 | `write(&len, sizeof(int))` first |
| Struct over pipe | Handshake V9 | `write(&struct, sizeof(struct))` |
| Sync barrier via pipe | Handshake V14 | Two pipes: ready + go signals |
| Find all secrets | Sniffer V5 | `found++; i += 4096` in loop |
| Decrypt XOR secret | Sniffer V4 | XOR each byte with key |
| Variable offset | Sniffer V2 | `*(int*)(p+i+len)` to read offset |
| Struct recovery | Sniffer V7 | Cast `(struct*)(p+i+16)` |
| Trace syscall args | Monitor V3 | Save `a0` before, print after |
| Count syscalls | Monitor V4 | `p->syscall_counts[num]++` |
| Filter by retval | Monitor V5 | `if (ret > threshold)` |
| Print process name | Monitor V6 | `p->name` in printf |
| Trace timing | Monitor V9 | `ticks` before/after syscall |
| Thread join | Uthread V1 | `while(state!=FREE) yield()` |
| Thread priorities | Uthread V2 | `if (priority > best)` in schedule |
| Thread arguments | Uthread V5 | Trampoline + start_info struct |
| User mutex | Uthread V6 | `while(locked) yield()` |
| Thread sleep | Uthread V3 | SLEEPING state + tick counter |
| Save extra regs | Uthread V4 | `sd t0-t6` in assembly |
| RW locks for hash | PH V1 | `pthread_rwlock_t` |
| Delete from hash | PH V2 | Double pointer `**pp` traversal |
| Producer-consumer | PH V3 | `cond_wait` with `while` loop |
| Barrier sync | PH V4 | `count++; if(count==n) broadcast` |
| Global lock | PH V5 | Single mutex (simple, slow) |
| Deadlock-safe swap | PH V6 | Always lock lower bucket first |
| Spinlock | PH V12 | `__sync_lock_test_and_set` |
