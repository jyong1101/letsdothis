# xv6 System Call Cheatsheet

## 📋 Contents
- [Quick Reference: 7 Files Checklist](#quick-reference-adding-a-new-system-call-7-files)
- [Pattern 1: No Parameters](#pattern-1-syscall-with-no-parameters)
- [Pattern 2: INT Parameter](#pattern-2-syscall-with-int-parameter)
- [Pattern 3: STRING Parameter](#pattern-3-syscall-with-string-parameter)
- [Pattern 4: Multiple Parameters](#pattern-4-syscall-with-multiple-parameters)
- [Pattern 5: Accessing Process Info](#pattern-5-accessing-process-info)
- [Complete Example](#complete-example-syscall-with-parameter)
- [Argument Functions](#argument-retrieval-functions)
- [Common Modifications](#common-modifications-asked)

---

## Quick Reference: Adding a New System Call (7 Files)

| Step | File | What to Add |
|------|------|-------------|
| 1 | `kernel/syscall.h` | `#define SYS_mysc 23` |
| 2 | `kernel/syscall.c` | `extern uint64 sys_mysc(void);` + table entry |
| 3 | `kernel/sysproc.c` | Implement `sys_mysc(void)` |
| 4 | `kernel/defs.h` | `uint64 sys_mysc(void);` |
| 5 | `user/usys.pl` | `entry("mysc");` |
| 6 | `user/user.h` | `int mysc(void);` or `int mysc(int n);` |
| 7 | `Makefile` | `$U/_mysc\` in UPROGS |

---

## Pattern 1: Syscall with NO Parameters

```c
// kernel/sysproc.c
uint64 sys_hello(void) {
    printf("Hello from kernel!\n");
    return 0;
}
```

```c
// user/user.h
int hello(void);
```

---

## Pattern 2: Syscall with INT Parameter

```c
// kernel/sysproc.c
uint64 sys_mysyscall(void) {
    int n;
    argint(0, &n);           // ← GET FIRST INT ARG
    
    printf("Got number: %d\n", n);
    return n * 2;            // ← MODIFY RETURN VALUE
}
```

```c
// user/user.h
int mysyscall(int n);        // ← MUST MATCH EXPECTED ARG
```

```c
// user/test.c - calling it
int result = mysyscall(42);  // result = 84
```

---

## Pattern 3: Syscall with STRING Parameter

```c
// kernel/sysproc.c
uint64 sys_greet(void) {
    char name[64];
    argstr(0, name, 64);     // ← GET STRING (max 64 chars)
    
    printf("Hello, %s!\n", name);
    return 0;
}
```

```c
// user/user.h
int greet(char *name);
```

---

## Pattern 4: Syscall with MULTIPLE Parameters

```c
// kernel/sysproc.c
uint64 sys_addtwo(void) {
    int a, b;
    argint(0, &a);           // ← FIRST arg
    argint(1, &b);           // ← SECOND arg
    return a + b;
}
```

```c
// user/user.h
int addtwo(int a, int b);
```

---

## Pattern 5: Accessing Process Info

```c
// kernel/sysproc.c
#include "spinlock.h"
#include "proc.h"

uint64 sys_getprocinfo(void) {
    struct proc *p = myproc();    // ← GET CURRENT PROCESS
    
    printf("PID: %d\n", p->pid);
    printf("Name: %s\n", p->name);
    printf("State: %d\n", p->state);
    
    return p->pid;
}
```

**Process struct fields you can access:**
- `p->pid` - Process ID
- `p->name` - Process name (char[16])
- `p->state` - Process state (RUNNING, SLEEPING, etc.)
- `p->parent` - Parent process pointer

---

## Complete Example: Syscall with Parameter

### kernel/syscall.h
```c
#define SYS_close  21
#define SYS_double 22          // ← ADD THIS
```

### kernel/syscall.c
```c
extern uint64 sys_double(void);  // ← ADD EXTERN

static uint64 (*syscalls[])(void) = {
    // ... existing ...
    [SYS_close]   sys_close,
    [SYS_double]  sys_double,    // ← ADD TABLE ENTRY
};
```

### kernel/sysproc.c
```c
uint64 sys_double(void) {
    int n;
    argint(0, &n);
    return n * 2;
}
```

### kernel/defs.h
```c
// syscall.c section
uint64          sys_double(void);
```

### user/usys.pl
```perl
entry("double");
```

### user/user.h
```c
int double(int n);
```

### user/double.c
```c
#include "kernel/types.h"
#include "user/user.h"

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(2, "Usage: double <number>\n");
        exit(1);
    }
    int n = atoi(argv[1]);
    int result = double(n);
    printf("%d doubled = %d\n", n, result);
    exit(0);
}
```

---

## Argument Retrieval Functions

| Function | Purpose | Example |
|----------|---------|---------|
| `argint(n, &val)` | Get nth int arg | `argint(0, &x);` |
| `argstr(n, buf, sz)` | Get nth string | `argstr(0, buf, 64);` |
| `argaddr(n, &addr)` | Get nth pointer | `argaddr(0, &addr);` |

---

## Common Modifications Asked

| Modification | Where to Change |
|--------------|-----------------|
| Change output message | `printf()` in sys_xxx() |
| Add parameter | Add `argint()` + change user.h signature |
| Return process PID | `return myproc()->pid;` |
| Return uptime | `return ticks;` (need tickslock) |
