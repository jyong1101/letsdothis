# xv6 User Programs Cheatsheet (sixfive & xargs)

## 📋 Contents

### SIXFIVE
- [Core Algorithm](#sixfive---core-algorithm)
- [Variation 1: Different Divisors](#variation-1-different-divisors)
- [Variation 2: Different Output Formats](#variation-2-different-output-formats)
- [Variation 3: Different Separators](#variation-3-different-separators)
- [Variation 4: Include Numbers in Words](#variation-4-include-numbers-in-words)
- [Variation 5: Print Only Unique Numbers](#variation-5-print-only-unique-numbers)

### XARGS
- [Core Algorithm](#xargs---core-algorithm)
- [Variation 1: Different Delimiters](#variation-1-different-delimiters)
- [Variation 2: Execute After Every Arg](#variation-2-execute-after-every-argument-like--n-1)
- [Variation 3: Batch Execute Once](#variation-3-batch-all-args-then-execute-once)
- [Variation 4: Print Command Before Exec](#variation-4-print-command-before-executing)
- [Variation 5: Handle -n Flag](#variation-5-handle--n-flag)

### Reference
- [Key Functions Reference](#key-functions-reference)
- [Common Exam Modifications](#common-exam-modifications-quick-reference)

---

## SIXFIVE - Core Algorithm

```c
#include "kernel/types.h"
#include "user/user.h"

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(2, "Usage: sixfive <file1> [file2...]\n");
        exit(1);
    }

    for (int j = 1; j < argc; j++) {
        int fd = open(argv[j], 0);
        if (fd < 0) {
            fprintf(2, "Cannot open %s\n", argv[j]);
            continue;
        }

        char c;
        char num_buf[32];
        int i = 0;
        int isValid = 1;
        
        // ═══════════════════════════════════════════════════════
        // MODIFY HERE: Change separator characters
        char *separators = " -\r\t\n./,";
        // ═══════════════════════════════════════════════════════

        while (read(fd, &c, 1) > 0) {
            if (strchr(separators, c)) {
                // SEPARATOR HIT - process number
                if (i > 0 && isValid) {
                    num_buf[i] = '\0';
                    int n = atoi(num_buf);
                    
                    // ═══════════════════════════════════════════
                    // MODIFY HERE: Change divisibility condition
                    if (n % 5 == 0 || n % 6 == 0) {
                        printf("%d\n", n);
                    }
                    // ═══════════════════════════════════════════
                }
                i = 0;
                isValid = 1;
            }
            else if (c >= '0' && c <= '9') {
                // DIGIT - add to buffer
                if (i < 31) num_buf[i++] = c;
            }
            else {
                // LETTER/OTHER - invalidates as embedded number
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

---

## SIXFIVE Variations

### Variation 1: Different Divisors
```c
// Multiples of 3 OR 7
if (n % 3 == 0 || n % 7 == 0) {
    printf("%d\n", n);
}

// Multiples of 3 AND 7 (i.e., 21)
if (n % 3 == 0 && n % 7 == 0) {
    printf("%d\n", n);
}

// Multiples of ANY of 2, 3, or 5
if (n % 2 == 0 || n % 3 == 0 || n % 5 == 0) {
    printf("%d\n", n);
}
```

### Variation 2: Different Output Formats
```c
// Count how many match
int count = 0;
if (n % 5 == 0 || n % 6 == 0) {
    count++;
}
// At end: printf("Count: %d\n", count);

// Sum all matching
int sum = 0;
if (n % 5 == 0 || n % 6 == 0) {
    sum += n;
}
// At end: printf("Sum: %d\n", sum);

// Print with label
if (n % 5 == 0 || n % 6 == 0) {
    printf("Found: %d\n", n);
}
```

### Variation 3: Different Separators
```c
// Only whitespace
char *separators = " \r\t\n";

// Include colon and semicolon
char *separators = " -\r\t\n./,:;";

// Only newlines (line by line)
char *separators = "\n";
```

### Variation 4: Include Numbers in Words
```c
// Remove the isValid check to include embedded numbers like "xv6"
while (read(fd, &c, 1) > 0) {
    if (strchr(separators, c)) {
        if (i > 0) {  // ← REMOVED isValid check
            num_buf[i] = '\0';
            int n = atoi(num_buf);
            if (n % 5 == 0 || n % 6 == 0) {
                printf("%d\n", n);
            }
        }
        i = 0;
    }
    else if (c >= '0' && c <= '9') {
        if (i < 31) num_buf[i++] = c;
    }
    // ← NO else branch for letters
}
```

### Variation 5: Print Only Unique Numbers
```c
// Add at top
int found[1000];
int found_count = 0;

// In the check:
if (n % 5 == 0 || n % 6 == 0) {
    int is_dup = 0;
    for (int k = 0; k < found_count; k++) {
        if (found[k] == n) { is_dup = 1; break; }
    }
    if (!is_dup) {
        printf("%d\n", n);
        found[found_count++] = n;
    }
}
```

---

## XARGS - Core Algorithm

```c
#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"
#include "kernel/param.h"

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("Usage: xargs <command> [args...]\n");
        exit(1);
    }

    // Build base argv from command line
    char *xargv[MAXARG];
    int base_argc = 0;
    for (int i = 1; i < argc; i++) {
        xargv[base_argc++] = argv[i];
    }

    int cur_argc = base_argc;
    char buf[1024];
    int n = 0;
    char c;

    while (read(0, &c, 1) > 0) {
        // ═══════════════════════════════════════════════════════
        // MODIFY HERE: Change delimiters
        if (c == '\n' || c == ' ' || c == '\t') {
        // ═══════════════════════════════════════════════════════
            if (n > 0) {
                buf[n] = 0;
                char *arg = malloc(n + 1);
                strcpy(arg, buf);
                xargv[cur_argc++] = arg;
                xargv[cur_argc] = 0;
                n = 0;
            }

            // ═══════════════════════════════════════════════════
            // MODIFY HERE: When to execute
            if (c == '\n' && cur_argc > base_argc) {
            // ═══════════════════════════════════════════════════
                if (fork() == 0) {
                    exec(xargv[0], xargv);
                    exit(1);
                }
                wait(0);
                cur_argc = base_argc;
            }
        } else {
            if (n < 1023) buf[n++] = c;
        }
    }

    // Handle remaining args
    if (cur_argc > base_argc) {
        xargv[cur_argc] = 0;
        if (fork() == 0) {
            exec(xargv[0], xargv);
            exit(1);
        }
        wait(0);
    }
    exit(0);
}
```

---

## XARGS Variations

### Variation 1: Different Delimiters
```c
// Only newlines (one arg per line)
if (c == '\n') {

// Comma-separated
if (c == ',' || c == '\n') {

// Custom delimiter (e.g., colon)
if (c == ':' || c == '\n') {
```

### Variation 2: Execute After Every Argument (like -n 1)
```c
// Execute after EACH whitespace arg, not just newlines
if (c == '\n' || c == ' ' || c == '\t') {
    if (n > 0) {
        buf[n] = 0;
        char *arg = malloc(n + 1);
        strcpy(arg, buf);
        xargv[cur_argc++] = arg;
        xargv[cur_argc] = 0;
        n = 0;

        // Execute immediately for EACH arg
        if (fork() == 0) {
            exec(xargv[0], xargv);
            exit(1);
        }
        wait(0);
        cur_argc = base_argc;  // Reset for next
    }
}
```

### Variation 3: Batch All Args Then Execute Once
```c
// Remove execution on newline, only execute at EOF
while (read(0, &c, 1) > 0) {
    if (c == '\n' || c == ' ' || c == '\t') {
        if (n > 0) {
            buf[n] = 0;
            char *arg = malloc(n + 1);
            strcpy(arg, buf);
            xargv[cur_argc++] = arg;
            n = 0;
        }
        // NO execution here - just collect
    } else {
        if (n < 1023) buf[n++] = c;
    }
}

// Execute ONCE at end with ALL collected args
xargv[cur_argc] = 0;
if (fork() == 0) {
    exec(xargv[0], xargv);
    exit(1);
}
wait(0);
```

### Variation 4: Print Command Before Executing
```c
if (fork() == 0) {
    // Print command being executed
    printf("Executing:");
    for (int k = 0; xargv[k] != 0; k++) {
        printf(" %s", xargv[k]);
    }
    printf("\n");
    
    exec(xargv[0], xargv);
    exit(1);
}
```

### Variation 5: Handle -n Flag
```c
int main(int argc, char *argv[]) {
    int n_flag = 1;  // default: 1 arg per exec
    int cmd_start = 1;
    
    // Check for -n flag
    if (argc >= 3 && strcmp(argv[1], "-n") == 0) {
        n_flag = atoi(argv[2]);
        cmd_start = 3;
    }
    
    // Build base argv starting from cmd_start
    for (int i = cmd_start; i < argc; i++) {
        xargv[base_argc++] = argv[i];
    }
    
    // Count args and execute when reaching n_flag
    int arg_count = 0;
    // ... in the loop:
    if (++arg_count >= n_flag) {
        // Execute and reset
        arg_count = 0;
    }
}
```

---

## Key Functions Reference

| Function | Description | Example |
|----------|-------------|---------|
| `open(path, 0)` | Open file read-only | `int fd = open("file.txt", 0);` |
| `read(fd, &c, 1)` | Read 1 char | `while (read(fd, &c, 1) > 0)` |
| `close(fd)` | Close file | `close(fd);` |
| `strchr(s, c)` | Find char in string | `if (strchr(" -,", c))` |
| `atoi(s)` | String to int | `int n = atoi(buf);` |
| `fork()` | Create child | `if (fork() == 0) { /* child */ }` |
| `exec(cmd, argv)` | Run program | `exec(argv[0], argv);` |
| `wait(0)` | Wait for child | `wait(0);` |
| `malloc(n)` | Allocate memory | `char *s = malloc(64);` |
| `strcpy(dst, src)` | Copy string | `strcpy(new_arg, buf);` |

---

## Common Exam Modifications Quick Reference

| Asked To | Solution ↑ | What to Change |
|----------|------------|----------------|
| Change divisors | [Variation 1](#variation-1-different-divisors) | `n % X == 0` condition |
| Add AND condition | [Variation 1](#variation-1-different-divisors) | `\|\|` → `&&` |
| Change separators | [Variation 3](#variation-3-different-separators) | separators string |
| Sum instead of print | [Variation 2](#variation-2-different-output-formats) | Add counter, print at end |
| Include embedded nums | [Variation 4](#variation-4-include-numbers-in-words) | Remove isValid logic |
| Print unique only | [Variation 5](#variation-5-print-only-unique-numbers) | Track seen numbers |
| Change delimiter | [xargs Var 1](#variation-1-different-delimiters) | The `if (c == ...)` check |
| Execute per-arg | [xargs Var 2](#variation-2-execute-after-every-argument-like--n-1) | Move exec inside token handler |
| Batch execute | [xargs Var 3](#variation-3-batch-all-args-then-execute-once) | Remove exec from loop, do at end |
| Print before exec | [xargs Var 4](#variation-4-print-command-before-executing) | Add printf before exec |
| Handle -n flag | [xargs Var 5](#variation-5-handle--n-flag) | Parse args, count before exec |
