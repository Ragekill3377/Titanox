#include "THPatchMem.h"

bool THPatchMem::PatchMemory(void* addr, const void* patch, size_t size) {
    if (!addr || !patch) {
        return false;
    }
    
    kern_return_t kr;

    // set mem to R/W
    kr = vm_protect(mach_task_self(), reinterpret_cast<vm_address_t>(addr), size, false,
                    VM_PROT_READ | VM_PROT_WRITE);

    if (kr != KERN_SUCCESS) {
        NSLog(@"ERROR: Failed to set memory to R/W.");
        return false;
    }

    
    memcpy(addr, patch, size); // this is the actual component which does the patch

    
    kr = vm_protect(mach_task_self(), reinterpret_cast<vm_address_t>(addr), size, false,
                    VM_PROT_READ | VM_PROT_EXECUTE);

    if (kr != KERN_SUCCESS) {
        NSLog(@"Failed to restore orig mem prot.");
    }

    return true;
}