# 🎓 xv6 Quiz 2 Master Reference: Syscalls & Threads


## 🛠️ Section 1: System Calls & IPC (Week 3)

### Task 1: The Handshake (Bi-directional Pipes)
[cite_start]**Reasoning**: A pipe is a unidirectional stream[cite: 582]. [cite_start]To achieve a two-way handshake, you must create two pipes: `p1` for Parent → Child and `p2` for Child → Parent[cite: 582].

**Key Code Logic**:
1. [cite_start]**Initialize Pipes**: Create two integer arrays `p1[2]` and `p2[2]`[cite: 582].
2. [cite_start]**Fork**: Split into Parent and Child processes[cite: 588].
3. [cite_start]**Close Unused Ends**: If the Child reads from `p1[0]`, it must close `p1[1]` to prevent hanging[cite: 583].


[handshake_Twists]
```c
// user/handshake.c logic
int p1[2], p2[2];
pipe(p1); pipe(p2); 

if (fork() == 0) { // CHILD
    close(p1[1]); close(p2[0]); [cite_start]// Close ends we don't use [cite: 583]
    read(p1[0], &buf, 1);       // Receive byte from parent [cite: 583]
    printf("%d: received %d from parent\n", getpid(), buf); [cite: 583]
    write(p2[1], &buf, 1);      // Echo byte back to parent [cite: 583]
    exit(0);
} else { // PARENT
    close(p1[0]); close(p2[1]);
    write(p1[1], &msg, 1);      // Send initial byte [cite: 583]
    read(p2[0], &buf, 1);       // Receive echo from child [cite: 584]
    printf("%d: received %d from child\n", getpid(), buf); [cite: 584]
    wait(0); exit(0);
}


1. Handshake Twist: The "Arithmetic Pipe"
The Question: Instead of just echoing the byte, the Child must square the number (or add a constant) before sending it back. If the result exceeds 255, send 255.

The Solution (user/handshake_math.c):
// ... same setup as standard handshake ...
if (pid == 0) {
    unsigned char val;
    read(p1[0], &val, 1);
    
    // THE TWIST: Math Logic
    // Reasoning: We cast to int to prevent overflow during calculation, then cap at 255. [cite: 407-409]
    int result = (int)val * (int)val;
    if (result > 255) result = 255;
    
    unsigned char final_val = (unsigned char)result;
    write(p2[1], &final_val, 1); 
    exit(0);
}


//Sniffer twists//


Task 2: sniffer (Memory Vulnerability)

Reasoning: Exploits a bug where memset(0) is omitted during memory allocation. New memory from sbrk() contains "dirty" data from previous processes.
// user/sniffer.c
#include "kernel/types.h"
#include "user/user.h"

int main(int argc, char *argv[]) {
    char *mem = sbrk(4096 * 32); // Request 32 pages 
    for (int i = 0; i < (4096 * 32); i++) {
        // Find printable ASCII (33-126) [cite: 622]
        if (mem[i] >= 33 && mem[i] <= 126) {
            // Skip noise logic (README, shell, etc.)
            if (mem[i] == 's' && mem[i+1] == 'h') { i += 2; continue; }
            printf("%s\n", &mem[i]); // Print discovered secret [cite: 622]
            while(i < (4096 * 32) && mem[i] != 0) i++; 
        }
    }
    exit(0);
}

Sniffer Twist: The "Targeted Sniff"
The Question: Instead of printing the first secret it finds, sniffer must accept a command-line argument and only print the secret if it matches that argument.

The Solution (user/sniffer_target.c):
int main(int argc, char *argv[]) {
    char *target = argv[1];
    char *mem = sbrk(4096 * 32); // [cite: 444]
    
    for (int i = 0; i < (4096 * 32); i++) {
        if (mem[i] >= 33 && mem[i] <= 126) {
            // THE TWIST: Comparison Logic
            // Reasoning: Use strcmp to verify if the leaked data matches what the user is looking for. [cite: 414, 447]
            if (strcmp(&mem[i], target) == 0) {
                printf("Found target: %s\n", &mem[i]);
                exit(0);
            }
            while(mem[i] != 0) i++; // Move to next string
        }
    }
}

//Monitor twists

Task 3: monitor (Syscall Tracing)
Reasoning: Tracks syscalls using a bitmask stored in the process structure.
The 7-File Plumbing Checklist:
kernel/syscall.h: Define #define SYS_monitor 22.
kernel/syscall.c: Add extern uint64 sys_monitor(void), update syscalls[] and syscall_names[].
kernel/proc.h: Add uint32 monitor_mask; to struct proc.
kernel/sysproc.c: Implement sys_monitor() using argint(0, &mask);.
kernel/proc.c: Modify fork() to copy mask: np->monitor_mask = p->monitor_mask;.
user/user.h: Add int monitor(int); prototype.
user/usys.pl: Add entry("monitor");

Monitor Twist: The "PID Filter"
The Question: Modify the monitor syscall to take a second argument: a specific PID. The kernel should only print traces if the bit is set AND the PID matches the target.

The Solution (kernel/sysproc.c):
uint64 sys_monitor(void) {
    int mask, target_pid;
    argint(0, &mask);
    argint(1, &target_pid); // THE TWIST: Fetch second argument [cite: 490, 494]
    
    struct proc *p = myproc();
    p->monitor_mask = (uint32)mask; [cite: 496]
    p->target_pid = target_pid; // Need to add 'int target_pid' to struct proc in proc.h [cite: 487]
    return 0;
}

// In kernel/syscall.c -> syscall()
if (((p->monitor_mask >> num) & 1) && (p->pid == p->target_pid)) { // Added PID check [cite: 543]
    printf("%d: syscall %s -> %d\n", p->pid, syscall_names[num], p->trapframe->a0);
}


//Uthread twist

Task 1: uthread (Context Switching)
Reasoning: Saving/Restoring 14 specific registers (ra, sp, s0-s11) to swap execution flow.
+1
Code Solution (user/uthread.c):
void thread_create(void (*func)()) {
  struct thread *t;
  /* ... find FREE thread ... */
  t->state = RUNNABLE;
  t->context.ra = (uint64)func; // Return address [cite: 837, 849]
  t->context.sp = (uint64)t->stack + STACK_SIZE; // Stack top [cite: 836, 840, 843]
}

void thread_schedule(void) {
  /* ... find next_thread ... */
  if (current_thread != next_thread) {
    next_thread->state = RUNNING;
    struct thread *t = current_thread;
    current_thread = next_thread;
    // Perform switch [cite: 852, 854]
    thread_switch((uint64)&t->context, (uint64)&next_thread->context);
  }
}

Assembly Solution (user/uthread_switch.S):

Code snippet
thread_switch:
    sd ra, 0(a0)    /* Store registers to OLD context (a0) [cite: 860, 863] */
    sd sp, 8(a0)
    # ... sd s0 to s11 ...
    ld ra, 0(a1)    /* Load registers from NEW context (a1) [cite: 866, 867] */
    ld sp, 8(a1)
    # ... ld s0 to s11 ...
    ret             /* Jump to address now in ra [cite: 870, 874] */

Uthread Twist: "Thread Kill"
The Question: Implement a function thread_kill(int tid) that sets a specific threads state to FREE so it never runs again.

The Solution (user/uthread.c):
void thread_kill(int tid) {
    // Reasoning: By setting the state to FREE, the scheduler's 'if(t->state == RUNNABLE)' 
    // check will skip this thread in the next loop. [cite: 651, 653]
    if (tid >= 0 && tid < MAX_THREAD) {
        all_thread[tid].state = FREE;
    }
}

//Synchronization twists


Task 2: ph (Synchronization)
Reasoning: Multiple threads updating one bucket causes lost data (race conditions). Use Per-Bucket Locking to allow parallelism.
Code Solution (notxv6/ph-with-mutex-locks.c):
pthread_mutex_t locks[NBUCKET]; // Step 1: Declare array of locks [cite: 977, 991]
static void put(int key, int value) {
  int i = key % NBUCKET;
  pthread_mutex_lock(&locks[i]); // Step 2: Acquire lock for bucket [cite: 977, 1009]
  /* ... insert/update logic ... */
  pthread_mutex_unlock(&locks[i]); // Step 3: Release lock [cite: 978, 1009]
}
int main(int argc, char *argv[]) {
  for (int i = 0; i < NBUCKET; i++) 
    pthread_mutex_init(&locks[i], NULL); // Step 4: Initialize [cite: 977, 1007]
  /* ... work ... */
  for (int i = 0; i < NBUCKET; i++) 
    pthread_mutex_destroy(&locks[i]); // Step 5: Destroy [cite: 1010]
}

PH (Hash) Twist: "Thread-Safe Count"
The Question: Add a global variable total_inserts that tracks how many items were successfully put into the table. Ensure it is thread-safe.

The Solution (notxv6/ph-with-mutex-locks.c):
int total_inserts = 0;
pthread_mutex_t count_lock = PTHREAD_MUTEX_INITIALIZER; // A separate lock for the counter [cite: 802, 831]

static void put(int key, int value) {
    int i = key % NBUCKET; [cite: 753]
    pthread_mutex_lock(&locks[i]); [cite: 802]
    
    // ... insert logic ...
    insert(key, value, &table[i], table[i]); 
    
    pthread_mutex_unlock(&locks[i]); [cite: 803]

    // THE TWIST: Atomic Increment
    // Reasoning: We use a separate lock so we don't slow down the bucket operations. [cite: 815, 849]
    pthread_mutex_lock(&count_lock);
    total_inserts++;
    pthread_mutex_unlock(&count_lock);
}





/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
POSSIBLE QUESTIONS BASED FROM QUIZ 1

Variation 1: The "Filtered" Handshake (IPC)

The Lab: You passed a raw byte between processes .
The Quiz Twist: The Child must modify the data (e.g., convert a lowercase letter to uppercase) before sending it back.

File to change: user/handshake.c
// Inside the Child process (pid == 0)
char buf;
read(p1[0], &buf, 1); 

// THE TWIST: Logic to modify the data
// Reasoning: If the byte is a lowercase letter, subtract 32 to make it uppercase.
if (buf >= 'a' && buf <= 'z') {
    buf = buf - 32;
}

printf("%d: received %d from parent\n", getpid(), buf);
write(p2[1], &buf, 1); // Send modified byte back

The "Arithmetic" Handshake

The Lab: You passed a raw byte between processes .
The Quiz Twist: The child must modify the byte (e.g., square it or add 10) before sending it back. If the result exceeds 255, cap it at 255.

Solution (user/handshake_math.c):
// Inside the Child process (pid == 0)
unsigned char buf;
read(p1[0], &buf, 1); 

// THE TWIST: Math logic
// Reasoning: Use a larger integer type to check for overflow before capping at 255.
int result = (int)buf + 10; 
if (result > 255) result = 255;

unsigned char final_val = (unsigned char)result;
printf("%d: received %d from parent, sending back %d\n", getpid(), buf, final_val);
write(p2[1], &final_val, 1);

Handshake Mechanic: "The Sequence Handshake"

Mechanic: Bi-directional communication over pipes.
Re-Application: Instead of echoing the same byte, the parent sends a number, and the child must send back the next three numbers in the sequence.

File to change: user/handshake.c
// Inside the Child (pid == 0)
unsigned char start_val;
read(p1[0], &start_val, 1); // Get starting byte [cite: 856]

// RE-APPLICATION: Generate sequence
unsigned char sequence[3];
for(int i = 0; i < 3; i++) {
    sequence[i] = start_val + (i + 1);
}

// Send 3 bytes back instead of 1 [cite: 856]
write(p2[1], sequence, 3); 
exit(0);

Handshake Mechanic: "The Parallel Byte Swap"

The Mechanic: Bidirectional communication via two pipes .
The Re-Application: The parent sends two bytes. The child must swap their positions and send them back as a single 2-byte write.

File to change: user/handshake.c
// Inside the Child (pid == 0)
unsigned char buf[2];
read(p1[0], buf, 2); // Read both bytes at once

// RE-APPLICATION: Byte swap logic
// Reasoning: Swapping the order of bytes in the array before sending back.
unsigned char temp = buf[0];
buf[0] = buf[1];
buf[1] = temp;

write(p2[1], buf, 2); // Send swapped pair back
exit(0);

Handshake Mechanic: "The Integrity Check"

The Mechanic: Passing data through pipes and echoing it back .
The Re-Application: The Parent sends a byte. The Child calculates its complement (NOT operation) and sends it back. The Parent then verifies if the received byte is indeed the correct complement.

File to change: user/handshake.c
// Inside the Child (pid == 0)
unsigned char val;
read(p1[0], &val, 1); // Receive byte [cite: 856]

// RE-APPLICATION: Bitwise NOT
// Reasoning: Swapping all 0s to 1s and 1s to 0s as a "check".
unsigned char complement = ~val; 

write(p2[1], &complement, 1); // Send complement back [cite: 856]
exit(0);

// Inside the Parent
unsigned char sent = 0xAA;
unsigned char received;
write(p1[1], &sent, 1);
read(p2[0], &received, 1);

// RE-APPLICATION: Verification
if (received == (unsigned char)~sent) {
    printf("Integrity Check Passed!\n");
}

Handshake Mechanic: "The Pipe Barrier"

Mechanic: Using pipes for process synchronization.
Re-Application: Instead of exchanging data, the parent must wait for the child to finish a "setup" task. The child sends a single 'R' (Ready) byte to the parent. The parent remains blocked on read() until that byte arrives.
+1

File to change: user/handshake.c
// Inside the Child (pid == 0)
// Step 1: Perform "Setup" (e.g., creating a file)
printf("Child: Performing setup...\n");
sleep(10); // Simulate work

// Step 2: Signal the Parent
char signal = 'R';
write(p2[1], &signal, 1); 
exit(0);

// Inside the Parent
char buf;
printf("Parent: Waiting for child...\n");
read(p2[0], &buf, 1); // Mechanic: This blocks until the child writes
printf("Parent: Child is ready, proceeding.\n");

Handshake Mechanic: "The Pipe Barrier"
Mechanic: Using read() on a pipe as a blocking synchronization point.
Re-Application: Instead of exchanging data, the parent must wait for the child to finish a "setup" task. The child sends a single 'R' (Ready) byte. The parent is blocked on read() until that byte arrives, acting as a "sync barrier."

File to change: user/handshake.c
// Inside the Child (pid == 0)
printf("Child: Performing setup...\n");
sleep(10); // Simulate work

// RE-APPLICATION: Signal the Parent
char signal = 'R';
write(p2[1], &signal, 1); [cite: 468, 583]
exit(0);

// Inside the Parent
char buf;
printf("Parent: Waiting for child...\n");
read(p2[0], &buf, 1); // Mechanic: This blocks until the child writes [cite: 469, 584]
printf("Parent: Child is ready, proceeding.\n");

Handshake Mechanic: "The Integrity Handshake"

The Mechanic: Synchronous data exchange over dual pipes .
Re-Application: Instead of just echoing, the Parent sends a byte and the Child must send back its bitwise complement (the ~ operator). The Parent then verifies the math.
+1

File to change:user/handshake.c
// Inside the Child (pid == 0)
unsigned char buf;
read(p1[0], &buf, 1); // Get byte from parent [cite: 583]

// RE-APPLICATION: Logic change
// Reasoning: Use bitwise NOT to flip all bits as an "integrity check."
unsigned char complement = ~buf; 

write(p2[1], &complement, 1); // Send back to parent [cite: 583]
exit(0);

// Inside the Parent
unsigned char sent = 0xAA; // Example byte
write(p1[1], &sent, 1); [cite: 583]
read(p2[0], &buf, 1); [cite: 584]

if (buf == (unsigned char)~sent) {
    printf("Success: Received correct bitwise complement!\n");
}

Handshake Mechanic: "The Sequence Checker"

Mechanic: Synchronous data verification over dual pipes.
Re-Application: The Parent sends a number (e.g., 5). The Child must check if it is even or odd. If even, it sends back 0; if odd, it sends back 1. The Parent then prints whether the child identified it correctly.

File to change: user/handshake.c
// Inside the Child (pid == 0)
unsigned char val;
read(p1[0], &val, 1); // Mechanic: Read from parent

// RE-APPLICATION: Data validation logic
unsigned char result = (val % 2 == 0) ? 0 : 1; 

write(p2[1], &result, 1); // Mechanic: Send result back
exit(0);

// Inside the Parent
unsigned char sent = 5;
unsigned char reply;
write(p1[1], &sent, 1);
read(p2[0], &reply, 1);
printf("Parent sent %d, Child says it is %s\n", sent, (reply == 1 ? "Odd" : "Even"));

Handshake Mechanic: "The Integrity Handshake"

The Mechanic: Synchronous data verification over dual pipes .
Re-Application: Instead of just echoing, the Parent sends a byte and the Child must send back its bitwise complement (using the ~ operator). The Parent then verifies the math to ensure the data wasnt corrupted.
File to change: user/handshake.c
// Inside the Child (pid == 0)
unsigned char buf;
read(p1[0], &buf, 1); // Mechanic: Read from parent

// RE-APPLICATION: Bitwise NOT logic
// Reasoning: Swapping all 0s to 1s as a basic integrity check.
unsigned char complement = ~buf; 

write(p2[1], &complement, 1); // Mechanic: Send result back
exit(0);


Handshake Variation: "The Data Multiplexer"

Mechanic: Sending structured data across pipes.
The Quiz Twist: Instead of one byte, the Parent sends two bytes representing a range (e.g., 5 and 10). The Child must calculate and send back the sum of all integers in that range.

File to change: user/handshake.c
// Inside the Child (pid == 0)
unsigned char range[2];
read(p1[0], range, 2); // Read 2 bytes: start and end

// RE-APPLICATION: Range Sum Logic
int sum = 0;
for(int i = range[0]; i <= range[1]; i++) {
    sum += i;
}

// Reasoning: We send back a 4-byte integer. 
// We must ensure the Parent reads 4 bytes, not 1.
write(p2[1], &sum, sizeof(int)); 
exit(0);

Handshake Mechanic: "The Array Accumulator"

The Mechanic: Streaming multi-byte data through pipes.
The Quiz Twist: Instead of a single byte, the Parent sends an array of 4 integers. The Child must calculate the sum and send that single integer back to the Parent.
File to change: user/handshake.c
// Inside the Child (pid == 0)
int nums[4];
read(p1[0], nums, sizeof(nums)); // Mechanic: Read 16 bytes (4 ints)

// RE-APPLICATION: Accumulation Logic
int total = 0;
for(int i = 0; i < 4; i++) {
    total += nums[i];
}

write(p2[1], &total, sizeof(int)); // Send back the 4-byte result
exit(0);

Handshake Mechanic: "The Selective Byte Relay"

The Mechanic: Synchronous bidirectional communication with data filtering .
The Quiz Twist: The Parent sends a string of 4 bytes. The Child must only send back the even-valued bytes. The Parent then prints the count of bytes it received back.

File to change: user/handshake.c
// Inside the Child (pid == 0)
unsigned char buf[4];
read(p1[0], buf, 4); // Mechanic: Read 4-byte chunk from parent [cite: 473]

// RE-APPLICATION: Data filtering logic
for(int i = 0; i < 4; i++) {
    if (buf[i] % 2 == 0) {
        write(p2[1], &buf[i], 1); // Only relay even bytes back [cite: 468]
    }
}
exit(0);

// Inside the Parent
unsigned char input[4] = {1, 2, 3, 4};
write(p1[1], input, 4); [cite: 473]
// ... parent read logic ...

Handshake Mechanic: "The Pipe Accumulator"

The Mechanic: Streaming multi-byte data through a unidirectional pipe .
The Quiz Twist: The Parent sends a string of 4 integers (16 bytes). The Child must calculate the sum of these integers and send that single 4-byte integer back to the Parent.

File to change: user/handshake.c
// Inside the Child (pid == 0)
int nums[4];
read(p1[0], nums, sizeof(nums)); // Mechanic: Read 16 bytes at once [cite: 583]

// RE-APPLICATION: Aggregation logic
int total = 0;
for(int i = 0; i < 4; i++) {
    total += nums[i];
}

// Send back the sum as a 4-byte write
write(p2[1], &total, sizeof(int)); 
exit(0);

Handshake Mechanic: "The Bi-directional Calculator"

The Mechanic: Synchronous data exchange using pipes .
The Quiz Twist: The Parent sends two bytes (operands). The Child reads them, calculates the product, and sends the result back. The Parent then prints whether the product is greater than 100.

File to change: user/handshake.c
// Inside the Child (pid == 0)
unsigned char operands[2];
read(p1[0], operands, 2); // Mechanic: Read multiple bytes from Parent [cite: 583]

// RE-APPLICATION: Calculation Logic
int product = (int)operands[0] * (int)operands[1];

// Send back the multi-byte result
write(p2[1], &product, sizeof(int)); [cite: 583]
exit(0);

Handshake Mechanic: "The Pipe Sync Barrier"

The Mechanic: Using read() on an empty pipe as a blocking synchronization point.
The Quiz Twist: Instead of passing data, the parent must wait for the child to finish a long-running "Setup" task. The child performs the work, then writes a single 'G' (for "Go") to the pipe. The parent remains blocked on read() until that signal is received.

File to change: user/handshake.c
// Inside the Child (pid == 0)
printf("Child: Starting complex setup...\n");
sleep(30); // Simulate heavy setup work
char signal = 'G';
write(p2[1], &signal, 1); // Mechanic: Signal the parent to continue
exit(0);

// Inside the Parent
char sync_buf;
printf("Parent: Waiting for child setup...\n");
read(p2[0], &sync_buf, 1); // RE-APPLICATION: Blocking until signal
printf("Parent: Signal received, starting main logic.\n");

The Cipher Handshake The Mechanic: Synchronous bidirectional communication via pipes .
The Quiz Twist: The Parent sends a character. The Child must apply a ROT13 cipher (or a simple $+5$ shift) to the character and send the encrypted version back. The Parent then prints the ciphered byte.File to change: user/handshake.c

// Inside the Child process (pid == 0)
char buf;
read(p1[0], &buf, 1); // 

// RE-APPLICATION: Data Transformation Logic
// Reasoning: Shift the ASCII value. If it exceeds 'z', wrap around.
if (buf >= 'a' && buf <= 'z') {
    buf = buf + 5;
    if (buf > 'z') buf = buf - 26;
}

write(p2[1], &buf, 1); // Send back encrypted byte 
exit(0);

Handshake Mechanic: "The Pipe Checksum"

The Mechanic: Synchronous bidirectional communication with data integrity verification .
The Quiz Twist: The Parent sends 4 bytes. The Child must calculate a simple checksum (the sum of all 4 bytes) and send that 1-byte result back. The Parent then prints "Valid" if the checksum matches its own calculation.

File to change: user/handshake.c
// Inside the Child process (pid == 0)
unsigned char buf[4];
read(p1[0], buf, 4); // Mechanic: Read multiple bytes from Parent 

// RE-APPLICATION: Logic to generate a checksum
unsigned char checksum = 0;
for(int i = 0; i < 4; i++) {
    checksum += buf[i];
}

write(p2[1], &checksum, 1); // Send back the single-byte result 
exit(0);

Task: Handshake — The "Checksum" Verification
This variation shifts the focus from simple byte echoes to data integrity. The Parent sends a 4-byte array to the Child over pipe p1 . The Child must compute a bitwise XOR checksum of all four bytes and send that single byte back to the Parent via p2 . This tests your ability to handle multi-byte reads and bitwise logic within the IPC plumbing.
+3

modified / created file 1: user/handshake.c
#include "kernel/types.h"
#include "user/user.h"

int main(int argc, char *argv[]) {
    int p1[2], p2[2];
    pipe(p1); pipe(p2);
    unsigned char buf[4];
    unsigned char checksum = 0;

    if (fork() == 0) {
        close(p1[1]); close(p2[0]);
        // Read the 4-byte array
        if (read(p1[0], buf, 4) != 4) exit(1);
        
        // RE-APPLICATION: Checksum Logic
        for (int i = 0; i < 4; i++) {
            checksum ^= buf[i];
        }
        
        printf("%d: checksum computed %d\n", getpid(), checksum);
        write(p2[1], &checksum, 1);
        exit(0);
    } else {
        close(p1[0]); close(p2[1]);
        unsigned char data[4] = {0x12, 0x34, 0x56, 0x78};
        write(p1[1], data, 4);
        read(p2[0], &checksum, 1);
        printf("%d: parent received checksum %d\n", getpid(), checksum);
        wait(0);
        exit(0);
    }
}

Handshake Mechanic: "The Bi-directional Calculator"

The Mechanic: Synchronous data exchange using pipes .
The Quiz Twist: The Parent sends two bytes (operands). The Child reads them, calculates the product, and sends the result back. The Parent then prints whether the product is greater than 100.
+1

File to change: user/handshake.c
// Inside the Child (pid == 0)
unsigned char operands[2];
read(p1[0], operands, 2); // Mechanic: Read multiple bytes from Parent [cite: 583]

// RE-APPLICATION: Calculation Logic
int product = (int)operands[0] * (int)operands[1];

// Send back the multi-byte result
write(p2[1], &product, sizeof(int)); [cite: 583]
exit(0);

Handshake Mechanic: "The Pipe Sync Barrier"

The Mechanic: Using read() on an empty pipe as a blocking synchronization point .
The Quiz Twist: Instead of passing data, the parent must wait for the child to finish a "Setup" task. The child performs the work, then writes a single 'G' (for "Go") to the pipe. The parent remains blocked on read() until that signal is received.

File to change: user/handshake.c

// Inside the Child (pid == 0)
printf("Child: Starting complex setup...\n");
sleep(30); // Simulate work
char signal = 'G';
write(p2[1], &signal, 1); // Mechanic: Signal parent [cite: 468, 583]
exit(0);

// Inside the Parent
char sync_buf;
printf("Parent: Waiting for child setup...\n");
read(p2[0], &sync_buf, 1); // RE-APPLICATION: Blocking until signal [cite: 469, 584]
printf("Parent: Signal received, proceeding.\n");

Handshake Mechanic: "The Selective Byte Relay"

The Mechanic: Synchronous bidirectional communication with data filtering .
The Quiz Twist: The Parent sends a string of 4 bytes. The Child must only send back the even-valued bytes. The Parent then prints the count of bytes it received back.
+2

File to change: user/handshake.c
// Inside the Child (pid == 0)
unsigned char buf[4];
read(p1[0], buf, 4); // Mechanic: Read 4-byte chunk from parent [cite: 473]

// RE-APPLICATION: Data filtering logic
for(int i = 0; i < 4; i++) {
    if (buf[i] % 2 == 0) {
        write(p2[1], &buf[i], 1); // Only relay even bytes back [cite: 473]
    }
}
exit(0);

Handshake Mechanic: "The Pipe Accumulator"
The Mechanic: Streaming multi-byte data through a unidirectional pipe.
The Quiz Twist: Instead of one byte, the Parent sends a string of 4 integers (16 bytes). The Child must calculate the sum of these integers and send that single 4-byte integer back to the Parent.

File to change: user/handshake.c
// Inside the Child (pid == 0)
int nums[4];
read(p1[0], nums, sizeof(nums)); // Mechanic: Read 16 bytes at once

// RE-APPLICATION: Aggregation logic
int total = 0;
for(int i = 0; i < 4; i++) {
    total += nums[i];
}

// Send back the sum as a 4-byte write
write(p2[1], &total, sizeof(int)); 
exit(0);

Handshake Mechanic: "The Pipe Parity Check"
The Mechanic: Synchronous bidirectional communication via pipes.
The Quiz Twist: The Parent sends a byte. The Child must determine if the number of set bits (1s) in that byte is even or odd. If even, it sends back 0; if odd, it sends back 1.

File to change: user/handshake.c
// Inside the Child (pid == 0)
unsigned char val;
read(p1[0], &val, 1); // Get byte from parent

// RE-APPLICATION: Bit counting logic
int count = 0;
for (int i = 0; i < 8; i++) {
    if ((val >> i) & 1) count++;
}
unsigned char parity = (count % 2 == 0) ? 0 : 1;

write(p2[1], &parity, 1); // Send parity bit back
exit(0);

Handshake Mechanic: "The Pipe Bit-Flipper"
The Mechanic: Bidirectional data flow through pipes.
The Quiz Twist: The Parent sends a byte. The Child must perform a circular bit shift (move all bits one position to the left, and the leftmost bit moves to the rightmost spot) before sending it back.

File to change: user/handshake.c
// Inside the Child (pid == 0)
unsigned char val;
read(p1[0], &val, 1); 

// RE-APPLICATION: Circular bit-shift logic
// Reasoning: This tests if you can manipulate individual bits within the byte stream.
unsigned char shifted = (val << 1) | (val >> 7);

write(p2[1], &shifted, 1); 
exit(0);

Handshake Mechanic: "The Pipe Cipher"
The Mechanic: Synchronous bidirectional communication via pipes.
The Quiz Twist: The Parent sends a character. The Child must apply a ROT13 cipher (shift by 13 positions, wrapping around 'z') and send the encrypted character back.

File to change: user/handshake.c
// Inside the Child (pid == 0)
char buf;
read(p1[0], &buf, 1); // Get char from parent

// RE-APPLICATION: Data Transformation
// Reasoning: This tests your ability to modify stream data on the fly.
if (buf >= 'a' && buf <= 'z') {
    buf = (buf - 'a' + 13) % 26 + 'a';
} else if (buf >= 'A' && buf <= 'Z') {
    buf = (buf - 'A' + 13) % 26 + 'A';
}

write(p2[1], &buf, 1); // Send encrypted back
exit(0);

Handshake Mechanic: "The Pipe Voting System"
The Mechanic: Synchronous data aggregation via pipes.
The Quiz Twist: The Parent forks two children. Each child sends a random byte to the Parent. The Parent must compare them and send back a '1' to the child with the larger byte and a '0' to the child with the smaller byte.

File to change: user/handshake_vote.c
// Inside the Parent
unsigned char c1_val, c2_val;
read(p1_child1[0], &c1_val, 1); // Get vote from Child 1
read(p1_child2[0], &c2_val, 1); // Get vote from Child 2

char win = 1, lose = 0;
if (c1_val > c2_val) {
    write(p2_child1[1], &win, 1);  // Child 1 wins
    write(p2_child2[1], &lose, 1); // Child 2 loses
} else {
    write(p2_child1[1], &lose, 1);
    write(p2_child2[1], &win, 1);
}


Handshake Mechanic: "The Selective Bit-Relay"
Mechanic: Bidirectional communication via two pipes.
The Quiz Twist: The Parent sends a string of 4 bytes. The Child must only send back the even-valued bytes (e.g., if the parent sends 1, 2, 3, 4, the child sends back 2, 4). The Parent then prints the count of bytes it successfully received back.

File to change: user/handshake.c
// Inside the Child (pid == 0)
unsigned char buf[4];
read(p1[0], buf, 4); // Mechanic: Read 4-byte chunk from parent

// RE-APPLICATION: Data filtering logic
// Reasoning: This checks if you can perform conditional logic on piped data.
for(int i = 0; i < 4; i++) {
    if (buf[i] % 2 == 0) {
        write(p2[1], &buf[i], 1); // Only relay even bytes back
    }
}
exit(0);

Handshake Mechanic: "The Bi-directional Pipe Calculator"
The Mechanic: Synchronous data exchange using pipes.
The Quiz Twist: The Parent sends two bytes (operands). The Child reads them, calculates the product, and sends the result back as a 4-byte integer. The Parent then prints whether the product is greater than 100.

File to change: user/handshake.c
// Inside the Child (pid == 0)
unsigned char operands[2];
read(p1[0], operands, 2); // Mechanic: Read multiple bytes from Parent

// RE-APPLICATION: Calculation Logic
int product = (int)operands[0] * (int)operands[1];

// Send back the multi-byte result
write(p2[1], &product, sizeof(int));
exit(0);


Handshake Twist: "The Selective Bit-Relay"
The Twist: Instead of echoing the whole byte, the parent sends a string of 4 bytes. The child must only send back the even-valued bytes. The parent then prints the count of bytes it received back.

The Steps:
  Buffer Management: Modify the read and write calls to handle arrays instead of single variables.
  Logic Loop: Implement a loop in the child to filter data based on parity.
Files to change: user/handshake.c

// Inside the Child (pid == 0)
unsigned char buf[4];
int count = 0;
read(p1[0], buf, 4); // Read the chunk

for(int i = 0; i < 4; i++) {
    if (buf[i] % 2 == 0) { // Twist: Only send back even bytes
        write(p2[1], &buf[i], 1);
        count++;
    }
}
exit(0);

// Inside Parent
unsigned char input[4] = {1, 2, 3, 4};
write(p1[1], input, 4);
// Parent read logic would loop until child exits or use a count


Handshake Twist: "The Synchronized Array Sort"
The Twist: The Parent sends an unsorted array of 4 bytes to the Child. The Child must sort them in ascending order and send the sorted array back. The Parent then verifies the order.
The Steps:
Buffer Scaling: Use read(p1[0], buf, 4) to pull the entire array at once.
Logic: Implement a simple bubble sort or comparison inside the child before the write .
Files to change: user/handshake.c

// Inside the Child (pid == 0)
unsigned char buf[4];
read(p1[0], buf, 4); // Read 4-byte chunk

// THE TWIST: Sort Logic
for (int i = 0; i < 3; i++) {
    for (int j = 0; j < 3 - i; j++) {
        if (buf[j] > buf[j+1]) {
            unsigned char tmp = buf[j];
            buf[j] = buf[j+1];
            buf[j+1] = tmp;
        }
    }
}
write(p2[1], buf, 4); // Send sorted array back
exit(0);

Handshake Twist: "The Double-Signal Barrier"
The Twist: Instead of one byte, the Parent must wait for two separate signals from two different Child processes before it proceeds. Child 1 sends an 'A', and Child 2 sends a 'B'. The Parent is blocked until both are received.
The Steps:
Multi-Forking: Call fork() twice to create two children.
Pipe Routing: Use a single pipe p2 where both children write their respective signals.
Files to change: user/handshake.c
// Inside the Parent
char signals[2];
read(p2[0], &signals[0], 1); // Blocks until first child signals
read(p2[0], &signals[1], 1); // Blocks until second child signals
printf("Parent: Both children signaled '%c' and '%c'. Proceeding.\n", signals[0], signals[1]);

Handshake Twist: "The Pipe Cipher Relay"
The Twist: The Parent sends a character to the Child. The Child must apply a ROT13 cipher (shift by 13 positions, wrapping around 'z') and send the encrypted character back. This tests your ability to handle stream data transformation within the IPC plumbing.
The Steps:
IPC setup: Initialize two pipes for bi-directional flow.
Logic: Implement the character shift logic within the Child process before the write .
Files to change: user/handshake.c

// Inside the Child (pid == 0)
char buf;
read(p1[0], &buf, 1); // Get char from parent

// THE TWIST: ROT13 Cipher Logic
if (buf >= 'a' && buf <= 'z') {
    buf = (buf - 'a' + 13) % 26 + 'a';
} else if (buf >= 'A' && buf <= 'Z') {
    buf = (buf - 'A' + 13) % 26 + 'A';
}

write(p2[1], &buf, 1); // Send encrypted char back
exit(0);

Handshake Twist: "The Parent-Mediated Relay"
The Twist: The Parent forks two children. Child 1 sends a byte to the Parent. The Parent must then pass that exact byte to Child 2. Child 2 then prints the byte and exits. This tests multi-pipe orchestration and blocking read/write synchronization.
The Steps:
Multi-Pipe Setup: Initialize four pipes (two for each child) to maintain bi-directional communication with the Parent.
Parent Logic: Read from Child 1s pipe, then immediately write that value to Child 2's pipe.
Files to change: user/handshake.c

// Inside the Parent
unsigned char shared_byte;
read(p1_child1[0], &shared_byte, 1);  // Block until Child 1 sends data
write(p1_child2[1], &shared_byte, 1); // Relay data to Child 2
wait(0); wait(0);


Handshake Twist: "The Parent-Mediated Byte Relay"
The Twist: The Parent forks two children. Child 1 sends a byte to the Parent. The Parent must then pass that exact byte to Child 2. Child 2 then prints the byte and exits. This tests multi-pipe orchestration and blocking synchronization.
The Steps:
Multi-Pipe Setup: Initialize four pipes (two for each child) to maintain communication with the Parent.
Parent Logic: Read from Child 1's pipe, then immediately write that value to Child 2's pipe.
Files to change: user/handshake.c
// Inside the Parent
unsigned char shared_byte;
read(p1_child1[0], &shared_byte, 1);  // Block until Child 1 sends data
write(p1_child2[1], &shared_byte, 1); // Relay data to Child 2
wait(0); wait(0);

Handshake Twist: "The Multi-Process Synchronization Barrier"
The Twist: The Parent forks three children. Instead of exchanging data, the Parent acts as a barrier. It must not proceed until it has received a single 'READY' byte from all three children. This tests multi-pipe orchestration and the "blocking" nature of read().

Files to change: user/handshake.c
// Inside the Parent
char signal;
int ready_count = 0;
// We assume 3 pipes: p_c1, p_c2, p_c3
while (ready_count < 3) {
    // Read from any child; the order doesn't matter as long as all signal
    if (read(p_from_children[0], &signal, 1) > 0 && signal == 'R') {
        ready_count++;
    }
}
printf("Parent: Barrier released. All 3 children ready.\n");














































"Targeted" Sniffer

The Lab: You printed the first non-null secret you found .
The Quiz Twist: sniffer must accept a command-line argument and only print the secret if it matches that specific word.

Solution (user/sniffer_target.c):
int main(int argc, char *argv[]) {
  char *target = argv[1];
  char *mem = sbrk(4096 * 32); // Request 32 pages [cite: 892]

  for (int i = 0; i < (4096 * 32); i++) {
    if (mem[i] >= 33 && mem[i] <= 126) {
      // THE TWIST: String comparison
      // Reasoning: Only report if the leaked memory matches the user's target word.
      if (strcmp(&mem[i], target) == 0) {
        printf("Found target: %s\n", &mem[i]);
        exit(0);
      }
      while(mem[i] != 0) i++; // Move to end of current string
    }
  }
  exit(0);
}


Sniffer Mechanic: "The Integer Sum Sniffer"

Mechanic: Using sbrk() to access non-zeroed heap memory .
Re-Application: Instead of finding a string, find two 4-byte integers hidden behind a marker and print their sum.

File to change: user/sniffer.c
// RE-APPLICATION: Find integer data
char *mem = sbrk(4096 * 32); // [cite: 892, 895]
char *marker = "SECRET_INT";

for (int i = 0; i < (4096 * 32) - 20; i++) {
    if (memcmp(mem + i, marker, 10) == 0) {
        // Point to the integers stored after the marker
        int *val1 = (int*)(mem + i + 12); 
        int *val2 = (int*)(mem + i + 16);
        printf("Sum: %d\n", *val1 + *val2);
        exit(0);
    }
}

Sniffer Mechanic: "The Page Boundary Sniffer"

The Mechanic: Accessing uncleared heap memory via sbrk() .
The Re-Application: Instead of a general scan, the sniffer must specifically check the start of every 4096-byte page for a "SECRET" header.

File to change
user/sniffer.c
// RE-APPLICATION: Page-aligned scanning
// Reasoning: This tests your understanding of page sizes (4096 bytes).
char *mem = sbrk(4096 * 32); 

for (int i = 0; i < 32; i++) {
    char *page_start = mem + (i * 4096); // Jump to the start of each page
    if (memcmp(page_start, "SECRET", 6) == 0) {
        printf("Secret on page %d: %s\n", i, page_start + 8);
    }
}

Sniffer Mechanic: "The Metadata Sniffer"

The Mechanic: Scanning sbrk() memory for leaked information .
The Re-Application: Instead of a string, search for a specific pattern of flags. For example, finding a sequence of three 0x01 bytes followed by a 0xFF byte, which marks the start of a "System Config" block.

File to change: user/sniffer.c
// RE-APPLICATION: Pattern matching
// Reasoning: Looking for a specific non-string byte signature.
char *mem = sbrk(4096 * 32); 
unsigned char signature[] = {0x01, 0x01, 0x01, 0xFF};

for (int i = 0; i < (4096 * 32) - 4; i++) {
    if (memcmp(mem + i, signature, 4) == 0) {
        // Report the offset where the config block was found
        printf("System Config found at offset: %d\n", i);
        break;
    }
}


Sniffer Mechanic: "The Structural Sniffer"

Mechanic: Casting raw heap bytes into C structures.
Re-Application: A previous process stored a struct record { int id; char name[16]; }. Your sniffer must find the marker "REC" and then cast the subsequent bytes into that structure to print the id.

File to change: user/sniffer.c
struct record { int id; char name[16]; };

// RE-APPLICATION: Scanning for structural data
char *mem = sbrk(4096 * 32); 

for (int i = 0; i < (4096 * 32) - sizeof(struct record); i++) {
    if (memcmp(mem + i, "REC", 3) == 0) {
        // Step: Cast the memory address (plus offset) to the struct type
        struct record *r = (struct record *)(mem + i + 4); 
        printf("Found Record ID: %d\n", r->id);
        exit(0);
    }
}

Sniffer Mechanic: "The Numeric Sniffer"

Mechanic: Scanning sbrk() memory for leaked non-string data.
Re-Application: A previous process stored two 4-byte integers hidden behind a marker "DATA". Your sniffer must find the marker and print the sum of the two integers.
File to change: user/sniffer.c
// RE-APPLICATION: Finding integer data instead of strings
char *mem = sbrk(4096 * 32); [cite: 517]
char *marker = "DATA";

for (int i = 0; i < (4096 * 32) - 12; i++) {
    if (memcmp(mem + i, marker, 4) == 0) {
        // Step: Cast the memory after the marker to integer pointers
        int *val1 = (int*)(mem + i + 4); 
        int *val2 = (int*)(mem + i + 8);
        printf("Sum: %d\n", *val1 + *val2);
        exit(0);
    }
}

Sniffer Mechanic: "The Page-Aligned Sniffer"

The Mechanic: Accessing uncleared heap memory via sbrk() .
Re-Application: Instead of a linear scan, the sniffer must specifically check the first 8 bytes of every 4096-byte page for a specific header (e.g., "HEAD").

File to change: user/sniffer.c
// RE-APPLICATION: Page-size awareness
// Reasoning: This tests if you know that memory is allocated in 4096-byte chunks.
char *mem = sbrk(4096 * 32); 

for (int i = 0; i < 32; i++) {
    char *page_start = mem + (i * 4096); // Jump to start of each page
    if (memcmp(page_start, "HEAD", 4) == 0) {
        printf("Found secret header on page %d: %s\n", i, page_start + 4);
    }
}

Sniffer Mechanic: "The Pattern-Matching Sniffer"

Mechanic: Scanning sbrk() memory for non-string binary markers.
Re-Application: Instead of a string, search for a specific hex signature (e.g., 0xDE 0xAD 0xBE 0xEF). Once found, print the 4 bytes that come immediately before it.
+1

File to change: user/sniffer.c
// RE-APPLICATION: Multi-byte signature matching
char *mem = sbrk(4096 * 32); 
unsigned char signature[] = {0xDE, 0xAD, 0xBE, 0xEF};

for (int i = 4; i < (4096 * 32) - 4; i++) {
    // Reasoning: memcmp is best for binary signatures rather than strings
    if (memcmp(mem + i, signature, 4) == 0) {
        printf("Signature found! Previous 4 bytes: %x %x %x %x\n", 
                mem[i-4], mem[i-3], mem[i-2], mem[i-1]);
        exit(0);
    }
}

Sniffer Mechanic: "The Page-Aligned Sniffer"

The Mechanic: Accessing uncleared heap memory via sbrk() .
Re-Application: Instead of a linear scan, the sniffer must check the first 8 bytes of every 4096-byte page for a specific 4-byte header (e.g., 0xDEADBEEF).
File to change: user/sniffer.c
// RE-APPLICATION: Page-size awareness (4096 bytes)
char *mem = sbrk(4096 * 32); 
unsigned int magic = 0xDEADBEEF;

for (int i = 0; i < 32; i++) {
    char *page_start = mem + (i * 4096); // Jump to start of each page
    if (memcmp(page_start, &magic, 4) == 0) {
        printf("Magic found on page %d! Secret: %s\n", i, page_start + 4);
        exit(0);
    }
}

The Mechanic: Accessing uncleared heap memory via sbrk(). 
The Quiz Twist: The secret isnt stored in plain text. Every character was XORed with 0xFF by the previous process. Your sniffer must find the marker and decrypt the secret by XORing it back before printing.

File to change: user/sniffer.c
// RE-APPLICATION: Bitwise decryption during scan
char *mem = sbrk(4096 * 32); [cite: 504]
char *marker = "SECRET";

for (int i = 0; i < (4096 * 32) - 32; i++) {
    if (memcmp(mem + i, marker, 6) == 0) {
        char *secret = mem + i + 8;
        printf("Decrypted Secret: ");
        for(int j = 0; secret[j] != '\0'; j++) {
            // Apply XOR 0xFF to recover original character
            printf("%c", (unsigned char)secret[j] ^ 0xFF);
        }
        printf("\n");
        exit(0);
    }
}

Sniffer Variation 2: The "Linked List" Sniffer

The Mechanic: Using pointer arithmetic to follow data chains in the leaked heap. 
The Quiz Twist: The secret is split. The memory at the marker contains a struct with a value and an offset to the next part of the secret. You must "hop" through the memory using these offsets to reconstruct the message.

File to change: user/sniffer.c
struct secret_node {
    char part;
    int next_offset; // Relative offset from current position
};

// RE-APPLICATION: Pointer Chasing
char *mem = sbrk(4096 * 32); [cite: 504]
if (memcmp(mem + i, "LIST", 4) == 0) {
    struct secret_node *current = (struct secret_node *)(mem + i + 4);
    while (current->part != '\0') {
        printf("%c", current->part);
        // Move to the next "hop" in the leaked memory
        current = (struct secret_node *)((char *)current + current->next_offset);
    }
    printf("\n");
}

Sniffer Mechanic: "The Structural Header Sniffer"

The Mechanic: Pointer casting and offset calculation in leaked heap memory .
The Quiz Twist: The secret is prefixed with a length header. You must find the marker "LEN:", read the integer immediately following it to know how many bytes the secret is, and then print exactly that many characters.

File to change: user/sniffer.c
// RE-APPLICATION: Length-prefixed data recovery
char *mem = sbrk(4096 * 32); 
char *marker = "LEN:";

for (int i = 0; i < (4096 * 32) - 20; i++) {
    if (memcmp(mem + i, marker, 4) == 0) {
        // Step: Read the length integer stored right after the marker
        int secret_len = *(int*)(mem + i + 4); 
        char *secret_ptr = mem + i + 8; // Secret starts after length
        
        // Step: Print exactly secret_len characters
        for(int j = 0; j < secret_len; j++) {
            printf("%c", secret_ptr[j]);
        }
        printf("\n");
        exit(0);
    }
}

Sniffer Mechanic: "The Page-Offset Secret"

The Mechanic: Locating data based on known physical page sizes in the leaked heap.
The Quiz Twist: The secret is always stored at an offset of exactly 2048 bytes (the middle) of every 4096-byte page. Your sniffer must jump to the middle of each page to check for a 4-byte ID.
+1

File to change: user/sniffer.c
// RE-APPLICATION: Page-boundary jumping logic
// Reasoning: This tests if you know a page is 4096 bytes and can calculate offsets.
char *mem = sbrk(4096 * 32); [cite: 504, 517]

for (int i = 0; i < 32; i++) {
    // Jump to the middle of page 'i'
    char *mid_page = mem + (i * 4096) + 2048; 
    
    if (memcmp(mid_page, "ID:", 3) == 0) {
        printf("Found ID on Page %d: %s\n", i, mid_page + 3);
    }
}

sniffer Mechanic: "The Relative Offset Sniffer"

The Mechanic: Navigating leaked memory using pointer arithmetic and sbrk().
The Quiz Twist: The "secret" is stored in two parts. After the marker "PART1:", there is a 4-byte integer offset. You must jump ahead by that many bytes to find "PART2:" and the actual password.
+1

File to change: user/sniffer.c
// RE-APPLICATION: Non-linear memory navigation
char *mem = sbrk(4096 * 32); 

for (int i = 0; i < (4096 * 32) - 100; i++) {
    if (memcmp(mem + i, "PART1:", 6) == 0) {
        // Step 1: Read the relative jump offset
        int jump = *(int*)(mem + i + 6);
        
        // Step 2: Calculate the location of Part 2
        char *part2_ptr = mem + i + jump;
        
        if (memcmp(part2_ptr, "PART2:", 6) == 0) {
            printf("Found secret: %s\n", part2_ptr + 6);
            exit(0);
        }
    }
}

Sniffer Mechanic: "The Struct-Aligned Sniffer"

The Mechanic: Casting leaked memory into C structures.
The Quiz Twist: A previous process stored a struct user { int id; char code[4]; }. Your sniffer must find the marker "USR", then cast the following memory to this struct to print the id only if the code is "SIT".

File to change: user/sniffer.c
struct user { int id; char code[4]; };

// RE-APPLICATION: Structural data recovery
char *mem = sbrk(4096 * 32); [cite: 504, 517]

for (int i = 0; i < (4096 * 32) - sizeof(struct user); i++) {
    if (memcmp(mem + i, "USR", 3) == 0) {
        // Step: Cast memory following the marker to the struct pointer
        struct user *u = (struct user *)(mem + i + 4);
        if (memcmp(u->code, "SIT", 3) == 0) {
            printf("Found SIT User ID: %d\n", u->id);
            exit(0);
        }
    }
}
Sniffer Mechanic: "The Page-Alignment Sniffer"

The Mechanic: Navigating memory based on fixed page boundaries (4096 bytes).
The Quiz Twist: A previous process was designed to only store its secret at the very start of a new memory page. Your sniffer should skip the middle of pages and only check the memory at every 4096-byte increment.

File to change: user/sniffer.c
// RE-APPLICATION: Page-aligned scanning
// Reasoning: This tests your knowledge that sbrk() gives you 4KB pages.
char *mem = sbrk(4096 * 32); 

for (int i = 0; i < 32; i++) {
    char *page_start = mem + (i * 4096); // Jump to the exact start of page 'i'
    if (page_start[0] != 0) { // Check if page is "dirty"
        printf("Potential secret at start of page %d: %s\n", i, page_start);
    }
}


Sniffer Mechanic: "The Targeted Pointer Sniffer"

The Mechanic: Navigating leaked memory using pointer arithmetic and sbrk().
The Quiz Twist: A previous process stored a pointer to the secret string, rather than the string itself. Your sniffer must find the marker "PTR:", read the 64-bit address following it, and then try to read the string at that specific memory location.
+1

File to change: user/sniffer.c
// RE-APPLICATION: Double-indirection memory recovery
char *mem = sbrk(4096 * 32); // [cite: 504]

for (int i = 0; i < (4096 * 32) - 8; i++) {
    if (memcmp(mem + i, "PTR:", 4) == 0) {
        // Step: Read the address (64-bit) stored in the leaked memory
        uint64 leaked_addr = *(uint64*)(mem + i + 4);
        
        // Step: Dereference that address to find the secret
        // Note: This only works if the address is still valid in your address space.
        char *secret = (char*)leaked_addr;
        printf("Followed pointer to secret: %s\n", secret);
        exit(0);
    }
}

Sniffer Mechanic: "The Page-Offset Sniffer"

The Mechanic: Navigating memory based on fixed page boundaries (4096 bytes).
The Quiz Twist: A previous process was configured to only store secrets at the exact middle (offset 2048) of every 4096-byte page. Your sniffer must jump specifically to these offsets instead of scanning linearly.

File to change: user/sniffer.c
// RE-APPLICATION: Page-boundary offset jumping
// Reasoning: This tests if you know a page is 4096 bytes and can calculate addresses.  [cite: 504, 891-892]
char *mem = sbrk(4096 * 32); 

for (int i = 0; i < 32; i++) {
    // Jump to the middle (2048 bytes) of page 'i'
    char *target = mem + (i * 4096) + 2048; 
    if (target[0] != 0) {
        printf("Potential secret at Page %d middle: %s\n", i, target);
    }
}

ask: Sniffer — The "Delimited Secret" Extraction
In this twist, the secret isnt a fixed-length string but is bounded by a specific delimiter. Your program must find the marker "VAL=", and then print every character following it until it hits a # character. This tests your ability to perform sequential memory scanning and conditional termination within uncleared heap memory.
+1

modified / created file 1: user/sniffer.c
#include "kernel/types.h"
#include "user/user.h"

int main(int argc, char *argv[]) {
    char *mem = sbrk(4096 * 32); // Request 32 pages 
    char *marker = "VAL=";

    for (int i = 0; i < (4096 * 32) - 10; i++) {
        // RE-APPLICATION: Search and Delimited Extract
        if (memcmp(mem + i, marker, 4) == 0) {
            char *start = mem + i + 4;
            printf("Secret: ");
            for (int j = 0; start[j] != '#' && start[j] != '\0'; j++) {
                printf("%c", start[j]);
            }
            printf("\n");
            exit(0);
        }
    }
    exit(0);
}


Sniffer Mechanic: "The Struct-Aligned Sniffer"

The Mechanic: Casting leaked memory into C structures.
The Quiz Twist: A previous process stored a struct user { int id; char code[4]; }. Your sniffer must find the marker "USR", then cast the following memory to this struct to print the id only if the code is "SIT".
+3

File to change: user/sniffer.c
struct user { int id; char code[4]; };

// RE-APPLICATION: Structural data recovery
char *mem = sbrk(4096 * 32); [cite: 504, 507]

for (int i = 0; i < (4096 * 32) - sizeof(struct user); i++) {
    if (memcmp(mem + i, "USR", 3) == 0) {
        // Step: Cast memory following the marker to the struct pointer
        struct user *u = (struct user *)(mem + i + 4);
        if (memcmp(u->code, "SIT", 3) == 0) {
            printf("Found SIT User ID: %d\n", u->id);
            exit(0);
        }
    }
}


Sniffer Mechanic: "The Page-Alignment Sniffer"

The Mechanic: Navigating memory based on fixed page boundaries (4096 bytes).
The Quiz Twist: A previous process was designed to only store its secret at the very start of a new memory page. Your sniffer should skip the middle of pages and only check the memory at every 4096-byte increment.

File to change: user/sniffer.c
// RE-APPLICATION: Page-aligned scanning
// Reasoning: This tests your knowledge that sbrk() gives you 4KB pages.
char *mem = sbrk(4096 * 32); 

for (int i = 0; i < 32; i++) {
    char *page_start = mem + (i * 4096); // Jump to the exact start of page 'i'
    if (page_start[0] != 0) { // Check if page is "dirty" [cite: 503]
        printf("Potential secret at start of page %d: %s\n", i, page_start);
    }
}



Sniffer Mechanic: "The Page-Offset Secret"

The Mechanic: Locating data based on known physical page sizes in the leaked heap.
The Quiz Twist: The secret is always stored at an offset of exactly 2048 bytes (the middle) of every 4096-byte page. Your sniffer must jump to the middle of each page to check for a 4-byte ID.
+2

File to change: user/sniffer.c
// RE-APPLICATION: Page-boundary jumping logic
// Reasoning: This tests if you know a page is 4096 bytes and can calculate offsets. 
char *mem = sbrk(4096 * 32); // [cite: 504, 517]

for (int i = 0; i < 32; i++) {
    // Jump to the middle (2048 bytes) of page 'i'
    char *mid_page = mem + (i * 4096) + 2048; 
    
    if (memcmp(mid_page, "ID:", 3) == 0) {
        printf("Found ID on Page %d: %s\n", i, mid_page + 3);
    }
}

Sniffer Mechanic: "The Numeric Range Sniffer"
The Mechanic: Using sbrk() to access non-zeroed heap memory and filtering for numeric data.
The Quiz Twist: A previous process stored a sequence of numbers. Your sniffer must find the marker "NUMS" and print only the numbers that fall between 100 and 200.

File to change: user/sniffer.c
// RE-APPLICATION: Numeric filtering in memory
char *mem = sbrk(4096 * 32);

for (int i = 0; i < (4096 * 32) - 8; i++) {
    if (memcmp(mem + i, "NUMS", 4) == 0) {
        int *ptr = (int*)(mem + i + 4);
        // Step: Check the next 4 integers for the range
        for(int j = 0; j < 4; j++) {
            if (ptr[j] >= 100 && ptr[j] <= 200) {
                printf("Found valid number: %d\n", ptr[j]);
            }
        }
    }
}

Sniffer Mechanic: "The Multi-Marker Sniffer"
The Mechanic: Navigating memory based on non-zeroed heap allocation using sbrk().
The Quiz Twist: The secret is split into two parts. You must find "PART1:", store the string, then continue scanning for "PART2:". Only print the full secret once both parts are found.

File to change: user/sniffer.c
// RE-APPLICATION: State-based memory scanning
char *mem = sbrk(4096 * 32);
char p1[16] = {0}, p2[16] = {0};

for (int i = 0; i < (4096 * 32) - 16; i++) {
    if (memcmp(mem + i, "PART1:", 6) == 0) {
        strcpy(p1, mem + i + 6);
    }
    if (memcmp(mem + i, "PART2:", 6) == 0) {
        strcpy(p2, mem + i + 6);
    }
}
if (p1[0] && p2[0]) printf("Full Secret: %s%s\n", p1, p2);

Sniffer Mechanic: "The Signature-Jump Sniffer"
Mechanic: Navigating leaked memory using pointer arithmetic and sbrk().
The Quiz Twist: The secret is not at the marker. The marker "JUMP" is followed by a 1-byte integer. You must skip ahead by that number of bytes from the markers position to find the actual secret string.

File to change: user/sniffer.c
// RE-APPLICATION: Non-linear memory navigation
char *mem = sbrk(4096 * 32); 

for (int i = 0; i < (4096 * 32) - 32; i++) {
    if (memcmp(mem + i, "JUMP", 4) == 0) {
        // Step 1: Read the skip value (1 byte)
        unsigned char skip = (unsigned char)mem[i + 4];
        
        // Step 2: Calculate the secret's location
        char *secret = mem + i + 4 + 1 + skip; 
        printf("Found Secret after jump: %s\n", secret);
        exit(0);
    }
}

Sniffer Mechanic: "The Page-Header Pattern Sniffer"
The Mechanic: Page-aligned memory access and signature matching.
The Quiz Twist: Secrets are only stored in pages that start with the signature 0xAA55. Your sniffer must check the first two bytes of every 4096-byte page; if they match, scan the rest of that page for printable ASCII.

File to change: user/sniffer.c
// RE-APPLICATION: Page-level signature gating
char *mem = sbrk(4096 * 32); 

for (int i = 0; i < 32; i++) {
    unsigned short *header = (unsigned short *)(mem + (i * 4096));
    
    // Step: Only scan pages that meet the criteria
    if (*header == 0xAA55) {
        char *page_data = (char *)header + 2;
        for (int j = 0; j < 4094; j++) {
            if (page_data[j] >= 33 && page_data[j] <= 126) {
                printf("Secret on Signed Page %d: %s\n", i, &page_data[j]);
                while(page_data[j] != 0) j++;
            }
        }
    }
}


Sniffer Mechanic: "The Delimited Memory Sniffer"
The Mechanic: Navigating uncleared heap memory using pointer arithmetic.
The Quiz Twist: The secret is not a null-terminated string. It starts after the marker "DATA=" and ends when the character # is encountered.

File to change: user/sniffer.c
// RE-APPLICATION: Delimited scanning logic
char *mem = sbrk(4096 * 32);
char *marker = "DATA=";

for (int i = 0; i < (4096 * 32) - 10; i++) {
    if (memcmp(mem + i, marker, 5) == 0) {
        char *start = mem + i + 5;
        printf("Secret: ");
        // Step: Print until delimiter '#' is found
        for (int j = 0; start[j] != '#' && start[j] != '\0'; j++) {
            printf("%c", start[j]);
        }
        printf("\n");
        exit(0);
    }
}

Sniffer Mechanic: "The Page-Offset Sniffer"
The Mechanic: Locating data based on known physical page sizes in the leaked heap.
The Quiz Twist: The secret is always stored at an offset of exactly 2048 bytes (the middle) of every 4096-byte page. Your sniffer must jump to the middle of each page to check for a 4-byte ID.

File to change: user/sniffer.c
// RE-APPLICATION: Page-boundary jumping logic
// Reasoning: This tests if you know a page is 4096 bytes and can calculate offsets.
char *mem = sbrk(4096 * 32); 

for (int i = 0; i < 32; i++) {
    // Jump to the middle (2048 bytes) of page 'i'
    char *mid_page = mem + (i * 4096) + 2048; 
    
    if (memcmp(mid_page, "ID:", 3) == 0) {
        printf("Found ID on Page %d: %s\n", i, mid_page + 3);
    }
}

Sniffer Mechanic: "The Multi-Page Secret Reconstruction"
The Mechanic: Page-aligned memory access using sbrk().
The Quiz Twist: The secret is fragmented. Every page starting at a multiple of 8 (Page 0, 8, 16, 24) contains one character of a 4-character password at its first byte. Your sniffer must visit these specific pages, collect the characters, and print the final word.

File to change: user/sniffer_frag.c
char *mem = sbrk(4096 * 32);
char password[5] = {0};

for (int i = 0; i < 4; i++) {
    // Jump specifically to the start of Page 0, 8, 16, 24
    password[i] = *(mem + (i * 8 * 4096)); 
}
printf("Reconstructed Secret: %s\n", password);


Sniffer Mechanic: "The Page-Header Pattern Sniffer"
Mechanic: Locating data based on known physical page sizes (4096 bytes) in the leaked heap.
The Quiz Twist: Secrets are only stored in pages that start with a specific 2-byte signature 0xAA55. Your sniffer must check the first two bytes of every page; if they match, scan the rest of that page for printable ASCII.

File to change: user/sniffer.c
// RE-APPLICATION: Page-level signature gating
char *mem = sbrk(4096 * 32); 

for (int i = 0; i < 32; i++) {
    unsigned short *header = (unsigned short *)(mem + (i * 4096));
    
    // Step: Only scan pages that meet the criteria
    if (*header == 0xAA55) {
        char *page_data = (char *)header + 2;
        for (int j = 0; j < 4094; j++) {
            if (page_data[j] >= 33 && page_data[j] <= 126) {
                printf("Secret on Signed Page %d: %s\n", i, &page_data[j]);
                while(page_data[j] != 0) j++; // Skip to end of string
            }
        }
    }
}

Sniffer Mechanic: "The Double-Indirection Sniffer"
The Mechanic: Navigating leaked memory using pointer arithmetic and sbrk().
The Quiz Twist: A previous process stored a pointer to the secret string, rather than the string itself. Your sniffer must find the marker "PTR:", read the 64-bit address following it, and then try to read the string at that specific memory location.

File to change: user/sniffer.c
// RE-APPLICATION: Double-indirection memory recovery
char *mem = sbrk(4096 * 32);

for (int i = 0; i < (4096 * 32) - 8; i++) {
    if (memcmp(mem + i, "PTR:", 4) == 0) {
        // Step: Read the address (64-bit) stored in the leaked memory
        uint64 leaked_addr = *(uint64*)(mem + i + 4);
        
        // Step: Dereference that address to find the secret
        char *secret = (char*)leaked_addr;
        printf("Followed pointer to secret: %s\n", secret);
        exit(0);
    }
}

Sniffer Twist: "The Page-Offset Secret"
The Twist: The secret is no longer at the start of a memory block. It is always stored at an offset of exactly 2048 bytes (the middle) of every 4096-byte page. Your sniffer must "jump" to the middle of each page to check for a 4-byte ID marker.

The Steps:

Memory Allocation: Use sbrk() to get a large block of memory.

Pointer Arithmetic: Instead of i++, increment your pointer by 4096 and add the 2048 offset.

Files to change: user/sniffer.c

The Solution:
char *mem = sbrk(4096 * 32); //
for (int i = 0; i < 32; i++) {
    // Jump to the middle of page 'i'
    char *mid_page = mem + (i * 4096) + 2048; 
    
    if (memcmp(mid_page, "ID:", 3) == 0) {
        printf("Found ID on Page %d: %s\n", i, mid_page + 3);
    }
}


Sniffer Twist: "The Pointer-Chasing Sniffer"
The Twist: The "secret" is stored in two parts. The marker "PTR" is followed by a 64-bit memory address. Your sniffer must read that address and then jump to that specific location in its own memory to find the actual string.
The Steps:
Memory Access: Use sbrk(4096 * 32) to ensure your address space overlaps with the leaked data.
Casting: Cast the 8 bytes following the marker to a uint64 and then to a char*.
Files to change: user/sniffer.c

char *mem = sbrk(4096 * 32); 
for (int i = 0; i < (4096 * 32) - 12; i++) {
    if (memcmp(mem + i, "PTR", 3) == 0) {
        // RE-APPLICATION: Double-indirection
        uint64 *addr_ptr = (uint64*)(mem + i + 4);
        char *secret = (char*)(*addr_ptr); 
        printf("Secret at leaked address: %s\n", secret);
        exit(0);
    }
}

Sniffer Twist: "The Bitwise-Masked Sniffer"
The Twist: The secret is not in plain text. Every character was XORed with 0xFF by the previous process. Your sniffer must find the marker "MASK", read the following data, and XOR it back to 0xFF to recover the original string .
The Steps:
Memory Allocation: Request memory via sbrk().
Decryption Logic: Apply bitwise XOR during the scan loop.
Files to change: user/sniffer.c
char *mem = sbrk(4096 * 32); 
if (memcmp(mem + i, "MASK", 4) == 0) {
    char *secret = mem + i + 4;
    printf("Decrypted: ");
    for(int j = 0; secret[j] != '\0'; j++) {
        printf("%c", (unsigned char)secret[j] ^ 0xFF); // RE-APPLICATION: XOR Decryption
    }
}


Sniffer Twist: "The Numeric Range Sniffer"
The Twist: A previous process stored a sequence of integers in the heap. Your sniffer must find the marker "NUMS" and print only the numbers that fall between 100 and 200. This tests your ability to scan leaked memory for binary data rather than just strings .
The Steps:
Memory Allocation: Request memory via sbrk().
Pointer Casting: Cast the memory following the marker to an integer pointer to read the data correctly.
Files to change: user/sniffer.c
char *mem = sbrk(4096 * 32); 

for (int i = 0; i < (4096 * 32) - 8; i++) {
    if (memcmp(mem + i, "NUMS", 4) == 0) {
        int *ptr = (int*)(mem + i + 4);
        // RE-APPLICATION: Scan the next 4 integers
        for(int j = 0; j < 4; j++) {
            if (ptr[j] >= 100 && ptr[j] <= 200) {
                printf("Found valid number: %d\n", ptr[j]);
            }
        }
    }
}

Sniffer Twist: "The Relative-Jump Sniffer"
The Twist: The secret is stored in two parts. After the marker "PART1:", there is a 4-byte integer offset. You must read that integer and "jump" ahead by that many bytes from your current position to find "PART2:" and the actual password. This tests your ability to handle non-linear memory navigation.

The Steps:
Memory Access: Request memory via sbrk().
Pointer Arithmetic: Use the integer retrieved from memory to calculate the next address dynamically .
Files to change: user/sniffer.c
char *mem = sbrk(4096 * 32); 
if (memcmp(mem + i, "PART1:", 6) == 0) {
    // RE-APPLICATION: Non-linear navigation
    int jump = *(int*)(mem + i + 6); // Read the offset
    char *part2_ptr = mem + i + jump; // Calculate jump
    
    if (memcmp(part2_ptr, "PART2:", 6) == 0) {
        printf("Found Secret: %s\n", part2_ptr + 6);
    }
}

Sniffer Twist: "The Relative-Jump Sniffer"
The Twist: The secret is stored in two parts. After the marker "PART1:", there is a 4-byte integer offset. You must read that integer and "jump" ahead by that many bytes from your current position to find "PART2:" and the actual password.
The Steps:
Memory Access: Request memory via sbrk().
Pointer Arithmetic: Use the integer retrieved from memory to calculate the next address dynamically .
Files to change: user/sniffer.c

char *mem = sbrk(4096 * 32); 
if (memcmp(mem + i, "PART1:", 6) == 0) {
    // RE-APPLICATION: Non-linear navigation
    int jump = *(int*)(mem + i + 6); // Read the offset
    char *part2_ptr = mem + i + jump; // Calculate jump
    
    if (memcmp(part2_ptr, "PART2:", 6) == 0) {
        printf("Found Secret: %s\n", part2_ptr + 6);
    }
}

Sniffer Twist: "The Metadata Header Sniffer"
The Twist: A previous process didnt store a simple string. It stored a 12-byte header consisting of [4-byte ID][4-byte Length][4-byte Checksum], followed by the secret. Your sniffer must find the ID 0x12345678, read the Length, and print only that exact number of bytes.

Files to change: user/sniffer.c

char *mem = sbrk(4096 * 32); 
for (int i = 0; i < (4096 * 32) - 12; i++) {
    uint32 *id_ptr = (uint32*)(mem + i);
    if (*id_ptr == 0x12345678) { // RE-APPLICATION: Multi-byte ID match
        int length = *(int*)(mem + i + 4);
        char *secret = mem + i + 12; // Secret follows the 12-byte header
        
        for(int j = 0; j < length; j++) printf("%c", secret[j]);
        printf("\n");
        exit(0);
    }
}
































🛠️ Variation 2: "Conditional" Monitoring (Syscalls)

The Lab: Print a trace for every syscall set in the mask .
The Quiz Twist: Only print the trace if the syscall fails (returns a negative value). This tests if you know that a0 holds the return value after execution.
+2

File to change: kernel/syscall.c
void syscall(void) {
  struct proc *p = myproc();
  int num = p->trapframe->a7; 

  if (num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    p->trapframe->a0 = syscalls[num](); // Execute the syscall

    // THE TWIST: Combined Condition
    // Reasoning: Check if the syscall is in the mask AND if the return value (a0) is < 0.
    if (((p->monitor_mask >> num) & 1) && ((int)p->trapframe->a0 < 0)) {
        printf("%d: syscall %s FAILED -> %d\n", p->pid, syscall_names[num], p->trapframe->a0);
    }
  }
}

"Error-Only" Monitor

The Lab: Trace every syscall set in the mask .
The Quiz Twist: Only print the trace if the system call fails (returns a negative value).
void syscall(void) {
  struct proc *p = myproc();
  int num = p->trapframe->a7; // Syscall number is in a7 [cite: 932]

  if (num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    p->trapframe->a0 = syscalls[num](); // Run syscall [cite: 947-954]

    // THE TWIST: Check return value
    // Reasoning: a0 holds the return value; cast to int to check for -1. [cite: 921]
    if (((p->monitor_mask >> num) & 1) && ((int)p->trapframe->a0 < 0)) {
      printf("%d: syscall %s FAILED -> %d\n", p->pid, syscall_names[num], p->trapframe->a0);
    }
  }
}

Monitor Mechanic: "The Targeted PID Monitor"

Mechanic: Conditional syscall tracing based on a bitmask.
Re-Application: Modify the logic so it only prints the trace if the process has a specific PID (e.g., only trace the init process or odd-numbered PIDs).

File to change:
void syscall(void) {
  struct proc *p = myproc(); // [cite: 943]
  int num = p->trapframe->a7; // [cite: 932]

  if (num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    p->trapframe->a0 = syscalls[num](); // [cite: 947-954]

    // RE-APPLICATION: Add PID-based condition
    // Only trace if bit is set AND PID is odd
    if (((p->monitor_mask >> num) & 1) && (p->pid % 2 != 0)) {
      printf("%d: syscall %s -> %d\n", p->pid, syscall_names[num], p->trapframe->a0); // [cite: 921]
    }
  }
}

Monitor Mechanic: "The Name-Based Filter"

The Mechanic: Modifying the kernels syscall() dispatcher to print traces.
The Re-Application: The monitor should only print a trace if the process name is exactly "sh" or "grep".
+3

File to change: kernel/syscall.c
void syscall(void) {
  struct proc *p = myproc(); // [cite: 943]
  int num = p->trapframe->a7; // 

  if (num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    p->trapframe->a0 = syscalls[num](); // [cite: 954]

    // RE-APPLICATION: Filter by process name
    // Reasoning: 'p->name' stores the string of the executable.
    if (((p->monitor_mask >> num) & 1) && (strncmp(p->name, "sh", 2) == 0)) {
        printf("%d: syscall %s -> %d\n", p->pid, syscall_names[num], p->trapframe->a0); // [cite: 921]
    }
  }
}

Monitor Mechanic: "The Syscall Call-Counter"

The Mechanic: Tracking system calls in the kernels dispatcher .
The Re-Application: Instead of printing a trace line immediately, the kernel should count how many times each monitored syscall is called. When the process calls exit(), it prints the final tally.

File 1 to change: kernel/proc.h
struct proc {
  // ... existing fields ...
  uint32 monitor_mask; // [cite: 935]
  int syscall_counts[24]; // RE-APPLICATION: Array to store counts
};

File 2 to change: kernel/syscall.c (inside syscall())
void syscall(void) {
  struct proc *p = myproc();
  int num = p->trapframe->a7; 

  if (num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    p->trapframe->a0 = syscalls[num](); 

    // RE-APPLICATION: Increment count if monitored
    if ((p->monitor_mask >> num) & 1) {
      p->syscall_counts[num]++; 
    }
  }
}

Monitor Mechanic: "The Syscall Argument Logger"

Mechanic: Accessing the trapframe to inspect syscall data.
Re-Application: The monitor must print the first argument of the system call if the bit is set. (Note: The first argument is stored in a0 before the syscall executes).
+1

File to change: kernel/syscall.c
void syscall(void) {
  struct proc *p = myproc();
  int num = p->trapframe->a7; 
  
  // RE-APPLICATION: Capture argument BEFORE it is overwritten by the return value
  uint64 arg0 = p->trapframe->a0; 

  if (num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    p->trapframe->a0 = syscalls[num](); // Execute syscall

    if ((p->monitor_mask >> num) & 1) {
      // Step: Print both the return value (a0) and the captured argument (arg0)
      printf("%d: %s(arg0: %p) -> %d\n", 
             p->pid, syscall_names[num], arg0, (int)p->trapframe->a0);
    }
  }
}

Monitor Mechanic: "The Syscall Call-Counter"

Mechanic: Updating process metadata inside the kernels syscall() dispatcher.
Re-Application: Instead of printing a trace line immediately, the kernel should count how many times each monitored syscall is called.
+1

File 1: kernel/proc.h
struct proc {
  // ... 
  uint32 monitor_mask; [cite: 547]
  int syscall_counts[24]; // RE-APPLICATION: Array to store counts
};
File 2: kernel/syscall.c (inside syscall())
void syscall(void) {
  struct proc *p = myproc(); [cite: 555]
  int num = p->trapframe->a7; [cite: 544]

  if (num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    p->trapframe->a0 = syscalls[num]();

    // RE-APPLICATION: Increment count if bit is set in mask
    if ((p->monitor_mask >> num) & 1) { [cite: 637, 639]
      p->syscall_counts[num]++; 
    }
  }
}

Monitor Mechanic: "The Syscall Call-Counter"

The Mechanic: Updating process metadata inside the kernels syscall() dispatcher .
Re-Application: Instead of printing a trace, the kernel should count how many times each monitored syscall is called.
+2

File 1: kernel/proc.h
struct proc {
  // ... existing fields ...
  uint32 monitor_mask; [cite: 547]
  int syscall_counts[24]; // RE-APPLICATION: Add a counter array
};

File 2: kernel/syscall.c (inside syscall())
void syscall(void) {
  struct proc *p = myproc(); [cite: 555]
  int num = p->trapframe->a7; [cite: 603]

  if (num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    p->trapframe->a0 = syscalls[num](); [cite: 603]

    // RE-APPLICATION: Increment count if monitored
    if ((1 << num) & p->monitor_mask) {
        p->syscall_counts[num]++; // Increment the specific syscall's tally
    }
  }
}

Monitor Mechanic: "The Syscall Limit Trigger"

Mechanic: Using a syscall to set a kernel-level threshold.
Re-Application: Modify the monitor syscall to accept a second argument: a "limit". The kernel should trace syscalls normally, but once the process has called more than "limit" syscalls, the kernel should kill the process instead of returning.
+1

File 1: kernel/proc.h
struct proc {
  // ...
  uint32 monitor_mask; [cite: 547]
  int syscall_count;   // RE-APPLICATION: Track total calls
  int syscall_limit;   // RE-APPLICATION: Store the threshold
};
File 2: kernel/syscall.c (inside syscall())
p->trapframe->a0 = syscalls[num](); [cite: 603]

// RE-APPLICATION: Enforcement logic
if ((1 << num) & p->monitor_mask) {
    p->syscall_count++;
    if (p->syscall_count > p->syscall_limit) {
        printf("Process %d exceeded syscall limit! Killing...\n", p->pid);
        setkilled(p); // Terminate the process
    }
}


Monitor Mechanic: "The Syscall Limit Trigger"

The Mechanic: Modifying the kernels syscall() dispatcher to enforce process-specific rules .
Re-Application: Modify monitor to take a "limit." The kernel traces syscalls normally, but once a process exceeds the limit, it is killed instead of returning.
+1

File 1: kernel/proc.h
struct proc {
  // ... existing fields ...
  uint32 monitor_mask; // [cite: 547]
  int call_count;      // RE-APPLICATION: Track total calls
  int call_limit;      // RE-APPLICATION: Threshold
};

File 2: kernel/syscall.c (inside syscall())
p->trapframe->a0 = syscalls[num](); // Run syscall

// RE-APPLICATION: Enforcement logic
if ((1 << num) & p->monitor_mask) {
    p->call_count++;
    if (p->call_count > p->call_limit) {
        printf("Process %d exceeded limit! Killing...\n", p->pid);
        setkilled(p); // Terminate process
    }
}
Monitor Variation: "The Return-Code Filter"

Mechanic: Intercepting syscall return values in syscall().
The Quiz Twist: The monitor should only print a trace if the system call succeeds (returns a non-negative value) AND if the system call number is odd.

File to change: kernel/syscall.c
void syscall(void) {
  struct proc *p = myproc();
  int num = p->trapframe->a7; 

  if (num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    p->trapframe->a0 = syscalls[num](); // Run syscall 

    // RE-APPLICATION: Success + Parity Check
    // Reasoning: 'num % 2 != 0' checks for odd syscall IDs.
    // '(int)p->trapframe->a0 >= 0' ensures we skip failures (-1).
    if (((p->monitor_mask >> num) & 1) && 
        ((int)p->trapframe->a0 >= 0) && 
        (num % 2 != 0)) {
      printf("%d: SUCCESS %s -> %d\n", p->pid, syscall_names[num], p->trapframe->a0);
    }
  }
}


Monitor Variation: "The Return-Code Filter"

Mechanic: Intercepting syscall return values in syscall().
The Quiz Twist: The monitor should only print a trace if the system call succeeds (returns a non-negative value) AND if the system call number is odd.

File to change: kernel/syscall.c
void syscall(void) {
  struct proc *p = myproc();
  int num = p->trapframe->a7; 

  if (num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    p->trapframe->a0 = syscalls[num](); // Run syscall 

    // RE-APPLICATION: Success + Parity Check
    // Reasoning: 'num % 2 != 0' checks for odd syscall IDs.
    // '(int)p->trapframe->a0 >= 0' ensures we skip failures (-1).
    if (((p->monitor_mask >> num) & 1) && 
        ((int)p->trapframe->a0 >= 0) && 
        (num % 2 != 0)) {
      printf("%d: SUCCESS %s -> %d\n", p->pid, syscall_names[num], p->trapframe->a0);
    }
  }
}

Monitor Mechanic: "The Syscall Return Mask"

The Mechanic: Manipulating the syscall() dispatcher to influence process behavior.
The Quiz Twist: Modify monitor so that if a syscall is monitored, the kernel fakes a success. Regardless of what the syscall actually did, it should return 0 to the user space.
+1

File to change: kernel/syscall.c
void syscall(void) {
  struct proc *p = myproc();
  int num = p->trapframe->a7;

  if (num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    p->trapframe->a0 = syscalls[num](); // Execute normally

    // RE-APPLICATION: Return Value Override
    // Reasoning: If monitored, we overwrite the return register (a0) with 0.
    if ((p->monitor_mask >> num) & 1) {
        printf("%d: %s intercepted. Faking success.\n", p->pid, syscall_names[num]);
        p->trapframe->a0 = 0; 
    }
  }
}

Monitor Mechanic: "The Syscall Success-Only Filter"The Mechanic: Intercepting and inspecting the syscall return register (a0) in the kernel .
The Quiz Twist: The monitor should only print a trace if the system call succeeded (return value $\geq$ 0). If it failed (-1), remain silent.+1File to change: kernel/syscall.c
void syscall(void) {
  struct proc *p = myproc(); [cite: 555]
  int num = p->trapframe->a7; [cite: 544]

  if (num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    p->trapframe->a0 = syscalls[num](); // Run syscall [cite: 603]

    // RE-APPLICATION: Filtering by return value success
    // Reasoning: The return value in a0 is only useful to trace if the call worked.
    if (((p->monitor_mask >> num) & 1) && ((int)p->trapframe->a0 >= 0)) {
        printf("%d: %s SUCCESS -> %d\n", p->pid, syscall_names[num], (int)p->trapframe->a0);
    }
  }
}

Monitor Mechanic: "The Syscall Error-only Trigger"

The Mechanic: Intercepting syscall return values in the kernels syscall() dispatcher.
The Quiz Twist: Modify the monitor syscall to take an upper limit. Tracing should only occur if the syscall fails (returns a negative value) AND the syscall number is below the limit.
+1

File to change: kernel/syscall.c
void syscall(void) {
  struct proc *p = myproc(); [cite: 555]
  int num = p->trapframe->a7; [cite: 544]

  if (num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    p->trapframe->a0 = syscalls[num](); // Run syscall [cite: 603]

    // RE-APPLICATION: Combined failure + range filter
    // Reasoning: 'monitor_limit' is a new field added to struct proc[cite: 547].
    if (((p->monitor_mask >> num) & 1) && 
        ((int)p->trapframe->a0 < 0) && 
        (num < p->monitor_limit)) {
      printf("%d: %s FAILED -> %d\n", p->pid, syscall_names[num], p->trapframe->a0);
    }
  }
}

Monitor Mechanic: "The Syscall Timestamping"

The Mechanic: Modifying the kernels syscall() dispatcher to record metadata.
The Re-Application: Instead of just tracing, the kernel should record the uptime (using ticks) when a monitored syscall starts and finished, printing the duration.
+1

File 1: kernel/proc.h
struct proc {
  // ... 
  uint32 monitor_mask; [cite: 547]
  uint start_tick; // RE-APPLICATION: Storage for timing
};

File 2: kernel/syscall.c (inside syscall())
void syscall(void) {
  struct proc *p = myproc(); [cite: 555]
  int num = p->trapframe->a7; [cite: 544]

  if (num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    // RE-APPLICATION: Capture start time
    if ((p->monitor_mask >> num) & 1) p->start_tick = ticks;

    p->trapframe->a0 = syscalls[num](); [cite: 603]

    // RE-APPLICATION: Calculate and print duration
    if ((p->monitor_mask >> num) & 1) {
      printf("%d: %s took %d ticks\n", p->pid, syscall_names[num], ticks - p->start_tick); [cite: 603]
    }
  }
}

Monitor Mechanic: "The Syscall Return-Value Filter"

The Mechanic: Intercepting the syscall return value in the kernel a0 register.
The Quiz Twist: Modify the monitor logic so it only prints a trace if the system call fails (i.e., returns a negative value). If the call is successful, the kernel should remain silent.
+1

File to change: kernel/syscall.c
void syscall(void) {
  struct proc *p = myproc();
  int num = p->trapframe->a7; 

  if (num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    p->trapframe->a0 = syscalls[num](); // Run syscall

    // RE-APPLICATION: Conditional tracing based on return status
    // Reasoning: We cast a0 to an int to check for -1 (failure)[cite: 603].
    if (((p->monitor_mask >> num) & 1) && ((int)p->trapframe->a0 < 0)) {
        printf("%d: %s FAILED with %d\n", p->pid, syscall_names[num], (int)p->trapframe->a0);
    }
  }
}

Monitor Mechanic: "The Syscall Return-Value Filter"

The Mechanic: Modifying the kernels syscall() dispatcher to inspect the a0 register.
The Quiz Twist: Modify the monitor syscall so that tracing only occurs if the system call returns a specific value (e.g., return value is exactly 0).
+1

File to change: kernel/syscall.c
void syscall(void) {
  struct proc *p = myproc(); // [cite: 555]
  int num = p->trapframe->a7; // [cite: 544]

  if (num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    p->trapframe->a0 = syscalls[num](); // Run syscall [cite: 603]

    // RE-APPLICATION: Filter by Return Value
    // Reasoning: Trace only successful calls that return exactly 0 (like close or unlink).
    if (((p->monitor_mask >> num) & 1) && (p->trapframe->a0 == 0)) {
        printf("%d: %s returned SUCCESS(0)\n", p->pid, syscall_names[num]);
    }
  }
}

Monitor Mechanic: "The Syscall Return-Value Override"

The Mechanic: Modifying the kernels syscall() dispatcher to influence user-space outcomes .
The Quiz Twist: Modify the monitor syscall so that if a system call is traced, the kernel fakes a failure. Regardless of the actual result, it should return -1 to the user program.
+1

File to change: kernel/syscall.c
void syscall(void) {
  struct proc *p = myproc(); // [cite: 555]
  int num = p->trapframe->a7; // [cite: 544]

  if (num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    p->trapframe->a0 = syscalls[num](); // Run syscall

    // RE-APPLICATION: Return Value Manipulation
    // Reasoning: Overwriting 'a0' changes the return value the user process sees.
    if ((p->monitor_mask >> num) & 1) {
        printf("%d: Intercepted %s. Faking failure.\n", p->pid, syscall_names[num]);
        p->trapframe->a0 = -1; 
    }
  }
}

Task: Monitor — The "Return Value Override"
This twist moves beyond simple tracing . Modify the syscall() dispatcher in the kernel so that if a system call is being monitored, the kernel overwrites the return value to be 0 (success), regardless of what the syscall actually returned . This tests your understanding of the trapframe->a0 register as the conduit for syscall results back to user space.
+3

modified / created file 1: kernel/syscall.c
void syscall(void) {
  struct proc *p = myproc();
  int num = p->trapframe->a7;

  if (num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    p->trapframe->a0 = syscalls[num](); // Run actual syscall

    // RE-APPLICATION: Return Value Manipulation
    // If the bit for this syscall is set in the mask, force success (0)
    if ((p->monitor_mask >> num) & 1) {
        printf("%d: monitored %s -> forced 0\n", p->pid, syscall_names[num]);
        p->trapframe->a0 = 0; 
    }
  }
}

Monitor Mechanic: "The Syscall Timestamping"

The Mechanic: Modifying the kernels syscall() dispatcher to record metadata.
The Re-Application: Instead of just tracing, the kernel should record the uptime (using ticks) when a monitored syscall starts and finished, printing the duration.
+2

File 1: kernel/proc.h
struct proc {
  // ... 
  uint32 monitor_mask; [cite: 547]
  uint start_tick; // RE-APPLICATION: Storage for timing
};

File 2: kernel/syscall.c (inside syscall())
void syscall(void) {
  struct proc *p = myproc(); [cite: 555]
  int num = p->trapframe->a7; [cite: 544]

  if (num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    // RE-APPLICATION: Capture start time
    if ((p->monitor_mask >> num) & 1) p->start_tick = ticks;

    p->trapframe->a0 = syscalls[num](); [cite: 603]

    // RE-APPLICATION: Calculate and print duration
    if ((p->monitor_mask >> num) & 1) {
      printf("%d: %s took %d ticks\n", p->pid, syscall_names[num], ticks - p->start_tick); [cite: 533]
    }
  }
}


Monitor Mechanic: "The Syscall Return-Value Filter"

The Mechanic: Intercepting and inspecting the syscall return register (a0) in the kernel.
The Quiz Twist: Modify the monitor logic so it only prints a trace if the system call fails (returns a negative value). If the call is successful, the kernel should remain silent.
+3

File to change: kernel/syscall.c
void syscall(void) {
  struct proc *p = myproc(); // [cite: 555]
  int num = p->trapframe->a7; // 

  if (num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    p->trapframe->a0 = syscalls[num](); // Run syscall [cite: 603]

    // RE-APPLICATION: Conditional tracing based on return status
    // Reasoning: We cast a0 to an int to check for -1 (failure). [cite: 533, 603]
    if (((p->monitor_mask >> num) & 1) && ((int)p->trapframe->a0 < 0)) {
        printf("%d: %s FAILED with %d\n", p->pid, syscall_names[num], (int)p->trapframe->a0);
    }
  }
}

Monitor Mechanic: "The Syscall Argument Filter"
The Mechanic: Accessing the trapframe registers to inspect syscall input parameters.
The Quiz Twist: The monitor should only print a trace if the syscall is write (SYS_write) AND the number of bytes being written (the 3rd argument, in register a2) is greater than 100.

File to change: kernel/syscall.c
void syscall(void) {
  struct proc *p = myproc();
  int num = p->trapframe->a7;

  if (num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    // RE-APPLICATION: Pre-execution Argument Inspection
    // Reasoning: a2 holds the 3rd argument for syscalls like write.
    uint64 arg2 = p->trapframe->a2; 

    p->trapframe->a0 = syscalls[num](); // Execute

    if (((p->monitor_mask >> num) & 1) && num == 16 && arg2 > 100) {
        printf("%d: LARGE WRITE (%d bytes) -> %d\n", p->pid, (int)arg2, (int)p->trapframe->a0);
    }
  }
}

Monitor Mechanic: "The Syscall Argument Guard"
The Mechanic: Intercepting the trapframe in the kernels syscall() dispatcher.
The Quiz Twist: Modify the monitor logic so that if a process tries to call write (SYS_write) to file descriptor 1 (stdout) with more than 50 bytes, the kernel blocks the call by returning -1 without executing the syscall.

File to change: kernel/syscall.c
void syscall(void) {
  struct proc *p = myproc();
  int num = p->trapframe->a7;

  // RE-APPLICATION: Pre-execution guard
  // Reasoning: a0 is the 1st arg (fd), a2 is the 3rd arg (count)
  if (num == 16 && p->trapframe->a0 == 1 && p->trapframe->a2 > 50) {
      p->trapframe->a0 = -1; // Force failure return
      return; 
  }

  if (num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    p->trapframe->a0 = syscalls[num]();
    // ... tracing logic ...
  }
}

Monitor Mechanic: "The Syscall Call-Logger"
Mechanic: Modifying the kernels syscall() dispatcher to record metadata.
The Quiz Twist: Instead of just tracing, the kernel must maintain a history of the last 5 monitored syscall numbers for that process in a small array within struct proc.

File 1: kernel/proc.h
struct proc {
  // ... existing fields ...
  uint32 monitor_mask;
  int syscall_history[5]; // RE-APPLICATION: Add history array
  int history_index;       // To track the current position
};

File 2: kernel/syscall.c (inside syscall())
void syscall(void) {
  struct proc *p = myproc();
  int num = p->trapframe->a7;

  if (num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    p->trapframe->a0 = syscalls[num]();

    // RE-APPLICATION: Circular buffer logic in kernel
    if ((p->monitor_mask >> num) & 1) {
        p->syscall_history[p->history_index] = num;
        p->history_index = (p->history_index + 1) % 5;
    }
  }
}

Monitor Mechanic: "The Syscall Failure Count"
The Mechanic: Tracking process metadata in the kernels syscall() dispatcher.
The Quiz Twist: Add an array fail_counts[24] to struct proc. Every time a monitored syscall returns a negative value (failure), increment its specific count in the array.

File 1: kernel/proc.h
struct proc {
  // ... existing fields ...
  uint32 monitor_mask;
  int fail_counts[24]; // RE-APPLICATION: Add failure trackers
};

File 2: kernel/syscall.c (inside syscall())
void syscall(void) {
  struct proc *p = myproc();
  int num = p->trapframe->a7;

  if (num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    p->trapframe->a0 = syscalls[num](); // Run syscall

    // RE-APPLICATION: Failure tracking logic
    // Reasoning: a0 holds the return value; -1 typically indicates an error.
    if (((p->monitor_mask >> num) & 1) && ((int)p->trapframe->a0 < 0)) {
        p->fail_counts[num]++;
    }
  }
}

Monitor Mechanic: "The Syscall Timestamping"
The Mechanic: Modifying the kernels syscall() dispatcher to record process metadata.
The Quiz Twist: Instead of just tracing, the kernel must record the tick count (uptime) of the last time each monitored syscall was called.

File 1: kernel/proc.h
struct proc {
  // ... existing fields ...
  uint32 monitor_mask;
  uint last_call_ticks[24]; // RE-APPLICATION: Storage for timestamps
};
File 2: kernel/syscall.c (inside syscall())
extern uint ticks; // Access global kernel timer

void syscall(void) {
  struct proc *p = myproc();
  int num = p->trapframe->a7;

  if (num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    p->trapframe->a0 = syscalls[num]();

    // RE-APPLICATION: Kernel state tracking
    if ((p->monitor_mask >> num) & 1) {
        p->last_call_ticks[num] = ticks;
        printf("%d: %s called at tick %d\n", p->pid, syscall_names[num], ticks);
    }
  }
}

Monitor Mechanic: "The Syscall Success-Only Filter"The Mechanic: Intercepting and inspecting the syscall return register (a0) in the kernel.The Quiz Twist: The monitor should only print a trace if the system call succeeded (return value $\geq$ 0). If it failed (-1), the kernel remains silent.File to change: kernel/syscall.c
void syscall(void) {
  struct proc *p = myproc();
  int num = p->trapframe->a7;

  if (num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    p->trapframe->a0 = syscalls[num](); // Run syscall

    // RE-APPLICATION: Filtering by return value success
    // Reasoning: The return value in a0 is only useful to trace if the call worked.
    if (((p->monitor_mask >> num) & 1) && ((int)p->trapframe->a0 >= 0)) {
        printf("%d: %s SUCCESS -> %d\n", p->pid, syscall_names[num], (int)p->trapframe->a0);
    }
  }
}

Monitor Mechanic: "The Syscall Cooldown"
The Mechanic: Modifying the kernels syscall() dispatcher to enforce timing.
The Quiz Twist: Prevent a process from "spamming" a monitored syscall. If a traced syscall is called more than once every 10 ticks, the kernel should return -1 for the second attempt without executing it.

File 1: kernel/proc.h
struct proc {
  // ...
  uint32 monitor_mask;
  uint last_call_time; // RE-APPLICATION: Record last success tick
};

File 2: kernel/syscall.c
extern uint ticks;
// ... inside syscall() ...
if ((p->monitor_mask >> num) & 1) {
    if (ticks - p->last_call_time < 10) {
        p->trapframe->a0 = -1; // Cooldown active, fail the call
        return;
    }
    p->last_call_time = ticks; // Reset cooldown on success
}
p->trapframe->a0 = syscalls[num]();

Monitor Mechanic: "The Syscall Argument Guard"
Mechanic: Intercepting the trapframe registers to inspect syscall input parameters.
The Quiz Twist: Modify the monitor logic so that if a process tries to call write (SYS_write) to file descriptor 1 (stdout) with more than 50 bytes, the kernel blocks the call by returning -1 without executing the syscall.

File to change: kernel/syscall.c
void syscall(void) {
  struct proc *p = myproc();
  int num = p->trapframe->a7;

  // RE-APPLICATION: Pre-execution guard
  // Reasoning: a0 is the 1st arg (fd), a2 is the 3rd arg (count).
  if (num == 16 && p->trapframe->a0 == 1 && p->trapframe->a2 > 50) {
      printf("%d: Write blocked - too large\n", p->pid);
      p->trapframe->a0 = -1; // Force failure return
      return; 
  }

  if (num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    p->trapframe->a0 = syscalls[num](); // Run normally
    // ... tracing logic ...
  }
}

Monitor Mechanic: "The Syscall Return-Value Override"
The Mechanic: Modifying the kernels syscall() dispatcher to influence user-space outcomes.
The Quiz Twist: Modify the monitor syscall so that if a system call is traced, the kernel fakes a success. Regardless of the actual result, it should return 0 to the user program.

File to change: kernel/syscall.c
void syscall(void) {
  struct proc *p = myproc();
  int num = p->trapframe->a7;

  if (num > 0 && num < NELEM(syscalls) && syscalls[num]) {
    p->trapframe->a0 = syscalls[num](); // Run actual syscall

    // RE-APPLICATION: Return Value Manipulation
    // Reasoning: Overwriting 'a0' changes the return value the user process sees.
    if ((p->monitor_mask >> num) & 1) {
        printf("%d: %s intercepted. Faking success.\n", p->pid, syscall_names[num]);
        p->trapframe->a0 = 0; 
    }
  }
}
Monitor Mechanic: "The Syscall Cooldown"
The Mechanic: Modifying the kernels syscall() dispatcher to enforce timing.
The Quiz Twist: Prevent a process from "spamming" a monitored syscall. If a traced syscall is called more than once every 10 ticks, the kernel should return -1 for the second attempt without executing it.
kernel/proc.h
struct proc {
  // ...
  uint32 monitor_mask;
  uint last_call_time; // RE-APPLICATION: Record last success tick
};

kernel/syscall.c
extern uint ticks;
// ... inside syscall() ...
if ((p->monitor_mask >> num) & 1) {
    // RE-APPLICATION: Cooldown Enforcement
    if (ticks - p->last_call_time < 10) {
        p->trapframe->a0 = -1; // Cooldown active, fail the call
        return;
    }
    p->last_call_time = ticks; // Reset cooldown on success
}
p->trapframe->a0 = syscalls[num]();


Monitor Twist: "The Syscall Failure Count"
The Twist: Instead of just tracing, the kernel must maintain a persistent count of how many times each monitored syscall has FAILED (returned -1) for that process. When the process calls exit(), the kernel prints the final failure tally for all monitored calls.
The Steps:
Structure Update: Add an array int fail_counts[24] to struct proc.
State Capture: In syscall(), check the return value in a0 after execution.
Files to change: kernel/proc.h, kernel/syscall.c
// kernel/syscall.c -> syscall()
p->trapframe->a0 = syscalls[num](); // Run syscall

if (((p->monitor_mask >> num) & 1) && ((int)p->trapframe->a0 < 0)) {
    p->fail_counts[num]++; // Increment failure tally [cite: 103]
}


Monitor Twist: "The Syscall Cooldown Monitor"
The Twist: Modify the monitor syscall to take a cooldown (in ticks). If a traced syscall is called more than once within that cooldown period, the kernel traces it but overwrites the return value with -1, effectively "throttling" the process.
The Steps:
proc.h: Add uint last_tick and uint cooldown to struct proc.
syscall.c: Use the global ticks variable to compare time since the last call.
Files to change: kernel/proc.h, kernel/syscall.c, kernel/sysproc.c
The Solution:

// kernel/syscall.c -> syscall()
extern uint ticks; 
if (((p->monitor_mask >> num) & 1)) {
    if (ticks - p->last_tick < p->cooldown) {
        p->trapframe->a0 = -1; // Force failure due to spamming
        printf("%d: %s throttled!\n", p->pid, syscall_names[num]);
    } else {
        p->trapframe->a0 = syscalls[num]();
        p->last_tick = ticks; // Reset timer
    }
}

Monitor Twist: "The Syscall Return-Value Filter"
The Twist: Modify the monitor logic so it only prints a trace if the system call succeeded (returns a value $\geq$ 0). 
If it failed (-1), the kernel remains silent. T
his tests your understanding of the a0 register as the post-execution return holder.
The Steps:
Dispatcher Update: Capture the return value from the trapframe->a0 register .+1
Logic: Cast a0 to an integer to perform the $\geq$ 0 comparison.
Files to change: kernel/syscall.cThe Solution:

// kernel/syscall.c -> syscall()
p->trapframe->a0 = syscalls[num](); // Execute [cite: 158]

// RE-APPLICATION: Filter by Success
if (((p->monitor_mask >> num) & 1) && ((int)p->trapframe->a0 >= 0)) {
    printf("%d: %s SUCCESS -> %d\n", p->pid, syscall_names[num], (int)p->trapframe->a0);
}

Monitor Twist: "The Syscall Return-Value Override"
The Twist: Modify the monitor syscall so that if a system call is traced, the kernel overwrites the return value with 0 (Success), regardless of what the syscall actually returned. This tests your understanding of the a0 register as the conduit for results back to user space.
The Steps:
Capture return: Execute the syscall and store the result in p->trapframe->a0.
Override: Check the mask and explicitly set a0 to 0.
Files to change: kernel/syscall.c
// kernel/syscall.c -> syscall()
p->trapframe->a0 = syscalls[num](); // Execute actual syscall

// THE TWIST: Success Masking
if ((p->monitor_mask >> num) & 1) {
    printf("%d: intercepted %s. Faking success.\n", p->pid, syscall_names[num]);
    p->trapframe->a0 = 0; // RE-APPLICATION: Force user-space to see success
}


Monitor Twist: "The Syscall Name-Based Filter"
The Twist: Modify the monitor syscall to only print traces if the process name (stored in p->name) is exactly "sh" or "grep". This requires you to move beyond bitmasks and look at process metadata.
The Steps:
String Comparison: Use strncmp to compare the current process name against your target.
Plumbing: This logic lives inside the syscall() dispatcher in kernel/syscall.c.
Files to change: kernel/syscall.c
// kernel/syscall.c -> syscall()
p->trapframe->a0 = syscalls[num](); // Execute

// RE-APPLICATION: Metadata Filtering
if (((p->monitor_mask >> num) & 1) && (strncmp(p->name, "sh", 2) == 0)) {
    printf("%d: %s -> %d\n", p->pid, syscall_names[num], (int)p->trapframe->a0);
}

Monitor Twist: "The Syscall Cooldown Monitor"
The Twist: Modify the monitor syscall to take a cooldown (in ticks). If a traced syscall is called more than once within that cooldown period, the kernel traces it but overwrites the return value with -1, effectively "throttling" the process .
The Steps:
Structure Update: Add uint last_tick and uint cooldown to struct proc.
Dispatcher Update: Use the global ticks variable to compare time since the last call.
Files to change: kernel/proc.h, kernel/syscall.c, kernel/sysproc.c
The Solution:
// kernel/syscall.c -> syscall()
extern uint ticks; 
if (((p->monitor_mask >> num) & 1)) {
    if (ticks - p->last_tick < p->cooldown) {
        p->trapframe->a0 = -1; // Force failure due to spamming
        printf("%d: %s throttled!\n", p->pid, syscall_names[num]);
    } else {
        p->trapframe->a0 = syscalls[num]();
        p->last_tick = ticks; // Reset timer
    }
}

Monitor Twist: "The Monitor State Persistence Check"
The Twist: Modify the monitor syscall to take an action flag.

If flag = 1, enable tracing.
If flag = 0, disable tracing.
If flag = 2, Reset all counts (if you implemented a counter twist).
This tests your ability to use argint for control logic, not just bitmasks .
Files to change: kernel/sysproc.c, kernel/syscall.c
The Solution:
// kernel/sysproc.c
uint64 sys_monitor(void) {
    int mask, flag;
    argint(0, &mask);
    argint(1, &flag); // THE TWIST: Command Flag
    struct proc *p = myproc();

    if (flag == 1) p->monitor_mask = mask;
    else if (flag == 0) p->monitor_mask = 0;
    else if (flag == 2) memset(p->syscall_counts, 0, sizeof(p->syscall_counts));
    return 0;
}



































🛠️ Variation 3: "Priority-Based" Scheduling (Threads)

The Lab: Simple Round-Robin (pick the next thread in a circular loop) .
The Quiz Twist: Pick the thread with the highest priority. This tests if you can modify the thread structure and the selection logic.

File 1: user/uthread.c (Structure)
struct thread {
  char       stack[STACK_SIZE]; 
  int        state;             
  int        priority;          // THE TWIST: Add priority field
  struct     thread_context context; 
};

File 2: user/uthread.c (Scheduler)
void thread_schedule(void) {
  struct thread *t, *best_thread = 0;

  // THE TWIST: Selection Logic
  // Reasoning: Instead of picking the first one, loop through ALL to find the highest priority.
  for (t = all_thread; t < all_thread + MAX_THREAD; t++) {
    if (t->state == RUNNABLE) {
      if (best_thread == 0 || t->priority > best_thread->priority) {
        best_thread = t;
      }
    }
  }

  if (best_thread && current_thread != best_thread) {
    next_thread = best_thread;
    next_thread->state = RUNNING;
    t = current_thread;
    current_thread = next_thread;
    thread_switch((uint64)&t->context, (uint64)&next_thread->context);
  }
}

"Priority" Thread Scheduling

The Lab: Circular Round-Robin (pick the next thread in a loop).
The Quiz Twist: Each thread has a priority. The scheduler must pick the RUNNABLE thread with the highest priority value.
+1

Solution (user/uthread.c):
// Step 1: Add priority to struct thread [cite: 606]
struct thread {
  char stack[STACK_SIZE];
  int state;
  int priority; // THE TWIST
  struct thread_context context;
};

// Step 2: Update thread_schedule selection logic [cite: 619-620]
void thread_schedule(void) {
  struct thread *t, *best_thread = 0;

  // THE TWIST: Scan for highest priority
  for (t = all_thread; t < all_thread + MAX_THREAD; t++) {
    if (t->state == RUNNABLE) {
      if (best_thread == 0 || t->priority > best_thread->priority) {
        best_thread = t;
      }
    }
  }
  
  if (best_thread && current_thread != best_thread) {
    next_thread = best_thread;
    // ... continue with thread_switch logic ... [cite: 622]
  }
}

Uthread Mechanic: "The Pausable Thread"

Mechanic: Context switching by saving/restoring registers.
Re-Application: Add a "paused" state. The scheduler should skip any thread whose state is PAUSED even if it is not FREE.
+1

File to change: user/uthread.c
#define PAUSED 0x3 // Add new state

void thread_schedule(void) {
  struct thread *t, *next_thread = 0;
  
  // RE-APPLICATION: Skip threads in PAUSED state
  t = current_thread + 1;
  for(int i = 0; i < MAX_THREAD; i++){
    if(t >= all_thread + MAX_THREAD) t = all_thread;
    
    // Logic: Only pick if RUNNABLE; ignores PAUSED and FREE [cite: 596]
    if(t->state == RUNNABLE) { 
      next_thread = t;
      break;
    }
    t = t + 1;
  }
  // ... rest of switch logic [cite: 620]
}

Uthread Mechanic: "Thread Local Storage (TLS)"

The Mechanic: Preserving register state in a thread_context struct .
The Re-Application: Add a field thread_id to each thread. When a thread yields, it must print its ID and the current value of its ra register.

File to change: user/uthread.c
void thread_yield(void) {
  // RE-APPLICATION: Monitoring context before switch
  // Reasoning: This proves you know where the context data is stored.
  printf("Thread %d yielding. Resuming at: %p\n", 
          current_thread - all_thread, current_thread->context.ra);
          
  current_thread->state = RUNNABLE;
  thread_schedule();
}

4. Uthread Mechanic: "Thread Statistics"

The Mechanic: Context switching by saving registers.
The Re-Application: Track how many times each thread has been scheduled. Add a field schedule_count to the thread struct and increment it every time thread_schedule selects that thread.

File to change: user/uthread.c
void thread_schedule(void) {
  // ... selection logic ...
  if (current_thread != next_thread) {
    // RE-APPLICATION: Tracking scheduler decisions
    next_thread->schedule_count++; 
    
    next_thread->state = RUNNING;
    // ... switch logic ... [cite: 620]
  }
}

uthread Mechanic: "The Thread Trampoline"

Mechanic: Manipulating the ra (Return Address) to control entry points .
Re-Application: Instead of jumping directly to func, every thread must first jump to a wrapper() function that prints "Starting thread..." and then calls func().
+1

File to change: user/uthread.c
void wrapper() {
    printf("Starting thread...\n");
    // In a real twist, you'd need a way to track which func to call, 
    // but the mechanic is setting RA to the wrapper's address.
}

void thread_create(void (*func)()) {
  /* ... */
  // RE-APPLICATION: Entry point redirection
  t->context.ra = (uint64)wrapper; 
  t->context.sp = (uint64)t->stack + STACK_SIZE; 
}

uthread Mechanic: "The Thread Trampoline"

Mechanic: Manipulating the ra (Return Address) to control thread entry points.
Re-Application: Every thread must first jump to a pre_run() function that prints "Thread Initializing" before executing the actual thread function.
+2

File to change: user/uthread.c
void pre_run() {
    printf("Thread Initializing...\n");
    // In a complex twist, this would then call the real function.
}

void thread_create(void (*func)()) {
  struct thread *t;
  /* ... find FREE thread ... */
  t->state = RUNNABLE; [cite: 653]
  
  // RE-APPLICATION: Redirecting initial execution
  t->context.ra = (uint64)pre_run; 
  t->context.sp = (uint64)t->stack + STACK_SIZE; [cite: 223, 611]
}



uthread Mechanic: "The Thread Entry Wrapper"

The Mechanic: Manipulating the Return Address (ra) to control where a thread starts .
Re-Application: In thread_create, instead of jumping directly to the function, set ra to a generic starter() function that prints "Thread booting..." before calling the real task.
+2

File to change: user/uthread.c
void starter() {
    printf("Thread booting up...\n");
    // In a real twist, this would use a saved pointer to call the original func.
}

void thread_create(void (*func)()) {
  struct thread *t;
  /* ... find FREE thread ... [cite: 660] */
  t->state = RUNNABLE; [cite: 661]
  
  // RE-APPLICATION: Redirecting the initial entry point
  t->context.ra = (uint64)starter; 
  t->context.sp = (uint64)t->stack + STACK_SIZE; [cite: 662]
}

uthread Mechanic: "The Thread Local ID"

Mechanic: Managing the thread_context and thread identifiers.
Re-Application: Add a tid (Thread ID) to the struct thread. When thread_switch occurs, the kernel-level printf should show: "Switching from Thread X to Thread Y".
+1

File to change: user/uthread.c
void thread_schedule(void) {
  // ... selection logic ...
  if (current_thread != next_thread) {
    // RE-APPLICATION: Identifying threads during switch
    printf("Switch: %d -> %d\n", current_thread->tid, next_thread->tid);
    
    struct thread *t = current_thread;
    current_thread = next_thread;
    thread_switch((uint64)&t->context, (uint64)&next_thread->context); [cite: 232]
  }
}
uthread Mechanic: "The Thread Entry Trampoline"

The Mechanic: Manipulating the Return Address (ra) to control initial execution .
Re-Application: In thread_create, instead of jumping directly to func, set ra to a generic log_start() function that prints "Thread X is now running" before calling the real task.
+2

File to change: user/uthread.c
void log_start() {
    printf("Thread %d is now running...\n", current_thread - all_thread);
    // In a real test, you'd need a jump to the actual func here.
}

void thread_create(void (*func)()) {
  struct thread *t;
  /* ... find FREE thread ... */
  t->state = RUNNABLE;
  
  // RE-APPLICATION: Entry point redirection
  t->context.ra = (uint64)log_start; 
  t->context.sp = (uint64)t->stack + STACK_SIZE; // 
}

uthread Variation: "The Round-Robin Observer"

Mechanic: Iterating through the thread table.
The Quiz Twist: In thread_schedule, you must skip any thread that has an even index in the all_thread array, effectively only scheduling threads 1 and 3.

File to change: user/uthread.c
void thread_schedule(void) {
  struct thread *t, *next_thread = 0;

  t = current_thread + 1;
  for (int i = 0; i < MAX_THREAD; i++) {
    if (t >= all_thread + MAX_THREAD) t = all_thread;
    
    // RE-APPLICATION: Index Filter
    // Reasoning: 't - all_thread' gives the index (0, 1, 2, or 3).
    int idx = t - all_thread;
    if (t->state == RUNNABLE && (idx % 2 != 0)) {
      next_thread = t;
      break;
    }
    t++;
  }
  // ... rest of switch logic [cite: 232]
}


PH (Hash) Variation: "The Conditional Swap"

Mechanic: Atomic "Check-and-Modify" using locks.
The Quiz Twist: Implement a function swap_if_greater(int key1, int key2). You must compare their values; if value1 > value2, swap them.

File to change: notxv6/ph-with-mutex-locks.c
void swap_if_greater(int k1, int k2) {
  int b1 = k1 % NBUCKET; [cite: 308]
  int b2 = k2 % NBUCKET;

  // RE-APPLICATION: Ordered locking to prevent deadlock
  int first = (b1 < b2) ? b1 : b2;
  int second = (b1 < b2) ? b2 : b1;

  pthread_mutex_lock(&locks[first]); [cite: 389]
  if (b1 != b2) pthread_mutex_lock(&locks[second]);

  struct entry *e1 = get_internal(k1);
  struct entry *e2 = get_internal(k2);

  if (e1 && e2 && e1->value > e2->value) {
    int temp = e1->value;
    e1->value = e2->value;
    e2->value = temp;
  }

  pthread_mutex_unlock(&locks[first]); [cite: 389]
  if (b1 != b2) pthread_mutex_unlock(&locks[second]);
}


uthread Mechanic: "The CPU Affinity Check"

The Mechanic: Tracking thread execution state and context .
The Quiz Twist: Add a field last_cpu to struct thread. Every time a thread is scheduled, update this field with the current CPU ID (hint: use cpuid() if in kernel, but for uthread in user space, you might just use a counter or a "Round ID").

File to change: user/uthread.c
void thread_schedule(void) {
  // ... selection logic ...
  if (current_thread != next_thread) {
    // RE-APPLICATION: State Tracking
    // Reasoning: Records the "generation" or "round" this thread last ran in.
    next_thread->last_run_round = global_round_counter++; 
    
    next_thread->state = RUNNING;
    thread_switch((uint64)&current_thread->context, (uint64)&next_thread->context);
  }
}
uthread Mechanic: "The Context Checksum"

The Mechanic: Ensuring the integrity of the thread_context during a yield .
The Quiz Twist: Add a field yield_count to the thread struct. Every time a thread yields, increment this count and print it along with the current value of the sp (Stack Pointer) register.

File to change: user/uthread.c
void thread_yield(void) {
  // RE-APPLICATION: Tracking thread lifecycle state
  current_thread->yield_count++; 
  printf("Thread %d yielding for the %d time. SP is %p\n", 
          current_thread - all_thread, current_thread->yield_count, current_thread->context.sp);

  current_thread->state = RUNNABLE; [cite: 206]
  thread_schedule(); [cite: 208]
}

uthread Mechanic: "The Thread Execution Monitor"

The Mechanic: Context switching and thread metadata management.
The Quiz Twist: Add a last_run timestamp (or a simple counter) to struct thread. Every time thread_schedule picks a thread, update this value. If you call a new function thread_info(), it must print how long ago each thread ran.
+1

File to change: user/uthread.c
void thread_schedule(void) {
  // ... selection logic ...
  if (current_thread != next_thread) {
    // RE-APPLICATION: State auditing
    // Reasoning: Tracking which threads are "starving" or getting more CPU time.
    next_thread->run_count++; 
    
    next_thread->state = RUNNING;
    thread_switch((uint64)&current_thread->context, (uint64)&next_thread->context); [cite: 232]
  }
}

uthread Mechanic: "The Thread Stack Canary"

The Mechanic: Monitoring stack boundaries during context switches.
The Quiz Twist: To detect stack overflow, place a "canary" value (0xDEADBEEF) at the very bottom of each threads stack. In thread_schedule, check if the canary is still there; if not, print "Stack Overflow!" and kill the thread.
+1

File to change: user/uthread.c
void thread_create(void (*func)()) {
  /* ... find FREE thread ... */
  t->state = RUNNABLE; [cite: 208]
  // RE-APPLICATION: Place canary at the base (lowest address) of the stack
  *(uint64*)(t->stack) = 0xDEADBEEF; 
  
  t->context.ra = (uint64)func; [cite: 214, 217]
  t->context.sp = (uint64)t->stack + STACK_SIZE; [cite: 216, 223]
}

void thread_schedule(void) {
  // RE-APPLICATION: Safety Check
  if (*(uint64*)(current_thread->stack) != 0xDEADBEEF) {
      printf("Panic: Thread %d Stack Overflow!\n", current_thread - all_thread);
      current_thread->state = FREE; // Kill it
  }
  // ... rest of schedule logic ... [cite: 208]
}
uthread Mechanic: "The Thread Execution Counter"

The Mechanic: Updating thread metadata during a context switch.
The Quiz Twist: Add a field run_count to struct thread. Every time thread_schedule selects a thread to run, increment its count. When a thread calls thread_yield, it should print how many times it has been scheduled so far.
+1

File to change: user/uthread.c
void thread_schedule(void) {
  // ... selection logic ...
  if (current_thread != next_thread) {
    // RE-APPLICATION: State auditing
    // Reasoning: Tracks how often the scheduler gives this thread a turn.
    next_thread->run_count++; 
    
    next_thread->state = RUNNING;
    thread_switch((uint64)&current_thread->context, (uint64)&next_thread->context);
  }
}

uthread Mechanic: "The Thread State Watchdog"

The Mechanic: Managing thread contexts and states .
The Quiz Twist: Add a field run_time to struct thread. Every time thread_yield is called, increment this counter. In thread_schedule, if a threads run_time exceeds a threshold, change its state to FREE (essentially "killing" a thread that runs for too long).

File to change: user/uthread.c
void thread_yield(void) {
  // RE-APPLICATION: Lifecycle management
  current_thread->run_time++;
  if (current_thread->run_time > 100) {
      current_thread->state = FREE; // Kill thread for exceeding "CPU quota"
  } else {
      current_thread->state = RUNNABLE;
  }
  thread_schedule();
}


uthread Mechanic: "The Stack Boundary Guard"

The Mechanic: Ensuring stack integrity during context switching.
The Quiz Twist: Place a "Canary" value (e.g., 0xAAAA) at the very bottom of the stack array. In thread_schedule, check if this value is still there. If it is changed, it means the thread overflowed its stack; print an error and kill it.

File to change: user/uthread.c
void thread_create(void (*func)()) {
  /* ... find FREE thread ... */
  t->state = RUNNABLE;
  // RE-APPLICATION: Place canary at the base (index 0) of the stack
  *(int*)(t->stack) = 0xAAAA; 
  
  t->context.ra = (uint64)func; [cite: 217]
  t->context.sp = (uint64)t->stack + STACK_SIZE; [cite: 223]
}

void thread_schedule(void) {
  // RE-APPLICATION: Integrity Check
  if (*(int*)(current_thread->stack) != 0xAAAA) {
      printf("Panic: Thread %d Stack Overflow detected!\n", current_thread - all_thread);
      current_thread->state = FREE; 
  }
  /* ... rest of scheduling logic ... */
}

Task: uthread — The "Stack Limit" Watchdog
To prevent silent memory corruption, this twist adds a safety check to the scheduler. You must add a stack_limit field to the thread struct. During every thread_schedule cycle, the program must calculate the current distance between the saved sp and the end of the stack; if it is less than 100 bytes, mark the thread as FREE and skip it. This requires calculating offsets between the context.sp and the stack array boundary.
+4

modified / created file 1: user/uthread.c
void thread_schedule(void) {
  struct thread *t, *next_thread = 0;
  
  // Find next runnable thread logic...
  
  if (next_thread) {
    // RE-APPLICATION: Stack Safety Check
    // Reasoning: Ensure the stack pointer hasn't grown too close to the array limit.
    uint64 stack_bottom = (uint64)next_thread->stack;
    if (next_thread->context.sp < (stack_bottom + 100)) {
        printf("Panic: Thread %d stack too low! Killing.\n", next_thread - all_thread);
        next_thread->state = FREE;
        thread_schedule(); // Re-schedule
        return;
    }
    // ... continue with thread_switch ...
  }
}
uthread Mechanic: "The Thread Stack Canary"

The Mechanic: Monitoring stack boundaries during context switches.
The Quiz Twist: To detect stack overflow, place a "canary" value (0xDEADBEEF) at the very bottom of each threads stack. In thread_schedule, check if the canary is still there; if not, print "Stack Overflow!" and kill the thread.
+3

File to change: user/uthread.c
void thread_create(void (*func)()) {
  /* ... find FREE thread ... [cite: 206] */
  t->state = RUNNABLE;
  // RE-APPLICATION: Place canary at the base (lowest address) of the stack 
  *(uint64*)(t->stack) = 0xDEADBEEF; 
  
  t->context.ra = (uint64)func; [cite: 214, 217]
  t->context.sp = (uint64)t->stack + STACK_SIZE; [cite: 214, 216, 223]
}

void thread_schedule(void) {
  // RE-APPLICATION: Safety Check 
  if (*(uint64*)(current_thread->stack) != 0xDEADBEEF) {
      printf("Panic: Thread %d Stack Overflow!\n", current_thread - all_thread);
      current_thread->state = FREE; // Kill it
  }
  // ... rest of schedule logic ... 
}

uthread Mechanic: "The Thread Execution Counter"

The Mechanic: Updating thread metadata during a context switch.
The Quiz Twist: Add a field run_count to struct thread. Every time thread_schedule selects a thread to run, increment its count. When a thread calls thread_yield, it should print how many times it has been scheduled.
+1

File to change: user/uthread.c
void thread_schedule(void) {
  // ... selection logic ... [cite: 208]
  if (current_thread != next_thread) {
    // RE-APPLICATION: State auditing
    // Reasoning: Tracks how often the scheduler gives this thread a turn.
    next_thread->run_count++; 
    
    next_thread->state = RUNNING;
    thread_switch((uint64)&current_thread->context, (uint64)&next_thread->context); [cite: 232]
  }
}

uthread Mechanic: "The Thread Execution Counter"

The Mechanic: Updating thread metadata during a context switch.
The Quiz Twist: Add a field run_count to struct thread. Every time thread_schedule selects a thread to run, increment its count. When a thread calls thread_yield, it should print how many times it has been scheduled.
+3

File to change: user/uthread.c
void thread_schedule(void) {
  struct thread *t, *next_thread = 0;
  // ... selection logic ... 
  if (current_thread != next_thread) {
    // RE-APPLICATION: State auditing
    // Reasoning: Tracks how often the scheduler gives this thread a turn. 
    next_thread->run_count++; 
    
    next_thread->state = RUNNING;
    thread_switch((uint64)&current_thread->context, (uint64)&next_thread->context); // [cite: 232]
  }
}
uthread Mechanic: "The Thread Priority Swap"
The Mechanic: Managing thread metadata and scheduler selection.
The Quiz Twist: Add a priority field to struct thread. Every time thread_yield is called, decrement the current threads priority. The scheduler must always pick the runnable thread with the highest remaining priority.

File to change: user/uthread.c
void thread_yield(void) {
  // RE-APPLICATION: Dynamic priority adjustment
  if (current_thread->priority > 0) current_thread->priority--;
  
  current_thread->state = RUNNABLE;
  thread_schedule();
}

void thread_schedule(void) {
  struct thread *t, *best = 0;
  for (t = all_thread; t < all_thread + MAX_THREAD; t++) {
    if (t->state == RUNNABLE) {
      if (!best || t->priority > best->priority) best = t;
    }
  }
  // ... perform switch to best ...
}

uthread Mechanic: "The Thread Affinity Check"
Mechanic: Context switching and thread metadata management.
The Quiz Twist: Add a field cpu_id to struct thread. Every time thread_schedule picks a thread, update this field with a "Round ID" (an incrementing global counter). When a thread calls thread_yield, it should print the Round ID of its last run.

File to change: user/uthread.c
int global_round = 0;

void thread_schedule(void) {
  // ... selection logic ...
  if (current_thread != next_thread) {
    // RE-APPLICATION: Tracking scheduling "generations"
    next_thread->last_round = global_round++; 
    
    next_thread->state = RUNNING;
    thread_switch((uint64)&current_thread->context, (uint64)&next_thread->context);
  }
}

uthread Mechanic: "The Thread Execution Watchdog"
The Mechanic: Managing thread contexts and return addresses.
The Quiz Twist: Every thread must execute exactly once and then be automatically set to FREE. Modify thread_schedule so that after a thread is switched away from, it can never be selected again.

File to change: user/uthread.c
void thread_schedule(void) {
  // ... selection logic ...
  if (current_thread != next_thread) {
    // RE-APPLICATION: One-shot execution policy
    // Reasoning: Setting state to FREE prevents the scheduler from picking it again.
    if (current_thread->state == RUNNING) {
        current_thread->state = FREE; 
    }
    
    next_thread->state = RUNNING;
    thread_switch((uint64)&current_thread->context, (uint64)&next_thread->context);
  }
}

uthread Mechanic: "The Thread Execution Watchdog"
The Mechanic: Managing thread metadata and scheduling states.
The Quiz Twist: Every thread must execute exactly once and then be automatically set to FREE. Once thread_switch returns to the scheduler from a thread that was just RUNNING, that threads state must be changed.

File to change: user/uthread.c
void thread_schedule(void) {
  // ... selection logic ...
  if (current_thread != next_thread) {
    // RE-APPLICATION: One-shot execution policy
    // Reasoning: Setting state to FREE prevents the scheduler from picking it again.
    if (current_thread->state == RUNNING) {
        current_thread->state = FREE; 
    }
    
    next_thread->state = RUNNING;
    thread_switch((uint64)&current_thread->context, (uint64)&next_thread->context);
  }
}

uthread Mechanic: "The Thread Switch Watchdog"
The Mechanic: Managing thread metadata and scheduler selection.
The Quiz Twist: Every thread must execute exactly once and then be automatically set to FREE. Once thread_switch returns to the scheduler from a thread that was just RUNNING, that threads state must be changed to prevent it from running again.

File to change: user/uthread.c
void thread_schedule(void) {
  // ... selection logic ...
  if (current_thread != next_thread) {
    // RE-APPLICATION: One-shot execution policy
    // Reasoning: Setting state to FREE prevents the scheduler from picking it again.
    if (current_thread->state == RUNNING) {
        current_thread->state = FREE; 
    }
    
    next_thread->state = RUNNING;
    thread_switch((uint64)&current_thread->context, (uint64)&next_thread->context);
  }
}
uthread Mechanic: "The Thread Dependency"
The Mechanic: Conditional thread scheduling using state management.
The Quiz Twist: Thread 2 cannot run until Thread 1 has finished (state is FREE). The scheduler must skip Thread 2 even if it is RUNNABLE as long as all_thread[1].state != FREE.

File to change: user/uthread.c
void thread_schedule(void) {
  struct thread *t;
  /* ... loop logic ... */
  int idx = t - all_thread;
  
  // THE TWIST: Dependency Logic
  if (idx == 2 && all_thread[1].state != FREE) {
      continue; // Skip Thread 2 because Thread 1 is still alive
  }
  
  if (t->state == RUNNABLE) {
      next_thread = t;
      break;
  }
}


uthread Mechanic: "The Thread Execution Watchdog"
Mechanic: Context switching and thread metadata management.
The Quiz Twist: Every thread must execute exactly once and then be automatically set to FREE. Modify thread_schedule so that after a thread is switched away from, it can never be selected again.

File to change: user/uthread.c
void thread_schedule(void) {
  // ... selection logic ...
  if (current_thread != next_thread) {
    // RE-APPLICATION: One-shot execution policy
    // Reasoning: Setting state to FREE prevents the scheduler from picking it again.
    if (current_thread->state == RUNNING) {
        current_thread->state = FREE; 
    }
    
    next_thread->state = RUNNING;
    thread_switch((uint64)&current_thread->context, (uint64)&next_thread->context);
  }
}

uthread Mechanic: "The Thread Stack Canary"
The Mechanic: Monitoring stack boundaries during context switches.
The Quiz Twist: To detect stack overflow, place a "canary" value (0xDEADBEEF) at the very bottom (lowest address) of each threads stack. In thread_schedule, check if the canary is still there; if not, print "Stack Overflow!" and kill the thread.

File to change: user/uthread.c
void thread_create(void (*func)()) {
  /* ... find FREE thread ... */
  t->state = RUNNABLE;
  // RE-APPLICATION: Place canary at the base (index 0) of the stack
  *(uint64*)(t->stack) = 0xDEADBEEF; 
  
  t->context.ra = (uint64)func;
  t->context.sp = (uint64)t->stack + STACK_SIZE;
}

void thread_schedule(void) {
  // RE-APPLICATION: Safety Check
  if (*(uint64*)(current_thread->stack) != 0xDEADBEEF) {
      printf("Panic: Thread %d Stack Overflow!\n", current_thread - all_thread);
      current_thread->state = FREE; // Kill it
  }
  // ... rest of schedule logic ...
}


uthread Twist: "The Context Integrity Checksum"
The Twist: To prevent memory corruption, add a checksum field to the thread_context. Every time a thread yields, calculate a simple XOR of its sp and ra. Before the scheduler restores a thread, it must verify this checksum. If it fails, the kernel should panic .
The Steps:
Structure Update: Add uint64 checksum to thread_context.
Yield Update: Calculate the checksum before calling thread_switch.
Restore Update: Add a check in thread_schedule.
Files to change: user/uthread.c
// Inside thread_yield
current_thread->context.checksum = current_thread->context.sp ^ current_thread->context.ra;
thread_schedule();

// Inside thread_schedule, before thread_switch
if (next_thread->context.checksum != (next_thread->context.sp ^ next_thread->context.ra)) {
    printf("Panic: Context corruption detected!\n");
    exit(-1);
}


uthread Twist: "The One-Shot Thread"
The Twist: Every thread created must execute exactly once and then be automatically set to FREE. Once the scheduler switches back to the main scheduler from a thread that was just RUNNING, that threads state must be changed .
The Steps:
Scheduler State Management: Modify the selection logic in thread_schedule.
Logic: Catch the thread right after the thread_switch returns .
Files to change: user/uthread.c
The Solution:
void thread_schedule(void) {
  // ... selection logic ...
  if (current_thread != next_thread) {
    struct thread *old = current_thread;
    current_thread = next_thread;
    next_thread->state = RUNNING;
    thread_switch((uint64)&old->context, (uint64)&current_thread->context);
    
    // THE TWIST: Clean up after return
    // Reasoning: Setting to FREE ensures it is skipped in the next schedule loop.
    old->state = FREE; 
  }
}

uthread Twist: "The Thread Execution Counter"
The Twist: Add a field run_count to struct thread. Every time thread_schedule selects a thread to run, increment its count. When a thread calls thread_yield, it must print how many times it has been scheduled so far .
The Steps:
Struct proc.h: Add int run_count to struct thread .
Scheduler Update: Increment the count for the next_thread before the switch .
Files to change: user/uthread.c
The Solution:

void thread_schedule(void) {
  // ... selection logic ...
  if (current_thread != next_thread) {
    next_thread->run_count++; // RE-APPLICATION: State auditing
    // ... switch logic ... [cite: 265]
  }
}

void thread_yield(void) {
  printf("Thread %d yielding. Total runs: %d\n", 
          current_thread - all_thread, current_thread->run_count);
  current_thread->state = RUNNABLE;
  thread_schedule();
}


uthread Twist: "The Thread Stack Canary"
The Twist: To detect stack overflow, place a canary value (0xDEADBEEF) at the very bottom of each threads stack. During thread_schedule, check if the canary is still there; if not, print "Stack Overflow!" and kill the thread .

The Steps:
Initialize: Place the canary at the base address of the stack in thread_create .
Audit: Add the verification logic in the scheduler loop.
Files to change: user/uthread.c
void thread_create(void (*func)()) {
  /* ... find FREE thread ... */
  t->state = RUNNABLE;
  // RE-APPLICATION: Set canary at lowest stack address
  *(uint64*)(t->stack) = 0xDEADBEEF; 
  
  t->context.ra = (uint64)func;
  t->context.sp = (uint64)t->stack + STACK_SIZE;
}

void thread_schedule(void) {
  // ... loop logic ...
  if (*(uint64*)(current_thread->stack) != 0xDEADBEEF) {
      printf("Panic: Thread %d Stack Overflow!\n", current_thread - all_thread);
      current_thread->state = FREE; // Terminate
      thread_schedule();
      return;
  }
}

uthread Twist: "The Scheduler Barrier"
The Twist: Implement a "Round-Robin Observer". In thread_schedule, you must skip any thread that has an even index in the all_thread array, effectively only scheduling threads 1 and 3. This tests your ability to manipulate the selection logic within the circular loop .
The Steps:
Index Calculation: Use pointer subtraction (t - all_thread) to find the thread index.
Selection Logic: Add a parity check (index % 2 != 0) inside the RUNNABLE check loop.
Files to change: user/uthread.c
void thread_schedule(void) {
  struct thread *t;
  // ... circular loop ...
  int idx = t - all_thread; // RE-APPLICATION: Index Filter
  if (t->state == RUNNABLE && (idx % 2 != 0)) {
    next_thread = t;
    break;
  }
}

uthread Twist: "The Scheduler Parity Observer"
The Twist: Implement an index-based filter. In thread_schedule, you must skip any thread that has an even index in the all_thread array, effectively only scheduling threads 1 and 3 .
The Steps:
Index Calculation: Use pointer subtraction (t - all_thread) to find the thread index.
Selection Logic: Add a parity check (index % 2 != 0) inside the RUNNABLE check loop.
Files to change: user/uthread.c
void thread_schedule(void) {
  struct thread *t;
  // ... circular loop ...
  int idx = t - all_thread; // RE-APPLICATION: Index Filter
  if (t->state == RUNNABLE && (idx % 2 != 0)) {
    next_thread = t;
    break;
  }
}

uthread Twist: "The Thread Execution Watchdog"
The Twist: Add a max_yields limit to each thread. Every time a thread calls thread_yield, increment a counter. If a thread exceeds 50 yields, the scheduler must change its state to FREE (essentially "starving" it out for performance reasons) .

Files to change: user/uthread.c

// Inside thread_yield
current_thread->yield_count++;
if (current_thread->yield_count > 50) {
    current_thread->state = FREE; // RE-APPLICATION: Auto-termination
} else {
    current_thread->state = RUNNABLE;
}
thread_schedule();














🛠️ Variation 4: "Snapshot" Summation (Locks)

The Lab: Protect individual buckets during insertion .
The Quiz Twist: Create a function to sum all values in the table. To get an accurate sum while other threads are writing, you must lock every bucket first.
File to change: notxv6/ph-with-mutex-locks.c
int sum_all_values() {
  int total = 0;

  // THE TWIST: Multi-locking
  // Reasoning: We must lock EVERY bucket to prevent threads from changing data 
  // while we are counting, ensuring a consistent "snapshot."
  for (int i = 0; i < NBUCKET; i++) {
    pthread_mutex_lock(&locks[i]);
  }

  for (int i = 0; i < NBUCKET; i++) {
    struct entry *e;
    for (e = table[i]; e != 0; e = e->next) {
      total += e->value;
    }
  }

  // Release all locks after counting
  for (int i = 0; i < NBUCKET; i++) {
    pthread_mutex_unlock(&locks[i]);
  }
  return total;
}


"Snapshot" Hash Summation

The Lab: Protect individual buckets during insertion .
The Quiz Twist: Implement a function to sum all values in the table. To be safe while other threads are inserting, you must lock all buckets first.

Solution (notxv6/ph-with-mutex-locks.c):
int sum_all_buckets() {
  int total = 0;

  // THE TWIST: Multi-locking
  // Reasoning: Locking all buckets ensures a consistent "snapshot" of the data. [cite: 793]
  for (int i = 0; i < NBUCKET; i++) {
    pthread_mutex_lock(&locks[i]);
  }

  for (int i = 0; i < NBUCKET; i++) {
    struct entry *e;
    for (e = table[i]; e != 0; e = e->next) {
      total += e->value;
    }
  }

  // Release all locks [cite: 778]
  for (int i = 0; i < NBUCKET; i++) {
    pthread_mutex_unlock(&locks[i]);
  }
  return total;
}

PH Mechanic: "The Global Counter Lock"

Mechanic: Using mutexes to prevent race conditions during concurrent access.
Re-Application: Track the total number of collisions (when two keys end up in the same bucket). Use a separate lock for this global counter.
+1

File to change: notxv6/ph-with-mutex-locks.c
int collisions = 0;
pthread_mutex_t collision_lock = PTHREAD_MUTEX_INITIALIZER; // [cite: 745]

static void put(int key, int value) {
  int i = key % NBUCKET; // [cite: 696]
  pthread_mutex_lock(&locks[i]); // [cite: 758]

  struct entry *e = 0;
  for (e = table[i]; e != 0; e = e->next) {
    if (e->key == key) break;
  }
  
  if (e) {
    e->value = value;
  } else {
    // RE-APPLICATION: If table[i] is NOT empty, it's a collision
    if (table[i] != 0) {
        pthread_mutex_lock(&collision_lock);
        collisions++;
        pthread_mutex_unlock(&collision_lock);
    }
    insert(key, value, &table[i], table[i]); // [cite: 735]
  }
  pthread_mutex_unlock(&locks[i]); // [cite: 746]
}

PH Mechanic: "The Sequential Lock" (Deadlock Prevention)

The Mechanic: Using bucket-specific mutexes .
The Re-Application: Implement a "Move" operation that moves a key from one bucket to another. To prevent deadlock, you must always lock the bucket with the lower index first.

File to change: notxv6/ph-with-mutex-locks.c
void move_key(int key, int old_bucket, int new_bucket) {
  // RE-APPLICATION: Deadlock prevention via lock ordering
  // Reasoning: If two threads try to lock buckets 1 and 2 in opposite orders, they hang.
  int first = (old_bucket < new_bucket) ? old_bucket : new_bucket;
  int second = (old_bucket < new_bucket) ? new_bucket : old_bucket;

  pthread_mutex_lock(&locks[first]);
  pthread_mutex_lock(&locks[second]);

  // ... move logic ...

  pthread_mutex_unlock(&locks[second]);
  pthread_mutex_unlock(&locks[first]);
}


The Mechanic: Using bucket-specific mutexes to prevent race conditions .
The Re-Application: Introduce a "Read-Only" mode. If a global flag readonly is set to 1, all put() operations should immediately return without doing anything, while get() operations continue to work without needing a lock.

File to change: notxv6/ph-with-mutex-locks.c
int readonly = 0; // Global flag

static void put(int key, int value) {
  // RE-APPLICATION: Mode-based branching
  // Reasoning: If in readonly mode, we prevent writes entirely.
  if (readonly) return; 

  int i = key % NBUCKET;
  pthread_mutex_lock(&locks[i]); // [cite: 745]
  // ... insert logic ...
  pthread_mutex_unlock(&locks[i]); // [cite: 746]
}

PH Mechanic: "The Fail-Fast Lock" (TryLock)

Mechanic: Using non-blocking synchronization.
Re-Application: If a bucket is already locked, the thread should not wait. Instead, it should increment a busy_count and move on to the next task.
+1

File to change: notxv6/ph-with-mutex-locks.c
int busy_count = 0;
pthread_mutex_t count_lock = PTHREAD_MUTEX_INITIALIZER;

static void put(int key, int value) {
  int i = key % NBUCKET;
  
  // RE-APPLICATION: Non-blocking lock attempt
  if (pthread_mutex_trylock(&locks[i]) != 0) {
      pthread_mutex_lock(&count_lock);
      busy_count++;
      pthread_mutex_unlock(&count_lock);
      return; // Skip this update if busy
  }

  insert(key, value, &table[i], table[i]);
  pthread_mutex_unlock(&locks[i]);
}


PH Mechanic: "The Multi-Bucket Transfer"Mechanic: Using lock ordering to avoid deadlocks when accessing multiple buckets.
Re-Application: Implement a move_item function that moves a key from bucket $A$ to bucket $B$. To be safe, you must lock the bucket with the lower index first.File to change: notxv6/ph-with-mutex-locks.c
void move_item(int key, int bucket_a, int bucket_b) {
  // RE-APPLICATION: Deadlock prevention via lock ordering
  // Reasoning: Always lock the smaller index first.
  int first = (bucket_a < bucket_b) ? bucket_a : bucket_b;
  int second = (bucket_a < bucket_b) ? bucket_b : bucket_a;

  pthread_mutex_lock(&locks[first]); [cite: 357]
  pthread_mutex_lock(&locks[second]);

  // ... perform move logic ...

  pthread_mutex_unlock(&locks[second]); [cite: 358]
  pthread_mutex_unlock(&locks[first]);
}

PH Mechanic: "The Deterministic Deadlock Avoidance"

The Mechanic: Using locks to protect shared data .
Re-Application: Implement a "Swap" function that moves data between two buckets. To prevent deadlock, you must always lock the bucket with the lower array index first.

File to change: notxv6/ph-with-mutex-locks.c
void swap_buckets(int idx1, int idx2) {
  // RE-APPLICATION: Consistent lock ordering
  // Reasoning: If threads lock buckets in different orders, they may wait forever for each other.
  int first = (idx1 < idx2) ? idx1 : idx2;
  int second = (idx1 < idx2) ? idx2 : idx1;

  pthread_mutex_lock(&locks[first]); [cite: 357]
  pthread_mutex_lock(&locks[second]); [cite: 357]

  // ... perform swap logic ...

  pthread_mutex_unlock(&locks[second]); [cite: 358]
  pthread_mutex_unlock(&locks[first]); [cite: 358]
}


PH Mechanic: "The Recursive Lock Check"

Mechanic: Using mutexes to prevent concurrent data corruption.
Re-Application: Implement a get_and_delete function. Since this involves both a search and a modification, you must ensure the bucket remains locked for the entire duration of both operations to prevent a "lost update."
+1

File to change: notxv6/ph-with-mutex-locks.c
static void get_and_delete(int key) {
    int i = key % NBUCKET; [cite: 308]
    pthread_mutex_lock(&locks[i]); // Mechanic: Lock the bucket [cite: 389]

    // RE-APPLICATION: Atomic "Read-then-Write"
    // Reasoning: If we unlocked between 'get' and 'delete', 
    // another thread could modify the list in between.
    struct entry *e = get_internal(key); 
    if (e) {
        delete_internal(e);
        printf("Deleted key %d\n", key);
    }

    pthread_mutex_unlock(&locks[i]); // Mechanic: Unlock [cite: 389]
}
PH Mechanic: "The Sequential Lock" (Deadlock Prevention)

The Mechanic: Using bucket-specific mutexes to allow parallel work .
Re-Application: Implement a "Swap" function that moves data between two buckets. To prevent deadlock, you must always lock the bucket with the lower array index first.

File to change: notxv6/ph-with-mutex-locks.c
void swap_items(int idx1, int idx2) {
  // RE-APPLICATION: Lock ordering for safety
  // Reasoning: If threads lock in different orders, they may wait forever for each other.
  int first = (idx1 < idx2) ? idx1 : idx2;
  int second = (idx1 < idx2) ? idx2 : idx1;

  pthread_mutex_lock(&locks[first]);  // Lock smaller index first
  pthread_mutex_lock(&locks[second]); // Lock larger index second

  // ... swap logic ...

  pthread_mutex_unlock(&locks[second]);
  pthread_mutex_unlock(&locks[first]);
}

PH (Hash) Mechanic: "The Write-Through Lock"

The Mechanic: Using mutexes to protect global shared state .
The Quiz Twist: Maintain a global "High Water Mark" max_value seen in the table. Whenever a thread performs a put(), it must check if the new value is higher than max_value and update it safely.

File to change: notxv6/ph-with-mutex-locks.c
int max_value = 0;
pthread_mutex_t max_lock = PTHREAD_MUTEX_INITIALIZER;

static void put(int key, int value) {
  int i = key % NBUCKET;
  pthread_mutex_lock(&locks[i]);
  insert(key, value, &table[i], table[i]);
  pthread_mutex_unlock(&locks[i]);

  // RE-APPLICATION: Global State Synchronization
  // Reasoning: We use a separate lock to avoid blocking other bucket insertions.
  pthread_mutex_lock(&max_lock);
  if (value > max_value) {
      max_value = value;
  }
  pthread_mutex_unlock(&max_lock);
}

PH Mechanic: "The Maximum Value Lock"

The Mechanic: Using a global mutex to protect a shared variable across multiple threads .
The Quiz Twist: Maintain a global variable highest_key. Every time a put() occurs, check if the new key is higher than the current highest_key and update it safely using a separate global lock.

File to change: notxv6/ph-with-mutex-locks.c
int highest_key = 0;
pthread_mutex_t high_lock = PTHREAD_MUTEX_INITIALIZER; // Step: Global lock [cite: 357]

static void put(int key, int value) {
    int i = key % NBUCKET; [cite: 308]
    pthread_mutex_lock(&locks[i]); [cite: 389]
    insert(key, value, &table[i], table[i]); 
    pthread_mutex_unlock(&locks[i]); [cite: 389]

    // THE TWIST: Atomic global update
    // Reasoning: Use a separate lock so we don't slow down bucket insertions.
    pthread_mutex_lock(&high_lock); [cite: 357]
    if (key > highest_key) {
        highest_key = key;
    }
    pthread_mutex_unlock(&high_lock); [cite: 358]
}
PH (Hash) Mechanic: "The Lock-Free Read Filter"

The Mechanic: Using bucket-level mutexes to prevent race conditions .
The Quiz Twist: Implement a "Bulk Delete" that only deletes keys with even values. To do this safely while others are writing, you must use the correct lock for each bucket before scanning.

File to change: notxv6/ph-with-mutex-locks.c
void delete_even_values() {
  for (int i = 0; i < NBUCKET; i++) {
    // RE-APPLICATION: Selective atomic modification
    // Reasoning: You must lock the bucket BEFORE scanning the list[cite: 389].
    pthread_mutex_lock(&locks[i]); 
    
    struct entry **pp = &table[i];
    while (*pp) {
      if ((*pp)->value % 2 == 0) {
        struct entry *to_free = *pp;
        *pp = (*pp)->next;
        free(to_free);
      } else {
        pp = &((*pp)->next);
      }
    }
    pthread_mutex_unlock(&locks[i]); [cite: 389]
  }
}

PH Mechanic: "The Atomic Read-Modify-Write"

The Mechanic: Using bucket locks to ensure consistency .
The Re-Application: Implement an increment_value(key) function. It must find the key and add 1 to its value. You must hold the lock for the entire read-and-update process to prevent a race condition.

File to change: notxv6/ph-with-mutex-locks.c
void increment_value(int key) {
  int i = key % NBUCKET; [cite: 308]
  pthread_mutex_lock(&locks[i]); [cite: 357]

  // RE-APPLICATION: Critical Section management
  // Reasoning: Holding the lock across both get and update ensures no one 
  // modifies the value between us reading it and writing it back.
  struct entry *e = get_internal(key);
  if (e) {
      e->value = e->value + 1;
  }

  pthread_mutex_unlock(&locks[i]); [cite: 358]
}

PH (Hash) Mechanic: "The Recursive Lock Check"

The Mechanic: Protecting a multi-step operation with a single lock.
The Quiz Twist: Implement a get_and_delete(key) function. To prevent a "lost update," you must ensure the bucket is locked for the entire duration of both finding the item and removing it.
+1

File to change: notxv6/ph-with-mutex-locks.c
void get_and_delete(int key) {
  int i = key % NBUCKET;
  pthread_mutex_lock(&locks[i]); // Step: Lock once for the whole operation [cite: 357]

  // RE-APPLICATION: Atomic "Check-then-Act"
  // Reasoning: If we unlocked between 'get' and 'delete', 
  // another thread could insert a different value at that key.
  struct entry *e = get_internal(key);
  if (e) {
      delete_internal(key); 
  }

  pthread_mutex_unlock(&locks[i]); // Step: Unlock only after modification is done [cite: 358]
}

PH (Hash) Mechanic: "The Lock-Free Probe"

The Mechanic: Using pthread_mutex_trylock for non-blocking operations.
The Quiz Twist: Implement a function try_put(key, value). If the buckets lock is already held by another thread, do not wait. Instead, increment a global skip_count and return immediately.
+1

File to change: notxv6/ph-with-mutex-locks.c
int skip_count = 0;
pthread_mutex_t skip_lock = PTHREAD_MUTEX_INITIALIZER;

static void try_put(int key, int value) {
  int i = key % NBUCKET; // [cite: 308]
  
  // RE-APPLICATION: Non-blocking synchronization
  // Reasoning: trylock returns non-zero if the lock is already busy.
  if (pthread_mutex_trylock(&locks[i]) != 0) {
      pthread_mutex_lock(&skip_lock);
      skip_count++;
      pthread_mutex_unlock(&skip_lock);
      return; // Give up and skip
  }

  insert(key, value, &table[i], table[i]); [cite: 347]
  pthread_mutex_unlock(&locks[i]); // [cite: 358]
}

PH Mechanic: "The Atomic Read-Modify-Write"

The Mechanic: Holding a lock across multiple operations to ensure atomicity .
The Quiz Twist: Implement an increment_value(key) function. It must find the key, read its current value, add 1, and update it. You must hold the bucket lock for the entire duration to prevent other threads from changing the value in between.
+1

File to change: notxv6/ph-with-mutex-locks.c
void increment_value(int key) {
    int i = key % NBUCKET; [cite: 308]
    pthread_mutex_lock(&locks[i]); // Step: Lock the bucket [cite: 357]

    // RE-APPLICATION: Critical Section Management
    // Reasoning: If we unlock between 'get' and 'update', 
    // we could overwrite someone else's update. [cite: 348-350]
    struct entry *e = get_internal(key); 
    if (e) {
        e->value = e->value + 1;
    }

    pthread_mutex_unlock(&locks[i]); // Step: Unlock only after modification [cite: 358]
}
Task: PH — The "Atomic Item Move" (Cross-Bucket Swap)This synchronization task requires moving a key-value pair from bucket $A$ to bucket $B$ atomically. To prevent deadlocks, you must implement a strict lock-ordering rule: always acquire the mutex for the bucket with the lower index first . This tests your ability to manage multiple pthread_mutex_t instances simultaneously .+4modified / created file 1: notxv6/ph-with-mutex-locks.c
void move_entry(int key, int from_bucket, int to_bucket) {
    // RE-APPLICATION: Deadlock-Free Multi-Locking
    // Logic: Always lock the smaller index first.
    int lock1 = (from_bucket < to_bucket) ? from_bucket : to_bucket;
    int lock2 = (from_bucket < to_bucket) ? to_bucket : from_bucket;

    pthread_mutex_lock(&locks[lock1]);
    if (lock1 != lock2) pthread_mutex_lock(&locks[lock2]);

    // Step: Find in from_bucket, remove, and insert into to_bucket
    struct entry *e = get_internal(key, from_bucket);
    if (e) {
        detach_from_list(e, &table[from_bucket]);
        e->next = table[to_bucket];
        table[to_bucket] = e;
    }

    if (lock1 != lock2) pthread_mutex_unlock(&locks[lock2]);
    pthread_mutex_unlock(&locks[lock1]);
}

PH Mechanic: "The Atomic Read-Modify-Write"

The Mechanic: Using bucket locks to ensure consistency .
The Re-Application: Implement an increment_value(key) function. It must find the key, read its current value, add 1, and update it. You must hold the lock for the entire read-and-update process to prevent a race condition .
+3

File to change: notxv6/ph-with-mutex-locks.c
void increment_value(int key) {
  int i = key % NBUCKET; [cite: 308]
  pthread_mutex_lock(&locks[i]); [cite: 357, 389]

  // RE-APPLICATION: Critical Section management [cite: 351]
  // Reasoning: Holding the lock across both get and update ensures no one 
  // modifies the value between us reading it and writing it back. 
  struct entry *e = get_internal(key); [cite: 313]
  if (e) {
      e->value = e->value + 1; [cite: 311]
  }

  pthread_mutex_unlock(&locks[i]); [cite: 358, 389]
}
PH (Hash) Mechanic: "The Maximum Value Lock"

The Mechanic: Using a global mutex to protect a shared variable across multiple threads .
The Quiz Twist: Maintain a global variable highest_key. Every time a put() occurs, check if the new key is higher than the current highest_key and update it safely using a separate global lock.

File to change: notxv6/ph-with-mutex-locks.c
int highest_key = 0;
pthread_mutex_t high_lock = PTHREAD_MUTEX_INITIALIZER; // Step: Global lock [cite: 357]

static void put(int key, int value) {
    int i = key % NBUCKET; [cite: 308]
    pthread_mutex_lock(&locks[i]); [cite: 357]
    insert(key, value, &table[i], table[i]); 
    pthread_mutex_unlock(&locks[i]); [cite: 358]

    // THE TWIST: Atomic global update
    // Reasoning: Use a separate lock so we don't slow down bucket insertions [cite: 403-404].
    pthread_mutex_lock(&high_lock);
    if (key > highest_key) {
        highest_key = key;
    }
    pthread_mutex_unlock(&high_lock);
}

PH (Hash) Mechanic: "The Recursive Lock Check"

The Mechanic: Protecting a multi-step operation with a single lock.
The Quiz Twist: Implement a get_and_delete(key) function. To prevent a "lost update," you must ensure the bucket is locked for the entire duration of both finding the item and removing it.
+4

File to change: notxv6/ph-with-mutex-locks.c
void get_and_delete(int key) {
  int i = key % NBUCKET; // [cite: 308]
  pthread_mutex_lock(&locks[i]); // Step: Lock once for the whole operation [cite: 357, 389]

  // RE-APPLICATION: Atomic "Check-then-Act"
  // Reasoning: If we unlocked between 'get' and 'delete', another thread could modify it. [cite: 348, 350]
  struct entry *e = get_internal(key);
  if (e) {
      delete_internal(key); 
  }

  pthread_mutex_unlock(&locks[i]); // Step: Unlock only after modification is done [cite: 358, 389]
}


PH Mechanic: "The Conditional Multi-Lock"
The Mechanic: Using bucket locks and ordering to prevent deadlocks.
The Quiz Twist: Implement transfer(key, from_b, to_b). You must ensure the item exists in from_b before locking to_b. If it doesnt exist, release the first lock and exit immediately.

File to change: notxv6/ph-with-mutex-locks.c
void transfer(int key, int from, int to) {
    // RE-APPLICATION: Early-exit locking logic
    pthread_mutex_lock(&locks[from]);
    if (get_internal(key, from) == 0) {
        pthread_mutex_unlock(&locks[from]);
        return; 
    }
    
    // Step: We have the item, now get the second lock safely
    pthread_mutex_lock(&locks[to]); 
    // ... move logic ...
    pthread_mutex_unlock(&locks[to]);
    pthread_mutex_unlock(&locks[from]);
}

PH (Hash) Mechanic: "The Bucket Balancing Lock"
The Mechanic: Using bucket-specific mutexes to prevent race conditions.
The Quiz Twist: Implement a get_bucket_size(int i) function. To get an accurate count of a bucket while other threads are inserting, you must lock that specific bucket and its neighbor (to ensure a consistent snapshot during a potential rebalance/move).

File to change: notxv6/ph-with-mutex-locks.c
int get_bucket_size(int i) {
  int count = 0;
  // RE-APPLICATION: Ordered multi-bucket locking
  int first = (i < (i+1)%NBUCKET) ? i : (i+1)%NBUCKET;
  int second = (i < (i+1)%NBUCKET) ? (i+1)%NBUCKET : i;

  pthread_mutex_lock(&locks[first]);
  pthread_mutex_lock(&locks[second]);

  for (struct entry *e = table[i]; e; e = e->next) count++;

  pthread_mutex_unlock(&locks[second]);
  pthread_mutex_unlock(&locks[first]);
  return count;
}

PH (Hash) Mechanic: "The Fail-Fast TryLock"
Mechanic: Using pthread_mutex_trylock for non-blocking synchronization.
The Quiz Twist: Implement put_if_free(key, value). If the bucket lock is already held by another thread, do not wait. Instead, increment a global busy_count and return immediately.

File to change: notxv6/ph-with-mutex-locks.c
int busy_count = 0;
pthread_mutex_t busy_lock = PTHREAD_MUTEX_INITIALIZER;

static void put_if_free(int key, int value) {
  int i = key % NBUCKET;
  
  // RE-APPLICATION: Non-blocking attempt
  // Reasoning: trylock returns 0 only if it successfully gets the lock.
  if (pthread_mutex_trylock(&locks[i]) != 0) {
      pthread_mutex_lock(&busy_lock);
      busy_count++;
      pthread_mutex_unlock(&busy_lock);
      return; 
  }

  insert(key, value, &table[i], table[i]);
  pthread_mutex_unlock(&locks[i]);
}

PH (Hash) Mechanic: "The Lock-Ordering Transfer"
The Mechanic: Atomic multi-bucket operations with deadlock prevention.
The Quiz Twist: Implement move_key(key, src_b, dst_b). You must move the key from the source bucket to the destination bucket. To prevent deadlock, you must lock the bucket with the higher index first. (Note: This is the reverse of the standard rule, but still prevents deadlock as long as everyone follows it).

File to change: notxv6/ph-with-mutex-locks.c
void move_key(int key, int src, int dst) {
    // RE-APPLICATION: Consistent (but reversed) lock ordering
    // Reasoning: Deadlock is prevented by ANY consistent order, even "higher first".
    int first = (src > dst) ? src : dst;
    int second = (src > dst) ? dst : src;

    pthread_mutex_lock(&locks[first]);
    pthread_mutex_lock(&locks[second]);

    // ... move logic (detach from src, attach to dst) ...

    pthread_mutex_unlock(&locks[second]);
    pthread_mutex_unlock(&locks[first]);
}


PH (Hash) Mechanic: "The Lock-Free Read"
The Mechanic: Using bucket-specific mutexes to allow parallel operations.
The Quiz Twist: Implement a "Read-Only" mode. If a global flag readonly is set to 1, all put() operations should immediately return without doing anything, while get() operations continue to work without needing to acquire any locks.

File to change: notxv6/ph-with-mutex-locks.c
int readonly = 0; // Global flag

static void put(int key, int value) {
  // RE-APPLICATION: Mode-based branching
  // Reasoning: If in readonly mode, we prevent writes entirely.
  if (readonly) return; 

  int i = key % NBUCKET;
  pthread_mutex_lock(&locks[i]);
  // ... insert logic ...
  pthread_mutex_unlock(&locks[i]);
}

PH (Hash) Mechanic: "The Item Transfer Lock"
The Mechanic: Using bucket-specific mutexes to allow parallel operations.
The Quiz Twist: Implement move_entry(key, src, dst). You must move the key from the source bucket to the destination bucket. To prevent deadlock, you must always lock the bucket with the lower index first.

File to change: notxv6/ph-with-mutex-locks.c
void move_entry(int key, int src, int dst) {
    // RE-APPLICATION: Consistent lock ordering
    // Reasoning: Deadlock is prevented by acquiring the smaller index lock first.
    int first = (src < dst) ? src : dst;
    int second = (src < dst) ? dst : src;

    pthread_mutex_lock(&locks[first]);
    pthread_mutex_lock(&locks[second]);

    // ... move logic (detach from src, attach to dst) ...

    pthread_mutex_unlock(&locks[second]);
    pthread_mutex_unlock(&locks[first]);
}

PH (Hash) Mechanic: "The Bucket-Specific Move"
The Mechanic: Lock ordering to prevent deadlocks during multi-bucket operations.
The Quiz Twist: Implement move_all_items(int src_bucket, int dst_bucket). You must move every item from the source linked list to the destination linked list. You must hold both locks for the entire duration of the move to prevent other threads from seeing a partial state.

File to change: notxv6/ph-with-mutex-locks.c
void move_all_items(int src, int dst) {
    // RE-APPLICATION: Ordered locking
    int first = (src < dst) ? src : dst;
    int second = (src < dst) ? dst : src;

    pthread_mutex_lock(&locks[first]);
    pthread_mutex_lock(&locks[second]);

    // Attach src list to the front of dst list
    struct entry *e = table[src];
    if (e) {
        struct entry *last = e;
        while (last->next) last = last->next;
        last->next = table[dst];
        table[dst] = e;
        table[src] = 0; // Empty the source
    }

    pthread_mutex_unlock(&locks[second]);
    pthread_mutex_unlock(&locks[first]);
}


PH (Hash) Mechanic: "The Bucket-Specific Move"
Mechanic: Ordered multi-bucket locking to prevent deadlocks.
The Quiz Twist: Implement move_all_items(int src_bucket, int dst_bucket). You must move every item from the source linked list to the destination linked list. You must hold both locks for the entire duration of the move.

File to change: notxv6/ph-with-mutex-locks.c
void move_all_items(int src, int dst) {
    // RE-APPLICATION: Ordered locking
    // Reasoning: Deadlock is prevented by acquiring the smaller index first.
    int first = (src < dst) ? src : dst;
    int second = (src < dst) ? dst : src;

    pthread_mutex_lock(&locks[first]);
    pthread_mutex_lock(&locks[second]);

    // Attach src list to the front of dst list
    struct entry *e = table[src];
    if (e) {
        struct entry *last = e;
        while (last->next) last = last->next;
        last->next = table[dst];
        table[dst] = e;
        table[src] = 0; // Empty source
    }

    pthread_mutex_unlock(&locks[second]);
    pthread_mutex_unlock(&locks[first]);
}

PH Mechanic: "The Maximum Value Lock"
The Mechanic: Using a global mutex to protect a shared variable across multiple threads.
The Quiz Twist: Maintain a global variable highest_key. Every time a put() occurs, check if the new key is higher than the current highest_key and update it safely using a separate global lock.

File to change: notxv6/ph-with-mutex-locks.c
int highest_key = 0;
pthread_mutex_t high_lock = PTHREAD_MUTEX_INITIALIZER;

static void put(int key, int value) {
    int i = key % NBUCKET;
    pthread_mutex_lock(&locks[i]);
    insert(key, value, &table[i], table[i]); 
    pthread_mutex_unlock(&locks[i]);

    // THE TWIST: Atomic global update
    // Reasoning: Use a separate lock so we don't slow down bucket insertions.
    pthread_mutex_lock(&high_lock);
    if (key > highest_key) {
        highest_key = key;
    }
    pthread_mutex_unlock(&high_lock);
}

PH Twist: "The Maximum Value Guard"
The Twist: Maintain a global variable highest_value. Every time a thread performs a put(), it must check if the new value is higher than the current highest_value and update it safely using a separate global lock.

The Steps:
Synchronization: Use a separate mutex for the global variable so you dont slow down bucket-level operations (fine-grained locking).
Atomic Update: Ensure the check-and-update is inside the critical section.
Files to change: notxv6/ph-with-mutex-locks.c
int highest_value = 0;
pthread_mutex_t high_lock = PTHREAD_MUTEX_INITIALIZER; // Separate lock [cite: 414, 428]

static void put(int key, int value) {
    int i = key % NBUCKET;
    pthread_mutex_lock(&locks[i]); // Bucket lock [cite: 414]
    insert(key, value, &table[i], table[i]); 
    pthread_mutex_unlock(&locks[i]);

    // Twist: Atomic global update
    pthread_mutex_lock(&high_lock);
    if (value > highest_value) {
        highest_value = value;
    }
    pthread_mutex_unlock(&high_lock);
}



PH Twist: "The Atomic Item-Swap"
The Twist: Implement a function swap_keys(int k1, int k2). You must safely swap the values of these two keys. If they are in different buckets, you must lock both buckets simultaneously without causing a deadlock.

The Steps:
Lock Ordering: Always lock the bucket with the lower index first to prevent circular waiting .
Fine-Grained Locking: Only hold the locks for the duration of the swap .
Files to change: notxv6/ph-with-mutex-locks.c

void swap_keys(int k1, int k2) {
    int b1 = k1 % NBUCKET;
    int b2 = k2 % NBUCKET;

    // THE TWIST: Deadlock-free multi-locking [cite: 357, 403]
    int first = (b1 < b2) ? b1 : b2;
    int second = (b1 < b2) ? b2 : b1;

    pthread_mutex_lock(&locks[first]);
    if (b1 != b2) pthread_mutex_lock(&locks[second]);

    // Perform the value swap logic...
    struct entry *e1 = get(k1);
    struct entry *e2 = get(k2);
    if(e1 && e2) { int tmp = e1->value; e1->value = e2->value; e2->value = tmp; }

    if (b1 != b2) pthread_mutex_unlock(&locks[second]);
    pthread_mutex_unlock(&locks[first]);
}


PH Twist: "The Lock-Ordering Transfer"
The Twist: Implement move_key(key, src_b, dst_b). You must move the key from the source bucket to the destination bucket. To prevent deadlock, you must lock the bucket with the higher index first .
The Steps:
Lock Comparison: Compare src_b and dst_b indices.
Atomic Move: Ensure the item is detached and re-attached while holding both locks .
Files to change: notxv6/ph-with-mutex-locks.c
The Solution:
void move_key(int key, int src, int dst) {
    // RE-APPLICATION: Reversed ordered locking
    int first = (src > dst) ? src : dst;
    int second = (src > dst) ? dst : src;

    pthread_mutex_lock(&locks[first]); // Lock higher index first
    pthread_mutex_lock(&locks[second]);

    // ... move logic (detach from src list, attach to dst list) ...

    pthread_mutex_unlock(&locks[second]);
    pthread_mutex_unlock(&locks[first]);
}

H Twist: "The Global Cooldown Lock"
The Twist: Implement a "Global Cooldown" for the hash table. If any thread is currently performing an insertion, all other threads must wait 100 milliseconds before they can even try to access their specific bucket locks. This tests the implementation of a coarse-grained bottleneck over a fine-grained system .
The Steps:
Synchronization: Use a separate global mutex and a sleep or usleep call.
Logic: Ensure the cooldown lock is acquired before the bucket lock .
Files to change: notxv6/ph-with-mutex-locks.c
The Solution
pthread_mutex_t global_cooldown = PTHREAD_MUTEX_INITIALIZER;

static void put(int key, int value) {
  // THE TWIST: Coarse-grained bottleneck
  pthread_mutex_lock(&global_cooldown);
  usleep(100000); // 100ms penalty
  pthread_mutex_unlock(&global_cooldown);

  int i = key % NBUCKET;
  pthread_mutex_lock(&locks[i]); // Standard bucket lock
  insert(key, value, &table[i], table[i]);
  pthread_mutex_unlock(&locks[i]);
}

PH Twist: "The Global Count Synchronization"
The Twist: Add a global variable total_inserts that tracks how many items were successfully put into the table. You must ensure it is thread-safe using a separate lock so it doesnt slow down the bucket-specific operations .
The Steps:
Synchronization: Declare and initialize a separate pthread_mutex_t count_lock.
Atomic Increment: Wrap the total_inserts++ logic in the new lock.
Files to change: notxv6/ph-with-mutex-locks.c
int total_inserts = 0;
pthread_mutex_t count_lock = PTHREAD_MUTEX_INITIALIZER;

static void put(int key, int value) {
    // ... bucket locking and insertion ...
    
    // THE TWIST: Atomic global increment
    pthread_mutex_lock(&count_lock);
    total_inserts++;
    pthread_mutex_unlock(&count_lock);
}

PH Twist: "The Per-Bucket Collision Counter"
The Twist: Add an array int collisions[NBUCKET] to track how many times a key was updated in each bucket. You must protect this array using the existing bucket locks to avoid adding new performance bottlenecks .
The Steps:
Data Structure: Declare the global collisions array.
Atomic Logic: In put(), if the key is found, increment the count for that bucket while the lock is already held.
Files to change: notxv6/ph-with-mutex-locks.c

int collisions[NBUCKET] = {0};

static void put(int key, int value) {
    int i = key % NBUCKET;
    pthread_mutex_lock(&locks[i]);
    
    struct entry *e = get_internal(key, i);
    if (e) {
        e->value = value;
        collisions[i]++; // TWIST: Atomic increment within existing lock
    } else {
        insert(key, value, &table[i], table[i]);
    }
    pthread_mutex_unlock(&locks[i]);
}

PH Twist: "The Atomic Multi-Bucket Aggregator"
The Twist: Implement get_two_bucket_sum(int b1, int b2). You must return the total count of items in both buckets. To prevent another thread from moving an item between b1 and b2 while you are counting (which would result in double-counting or missing an item), you must lock both buckets using the lower-index-first rule .
Files to change: notxv6/ph-with-mutex-locks.c
The Solution:
int get_two_bucket_sum(int b1, int b2) {
    int count = 0;
    // THE TWIST: Consistent locking for accuracy
    int first = (b1 < b2) ? b1 : b2;
    int second = (b1 < b2) ? b2 : b1;

    pthread_mutex_lock(&locks[first]);
    if (b1 != b2) pthread_mutex_lock(&locks[second]);

    // ... counting logic for both buckets ...

    if (b1 != b2) pthread_mutex_unlock(&locks[second]);
    pthread_mutex_unlock(&locks[first]);
    return count;
}










//Checklist
"The 7-File Rule": For any syscall task, you will touch syscall.h, syscall.c, sysproc.c, proc.h, user.h, usys.pl, and the Makefile .
Stack Pointer Setup: Always point sp to stack + STACK_SIZE in thread_create .
Inheritance: If the new feature (like a monitor mask) must persist through a fork(), you must update kernel/proc.c

The Fork Copy: If the quiz asks for a new process feature (like a "tracing limit" or "owner ID"), you must copy that variable in kernel/proc.c inside the fork() function .
The argint() Rule: Whenever a new syscall needs a number from the user, you use argint(0, &val).
The Stack Top: In thread_create, the stack pointer must be stack + STACK_SIZE.


Th argint Fetch: Always remember that argint(0, &x) pulls the first argument from the users register/stack into the kernel.
The usys.pl Entry: If you dont add your syscall to this Perl script, your user program will fail to compile with an "undefined reference" error .
The sp Calculation: In thread_create, the stack pointer MUST be t->stack + STACK_SIZE. If you use t->stack, you are pointing to the bottom, and the first function call will write into invalid memory

Stack Math: In thread_create, the sp must be t->stack + STACK_SIZE.Registers: $a7$ is the syscall number; $a0$ is the return value.+1Pipe EOF: 
If the handshake hangs, verify that the writing process closed its write-end of the pipe so the reader receives an EOF.

Symptom,Probable Cause,Tactical Fix
handshake hangs,Write-end of pipe is still open in the reader process.,Ensure both Parent and Child close the ends they aren't using.
sniffer prints garbage,Loop went past the allocated sbrk memory.,Always use (4096 * 32) - marker_length in your for loop limit.
monitor prints wrong PID,fork() didn't copy the monitor_mask.,Check kernel/proc.c and ensure np->monitor_mask = p->monitor_mask; is there.
uthread traps/crashes,"sp points to the bottom of the stack, not the top.",Ensure sp = stack + STACK_SIZE. It grows downward.
ph is slow / same time,You used one global lock instead of the locks[NBUCKET] array.,"Ensure you are locking &locks[i], where i = key % NBUCKET."

If you see scause 0x000000000000000c (Instruction Page Fault) in uthread, it almost always means your ra (Return Address) was set to an invalid memory address.

Fix: Check that t->context.ra = (uint64)func; is actually receiving a valid function pointer.

Would you like me to generate a "Cheat Sheet" of common RISC-V registers (like s0-s11, a0-a7) and their specific roles in your labs? Conclude by letting me know.

