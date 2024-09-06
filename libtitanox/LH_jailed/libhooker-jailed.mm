#include "libhooker-jailed.h"
#include <stdlib.h>
#include <mach/mach.h>
#include <sys/mman.h>
#include <string.h>
#include <stdio.h>

// 1 = true, 0 = false. You shouldn't modify unless your targets are x86_64. IOS is arm64 (usually).
#define arm64 1
#define x86_64 0

static void make_memory_writable(void* target_function, size_t size) {
    vm_protect(mach_task_self(), (vm_address_t)target_function, size, false, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
}

static void* generate_trampoline(void* target_function, size_t instructions_to_save) {
    void* trampoline = malloc(instructions_to_save + 16); // Original + jump back
    if (!trampoline) return nullptr;

    // copy original instructions to the trampoline
    memcpy(trampoline, target_function, instructions_to_save);

    return trampoline;
}

bool LHHookFunction(void* target_function, void* hook_function, LHHookRef* out_hook_ref) {
    if (!target_function || !hook_function || !out_hook_ref) {
        return false;
    }

    // Compile for ARM64 if arm64 is defined as 1
#if arm64 == 1

    const size_t instructions_to_overwrite = 12; // 3 instructions (12 bytes)
    out_hook_ref->trampoline = generate_trampoline(target_function, instructions_to_overwrite);
    if (!out_hook_ref->trampoline) {
        return false;
    }

    make_memory_writable(target_function, instructions_to_overwrite);

    // INLINE ARM64 ASM
    uint64_t hook_address = (uint64_t)hook_function;

    __asm__ __volatile__ (
        "mov x20, %0\n"        // Load the address of hook function into x20
        "br x20\n"             // Branch to hook function (indirect branch via x20)
        :
        : "r" (hook_address)   // Input: hook_function
        : "x20"                // Clobbered register: x20
    );

    // Save
    out_hook_ref->original_function = target_function;
    out_hook_ref->hook_function = hook_function;

#elif x86_64 == 1

    const size_t instructions_to_overwrite = 16; // Space for mov + jmp instructions
    out_hook_ref->trampoline = generate_trampoline(target_function, instructions_to_overwrite);
    if (!out_hook_ref->trampoline) {
        return false;
    }

    make_memory_writable(target_function, instructions_to_overwrite);

    // INLINE X86_64 ASM
    uint64_t hook_address = (uint64_t)hook_function;

    __asm__ __volatile__ (
        "movabsq %0, %%rax\n" // Move hook function address into rax
        "jmp *%%rax\n"        // Jump to hook function
        :
        : "r" (hook_address)  // Input: hook function address
        : "rax", "memory"
    );

    // Save this aswell.
    out_hook_ref->original_function = target_function;
    out_hook_ref->hook_function = hook_function;

#else
#error "Unsupported architecture! Define 'arm64' or 'x86_64'."
#endif

    return true;
}


// Not always necessary. 
// in main.mm of libtitanox I have NOT added this call. 
// However, if you want your hooks to be temporary, then please use this to un-hook. 
// Else, ignore it.


bool LHUnhookFunction(LHHookRef* hook_ref) {
    if (!hook_ref || !hook_ref->original_function || !hook_ref->trampoline) {
        return false;
    }

#if arm64 == 1

    make_memory_writable(hook_ref->original_function, 12);
    memcpy(hook_ref->original_function, hook_ref->trampoline, 12);

#elif x86_64 == 1

    make_memory_writable(hook_ref->original_function, 16);
    memcpy(hook_ref->original_function, hook_ref->trampoline, 16);

#endif

    free(hook_ref->trampoline);
    hook_ref->trampoline = nullptr;

    return true;
}
