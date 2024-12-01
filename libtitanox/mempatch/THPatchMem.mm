#include "THPatchMem.h"
#include <sys/mman.h>

bool THPatchMem::memcpyAndValidate(void* address, const uint8_t* buffer, size_t bufferSize) {
    
    std::unique_ptr<uint8_t[]> tempBuffer(new uint8_t[bufferSize]);
    std::memcpy(tempBuffer.get(), buffer, bufferSize);
    return std::memcmp(address, tempBuffer.get(), bufferSize) == 0;
}

bool THPatchMem::writeWithVMWrite(void* address, const uint8_t* buffer, size_t bufferSize) {
    
    std::unique_ptr<uint8_t[]> tempBuffer(new uint8_t[bufferSize]);
    std::memcpy(tempBuffer.get(), buffer, bufferSize);

    kern_return_t kr = vm_write(mach_task_self(), reinterpret_cast<vm_address_t>(address),
                                reinterpret_cast<vm_address_t>(tempBuffer.get()), bufferSize);
    if (kr != KERN_SUCCESS) {
        NSLog(@"[THPatchMem] vm_write failed: %s", mach_error_string(kr));
        return false;
    }
    return true;
}

bool THPatchMem::PatchMemory(void* address, uint8_t* buffer, size_t bufferSize) {
    if (!address || !buffer || bufferSize == 0) {
        NSLog(@"[THPatchMem] Invalid arguments for patching.");
        return false;
    }

    
    vm_size_t pageSize = (vm_size_t)getpagesize();
    uintptr_t pageStart = (uintptr_t)address & ~(pageSize - 1);
    size_t pageOffset = (uintptr_t)address - pageStart;

    mach_port_t selfTask = mach_task_self();
    kern_return_t kr;

    
    std::unique_ptr<uint8_t[]> backupBuffer(new uint8_t[bufferSize]);
    std::memcpy(backupBuffer.get(), (void*)(pageStart + pageOffset), bufferSize);

    
    kr = vm_protect(selfTask, pageStart, pageSize, false, VM_PROT_READ | VM_PROT_WRITE); //removed PROT_COPY
    if (kr != KERN_SUCCESS) {
        NSLog(@"[THPatchMem] vm_protect (R/W) failed: %s", mach_error_string(kr));
        return false;
    }

    
    if (!memcpyAndValidate((void*)(pageStart + pageOffset), buffer, bufferSize)) {
        if (!writeWithVMWrite((void*)(pageStart + pageOffset), buffer, bufferSize)) {
            NSLog(@"[THPatchMem] Failed to patch with both memcpy and vm_write. Restoring original.");
            writeWithVMWrite((void*)(pageStart + pageOffset), backupBuffer.get(), bufferSize); // Restore
            return false;
        }
    }

    
    kr = vm_protect(selfTask, pageStart, pageSize, false, VM_PROT_READ | VM_PROT_EXECUTE);
    if (kr != KERN_SUCCESS) {
        NSLog(@"[THPatchMem] vm_protect (R/X) restore failed: %s", mach_error_string(kr));
        return false;
    }

    return true;
}
