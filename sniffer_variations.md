# Sniffer (Memory/Heap) — Coded Variations

> **Lab**: Sniffer (Week 3) — Exploit unzeroed heap pages to steal secrets from a terminated process.
> **Exploit**: xv6 omits `memset` in `uvmalloc()` and `kalloc()` → freed pages retain data → `sbrk()` returns stale pages.
> **Source files**: `user/sniffer.c` (attacker), `user/secret.c` (victim)

---

## Memory Layout (secret.c)

```
data[8*4096] (BSS — global, uninitialized, 32768 bytes total)
┌─────────────────────────────────────────────────────┐
│ Offset 0:   "This may help.\0"  (marker, 15 bytes)  │
│ Offset 12:  (available for length field in S8)      │
│ Offset 16:  "the-secret-string\0" (argv[1])         │
│ Offset 48:  (available for timestamp in S19)        │
│ Offset 56:  (available for next_offset in S21)      │
│ Offset 64:  (available for hash in S3)              │
│ ...                                                 │
│ Offset 32767: end of BSS                            │
└─────────────────────────────────────────────────────┘
```

> 💡 `secret.c` exits → `kfree()` returns pages to freelist → `sniffer.c` calls `sbrk()` → `kalloc()` returns SAME physical pages → data is still there.

---

## Core Boilerplate (sniffer.c)

```c
#include "kernel/types.h"
#include "kernel/fcntl.h"
#include "user/user.h"
#include "kernel/riscv.h"

int
main(int argc, char *argv[])
{
  // ════════════════════════════════════════════
  // ════════ MODIFY HERE [SETUP] ══════════════
  // Variables, sbrk calls, argv parsing, marker
  // ════════════════════════════════════════════
  int size = 10 * 4096;               // 10 pages (secret uses 8)
  char *p = sbrk(size);

  if (p == (char*)-1) {
    printf("sniffer: sbrk failed\n");
    exit(1);
  }

  char *marker = "This may help.";
  int marker_len = strlen(marker);
  // ════════ END SETUP ════════════════════════

  // ════════════════════════════════════════════
  // ════════ MODIFY HERE [SCAN LOGIC] ═════════
  // Memory traversal loop + secret extraction
  // ════════════════════════════════════════════
  for (int i = 0; i < size - 64; i++) {
    if (memcmp(p + i, marker, marker_len) == 0) {
      printf("%s\n", p + i + 16);      // secret at marker + 16
      exit(0);
    }
  }
  // ════════ END SCAN LOGIC ══════════════════

  printf("secret not found\n");
  exit(1);
}
```

### Drop Zone Guide

| Zone | What goes here | Lines in boilerplate |
|------|---------------|---------------------|
| `[SETUP]` | `sbrk()` calls, `argv` parsing, marker string, extra variables | Between includes and scan loop |
| `[SCAN LOGIC]` | `for`/`while` loop, `memcmp`, extraction, output formatting | The scan loop + exit |

---
---

# Pattern A — Logic Twists (S1–S14)

> **Scope**: Variations that change **how** we scan or **what** we extract from the same memory.
> **Rule**: Only the `[SETUP]` and `[SCAN LOGIC]` zones change.

---

## S1: Reverse Marker Search

> Scan memory **backwards** from highest address to lowest. Finds the **last** occurrence of the marker instead of the first.

**Scan Logic:**
```c
for (int i = size - 64; i >= 0; i--) {
    if (memcmp(p + i, marker, marker_len) == 0) {
        printf("%s\n", p + i + 16);
        exit(0);
    }
}
```

---

## S2: Substring Match

> Find a secret that **contains** a user-specified substring. Useful when multiple secrets exist and you want a specific one.

**Setup:**
```c
int size = 10 * 4096;
char *p = sbrk(size);
if (p == (char*)-1) { printf("sbrk failed\n"); exit(1); }
char *marker = "This may help.";
int marker_len = strlen(marker);
char *needle = argv[1];              // substring to find
```

**Scan Logic:**
```c
for (int i = 0; i < size - 64; i++) {
    if (memcmp(p + i, marker, marker_len) == 0) {
        char *secret = p + i + 16;
        // Check if secret contains the needle
        if (strstr(secret, needle) != 0) {
            printf("%s\n", secret);
            exit(0);
        }
    }
}
```

> 💡 `strstr()` is available in xv6 user space (defined in `ulib.c`). Returns pointer to first occurrence or 0.

---

## S3: Hash Verification

> Verify a **simple checksum** at offset +64 before trusting the secret. The secret writer stores `sum(bytes) & 0xFF` at offset +64.

**Scan Logic:**
```c
for (int i = 0; i < size - 128; i++) {
    if (memcmp(p + i, marker, marker_len) == 0) {
        char *secret = p + i + 16;
        unsigned char stored_hash = *(unsigned char*)(p + i + 64);

        // Compute checksum of secret
        unsigned char computed = 0;
        for (int j = 0; secret[j] != '\0'; j++)
            computed += (unsigned char)secret[j];
        computed &= 0xFF;

        if (computed == stored_hash) {
            printf("VERIFIED: %s\n", secret);
            exit(0);
        } else {
            printf("HASH MISMATCH: got 0x%x, expected 0x%x\n",
                   computed, stored_hash);
        }
    }
}
```

---

## S4: Page-Aligned Direct Access

> Compute the **exact page-aligned address** where the marker should be. Since BSS starts at a page boundary, skip directly to page N.

**Setup:**
```c
int size = 10 * 4096;
char *p = sbrk(size);
if (p == (char*)-1) { printf("sbrk failed\n"); exit(1); }
char *marker = "This may help.";
int marker_len = strlen(marker);
int target_page = atoi(argv[1]);     // which page (0-indexed)
```

**Scan Logic:**
```c
// Jump directly to the target page
int offset = target_page * 4096;
if (offset >= 0 && offset < size - 64) {
    if (memcmp(p + offset, marker, marker_len) == 0) {
        printf("found on page %d: %s\n", target_page, p + offset + 16);
        exit(0);
    }
}
// Fallback: scan all pages
for (int pg = 0; pg < size / 4096; pg++) {
    int off = pg * 4096;
    if (memcmp(p + off, marker, marker_len) == 0) {
        printf("found on page %d: %s\n", pg, p + off + 16);
        exit(0);
    }
}
```

---

## S5: Word-Aligned Scan

> Only check **8-byte boundaries** (word-aligned). Faster scan since compilers typically align global arrays to word boundaries.

**Scan Logic:**
```c
for (int i = 0; i < size - 64; i += 8) {   // step by 8 (word)
    if (memcmp(p + i, marker, marker_len) == 0) {
        printf("%s\n", p + i + 16);
        exit(0);
    }
}
```

> ⚠️ This works because `data[]` is a global array — BSS is word-aligned. Markers written at `data[0]` will be at an aligned offset.

---

## S6: Dual Marker (BEGIN/END Extraction)

> Extract everything between `BEGIN_SECRET` and `END_SECRET` markers. Tests multi-marker scanning.

**Setup:**
```c
int size = 10 * 4096;
char *p = sbrk(size);
if (p == (char*)-1) { printf("sbrk failed\n"); exit(1); }
char *begin_mark = "BEGIN_SECRET";
char *end_mark = "END_SECRET";
int blen = strlen(begin_mark);
int elen = strlen(end_mark);
```

**Scan Logic:**
```c
for (int i = 0; i < size - 128; i++) {
    if (memcmp(p + i, begin_mark, blen) == 0) {
        char *start = p + i + blen;
        // Find END marker
        for (int j = i + blen; j < size - elen; j++) {
            if (memcmp(p + j, end_mark, elen) == 0) {
                int secret_len = (p + j) - start;
                write(1, start, secret_len);  // print between markers
                write(1, "\n", 1);
                exit(0);
            }
        }
    }
}
```

---

## S7: Page Counting

> Count how many **distinct 4096-byte pages** contain the marker. Useful for understanding memory fragmentation.

**Scan Logic:**
```c
int found_pages = 0;
for (int pg = 0; pg < size / 4096; pg++) {
    char *page_start = p + (pg * 4096);
    for (int j = 0; j < 4096 - marker_len; j++) {
        if (memcmp(page_start + j, marker, marker_len) == 0) {
            printf("page %d: marker found at offset %d\n", pg, j);
            found_pages++;
            break;                     // count each page once
        }
    }
}
printf("total pages with marker: %d\n", found_pages);
if (found_pages == 0) exit(1);
exit(0);
```

---

## S8: Length-Prefixed Data (Non-Null-Terminated)

> The secret is NOT null-terminated. Instead, a **4-byte length** is stored at offset +12. Use `write()` with the exact length instead of `printf("%s")`.

**Scan Logic:**
```c
for (int i = 0; i < size - 64; i++) {
    if (memcmp(p + i, marker, marker_len) == 0) {
        int secret_len = *(int*)(p + i + 12);  // length at offset 12
        if (secret_len > 0 && secret_len < 256) {
            write(1, p + i + 16, secret_len);  // NOT printf — no null needed
            write(1, "\n", 1);
            exit(0);
        }
    }
}
```

> 💡 Cast `(int*)(p + i + 12)` reads 4 bytes as an integer. Requires proper alignment (offset 12 is 4-byte aligned ✓).

---

## S9: De-Interleaved Storage

> Secret bytes are stored at **even offsets** only (0, 2, 4, ...). Odd offsets contain garbage. Sniffer must de-interleave.

**Scan Logic:**
```c
for (int i = 0; i < size - 64; i++) {
    if (memcmp(p + i, marker, marker_len) == 0) {
        char *data = p + i + 16;
        char result[128];
        int k = 0;
        for (int j = 0; j < 256 && k < 127; j += 2) {
            if (data[j] == '\0') break;
            result[k++] = data[j];    // take even offsets only
        }
        result[k] = '\0';
        printf("%s\n", result);
        exit(0);
    }
}
```

---

## S10: Caesar-Shifted Secret

> Each byte of the secret is **shifted by +3** (Caesar cipher). Sniffer subtracts 3 to decode.

**Scan Logic:**
```c
for (int i = 0; i < size - 64; i++) {
    if (memcmp(p + i, marker, marker_len) == 0) {
        char *encoded = p + i + 16;
        char decoded[128];
        int j;
        for (j = 0; encoded[j] != '\0' && j < 127; j++)
            decoded[j] = encoded[j] - 3;  // Caesar shift: -3
        decoded[j] = '\0';
        printf("%s\n", decoded);
        exit(0);
    }
}
```

---

## S11: Multi-Secret Priority

> Multiple markers exist with a **priority byte** at offset +15. Print only the secret with the **highest priority** value.

**Scan Logic:**
```c
int best_prio = -1;
char best_secret[128];

for (int i = 0; i < size - 64; i++) {
    if (memcmp(p + i, marker, marker_len) == 0) {
        int prio = (unsigned char)*(p + i + 15);  // priority at offset 15
        if (prio > best_prio) {
            best_prio = prio;
            char *s = p + i + 16;
            int k;
            for (k = 0; s[k] != '\0' && k < 127; k++)
                best_secret[k] = s[k];
            best_secret[k] = '\0';
        }
    }
}

if (best_prio >= 0) {
    printf("priority %d: %s\n", best_prio, best_secret);
    exit(0);
}
```

---

## S12: Page-Aligned Scan Only

> Marker is always at the **start of a 4096-byte page boundary**. Skip non-aligned offsets for extreme speed.

**Scan Logic:**
```c
for (int i = 0; i < size; i += 4096) {   // jump by PGSIZE
    if (memcmp(p + i, marker, marker_len) == 0) {
        printf("page %d: %s\n", i / 4096, p + i + 16);
        exit(0);
    }
}
```

> 💡 BSS data starts at a page boundary. `data[0]` (where marker is stored) lands at a page start. So stepping by 4096 catches it on the first hit.

---

## S13: Backward Secret (Reversed String)

> Secret was written **reversed** in memory. Sniffer reverses it back to get the original.

**Scan Logic:**
```c
for (int i = 0; i < size - 64; i++) {
    if (memcmp(p + i, marker, marker_len) == 0) {
        char *rev = p + i + 16;
        int len = strlen(rev);
        char result[128];
        for (int j = 0; j < len && j < 127; j++)
            result[j] = rev[len - 1 - j];   // reverse
        result[len < 127 ? len : 127] = '\0';
        printf("%s\n", result);
        exit(0);
    }
}
```

---

## S14: Hex Output

> Print the secret as **hexadecimal pairs** instead of ASCII. Useful for binary/non-printable secrets.

**Scan Logic:**
```c
for (int i = 0; i < size - 64; i++) {
    if (memcmp(p + i, marker, marker_len) == 0) {
        char *secret = p + i + 16;
        for (int j = 0; secret[j] != '\0' && j < 64; j++)
            printf("%x ", (unsigned char)secret[j]);
        printf("\n");
        exit(0);
    }
}
```

---

## Pattern A Quick Reference

| # | Name | Zone Modified | Key Technique | Complexity |
|---|------|--------------|---------------|------------|
| S1 | Reverse scan | Scan | `i = size-64; i >= 0; i--` | Simple |
| S2 | Substring match | Setup + Scan | `strstr(secret, needle)` | Simple |
| S3 | Hash verify | Scan | Checksum at offset +64 | Medium |
| S4 | Page-aligned | Setup + Scan | `target_page * 4096` direct jump | Medium |
| S5 | Word-aligned | Scan | `i += 8` | Simple |
| S6 | Dual marker | Setup + Scan | BEGIN/END extraction | Medium |
| S7 | Page counting | Scan | Nested page+offset loop | Medium |
| S8 | Length-prefixed | Scan | `*(int*)(p+i+12)` + `write()` | Medium |
| S9 | De-interleave | Scan | Even offsets only | Simple |
| S10 | Caesar shift | Scan | `byte - 3` | Simple |
| S11 | Multi-priority | Scan | Track `best_prio`, compare | Medium |
| S12 | Page-only scan | Scan | `i += 4096` | Simple |
| S13 | Reversed | Scan | `rev[len-1-j]` | Simple |
| S14 | Hex output | Scan | `printf("%x", byte)` | Simple |

---
---

# Pattern B — Feature Extensions (S15–S24)

> **Scope**: Extensions that add new capabilities — configurable markers, multiple sbrk calls, linked list recovery, BSS exploitation, negative sbrk.
> **Rule**: Only the `[SETUP]` and `[SCAN LOGIC]` zones change.

---

## S15: Configurable Marker (argv)

> Marker string is passed via **command line** instead of hardcoded. Generalizes the sniffer to find any marker.

**Setup:**
```c
if (argc < 2) { printf("usage: sniffer <marker>\n"); exit(1); }
int size = 10 * 4096;
char *p = sbrk(size);
if (p == (char*)-1) { printf("sbrk failed\n"); exit(1); }
char *marker = argv[1];               // marker from command line
int marker_len = strlen(marker);
```

**Scan Logic:**
```c
for (int i = 0; i < size - 64; i++) {
    if (memcmp(p + i, marker, marker_len) == 0) {
        printf("found at offset %d: %s\n", i, p + i + marker_len + 2);
        exit(0);
    }
}
```

---

## S16: Page Heat Map

> Output a **heat map** showing which pages have non-zero content (likely contain remnant data from previous processes).

**Scan Logic:**
```c
int num_pages = size / 4096;
for (int pg = 0; pg < num_pages; pg++) {
    char *page = p + (pg * 4096);
    int nonzero = 0;
    for (int j = 0; j < 4096; j++) {
        if (page[j] != 0)
            nonzero++;
    }
    char heat;
    if (nonzero == 0)       heat = '.';  // empty
    else if (nonzero < 128) heat = 'o';  // some data
    else if (nonzero < 1024) heat = 'O'; // moderate
    else                     heat = '#'; // full

    printf("page %d: [%c] %d non-zero bytes\n", pg, heat, nonzero);

    // Also check for marker
    if (memcmp(page, marker, marker_len) == 0) {
        printf("  >> SECRET: %s\n", page + 16);
    }
}
exit(0);
```

---

## S17: Size from Argv

> `sbrk(N)` where N (in pages) is from command-line argument. Tests understanding of dynamic heap sizing.

**Setup:**
```c
if (argc < 2) { printf("usage: sniffer <pages>\n"); exit(1); }
int pages = atoi(argv[1]);
int size = pages * 4096;
char *p = sbrk(size);
if (p == (char*)-1) { printf("sbrk(%d) failed\n", size); exit(1); }
char *marker = "This may help.";
int marker_len = strlen(marker);
```

**Scan Logic:** (same as boilerplate)

---

## S18: Double sbrk (Two Regions)

> Call `sbrk()` **twice**. Scan both regions. Tests understanding that consecutive sbrk calls return contiguous memory (heap grows upward).

**Setup:**
```c
int size1 = 5 * 4096;
int size2 = 5 * 4096;
char *p1 = sbrk(size1);
if (p1 == (char*)-1) { printf("sbrk1 failed\n"); exit(1); }
char *p2 = sbrk(size2);
if (p2 == (char*)-1) { printf("sbrk2 failed\n"); exit(1); }
char *marker = "This may help.";
int marker_len = strlen(marker);
printf("region1: %p (size %d)\n", p1, size1);
printf("region2: %p (size %d)\n", p2, size2);
```

**Scan Logic:**
```c
// Scan region 1
for (int i = 0; i < size1 - 64; i++) {
    if (memcmp(p1 + i, marker, marker_len) == 0) {
        printf("region1 offset %d: %s\n", i, p1 + i + 16);
        exit(0);
    }
}
// Scan region 2
for (int i = 0; i < size2 - 64; i++) {
    if (memcmp(p2 + i, marker, marker_len) == 0) {
        printf("region2 offset %d: %s\n", i, p2 + i + 16);
        exit(0);
    }
}
```

> 💡 `p2 == p1 + size1` — sbrk returns contiguous memory. Both regions can be scanned as one big block: `for (i = 0; i < size1 + size2 - 64; i++)`.

---

## S19: Timestamp Recovery

> Secret writer also stores `uptime()` at offset +48. Sniffer recovers and prints the timestamp alongside the secret.

**Scan Logic:**
```c
for (int i = 0; i < size - 64; i++) {
    if (memcmp(p + i, marker, marker_len) == 0) {
        char *secret = p + i + 16;
        int timestamp = *(int*)(p + i + 48);  // uptime at offset 48
        printf("secret: %s (written at tick %d)\n", secret, timestamp);
        exit(0);
    }
}
```

---

## S20: Binary Dump (Hexdump Style)

> Dump **64 bytes** starting from the marker in hex + ASCII format, like the `hexdump` command.

**Scan Logic:**
```c
for (int i = 0; i < size - 64; i++) {
    if (memcmp(p + i, marker, marker_len) == 0) {
        printf("=== DUMP at offset %d ===\n", i);
        for (int row = 0; row < 4; row++) {      // 4 rows × 16 bytes = 64
            printf("%04x: ", row * 16);
            // Hex
            for (int col = 0; col < 16; col++)
                printf("%x ", (unsigned char)p[i + row*16 + col]);
            printf(" |");
            // ASCII
            for (int col = 0; col < 16; col++) {
                char c = p[i + row*16 + col];
                printf("%c", (c >= 0x20 && c <= 0x7e) ? c : '.');
            }
            printf("|\n");
        }
        exit(0);
    }
}
```

---

## S21: Linked List Recovery

> Secret writer stored **3 records** as a linked list using relative offsets. Each record: `[4-byte next_offset][data...]`. Sniffer follows the chain.

**Scan Logic:**
```c
for (int i = 0; i < size - 256; i++) {
    if (memcmp(p + i, marker, marker_len) == 0) {
        int current = i + 16;          // first record starts at marker+16
        int rec = 0;
        while (current > 0 && current < size - 64) {
            int next_off = *(int*)(p + current);       // relative offset to next
            char *data = p + current + 4;              // data after next-pointer
            printf("record %d: %s\n", rec, data);
            if (next_off == 0) break;                  // end of chain
            current = current + next_off;              // follow chain
            rec++;
            if (rec > 10) break;                       // safety limit
        }
        exit(0);
    }
}
```

> 💡 Each record layout: `[next_offset: int(4)][data: char[]]`. `next_off == 0` means end of chain.

---

## S22: Freed Stack Remnants

> Fork a child that writes a secret to its **stack** (local variable), then exits. Parent sniffs the freed stack pages.

> ⚠️ **Replace entire boilerplate** — standalone program:
```c
#include "kernel/types.h"
#include "kernel/fcntl.h"
#include "user/user.h"
#include "kernel/riscv.h"

int main() {
    int pid = fork();
    if (pid == 0) {
        // Child: write secret on the STACK (local variable)
        char stack_secret[64];
        strcpy(stack_secret, "STACK_MARKER");
        strcpy(stack_secret + 16, "stack-data-here");
        exit(0);                       // pages freed on exit
    }
    wait(0);                           // wait for child to exit + free pages

    // Now try to find the stack data in freshly allocated pages
    int size = 20 * 4096;             // allocate more to cover stack pages
    char *p = sbrk(size);
    if (p == (char*)-1) { printf("sbrk failed\n"); exit(1); }

    char *marker = "STACK_MARKER";
    int marker_len = strlen(marker);
    for (int i = 0; i < size - 64; i++) {
        if (memcmp(p + i, marker, marker_len) == 0) {
            printf("found stack remnant: %s\n", p + i + 16);
            exit(0);
        }
    }
    printf("stack data not found (may have been overwritten)\n");
    exit(1);
}
```

> ⚠️ Stack pages are freed on exit but may be reused by kernel before sniffer runs. Less reliable than BSS exploit.

---

## S23: BSS Region Scan

> Allocate via `sbrk()` enough pages to cover the **entire BSS region** of a previous process. Since BSS is a large uninitialised global array, its pages are prime targets.

**Setup:**
```c
// secret.c uses data[8*4096] = 32768 bytes = 8 pages
// Allocate 12 pages to be safe (covers BSS + possible alignment)
int size = 12 * 4096;
char *p = sbrk(size);
if (p == (char*)-1) { printf("sbrk failed\n"); exit(1); }
char *marker = "This may help.";
int marker_len = strlen(marker);
printf("scanning %d pages for BSS remnants...\n", size / 4096);
```

**Scan Logic:**
```c
int found = 0;
for (int pg = 0; pg < size / 4096; pg++) {
    char *page = p + (pg * 4096);
    // BSS pages start with marker at page offset 0
    if (memcmp(page, marker, marker_len) == 0) {
        printf("BSS page %d: secret = \"%s\"\n", pg, page + 16);
        found = 1;
    }
}
if (!found) {
    // Fallback: byte-by-byte scan
    for (int i = 0; i < size - 64; i++) {
        if (memcmp(p + i, marker, marker_len) == 0) {
            printf("found at byte offset %d: %s\n", i, p + i + 16);
            exit(0);
        }
    }
}
exit(found ? 0 : 1);
```

---

## S24: Negative sbrk (Shrink + Regrow)

> Allocate memory, find secret, then `sbrk(-size)` to free it, then `sbrk(size)` again to re-allocate. Verify if data **persists** after shrink+grow cycle.

> ⚠️ **Replace entire boilerplate** — standalone:
```c
#include "kernel/types.h"
#include "kernel/fcntl.h"
#include "user/user.h"
#include "kernel/riscv.h"

int main() {
    int size = 10 * 4096;
    char *marker = "This may help.";
    int marker_len = strlen(marker);

    // Phase 1: allocate and find secret
    char *p1 = sbrk(size);
    if (p1 == (char*)-1) { printf("sbrk1 failed\n"); exit(1); }

    int found_offset = -1;
    for (int i = 0; i < size - 64; i++) {
        if (memcmp(p1 + i, marker, marker_len) == 0) {
            printf("phase1: found at offset %d → \"%s\"\n", i, p1 + i + 16);
            found_offset = i;
            break;
        }
    }

    // Phase 2: shrink heap (free pages)
    printf("shrinking heap by %d bytes...\n", size);
    sbrk(-size);

    // Phase 3: regrow heap (pages may be reused)
    char *p2 = sbrk(size);
    if (p2 == (char*)-1) { printf("sbrk3 failed\n"); exit(1); }

    printf("p1=%p, p2=%p (same? %s)\n", p1, p2,
           p1 == p2 ? "YES" : "NO");

    // Phase 4: check if data survived
    if (found_offset >= 0 && memcmp(p2 + found_offset, marker, marker_len) == 0) {
        printf("phase3: data SURVIVED shrink+grow → \"%s\"\n",
               p2 + found_offset + 16);
    } else {
        printf("phase3: data LOST after shrink+grow\n");
    }
    exit(0);
}
```

> 💡 **Expected**: Data SURVIVES because `sbrk(-size)` calls `kfree()` which adds pages to freelist. `sbrk(size)` calls `kalloc()` which pops from the same freelist (LIFO). Same physical pages, same data.

---

## Pattern B Quick Reference

| # | Name | Zone Modified | Key Technique | Complexity |
|---|------|--------------|---------------|------------|
| S15 | Configurable marker | Setup | `argv[1]` as marker | Simple |
| S16 | Page heat map | Scan | Count non-zero bytes per page | Medium |
| S17 | Size from argv | Setup | `atoi(argv[1]) * 4096` | Simple |
| S18 | Double sbrk | Setup + Scan | Two regions, contiguous | Medium |
| S19 | Timestamp | Scan | `*(int*)(p+i+48)` | Simple |
| S20 | Binary dump | Scan | 4×16 hex+ASCII grid | Medium |
| S21 | Linked list | Scan | Follow `next_offset` chain | Medium |
| S22 | Stack remnants | Full replace | fork+exit, scan freed stack | Medium |
| S23 | BSS region | Setup + Scan | Page-aligned BSS scan | Medium |
| S24 | Negative sbrk | Full replace | sbrk(-size)+sbrk(size) | Medium |

---
---

# Pattern C — Combo Tasks (S25–S34)

> **Scope**: Each variation is a **two-part combo**: kernel code (in `kalloc.c`, `sysproc.c`, or `vm.c`) + user-space sniffer program.
> **Kernel structures verified from xv6-src-booklet**: `struct run { struct run *next; }`, `kmem { spinlock lock; struct run *freelist; }`, `walk(pagetable, va, alloc)` → `pte_t*`, PTE flags (V=1, R=2, W=4, X=8, U=16).

---

## S25: `memscrub` Syscall — Zero All Free Pages

> Walks the **kernel free list** and zeroes every free page. After calling this, `sbrk()` returns clean pages and sniffer finds nothing. Tests understanding of the `kmem.freelist` linked list.

**Kernel (`kalloc.c`):**
```c
uint64
sys_memscrub(void)
{
  struct run *r;
  int count = 0;

  acquire(&kmem.lock);
  r = kmem.freelist;
  while (r) {
    memset((char*)r + sizeof(struct run), 0,
           PGSIZE - sizeof(struct run));  // preserve next pointer!
    count++;
    r = r->next;
  }
  release(&kmem.lock);
  return count;  // number of pages scrubbed
}
```

**User program:**
```c
#include "kernel/types.h"
#include "user/user.h"

int main() {
    int scrubbed = memscrub();
    printf("scrubbed %d free pages\n", scrubbed);

    // Now try to sniff — should fail
    int size = 10 * 4096;
    char *p = sbrk(size);
    char *marker = "This may help.";
    int marker_len = strlen(marker);

    for (int i = 0; i < size - 64; i++) {
        if (memcmp(p + i, marker, marker_len) == 0) {
            printf("FOUND (scrub failed!): %s\n", p + i + 16);
            exit(1);
        }
    }
    printf("secret NOT found — memscrub worked!\n");
    exit(0);
}
```

> ⚠️ Must preserve `sizeof(struct run)` bytes at the start of each free page — that's where the `next` pointer lives!

---

## S26: `getfreepages` Syscall — Count Free Pages

> Walks `kmem.freelist` and counts nodes. Returns the number of **free physical pages** in the system.

**Kernel (`kalloc.c`):**
```c
uint64
sys_getfreepages(void)
{
  struct run *r;
  int count = 0;

  acquire(&kmem.lock);
  for (r = kmem.freelist; r; r = r->next)
    count++;
  release(&kmem.lock);
  return count;
}
```

**User program:**
```c
#include "kernel/types.h"
#include "user/user.h"

int main() {
    int before = getfreepages();
    printf("free pages before sbrk: %d\n", before);

    char *p = sbrk(5 * 4096);   // allocate 5 pages
    int after = getfreepages();
    printf("free pages after sbrk(5pg): %d (diff=%d)\n",
           after, before - after);

    sbrk(-5 * 4096);            // free them back
    int restored = getfreepages();
    printf("free pages after sbrk(-5pg): %d\n", restored);
    exit(0);
}
```

> 💡 `before - after` should equal 5 (one page per 4096 bytes allocated).

---

## S27: `pageinfo` Syscall — Get PTE Flags for VA

> Uses `walk()` to look up the **page table entry** for a given virtual address. Returns the raw PTE flags. Tests understanding of Sv39 page tables.

**Kernel (`sysproc.c`):**
```c
// Need: extern pte_t* walk(pagetable_t, uint64, int);
// Defined in vm.c

uint64
sys_pageinfo(void)
{
  uint64 va;
  argaddr(0, &va);

  struct proc *p = myproc();
  pte_t *pte = walk(p->pagetable, va, 0);

  if (pte == 0 || (*pte & PTE_V) == 0)
    return -1;  // not mapped

  return PTE_FLAGS(*pte);  // return just the flag bits
}
```

**User program:**
```c
#include "kernel/types.h"
#include "user/user.h"

int main() {
    char *p = sbrk(4096);

    uint64 flags = pageinfo((uint64)p);
    printf("PTE flags for %p: 0x%x\n", p, flags);
    printf("  Valid=%d Read=%d Write=%d Exec=%d User=%d\n",
           (flags >> 0) & 1,    // PTE_V
           (flags >> 1) & 1,    // PTE_R
           (flags >> 2) & 1,    // PTE_W
           (flags >> 3) & 1,    // PTE_X
           (flags >> 4) & 1);   // PTE_U
    exit(0);
}
```

> 💡 PTE flags: `V=bit0, R=bit1, W=bit2, X=bit3, U=bit4`. User heap pages should have `V|R|W|U` = `0x17`.

---

## S28: `markpage` Syscall — Sensitive Page (Zero-on-Free)

> Sets a global flag that makes `kfree()` **zero every page** before adding it to the free list. Prevents sniffer after secret exits.

**Kernel (`kalloc.c` — modified kfree):**
```c
int scrub_on_free = 0;  // global flag

uint64
sys_markpage(void)
{
  int enable;
  argint(0, &enable);
  scrub_on_free = enable;
  return 0;
}

// Modified kfree:
void
kfree(void *pa)
{
  struct run *r;
  // ... existing validation ...
  if (scrub_on_free)
    memset(pa, 0, PGSIZE);       // zero BEFORE adding to freelist

  r = (struct run*)pa;
  acquire(&kmem.lock);
  r->next = kmem.freelist;
  kmem.freelist = r;
  release(&kmem.lock);
}
```

**User program:**
```c
#include "kernel/types.h"
#include "user/user.h"

int main() {
    markpage(1);   // enable scrub-on-free
    printf("scrub-on-free ENABLED\n");
    // Now run: $ secret ict1012; sniffer → should find nothing
    exit(0);
}
```

---

## S29: Secret + Sniffer in One Process

> No separate programs. **Fork** a child that acts as `secret.c`, child exits, parent acts as `sniffer.c`. All in one file.

> ⚠️ **Replace entire boilerplate** — standalone:
```c
#include "kernel/types.h"
#include "kernel/fcntl.h"
#include "user/user.h"
#include "kernel/riscv.h"

#define DATASIZE (8*4096)
char data[DATASIZE];               // BSS — global array (like secret.c)

int main(int argc, char *argv[]) {
    if (argc < 2) { printf("usage: combo <secret>\n"); exit(1); }

    int pid = fork();
    if (pid == 0) {
        // ── Child = secret.c ──
        strcpy(data, "This may help.");
        strcpy(data + 16, argv[1]);
        exit(0);                   // frees BSS pages
    }
    wait(0);                       // wait for child to exit

    // ── Parent = sniffer.c ──
    int size = 10 * 4096;
    char *p = sbrk(size);
    if (p == (char*)-1) { printf("sbrk failed\n"); exit(1); }

    char *marker = "This may help.";
    int mlen = strlen(marker);
    for (int i = 0; i < size - 64; i++) {
        if (memcmp(p + i, marker, mlen) == 0) {
            printf("sniffed: %s\n", p + i + 16);
            exit(0);
        }
    }
    printf("not found\n");
    exit(1);
}
```

> 💡 Child writes to BSS, exits (pages freed), parent sbrk's (gets same pages). Same exploit, one file.

---

## S30: `meminfo` Syscall — Get Process Heap Size

> Returns `myproc()->sz` — the **current virtual address space size** (heap break) for the calling process.

**Kernel (`sysproc.c`):**
```c
uint64
sys_meminfo(void)
{
  return myproc()->sz;
}
```

**User program:**
```c
#include "kernel/types.h"
#include "user/user.h"

int main() {
    uint64 before = meminfo();
    printf("sz before sbrk: %p\n", before);

    sbrk(5 * 4096);
    uint64 after = meminfo();
    printf("sz after sbrk(5pg): %p (grew by %d bytes)\n",
           after, (int)(after - before));

    sbrk(-5 * 4096);
    uint64 shrunk = meminfo();
    printf("sz after sbrk(-5pg): %p\n", shrunk);
    exit(0);
}
```

---

## S31: Heap Canary

> Check a **magic canary value** at marker offset +60 before trusting the secret. If canary is corrupt, the data is stale/garbage.

**Scan Logic:**
```c
#define CANARY 0xDEADBEEF

for (int i = 0; i < size - 64; i++) {
    if (memcmp(p + i, marker, marker_len) == 0) {
        uint canary = *(uint*)(p + i + 60);
        if (canary == CANARY) {
            printf("CANARY OK: %s\n", p + i + 16);
            exit(0);
        } else {
            printf("CANARY CORRUPT at offset %d: 0x%x != 0x%x\n",
                   i, canary, CANARY);
        }
    }
}
```

> 💡 Secret writer must store `0xDEADBEEF` at `data[60]`: `*(uint*)(data + 60) = 0xDEADBEEF;`

---

## S32: Multi-Process Secret (Two Secrets)

> Two different `secret` programs ran with different markers. Sniffer finds **both**.

**Setup:**
```c
int size = 20 * 4096;              // more pages = more coverage
char *p = sbrk(size);
if (p == (char*)-1) { printf("sbrk failed\n"); exit(1); }
char *marker1 = "This may help.";
char *marker2 = "Another hint..";   // second marker
int mlen1 = strlen(marker1);
int mlen2 = strlen(marker2);
```

**Scan Logic:**
```c
int found = 0;
for (int i = 0; i < size - 64; i++) {
    if (memcmp(p + i, marker1, mlen1) == 0) {
        printf("secret1: %s\n", p + i + 16);
        found++;
    }
    if (memcmp(p + i, marker2, mlen2) == 0) {
        printf("secret2: %s\n", p + i + 16);
        found++;
    }
}
printf("found %d secrets\n", found);
exit(found > 0 ? 0 : 1);
```

---

## S33: `report` Syscall — Kernel Printf for Secrets

> Syscall that takes a **user-space address** and prints it via kernel `printf`. Demonstrates kernel-assisted introspection.

**Kernel (`sysproc.c`):**
```c
uint64
sys_report(void)
{
  uint64 addr;
  int len;
  argaddr(0, &addr);
  argint(1, &len);

  struct proc *p = myproc();
  char buf[128];
  if (len > 127) len = 127;

  if (copyin(p->pagetable, buf, addr, len) < 0)
    return -1;
  buf[len] = '\0';

  printf("[KERNEL REPORT pid=%d]: %s\n", p->pid, buf);
  return 0;
}
```

**User program:**
```c
for (int i = 0; i < size - 64; i++) {
    if (memcmp(p + i, marker, marker_len) == 0) {
        char *secret = p + i + 16;
        report(secret, strlen(secret));   // kernel prints it
        exit(0);
    }
}
```

---

## S34: Anti-Sniffer (Defensive Zeroing)

> Program that **explicitly zeroes** its memory before exiting. Prevents the sniffer exploit. User-space defense.

> ⚠️ **Replace entire boilerplate** — standalone:
```c
#include "kernel/types.h"
#include "user/user.h"

#define DATASIZE (8*4096)
char data[DATASIZE];

int main(int argc, char *argv[]) {
    if (argc < 2) { printf("usage: antisecret <secret>\n"); exit(1); }

    strcpy(data, "This may help.");
    strcpy(data + 16, argv[1]);

    printf("secret stored. now zeroing before exit...\n");

    // DEFENSE: zero all sensitive data before exiting
    memset(data, 0, DATASIZE);

    exit(0);
    // Pages freed by exit(), but content is already zeroed
    // Sniffer will find all zeros — no secret!
}
```

> 💡 This is the **countermeasure** to the sniffer. Even without kernel fixes, user programs can `memset(0)` their sensitive data before exiting.

---

## Pattern C Quick Reference

| # | Name | Syscall | Kernel File | Key Concept |
|---|------|---------|------------|-------------|
| S25 | memscrub | `sys_memscrub` | kalloc.c | Walk freelist, memset(0) each page |
| S26 | getfreepages | `sys_getfreepages` | kalloc.c | Count freelist nodes |
| S27 | pageinfo | `sys_pageinfo` | sysproc.c | `walk()` + `PTE_FLAGS()` |
| S28 | markpage | `sys_markpage` | kalloc.c | Global flag → zero in kfree() |
| S29 | combo | — (user only) | — | fork+exit+sbrk in one file |
| S30 | meminfo | `sys_meminfo` | sysproc.c | `return myproc()->sz` |
| S31 | heap canary | — (user only) | — | Magic 0xDEADBEEF at +60 |
| S32 | multi-secret | — (user only) | — | Two markers, two secrets |
| S33 | report | `sys_report` | sysproc.c | `copyin` + kernel printf |
| S34 | anti-sniffer | — (user only) | — | `memset(data, 0)` before exit |

---
---

# Pattern D — Mutation Dimensions (S35–S51)

> **Scope**: Edge cases, error paths, and stress tests for the sniffer boilerplate.
> **Rule**: Only the `[SETUP]` and `[SCAN LOGIC]` zones change (unless noted as standalone).

---

## S35: sbrk Failure Handling

> Request an **impossibly large** allocation. `sbrk()` returns `(char*)-1`. Test graceful failure.

**Setup:**
```c
int huge = 1 << 30;                // 1 GB — way more than available
char *p = sbrk(huge);

if (p == (char*)-1) {
    printf("sbrk(%d) failed as expected\n", huge);
    // Try a reasonable size instead
    int size = 10 * 4096;
    p = sbrk(size);
    if (p == (char*)-1) { printf("even small sbrk failed!\n"); exit(1); }
    // Continue with normal scan...
    char *marker = "This may help.";
    int marker_len = strlen(marker);
```

**Scan Logic:** (same as boilerplate, using the fallback `p` and `size`)

> ⚠️ `sbrk()` returns `(char*)-1` on failure, NOT null. Always cast-compare to `(char*)-1`.

---

## S36: sbrk(0) — Get Current Break

> `sbrk(0)` returns the **current program break** without allocating anything. Useful for measuring heap growth.

**Setup:**
```c
char *brk_before = sbrk(0);       // query current break
printf("break before: %p\n", brk_before);

int size = 10 * 4096;
char *p = sbrk(size);
if (p == (char*)-1) { printf("sbrk failed\n"); exit(1); }

char *brk_after = sbrk(0);        // query again
printf("break after:  %p (grew by %d)\n",
       brk_after, (int)(brk_after - brk_before));

char *marker = "This may help.";
int marker_len = strlen(marker);
```

**Scan Logic:** (same as boilerplate)

> 💡 `sbrk(0)` is equivalent to `meminfo()` (S30) but from user space. `p == brk_before` always.

---

## S37: Manual memcmp (Byte-by-Byte)

> Replace `memcmp()` with a **hand-written byte loop**. Tests C pointer arithmetic understanding.

**Scan Logic:**
```c
for (int i = 0; i < size - 64; i++) {
    // Manual memcmp
    int match = 1;
    for (int j = 0; j < marker_len; j++) {
        if (*(p + i + j) != *(marker + j)) {
            match = 0;
            break;
        }
    }
    if (match) {
        printf("%s\n", p + i + 16);
        exit(0);
    }
}
```

> 💡 `*(p + i + j)` is identical to `p[i + j]`. Both are char pointer dereference.

---

## S38: Page Boundary Marker

> Marker is placed so it **spans two pages** (starts near the end of one page, continues into the next). Tests that `memcmp` works across page boundaries.

**Scan Logic:**
```c
// Standard byte-by-byte scan ALREADY handles page boundaries
// because memcmp reads contiguous virtual addresses
// xv6 maps pages contiguously in VA space even if PA is different
for (int i = 0; i < size - 64; i++) {
    if (memcmp(p + i, marker, marker_len) == 0) {
        int page_num = i / 4096;
        int page_off = i % 4096;
        printf("found at page %d, offset %d", page_num, page_off);
        if (page_off + marker_len > 4096)
            printf(" (SPANS page boundary!)");
        printf(": %s\n", p + i + 16);
        exit(0);
    }
}
```

> 💡 Spanning works because `sbrk` returns a **contiguous virtual range**. The physical pages may be non-contiguous, but the page table maps them sequentially.

---

## S39: Multiple sbrk + Freed Region

> `sbrk(+)` → `sbrk(-)` → `sbrk(+)`. Pages freed in step 2 are recycled in step 3. Tests LIFO page reuse.

**Setup:**
```c
// Phase 1: allocate and immediately free
char *p1 = sbrk(5 * 4096);
sbrk(-5 * 4096);                  // free 5 pages back to kernel

// Phase 2: allocate more — should get same pages back (LIFO)
int size = 10 * 4096;
char *p = sbrk(size);
if (p == (char*)-1) { printf("sbrk failed\n"); exit(1); }

printf("p1=%p, p=%p\n", p1, p);  // p == p1 (same VA)

char *marker = "This may help.";
int marker_len = strlen(marker);
```

**Scan Logic:** (same as boilerplate)

> 💡 `kfree` pushes to front of freelist (LIFO). `kalloc` pops from front. So the most recently freed pages are allocated first.

---

## S40: Large Secret (> 1 Page)

> Secret is **larger than 4096 bytes** and spans multiple pages. Scanner must not stop at page boundaries.

**Setup:**
```c
int size = 20 * 4096;              // larger allocation
char *p = sbrk(size);
if (p == (char*)-1) { printf("sbrk failed\n"); exit(1); }
char *marker = "This may help.";
int marker_len = strlen(marker);
```

**Scan Logic:**
```c
for (int i = 0; i < size - 8192; i++) {  // need room for large secret
    if (memcmp(p + i, marker, marker_len) == 0) {
        char *secret = p + i + 16;
        // Don't trust strlen — use strnlen-like approach
        int len = 0;
        while (secret[len] != '\0' && len < 8000)
            len++;
        printf("large secret (%d bytes): ", len);
        write(1, secret, len);
        write(1, "\n", 1);
        exit(0);
    }
}
```

---

## S41: Embedded Structs

> Secret contains an **array of structs** at offset +16. Each struct: `{ int id; char name[12]; }` = 16 bytes.

**Scan Logic:**
```c
struct record { int id; char name[12]; };

for (int i = 0; i < size - 256; i++) {
    if (memcmp(p + i, marker, marker_len) == 0) {
        struct record *recs = (struct record*)(p + i + 16);
        int count = *(int*)(p + i + 12);  // count at offset 12
        if (count <= 0 || count > 10) count = 3; // safety

        for (int r = 0; r < count; r++) {
            printf("record[%d]: id=%d name=%s\n",
                   r, recs[r].id, recs[r].name);
        }
        exit(0);
    }
}
```

> 💡 Cast `(struct record*)(p + i + 16)` — treating raw bytes as a struct array. Alignment matters: offset 16 is 4- and 8-byte aligned ✓.

---

## S42: Packed Integers

> Extract **4 integers** stored at known offsets from the marker: `+16`, `+20`, `+24`, `+28`.

**Scan Logic:**
```c
for (int i = 0; i < size - 64; i++) {
    if (memcmp(p + i, marker, marker_len) == 0) {
        int a = *(int*)(p + i + 16);
        int b = *(int*)(p + i + 20);
        int c = *(int*)(p + i + 24);
        int d = *(int*)(p + i + 28);
        printf("ints: %d %d %d %d\n", a, b, c, d);
        printf("sum = %d\n", a + b + c + d);
        exit(0);
    }
}
```

> 💡 `*(int*)(p + i + 16)` reads 4 bytes at that address as a little-endian int (RISC-V is little-endian).

---

## S43: Child sbrk, Parent sbrk (Cross-Process)

> Fork → child calls `sbrk`, writes data, exits → parent calls `sbrk` and tries to find child's data. Tests cross-process page recycling.

> ⚠️ **Replace entire boilerplate** — standalone:
```c
#include "kernel/types.h"
#include "user/user.h"

int main() {
    int pid = fork();
    if (pid == 0) {
        // Child: allocate and write
        char *cp = sbrk(4096);
        strcpy(cp, "CHILD_MARKER");
        strcpy(cp + 16, "child-secret");
        exit(0);                   // child's sbrk pages freed
    }
    wait(0);

    // Parent: allocate — may get child's freed pages
    int size = 10 * 4096;
    char *p = sbrk(size);
    if (p == (char*)-1) { printf("sbrk failed\n"); exit(1); }

    char *marker = "CHILD_MARKER";
    int mlen = strlen(marker);
    for (int i = 0; i < size - 64; i++) {
        if (memcmp(p + i, marker, mlen) == 0) {
            printf("found child data: %s\n", p + i + 16);
            exit(0);
        }
    }
    printf("child data not found (pages may have been reused elsewhere)\n");
    exit(1);
}
```

---

## S44: Time-Limited Sniffer

> Abort the scan after **100 ticks** (using `uptime()`). Prevents hanging on large allocations.

**Setup:**
```c
int size = 50 * 4096;              // extra large
char *p = sbrk(size);
if (p == (char*)-1) { printf("sbrk failed\n"); exit(1); }
char *marker = "This may help.";
int marker_len = strlen(marker);
int start_time = uptime();
```

**Scan Logic:**
```c
for (int i = 0; i < size - 64; i++) {
    if (i % 4096 == 0) {           // check time every page
        if (uptime() - start_time > 100) {
            printf("TIMEOUT after %d ticks, scanned %d bytes\n",
                   uptime() - start_time, i);
            exit(1);
        }
    }
    if (memcmp(p + i, marker, marker_len) == 0) {
        printf("found in %d ticks: %s\n",
               uptime() - start_time, p + i + 16);
        exit(0);
    }
}
```

---

## S45: Verbose Mode (Print Addresses)

> Print the **hex virtual address** of every marker found, not just the secret content.

**Scan Logic:**
```c
for (int i = 0; i < size - 64; i++) {
    if (memcmp(p + i, marker, marker_len) == 0) {
        printf("[0x%x] offset=%d page=%d: %s\n",
               (uint)(uint64)(p + i),
               i, i / 4096,
               p + i + 16);
        // Don't exit — find ALL markers
    }
}
exit(0);
```

---

## S46: Pattern Frequency Counter (Byte Histogram)

> Count occurrences of each **byte value** (0x00–0xFF) in the scanned region. Print a histogram of the top 5 most common non-zero bytes.

**Scan Logic:**
```c
int freq[256];
memset(freq, 0, sizeof(freq));

for (int i = 0; i < size; i++)
    freq[(unsigned char)p[i]]++;

// Find top 5 non-zero bytes
for (int top = 0; top < 5; top++) {
    int best = -1, best_count = 0;
    for (int b = 1; b < 256; b++) {  // skip 0x00
        if (freq[b] > best_count) {
            best_count = freq[b];
            best = b;
        }
    }
    if (best < 0) break;
    printf("0x%x ('%c'): %d times\n",
           best, (best >= 0x20 && best <= 0x7e) ? best : '.', best_count);
    freq[best] = 0;                // remove from next iteration
}

// Also do normal marker scan
for (int i = 0; i < size - 64; i++) {
    if (memcmp(p + i, marker, marker_len) == 0) {
        printf("secret: %s\n", p + i + 16);
        exit(0);
    }
}
exit(1);
```

---

## S47: /dev/mem — Why It Doesn't Work in xv6

> xv6 has **no `/dev/mem`**. Unlike Linux, there's no device file to read physical memory directly. This variation explains the limitation and shows the sbrk-based workaround.

**Scan Logic:**
```c
// Attempt to open /dev/mem (will fail in xv6)
int fd = open("/dev/mem", 0);
if (fd < 0) {
    printf("/dev/mem NOT available (xv6 has no devfs)\n");
    printf("falling back to sbrk-based sniffer...\n");
}

// Standard sbrk-based scan
for (int i = 0; i < size - 64; i++) {
    if (memcmp(p + i, marker, marker_len) == 0) {
        printf("found via sbrk: %s\n", p + i + 16);
        exit(0);
    }
}
```

> 💡 Linux `/dev/mem` maps physical RAM into user space via `mmap`. xv6 has no mmap, no devfs, and no character device for memory.

---

## S48: Sniffer with Pipe Output

> Fork a **sniffer child** that sends the found secret through a **pipe** to the parent instead of printing directly.

> ⚠️ **Replace entire boilerplate** — standalone:
```c
#include "kernel/types.h"
#include "user/user.h"

int main() {
    int p1[2];
    pipe(p1);

    int pid = fork();
    if (pid == 0) {
        // Child = sniffer
        close(p1[0]);
        int size = 10 * 4096;
        char *p = sbrk(size);
        if (p == (char*)-1) { write(p1[1], "FAIL", 4); close(p1[1]); exit(1); }

        char *marker = "This may help.";
        int mlen = strlen(marker);
        for (int i = 0; i < size - 64; i++) {
            if (memcmp(p + i, marker, mlen) == 0) {
                char *secret = p + i + 16;
                write(p1[1], secret, strlen(secret));
                close(p1[1]);
                exit(0);
            }
        }
        write(p1[1], "NOTFOUND", 8);
        close(p1[1]);
        exit(1);
    }

    // Parent reads result from pipe
    close(p1[1]);
    char buf[256];
    int n = read(p1[0], buf, 255);
    buf[n] = '\0';
    close(p1[0]);
    wait(0);
    printf("sniffer reported: %s\n", buf);
    exit(0);
}
```

---

## S49: Double-Free Detection

> Modify `kfree()` to **detect double-free** — check if the page is already in the free list before adding it.

**Kernel (`kalloc.c`):**
```c
void
kfree(void *pa)
{
  struct run *r;
  // ... existing validation (alignment, range) ...

  // Double-free check: walk freelist
  acquire(&kmem.lock);
  for (r = kmem.freelist; r; r = r->next) {
    if ((char*)r == (char*)pa) {
      printf("DOUBLE FREE detected: pa=%p\n", pa);
      release(&kmem.lock);
      return;                      // don't add again!
    }
  }
  release(&kmem.lock);

  // Normal kfree path
  memset(pa, 1, PGSIZE);          // fill with junk (existing behaviour)
  r = (struct run*)pa;
  acquire(&kmem.lock);
  r->next = kmem.freelist;
  kmem.freelist = r;
  release(&kmem.lock);
}
```

**User program** (test):
```c
// Double-free is a kernel bug — user can't directly trigger without kernel mod
// But can observe via getfreepages:
int before = getfreepages();
sbrk(4096);
sbrk(-4096);   // free 1 page
sbrk(-4096);   // try to free AGAIN — should trigger detection
int after = getfreepages();
printf("before=%d after=%d (should be same with protection)\n",
       before, after);
```

> ⚠️ Without this protection, double-free corrupts the freelist → two `kalloc()` calls return the same page → data corruption.

---

## S50: Function Pointer Recovery

> Secret writer stored a **function pointer** at offset +32. Sniffer extracts and prints it as a hex address.

**Scan Logic:**
```c
for (int i = 0; i < size - 64; i++) {
    if (memcmp(p + i, marker, marker_len) == 0) {
        uint64 fptr = *(uint64*)(p + i + 32);
        printf("function pointer at +32: 0x%x\n", fptr);
        printf("secret text at +16: %s\n", p + i + 16);
        exit(0);
    }
}
```

> 💡 `*(uint64*)(p + i + 32)` reads an 8-byte pointer value. On RISC-V, pointers are 64-bit (8 bytes). Offset 32 is 8-byte aligned ✓.

---

## S51: sbrk Alignment Verification

> Verify that `sbrk()` always returns a **page-aligned address** (divisor of 4096).

**Setup:**
```c
char *p = sbrk(0);                 // get current break
printf("initial break: %p, aligned? %s\n",
       p, ((uint64)p % 4096 == 0) ? "YES" : "NO");

int size = 10 * 4096;
char *newp = sbrk(size);
printf("sbrk(%d) returned: %p, aligned? %s\n",
       size, newp, ((uint64)newp % 4096 == 0) ? "YES" : "NO");

// Test non-page-aligned sbrk
char *odd = sbrk(100);            // not a multiple of 4096
printf("sbrk(100) returned: %p, aligned? %s\n",
       odd, ((uint64)odd % 4096 == 0) ? "YES" : "NO");

char *marker = "This may help.";
int marker_len = strlen(marker);
```

**Scan Logic:** (same as boilerplate, using `newp` as `p` and `size`)

> 💡 **Expected**: `sbrk(N)` returns the OLD break. The old break is page-aligned if `uvmalloc` was last used. But `sbrk(100)` returns a non-page-aligned address because it just moves the break by 100 bytes.

---

## Pattern D Quick Reference

| # | Name | Tests | Expected Result | Key Concept |
|---|------|-------|-----------------|-------------|
| S35 | sbrk failure | `sbrk(1<<30)` | Returns `(char*)-1` | Error handling |
| S36 | sbrk(0) | Query break | No allocation | Break pointer |
| S37 | Manual memcmp | Byte-by-byte | Same as memcmp | Pointer arithmetic |
| S38 | Page boundary | Marker spans 2 pages | memcmp still works | Contiguous VA |
| S39 | sbrk + free + sbrk | LIFO recycling | Same pages returned | kfree/kalloc LIFO |
| S40 | Large secret | > 4096 bytes | Use write() for safety | strnlen-like loop |
| S41 | Embedded structs | `struct record` array | Cast to struct pointer | Alignment at +16 |
| S42 | Packed ints | 4 ints at +16/+20/+24/+28 | `*(int*)(addr)` | Little-endian RISC-V |
| S43 | Cross-process | Child sbrk → parent sbrk | Pages may be recycled | fork+exit+sbrk |
| S44 | Time-limited | 100-tick timeout | `uptime()` check | Abort on timeout |
| S45 | Verbose | Print hex addresses | `0x%x` for all markers | Address inspection |
| S46 | Byte histogram | Frequency of each byte | Top 5 non-zero | `freq[256]` array |
| S47 | /dev/mem | Open fails | xv6 has no devfs | sbrk workaround |
| S48 | Pipe output | Child sniffs → pipe → parent | Decoupled output | fork+pipe |
| S49 | Double-free | Walk freelist in kfree | Detect duplicate PA | kalloc.c mod |
| S50 | Function ptr | `*(uint64*)(addr+32)` | Print hex address | 8-byte pointer |
| S51 | sbrk alignment | `p % 4096 == 0?` | Page-aligned for full pages | uvmalloc rounding |
