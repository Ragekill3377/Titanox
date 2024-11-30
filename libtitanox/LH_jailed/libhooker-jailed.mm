#import <Foundation/Foundation.h>
#include "libhooker-jailed.h"
#include "../MemoryManager/CGuardMemory/CGPMemory.h"
#include <mach/mach.h>
#include <sys/mman.h>
#include <string.h>
#include <stdio.h>

static CGPMemoryEngine *memEngine = nullptr;
void initMem_engine() {
    if (memEngine == nullptr) {
        memEngine = new CGPMemoryEngine(mach_task_self());
    }
}

/*

1 = true, 0 = false. You shouldn't modify unless your targets are x86_64. IOS is arm64.
Only System binaries are arm64e (After A11).
You don't have to build for arm64e.

*/
#define arm64 1
#define x86_64 0

static void make_memory_writable(void* target_function, size_t size) {
    memEngine->ChangeMemoryProtection((uintptr_t)target_function, size, PROT_READ | PROT_WRITE | PROT_EXEC);
}


// allow writing
template<typename T>
void Write(long address, T value) {
    memEngine->WriteMemory((void*)address, reinterpret_cast<void*>(&value), sizeof(T));
    if (!address){
        NSLog(@"address is invalid.");
    }
    NSLog(@"WRITE: address:%ld value:%u", address, value); // comment this out later, if its working :p
}

template<typename T>
T Read(unsigned long long address) {
    size_t len = sizeof(T);
    void* memory = memEngine->CGPReadMemory(address, len);

    if (memory == nullptr) {
        return T();
    }

    T data;
    memcpy(&data, memory, len);
    free(memory);
    return data;
}

static void* generate_trampoline(void* target_function, size_t instructions_to_save) {
    void* trampoline = memEngine->CGPAllocateMemory(instructions_to_save + 16); // orig + jmp back
    if (!trampoline) return NULL;

    size_t len = instructions_to_save;
    void* memory = memEngine->CGPReadMemory((unsigned long long)target_function, len);
    if (!memory) {
        NSLog(@"Reading failed. Target-Func:%p\n", target_function);
        memEngine->CGPDeallocateMemory(trampoline, instructions_to_save + 16);
        return NULL;
    }

    memcpy(trampoline, memory, len);
    free(memory);
    return trampoline;
}

// THIS is the stuff
bool LHHookFunction(void* target_function, void* hook_function, LHHookRef* out_hook_ref) {
    if (!target_function || !hook_function || !out_hook_ref) {
        return false;
    }

    if (out_hook_ref->is_hooked) {
        NSLog(@"Already hooked...");
        return true;
    }
    initMem_engine();

#if arm64 == 1
    const size_t instructions_to_overwrite = 12; // 3 instr (12 bytes)
    out_hook_ref->trampoline = generate_trampoline(target_function, instructions_to_overwrite);
    if (!out_hook_ref->trampoline) {
        return false;
    }
    make_memory_writable(target_function, instructions_to_overwrite);

    
    uint64_t hook_address = (uint64_t)hook_function;
    uint32_t hook_instr[] = {
        0x58000051,                 // ldr x17, #8 (hook address is loaded into x17)
        0xD61F0220,                 // br x17 (branch to x17)
        (uint32_t)(hook_address & 0xFFFFFFFF), // lower 32
        (uint32_t)((hook_address >> 32) & 0xFFFFFFFF) // upper 32
    };

    for (size_t i = 0; i < sizeof(hook_instr) / sizeof(hook_instr[0]); i++) {
        Write<uint32_t>((long)target_function + (i * sizeof(uint32_t)), hook_instr[i]);
    }

    out_hook_ref->is_hooked = true;
    out_hook_ref->original_function = target_function;
    out_hook_ref->hook_function = hook_function;

#elif x86_64 == 1
    const size_t instructions_to_overwrite = 16; // Space for mov + jmp instructions
    out_hook_ref->trampoline = generate_trampoline(target_function, instructions_to_overwrite);
    if (!out_hook_ref->trampoline) {
        return false;
    }

    make_memory_writable(target_function, instructions_to_overwrite);

    uint64_t hook_address = (uint64_t)hook_function;
    uint8_t hook_instr[] = {
        0x48, 0xB8, // mov rax, imm64
        hook_address & 0xFF, (hook_address >> 8) & 0xFF, (hook_address >> 16) & 0xFF, (hook_address >> 24) & 0xFF,
        (hook_address >> 32) & 0xFF, (hook_address >> 40) & 0xFF, (hook_address >> 48) & 0xFF, (hook_address >> 56) & 0xFF,
        0xFF, 0xE0  // jmp rax
    };

    for (size_t i = 0; i < sizeof(hook_instr); i++) {
        Write<uint8_t>((long)target_function + i, hook_instr[i]);
    }

    out_hook_ref->is_hooked = true;
    out_hook_ref->original_function = target_function;
    out_hook_ref->hook_function = hook_function;

#else
    #error "Unsupported architecture! Define 'arm64 1/0' or 'x86_64 1/0'."
#endif

    return true;
}

bool LHUnhookFunction(LHHookRef* hook_ref) {
    if (!hook_ref || !hook_ref->original_function || !hook_ref->trampoline) {
        return false;
    }

    if (!hook_ref->is_hooked) {
        return true;
    }

#if arm64 == 1
    const size_t instructions_to_overwrite = 12;
    make_memory_writable(hook_ref->original_function, instructions_to_overwrite);
    for (size_t i = 0; i < instructions_to_overwrite; i += sizeof(uint32_t)) {
        Write<uint32_t>((long)hook_ref->original_function + i,
            Read<uint32_t>((unsigned long long)hook_ref->trampoline + i));
    }
#elif x86_64 == 1
    const size_t instructions_to_overwrite = 16;
    make_memory_writable(hook_ref->original_function, instructions_to_overwrite);
    for (size_t i = 0; i < instructions_to_overwrite; i++) {
        Write<uint8_t>((long)hook_ref->original_function + i,
            Read<uint8_t>((unsigned long long)hook_ref->trampoline + i));
    }
#endif

    hook_ref->is_hooked = false;
    memEngine->CGPDeallocateMemory(hook_ref->trampoline, instructions_to_overwrite + 16);
    hook_ref->trampoline = NULL;

    return true;
}
