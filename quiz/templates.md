# xv6 Program Templates Cheatsheet

## 📋 Contents

### Templates
1. [Basic User Program](#template-1-basic-user-program)
2. [Read File Char-by-Char](#template-2-read-file-character-by-character)
3. [Read File in Chunks](#template-3-read-file-in-chunks-bulk)
4. [Read from Stdin](#template-4-read-from-stdin)
5. [Process Multiple Files](#template-5-process-multiple-files)
6. [Fork and Execute](#template-6-fork-and-execute-command)
7. [Dynamic Argument List](#template-7-build-dynamic-argument-list)
8. [Pipe Between Processes](#template-8-pipe-between-processes)
9. [Parse Numbers from Text](#template-9-parse-numbers-from-text)
10. [Line-by-Line Processing](#template-10-line-by-line-processing)
11. [memdump-style Parser](#template-11-memdump-style-format-parser)

### Reference
- [Data Size Reference](#common-data-size-reference)
- [Utility Functions](#utility-functions-quick-reference)
- [File Descriptors](#file-descriptor-reference)
- [Common Mistakes](#common-mistakes-to-avoid)
- [Makefile Entry](#makefile-entry-format)

---

## Template 1: Basic User Program

```c
#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"

int main(int argc, char *argv[]) {
    // ARGUMENT VALIDATION
    if (argc < 2) {
        fprintf(2, "Usage: %s <arg>\n", argv[0]);
        exit(1);
    }
    
    // YOUR CODE HERE
    
    exit(0);  // ALWAYS exit!
}
```

**Remember:** Add to Makefile UPROGS: `$U/_programname\`

---

## Template 2: Read File Character-by-Character

```c
#include "kernel/types.h"
#include "user/user.h"

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(2, "Usage: %s <filename>\n", argv[0]);
        exit(1);
    }

    int fd = open(argv[1], 0);  // 0 = O_RDONLY
    if (fd < 0) {
        fprintf(2, "Cannot open %s\n", argv[1]);
        exit(1);
    }

    char c;
    while (read(fd, &c, 1) > 0) {
        // PROCESS EACH CHARACTER
        printf("%c", c);  // Example: just echo it
    }

    close(fd);
    exit(0);
}
```

---

## Template 3: Read File in Chunks (Bulk)

```c
#include "kernel/types.h"
#include "user/user.h"

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(2, "Usage: %s <filename>\n", argv[0]);
        exit(1);
    }

    int fd = open(argv[1], 0);
    if (fd < 0) {
        fprintf(2, "Cannot open %s\n", argv[1]);
        exit(1);
    }

    char buf[512];
    int n;
    while ((n = read(fd, buf, sizeof(buf))) > 0) {
        // PROCESS buf[0] to buf[n-1]
        write(1, buf, n);  // Example: write to stdout
    }

    close(fd);
    exit(0);
}
```

---

## Template 4: Read from Stdin

```c
#include "kernel/types.h"
#include "user/user.h"

int main(int argc, char *argv[]) {
    char c;
    
    // Read from stdin (fd = 0) until EOF
    while (read(0, &c, 1) > 0) {
        // PROCESS EACH CHARACTER
        if (c == '\n') {
            // End of line
        }
    }
    
    exit(0);
}
```

**Usage:** `echo "input" | program` or `program < file.txt`

---

## Template 5: Process Multiple Files

```c
#include "kernel/types.h"
#include "user/user.h"

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(2, "Usage: %s <file1> [file2...]\n", argv[0]);
        exit(1);
    }

    // Loop through all file arguments
    for (int i = 1; i < argc; i++) {
        int fd = open(argv[i], 0);
        if (fd < 0) {
            fprintf(2, "Cannot open %s\n", argv[i]);
            continue;  // Skip bad files
        }

        // PROCESS THIS FILE
        char c;
        while (read(fd, &c, 1) > 0) {
            // ...
        }

        close(fd);
    }
    
    exit(0);
}
```

---

## Template 6: Fork and Execute Command

```c
#include "kernel/types.h"
#include "user/user.h"

int main(int argc, char *argv[]) {
    char *cmd = "/echo";      // Command to run
    char *args[] = {"echo", "hello", "world", 0};  // NULL-terminated!
    
    if (fork() == 0) {
        // CHILD PROCESS
        exec(cmd, args);
        fprintf(2, "exec failed\n");
        exit(1);
    } else {
        // PARENT PROCESS
        wait(0);  // Wait for child
        printf("Child finished\n");
    }
    
    exit(0);
}
```

---

## Template 7: Build Dynamic Argument List

```c
#include "kernel/types.h"
#include "user/user.h"
#include "kernel/param.h"  // For MAXARG

int main(int argc, char *argv[]) {
    char *newargv[MAXARG];
    int n = 0;
    
    // Add static args
    newargv[n++] = "echo";
    newargv[n++] = "prefix";
    
    // Add dynamic args from command line
    for (int i = 1; i < argc; i++) {
        newargv[n++] = argv[i];
    }
    
    // MUST null-terminate!
    newargv[n] = 0;
    
    if (fork() == 0) {
        exec(newargv[0], newargv);
        exit(1);
    }
    wait(0);
    exit(0);
}
```

---

## Template 8: Pipe Between Processes

```c
#include "kernel/types.h"
#include "user/user.h"

int main(void) {
    int p[2];
    pipe(p);  // p[0] = read end, p[1] = write end
    
    if (fork() == 0) {
        // CHILD: Writer
        close(p[0]);              // Close read end
        write(p[1], "hello", 5);  // Write to pipe
        close(p[1]);
        exit(0);
    } else {
        // PARENT: Reader
        close(p[1]);              // Close write end
        char buf[100];
        int n = read(p[0], buf, sizeof(buf));
        buf[n] = '\0';
        printf("Received: %s\n", buf);
        close(p[0]);
        wait(0);
    }
    
    exit(0);
}
```

---

## Template 9: Parse Numbers from Text

```c
#include "kernel/types.h"
#include "user/user.h"

// SEPARATORS - modify as needed
char *separators = " -\r\t\n./,";

int is_separator(char c) {
    return strchr(separators, c) != 0;
}

int main(int argc, char *argv[]) {
    int fd = open(argv[1], 0);
    
    char c;
    char num_buf[32];
    int i = 0;
    int isValid = 1;  // Track if pure number (not embedded)
    
    while (read(fd, &c, 1) > 0) {
        if (is_separator(c)) {
            // Process accumulated number
            if (i > 0 && isValid) {
                num_buf[i] = '\0';
                int n = atoi(num_buf);
                
                // DO SOMETHING WITH n
                printf("Found: %d\n", n);
            }
            i = 0;
            isValid = 1;
        }
        else if (c >= '0' && c <= '9') {
            if (i < 31) num_buf[i++] = c;
        }
        else {
            // Letter - number is embedded in word
            isValid = 0;
        }
    }
    
    // Handle last number (no trailing separator)
    if (i > 0 && isValid) {
        num_buf[i] = '\0';
        int n = atoi(num_buf);
        printf("Found: %d\n", n);
    }
    
    close(fd);
    exit(0);
}
```

---

## Template 10: Line-by-Line Processing

```c
#include "kernel/types.h"
#include "user/user.h"

int main(int argc, char *argv[]) {
    int fd = open(argv[1], 0);
    
    char line[256];
    int len = 0;
    char c;
    
    while (read(fd, &c, 1) > 0) {
        if (c == '\n') {
            line[len] = '\0';
            
            // PROCESS LINE HERE
            printf("Line: %s\n", line);
            
            len = 0;  // Reset for next line
        } else {
            if (len < 255) line[len++] = c;
        }
    }
    
    // Handle last line (no trailing newline)
    if (len > 0) {
        line[len] = '\0';
        printf("Line: %s\n", line);
    }
    
    close(fd);
    exit(0);
}
```

---

## Template 11: memdump-style Format Parser

```c
#include "kernel/types.h"
#include "user/user.h"

void memdump(char *fmt, char *data) {
    while (*fmt != 0) {
        switch (*fmt) {
            case 'c':  // 1 byte - char
                printf("%c\n", *data);
                data += 1;
                break;
            
            case 'h':  // 2 bytes - short
                printf("%d\n", *(short *)data);
                data += 2;
                break;
            
            case 'i':  // 4 bytes - int
                printf("%d\n", *(int *)data);
                data += 4;
                break;
            
            case 'p':  // 8 bytes - pointer (hex)
                printf("%p\n", (void *)*(uint64 *)data);
                data += 8;
                break;
            
            case 's':  // 8 bytes - pointer to string
                printf("%s\n", *(char **)data);
                data += 8;
                break;
            
            case 'S':  // Rest is inline string
                printf("%s\n", data);
                return;  // S consumes rest
            
            // ADD NEW FORMATS HERE
            // case 'o':  // octal
            //     printf("%o\n", *(int *)data);
            //     data += 4;
            //     break;
        }
        fmt++;
    }
}
```

---

## Common Data Size Reference

| Type | Size | Cast |
|------|------|------|
| char | 1 byte | `*data` |
| short | 2 bytes | `*(short *)data` |
| int | 4 bytes | `*(int *)data` |
| uint64/pointer | 8 bytes | `*(uint64 *)data` |

---

## Utility Functions Quick Reference

### String Functions
```c
int   strlen(const char *s);           // Get length
char* strcpy(char *dst, const char *src);  // Copy string
int   strcmp(const char *a, const char *b);  // Compare (0=equal)
char* strchr(const char *s, char c);   // Find char (NULL if not found)
```

### Number Conversion
```c
int atoi(const char *s);  // String to int: "123" → 123
```

### Memory Functions
```c
void* memset(void *p, int c, uint n);   // Set n bytes to c
void* memcpy(void *dst, void *src, uint n);  // Copy n bytes
void* malloc(uint n);   // Allocate n bytes
void  free(void *p);    // Free allocated memory
```

### I/O Functions
```c
void printf(const char *fmt, ...);       // Print to stdout
void fprintf(int fd, const char *fmt, ...);  // Print to fd (2=stderr)
```

### Process Functions
```c
int  fork(void);             // Create child (0 in child, pid in parent)
int  exec(char *path, char **argv);  // Replace with new program
void exit(int status);       // Terminate (0=success, 1=error)
int  wait(int *status);      // Wait for child
int  getpid(void);           // Get current PID
```

### File Functions
```c
int open(const char *path, int mode);  // Open (0=read, 1=write)
int read(int fd, void *buf, int n);    // Read n bytes
int write(int fd, void *buf, int n);   // Write n bytes
int close(int fd);                     // Close file
```

---

## File Descriptor Reference

| FD | Name | Usage |
|----|------|-------|
| 0 | stdin | `read(0, &c, 1)` |
| 1 | stdout | `write(1, buf, n)` or `printf()` |
| 2 | stderr | `fprintf(2, "error\n")` |

---

## Common Mistakes to Avoid

| Mistake | Fix |
|---------|-----|
| Forgot `exit(0)` | Program hangs - always call exit() |
| argv not null-terminated | Add `argv[n] = 0;` after last arg |
| Forgot to close file | Add `close(fd);` after done |
| Buffer overflow | Check `i < BUFSIZE - 1` before adding |
| Using = instead of == | `if (n == 5)` not `if (n = 5)` |
| Forgot to handle last item | Check buffer after loop ends |

---

## Makefile Entry Format

```makefile
UPROGS=\
	$U/_cat\
	$U/_echo\
	$U/_myprogram\
```

**After changes:** `make clean && make qemu`
