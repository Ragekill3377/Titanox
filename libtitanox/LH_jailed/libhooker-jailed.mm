#include "libhooker-jailed.h"
#include <stdlib.h>
#include <mach/mach.h>
#include <sys/mman.h>
#include <string.h>
#include <stdio.h>

/*

1 = true, 0 = false. You shouldn't modify unless your targets are x86_64.IOS is arm64.
Only System binaries are arm64e (After A11).
You don't have to build for arm64e.

*/
#define arm64 1
#define x86_64 0

// allow writing
static void make_memory_writable(void* target_function, size_t size) {
    vm_protect(mach_task_self(), (vm_address_t)target_function, size, false, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
}

// r/o
static kern_return_t vm_read_safe(vm_address_t address, void* buffer, size_t size) {
    if (address == 0 || buffer == NULL || size == 0) {
        return KERN_INVALID_ARGUMENT;
    }
    vm_offset_t data;
    mach_msg_type_number_t bytes_read;

    
    kern_return_t result = vm_read(mach_task_self(), address, size, &data, &bytes_read);
    if (result == KERN_SUCCESS) {
        memcpy(buffer, (void*)data, bytes_read);
        vm_deallocate(mach_task_self(), data, bytes_read);
    }
    return result;
}

// r/w
static kern_return_t vm_write_safe(vm_address_t address, void* buffer, size_t size) {
    if (address == 0 || buffer == NULL || size == 0) {
        return KERN_INVALID_ARGUMENT;
    }
    return vm_write(mach_task_self(), address, (vm_offset_t)buffer, size);
}



static void* generate_trampoline(void* target_function, size_t instructions_to_save) {
    void* trampoline = malloc(instructions_to_save + 16); // Original + jump back
    if (!trampoline) return NULL;

    
    kern_return_t ret = vm_read_safe((vm_address_t)target_function, trampoline, instructions_to_save);
    if (ret != KERN_SUCCESS) {
        free(trampoline);
        return NULL;
    }

    return trampoline;
}

// THIS is the stuff
bool LHHookFunction(void* target_function, void* hook_function, LHHookRef* out_hook_ref) {
    if (!target_function || !hook_function || !out_hook_ref) {
        return false;
    }

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

    // write
    kern_return_t ret = vm_write_safe((vm_address_t)target_function, hook_instr, sizeof(hook_instr));
    if (ret != KERN_SUCCESS) {
        return false;
    }

    
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
        0x48, 0xB8, // mov rax, imm64 (so here we load the hook address into rax)
        hook_address & 0xFF, (hook_address >> 8) & 0xFF, (hook_address >> 16) & 0xFF, (hook_address >> 24) & 0xFF,
        (hook_address >> 32) & 0xFF, (hook_address >> 40) & 0xFF, (hook_address >> 48) & 0xFF, (hook_address >> 56) & 0xFF,
        0xFF, 0xE0  // jmp rax
    };

    
    kern_return_t ret = vm_write_safe((vm_address_t)target_function, hook_instr, sizeof(hook_instr));
    if (ret != KERN_SUCCESS) {
        return false;
    }

    
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

#if arm64 == 1
    
    make_memory_writable(hook_ref->original_function, 12);
    kern_return_t ret = vm_write_safe((vm_address_t)hook_ref->original_function, hook_ref->trampoline, 12);
    if (ret != KERN_SUCCESS) {
        return false;
    }

#elif x86_64 == 1
    
    make_memory_writable(hook_ref->original_function, 16);
    kern_return_t ret = vm_write_safe((vm_address_t)hook_ref->original_function, hook_ref->trampoline, 16);
    if (ret != KERN_SUCCESS) {
        return false;
    }

#endif

    
    free(hook_ref->trampoline);
    hook_ref->trampoline = NULL;

    return true;
}
