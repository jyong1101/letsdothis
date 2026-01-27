#include "kernel/types.h"
#include "kernel/stat.h" 
#include "user/user.h"

int main(int argc, char *argv[]) {
     if (argc < 2) {
        fprintf(2, "wrong");
        exit(1);
    }
     if (argc != 2) {
        fprintf(2, "usage sleep <ticks>/n");
        exit(1);
     }
    int ticks = atoi(*argv);
    pause(ticks);    
    exit(0);
}