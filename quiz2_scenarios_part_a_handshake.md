# Quiz 2 Predicted Scenarios — Part A: Handshake Modifications

> **Based on**: Lab3 `handshake.c` — Pipe-based parent-child byte exchange
> **Quiz 1 Pattern Applied**: Twist the core logic while keeping the pipe infrastructure

---

## Scenario A1: "relay" — Multi-Process Pipe Chain

**Difficulty**: ★★★☆☆ (Moderate)
**Concept Tested**: Multi-process pipe IPC, sequential fork/exec orchestration

**Task Description**: Write a program `relay` that takes a byte and a count N. It creates a chain of N child processes. The byte is passed through the chain via pipes, and each process prints receipt before forwarding.

```
$ relay a 3
2: received a, relaying
3: received a, relaying
4: received a, relaying
5: received a (final)
```

### Implementation Steps

**File**: `user/relay.c`

**Add to Makefile UPROGS**: `$U/_relay\`

### Code

```c
// user/relay.c
#include "kernel/types.h"
#include "user/user.h"

int
main(int argc, char *argv[])
{
  if (argc != 3) {
    fprintf(2, "Usage: relay <byte> <count>\n");
    exit(1);
  }

  char byte = argv[1][0];
  int count = atoi(argv[2]);

  for (int i = 0; i < count; i++) {
    int p[2];
    if (pipe(p) < 0) {
      fprintf(2, "pipe failed\n");
      exit(1);
    }

    int pid = fork();
    if (pid < 0) {
      fprintf(2, "fork failed\n");
      exit(1);
    }

    if (pid > 0) {
      // Parent: send the byte and exit
      close(p[0]);          // close read end
      write(p[1], &byte, 1);
      close(p[1]);
      wait(0);
      exit(0);
    } else {
      // Child: read the byte
      close(p[1]);          // close write end
      char buf;
      if (read(p[0], &buf, 1) != 1) {
        fprintf(2, "read failed\n");
        exit(1);
      }
      close(p[0]);

      if (i < count - 1) {
        printf("%d: received %c, relaying\n", getpid(), buf);
      } else {
        printf("%d: received %c (final)\n", getpid(), buf);
      }
      byte = buf; // continue loop as the new "sender"
    }
  }

  exit(0);
}
```

---

## Scenario A2: "pingpong" — Multi-Round Pipe Exchange

**Difficulty**: ★★★☆☆ (Moderate)
**Concept Tested**: Bidirectional pipe communication, loop-based IPC synchronization

**Task Description**: Modify handshake so that parent and child exchange a byte back and forth N times. Each exchange increments the byte value.

```
$ pingpong a 3
4: round 1 received a from parent
3: round 1 received b from child
4: round 2 received b from parent
3: round 2 received c from child
4: round 3 received c from parent
3: round 3 received d from child
```

### Code

```c
// user/pingpong.c
#include "kernel/types.h"
#include "user/user.h"

int
main(int argc, char *argv[])
{
  if (argc != 3) {
    fprintf(2, "Usage: pingpong <byte> <rounds>\n");
    exit(1);
  }

  char byte = argv[1][0];
  int rounds = atoi(argv[2]);
  int p1[2], p2[2]; // p1: parent->child, p2: child->parent

  if (pipe(p1) < 0 || pipe(p2) < 0) {
    fprintf(2, "pipe failed\n");
    exit(1);
  }

  int pid = fork();
  if (pid < 0) {
    fprintf(2, "fork failed\n");
    exit(1);
  }

  if (pid == 0) {
    // Child
    close(p1[1]); // close write end of parent->child
    close(p2[0]); // close read end of child->parent

    char buf;
    for (int i = 1; i <= rounds; i++) {
      if (read(p1[0], &buf, 1) != 1) {
        fprintf(2, "child read error\n");
        exit(1);
      }
      printf("%d: round %d received %c from parent\n", getpid(), i, buf);
      buf++; // increment the byte
      write(p2[1], &buf, 1);
    }

    close(p1[0]);
    close(p2[1]);
    exit(0);
  } else {
    // Parent
    close(p1[0]);
    close(p2[1]);

    char buf = byte;
    for (int i = 1; i <= rounds; i++) {
      write(p1[1], &buf, 1);
      if (read(p2[0], &buf, 1) != 1) {
        fprintf(2, "parent read error\n");
        exit(1);
      }
      printf("%d: round %d received %c from child\n", getpid(), i, buf);
    }

    close(p1[1]);
    close(p2[0]);
    wait(0);
    exit(0);
  }
}
```

---

## Scenario A3: "handshake_msg" — String Message Handshake

**Difficulty**: ★★★★☆ (Moderate-Hard)
**Concept Tested**: Variable-length pipe communication, string handling over IPC

**Task Description**: Modify handshake to send a full string message (argv[1]) instead of a single byte. The child receives the string, reverses it, and sends it back.

```
$ handshake_msg hello
5: received hello from parent
4: received olleh from child
```

### Code

```c
// user/handshake_msg.c
#include "kernel/types.h"
#include "user/user.h"

int
main(int argc, char *argv[])
{
  if (argc != 2) {
    fprintf(2, "Usage: handshake_msg <message>\n");
    exit(1);
  }

  char *msg = argv[1];
  int len = strlen(msg);
  int p1[2], p2[2];

  if (pipe(p1) < 0 || pipe(p2) < 0) {
    fprintf(2, "pipe failed\n");
    exit(1);
  }

  int pid = fork();
  if (pid < 0) {
    fprintf(2, "fork failed\n");
    exit(1);
  }

  if (pid == 0) {
    // Child
    close(p1[1]);
    close(p2[0]);

    // Read length first (as 4 bytes)
    int rlen;
    read(p1[0], &rlen, sizeof(int));

    // Read the message
    char buf[256];
    read(p1[0], buf, rlen);
    buf[rlen] = '\0';
    printf("%d: received %s from parent\n", getpid(), buf);

    // Reverse the string
    char rev[256];
    for (int i = 0; i < rlen; i++) {
      rev[i] = buf[rlen - 1 - i];
    }
    rev[rlen] = '\0';

    // Send reversed string back
    write(p2[1], &rlen, sizeof(int));
    write(p2[1], rev, rlen);

    close(p1[0]);
    close(p2[1]);
    exit(0);
  } else {
    // Parent
    close(p1[0]);
    close(p2[1]);

    // Send length and message
    write(p1[1], &len, sizeof(int));
    write(p1[1], msg, len);

    // Read reversed message
    int rlen;
    read(p2[0], &rlen, sizeof(int));
    char buf[256];
    read(p2[0], buf, rlen);
    buf[rlen] = '\0';
    printf("%d: received %s from child\n", getpid(), buf);

    close(p1[1]);
    close(p2[0]);
    wait(0);
    exit(0);
  }
}
```

---

## Scenario A4: "handshake_xor" — Encrypted Handshake

**Difficulty**: ★★★☆☆ (Moderate)
**Concept Tested**: Bitwise operations with pipe IPC

**Task Description**: Parent sends a byte to child. Child XORs it with a key (second argument) and sends the result back. Parent XORs again to verify the round-trip produces the original byte.

```
$ handshake_xor A 7
5: received A, encrypted to F
4: received F, decrypted to A - verified!
```

### Code

```c
// user/handshake_xor.c
#include "kernel/types.h"
#include "user/user.h"

int
main(int argc, char *argv[])
{
  if (argc != 3) {
    fprintf(2, "Usage: handshake_xor <byte> <key>\n");
    exit(1);
  }

  char byte = argv[1][0];
  char key = (char)atoi(argv[2]);
  int p1[2], p2[2];

  if (pipe(p1) < 0 || pipe(p2) < 0) {
    fprintf(2, "pipe failed\n");
    exit(1);
  }

  int pid = fork();
  if (pid < 0) {
    fprintf(2, "fork failed\n");
    exit(1);
  }

  if (pid == 0) {
    // Child
    close(p1[1]);
    close(p2[0]);

    char buf;
    read(p1[0], &buf, 1);
    char encrypted = buf ^ key;
    printf("%d: received %c, encrypted to %c\n", getpid(), buf, encrypted);
    write(p2[1], &encrypted, 1);

    close(p1[0]);
    close(p2[1]);
    exit(0);
  } else {
    // Parent
    close(p1[0]);
    close(p2[1]);

    write(p1[1], &byte, 1);

    char buf;
    read(p2[0], &buf, 1);
    char decrypted = buf ^ key;
    if (decrypted == byte) {
      printf("%d: received %c, decrypted to %c - verified!\n", getpid(), buf, decrypted);
    } else {
      printf("%d: verification failed!\n", getpid());
    }

    close(p1[1]);
    close(p2[0]);
    wait(0);
    exit(0);
  }
}
```

---

## Scenario A5: "pipeline" — Fork-Exec Pipeline

**Difficulty**: ★★★★☆ (Moderate-Hard)
**Concept Tested**: Building Unix pipelines programmatically with pipe + fork + exec + dup

**Task Description**: Write `pipeline` that takes two commands separated by `--` and connects them via a pipe, similar to shell pipe `|`.

```
$ pipeline echo hello -- grep hello
hello
```

### Code

```c
// user/pipeline.c
#include "kernel/types.h"
#include "user/user.h"

int
main(int argc, char *argv[])
{
  // Find the "--" separator
  int sep = -1;
  for (int i = 1; i < argc; i++) {
    if (argv[i][0] == '-' && argv[i][1] == '-' && argv[i][2] == '\0') {
      sep = i;
      break;
    }
  }

  if (sep < 0 || sep == 1 || sep == argc - 1) {
    fprintf(2, "Usage: pipeline <cmd1> [args] -- <cmd2> [args]\n");
    exit(1);
  }

  // Build argv arrays for both commands
  // cmd1 args: argv[1] .. argv[sep-1]
  // cmd2 args: argv[sep+1] .. argv[argc-1]

  // Null-terminate cmd1's argv
  argv[sep] = 0;

  int p[2];
  pipe(p);

  // First child: runs cmd1, stdout -> pipe write end
  if (fork() == 0) {
    close(p[0]);
    close(1);           // close stdout
    dup(p[1]);          // dup pipe write end to fd 1
    close(p[1]);
    exec(argv[1], &argv[1]);
    fprintf(2, "exec %s failed\n", argv[1]);
    exit(1);
  }

  // Second child: runs cmd2, stdin <- pipe read end
  if (fork() == 0) {
    close(p[1]);
    close(0);           // close stdin
    dup(p[0]);          // dup pipe read end to fd 0
    close(p[0]);
    exec(argv[sep + 1], &argv[sep + 1]);
    fprintf(2, "exec %s failed\n", argv[sep + 1]);
    exit(1);
  }

  // Parent: close pipe and wait for both children
  close(p[0]);
  close(p[1]);
  wait(0);
  wait(0);
  exit(0);
}
```
