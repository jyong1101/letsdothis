# Quiz 2 Predicted Scenarios — Part B: Sniffer Modifications

> **Based on**: Lab3 `sniffer.c` + `secret.c` — Heap memory snooping via `sbrk()`
> **Quiz 1 Pattern Applied**: Twist the detection/search logic while keeping the sbrk scanning infrastructure

---

## Scenario B1: "sniffer_multi" — Find All Secrets

**Difficulty**: ★★★☆☆ (Moderate)
**Concept Tested**: Memory scanning, multiple pattern matches in heap

**Task Description**: Modify `sniffer` to find and print ALL secrets stored in memory, not just the first one. The program `secret` is called multiple times before `sniffer` runs.

```
$ secret alpha
$ secret bravo
$ sniffer_multi
alpha
bravo
```

### Code

```c
// user/sniffer_multi.c
#include "kernel/types.h"
#include "kernel/fcntl.h"
#include "user/user.h"
#include "kernel/riscv.h"

int
main(int argc, char *argv[])
{
  int size = 20 * 4096; // allocate more to catch multiple secrets
  char *p = sbrk(size);

  if (p == (char*)-1) {
    printf("sniffer: sbrk failed\n");
    exit(1);
  }

  char *marker = "This may help.";
  int marker_len = strlen(marker);
  int found = 0;

  // Scan the entire allocated region for ALL occurrences of the marker
  for (int i = 0; i < size - 64; i++) {
    if (memcmp(p + i, marker, marker_len) == 0) {
      printf("%s\n", p + i + 16);
      found++;
      // Skip past this secret to avoid re-matching within the same block
      i += 4096;
    }
  }

  if (found == 0) {
    printf("sniffer: no secrets found\n");
  }

  exit(found > 0 ? 0 : 1);
}
```

---

## Scenario B2: "sniffer_xor" — Encrypted Secret Recovery

**Difficulty**: ★★★★☆ (Moderate-Hard)
**Concept Tested**: Bitwise operations, memory layout understanding, XOR cipher

**Task Description**: The `secret_xor` program XOR-encrypts the secret with a key byte before storing it. Write `sniffer_xor` that takes the key as argument, finds the encrypted secret, and decrypts it.

### Modified `secret_xor.c`

```c
// user/secret_xor.c
#include "kernel/types.h"
#include "kernel/fcntl.h"
#include "user/user.h"
#include "kernel/riscv.h"

#define DATASIZE (8*4096)
char data[DATASIZE];

int
main(int argc, char *argv[])
{
  if (argc != 3) {
    printf("Usage: secret_xor <secret> <key_byte>\n");
    exit(1);
  }

  strcpy(data, "This may help.");
  
  char key = (char)atoi(argv[2]);
  char *secret = argv[1];
  int len = strlen(secret);

  // XOR encrypt the secret before storing
  for (int i = 0; i < len; i++) {
    data[16 + i] = secret[i] ^ key;
  }
  data[16 + len] = '\0';

  exit(0);
}
```

### Sniffer Code

```c
// user/sniffer_xor.c
#include "kernel/types.h"
#include "kernel/fcntl.h"
#include "user/user.h"
#include "kernel/riscv.h"

int
main(int argc, char *argv[])
{
  if (argc != 2) {
    fprintf(2, "Usage: sniffer_xor <key_byte>\n");
    exit(1);
  }

  char key = (char)atoi(argv[1]);
  int size = 10 * 4096;
  char *p = sbrk(size);

  if (p == (char*)-1) {
    printf("sniffer: sbrk failed\n");
    exit(1);
  }

  char *marker = "This may help.";
  int marker_len = strlen(marker);

  for (int i = 0; i < size - 64; i++) {
    if (memcmp(p + i, marker, marker_len) == 0) {
      // Decrypt the secret by XOR with key
      char *encrypted = p + i + 16;
      int j = 0;
      while (encrypted[j] != '\0') {
        char decrypted = encrypted[j] ^ key;
        printf("%c", decrypted);
        j++;
      }
      printf("\n");
      exit(0);
    }
  }

  printf("sniffer: secret not found\n");
  exit(1);
}
```

---

## Scenario B3: "sniffer_offset" — Variable Offset Secret

**Difficulty**: ★★★☆☆ (Moderate)
**Concept Tested**: Memory scanning with variable-length markers, pointer arithmetic

**Task Description**: The modified `secret` stores the marker AND the offset as part of the data. The sniffed secret is at a variable offset that must be read from the marker region itself.

### Modified `secret_offset.c`

```c
// user/secret_offset.c
#include "kernel/types.h"
#include "kernel/fcntl.h"
#include "user/user.h"
#include "kernel/riscv.h"

#define DATASIZE (8*4096)
char data[DATASIZE];

int
main(int argc, char *argv[])
{
  if (argc != 2) {
    printf("Usage: secret_offset <secret>\n");
    exit(1);
  }

  strcpy(data, "MARKER_V2");

  // Store the offset as a 4-byte integer at position 12
  int offset = 32; // secret is at byte 32 from marker
  *(int *)(data + 12) = offset;

  // Store secret at the specified offset
  strcpy(data + offset, argv[1]);

  exit(0);
}
```

### Sniffer Code

```c
// user/sniffer_offset.c
#include "kernel/types.h"
#include "kernel/fcntl.h"
#include "user/user.h"
#include "kernel/riscv.h"

int
main(int argc, char *argv[])
{
  int size = 10 * 4096;
  char *p = sbrk(size);

  if (p == (char*)-1) {
    printf("sniffer: sbrk failed\n");
    exit(1);
  }

  char *marker = "MARKER_V2";
  int marker_len = strlen(marker);

  for (int i = 0; i < size - 64; i++) {
    if (memcmp(p + i, marker, marker_len) == 0) {
      // Read the offset stored at position 12 from marker
      int offset = *(int *)(p + i + 12);
      // Read the secret at the computed offset
      printf("%s\n", p + i + offset);
      exit(0);
    }
  }

  printf("sniffer: secret not found\n");
  exit(1);
}
```

---

## Scenario B4: "scrub" — Kernel Syscall for Secure Memory Clearing

**Difficulty**: ★★★★★ (Hard)
**Concept Tested**: Kernel syscall implementation, memory management, security

**Task Description**: Implement a new system call `int scrub(void)` that zeroes all freed pages in the kernel's free list, preventing sniffer attacks. After calling `scrub`, the sniffer should fail to find any secrets.

### Implementation Steps

#### 1. `kernel/syscall.h` — Add syscall number
```c
#define SYS_monitor 22
#define SYS_scrub   23
```

#### 2. `kernel/syscall.c` — Add extern and table entry
```c
extern uint64 sys_scrub(void);

// In syscalls[] array:
[SYS_scrub]   sys_scrub,

// In syscall_names[] array:
[SYS_scrub]   "scrub",
```

#### 3. `kernel/sysproc.c` — Implement the handler
```c
uint64
sys_scrub(void)
{
  scrub_freelist();
  return 0;
}
```

#### 4. `kernel/kalloc.c` — Add scrub function
```c
void
scrub_freelist(void)
{
  struct run *r;

  acquire(&kmem.lock);
  r = kmem.freelist;
  while (r) {
    // Zero the entire page (4096 bytes)
    memset((char *)r + sizeof(struct run), 0, PGSIZE - sizeof(struct run));
    r = r->next;
  }
  release(&kmem.lock);
}
```

#### 5. `kernel/defs.h` — Add prototype
```c
// kalloc.c
void            scrub_freelist(void);
```

#### 6. `user/usys.pl` — Add entry
```perl
entry("scrub");
```

#### 7. `user/user.h` — Add declaration
```c
int scrub(void);
```

#### 8. `user/scrub.c` — Test program
```c
#include "kernel/types.h"
#include "user/user.h"

int main(void) {
  printf("Scrubbing free pages...\n");
  int r = scrub();
  printf("scrub returned %d\n", r);
  exit(0);
}
```

---

## Scenario B5: "sniffer_struct" — Structured Data Recovery

**Difficulty**: ★★★★☆ (Moderate-Hard)
**Concept Tested**: Memory layout, struct interpretation, memdump-style casting

**Task Description**: The secret program stores structured data (not just a string). The sniffer must interpret the raw bytes as a struct containing: an int ID, a short age, and a string name.

### Modified `secret_struct.c`

```c
// user/secret_struct.c
#include "kernel/types.h"
#include "user/user.h"

#define DATASIZE (8*4096)
char data[DATASIZE];

struct record {
  int id;
  short age;
  char name[64];
};

int
main(int argc, char *argv[])
{
  if (argc != 4) {
    printf("Usage: secret_struct <id> <age> <name>\n");
    exit(1);
  }

  strcpy(data, "RECORD_MARK");

  struct record *rec = (struct record *)(data + 16);
  rec->id = atoi(argv[1]);
  rec->age = (short)atoi(argv[2]);
  strcpy(rec->name, argv[3]);

  exit(0);
}
```

### Sniffer Code

```c
// user/sniffer_struct.c
#include "kernel/types.h"
#include "kernel/fcntl.h"
#include "user/user.h"
#include "kernel/riscv.h"

struct record {
  int id;
  short age;
  char name[64];
};

int
main(int argc, char *argv[])
{
  int size = 10 * 4096;
  char *p = sbrk(size);

  if (p == (char*)-1) {
    printf("sniffer: sbrk failed\n");
    exit(1);
  }

  char *marker = "RECORD_MARK";
  int marker_len = strlen(marker);

  for (int i = 0; i < size - 128; i++) {
    if (memcmp(p + i, marker, marker_len) == 0) {
      struct record *rec = (struct record *)(p + i + 16);
      printf("ID: %d\n", rec->id);
      printf("Age: %d\n", (int)rec->age);
      printf("Name: %s\n", rec->name);
      exit(0);
    }
  }

  printf("sniffer: record not found\n");
  exit(1);
}
```
