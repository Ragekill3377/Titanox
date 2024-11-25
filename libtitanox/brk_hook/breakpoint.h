#pragma once

#include <mach/mach.h>
#include <mach/mach_error.h>
#include <stdio.h>
#include <mach/thread_act.h>
#include <mach/thread_status.h>

// constants.
// max hardware breakpoints will always be 6. you cannot exceed this.
// you can adjust the max brk to whatever you want.
// but, these are software breakpoints and shouldn't have a limit. (yea im weird, and it looks weird. its due to my lack of understanding i guess... :p)
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

