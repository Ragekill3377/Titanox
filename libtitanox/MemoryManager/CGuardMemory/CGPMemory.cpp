//
//  CGPMemory.cpp
//  CGuardProbe
//
//  Made by OPSphystech420 on 2024/5/17
//

#include "CGPMemory.h"

CGPMemoryEngine::CGPMemoryEngine(mach_port_t task) {
    this->task = task;
    Result *newResult = new Result;
    newResult->count = 0;
    this->result = newResult;
}

CGPMemoryEngine::~CGPMemoryEngine(void) {
    if (result != nullptr) {
        for (int i = 0; i < result->resultBuffer.size(); i++) {
            result->resultBuffer[i]->slide.clear();
            result->resultBuffer[i]->slide.shrink_to_fit();
            delete result->resultBuffer[i];
            result->resultBuffer[i] = nullptr;
        }
        result->resultBuffer.clear();
        result->resultBuffer.shrink_to_fit();
        delete result;
        result = nullptr;
    }
}

void CGPMemoryEngine::CGPScanMemory(AddrRange range, void* target, size_t len) {
    vm_size_t size = range.end - range.start;
    vm_address_t address = range.start;
    kern_return_t kr;

    while (address < range.end) {
        vm_size_t vmsize;
        vm_region_basic_info_data_64_t info;
        mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
        memory_object_name_t object;

        kr = vm_region_64(task, &address, &vmsize, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&info, &count, &object);
        if (kr != KERN_SUCCESS) {
            address += vmsize;
            continue;
        }

        std::vector<uint8_t> buffer(vmsize);
        size_t bytesRead = 0;

        kr = vm_read_overwrite(task, address, vmsize, (vm_address_t)buffer.data(), &bytesRead);
        if (kr != KERN_SUCCESS) {
            address += vmsize;
            continue;
        }

        if (bytesRead > vmsize) {
            bytesRead = vmsize;
        }

        for (size_t i = 0; i <= bytesRead - len; i++) {
            if (memcmp(buffer.data() + i, target, len) == 0) {
                result_region* region = new result_region();
                region->region_base = address + i;
                region->slide.push_back((uint32_t)i);
                result->resultBuffer.push_back(region);
                result->count++;
            }
        }

        address += vmsize;
    }
}

void CGPMemoryEngine::CGPNearBySearch(int range, void* target, size_t len) {
    vector<result_region*> newResultBuffer;

    for (auto& region : result->resultBuffer) {
        vm_address_t base = region->region_base;

        for (int i = -range; i <= range; i++) {
            vm_address_t address = base + i * len;

            void* readResult = CGPReadMemory(address, len);
            
            if (readResult != nullptr) {
                if (memcmp(readResult, target, len) == 0) {
                    result_region* newRegion = new result_region;
                    newRegion->region_base = address;
                    newResultBuffer.push_back(newRegion);
                }
                free(readResult);
            }
        }
    }

    for (auto& region : result->resultBuffer) {
        delete region;
    }
    result->resultBuffer.clear();
    result->resultBuffer = newResultBuffer;
    result->count = newResultBuffer.size();
}

bool CGPMemoryEngine::CGPSearchByAddress(unsigned long long address, void* target, size_t len) {
    void* readResult = CGPReadMemory(address, len);
    if (readResult != nullptr && memcmp(readResult, target, len) == 0) {
        free(readResult);
        return true;
    }
    if (readResult != nullptr) {
        free(readResult);
    }
    return false;
}

void* CGPMemoryEngine::CGPReadMemory(unsigned long long address, size_t len) {
    std::vector<uint8_t> buffer(len);
    vm_size_t bytesRead = 0;
    kern_return_t kr = vm_read_overwrite(task, address, len, (vm_address_t)buffer.data(), &bytesRead);
    
    if (kr != KERN_SUCCESS || bytesRead != len) {
        return nullptr;
    }
    
    void* resultBuffer = malloc(len);
    if (resultBuffer == nullptr) {
        return nullptr;
    }
    
    memcpy(resultBuffer, buffer.data(), len);
    return resultBuffer;
}

void CGPMemoryEngine::CGPWriteMemory(long address, void* target, int len) {
    kern_return_t kr = vm_write(task, (vm_address_t)address, (vm_offset_t)target, (mach_msg_type_number_t)len);
    if (kr != KERN_SUCCESS) {
        // You can handle error, if needed
    }
}

vector<void*> CGPMemoryEngine::getAllResults() {
    vector<void*> addresses;
    for (auto& region : result->resultBuffer) {
        addresses.push_back((void*)region->region_base);
    }
    return addresses;
}

vector<void*> CGPMemoryEngine::getResults(int count) {
    vector<void*> addresses;
    for (int i = 0; i < count && i < result->resultBuffer.size(); i++) {
        addresses.push_back((void*)result->resultBuffer[i]->region_base);
    }
    return addresses;
}

void* CGPMemoryEngine::CGPAllocateMemory(size_t size) {
    vm_address_t address = 0;
    kern_return_t kr = vm_allocate(task, &address, size, VM_FLAGS_ANYWHERE);
    if (kr != KERN_SUCCESS) {
        return nullptr;
    }
    return (void*)address;
}

void CGPMemoryEngine::CGPDeallocateMemory(void* address, size_t size) {
    vm_deallocate(task, (mach_vm_address_t)address, size);
}

kern_return_t CGPMemoryEngine::CGPProtectMemory(void* address, size_t size, vm_prot_t protection) {
    return vm_protect(task, (vm_address_t)address, size, FALSE, protection);
}

kern_return_t CGPMemoryEngine::CGPQueryMemory(void* address, vm_size_t* size, vm_prot_t* protection, vm_inherit_t* inheritance) {
    vm_address_t addr = (vm_address_t)address;
    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
    memory_object_name_t object;
    kern_return_t kr = vm_region_64(task, &addr, size, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&info, &count, &object);
    if (kr == KERN_SUCCESS) {
        *protection = info.protection;
        *inheritance = info.inheritance;
    }
    return kr;
}

void CGPMemoryEngine::ResultDeallocate(Result* result) {
    if (result != nullptr && result->count != 0) {
        for (int i = 0; i < result->resultBuffer.size(); i++) {
            result->resultBuffer[i]->slide.clear();
            result->resultBuffer[i]->slide.shrink_to_fit();
            delete result->resultBuffer[i];
        }
        result->resultBuffer.clear();
        result->resultBuffer.shrink_to_fit();
        delete result;
    }
}

Result* CGPMemoryEngine::ResultAllocate() {
    Result* newResult = new Result;
    newResult->count = 0;
    return newResult;
}
