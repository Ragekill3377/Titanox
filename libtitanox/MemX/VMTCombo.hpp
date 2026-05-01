#pragma once

#include <cstdint>
#include <utility>
#include "MemX.hpp"

template<typename FuncType>
class VMTHook
{
private:
    void** OriginalVTable;
    void** DetourVTable;
    FuncType* OriginalFunction;
    FuncType* NewFunction;
    int32_t FunctionIndex;
    void* HookedInstance;

    int GetNumMethods(void** VTable) const;

public:
    VMTHook(FuncType* NewFunc, int32_t Index);

    void Swap(void* Class);
    void Reset(void* Class);

    template<typename... Args>
    auto InvokeOriginal(Args&&... args) const -> decltype(auto)
    {
        return (*OriginalFunction)(std::forward<Args>(args)...);
    }
};

template<typename FuncType>
class VMTInvokerBase
{
protected:
    void* Instance;
    int32_t FunctionIndex;
    FuncType* OriginalFunction;

public:
    VMTInvokerBase(void* instance, int32_t index);

    template<typename... Args>
    auto Invoke(Args&&... args) const -> decltype(auto)
    {
        return (*OriginalFunction)(std::forward<Args>(args)...);
    }
};

template<typename FuncType>
class VMTInvoker : public VMTInvokerBase<FuncType>
{
public:
    using VMTInvokerBase<FuncType>::Instance;
    using VMTInvokerBase<FuncType>::FunctionIndex;
    using VMTInvokerBase<FuncType>::OriginalFunction;

    VMTInvoker(void* instance, int32_t index);
};

#include "VMTCombo.tpp"
