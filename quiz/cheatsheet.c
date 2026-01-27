/*
 * XV6 PRACTICAL QUIZ MASTER CHEATSHEET - ICT1012
 * ----------------------------------------------------------------------------
 * This file contains templates for common quiz questions from Labs 1 & 2.
 * ----------------------------------------------------------------------------
 */

#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"
#include "kernel/fcntl.h"
#include "kernel/param.h" // Needed for MAXARG [cite: 291]

// ============================================================================
// PROBLEM TYPE 1: KERNEL MODIFICATION (e.g., sys_get_cmdline, sys_hello)
// ============================================================================
/*
 * GOAL: Add a system call that retrieves or prints kernel data.
 *
 * STEPS:
 * 1. kernel/syscall.h: Define number -> #define SYS_getname 23 [cite: 156-161]
 * 2. kernel/syscall.c: 
 * - Add: extern uint64 sys_getname(void); [cite: 162-166]
 * - Add: [SYS_getname] sys_getname, to the syscalls[] table [cite: 169-178]
 * 3. kernel/sysproc.c: Implement the handler.
 * - To print current process name: printf("%s", myproc()->name);
 * - To get Parent PID: return myproc()->parent->pid;
 * 4. kernel/defs.h: Add prototype -> uint64 sys_getname(void); [cite: 187, 203]
 * 5. user/usys.pl: Add entry -> entry("getname"); [cite: 205, 211]
 * 6. user/user.h: Add prototype -> int getname(void); [cite: 212, 217]
 */

// ============================================================================
// PROBLEM TYPE 2: PROCESS ORCHESTRATION (e.g., waitchild, limit, xargs)
// ============================================================================
/*
 * GOAL: Run one or more commands based on logic or input.
 *
 * STEPS:
 * 1. Check argc for required arguments [cite: 25, 222-224].
 * 2. If reading from pipe (stdin), use a while(read(0, ...)) loop[cite: 82, 290].
 * 3. Use fork() to create a child[cite: 288].
 * 4. In Child: Use exec(argv[0], argv)[cite: 288]. Array MUST end in 0[cite: 300].
 * 5. In Parent: Use wait(0) to ensure commands run sequentially[cite: 289].
 */

void run_sequential_example(char *cmd1, char **args1, char *cmd2, char **args2) {
    if(fork() == 0) {
        exec(cmd1, args1);
        exit(1);
    }
    wait(0); // Wait for first to finish [cite: 289]
    if(fork() == 0) {
        exec(cmd2, args2);
        exit(1);
    }
    wait(0);
}

// ============================================================================
// PROBLEM TYPE 3: TEXT PARSING & FILTERING (e.g., find_range, sum_only)
// ============================================================================
/*
 * GOAL: Find specific data inside a file using character-level scanning.
 *
 * STEPS:
 * 1. open(argv[i], O_RDONLY) to get file descriptor (fd)[cite: 256].
 * 2. while(read(fd, &c, 1) > 0) to read byte-by-byte[cite: 262].
 * 3. Use strchr(" \n\t", c) to identify separators[cite: 263].
 * 4. When a separator is found, convert the buffer: atoi(buf)[cite: 26].
 * 5. Apply range logic: if(val >= min && val <= max) { printf("%d\n", val); }
 * 6. Handle the "Last Word" case after the while loop finishes[cite: 264].
 */

// ============================================================================
// PROBLEM TYPE 4: MEMORY INSPECTION (e.g., memdump, endian_swap)
// ============================================================================
/*
 * GOAL: Interpret raw bytes as specific data types.
 *
 * SIZES & CASTS :
 * - Int (4 bytes):  *(int *)data;    data += 4;
 * - Short (2 bytes):*(short *)data;  data += 2;
 * - Ptr (8 bytes):  *(uint64 *)data; data += 8;
 * - Char (1 byte):  *data;           data += 1;
 */

void inspect_memory(char *data, int offset) {
    // Jump to a specific spot
    char *target = data + offset;
    // Read an integer at that spot
    int secret_val = *(int *)target;
    printf("Value at offset %d is %d\n", offset, secret_val);
}

// ============================================================================
// BOILERPLATE: THE "EVERYTHING" TEMPLATE
// ============================================================================

int main(int argc, char *argv[]) {
    // 1. Validate Input
    if(argc < 2) {
        fprintf(2, "Usage: %s <arg>\n", argv[0]);
        exit(1);
    }

    // 2. Logic (Parsing, Forking, or Syscall)
    // hello(); // Example syscall call [cite: 225]

    // 3. Finish
    exit(0); // Always exit [cite: 29]
}