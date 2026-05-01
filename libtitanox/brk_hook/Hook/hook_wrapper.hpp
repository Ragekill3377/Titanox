// Modified by Euclid Jan G.

#pragma once
#include "hook.h"

class HookWrapper {
public:
    static bool callHook(void *origArray[], void *hookArray[], int count) {
        return hook(origArray, hookArray, count);
    }
    
    static bool callUnHook(void *origArray[], int count) {
        return unhook(origArray, count);
    }
};