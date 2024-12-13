#include "stdint.h"
#include "stdio/stdio.h"
#include "disk/asmDisk.h"


void _cdecl cstart_(){

    uint8_t error;
    x86_Disk_Reset(0, &error);
    if(error != (uint8_t)0){
        printf("Error while resetting disk. Error Code: %d \r\n", error);
    }else{
        puts("Successfuly reset disk! \r\n");
    }

    puts("Hello world from C! \r\n");
    printf("Test: String %s, Char: %c, Percent: %%, Int: %d, Negative int: %d \r\n", "string", 'c', 532, -1231);
}

/*
void _cdecl cstart_(){
    printf("Test");
    int test;
}*/