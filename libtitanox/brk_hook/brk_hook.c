// inspiration from ellekit's JITless.c

#include "breakpoint.h"


int allHooks = 0;
struct debug_state globalDebugState = {};


void* hook1;
void* hook1rep;
void* hook2;
void* hook2rep;
void* hook3;
void* hook3rep;
void* hook4;
void* hook4rep;
void* hook5;
void* hook5rep;
void* hook6;
void* hook6rep;


__attribute__((naked))
extern void orig1(void) {
    __asm__ volatile(
        ".extern _hook1\n"
        "adrp x16, _hook1@PAGE\n"
        "ldr x16, [x16, _hook1@PAGEOFF]\n"
        "add x16, x16, #4\n"
        "pacibsp\n"
        "br x16\n"
    );
}

__attribute__((naked))
static void orig2(void) {
    __asm__ volatile(
        ".extern _hook2\n"
        "adrp x16, _hook2@PAGE\n"
        "ldr x16, [x16, _hook2@PAGEOFF]\n"
        "add x16, x16, #4\n"
        "pacibsp\n"
        "br x16\n"
    );
}

__attribute__((naked))
extern void orig3(void) {
    __asm__ volatile(
        ".extern _hook3\n"
        "adrp x16, _hook3@PAGE\n"
        "ldr x16, [x16, _hook3@PAGEOFF]\n"
        "add x16, x16, #4\n"
        "pacibsp\n"
        "br x16\n"
    );
}

__attribute__((naked))
static void orig4(void) {
    __asm__ volatile(
        ".extern _hook4\n"
        "adrp x16, _hook4@PAGE\n"
        "ldr x16, [x16, _hook4@PAGEOFF]\n"
        "add x16, x16, #4\n"
        "pacibsp\n"
        "br x16\n"
    );
}

__attribute__((naked))
extern void orig5(void) {
    __asm__ volatile(
        ".extern _hook5\n"
        "adrp x16, _hook5@PAGE\n"
        "ldr x16, [x16, _hook5@PAGEOFF]\n"
        "add x16, x16, #4\n"
        "pacibsp\n"
        "br x16\n"
    );
}

__attribute__((naked))
static void orig6(void) {
    __asm__ volatile(
        ".extern _hook6\n"
        "adrp x16, _hook6@PAGE\n"
        "ldr x16, [x16, _hook6@PAGEOFF]\n"
        "add x16, x16, #4\n"
        "pacibsp\n"
        "br x16\n"
    );
}


void init_breakpoints(void) {
    allHooks = 0;
    for (int i = 0; i < MAX_BREAKPOINTS; ++i) {
        globalDebugState.bvr[i] = 0;
        globalDebugState.bcr[i] = 0;
    }
}

void add_breakpoint(void* target, void* replacement, void** orig) {
    if (allHooks >= MAX_BREAKPOINTS) {
        printf("Error: Maximum number of breakpoints reached.\n");
        return;
    }

    void* clean_target = (void*)((uint64_t)target & 0x0000007fffffffff);
    void* clean_replacement = (void*)((uint64_t)replacement & 0x0000007fffffffff);

    switch (allHooks) {
        case 0:
            hook1 = clean_target;
            hook1rep = clean_replacement;
            if (orig) *orig = orig1;
            break;
        case 1:
            hook2 = clean_target;
            hook2rep = clean_replacement;
            if (orig) *orig = orig2;
            break;
        case 2:
            hook3 = clean_target;
            hook3rep = clean_replacement;
            if (orig) *orig = orig3;
            break;
        case 3:
            hook4 = clean_target;
            hook4rep = clean_replacement;
            if (orig) *orig = orig4;
            break;
        case 4:
            hook5 = clean_target;
            hook5rep = clean_replacement;
            if (orig) *orig = orig5;
            break;
        case 5:
            hook6 = clean_target;
            hook6rep = clean_replacement;
            if (orig) *orig = orig6;
            break;
        default:
            printf("Error: Invalid hook index.\n");
            return;
    }

    uint32_t firstInstruction = *(uint32_t*)clean_target;
    globalDebugState.bvr[allHooks] = (uint64_t)clean_target;
    globalDebugState.bcr[allHooks] = 0x1e5;

    allHooks++;

    kern_return_t ret = task_set_state(
        mach_task_self(),
        ARM_DEBUG_STATE64,
        (thread_state_t)&globalDebugState,
        MAX_BREAKPOINTS * 2
    );

    if (ret != KERN_SUCCESS) {
        printf("Error: task_set_state failed: %s\n", mach_error_string(ret));
        return;
    }

}
