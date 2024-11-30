#ifndef THPATCHMEM_H
#define THPATCHMEM_H

#include <cstddef>
#include <mach/mach.h>
#include <mach/mach.h>
/*#include <mach/vm_statistics.h>
#include <mach/mach_vm.h>*/
#include <iostream>
#import <Foundation/Foundation.h>

class THPatchMem {
public:
    static bool PatchMemory(void* addr, const void* patch, size_t size);
};

#endif
