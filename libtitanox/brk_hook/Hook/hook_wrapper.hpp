#pragma once
#include "hook.h"

class HookWrapper {
public:
    static bool callHook(void *origArray[], void *hookArray[], int count) {
        return hook(origArray, hookArray, count);
    }
};
