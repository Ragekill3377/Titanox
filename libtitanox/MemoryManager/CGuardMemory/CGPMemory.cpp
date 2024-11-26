//
//  CGPMemory.cpp
//  CGuardProbe
//
//  Made by OPSphystech420 on 2024/5/17
//  Contributor ZarakiDev
//

#include "CGPMemory.h"
#include "../../fishhook/fishhook.h"


uintptr_t CGPMemoryEngine::GetImageBase(const std::string& imageName) {
    static uintptr_t imageBase;
    
    if (imageBase) return imageBase;

    for (uint32_t i = 0; i < _dyld_image_count(); ++i) {
        const char* dyldImageName = _dyld_get_image_name(i);
        if (strstr(dyldImageName, imageName.c_str())) {
            imageBase = reinterpret_cast<uintptr_t>(_dyld_get_image_header(i));
            break;
        }
    }
    return imageBase;
}

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

bool CGPMemoryEngine::CGPWriteMemory(void* address, void* target, int len) {
    kern_return_t kr = vm_write(task, (vm_address_t)address, (vm_offset_t)target, (mach_msg_type_number_t)len);
    if (kr != KERN_SUCCESS) {
        // You can handle error, if needed
        return false;
    }
    return true;
}

bool CGPMemoryEngine::WriteMemory(void* address,void *target, int len){
    mach_port_t object_name;
        mach_vm_size_t region_size=0;
        mach_vm_address_t region_base = (uint64_t)address;
        
        vm_region_basic_info_data_64_t info = {0};
        mach_msg_type_number_t info_cnt = VM_REGION_BASIC_INFO_COUNT_64;
        
        
        kern_return_t kr = mach_vm_region(task, &region_base, &region_size,
                                              VM_REGION_BASIC_INFO_64, (vm_region_info_t)&info, &info_cnt, &object_name);
        if(kr != KERN_SUCCESS) {
            return false;
        }
        
        vm_address_t base = 0;
        if(!(info.protection & VM_PROT_WRITE)) {
            base = (uint64_t)address & ~PAGE_MASK;
            kr = mach_vm_protect(task, base, PAGE_SIZE, false, info.protection|VM_PROT_WRITE|VM_PROT_COPY);
            if(kr != KERN_SUCCESS) {
                kr = mach_vm_protect(task, base, PAGE_SIZE, false, VM_PROT_READ|VM_PROT_WRITE|VM_PROT_COPY);
                if(kr != KERN_SUCCESS) {
                    //NSLog(@"mprotect=%d, %d, %s", mprotect((void*)base, PAGE_SIZE, info.protection|VM_PROT_WRITE), errno, strerror(errno));
                    
                    return false;
                }
            }
        }
        
        bool result = CGPWriteMemory(address, target, len);
        
        if(!result && base) {
            
            kr = mach_vm_protect(task, base, PAGE_SIZE, false, VM_PROT_READ|VM_PROT_WRITE|VM_PROT_COPY);
            
            if(kr != KERN_SUCCESS) {
                
            } else {
                result = CGPWriteMemory(address, target, len);
            }
        }
        
        if(base)
            vm_protect(task, base, PAGE_SIZE, false, info.protection);
        
        return result;
}


vector<void*> CGPMemoryEngine::GetAllResults() {
    vector<void*> addresses;
    for (auto& region : result->resultBuffer) {
        addresses.push_back((void*)region->region_base);
    }
    return addresses;
}

vector<void*> CGPMemoryEngine::GetResults(int count) {
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

bool CGPMemoryEngine::ChangeMemoryProtection(uintptr_t address, size_t size, int protection) {
    size_t pageSize = sysconf(_SC_PAGESIZE);
    uintptr_t pageStart = address & ~(pageSize - 1);
    uintptr_t pageEnd = (address + size + pageSize - 1) & ~(pageSize - 1);
    return mprotect((void*)pageStart, pageEnd - pageStart, protection) == 0;
}

template<int Index>
void CGPMemoryEngine::VMTHook(uintptr_t classInstance, uintptr_t newFunc, uintptr_t& origFunc) {
    if (!classInstance) return;
    uintptr_t vtable = *reinterpret_cast<uintptr_t*>(classInstance);
    if (!vtable) return;

    uintptr_t functionAddress = vtable + Index * sizeof(void*);

    if (*reinterpret_cast<uintptr_t*>(functionAddress) != newFunc) {
        origFunc = *reinterpret_cast<uintptr_t*>(functionAddress);
        ChangeMemoryProtection(functionAddress, sizeof(void*), PROT_READ | PROT_WRITE | PROT_EXEC);
        *reinterpret_cast<uintptr_t*>(functionAddress) = newFunc;
        ChangeMemoryProtection(functionAddress, sizeof(void*), PROT_READ | PROT_EXEC);
    }
}

kern_return_t CGPMemoryEngine::CGPRebindSymbol(const char* symbol, void* replacement, void** oldFunction) {
    /* From fishhook.h */
    struct rebinding rebind;
    rebind.name = symbol;
    rebind.replacement = replacement;
    rebind.replaced = oldFunction;
    
    // rebind
    int result = rebind_symbols((struct rebinding[]){rebind}, 1);

    // 0 if success, or error code.
    return result == 0 ? KERN_SUCCESS : KERN_FAILURE;
}

bool CGPMemoryEngine::RemapLibrary(const string& libraryName) {
    uint32_t imageCount = _dyld_image_count();
    const mach_header* header = nullptr;
    uintptr_t slide = 0;

    for (uint32_t i = 0; i < imageCount; ++i) {
        const char* imageName = _dyld_get_image_name(i);
        if (strstr(imageName, libraryName.c_str())) {
            header = _dyld_get_image_header(i);
            slide = _dyld_get_image_vmaddr_slide(i);
            break;
        }
    }

    if (!header) return false;

    const segment_command_64* seg = nullptr;
    uintptr_t startAddress = UINTPTR_MAX;
    uintptr_t endAddress = 0;

    const uint8_t* ptr = reinterpret_cast<const uint8_t*>(header);
    const load_command* cmd = reinterpret_cast<const load_command*>(ptr + sizeof(mach_header_64));
    for (uint32_t i = 0; i < header->ncmds; ++i) {
        if (cmd->cmd == LC_SEGMENT_64) {
            seg = reinterpret_cast<const segment_command_64*>(cmd);
            if (seg->vmsize > 0) {
                uintptr_t segStart = seg->vmaddr + slide;
                uintptr_t segEnd = segStart + seg->vmsize;
                if (segStart < startAddress) startAddress = segStart;
                if (segEnd > endAddress) endAddress = segEnd;
            }
        }
        cmd = reinterpret_cast<const load_command*>(reinterpret_cast<const uint8_t*>(cmd) + cmd->cmdsize);
    }

    size_t imageSize = endAddress - startAddress;
    void* originalAddress = reinterpret_cast<void*>(startAddress);

    void* newMapping = mmap(nullptr, imageSize, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_PRIVATE | MAP_ANON, -1, 0);
    if (newMapping == MAP_FAILED) {
        // You can handle error, if needed
        return false;
    }

    kern_return_t kr = vm_read_overwrite(
        mach_task_self(),
        startAddress,
        imageSize,
        reinterpret_cast<mach_vm_address_t>(newMapping),
        &imageSize
    );
    
    if (kr != KERN_SUCCESS) {
        // You can handle error, if needed
        munmap(newMapping, imageSize);
        return false;
    }

    kr = vm_deallocate(mach_task_self(), startAddress, imageSize);
    if (kr != KERN_SUCCESS) {
        // You can handle error, if needed
        munmap(newMapping, imageSize);
        return false;
    }

    void* remapped = mmap(
        originalAddress,
        imageSize,
        PROT_READ | PROT_WRITE | PROT_EXEC,
        MAP_FIXED | MAP_PRIVATE | MAP_ANON,
        -1,
        0
    );
    if (remapped == MAP_FAILED) {
        // You can handle error, if needed
        munmap(newMapping, imageSize);
        return false;
    }

    memcpy(remapped, newMapping, imageSize);
    munmap(newMapping, imageSize);

    mprotect(remapped, imageSize, PROT_READ | PROT_EXEC);

    return true;
}

void CGPMemoryEngine::ParseIDAPattern(const string& ida_pattern, vector<uint8_t>& pattern, std::string& mask) {
    size_t i = 0;
    
    while (i < ida_pattern.length()) {
        
        if (std::isspace(ida_pattern[i])) {
            ++i;
            continue;
        }
        
        if (ida_pattern[i] == '?') {
            pattern.push_back(0x00);
            mask += '?';
            ++i;
        } else if (std::isxdigit(ida_pattern[i])) {
            std::string byteStr;
            byteStr += ida_pattern[i++];
            
            if (i < ida_pattern.length() && isxdigit(ida_pattern[i])) byteStr += ida_pattern[i++];
            else continue; /* u can add logs, if hex digit is invalid - byteStr */
            
            uint8_t byte = static_cast<uint8_t>(std::stoul(byteStr, nullptr, 16));
            pattern.push_back(byte);
            mask += 'x';
        } else {
            /* invalid character - ida_pattern[i] */
            ++i;
        }
    }
}

uintptr_t /* std::vector<size_t> */ CGPMemoryEngine::ScanPattern(const uint8_t* data, size_t data_len, const uint8_t* pattern, const char* mask) {
   /* std::vector<size_t> results; */
    
    size_t pattern_len = std::strlen(mask);
    
    for (size_t i = 0; i <= data_len - pattern_len; ++i) {
        
        bool found = true;
        for (size_t j = 0; j < pattern_len; ++j) {
            
            if (mask[j] == 'x' && data[i + j] != pattern[j]) {
                found = false;
                break;
            }
            // if mask[j] == '?' - wildcard
        }
        
     /*   if (found) results.push_back(i); */
        if (found) return reinterpret_cast<uintptr_t>(&data[i]);
    }
    return /* results */ 0;
}

uintptr_t CGPMemoryEngine::ScanIDAPattern(const uint8_t* data, size_t data_len, const std::string& ida_pattern) {
    
    std::vector<uint8_t> pattern;
    std::string mask;
    
    ParseIDAPattern(ida_pattern, pattern, mask);
    
    return ScanPattern(data, data_len, pattern.data(), mask.c_str());
}

bool CGPMemoryEngine::IsValidAddress(long addr){
    return addr > 0x100000000 && addr < 0x3000000000;
}
