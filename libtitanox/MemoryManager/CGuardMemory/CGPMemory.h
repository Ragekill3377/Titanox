//
//  CGPMemory.h
//  CGuardProbe
//
//  Made by OPSphystech420 on 2024/5/17
//  Contributor ZarakiDev
//

#ifndef CGPMemory_h
#define CGPMemory_h

#include <mach-o/dyld.h>
#include <mach/mach.h>

#include <sys/mman.h>
#include <unistd.h>

#include <iostream>
#include <vector>
#include <string>
#include <algorithm>
#include <functional>

#include <cstdint>
#include <cstring>
#include <cctype>

#include <stdio.h>

#define CGP_Search_Type_ULong 8
#define CGP_Search_Type_Double 8
#define CGP_Search_Type_SLong 8
#define CGP_Search_Type_Float 4
#define CGP_Search_Type_UInt 4
#define CGP_Search_Type_SInt 4
#define CGP_Search_Type_UShort 2
#define CGP_Search_Type_SShort 2
#define CGP_Search_Type_UByte 1
#define CGP_Search_Type_SByte 1

using namespace std;



extern "C" kern_return_t mach_vm_region
(
     vm_map_t target_task,
     mach_vm_address_t *address,
     mach_vm_size_t *size,
     vm_region_flavor_t flavor,
     vm_region_info_t info,
     mach_msg_type_number_t *infoCnt,
     mach_port_t *object_name
 );

extern "C" kern_return_t mach_vm_protect
(
 vm_map_t target_task,
 mach_vm_address_t address,
 mach_vm_size_t size,
 boolean_t set_maximum,
 vm_prot_t new_protection
 );


typedef struct _result_region {
    mach_vm_address_t region_base;
    vector<uint32_t> slide;
} result_region;

typedef struct _result {
    vector<result_region*> resultBuffer;
    int count;
} Result;

typedef struct _addrRange {
    uint64_t start;
    uint64_t end;
} AddrRange;

typedef struct _image {
    vector<uint64_t> base;
    vector<uint64_t> end;
} ImagePtr;

class CGPMemoryEngine {
public:
    uintptr_t GetImageBase(const string& imageName);

    CGPMemoryEngine(mach_port_t task);
    ~CGPMemoryEngine(void);
    
    void CGPScanMemory(AddrRange range, void* target, size_t len);
    void CGPNearBySearch(int range, void *target, size_t len);
    bool CGPSearchByAddress(unsigned long long address, void* target, size_t len);
    
    void *CGPReadMemory(unsigned long long address, size_t len);
    bool CGPWriteMemory(void* address, void *target, int len);
    
    vector<void*> GetAllResults();
    vector<void*> GetResults(int count);
    
    void* CGPAllocateMemory(size_t size);
    void CGPDeallocateMemory(void* address, size_t size);
    
    kern_return_t CGPProtectMemory(void* address, size_t size, vm_prot_t protection);
    kern_return_t CGPQueryMemory(void* address, vm_size_t* size, vm_prot_t* protection, vm_inherit_t* inheritance);
    kern_return_t CGPRebindSymbol(const char* symbol, void* replacement, void** oldFunction);
    

    bool ChangeMemoryProtection(uintptr_t address, size_t size, int protection);
    
    template<int Index>
    void VMTHook(uintptr_t classInstance, uintptr_t newFunction, uintptr_t& originalFunction);
    
    bool RebindSymbol(const char* symbolName, void* newFunction, void** originalFunction);
    bool RebindSymbols(
        const vector<tuple<const char*, void*, void**>>& symbols,
        const function<bool(const char*)>& condition = nullptr,
        const function<void(const char*)>& onFailure = nullptr
    );
    
    bool RemapLibrary(const string& libraryName);

    void ParseIDAPattern(const string& ida_pattern, vector<uint8_t>& pattern, string& mask);
    uintptr_t ScanPattern(const uint8_t* data, size_t data_len, const uint8_t* pattern, const char* mask);
    uintptr_t ScanIDAPattern(const uint8_t* data, size_t data_len, const string& ida_pattern);
    
    bool IsValidAddress(long addr);
    bool WriteMemory(void* address,void *target, int len);
    template<typename T> void Write(long address, T value){
        WriteMemory((void*)address, reinterpret_cast<void *>(&value), sizeof(T));
    }
    template<typename T>
    T Read(unsigned long long address) {
        size_t len = sizeof(T);
        void* memory = CGPReadMemory(address, len);
        
        if (memory == nullptr) {
            return T();
        }

        T data;
        memcpy(&data, memory, len);  // Copy data into the variable of type T
        free(memory);               // Free the allocated memory
        return data;
    }



private:
    mach_port_t task;
    Result *result;
    
    void ResultDeallocate(Result *result);
    Result* ResultAllocate(void);
};


#endif /* CGPMemory_h */
