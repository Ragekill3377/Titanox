#include "THPatchMem.h"


bool THPatchMem::memcpyAndValidate(void* address, const uint8_t* buffer, size_t bufferSize) {
    std::memcpy(address, buffer, bufferSize);
    return std::memcmp(address, buffer, bufferSize) == 0;
}


bool THPatchMem::writeWithVMWrite(void* address, const uint8_t* buffer, size_t bufferSize) {
    kern_return_t kr = vm_write(mach_task_self(), reinterpret_cast<vm_address_t>(address),
                                reinterpret_cast<vm_address_t>(buffer), bufferSize);
    if (kr != KERN_SUCCESS) {
        std::cerr << "[THPatchMem] vm_write failed: " << mach_error_string(kr) << std::endl;
        return false;
    }
    return true;
}


bool THPatchMem::PatchMemory(void* address, uint8_t* buffer, size_t bufferSize) {
    if (!address || !buffer || bufferSize == 0) {
        std::cerr << "[THPatchMem] Invalid arguments." << std::endl;
        return false;
    }

    
    vm_size_t pageSize = (vm_size_t)getpagesize();
    uintptr_t pageStart = (uintptr_t)address & ~(pageSize - 1);
    size_t pageOffset = (uintptr_t)address - pageStart;

    mach_port_t selfTask = mach_task_self();
    kern_return_t kr;

    // R/W
    kr = vm_protect(selfTask, pageStart, pageSize, false, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    if (kr != KERN_SUCCESS) {
        std::cerr << "[THPatchMem] vm_protect failed: " << mach_error_string(kr) << std::endl;
        return false;
    }

    
    if (!memcpyAndValidate((void*)(pageStart + pageOffset), buffer, bufferSize)) {
        // ifi memcpy failed/ we fallback to vm_write
        if (!writeWithVMWrite((void*)(pageStart + pageOffset), buffer, bufferSize)) {
            std::cerr << "[THPatchMem] Failed to apply patch with both memcpy and vm_write." << std::endl;
            return false;
        }
    }

    // R/Exec
    kr = vm_protect(selfTask, pageStart, pageSize, false, VM_PROT_READ | VM_PROT_EXECUTE);
    if (kr != KERN_SUCCESS) {
        std::cerr << "[THPatchMem] vm_protect restore failed: " << mach_error_string(kr) << std::endl;
        return false;
    }

    return true;
}
