/*
 * XV6 ADVANCED CHALLENGE CHEATSHEET
 * Logic for Uptime, Shell Modifications, and Kernel Data
 * ----------------------------------------------------------------------------
 */

#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"
#include "kernel/fcntl.h"

// ============================================================================
// 1. UPTIME UTILITY (Easy)
// ============================================================================
/*
 * TASK: Create 'uptime' program to print ticks since boot.
 * Logic: Call existing syscall and print. [cite: 210, 216]
 */
void uptime_logic() {
    int ticks = uptime(); 
    printf("Uptime: %d ticks\n", ticks);
    exit(0);
}

// ============================================================================
// 2. SHELL MODIFICATION: SILENCE PROMPT (Moderate)
// ============================================================================
/*
 * TASK: Don't print '$' when running commands from a file.
 * Logic: Use 'isatty' to check if input is the console or a file. 
 * File: user/sh.c
 */
void shell_prompt_logic() {
    // Inside the main loop of sh.c:
    // Only print the prompt if file descriptor 0 (stdin) is a terminal.
    if (isatty(0)) {
        fprintf(2, "$ ");
    }
}

// ============================================================================
// 3. SHELL MODIFICATION: SUPPORT 'WAIT' (Easy)
// ============================================================================
/*
 * TASK: Add a built-in 'wait' command to the shell.
 * Logic: Intercept "wait" before the shell tries to exec it as a file.
 * File: user/sh.c (near the 'cd' logic)
 */
void shell_wait_logic(char *buf) {
    // If the command typed is "wait"
    if(buf[0] == 'w' && buf[1] == 'a' && buf[2] == 'i' && buf[3] == 't'){
        wait(0); // Call the wait system call [cite: 289]
        // skip the rest of the loop and get next command
    }
}

// ============================================================================
// 4. FIND WITH REGEX (Easy/Moderate)
// ============================================================================
/*
 * TASK: Support grep-style matching in your 'find' utility.
 * Logic: Use the 'match' function logic from grep.c.
 */
// Simplified match logic from grep.c
int match(char *re, char *text); 

void find_with_regex(char *filename, char *pattern) {
    if(match(pattern, filename)) {
        printf("Found: %s\n", filename);
    }
}

// ============================================================================
// 5. KERNEL TASK: GET PARENT PID (sys_getppid)
// ============================================================================
/*
 * TASK: Add syscall to return parent's PID.
 * File: kernel/sysproc.c
 */
/*
uint64 sys_getppid(void) {
    // myproc() gets current process; ->parent gets the parent struct.
    return myproc()->parent->pid; 
}
*/

/*

Step 1: The uptime Program
If asked to write uptime.c, it is the simplest user-level program.

Create user/uptime.c.

Include kernel/types.h and user/user.h. 

In main, just call printf("%d\n", uptime());. 

Add _uptime to UPROGS in the Makefile. 

Step 2: Modifying user/sh.c
For the "Moderate" tasks (silencing $ or adding wait):

Find the Main Loop: Search for while(getcmd(buf, sizeof(buf), "$ ") >= 0).

Handle wait: Right after getcmd, check if buf starts with "wait". If so, call wait(0) and continue.


Silence $: Change the getcmd call so it passes a blank string "" if isatty(0) is false. 

Step 3: Regex in find
If they ask for "regex support":

Open user/grep.c and copy the functions match, matchhere, and matchstar.

Paste them into your find.c.

Instead of using strcmp(p, name) == 0, use match(name, p).
*/

//https://github.com/0xanwar/xv6-labs-2024
//https://github.com/fcsiba/xv6-labs-2025
