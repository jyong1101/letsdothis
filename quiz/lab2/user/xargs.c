#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"
#include "kernel/param.h"

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("Usage: xargs <command> [args...]\n");
        exit(1);
    }

    int start_index = 1;
    int mode_realtime = 0;

    if (strcmp(argv[1], "-n") == 0 && argc > 3) {
        start_index = 3;
        mode_realtime = 1;
    }

    char *xargv[MAXARG]; 
    int static_argc = 0;

    for (int i = start_index; i < argc; i++) {
        xargv[static_argc] = argv[i];
        static_argc++;
    }

    int current_argc = static_argc;

    char buf[1024]; 
    int n = 0;      
    char c;

    while (read(0, &c, 1) > 0) {
        
        if (c == '\n' || c == ' ' || c == '\t') {
            
            if (n > 0) {
                buf[n] = 0;

                char *new_arg = malloc(n + 1);
                strcpy(new_arg, buf);
                
                xargv[current_argc] = new_arg;
                current_argc++;
                xargv[current_argc] = 0;

                if (mode_realtime == 1 || current_argc >= MAXARG - 1) {
                    if (fork() == 0) {
                        exec(xargv[0], xargv);
                        exit(1);
                    } else {
                        wait(0);
                    }
                    current_argc = static_argc;
                }
                
                n = 0;
            }
        } 
        else {
            if (n < 1023) {
                buf[n] = c;
                n++;
            }
        }
    }

    if (n > 0) {
        buf[n] = 0;
        char *new_arg = malloc(n + 1);
        strcpy(new_arg, buf);
        xargv[current_argc] = new_arg;
        current_argc++;
    }

    if (current_argc > static_argc) {
        xargv[current_argc] = 0;
        if (fork() == 0) {
            exec(xargv[0], xargv);
            exit(1);
        } else {
            wait(0);
        }
    }

    exit(0);
}