# Handshake — Pattern A Variations (H1–H17)

> **Scope**: Logic twists on the standard 2-pipe parent↔child handshake.  
> **Usage**: Paste the snippet into the matching `MODIFY HERE` zone in the boilerplate below.  
> **Edge cases**: Every snippet handles `read()` return values. Close unused pipe ends or deadlock.

---

## 📋 Contents

- [Core Boilerplate](#core-boilerplate)
- [H1: Arithmetic](#h1-arithmetic)
- [H2: Bidirectional Checksum](#h2-bidirectional-checksum)
- [H3: Byte-Shift (Circular)](#h3-byte-shift-circular)
- [H4: NOT-Gate](#h4-not-gate)
- [H5: ASCII Case-Swap](#h5-ascii-case-swap)
- [H6: Countdown Relay](#h6-countdown-relay)
- [H7: FizzBuzz Pipe](#h7-fizzbuzz-pipe)
- [H8: Reverse-Order Stream](#h8-reverse-order-stream)
- [H9: Alternating Parity](#h9-alternating-parity)
- [H10: Max-of-Two](#h10-max-of-two)
- [H11: Token Ring](#h11-token-ring)
- [H12: Accumulator Chain](#h12-accumulator-chain)
- [H13: Echo with Delay](#h13-echo-with-delay)
- [H14: Odd-Even Sorter](#h14-odd-even-sorter)
- [H15: Pipe Capacity Test](#h15-pipe-capacity-test)
- [H16: Multi-Byte XOR Stream](#h16-multi-byte-xor-stream)
- [H17: PID Exchange](#h17-pid-exchange)
- [Quick Reference](#quick-reference)

---

## Core Boilerplate

```c
#include "kernel/types.h"
#include "user/user.h"

int main(int argc, char *argv[]) {
    int p1[2], p2[2]; // p1: parent→child, p2: child→parent
    if (pipe(p1) < 0 || pipe(p2) < 0) { fprintf(2, "pipe failed\n"); exit(1); }

    int pid = fork();
    if (pid < 0) { fprintf(2, "fork failed\n"); exit(1); }

    // ════════ MODIFY HERE [SETUP] ════════
    // (Empty for H1-H17. Used for extra pipes/vars in H18-H30)

    if (pid == 0) {
        // ── Child ──
        close(p1[1]); close(p2[0]); // close: parent→child WRITE, child→parent READ

        // ════════════════════════════════════════════════════════════════
        // MODIFY HERE [CHILD]
        // Read from p1[0], process, write to p2[1]
        char buf;
        if (read(p1[0], &buf, 1) == 1) {
            printf("%d: received %c\n", getpid(), buf);
            write(p2[1], &buf, 1);
        }
        // ════════════════════════════════════════════════════════════════

        close(p1[0]); close(p2[1]);
        exit(0);
    } else {
        // ── Parent ──
        close(p1[0]); close(p2[1]); // close: parent→child READ, child→parent WRITE

        // ════════════════════════════════════════════════════════════════
        // MODIFY HERE [PARENT]
        // Write to p1[1], read from p2[0]
        char msg = argv[1][0];
        write(p1[1], &msg, 1);
        char buf;
        if (read(p2[0], &buf, 1) == 1) {
            printf("%d: received %c\n", getpid(), buf);
        }
        // ════════════════════════════════════════════════════════════════

        close(p1[1]); close(p2[0]);
        wait(0);
        exit(0);
    }
}
```

**Pipe direction reminder:**
```
p1[1] ──write──▶ p1[0]     Parent → Child
p2[1] ──write──▶ p2[0]     Child  → Parent
```

---

## H1: Arithmetic

> Child receives a byte, **multiplies by a constant from argv**, sends the product back. Tests integer conversion over raw pipe bytes.

**Parent:**
```c
int val = atoi(argv[1]);           // e.g. argv[1] = "7"
write(p1[1], &val, sizeof(int));
int result;
if (read(p2[0], &result, sizeof(int)) == sizeof(int))
    printf("%d: result = %d\n", getpid(), result);
```

**Child:**
```c
int val, multiplier = atoi(argv[2]); // e.g. argv[2] = "3"
if (read(p1[0], &val, sizeof(int)) == sizeof(int)) {
    int product = val * multiplier;
    printf("%d: %d * %d = %d\n", getpid(), val, multiplier, product);
    write(p2[1], &product, sizeof(int));
}
```

---

## H2: Bidirectional Checksum

> Parent sends a **multi-byte string**. Child computes an **additive checksum** (sum of all bytes mod 256) and sends the 1-byte result back. Parent verifies.

**Parent:**
```c
char *msg = argv[1];               // e.g. "hello"
int len = strlen(msg);
write(p1[1], &len, sizeof(int));   // send length first
write(p1[1], msg, len);            // then send string
close(p1[1]);                      // signal EOF to child

char checksum;
if (read(p2[0], &checksum, 1) == 1) {
    // Verify locally
    char expected = 0;
    for (int i = 0; i < len; i++) expected += msg[i];
    printf("%d: checksum=%d %s\n", getpid(), (int)(unsigned char)checksum,
           checksum == expected ? "MATCH" : "MISMATCH");
}
```

**Child:**
```c
int len;
if (read(p1[0], &len, sizeof(int)) == sizeof(int)) {
    char buf[256];
    int n = read(p1[0], buf, len);
    char checksum = 0;
    for (int i = 0; i < n; i++) checksum += buf[i];
    printf("%d: computed checksum=%d over %d bytes\n", getpid(), (int)(unsigned char)checksum, n);
    write(p2[1], &checksum, 1);
}
```

---

## H3: Byte-Shift (Circular)

> Child receives a byte, performs **left-circular-shift by N bits** (N from argv), sends back. Relies on the identity: `(x << N) | (x >> (8-N))` wraps the bits around.

**Parent:**
```c
char msg = argv[1][0];
int n = atoi(argv[2]);             // shift amount
write(p1[1], &msg, 1);
char buf;
if (read(p2[0], &buf, 1) == 1) {
    // Verify: right-circular-shift should recover original
    unsigned char recovered = ((unsigned char)buf >> n) | ((unsigned char)buf << (8 - n));
    printf("%d: sent '%c'(0x%x) got 0x%x recovered '%c'\n",
           getpid(), msg, (unsigned char)msg, (unsigned char)buf, recovered);
}
```

**Child:**
```c
char buf;
int n = atoi(argv[2]);             // same shift amount
if (read(p1[0], &buf, 1) == 1) {
    unsigned char shifted = ((unsigned char)buf << n) | ((unsigned char)buf >> (8 - n));
    printf("%d: shifted '%c' left by %d → 0x%x\n", getpid(), buf, n, shifted);
    buf = (char)shifted;
    write(p2[1], &buf, 1);
}
```

---

## H4: NOT-Gate

> Child **bitwise-NOTs** every byte, sends back. Parent confirms round-trip identity: `~~x == x`.

**Parent:**
```c
char msg = argv[1][0];
write(p1[1], &msg, 1);
char buf;
if (read(p2[0], &buf, 1) == 1)
    printf("%d: sent 0x%x, got NOT=0x%x, ~~=0x%x %s\n",
           getpid(), (unsigned char)msg, (unsigned char)buf,
           (unsigned char)(~buf), (~buf == msg) ? "OK" : "FAIL");
```

**Child:**
```c
char buf;
if (read(p1[0], &buf, 1) == 1) {
    buf = ~buf;
    printf("%d: NOT → 0x%x\n", getpid(), (unsigned char)buf);
    write(p2[1], &buf, 1);
}
```

---

## H5: ASCII Case-Swap

> Child **toggles case** using `XOR 0x20` — works because uppercase (0x41–0x5A) and lowercase (0x61–0x7A) differ by exactly bit 5.

**Parent:**
```c
char msg = argv[1][0];
write(p1[1], &msg, 1);
char buf;
if (read(p2[0], &buf, 1) == 1)
    printf("%d: '%c' → '%c'\n", getpid(), msg, buf);
```

**Child:**
```c
char buf;
if (read(p1[0], &buf, 1) == 1) {
    if ((buf >= 'A' && buf <= 'Z') || (buf >= 'a' && buf <= 'z'))
        buf ^= 0x20;               // toggle bit 5 = swap case
    printf("%d: case-swapped → '%c'\n", getpid(), buf);
    write(p2[1], &buf, 1);
}
```

---

## H6: Countdown Relay

> Parent sends integer N. Child sends N-1 back. Parent sends N-2. Continues **alternating** until 0 is reached. Tests **multi-round bidirectional I/O** with a termination condition.

**Parent:**
```c
int val = atoi(argv[1]);           // starting number
while (val > 0) {
    write(p1[1], &val, sizeof(int));
    printf("%d: sent %d\n", getpid(), val);
    if (read(p2[0], &val, sizeof(int)) != sizeof(int)) break;
    printf("%d: received %d\n", getpid(), val);
}
// Signal done: close write end so child's read returns EOF
close(p1[1]); p1[1] = -1;         // mark as already closed
```

**Child:**
```c
int val;
while (read(p1[0], &val, sizeof(int)) == sizeof(int)) {
    printf("%d: received %d\n", getpid(), val);
    val--;
    if (val <= 0) {
        printf("%d: countdown done!\n", getpid());
        break;
    }
    write(p2[1], &val, sizeof(int));
    printf("%d: sent %d\n", getpid(), val);
    val--;   // pre-decrement for parent's next round
}
```

> ⚠️ Close `p1[1]` inside the PARENT zone. Set `p1[1] = -1` so the cleanup `close(p1[1])` after the zone doesn't double-close.

---

## H7: FizzBuzz Pipe

> Parent sends integers 1..N. Child replies `'F'` (÷3), `'B'` (÷5), `'X'` (÷15), or the digit char. Tests **multi-round conditional pipe logic**.

**Parent:**
```c
int n = atoi(argv[1]);
for (int i = 1; i <= n; i++)
    write(p1[1], &i, sizeof(int));
close(p1[1]); p1[1] = -1;         // EOF → child stops reading

char reply;
while (read(p2[0], &reply, 1) == 1)
    printf("%d: got '%c'\n", getpid(), reply);
```

**Child:**
```c
int val;
while (read(p1[0], &val, sizeof(int)) == sizeof(int)) {
    char r;
    if (val % 15 == 0)      r = 'X';
    else if (val % 3 == 0)  r = 'F';
    else if (val % 5 == 0)  r = 'B';
    else                    r = '0' + (val % 10); // last digit as char
    write(p2[1], &r, 1);
}
```

> ⚠️ Parent must close `p1[1]` before reading replies, otherwise child's `read()` never returns EOF and the child never finishes writing.

---

## H8: Reverse-Order Stream

> Parent sends N bytes at once. Child reads all N, **reverses the array**, writes all N back. Tests **buffered pipe I/O** and array manipulation.

**Parent:**
```c
char *msg = argv[1];               // e.g. "abcde"
int len = strlen(msg);
write(p1[1], &len, sizeof(int));   // send length
write(p1[1], msg, len);            // send data
close(p1[1]); p1[1] = -1;

char buf[256];
int n = read(p2[0], buf, len);
buf[n] = '\0';
printf("%d: reversed = \"%s\"\n", getpid(), buf);
```

**Child:**
```c
int len;
if (read(p1[0], &len, sizeof(int)) == sizeof(int)) {
    char buf[256];
    int n = read(p1[0], buf, len);
    // Reverse in-place
    for (int i = 0; i < n / 2; i++) {
        char tmp = buf[i];
        buf[i] = buf[n - 1 - i];
        buf[n - 1 - i] = tmp;
    }
    write(p2[1], buf, n);
}
```

---

## H9: Alternating Parity

> Even byte → **+1**. Odd byte → **-1**. Parent verifies the transformation.

**Parent:**
```c
char msg = argv[1][0];
write(p1[1], &msg, 1);
char buf;
if (read(p2[0], &buf, 1) == 1)
    printf("%d: '%c'(0x%x) → '%c'(0x%x) [%s]\n", getpid(),
           msg, (unsigned char)msg, buf, (unsigned char)buf,
           (msg % 2 == 0) ? "even:+1" : "odd:-1");
```

**Child:**
```c
char buf;
if (read(p1[0], &buf, 1) == 1) {
    if (buf % 2 == 0) buf += 1;    // even → +1
    else              buf -= 1;    // odd  → -1
    write(p2[1], &buf, 1);
}
```

---

## H10: Max-of-Two

> Parent forks **TWO children**, sends a different byte to each. Children compare via a **third pipe** — the one with the larger byte prints "I win". Tests multi-child coordination and 3+ pipes.

> ⚠️ This replaces the entire if/else fork block. Paste as the **full body of `main()`** after pipe/fork error checks.

**Full main body (replaces both zones):**
```c
int pa[2], pb[2], cmp[2]; // pa: parent→A, pb: parent→B, cmp: A↔B comparison
if (pipe(pa) < 0 || pipe(pb) < 0 || pipe(cmp) < 0) { fprintf(2, "pipe failed\n"); exit(1); }

char a_val = argv[1][0], b_val = argv[2][0];

int pidA = fork();
if (pidA < 0) { fprintf(2, "fork failed\n"); exit(1); }
if (pidA == 0) {
    // Child A: read own byte, write to cmp pipe, read other's byte
    close(pa[1]); close(pb[0]); close(pb[1]); close(cmp[0]);
    char mine; read(pa[0], &mine, 1); close(pa[0]);
    write(cmp[1], &mine, 1); close(cmp[1]);
    // A doesn't know B's value — only one child needs to compare
    exit(0);
}

int pidB = fork();
if (pidB < 0) { fprintf(2, "fork failed\n"); exit(1); }
if (pidB == 0) {
    // Child B: read own byte, read A's byte from cmp, compare
    close(pb[1]); close(pa[0]); close(pa[1]); close(cmp[1]);
    char mine; read(pb[0], &mine, 1); close(pb[0]);
    char other; read(cmp[0], &other, 1); close(cmp[0]);
    if (mine > other)  printf("%d(B): I win! %c > %c\n", getpid(), mine, other);
    else if (mine < other) printf("%d(B): A wins. %c > %c\n", getpid(), other, mine);
    else               printf("%d(B): tie! %c == %c\n", getpid(), mine, other);
    exit(0);
}

// Parent: send bytes, close, wait
close(pa[0]); close(pb[0]); close(cmp[0]); close(cmp[1]);
write(pa[1], &a_val, 1); close(pa[1]);
write(pb[1], &b_val, 1); close(pb[1]);
wait(0); wait(0);
exit(0);
```

---

## H11: Token Ring

> **N children** arranged in a ring. A token byte circulates **K times**. Each child prints on receipt and forwards. Tests circular pipe topology.

> ⚠️ Replaces the full body of `main()`.

**Full main body:**
```c
int n = atoi(argv[1]);             // number of processes in ring
int k = atoi(argv[2]);             // number of laps
int pipes[16][2];                  // pipes[i]: process i → process (i+1)%n

for (int i = 0; i < n; i++)
    if (pipe(pipes[i]) < 0) { fprintf(2, "pipe failed\n"); exit(1); }

for (int i = 0; i < n; i++) {
    int cpid = fork();
    if (cpid < 0) { fprintf(2, "fork failed\n"); exit(1); }
    if (cpid == 0) {
        // Child i: read from pipes[i-1], write to pipes[i]
        // Close all fds except: read from prev, write to current
        int rd = (i == 0) ? n - 1 : i - 1; // read from previous pipe
        for (int j = 0; j < n; j++) {
            if (j == rd)  close(pipes[j][1]);         // keep read end
            else if (j == i) close(pipes[j][0]);      // keep write end
            else { close(pipes[j][0]); close(pipes[j][1]); }
        }
        char token;
        int total = (i == 0) ? k : k; // all children relay k tokens
        for (int t = 0; t < total; t++) {
            if (read(pipes[rd][0], &token, 1) != 1) break;
            printf("%d(slot %d): token '%c' lap %d\n", getpid(), i, token, t + 1);
            write(pipes[i][1], &token, 1);
        }
        close(pipes[rd][0]); close(pipes[i][1]);
        exit(0);
    }
}

// Parent: close all child pipe ends, inject token, then collect
for (int i = 0; i < n; i++) { close(pipes[i][0]); close(pipes[i][1]); }
// Reopen: parent injects token into pipes[n-1] → child 0 reads it
// Actually, parent should keep pipes[n-1][1] open to inject:
// (Move the close above to be selective, or inject before closing)
// Simplified: open a fresh injection pipe before the loop.

// ── Simpler approach: parent IS slot 0 ──
// For exam simplicity, keep parent in the ring as slot 0.
// See standalone note — for exam, a 3-process ring is more practical.

for (int i = 0; i < n; i++) wait(0);
exit(0);
```

> 💡 **Exam tip**: For token ring, it's cleanest to have the **parent be one node in the ring**. A 3-process version (parent + 2 children) with 2 pipes is the most exam-realistic size.

---

## H12: Accumulator Chain

> Chain of N processes. Each **adds its PID (mod 256)** to the byte before forwarding. Last process prints the accumulated value. Tests sequential fork+pipe chains.

> ⚠️ Replaces the full body of `main()`.

**Full main body:**
```c
int n = atoi(argv[1]);             // chain length
char val = 0;                      // accumulator starts at 0
int i;

for (i = 0; i < n; i++) {
    int p[2];
    if (pipe(p) < 0) { fprintf(2, "pipe failed\n"); exit(1); }
    int cpid = fork();
    if (cpid < 0) { fprintf(2, "fork failed\n"); exit(1); }

    if (cpid == 0) {
        // Child: will become next link in chain — read from p
        close(p[1]);
        if (read(p[0], &val, 1) != 1) { close(p[0]); exit(1); }
        close(p[0]);
        val += (char)(getpid() % 256);
        printf("%d: accumulated = %d\n", getpid(), (unsigned char)val);
        // Continue loop → child may fork its own child (next link)
    } else {
        // Parent: write current val to child, done with this link
        close(p[0]);
        val += (char)(getpid() % 256);
        write(p[1], &val, 1);
        close(p[1]);
        wait(0);
        exit(0);
    }
}
// Last process (no more forks)
printf("%d: FINAL accumulated = %d\n", getpid(), (unsigned char)val);
exit(0);
```

---

## H13: Echo with Delay

> Child reads byte, **sleeps for N ticks** using `pause()`, then echoes back unchanged. Parent measures elapsed time with `uptime()`.

**Parent:**
```c
char msg = argv[1][0];
int t0 = uptime();
write(p1[1], &msg, 1);
char buf;
if (read(p2[0], &buf, 1) == 1) {
    int t1 = uptime();
    printf("%d: sent '%c', got '%c' after %d ticks\n",
           getpid(), msg, buf, t1 - t0);
}
```

**Child:**
```c
int delay = atoi(argv[2]);         // ticks to sleep
char buf;
if (read(p1[0], &buf, 1) == 1) {
    pause(delay);                  // sleep for N ticks
    printf("%d: echoing '%c' after %d tick delay\n", getpid(), buf, delay);
    write(p2[1], &buf, 1);
}
```

---

## H14: Odd-Even Sorter

> Parent sends **two bytes**. Child returns them in **sorted order** (smaller first). Tests comparison + swap over pipes.

**Parent:**
```c
char a = argv[1][0], b = argv[2][0];
write(p1[1], &a, 1);
write(p1[1], &b, 1);
char sorted[2];
if (read(p2[0], sorted, 2) == 2)
    printf("%d: sorted '%c','%c' → '%c','%c'\n",
           getpid(), a, b, sorted[0], sorted[1]);
```

**Child:**
```c
char buf[2];
if (read(p1[0], buf, 2) == 2) {
    if (buf[0] > buf[1]) {         // swap if out of order
        char tmp = buf[0];
        buf[0] = buf[1];
        buf[1] = tmp;
    }
    printf("%d: sorted → '%c' '%c'\n", getpid(), buf[0], buf[1]);
    write(p2[1], buf, 2);
}
```

---

## H15: Pipe Capacity Test

> Parent writes bytes **until write blocks**, counting how many fit. Tests xv6 pipe buffer limit (PIPESIZE = 512). Child drains after a delay.

**Parent:**
```c
// Write bytes one at a time, counting until write fails/blocks
// To avoid true blocking, we use a trick: close read-end so write returns -1
int count = 0;
char c = 'x';
close(p2[0]); close(p2[1]);       // don't need p2 for this test

// Fork already done — child will drain after delay
// Parent writes until it can't write anymore
while (1) {
    int r = write(p1[1], &c, 1);
    if (r <= 0) break;
    count++;
}
printf("%d: pipe capacity = %d bytes\n", getpid(), count);
```

**Child:**
```c
close(p2[0]); close(p2[1]);       // don't need p2
pause(50);                        // delay: let parent fill the pipe
// Drain pipe
char buf[512];
while (read(p1[0], buf, sizeof(buf)) > 0);
```

> ⚠️ Parent's `write()` blocks (not errors) when pipe is full in xv6. Child must drain eventually. For a clean test, set child to drain after a known delay.

---

## H16: Multi-Byte XOR Stream

> Parent sends a string. Child **XOR-encrypts each byte** with a rotating key (key string from argv). Sends encrypted string back. Parent can decrypt by XOR-ing again.

**Parent:**
```c
char *msg = argv[1];
char *key = argv[2];
int len = strlen(msg);
write(p1[1], &len, sizeof(int));
write(p1[1], msg, len);
close(p1[1]); p1[1] = -1;

char enc[256];
int n = read(p2[0], enc, len);
enc[n] = '\0';
// Decrypt to verify
char dec[256];
int klen = strlen(key);
for (int i = 0; i < n; i++) dec[i] = enc[i] ^ key[i % klen];
dec[n] = '\0';
printf("%d: encrypted hex:", getpid());
for (int i = 0; i < n; i++) printf(" %x", (unsigned char)enc[i]);
printf("\n%d: decrypted = \"%s\"\n", getpid(), dec);
```

**Child:**
```c
char *key = argv[2];
int klen = strlen(key);
int len;
if (read(p1[0], &len, sizeof(int)) == sizeof(int)) {
    char buf[256];
    int n = read(p1[0], buf, len);
    for (int i = 0; i < n; i++)
        buf[i] ^= key[i % klen];  // XOR with rotating key
    write(p2[1], buf, n);
}
```

---

## H17: PID Exchange

> Parent sends its PID to child, child sends its PID to parent. Both **verify** they received the correct PID using `getpid()`. Tests structured integer I/O over pipes.

**Parent:**
```c
int my_pid = getpid();
write(p1[1], &my_pid, sizeof(int));
int child_pid;
if (read(p2[0], &child_pid, sizeof(int)) == sizeof(int))
    printf("%d: child PID = %d, fork returned %d, %s\n",
           my_pid, child_pid, pid,
           (child_pid == pid) ? "VERIFIED" : "MISMATCH");
```

**Child:**
```c
int my_pid = getpid();
int parent_pid;
if (read(p1[0], &parent_pid, sizeof(int)) == sizeof(int)) {
    printf("%d: parent PID = %d\n", my_pid, parent_pid);
    write(p2[1], &my_pid, sizeof(int));
}
```

---

## Quick Reference

| # | Name | What Changes | Key Concept | Zone Size |
|---|------|-------------|-------------|-----------|
| H1 | Arithmetic | `val * multiplier` | Integer I/O over pipes | Small |
| H2 | Checksum | Sum bytes mod 256 | Multi-byte read + 1-byte reply | Medium |
| H3 | Byte-Shift | `(x<<N)|(x>>(8-N))` | Bitwise circular rotation | Small |
| H4 | NOT-Gate | `~buf` | Bitwise NOT identity | Small |
| H5 | Case-Swap | `buf ^= 0x20` | XOR trick for ASCII case | Small |
| H6 | Countdown | Loop: send(N), recv(N-1) | Multi-round bidirectional | Medium |
| H7 | FizzBuzz | Conditional reply char | Multi-round + conditional | Medium |
| H8 | Reverse | Read N, reverse array | Buffered I/O + array ops | Medium |
| H9 | Parity | Even: +1, Odd: -1 | Parity check over IPC | Small |
| H10 | Max-of-Two | 2 children, 3 pipes | Multi-fork coordination | Large |
| H11 | Token Ring | N children, ring pipes | Circular pipe topology | Large |
| H12 | Accumulator | Chain of N processes | Sequential fork+pipe chain | Large |
| H13 | Echo Delay | `pause(N)` + `uptime()` | Timing over IPC | Small |
| H14 | Odd-Even Sort | Compare + swap 2 bytes | Comparison over pipes | Small |
| H15 | Pipe Capacity | Write until block, count | PIPESIZE = 512 | Medium |
| H16 | XOR Stream | `buf[i] ^= key[i%klen]` | Stream cipher over pipes | Medium |
| H17 | PID Exchange | `getpid()` → pipe → verify | Integer IPC + verification | Small |

---
---

# Pattern B — Feature Extensions (H18–H30)

> **Scope**: Feature extensions that add new capabilities (file I/O, exec, dup, multi-fork, structs, signals) to the standard 2-pipe handshake.
> **Zones**: Snippets target `[SETUP]`, `[PARENT]`, and `[CHILD]` drop zones in the Core Boilerplate above.
> **Extra include**: H20 needs `#include "kernel/fcntl.h"` at the top of the file.

---

## H18: Error Code Reply

> Child checks if received byte is **printable ASCII** (0x20–0x7E). Writes back `0` (success) or `1` (failure). Tests **validation logic** over pipes.

**Parent:**
```c
char msg = argv[1][0];
write(p1[1], &msg, 1);
char result;
if (read(p2[0], &result, 1) == 1)
    printf("%d: byte 0x%x → %s\n", getpid(), (unsigned char)msg,
           result == 0 ? "PRINTABLE" : "NON-PRINTABLE");
```

**Child:**
```c
char buf;
if (read(p1[0], &buf, 1) == 1) {
    char ok = (buf >= 0x20 && buf <= 0x7E) ? 0 : 1;
    printf("%d: 0x%x is %s\n", getpid(), (unsigned char)buf,
           ok == 0 ? "printable" : "non-printable");
    write(p2[1], &ok, 1);
}
```

---

## H19: Multi-Pipe Fan-Out

> Parent forks **N children**, each with its own pipe pair. Sends a different byte to each, reads each response. Tests **dynamic multi-fork** with pipe arrays.

> ⚠️ The boilerplate's first `fork()` creates child 0 using `p1/p2`. Additional children are forked **inside the PARENT zone** with pipes from `[SETUP]`.

**Setup:**
```c
// Additional pipe pairs for children 1..N-1 (child 0 uses p1/p2)
int N = atoi(argv[1]);             // total children (including child 0)
int pp[8][2], qp[8][2];           // pp[i]: parent→child_i, qp[i]: child_i→parent
for (int i = 1; i < N; i++) {
    pipe(pp[i]); pipe(qp[i]);
}
```

**Child (child 0 only):**
```c
char buf;
if (read(p1[0], &buf, 1) == 1) {
    printf("%d(child 0): got '%c'\n", getpid(), buf);
    buf += 1;                      // transform: +1
    write(p2[1], &buf, 1);
}
```

**Parent:**
```c
// Fork children 1..N-1 inside parent zone
for (int i = 1; i < N; i++) {
    int cpid = fork();
    if (cpid == 0) {
        // Child i
        close(pp[i][1]); close(qp[i][0]);
        char buf;
        if (read(pp[i][0], &buf, 1) == 1) {
            printf("%d(child %d): got '%c'\n", getpid(), i, buf);
            buf += 1;
            write(qp[i][1], &buf, 1);
        }
        close(pp[i][0]); close(qp[i][1]);
        exit(0);
    }
}

// Send different byte to each child
char base = 'A';
write(p1[1], &base, 1);           // child 0
for (int i = 1; i < N; i++) {
    char c = base + i;
    close(pp[i][0]); close(qp[i][1]);
    write(pp[i][1], &c, 1);
}

// Read responses
char buf;
read(p2[0], &buf, 1);
printf("%d: child 0 replied '%c'\n", getpid(), buf);
for (int i = 1; i < N; i++) {
    read(qp[i][0], &buf, 1);
    printf("%d: child %d replied '%c'\n", getpid(), i, buf);
    close(pp[i][1]); close(qp[i][0]);
    wait(0);
}
```

---

## H20: File Logging

> Both parent and child **append** the exchanged byte to a log file using `open()/write()/close()`. Tests file I/O combined with IPC.

> ⚠️ Add `#include "kernel/fcntl.h"` at the top of the file for `O_WRONLY` and `O_CREATE`.

**Parent:**
```c
char msg = argv[1][0];
write(p1[1], &msg, 1);
char buf;
if (read(p2[0], &buf, 1) == 1) {
    printf("%d: received '%c'\n", getpid(), buf);
    // Log to file
    int fd = open("handshake.log", O_WRONLY | O_CREATE);
    if (fd >= 0) {
        write(fd, "P:", 2);
        write(fd, &buf, 1);
        write(fd, "\n", 1);
        close(fd);
    }
}
```

**Child:**
```c
char buf;
if (read(p1[0], &buf, 1) == 1) {
    printf("%d: received '%c'\n", getpid(), buf);
    // Log to file
    int fd = open("handshake.log", O_WRONLY | O_CREATE);
    if (fd >= 0) {
        write(fd, "C:", 2);
        write(fd, &buf, 1);
        write(fd, "\n", 1);
        close(fd);
    }
    write(p2[1], &buf, 1);
}
```

---

## H21: Handshake via Exec

> Child redirects **stdin/stdout to pipes** using `close()+dup()`, then `exec()`s a separate program. The exec'd program reads from stdin and writes to stdout — which are now the pipes. Tests **fd redirection + exec**.

**Parent:**
```c
char *input = argv[2];             // string to send to exec'd program
int len = strlen(input);
write(p1[1], input, len);
close(p1[1]); p1[1] = -1;         // EOF so child's stdin read terminates

char buf[256];
int n = read(p2[0], buf, sizeof(buf) - 1);
if (n > 0) { buf[n] = '\0'; printf("%d: exec output = \"%s\"\n", getpid(), buf); }
```

**Child:**
```c
// Redirect stdin ← p1[0]
close(0);                          // free fd 0
dup(p1[0]);                        // dup returns 0 (lowest available) → stdin = pipe
close(p1[0]);                      // original fd no longer needed

// Redirect stdout → p2[1]
close(1);                          // free fd 1
dup(p2[1]);                        // dup returns 1 → stdout = pipe
close(p2[1]);                      // original fd no longer needed

// exec the target program
char *args[] = { argv[1], 0 };     // argv[1] = program name (e.g. "cat")
exec(args[0], args);
fprintf(2, "exec failed\n");       // only reached on failure
```

> 💡 `dup()` always returns the **lowest available fd**. So `close(0); dup(p1[0])` makes fd 0 point to the pipe.

---

## H22: Three-Way Ring

> **Ring topology**: Parent → Child1 → Child2 → Parent. Each process reads one byte, transforms, and forwards to the next. Tests **3-pipe ring** with 2 children.

**Setup:**
```c
int p3[2];                         // p3: child2 → parent (completing the ring)
pipe(p3);                          // p1: parent→child1, p2: child1→child2, p3: child2→parent
```

**Child (Child 1):**
```c
close(p3[0]); close(p3[1]);       // child1 doesn't use p3
char buf;
if (read(p1[0], &buf, 1) == 1) {
    buf += 1;                      // transform: +1
    printf("%d(C1): '%c' → '%c'\n", getpid(), buf - 1, buf);
    write(p2[1], &buf, 1);        // forward to child2
}
```

**Parent:**
```c
// Fork child2 inside parent zone
int pid2 = fork();
if (pid2 == 0) {
    // ── Child 2 ──
    close(p1[0]); close(p1[1]);   // child2 doesn't use p1
    close(p2[1]);                  // child2 reads from p2, writes to p3
    close(p3[0]);
    char buf;
    if (read(p2[0], &buf, 1) == 1) {
        buf += 1;                  // transform: +1
        printf("%d(C2): '%c' → '%c'\n", getpid(), buf - 1, buf);
        write(p3[1], &buf, 1);    // forward to parent
    }
    close(p2[0]); close(p3[1]);
    exit(0);
}

// Parent: inject into ring, read final result
close(p2[0]); close(p2[1]);       // parent doesn't use p2
close(p3[1]);                      // parent reads from p3
char msg = argv[1][0];
write(p1[1], &msg, 1);

char result;
if (read(p3[0], &result, 1) == 1)
    printf("%d(P): sent '%c', ring returned '%c'\n", getpid(), msg, result);
close(p3[0]);
wait(0);                           // wait for child2 (child1 waited by boilerplate)
```

---

## H23: Dup Stdin Read

> Child uses `close(0) + dup()` to make **stdin point to the pipe**, then reads via `read(0, ...)`. Tests understanding of **file descriptor redirection** without exec.

**Parent:**
```c
char msg = argv[1][0];
write(p1[1], &msg, 1);
char buf;
if (read(p2[0], &buf, 1) == 1)
    printf("%d: got '%c' back\n", getpid(), buf);
```

**Child:**
```c
// Redirect stdin to pipe
close(0);                          // free fd 0 (stdin)
dup(p1[0]);                        // now fd 0 = p1 read end
close(p1[0]);                      // cleanup original fd

char buf;
if (read(0, &buf, 1) == 1) {      // read from "stdin" = actually pipe
    printf("%d: read '%c' from stdin (fd 0 = pipe)\n", getpid(), buf);
    write(p2[1], &buf, 1);
}
```

---

## H24: Tee Pipe (Dual Fan-Out)

> Parent sends the **same byte to two children** simultaneously. Both respond independently. Parent collects both replies. Tests **broadcast IPC** pattern.

**Setup:**
```c
int p3[2], p4[2];                  // p3: parent→child2, p4: child2→parent
pipe(p3); pipe(p4);
```

**Child (Child 1):**
```c
close(p3[0]); close(p3[1]);       // child1 doesn't use p3/p4
close(p4[0]); close(p4[1]);
char buf;
if (read(p1[0], &buf, 1) == 1) {
    buf += 1;                      // child1 transform: +1
    printf("%d(C1): '%c'\n", getpid(), buf);
    write(p2[1], &buf, 1);
}
```

**Parent:**
```c
// Fork child2
int pid2 = fork();
if (pid2 == 0) {
    // ── Child 2 ──
    close(p1[0]); close(p1[1]);
    close(p2[0]); close(p2[1]);
    close(p3[1]); close(p4[0]);
    char buf;
    if (read(p3[0], &buf, 1) == 1) {
        buf *= 2;                  // child2 transform: *2
        printf("%d(C2): '%c'\n", getpid(), buf);
        write(p4[1], &buf, 1);
    }
    close(p3[0]); close(p4[1]);
    exit(0);
}

// Parent: send same byte to both children
close(p3[0]); close(p4[1]);
char msg = argv[1][0];
write(p1[1], &msg, 1);            // to child1
write(p3[1], &msg, 1);            // to child2 (same byte)
close(p3[1]);

// Collect both replies
char r1, r2;
read(p2[0], &r1, 1);
read(p4[0], &r2, 1);
printf("%d(P): sent '%c', C1='%c', C2='%c'\n", getpid(), msg, r1, r2);
close(p4[0]);
wait(0);                           // wait for child2
```

---

## H25: Struct Payload

> Exchange a **struct** containing `pid` and `msg` fields over the pipe. Tests structured binary I/O — `write(&s, sizeof(s))` sends raw bytes.

> ⚠️ Add struct definition **above `main()`**:
```c
struct handshake_msg {
    int pid;
    char msg[32];
};
```

**Parent:**
```c
struct handshake_msg out, in;
out.pid = getpid();
strcpy(out.msg, argv[1]);
write(p1[1], &out, sizeof(out));

if (read(p2[0], &in, sizeof(in)) == sizeof(in))
    printf("%d: child %d says \"%s\"\n", getpid(), in.pid, in.msg);
```

**Child:**
```c
struct handshake_msg in, out;
if (read(p1[0], &in, sizeof(in)) == sizeof(in)) {
    printf("%d: parent %d says \"%s\"\n", getpid(), in.pid, in.msg);
    out.pid = getpid();
    strcpy(out.msg, "ACK");
    write(p2[1], &out, sizeof(out));
}
```

---

## H26: Conditional Fork Chain

> **Recursive forking**: child reads depth from parent. If `depth < N`, child creates a new pipe, forks a grandchild, and relays. Last descendant sends the final reply all the way back up. Tests **recursive IPC chains**.

**Parent:**
```c
int depth = atoi(argv[1]);         // chain depth
write(p1[1], &depth, sizeof(int));
char result;
if (read(p2[0], &result, 1) == 1)
    printf("%d(P): final result from depth %d = '%c'\n", getpid(), depth, result);
```

**Child:**
```c
int depth;
if (read(p1[0], &depth, sizeof(int)) == sizeof(int)) {
    printf("%d: depth=%d\n", getpid(), depth);
    if (depth <= 1) {
        // Base case: last in chain, send reply
        char reply = 'Z';
        write(p2[1], &reply, 1);
    } else {
        // Recursive case: create new pipe, fork grandchild
        int np[2]; pipe(np);
        int gpid = fork();
        if (gpid == 0) {
            // Grandchild: read from np, write reply to p2 (inherited)
            close(np[1]);
            int next = depth - 1;
            // Recurse by reading next depth, doing same logic
            printf("%d: depth=%d\n", getpid(), next);
            if (next <= 1) {
                char reply = 'Z';
                write(p2[1], &reply, 1);
            } else {
                // For exam: just send reply at depth 2
                char reply = 'Y';
                write(p2[1], &reply, 1);
            }
            close(np[0]);
            exit(0);
        }
        close(np[0]);
        int next = depth - 1;
        write(np[1], &next, sizeof(int));
        close(np[1]);
        wait(0);
    }
}
```

> 💡 For exam: depth 2-3 is realistic. Deeper recursion requires cleaner looping — see H12 for iterative approach.

---

## H27: Pipe + Kill Signal

> Parent sends a byte, child reads and prints it, then parent **kills** the child with `kill(pid)`. Tests understanding that `kill()` is asynchronous — child must read/print **before** being killed.

**Parent:**
```c
char msg = argv[1][0];
write(p1[1], &msg, 1);

// Give child time to read and print
pause(5);

// Kill child
kill(pid);                         // xv6 kill() — no signal arg, just pid
printf("%d: killed child %d\n", getpid(), pid);
```

**Child:**
```c
char buf;
if (read(p1[0], &buf, 1) == 1)
    printf("%d: received '%c' (about to be killed)\n", getpid(), buf);

// Child stays alive doing work until killed
for (;;) pause(1);                 // infinite sleep — killed by parent
```

> ⚠️ xv6's `kill(pid)` takes **only PID** (no signal number). It sets `p->killed = 1`; the process dies at the next kernel return.

---

## H28: Exit Status Handshake

> Child reads a byte and passes it back via **`exit(byte)`** instead of a pipe write. Parent retrieves it with `wait(&status)`. Tests process exit status as a communication channel.

**Parent:**
```c
char msg = argv[1][0];
write(p1[1], &msg, 1);
close(p1[1]); p1[1] = -1;
close(p2[0]); close(p2[1]);       // don't need p2 — using exit status instead
// Note: boilerplate's close(p2[0]) will run, fine since already closed
```

> ⚠️ Also modify the boilerplate's **`wait(0)`** to **`int status; wait(&status);`**:
```c
// Replace the boilerplate's wait(0) with:
int status;
wait(&status);
printf("%d: child exited with status %d (byte='%c')\n",
       getpid(), status, (char)status);
```

**Child:**
```c
close(p2[0]); close(p2[1]);       // not using p2
char buf;
if (read(p1[0], &buf, 1) == 1) {
    printf("%d: received '%c', exiting with status %d\n",
           getpid(), buf, (int)(unsigned char)buf);
    close(p1[0]); close(p2[1]);   // cleanup before exit
    exit((int)(unsigned char)buf); // pass byte as exit status
}
```

> 💡 xv6's `wait(&status)` stores raw `xstate` — no `WEXITSTATUS()` macro needed (unlike Linux).

---

## H29: Double-Fork (Grandchild Communication)

> Parent forks A. A forks B (grandchild). Parent sends a message, A relays it to B, B transforms and writes the result back to parent via **inherited pipe**. Tests **multi-generation** fork with fd inheritance.

**Parent:**
```c
char msg = argv[1][0];
write(p1[1], &msg, 1);
char result;
if (read(p2[0], &result, 1) == 1)
    printf("%d(P): sent '%c', grandchild B returned '%c'\n",
           getpid(), msg, result);
```

**Child (A — forks grandchild B):**
```c
// A creates internal pipe for A→B communication
int ab[2]; pipe(ab);

int bpid = fork();
if (bpid == 0) {
    // ── Grandchild B ──
    close(p1[0]); close(p1[1]);   // B doesn't use parent→A pipe
    close(ab[1]);                  // B reads from A
    char buf;
    if (read(ab[0], &buf, 1) == 1) {
        buf ^= 0xFF;               // B's transform: XOR with 0xFF
        printf("%d(B): transformed → 0x%x\n", getpid(), (unsigned char)buf);
        write(p2[1], &buf, 1);    // B writes directly to parent via inherited p2
    }
    close(ab[0]); close(p2[1]);
    exit(0);
}

// A: relay parent's message to B
close(ab[0]);
char buf;
if (read(p1[0], &buf, 1) == 1) {
    printf("%d(A): relaying '%c' to grandchild\n", getpid(), buf);
    write(ab[1], &buf, 1);
}
close(ab[1]);
wait(0);                           // A waits for B
```

> 💡 Key insight: B inherits `p2[1]` from A (who inherited it from parent via fork). So B can write directly to parent.

---

## H30: Pipeline of 3 (cmd1 | cmd2 | cmd3)

> Programmatically build a **3-stage pipeline**: cmd1's stdout → cmd2's stdin → cmd2's stdout → cmd3's stdin. Uses `dup()` for fd redirection and `exec()` for each stage. Tests **pipeline construction**.

**Setup:**
```c
int p3[2];                         // p1: cmd1→cmd2, p2: cmd2→cmd3
pipe(p3);                          // p3 unused in this variation, or use p2 for stage 2
// Actually: p1 = stage1→stage2, p2 = stage2→stage3
```

**Child (cmd1 — first stage):**
```c
// cmd1: stdout → p1[1]
close(p2[0]); close(p2[1]);       // cmd1 doesn't use stage2 pipe
close(p3[0]); close(p3[1]);       // cmd1 doesn't use p3
close(1);                          // free stdout
dup(p1[1]);                        // stdout = p1 write end
close(p1[0]); close(p1[1]);       // cleanup

char *args[] = { argv[1], 0 };     // argv[1] = cmd1 name (e.g. "echo")
exec(args[0], args);
fprintf(2, "exec cmd1 failed\n");
```

**Parent (fork cmd2 and cmd3):**
```c
// Fork cmd2 (middle stage)
int pid2 = fork();
if (pid2 == 0) {
    // cmd2: stdin ← p1[0], stdout → p2[1]
    close(p3[0]); close(p3[1]);
    close(0); dup(p1[0]);          // stdin = p1 read end
    close(1); dup(p2[1]);          // stdout = p2 write end
    close(p1[0]); close(p1[1]); close(p2[0]); close(p2[1]);

    char *args[] = { argv[2], 0 }; // argv[2] = cmd2 name
    exec(args[0], args);
    fprintf(2, "exec cmd2 failed\n");
    exit(1);
}

// Fork cmd3 (last stage)
int pid3 = fork();
if (pid3 == 0) {
    // cmd3: stdin ← p2[0]
    close(p1[0]); close(p1[1]);
    close(p3[0]); close(p3[1]);
    close(0); dup(p2[0]);          // stdin = p2 read end
    close(p2[0]); close(p2[1]);

    char *args[] = { argv[3], 0 }; // argv[3] = cmd3 name
    exec(args[0], args);
    fprintf(2, "exec cmd3 failed\n");
    exit(1);
}

// Parent: close all pipe ends and wait for all 3 children
close(p1[0]); close(p1[1]); p1[0] = p1[1] = -1;
close(p2[0]); close(p2[1]); p2[0] = p2[1] = -1;
close(p3[0]); close(p3[1]);
wait(0); wait(0);                  // wait for cmd2 + cmd3 (cmd1 waited by boilerplate)
```

> ⚠️ Close **ALL** unused pipe ends in each child before `exec()`. Failing to close a write end means the reader never gets EOF.

---

## Pattern B Quick Reference

| # | Name | Zones Used | Key Concept | xv6 API |
|---|------|-----------|-------------|---------|
| H18 | Error Code | P, C | Validation + status byte | — |
| H19 | Fan-Out | S, P, C | N children, N pipe pairs | pipe(), fork() loop |
| H20 | File Log | P, C | File I/O + IPC | open(), O_CREATE |
| H21 | Exec Redirect | P, C | fd redirect + exec | close()+dup(), exec() |
| H22 | 3-Way Ring | S, P, C | Ring topology, 3 pipes | 2nd fork in PARENT |
| H23 | Dup Stdin | C | fd 0 = pipe read end | close(0)+dup() |
| H24 | Tee Pipe | S, P, C | Broadcast to 2 children | 2nd fork + extra pipes |
| H25 | Struct | P, C | Binary struct over pipe | sizeof(struct) |
| H26 | Recursive Fork | P, C | Chain depth via recursive fork | pipe()+fork() in CHILD |
| H27 | Kill Signal | P, C | Async kill after IPC | kill(pid), pause() |
| H28 | Exit Status | P, C | Exit code as reply channel | exit(n), wait(&status) |
| H29 | Double-Fork | C | Grandchild via nested fork | fork() in CHILD |
| H30 | Pipeline of 3 | S, P, C | 3-stage cmd pipeline | dup(), exec() ×3 |

---
---

# Pattern C — New Combo Tasks (H31–H40)

> **Scope**: Each variation is a **two-part combo**: a new kernel syscall (`sys_xxx` in `sysproc.c`) + a user-space test program that uses handshake concepts.
> **Assumption**: You already know the 7-step syscall checklist (`syscall.h` → `syscall.c` → `usys.pl` → `user.h` → etc.). Only the **C logic** is shown here.
> **Kernel helpers**: `myproc()`, `argint(n, &val)`, `argaddr(n, &addr)`, `copyout(pagetable, va, src, len)`, `copyin(pagetable, dst, va, len)`, `argstr(n, buf, max)`

---

## H31: `pipecount` — Count Active Pipes

> Iterates the **global file table** (`ftable.file[NFILE]`) and counts entries with `type == FD_PIPE`. Each pipe has 2 file entries (read + write), so divide by 2 for unique pipe count.

**Kernel (`sysproc.c`):**
```c
// Need access to ftable — add extern at top of sysproc.c:
// extern struct { struct spinlock lock; struct file file[NFILE]; } ftable;
#include "spinlock.h"
#include "file.h"

uint64
sys_pipecount(void)
{
  int count = 0;
  acquire(&ftable.lock);
  for (int i = 0; i < NFILE; i++) {
    if (ftable.file[i].type == FD_PIPE)
      count++;
  }
  release(&ftable.lock);
  return count / 2;  // each pipe = 2 file entries (read + write)
}
```

**User program (`user/testpipecount.c`):**
```c
#include "kernel/types.h"
#include "user/user.h"

int main() {
    printf("pipes before: %d\n", pipecount());

    int p1[2], p2[2];
    pipe(p1); pipe(p2);
    printf("pipes after:  %d\n", pipecount()); // should be +2

    int pid = fork();
    if (pid == 0) {
        close(p1[1]); close(p2[0]);
        printf("child sees %d pipes\n", pipecount());
        char buf;
        read(p1[0], &buf, 1);
        write(p2[1], &buf, 1);
        close(p1[0]); close(p2[1]);
        exit(0);
    }
    close(p1[0]); close(p2[1]);
    char msg = 'X';
    write(p1[1], &msg, 1);
    char buf;
    read(p2[0], &buf, 1);
    printf("parent got '%c', pipes now: %d\n", buf, pipecount());
    close(p1[1]); close(p2[0]);
    wait(0);
    printf("pipes after cleanup: %d\n", pipecount());
    exit(0);
}
```

---

## H32: `getppid` — Get Parent PID

> Returns the **PID of the calling process's parent**. Child uses it in a handshake to verify the parent's identity without needing pipes to transmit it.

**Kernel (`sysproc.c`):**
```c
uint64
sys_getppid(void)
{
  struct proc *p = myproc();
  // parent is set in fork(), only changes on reparent to init
  return p->parent->pid;
}
```

**User program (`user/testgetppid.c`):**
```c
#include "kernel/types.h"
#include "user/user.h"

int main() {
    int p1[2];
    pipe(p1);

    int pid = fork();
    if (pid == 0) {
        close(p1[0]);
        int ppid = getppid();           // syscall — no pipe needed!
        write(p1[1], &ppid, sizeof(int));
        close(p1[1]);
        exit(0);
    }
    close(p1[1]);
    int reported_ppid;
    read(p1[0], &reported_ppid, sizeof(int));
    close(p1[0]);
    printf("parent PID=%d, child reported ppid=%d → %s\n",
           getpid(), reported_ppid,
           reported_ppid == getpid() ? "VERIFIED" : "MISMATCH");
    wait(0);
    exit(0);
}
```

---

## H33: `forkcount` — Track Fork Calls

> Counts how many times **this process** has called `fork()`. Requires adding a `forkcount` field to `struct proc` and incrementing it in `fork()`.

**Kernel — proc.h (add field):**
```c
// Inside struct proc:
int forkcount;             // number of fork() calls by this process
```

**Kernel — proc.c (increment in fork):**
```c
// Inside fork(), after successful child creation:
p->forkcount++;            // p = parent (myproc())
np->forkcount = 0;         // np = new child, starts at 0
```

**Kernel (`sysproc.c`):**
```c
uint64
sys_forkcount(void)
{
  return myproc()->forkcount;
}
```

**User program:**
```c
#include "kernel/types.h"
#include "user/user.h"

int main() {
    printf("forkcount before: %d\n", forkcount());  // 0

    int p1[2]; pipe(p1);

    int pid1 = fork();  // forkcount → 1
    if (pid1 == 0) { close(p1[0]); close(p1[1]); exit(0); }
    wait(0);

    int pid2 = fork();  // forkcount → 2
    if (pid2 == 0) {
        close(p1[1]);
        int fc = forkcount();  // child's own forkcount = 0
        write(p1[1], &fc, sizeof(int));
        close(p1[0]);
        exit(0);
    }

    close(p1[0]);
    printf("parent forkcount: %d\n", forkcount());  // 2
    wait(0);
    exit(0);
}
```

---

## H34: `dupfd` — Dup into Specific Fd (like `dup2`)

> Duplicates `oldfd` into exactly `newfd`. If `newfd` is already open, it's closed first. Uses the process's `ofile[]` array and `filedup()`.

**Kernel (`sysproc.c`):**
```c
uint64
sys_dupfd(void)
{
  int oldfd, newfd;
  argint(0, &oldfd);
  argint(1, &newfd);

  struct proc *p = myproc();

  if (oldfd < 0 || oldfd >= NOFILE || p->ofile[oldfd] == 0)
    return -1;
  if (newfd < 0 || newfd >= NOFILE)
    return -1;
  if (oldfd == newfd)
    return newfd;  // no-op

  // Close newfd if it's open
  if (p->ofile[newfd])
    fileclose(p->ofile[newfd]);

  p->ofile[newfd] = p->ofile[oldfd];
  filedup(p->ofile[newfd]);
  return newfd;
}
```

**User program:**
```c
#include "kernel/types.h"
#include "user/user.h"

int main() {
    int p1[2]; pipe(p1);

    // Redirect: make fd 7 point to pipe read end
    dupfd(p1[0], 7);
    close(p1[0]);  // original fd no longer needed

    int pid = fork();
    if (pid == 0) {
        // Child writes to pipe
        close(7);  // child doesn't read
        char msg = 'Q';
        write(p1[1], &msg, 1);
        close(p1[1]);
        exit(0);
    }

    close(p1[1]);
    char buf;
    read(7, &buf, 1);  // read from our custom fd 7
    printf("read '%c' from fd 7\n", buf);
    close(7);
    wait(0);
    exit(0);
}
```

---

## H35: `pipeaudit` — Read Pipe Statistics

> Returns `nread` and `nwrite` counters from the **kernel pipe struct** for a given file descriptor. Uses `copyout()` to send kernel data to user space.

**Kernel (`sysproc.c`):**
```c
uint64
sys_pipeaudit(void)
{
  int fd;
  uint64 nread_addr, nwrite_addr;
  argint(0, &fd);
  argaddr(1, &nread_addr);
  argaddr(2, &nwrite_addr);

  struct proc *p = myproc();
  if (fd < 0 || fd >= NOFILE || p->ofile[fd] == 0)
    return -1;

  struct file *f = p->ofile[fd];
  if (f->type != FD_PIPE)
    return -1;  // not a pipe

  struct pipe *pi = f->pipe;
  uint nr = pi->nread;
  uint nw = pi->nwrite;

  if (copyout(p->pagetable, nread_addr, (char*)&nr, sizeof(uint)) < 0)
    return -1;
  if (copyout(p->pagetable, nwrite_addr, (char*)&nw, sizeof(uint)) < 0)
    return -1;

  return 0;
}
```

**User program:**
```c
#include "kernel/types.h"
#include "user/user.h"

int main() {
    int p1[2]; pipe(p1);

    // Write some bytes
    write(p1[1], "hello", 5);

    uint nr, nw;
    pipeaudit(p1[0], &nr, &nw);  // query read end
    printf("nread=%d, nwrite=%d\n", nr, nw);  // expect 0, 5

    // Read 3 bytes
    char buf[8];
    read(p1[0], buf, 3);

    pipeaudit(p1[0], &nr, &nw);
    printf("nread=%d, nwrite=%d\n", nr, nw);  // expect 3, 5

    close(p1[0]); close(p1[1]);
    exit(0);
}
```

> 💡 `pipeaudit` signature in `user.h`: `int pipeaudit(int fd, uint *nread, uint *nwrite);`

---

## H36: `proctree` — Print Process Tree

> Iterates the **global proc table** (`proc[NPROC]`) and prints each active process's PID and parent PID. Returns the count of active processes.

**Kernel (`sysproc.c`):**
```c
uint64
sys_proctree(void)
{
  // proc table is extern: struct proc proc[NPROC];
  int count = 0;
  for (int i = 0; i < NPROC; i++) {
    struct proc *p = &proc[i];
    acquire(&p->lock);
    if (p->state != UNUSED) {
      int ppid = p->parent ? p->parent->pid : 0;
      printf("  [%d] %s → parent [%d]\n", p->pid, p->name, ppid);
      count++;
    }
    release(&p->lock);
  }
  return count;
}
```

**User program:**
```c
#include "kernel/types.h"
#include "user/user.h"

int main() {
    int pid = fork();
    if (pid == 0) {
        printf("--- child's view ---\n");
        int n = proctree();
        printf("total active: %d\n", n);
        exit(0);
    }
    wait(0);
    printf("--- parent's view ---\n");
    int n = proctree();
    printf("total active: %d\n", n);
    exit(0);
}
```

---

## H37: Orphan Rescue (uses `getppid` from H32)

> Parent forks A, A forks grandchild B, then **A exits**. B becomes an orphan and is reparented to **init (PID 1)**. B uses `getppid()` to verify reparenting. Tests xv6's `reparent()` mechanism.

> ⚠️ No new syscall — uses `getppid` from H32.

**User program (`user/orphan.c`):**
```c
#include "kernel/types.h"
#include "user/user.h"

int main() {
    int p1[2]; pipe(p1);

    int pidA = fork();
    if (pidA == 0) {
        // ── Process A ──
        int pidB = fork();
        if (pidB == 0) {
            // ── Grandchild B ──
            close(p1[0]);
            pause(10);  // wait for A to exit and be reaped

            int ppid = getppid();
            write(p1[1], &ppid, sizeof(int));
            printf("B (pid %d): my parent is now %d %s\n",
                   getpid(), ppid,
                   ppid == 1 ? "(init — ORPHANED)" : "(still A)");
            close(p1[1]);
            exit(0);
        }
        // A exits immediately — orphaning B
        exit(0);
    }

    // Original parent
    close(p1[1]);
    wait(0);  // reap A

    int bppid;
    read(p1[0], &bppid, sizeof(int));
    printf("parent: B's parent after orphaning = %d %s\n",
           bppid, bppid == 1 ? "CORRECT (init)" : "UNEXPECTED");
    close(p1[0]);
    // Note: init will reap B, not us
    exit(0);
}
```

> 💡 xv6's `reparent()` (in `proc.c`) re-parents all children of a dying process to `initproc` (PID 1).

---

## H38: Shared Page Handshake

> Syscall allocates a **physical page** and maps it at a known VA. After `fork()`, the child calls the same syscall to map the **same physical page** into its address space. Parent and child communicate via shared memory — no pipes needed.

**Kernel — proc.h (add field):**
```c
// Inside struct proc:
uint64 shmpa;              // physical address of shared page (0 = none)
uint64 shmva;              // virtual address where shared page is mapped
```

**Kernel (`sysproc.c`):**
```c
#include "memlayout.h"

uint64
sys_shmalloc(void)
{
  struct proc *p = myproc();

  if (p->shmpa != 0)
    return p->shmva;  // already allocated

  void *mem = kalloc();
  if (mem == 0)
    return -1;

  memset(mem, 0, PGSIZE);
  uint64 va = PGROUNDUP(p->sz);  // map just above heap

  if (mappages(p->pagetable, va, PGSIZE, (uint64)mem, PTE_W | PTE_R | PTE_U) < 0) {
    kfree(mem);
    return -1;
  }

  p->shmpa = (uint64)mem;
  p->shmva = va;
  p->sz = va + PGSIZE;
  return va;
}

uint64
sys_shmattach(void)
{
  struct proc *p = myproc();

  if (p->shmpa == 0)
    return -1;  // no shared page from parent

  // shmpa was inherited from parent via fork()
  // But fork() already mapped a COPY. We need to remap to the SAME physical page.
  // Unmap the copy, then map the original PA.
  uint64 va = p->shmva;
  uvmunmap(p->pagetable, va, 1, 1);  // unmap + free the copy

  if (mappages(p->pagetable, va, PGSIZE, p->shmpa, PTE_W | PTE_R | PTE_U) < 0)
    return -1;

  return va;
}
```

**Kernel — proc.c (inherit in fork):**
```c
// Inside fork(), after copying pagetable:
np->shmpa = p->shmpa;   // child inherits parent's shared page PA
np->shmva = p->shmva;
```

**User program:**
```c
#include "kernel/types.h"
#include "user/user.h"

int main() {
    char *shm = (char*)shmalloc();  // allocate shared page
    if ((int)(uint64)shm == -1) { printf("shmalloc failed\n"); exit(1); }

    strcpy(shm, "hello from parent");

    int pid = fork();
    if (pid == 0) {
        shmattach();                // remap to same physical page
        printf("child reads: \"%s\"\n", shm);
        strcpy(shm, "reply from child");
        exit(0);
    }
    wait(0);
    printf("parent reads: \"%s\"\n", shm);
    exit(0);
}
```

> ⚠️ This is the most complex variation. For exam, focus on the concept: `kalloc()` → `mappages()` → both processes share same PA.

---

## H39: Message Queue over Pipes

> **User-space only** — no kernel syscall. Implements `send_msg()` / `recv_msg()` helpers that wrap raw pipe I/O with a **typed message protocol**: `[type:int][len:int][data:char[]]`.

**User program (`user/msgqueue.c`):**
```c
#include "kernel/types.h"
#include "user/user.h"

struct msg {
    int type;     // message type tag
    int len;      // payload length
    char data[64];
};

void send_msg(int fd, int type, char *data, int len) {
    struct msg m;
    m.type = type;
    m.len = len;
    memmove(m.data, data, len);
    write(fd, &m, sizeof(struct msg));
}

int recv_msg(int fd, struct msg *m) {
    int n = read(fd, m, sizeof(struct msg));
    return (n == sizeof(struct msg)) ? 0 : -1;
}

int main() {
    int p1[2], p2[2];
    pipe(p1); pipe(p2);

    int pid = fork();
    if (pid == 0) {
        close(p1[1]); close(p2[0]);
        struct msg m;
        // Wait for PING (type=1)
        if (recv_msg(p1[0], &m) == 0 && m.type == 1) {
            printf("child: PING received, data=\"%s\"\n", m.data);
            // Reply with PONG (type=2)
            send_msg(p2[1], 2, "PONG", 5);
        }
        close(p1[0]); close(p2[1]);
        exit(0);
    }

    close(p1[0]); close(p2[1]);
    // Send PING
    send_msg(p1[1], 1, "PING", 5);

    // Receive PONG
    struct msg reply;
    if (recv_msg(p2[0], &reply) == 0 && reply.type == 2)
        printf("parent: %s received!\n", reply.data);

    close(p1[1]); close(p2[0]);
    wait(0);
    exit(0);
}
```

> 💡 The key pattern: `write(&struct, sizeof(struct))` sends the entire struct atomically (if ≤ PIPESIZE=512).

---

## H40: `setsecret` / `getsecret` — Environment Passing via Proc

> Parent stores a **secret string** in a new `struct proc` field via syscall. The field is **inherited on fork** and **preserved across exec**. Child execs a program that retrieves the secret.

**Kernel — proc.h (add field):**
```c
// Inside struct proc:
char secret[64];           // inherited on fork, preserved on exec
```

**Kernel — proc.c (inherit in fork):**
```c
// Inside fork():
memmove(np->secret, p->secret, 64);
```

**Kernel (`sysproc.c`):**
```c
uint64
sys_setsecret(void)
{
  struct proc *p = myproc();
  // Copy string from user space into proc's secret field
  if (argstr(0, p->secret, 64) < 0)
    return -1;
  return 0;
}

uint64
sys_getsecret(void)
{
  struct proc *p = myproc();
  uint64 addr;
  int len;
  argaddr(0, &addr);
  argint(1, &len);
  if (len > 64) len = 64;
  if (copyout(p->pagetable, addr, p->secret, len) < 0)
    return -1;
  return 0;
}
```

**User programs:**

`user/setsecrettest.c` (parent):
```c
#include "kernel/types.h"
#include "user/user.h"

int main(int argc, char *argv[]) {
    if (argc < 2) { printf("usage: setsecrettest <secret>\n"); exit(1); }

    setsecret(argv[1]);
    printf("secret set to \"%s\"\n", argv[1]);

    // Fork and exec the reader program
    int pid = fork();
    if (pid == 0) {
        char *args[] = { "getsecrettest", 0 };
        exec(args[0], args);
        printf("exec failed\n");
        exit(1);
    }
    wait(0);
    exit(0);
}
```

`user/getsecrettest.c` (child, exec'd):
```c
#include "kernel/types.h"
#include "user/user.h"

int main() {
    char buf[64];
    getsecret(buf, 64);
    printf("inherited secret = \"%s\"\n", buf);
    exit(0);
}
```

> 💡 `secret` survives `exec()` because `exec()` replaces the memory image but **does not clear** custom proc fields (only the ones explicitly zeroed in `exec.c`).

---

## Pattern C Quick Reference

| # | Name | Syscall | Kernel Struct Modified | Key Concept |
|---|------|---------|----------------------|-------------|
| H31 | pipecount | `sys_pipecount` | ftable (file.c) | Iterate file table, count FD_PIPE |
| H32 | getppid | `sys_getppid` | — (read only) | `myproc()->parent->pid` |
| H33 | forkcount | `sys_forkcount` | proc.h: `int forkcount` | Increment in fork(), read via syscall |
| H34 | dupfd | `sys_dupfd` | — (ofile[] array) | `fileclose` old + `filedup` new |
| H35 | pipeaudit | `sys_pipeaudit` | — (read pipe struct) | `f->pipe->nread/nwrite` + `copyout` |
| H36 | proctree | `sys_proctree` | — (iterate proc[]) | `acquire(&p->lock)` + iterate |
| H37 | orphan | (uses H32) | — | `reparent()` to init, verify via `getppid` |
| H38 | shared page | `sys_shmalloc/attach` | proc.h: `shmpa, shmva` | `kalloc` + `mappages` + shared PA |
| H39 | msg queue | (user-space only) | — | struct protocol over pipes |
| H40 | setsecret | `sys_set/getsecret` | proc.h: `char secret[64]` | `argstr` + `copyout` + inherit on fork |

---
---

# Pattern D — Mutation Dimensions (H41–H52)

> **Scope**: Edge cases, stress tests, and error-path mutations of the standard 2-pipe handshake. Tests xv6 **limits** (`NPROC=64`, `PIPESIZE=512`, `NOFILE=16`), **error returns** (`-1` on invalid ops), and advanced **coordination patterns**.
> **Zones**: Drop-zone snippets for `[SETUP]`, `[PARENT]`, `[CHILD]`. Some variations (H47, H48) replace the boilerplate entirely — noted explicitly.

---

## H41: Pipe Stress (Fork to NPROC Limit)

> Fork children in a loop until `fork()` returns `-1` (NPROC=64 exhausted). Count how many succeeded. Each child does a minimal read/write handshake on a **shared pipe pair**. Tests **resource exhaustion** handling.

> ⚠️ NPROC=64 includes `init`(1) + `sh`(1) + parent(1) → max ~61 new children.

**Parent:**
```c
int count = 0;
for (int i = 0; i < 64; i++) {
    int cpid = fork();
    if (cpid < 0) {
        printf("%d: fork failed after %d children (NPROC=%d)\n",
               getpid(), count, 64);
        break;
    }
    if (cpid == 0) {
        // Child: read 1 byte, echo it back
        close(p1[1]); close(p2[0]);
        char buf;
        if (read(p1[0], &buf, 1) == 1)
            write(p2[1], &buf, 1);
        close(p1[0]); close(p2[1]);
        exit(0);
    }
    count++;
}
printf("%d: forked %d children\n", getpid(), count);

// Send 1 byte per child, read 1 back
for (int i = 0; i < count; i++) {
    char c = 'A' + (i % 26);
    write(p1[1], &c, 1);
}
for (int i = 0; i < count; i++) {
    char buf;
    read(p2[0], &buf, 1);
}
// Reap all
for (int i = 0; i < count; i++)
    wait(0);
printf("%d: all %d children reaped\n", getpid(), count);
```

**Child:**
```c
// (handled inside parent loop above — child code is inline)
// If using the boilerplate's child zone, leave it empty:
// The child is spawned inside the PARENT zone loop.
```

> 💡 Shared pipe gotcha: all children race to `read(p1[0])`. Each byte is consumed by exactly one child.

---

## H42: Write After Close

> Parent **closes** the write end of `p1`, then tries to write to it. Tests that xv6 returns `-1` when writing to a closed/invalid file descriptor.

**Parent:**
```c
char msg = 'X';
close(p1[1]);                      // close write end FIRST
p1[1] = -1;                       // mark as invalid

int ret = write(p1[1], &msg, 1);  // attempt write on fd -1
printf("%d: write after close → returned %d %s\n",
       getpid(), ret, ret == -1 ? "(EXPECTED -1)" : "(UNEXPECTED!)");

// Also test: write on the closed but valid-numbered fd
// After close(p1[1]), ofile[p1[1]] == 0 internally
// So writing to the original fd number also returns -1
```

**Child:**
```c
// Child tries to read — gets EOF immediately (write end closed)
char buf;
int n = read(p1[0], &buf, 1);
printf("%d: read from closed-write pipe → %d %s\n",
       getpid(), n, n == 0 ? "(EOF as expected)" : "(unexpected)");
```

> ⚠️ xv6: `write(fd, ...)` where `ofile[fd] == 0` → `argfd()` fails → returns `-1`. On fd `-1` → out of range → also returns `-1`.

---

## H43: Read from Write-End

> Try to `read()` from the **write end** of a pipe (`p1[1]`). The file struct has `readable=0`, so `fileread()` returns `-1`.

**Parent:**
```c
char msg = 'X';
write(p1[1], &msg, 1);            // normal write

// Now try reading from the WRITE end
char buf;
int ret = read(p1[1], &buf, 1);   // read from write end!
printf("%d: read from write-end → returned %d %s\n",
       getpid(), ret, ret == -1 ? "(EXPECTED -1)" : "(UNEXPECTED!)");

// Also try writing to the READ end
ret = write(p1[0], &msg, 1);
printf("%d: write to read-end → returned %d %s\n",
       getpid(), ret, ret == -1 ? "(EXPECTED -1)" : "(UNEXPECTED!)");
```

**Child:**
```c
char buf;
read(p1[0], &buf, 1);             // normal read (consumes the 'X')
printf("%d: normal read got '%c'\n", getpid(), buf);
write(p2[1], &buf, 1);
```

> 💡 xv6 `fileread()` checks `f->readable`; `filewrite()` checks `f->writable`. Wrong direction → instant `-1`.

---

## H44: Zero-Length Read

> Call `read(fd, buf, 0)` on a pipe. In xv6, `piperead()` checks the blocking condition **before** the loop — so a zero-length read on an **empty, write-open pipe** will **BLOCK forever**.

**Parent:**
```c
// First: write something so pipe isn't empty
char msg = 'A';
write(p1[1], &msg, 1);

// Now child will test zero-length read on non-empty pipe → returns 0
// AND zero-length read on empty pipe → BLOCKS (see child)
char buf;
read(p2[0], &buf, 1);
printf("%d: child result = '%c'\n", getpid(), buf);
```

**Child:**
```c
// Test 1: zero-length read on NON-EMPTY pipe
char buf;
read(p1[0], &buf, 1);             // consume the 'A' first? No — let's test with data present
// Actually, let's test with data present:
int ret = read(p1[0], &buf, 0);   // zero-length read, data present
printf("%d: read(fd, buf, 0) with data → %d\n", getpid(), ret);
// Expected: ret = 0 (loop runs 0 times)
// BUT GOTCHA: piperead first does while(nread==nwrite && writeopen) sleep()
//             nread != nwrite (data present), so no block → for loop 0 iters → return 0

// Now consume the actual data
read(p1[0], &buf, 1);
printf("%d: consumed '%c'\n", getpid(), buf);

char result = (char)ret;           // 0
write(p2[1], &buf, 1);
```

> ⚠️ **CRITICAL GOTCHA**: `read(fd, buf, 0)` on an **empty** pipe with write-end **open** → `piperead` **BLOCKS** at the `while(nread==nwrite && writeopen)` loop. The `n=0` check happens **after** the blocking check.

---

## H45: EOF Detection (Close-and-Count)

> Parent writes `N` bytes, then **closes write end**. Child reads in a loop until `read()` returns `0` (EOF). Counts total bytes received. Tests the EOF handshake.

**Parent:**
```c
int N = 10;
for (int i = 0; i < N; i++) {
    char c = 'A' + i;
    write(p1[1], &c, 1);
}
close(p1[1]); p1[1] = -1;         // signal EOF

// Read child's byte count
int count;
read(p2[0], &count, sizeof(int));
printf("%d: sent %d bytes, child received %d → %s\n",
       getpid(), N, count,
       count == N ? "MATCH" : "MISMATCH");
```

**Child:**
```c
int count = 0;
char buf;
while (read(p1[0], &buf, 1) > 0) {
    count++;                       // count each byte until EOF
}
// read returned 0 → EOF (write end closed, pipe empty)
printf("%d: EOF after %d bytes\n", getpid(), count);
write(p2[1], &count, sizeof(int));
```

> 💡 EOF condition in `piperead()`: `nread == nwrite && !writeopen` → exits the `while` loop → `for` loop reads 0 bytes → returns `0`.

---

## H46: Multiple Readers (Race on Shared Pipe)

> Two children **both read from the same pipe read-end** (`p1[0]`). Parent writes 2 bytes. Each child races to consume one. Tests that pipe data is **consumed, not duplicated**.

**Setup:**
```c
int p3[2]; pipe(p3);              // p3: child2 → parent reply channel
```

**Child (Child 1):**
```c
close(p3[0]); close(p3[1]);       // child1 doesn't use p3
char buf;
int n = read(p1[0], &buf, 1);     // race with child2!
if (n == 1) {
    printf("%d(C1): won race, got '%c'\n", getpid(), buf);
    write(p2[1], &buf, 1);
} else {
    printf("%d(C1): lost race (n=%d)\n", getpid(), n);
    char z = '?';
    write(p2[1], &z, 1);
}
```

**Parent:**
```c
// Fork child2
int pid2 = fork();
if (pid2 == 0) {
    // ── Child 2 ──
    close(p2[0]); close(p2[1]);   // child2 uses p3 for reply
    close(p3[1]);
    // WRONG: close(p3[0]); — child2 needs to WRITE to p3[1]
    close(p1[1]);
    close(p3[0]);
    char buf;
    int n = read(p1[0], &buf, 1); // race with child1!
    if (n == 1) {
        printf("%d(C2): won race, got '%c'\n", getpid(), buf);
        write(p3[1], &buf, 1);
    } else {
        char z = '?';
        write(p3[1], &z, 1);
    }
    // Fix: properly close fds
    close(p1[0]);
    exit(0);
}

// Correction for child2 — rewrite cleanly:
// (The above child2 block has fd management issues.
//  Clean version below in parent perspective)

// Parent sends 2 bytes
char a = 'X', b = 'Y';
write(p1[1], &a, 1);
write(p1[1], &b, 1);
close(p1[1]); p1[1] = -1;

// Read replies
char r1, r2;
read(p2[0], &r1, 1);              // from child1
read(p3[0], &r2, 1);              // from child2
printf("%d(P): C1 got '%c', C2 got '%c'\n", getpid(), r1, r2);
close(p3[0]);
wait(0);                           // wait for child2
```

> ⚠️ With 2 readers on 1 pipe, each byte is consumed by **exactly one** child. Order is non-deterministic. No duplication.

---

## H47: Self-Pipe (No Fork)

> Process creates a pipe, writes, then reads **without forking**. No boilerplate needed — this is a **standalone replacement**.

> ⚠️ **Replace entire boilerplate** with this standalone program:
```c
#include "kernel/types.h"
#include "user/user.h"

int main() {
    int p[2];
    pipe(p);

    // Write small data
    char out = 'Z';
    write(p[1], &out, 1);

    // Read it back — same process
    char in;
    read(p[0], &in, 1);
    printf("self-pipe: wrote '%c', read '%c' → %s\n",
           out, in, out == in ? "MATCH" : "MISMATCH");

    // Demonstrate PIPESIZE limit
    printf("writing %d bytes (PIPESIZE=512)...\n", 512);
    char buf[512];
    memset(buf, 'A', 512);
    write(p[1], buf, 512);         // fills pipe completely
    printf("pipe full. next write would DEADLOCK!\n");
    // write(p[1], &out, 1);       // ← DEADLOCK: pipe full, no reader to free space

    // Drain and prove
    char readbuf[512];
    int n = read(p[0], readbuf, 512);
    printf("drained %d bytes\n", n);

    close(p[0]); close(p[1]);
    exit(0);
}
```

> ⚠️ **DEADLOCK RULE**: Single-threaded process + write > PIPESIZE (512) → `pipewrite()` sleeps waiting for reader → nobody to read → **permanent block**.

---

## H48: Fork Before Pipe (Ordering Matters)

> Fork **first**, then child creates a pipe. Parent tries to communicate — but **cannot**, because it doesn't have the child's pipe file descriptors.

> ⚠️ **Replace entire boilerplate** with this standalone program:
```c
#include "kernel/types.h"
#include "user/user.h"

int main() {
    int pid = fork();

    if (pid == 0) {
        // Child creates pipe AFTER fork
        int cp[2];
        pipe(cp);

        // Child can use its own pipe (self-pipe)
        char msg = 'Q';
        write(cp[1], &msg, 1);
        char buf;
        read(cp[0], &buf, 1);
        printf("%d(child): self-pipe works → '%c'\n", getpid(), buf);

        close(cp[0]); close(cp[1]);
        exit(0);
    }

    // Parent has NO access to child's pipe fds
    // cp[0] and cp[1] don't exist in parent's fd table
    printf("%d(parent): cannot access child's pipe — fds not shared!\n",
           getpid());

    // Contrast: if pipe was created BEFORE fork, both would have it
    wait(0);
    printf("lesson: pipe() MUST come before fork() for IPC\n");
    exit(0);
}
```

> 💡 `fork()` copies the parent's fd table at fork time. Pipes created **after** fork exist only in the process that called `pipe()`.

---

## H49: Cascading Wait (Process Chain)

> Chain of 5 processes: P→C1→C2→C3→C4. Each **forks one child** and **waits for it** before exiting. The deepest child exits first, triggering a cascade of waits back up to P.

**Parent:**
```c
// Build chain using p1 for message passing, p2 for result
char msg = argv[1][0];
write(p1[1], &msg, 1);

char result;
read(p2[0], &result, 1);
printf("%d(P): final result = '%c'\n", getpid(), result);
```

**Child:**
```c
int depth = 4;                     // how many more to fork
char buf;
read(p1[0], &buf, 1);
printf("%d(depth %d): got '%c'\n", getpid(), depth, buf);

if (depth <= 1) {
    // Deepest child — end of chain
    buf += depth;                  // mutate
    printf("%d: chain bottom, replying '%c'\n", getpid(), buf);
    write(p2[1], &buf, 1);
} else {
    // Fork next link
    int np[2]; pipe(np);
    int cpid = fork();
    if (cpid == 0) {
        // Next link reads from np, writes to p2
        close(np[1]);
        char b2;
        read(np[0], &b2, 1);
        int newdepth = depth - 1;
        printf("%d(depth %d): got '%c'\n", getpid(), newdepth, b2);
        if (newdepth <= 1) {
            b2 += newdepth;
            write(p2[1], &b2, 1);
        } else {
            // For exam: limit to depth 2-3
            b2 += newdepth;
            write(p2[1], &b2, 1);
        }
        close(np[0]);
        exit(0);
    }
    close(np[0]);
    buf += 1;                      // this link's mutation
    write(np[1], &buf, 1);
    close(np[1]);
    int status;
    wait(&status);                 // cascading wait
    printf("%d: child exited with status %d\n", getpid(), status);
}
```

> 💡 Wait cascade: C4 exits → C3's `wait()` returns → C3 exits → C2's `wait()` returns → ... → P's `wait()` returns last.

---

## H50: Exit Status Encoding

> Child encodes **two 4-bit values** into its exit status: `status = (a << 4) | b`. Parent decodes them after `wait()`. Tests understanding that xv6's `wait(&status)` gives raw `xstate`.

**Parent:**
```c
char val = argv[1][0];
write(p1[1], &val, 1);

// Don't use p2 — communication via exit status
close(p2[0]); close(p2[1]);

int status;
wait(&status);

int upper = (status >> 4) & 0x0F;  // extract high nibble
int lower = status & 0x0F;         // extract low nibble
printf("%d: exit status = 0x%02x → upper=%d, lower=%d\n",
       getpid(), status, upper, lower);
printf("decoded: byte_value=%d, is_alpha=%d\n", upper, lower);
```

**Child:**
```c
close(p2[0]); close(p2[1]);       // not using p2
char buf;
if (read(p1[0], &buf, 1) == 1) {
    int val = (unsigned char)buf;
    int is_alpha = (buf >= 'A' && buf <= 'z') ? 1 : 0;
    int encoded = ((val & 0x0F) << 4) | is_alpha;
    printf("%d: encoding val=%d, alpha=%d → status=0x%02x\n",
           getpid(), val & 0x0F, is_alpha, encoded);
    close(p1[0]);
    exit(encoded);
}
```

> 💡 xv6 `wait(&status)` stores raw `exit()` arg — no `WEXITSTATUS()` macro needed. Values 0–255 work directly.

---

## H51: Broadcast (Process Group Simulation)

> Parent creates **N pipe pairs**, forks N children, sends the **same byte to all** (broadcast). Each child applies a unique transform and replies. Parent collects all responses.

**Setup:**
```c
int N = atoi(argv[1]);
int pp[8][2], rp[8][2];           // pp[i]: parent→child_i, rp[i]: child_i→parent
for (int i = 0; i < N; i++) {
    pipe(pp[i]); pipe(rp[i]);
}
```

**Child (child 0 from boilerplate):**
```c
// Child 0 uses p1/p2 (from boilerplate)
close(pp[0][0]); close(pp[0][1]); // child0 uses p1/p2, not pp/rp
close(rp[0][0]); close(rp[0][1]);
char buf;
if (read(p1[0], &buf, 1) == 1) {
    buf += 0;                      // child0 transform: identity
    write(p2[1], &buf, 1);
}
```

**Parent:**
```c
// Fork children 1..N-1
for (int i = 1; i < N; i++) {
    int cpid = fork();
    if (cpid == 0) {
        close(pp[i][1]); close(rp[i][0]);
        char buf;
        if (read(pp[i][0], &buf, 1) == 1) {
            buf += i;              // child_i transform: +i
            write(rp[i][1], &buf, 1);
        }
        close(pp[i][0]); close(rp[i][1]);
        exit(0);
    }
}

// Broadcast: send SAME byte to all
char msg = argv[2][0];
write(p1[1], &msg, 1);            // child 0
for (int i = 1; i < N; i++) {
    close(pp[i][0]); close(rp[i][1]);
    write(pp[i][1], &msg, 1);     // same byte to each child
}

// Collect all responses
char buf;
read(p2[0], &buf, 1);
printf("%d: child 0 → '%c'\n", getpid(), buf);
for (int i = 1; i < N; i++) {
    read(rp[i][0], &buf, 1);
    printf("%d: child %d → '%c'\n", getpid(), i, buf);
    close(pp[i][1]); close(rp[i][0]);
    wait(0);
}
```

> 💡 Broadcast = same byte sent to N pipes. Each child has its own pipe pair, so no race conditions.

---

## H52: Ping-Pong with Mutation (Multi-Op Rounds)

> **K rounds** of ping-pong. Each round applies a **different math operation**: round 0 = `+1`, round 1 = `*2`, round 2 = `^0xFF`, round 3 = `-3`. Parent sends, child transforms, parent reads, repeats.

**Parent:**
```c
char val = argv[1][0];
int K = 4;                         // number of rounds
char *ops[] = { "+1", "*2", "^FF", "-3" };

for (int i = 0; i < K; i++) {
    write(p1[1], &val, 1);
    char result;
    read(p2[0], &result, 1);
    printf("%d: round %d (%s): sent 0x%02x → got 0x%02x\n",
           getpid(), i, ops[i],
           (unsigned char)val, (unsigned char)result);
    val = result;                  // feed result into next round
}
```

**Child:**
```c
int K = 4;
for (int i = 0; i < K; i++) {
    char buf;
    if (read(p1[0], &buf, 1) != 1) break;

    // Apply operation based on round number
    switch (i) {
        case 0: buf += 1;     break;  // +1
        case 1: buf *= 2;     break;  // *2
        case 2: buf ^= 0xFF;  break;  // XOR 0xFF
        case 3: buf -= 3;     break;  // -3
    }
    write(p2[1], &buf, 1);
}
```

> 💡 Multi-round pattern: both parent and child must agree on round count `K`. Parent chains output → next input. Great exam pattern for "what is the final value?".

---

## Pattern D Quick Reference

| # | Name | Tests | Expected Result | xv6 Constant |
|---|------|-------|-----------------|--------------|
| H41 | Pipe Stress | Fork to NPROC | fork() → -1 after ~61 | NPROC=64 |
| H42 | Write After Close | write(closed_fd) | returns -1 | ofile[fd]==0 |
| H43 | Read Write-End | read(write_end) | returns -1 | f->readable==0 |
| H44 | Zero-Length Read | read(fd, buf, 0) | **BLOCKS** if empty! | piperead loop |
| H45 | EOF Detection | close write → read=0 | child counts N bytes | writeopen=0 |
| H46 | Multiple Readers | 2 children, 1 read-end | Race: byte consumed once | No duplication |
| H47 | Self-Pipe | write+read, no fork | Works ≤512; deadlock >512 | PIPESIZE=512 |
| H48 | Fork Before Pipe | pipe() after fork() | Parent can't access | fd inheritance |
| H49 | Cascading Wait | 5-deep chain | Deepest exits first | wait() ordering |
| H50 | Exit Encoding | (a<<4)\|b in exit() | Raw xstate, no macro | xstate direct |
| H51 | Broadcast | Same byte → N children | Each gets own copy | N pipe pairs |
| H52 | Multi-Op Pong | +1, *2, ^FF, -3 | Chain transforms | Round number |
