#pragma once

#include <cstdlib>
#include <cstring>
#include <mach/mach.h>
#include <sys/mman.h>
#include <unistd.h>

template<typename FuncType>
VMTHook<FuncType>::VMTHook(FuncType* NewFunc, int32_t Index)
    : OriginalVTable(nullptr), DetourVTable(nullptr), OriginalFunction(nullptr),
      NewFunction(NewFunc), FunctionIndex(Index), HookedInstance(nullptr) {}

template<typename FuncType>
int VMTHook<FuncType>::GetNumMethods(void** VTable) const {
    int Count = 0;
    while (VTable[Count]) ++Count;
    return Count;
}

template<typename FuncType>
void VMTHook<FuncType>::Swap(void* Class)
{
    if (!Class || !NewFunction) return;

    void** VTable = *reinterpret_cast<void***>(Class);
    if (!VTable || VTable[FunctionIndex] == NewFunction || !MemX::IsValidPointer(reinterpret_cast<uintptr_t>(VTable))) return;

    if (HookedInstance && HookedInstance != Class) Reset(HookedInstance);

    int MethodCount = GetNumMethods(VTable);
    DetourVTable = static_cast<void**>(malloc(MethodCount * sizeof(void*)));
    if (!DetourVTable) return;

    memcpy(DetourVTable, VTable, MethodCount * sizeof(void*));
    OriginalVTable = VTable;
    OriginalFunction = reinterpret_cast<FuncType*>(DetourVTable[FunctionIndex]);
    DetourVTable[FunctionIndex] = reinterpret_cast<void*>(NewFunction);
    *(void***)Class = DetourVTable;
    HookedInstance = Class;
}

template<typename FuncType>
void VMTHook<FuncType>::Reset(void* Class)
{
    if (Class && OriginalVTable) *(void***)Class = OriginalVTable;
    if (DetourVTable) { free(DetourVTable); DetourVTable = nullptr; }
    OriginalVTable = nullptr;
    HookedInstance = nullptr;
}

template<typename FuncType>
VMTInvokerBase<FuncType>::VMTInvokerBase(void* instance, int32_t index)
    : Instance(instance), FunctionIndex(index), OriginalFunction(nullptr) {}

template<typename FuncType>
VMTInvoker<FuncType>::VMTInvoker(void* instance, int32_t index)
    : VMTInvokerBase<FuncType>(instance, index)
{
    void** VTable = *reinterpret_cast<void***>(instance);
    OriginalFunction = reinterpret_cast<FuncType*>(VTable[FunctionIndex]);
}
