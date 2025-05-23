#pragma once

#include <cstdint>

#ifdef __cplusplus
extern "C" {
#endif

void* VMTHook_Create(void* newFunc, int32_t index);
void VMTHook_Swap(void* hook, void* instance);
void VMTHook_Reset(void* hook, void* instance);
void VMTHook_Destroy(void* hook);

void* VMTInvoker_Create(void* instance, int32_t index);
void VMTInvoker_Destroy(void* invoker);

#ifdef __cplusplus
}
#endif
