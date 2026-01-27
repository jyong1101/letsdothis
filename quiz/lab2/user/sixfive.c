#include "kernel/types.h"
#include "user/user.h"

int main(int argc, char *argv[]) {
    // Step 1: Check if the user provided at least one argument
    // argc < 2 means the user only typed "sixfive" without a filename
    if (argc < 2) {
        fprintf(2, "Usage: sixfive <filename1> <filename2> ...\n");
        exit(1);
    }

    // Step 2: Loop through every filename provided (argv[1], argv[2], etc.)
    for (int j = 1; j < argc; j++) {
        
        // Try to open the current file
        int fd = open(argv[j], 0);

        if (fd < 0) {
            // File not found or couldn't be opened
            fprintf(2, "Error: cannot open file %s\n", argv[j]);
            // Use 'continue' to skip to the next file in the list
            continue; 
        }

        // If we reach here, the file was found and opened successfully!
        printf("Successfully found and opened: %s\n", argv[j]);

        // Step 3: Placeholder for the reading logic
        // (This is where the while loop and modulo logic will eventually go)
        
        char c;
        char num_buf[32];
        char *separators = " -\r\t\n./,";
        int i = 0;
        int isValid = 1; // Flag for the "xv6" rule: 1 is clean, 0 is word-embedded

        //read file char by char
        while (read(fd, &c, 1) > 0) {
             // Check if the current character is a separator - space, newline, punctuation, etc
             if (strchr(separators, c)) {
                if (i > 0 && isValid) {
                    num_buf[i] = '\0';
                    int n = atoi(num_buf);
                    if (n % 5 == 0 || n % 6 == 0) {
                        printf("%d\n", n);
                    }
                }
                i = 0; // Reset for the next number sequence
                isValid = 1; // Reset validity for the next number sequence
             }
             else if (c >= '0' && c <= '9') {
                // If it's a digit, store it in our buffer
                if (i < 31) {
                    num_buf[i++] = c;
                }
            } 
            else {
                // THE XV6 RULE: If it's a letter (like 'v'), mark the sequence as invalid
                isValid = 0;
            }
        }

        if (i > 0 && isValid) {
            num_buf[i] = '\0';
            int n = atoi(num_buf);
            if (n % 5 == 0 || n % 6 == 0) {
                printf("%d\n", n);
            }
        }
        // Step 4: Always close the file before moving to the next one
        close(fd);
    }

    // Tell the OS the program finished successfully
    exit(0);
}