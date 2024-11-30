#ifndef THPATCHMEM_H
#define THPATCHMEM_H

#include <cstddef>
#include <cstring>
#include <unistd.h>
#include <iostream>
#include <mach/mach.h>
#include <memory>
/*#include <mach/vm_statistics.h>
#include <mach/mach_vm.h>*/
#import <Foundation/Foundation.h>

class THPatchMem {
public:
    static bool PatchMemory(void* address, uint8_t* buffer, size_t bufferSize);
    static bool memcpyAndValidate(void* address, const uint8_t* buffer, size_t bufferSize);
    static bool writeWithVMWrite(void* address, const uint8_t* buffer, size_t bufferSize);
};

#endif
