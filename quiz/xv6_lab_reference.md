# xv6 Lab 1 & Lab 2 Comprehensive Reference Guide

> **Purpose**: CLI AI reference document for xv6 RISC-V operating system labs.
> **Coverage**: Lab1-w1 (sleep, memdump), Lab1-w2 (hello syscall, sixfive, xargs)

---

## Table of Contents
1. [Environment Setup](#environment-setup)
2. [xv6 System Calls Reference](#xv6-system-calls-reference)
3. [Lab 1 Week 1 Tasks](#lab-1-week-1-tasks)
4. [Lab 1 Week 2 Tasks](#lab-1-week-2-tasks)
5. [Utility Functions Reference](#utility-functions-reference)
6. [Common Patterns & Templates](#common-patterns--templates)
7. [Testing & Grading](#testing--grading)

---

## Environment Setup

### Running xv6 on WSL Ubuntu
```bash
# Open Ubuntu WSL from Windows
wsl -d ubuntu

# Navigate to lab directory (Windows path)
cd /mnt/d/ICT1012/xv6labs-w1

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
int mkdir(const char *path);              // Create directory
int chdir(const char *path);              // Change directory
int link(const char *old, const char *new); // Create hard link
int unlink(const char *path);             // Delete file
int fstat(int fd, struct stat *st);       // Get file status
int mknod(const char *path, short major, short minor); // Create device

// Memory
char* sbrk(int n);                 // Grow memory by n bytes

// Timing
int pause(int ticks);              // Sleep for ticks (used by sleep)
int uptime(void);                  // Get ticks since boot

// Pipes
int pipe(int *fds);                // Create pipe, fds[0]=read, fds[1]=write
```

---

## Lab 1 Week 1 Tasks

### Task 1: sleep Program

**Objective**: Pause execution for user-specified number of ticks.

**File**: `user/sleep.c`

**Reference Implementation**:
```c
#include "kernel/types.h"
#include "kernel/stat.h" 
#include "user/user.h"

int main(int argc, char *argv[]) {
    // Check for argument
    if (argc != 2) {
        fprintf(2, "usage: sleep <ticks>\n");
        exit(1);
    }
    
    // Convert string argument to integer
    int ticks = atoi(argv[1]);
    
    // Use pause system call to sleep
    pause(ticks);
    
    exit(0);
}
```

**Key Concepts**:
- `argc` = argument count (includes program name)
- `argv[0]` = program name ("sleep")
- `argv[1]` = first argument (number of ticks)
- `atoi()` converts string to integer
- `pause(n)` sleeps for n timer ticks
- `fprintf(2, ...)` writes to stderr (fd 2)
- Always call `exit(0)` at end

**sys_pause Implementation** (kernel/sysproc.c):
```c
uint64 sys_pause(void) {
    int n;
    uint ticks0;
    
    argint(0, &n);              // Get first argument
    if(n < 0) n = 0;
    
    acquire(&tickslock);
    ticks0 = ticks;
    while(ticks - ticks0 < n) {
        if(killed(myproc())) {
            release(&tickslock);
            return -1;
        }
        sleep(&ticks, &tickslock);
    }
    release(&tickslock);
    return 0;
}
```

---

### Task 2: memdump Program

**Objective**: Print memory contents according to format string.

**File**: `user/memdump.c`

**Format Characters**:
| Format | Size | Description |
|--------|------|-------------|
| `c` | 1 byte | Print as ASCII character |
| `h` | 2 bytes | Print as 16-bit integer (decimal) |
| `i` | 4 bytes | Print as 32-bit integer (decimal) |
| `p` | 8 bytes | Print as 64-bit pointer (hex) |
| `s` | 8 bytes | Read 8-byte pointer, print string it points to |
| `S` | variable | Print rest of data as null-terminated string |

**Reference Implementation**:
```c
void memdump(char *fmt, char *data) {
    while (*fmt != 0) {
        if (*fmt == 'c') {
            // 1 byte - ASCII character
            char val = *data;
            printf("%c\n", val);
            data += 1;
        }
        else if (*fmt == 'h') {
            // 2 bytes - short integer
            short val = *(short *)data;
            printf("%d\n", val);
            data += 2;
        }
        else if (*fmt == 'i') {
            // 4 bytes - integer
            int val = *(int *)data;
            printf("%d\n", val);
            data += 4;
        }
        else if (*fmt == 'p') {
            // 8 bytes - pointer (print as hex)
            uint64 val = *(uint64 *)data;
            printf("%p\n", (void *)val);
            data += 8;
        }
        else if (*fmt == 's') {
            // 8 bytes - pointer to string
            char *str_val = *(char **)data;
            printf("%s\n", str_val);
            data += 8;
        }
        else if (*fmt == 'S') {
            // Rest of data is inline string
            printf("%s\n", data);
            break;  // S consumes rest of data
        }
        fmt++;
    }
}
```

**Memory Layout Diagram**:
```
Format: "pihcS"
Data structure:
+------------------+
| char *ptr   (8B) |  -> "hello"
+------------------+
| int num1    (4B) |  = 1819438967
+------------------+
| short num2  (2B) |  = 100
+------------------+
| char byte   (1B) |  = 'z'
+------------------+
| char bytes[8]    |  = "xyzzy\0..."
+------------------+
```

**Usage Examples**:
```bash
$ memdump                    # Run built-in examples
$ echo deadc0de | memdump hhcccc
# Output: 25956, 25697, c, 0, d, e

$ echo deadc0de | memdump p
# Output: 64616564
```

---

## Lab 1 Week 2 Tasks

### Task 1: Adding a New System Call (hello)

**Objective**: Create a new system call that prints from kernel space.

**Files to Modify**:

#### 1. kernel/syscall.h - Add syscall number
```c
#define SYS_mkdir  20
#define SYS_close  21
#define SYS_hello  22    // Add new syscall number
```

#### 2. kernel/syscall.c - Add extern and table entry
```c
// Add extern declaration
extern uint64 sys_hello(void);

// Add to syscalls[] array
static uint64 (*syscalls[])(void) = {
    // ... existing entries ...
    [SYS_close]   sys_close,
    [SYS_hello]   sys_hello,    // Add entry
};
```

#### 3. kernel/sysproc.c - Implement the syscall
```c
uint64 sys_hello(void) {
    printf("Hello from kernel syscall!\n");
    printf("I am ICT1012!\n");
    return 0;
}
```

#### 4. kernel/defs.h - Add function prototype
```c
// syscall.c section
uint64          sys_hello(void);
```

#### 5. user/usys.pl - Add user-space stub generator
```perl
entry("uptime");
entry("hello");    # Add entry
```

#### 6. user/user.h - Add user-space declaration
```c
int uptime(void);
int hello(void);   // Add declaration
```

#### 7. user/hello.c - Create test program
```c
#include "kernel/types.h"
#include "user/user.h"

int main(void) {
    int r = hello();
    printf("hello returned %d\n", r);
    return 0;
}
```

#### 8. Makefile - Add to UPROGS
```makefile
UPROGS=\
    $U/_hello\
```

**System Call Flow**:
```
User Space          |  Kernel Space
--------------------|------------------
hello() in user.h   |
        ↓           |
usys.S: ecall       | → trap handler
        ↓           |        ↓
                    |  syscall() dispatcher
                    |        ↓
                    |  sys_hello() in sysproc.c
                    |        ↓
return value ← ←  ← |  return 0
```

---

### Task 2: sixfive Program

**Objective**: Print all numbers divisible by 5 or 6 from input files.

**File**: `user/sixfive.c`

**Rules**:
- Numbers are separated by: ` `, `-`, `\r`, `\t`, `\n`, `.`, `/`, `,`
- Numbers embedded in words (like "xv6") are NOT printed
- Only standalone numbers count

**Reference Implementation**:
```c
#include "kernel/types.h"
#include "user/user.h"

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(2, "Usage: sixfive <filename1> <filename2> ...\n");
        exit(1);
    }

    // Process each file
    for (int j = 1; j < argc; j++) {
        int fd = open(argv[j], 0);  // 0 = O_RDONLY
        if (fd < 0) {
            fprintf(2, "Error: cannot open file %s\n", argv[j]);
            continue;
        }

        char c;
        char num_buf[32];
        char *separators = " -\r\t\n./,";
        int i = 0;
        int isValid = 1;  // 1 = valid number, 0 = embedded in word

        while (read(fd, &c, 1) > 0) {
            if (strchr(separators, c)) {
                // Hit a separator - process accumulated number
                if (i > 0 && isValid) {
                    num_buf[i] = '\0';
                    int n = atoi(num_buf);
                    if (n % 5 == 0 || n % 6 == 0) {
                        printf("%d\n", n);
                    }
                }
                i = 0;
                isValid = 1;
            }
            else if (c >= '0' && c <= '9') {
                // Digit - add to buffer
                if (i < 31) {
                    num_buf[i++] = c;
                }
            }
            else {
                // Letter or other - invalidates current sequence
                isValid = 0;
            }
        }

        // Handle last number (no trailing separator)
        if (i > 0 && isValid) {
            num_buf[i] = '\0';
            int n = atoi(num_buf);
            if (n % 5 == 0 || n % 6 == 0) {
                printf("%d\n", n);
            }
        }

        close(fd);
    }
    exit(0);
}
```

**Key Functions Used**:
- `open(path, 0)` - Open file read-only
- `read(fd, &c, 1)` - Read one character
- `strchr(str, c)` - Check if char is in string (returns pointer or 0)
- `atoi(str)` - Convert string to int
- `close(fd)` - Close file

---

### Task 3: xargs Program

**Objective**: Read lines from stdin and execute command for each.

**File**: `user/xargs.c`

**Behavior**:
```bash
$ echo hello too | xargs echo bye
bye hello too

$ (echo 1 ; echo 2) | xargs -n 1 echo
1
2
```

**Reference Implementation**:
```c
#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"
#include "kernel/param.h"  // For MAXARG

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("Usage: xargs <command> [args...]\n");
        exit(1);
    }

    // Build initial argv array from command line args
    char *xargv[MAXARG];
    int static_argc = 0;
    
    for (int i = 1; i < argc; i++) {
        xargv[static_argc++] = argv[i];
    }

    int current_argc = static_argc;
    char buf[1024];
    int n = 0;
    char c;

    // Read from stdin character by character
    while (read(0, &c, 1) > 0) {
        if (c == '\n' || c == ' ' || c == '\t') {
            if (n > 0) {
                buf[n] = 0;
                
                // Allocate and copy argument
                char *new_arg = malloc(n + 1);
                strcpy(new_arg, buf);
                
                xargv[current_argc++] = new_arg;
                xargv[current_argc] = 0;  // Null terminate
                
                n = 0;
            }
            
            // On newline, execute command
            if (c == '\n' && current_argc > static_argc) {
                if (fork() == 0) {
                    exec(xargv[0], xargv);
                    exit(1);
                } else {
                    wait(0);
                }
                current_argc = static_argc;
            }
        } else {
            if (n < 1023) {
                buf[n++] = c;
            }
        }
    }

    // Handle remaining arguments
    if (current_argc > static_argc) {
        xargv[current_argc] = 0;
        if (fork() == 0) {
            exec(xargv[0], xargv);
            exit(1);
        } else {
            wait(0);
        }
    }

    exit(0);
}
```

**Key Concepts**:
- `fork()` - Returns 0 in child, PID in parent
- `exec(cmd, argv)` - Replace process with new program
- `wait(0)` - Wait for any child to exit
- `MAXARG` - Maximum number of arguments (from kernel/param.h)
- Always null-terminate argv array: `argv[n] = 0`

**Fork/Exec Pattern**:
```c
if (fork() == 0) {
    // Child process
    exec(command, arguments);
    exit(1);  // Only reached if exec fails
} else {
    // Parent process
    wait(0);  // Wait for child
}
```

---

## Utility Functions Reference

### String Functions (user/ulib.c)

```c
// Copy string from src to dst
char* strcpy(char *dst, const char *src);

// Compare strings (0 = equal)
int strcmp(const char *p, const char *q);

// Get string length
uint strlen(const char *s);

// Find character in string (returns pointer or 0)
char* strchr(const char *s, char c);

// Convert string to integer
int atoi(const char *s);
```

### Memory Functions (user/ulib.c)

```c
// Set n bytes to value c
void* memset(void *dst, int c, uint n);

// Copy n bytes (handles overlap)
void* memmove(void *dst, const void *src, int n);

// Copy n bytes
void* memcpy(void *dst, const void *src, uint n);

// Compare n bytes
int memcmp(const void *s1, const void *s2, uint n);
```

### Memory Allocation (user/umalloc.c)

```c
void* malloc(uint nbytes);  // Allocate memory
void free(void *ptr);       // Free memory
```

### I/O Functions (user/printf.c)

```c
// Print formatted output
void printf(const char *fmt, ...);

// Print to file descriptor (fd=1 stdout, fd=2 stderr)
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

---

## Common Patterns & Templates

### Basic User Program Template
```c
#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"

int main(int argc, char *argv[]) {
    // Argument validation
    if (argc < 2) {
        fprintf(2, "Usage: %s <arg>\n", argv[0]);
        exit(1);
    }
    
    // Your code here
    
    exit(0);
}
```

### File Reading Pattern
```c
int fd = open(filename, 0);  // O_RDONLY = 0
if (fd < 0) {
    fprintf(2, "Error: cannot open %s\n", filename);
    exit(1);
}

char buf[512];
int n;
while ((n = read(fd, buf, sizeof(buf))) > 0) {
    // Process buf[0..n-1]
}

close(fd);
```

### Character-by-Character Reading
```c
char c;
while (read(fd, &c, 1) > 0) {
    // Process single character
}
```

### Pipe Usage Pattern
```c
int p[2];
pipe(p);  // p[0]=read end, p[1]=write end

if (fork() == 0) {
    // Child: write to pipe
    close(p[0]);  // Close read end
    write(p[1], "hello", 5);
    close(p[1]);
    exit(0);
} else {
    // Parent: read from pipe
    close(p[1]);  // Close write end
    char buf[100];
    read(p[0], buf, sizeof(buf));
    close(p[0]);
    wait(0);
}
```

---

## Testing & Grading

### Running Individual Tests
```bash
# Test specific program
./grade-lab-util sleep
./grade-lab-util memdump
./grade-lab-util hello
./grade-lab-util sixfive
./grade-lab-util xargs
```

### Full Grade
```bash
make grade
```

### Expected Scores
- **Lab1-w1**: 40/40 (sleep + memdump)
- **Lab1-w2**: 55/55 (hello + sixfive + xargs)

### Creating Submission
```bash
make zipball
# Creates lab.zip for upload
```

### Test Cases Overview

**sleep tests**:
- `sleep, no arguments` - Should print error
- `sleep, returns` - Should exit properly
- `sleep, makes syscall` - Should use pause syscall

**memdump tests**:
- `memdump, examples` - Built-in examples output correctly
- `memdump, format ii, S, p` - Various format combinations

**hello tests**:
- `hello` - Prints kernel messages and returns 0

**sixfive tests**:
- `sixfive_test` - Basic file processing
- `sixfive_readme` - Process README file
- `sixfive_all` - Multiple file handling

**xargs tests**:
- `xargs` - Basic piped input
- `xargs, multi-line echo` - Multiple line handling

---

## Quick Reference Card

### File Descriptors
| FD | Name | Description |
|----|------|-------------|
| 0 | stdin | Standard input |
| 1 | stdout | Standard output |
| 2 | stderr | Standard error |

### Common Errors
| Error | Cause | Fix |
|-------|-------|-----|
| No command | Missing in UPROGS | Add `$U/_program\` to Makefile |
| Exec fail | Wrong path | Check command name in argv[0] |
| Segfault | NULL pointer | Check return values |
| Hang | Missing exit() | Add exit(0) at end |

### Size Reference
| Type | Bytes |
|------|-------|
| char | 1 |
| short | 2 |
| int | 4 |
| uint64 | 8 |
| pointer | 8 |

### Exit Codes
| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Error/Failure |

---

*Generated for ICT1012 Operating Systems - Lab 1 & Lab 2 Reference*
