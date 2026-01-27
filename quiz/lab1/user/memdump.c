#include "kernel/types.h"
#include "user/user.h"
#include "kernel/fcntl.h"

void memdump(char *fmt, char *data);

int
main(int argc, char *argv[])
{
  if(argc == 1){
    printf("Example 1:\n");
    int a[2] = { 61810, 2025 };
    memdump("ii", (char*) a);
    
    printf("Example 2:\n");
    memdump("S", "a string");
    
    printf("Example 3:\n");
    char *s = "another";
    memdump("s", (char *) &s);

    struct sss {
      char *ptr;
      int num1;
      short num2;
      char byte;
      char bytes[8];
    } example;
    
    example.ptr = "hello";
    example.num1 = 1819438967;
    example.num2 = 100;
    example.byte = 'z';
    strcpy(example.bytes, "xyzzy");
    
    printf("Example 4:\n");
    memdump("pihcS", (char*) &example);
    
    printf("Example 5:\n");
    memdump("sccccc", (char*) &example);
  } else if(argc == 2){
    // format in argv[1], up to 512 bytes of data from standard input.
    char data[512];
    int n = 0;
    memset(data, '\0', sizeof(data));
    while(n < sizeof(data)){
      int nn = read(0, data + n, sizeof(data) - n);
      if(nn <= 0)
        break;
      n += nn;
    }
    memdump(argv[1], data);
  } else {
    printf("Usage: memdump [format]\n");
    exit(1);
  }
  exit(0);
}

void
memdump(char *fmt, char *data)
{
  // Your code here.
// CASE 1: Character ('c') - 1 Byte
  while (*fmt != 0) {
    if (*fmt == 'c') {
      char val = *data;          // Read 1 byte
      printf("%c\n", val);       // Print char
      data += 1;                 // Move 1 byte
    }
// CASE 2: Integer ('i') - 4 Bytes
    else if (*fmt == 'i') {      // Cast to int* and read
      int val = *(int *)data;    // Print int
      printf("%d\n", val);       // Move 4 bytes
      data += 4;
    }
// CASE 3: Short ('h') - 2 Bytes
    else if (*fmt == 'h') {
      short val = *(short *)data; // Cast to short* and read
      printf("%d\n", val);        // Print short
      data += 2;                  // Move 2 bytes
    }


// CASE 4: Pointer ('p') - 8 Bytes
    else if (*fmt == 'p') {          // Read 8-bit addr as number
      uint64 val = *(uint64 *)data;  // Cast back to void* for printing
      printf("%p\n", (void *)val);   // Move 8 bytes
      data += 8;
    }

// CASE 5: String ('s') - 8 Bytes
   else if (*fmt == 's') {           // Read the addr of the string
    char *str_val = *(char **)data;  // Print the string found there
    printf("%s\n", str_val);         // Move 8 bytes (size of the pointer)
    data += 8;
   }

// CASE 6: Inline String ('S') - Uppercase
// The data on the belt IS the text itself.
    else if (*fmt == 'S') {
      printf("%s\n", data);            // Print the data directly as a string
      data += 8;                       // Move past the buffer (Lab assumes 8 bytes)
    }
    fmt++;
  }

}



