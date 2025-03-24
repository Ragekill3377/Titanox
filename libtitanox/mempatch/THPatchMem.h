#ifndef THPATCHMEM_H
#define THPATCHMEM_H

#include <cstddef>
#include <unistd.h>
#include <iostream>
#include <mach/mach.h>
#include <memory>
#include <cstring>
#include <sys/mman.h>
#include <mach/error.h>
#import <Foundation/Foundation.h>
#include "../utils/utils.h"

#define PG_SIZE    (getpagesize())
#define VM_WRITE_ERROR_MSG    @"[THPatchMem] vm_write failed: %s"
#define VM_PROTECT_ERROR_MSG  @"[THPatchMem] vm_protect change failed: %s"
#define MEMCPY_ERROR_MSG      @"[THPatchMem] memcpy failed, fallback to vm_write"

class THPatchMem {
public:
    static bool PatchMemory(void* address, uint8_t* buffer, size_t bufferSize);
    static bool memcpyAndValidate(void* address, const uint8_t* buffer, size_t bufferSize);
    static bool writeWithVMWrite(void* address, const uint8_t* buffer, size_t bufferSize);
    static bool MemPatchR(void* address, uint8_t* buffer, size_t bufferSize);
};

#endif
