#pragma once

#include <mach/mach.h>
#include <mach/mach_error.h>
#include <stdio.h>
#include <mach/thread_act.h>
#include <mach/thread_status.h>

// constants.
// max software breakpoints will always be 6. you cannot exceed this.
#define SOFTWARE_BP_OPCODE 0xD4200000  // ARM64 BRK instruction opcode
#define MAX_BREAKPOINTS 6

// so this struct will hold the current state of said breakpoints.
struct debug_state {
    __uint64_t bvr[MAX_BREAKPOINTS];
    __uint64_t bcr[MAX_BREAKPOINTS];
};

#ifdef __cplusplus
extern "C" {
#endif

void init_breakpoints(void);
void add_breakpoint(void* target, void* replacement, void** orig);

#ifdef __cplusplus
}
#endif

