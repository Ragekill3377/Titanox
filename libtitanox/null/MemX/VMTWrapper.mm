#import "VMTWrapper.h"
#import "VMTCombo.hpp"

static VMTHook<void()>* vmthook_void = nullptr;
static VMTInvoker<void()>* vmtinvoker_void = nullptr;

extern "C" {

void* VMTHook_Create(void* newFunc, int32_t index)
{
    auto hook = new VMTHook<void()>(reinterpret_cast<void(*)()>(newFunc), index);
    return hook;
}

void VMTHook_Swap(void* hookPtr, void* instance)
{
    auto hook = static_cast<VMTHook<void()>*>(hookPtr);
    hook->Swap(instance);
}

void VMTHook_Reset(void* hookPtr, void* instance)
{
    auto hook = static_cast<VMTHook<void()>*>(hookPtr);
    hook->Reset(instance);
}

void VMTHook_Destroy(void* hookPtr)
{
    auto hook = static_cast<VMTHook<void()>*>(hookPtr);
    delete hook;
}

void* VMTInvoker_Create(void* instance, int32_t index)
{
    auto invoker = new VMTInvoker<void()>(instance, index);
    return invoker;
}

void VMTInvoker_Destroy(void* invokerPtr)
{
    auto invoker = static_cast<VMTInvoker<void()>*>(invokerPtr);
    delete invoker;
}

}
