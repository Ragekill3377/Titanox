#pragma once

#include <stdint.h>
#include <stdbool.h>

typedef struct {
    void* original_function;
    void* hook_function;
    void* trampoline;
    bool is_hooked;
} LHHookRef;

bool LHHookFunction(void* target_function, void* hook_function, LHHookRef* out_hook_ref);
bool LHUnhookFunction(LHHookRef* hook_ref);
