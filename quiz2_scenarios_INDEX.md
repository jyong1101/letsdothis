# 🎯 Quiz 2 — Comprehensive Predicted Scenarios Index

> **Course**: ICT1012 Operating Systems  
> **Coverage**: Labs Week 3 (handshake, sniffer, monitor) & Week 5 (uthread, pthreads hash table)  
> **Analysis Methodology**: Modeled on Quiz 1 modification patterns (logic twist, feature extension, new cross-cutting task)

---

## Quiz 1 Modification Patterns Observed

| Pattern | Quiz 1 Example | Description |
|---------|----------------|-------------|
| **A — Logic Twist** | sixfive: "multiples of 5/6" → "sequences of digits 5,6 ≤ 3 chars" | Change the filtering criteria while preserving the parsing infrastructure |
| **B — Feature Extension** | memdump: added format `q` for 16-byte hex strings | Add a new case/option to existing switch/if-else logic |
| **C — New Combined Task** | swap32: user program + kernel syscall for endian swap | Entirely new task requiring both user-space and kernel implementation |

---

## Predicted Scenario Summary (33 Total)

### Part A: Handshake Modifications (5 scenarios)
📄 [quiz2_scenarios_part_a_handshake.md](file:///d:/SIT/Year%201/Trimester%202/OS/quiz2/quiz2_scenarios_part_a_handshake.md)

| # | Scenario | Difficulty | Concept |
|---|----------|-----------|---------|
| A1 | **relay** — Multi-process pipe chain | ★★★☆☆ | Multi-process fork chains, sequential pipe relay |
| A2 | **pingpong** — Multi-round exchange | ★★★☆☆ | Bidirectional pipe loops, byte mutation |
| A3 | **handshake_msg** — String message | ★★★★☆ | Variable-length pipe I/O, string reversal |
| A4 | **handshake_xor** — Encrypted handshake | ★★★☆☆ | Bitwise XOR over pipes |
| A5 | **pipeline** — Fork-exec pipeline | ★★★★☆ | Programmatic `\|` with dup/close/exec |

---

### Part B: Sniffer Modifications (5 scenarios)
📄 [quiz2_scenarios_part_b_sniffer.md](file:///d:/SIT/Year%201/Trimester%202/OS/quiz2/quiz2_scenarios_part_b_sniffer.md)

| # | Scenario | Difficulty | Concept |
|---|----------|-----------|---------|
| B1 | **sniffer_multi** — Find all secrets | ★★★☆☆ | Multiple pattern matches in sbrk memory |
| B2 | **sniffer_xor** — Encrypted recovery | ★★★★☆ | XOR cipher + heap scanning |
| B3 | **sniffer_offset** — Variable offset | ★★★☆☆ | Integer casting from raw memory |
| B4 | **scrub** — Kernel page clearing syscall | ★★★★★ | New syscall modifying `kalloc.c` free list |
| B5 | **sniffer_struct** — Structured data recovery | ★★★★☆ | Struct reinterpretation (memdump-like) |

---

### Part C: Monitor Extensions (6 scenarios)
📄 [quiz2_scenarios_part_c_monitor.md](file:///d:/SIT/Year%201/Trimester%202/OS/quiz2/quiz2_scenarios_part_c_monitor.md)

| # | Scenario | Difficulty | Concept |
|---|----------|-----------|---------|
| C1 | **monitor_args** — Trace arguments | ★★★★★ | RISC-V trap frame `a0` access before syscall |
| C2 | **monitor_count** — Syscall counting | ★★★★☆ | Per-process arrays in `proc.h`, exit hooks |
| C3 | **monitor_filter** — Threshold filtering | ★★★★☆ | Multi-argument syscall, conditional tracing |
| C4 | **monitor_name** — Process name in trace | ★★★☆☆ | Accessing `p->name` in kernel context |
| C5 | **monitor_inherit** — Control inheritance | ★★★★☆ | Fork semantics, parent→child state copy |
| C6 | **sysinfo** — System information syscall | ★★★★★ | `copyout`, iterating proc/free lists |

---

### Part D: Uthread Modifications (6 scenarios)
📄 [quiz2_scenarios_part_d_uthread.md](file:///d:/SIT/Year%201/Trimester%202/OS/quiz2/quiz2_scenarios_part_d_uthread.md)

| # | Scenario | Difficulty | Concept |
|---|----------|-----------|---------|
| D1 | **uthread_arg** — Argument passing | ★★★★☆ | Trampoline function, `a0` register setup |
| D2 | **uthread_priority** — Priority scheduling | ★★★★★ | Scheduling algorithm modification |
| D3 | **uthread_join** — Thread join | ★★★★☆ | Blocking/busy-wait synchronization |
| D4 | **uthread_mutex** — User-space mutex | ★★★★★ | Yield-based locking for cooperative threads |
| D5 | **uthread_sleep** — Timed sleep | ★★★★☆ | New thread state, sleep counter management |
| D6 | **uthread_extra_regs** — Extended context | ★★★★★ | RISC-V assembly `sd`/`ld` for `t0-t6` |

---

### Part E: Pthreads Hash Table Modifications (5 scenarios)
📄 [quiz2_scenarios_part_e_pthreads.md](file:///d:/SIT/Year%201/Trimester%202/OS/quiz2/quiz2_scenarios_part_e_pthreads.md)

| # | Scenario | Difficulty | Concept |
|---|----------|-----------|---------|
| E1 | **ph-rwlock** — Read-write locks | ★★★★☆ | `pthread_rwlock_t`, concurrent read optimization |
| E2 | **ph-delete** — Thread-safe deletion | ★★★★☆ | Linked list deletion under mutex |
| E3 | **ph-condvar** — Producer-consumer | ★★★★★ | `pthread_cond_t`, bounded buffer |
| E4 | **ph-barrier** — Barrier synchronization | ★★★★☆ | Reusable barrier with cond/mutex |
| E5 | **ph-global-lock** — Single global lock | ★★☆☆☆ | Simplest correct but slow approach |

---

### Part F: Cross-Lab New Tasks (6 scenarios)
📄 [quiz2_scenarios_part_f_crosslab.md](file:///d:/SIT/Year%201/Trimester%202/OS/quiz2/quiz2_scenarios_part_f_crosslab.md)

| # | Scenario | Difficulty | Concept |
|---|----------|-----------|---------|
| F1 | **getprocinfo** — Process info syscall | ★★★★★ | `copyout`, iterating `proc[]` table |
| F2 | **alarm** — Periodic callbacks | ★★★★★ | Timer interrupts, trap frame manipulation |
| F3 | **ps** — Process listing | ★★★★☆ | Kernel printf, proc state enumeration |
| F4 | **pipestat** — Pipe statistics | ★★★★★ | Extending kernel `pipe` struct |
| F5 | **waitpid** — Wait for specific child | ★★★★☆ | Extending `wait` mechanism |
| F6 | **nproc** — Process count syscall | ★★★★★ | Simple `proc[]` iteration + fork test |

---

## 🔮 Top 10 Most Likely Quiz Questions

Based on the difficulty pattern from Quiz 1 (3 tasks, escalating complexity):

| Rank | Scenario | Why Likely |
|------|----------|-----------|
| 1 | **C4 — monitor_name** | Trivial kernel extension — perfect for "easy" Q1 |
| 2 | **A2 — pingpong** | Natural twist on handshake, same infrastructure |
| 3 | **C1 — monitor_args** | Tests deep RISC-V trap frame understanding |
| 4 | **D1 — uthread_arg** | Minimal change to `thread_create`, tests context |
| 5 | **B1 — sniffer_multi** | Simple modification, tests loop/scan comprehension |
| 6 | **F1 — getprocinfo** | Classic "new syscall" like swap32 pattern |
| 7 | **C2 — monitor_count** | Extension pattern matching memdump→q format |
| 8 | **E2 — ph-delete** | Natural hash table extension |
| 9 | **D2 — uthread_priority** | Tests scheduling algorithms understanding |
| 10 | **F6 — nproc** | Simple new syscall with fork verification |

---

## 📝 Syscall Implementation Checklist (for any new syscall)

Every new xv6 system call requires modifications to these **7 files**:

1. `kernel/syscall.h` — `#define SYS_newsyscall N`
2. `kernel/syscall.c` — `extern` + `syscalls[]` table + `syscall_names[]`
3. `kernel/sysproc.c` — `uint64 sys_newsyscall(void) { ... }`
4. `kernel/defs.h` — Prototype (if calling helper functions)
5. `user/usys.pl` — `entry("newsyscall");`
6. `user/user.h` — User-space function declaration
7. `Makefile` — Add `$U/_testprogram\` to `UPROGS`

---

## 🔧 Quick Reference: RISC-V Registers

| Register | Convention | Saved By |
|----------|-----------|----------|
| `a0-a7` | Function arguments & return value | Caller |
| `s0-s11` | Callee-saved (preserved across calls) | Callee |
| `t0-t6` | Temporaries (scratch) | Caller |
| `ra` | Return address | Callee |
| `sp` | Stack pointer | Callee |
| `a7` | Syscall number (in ecall) | — |
| `a0` | Syscall return value | — |
