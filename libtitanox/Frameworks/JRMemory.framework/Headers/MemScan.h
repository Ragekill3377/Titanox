//
//  Header.h
//  MemoryScan
//
//  Created by macgu on 2020/2/24.
//  Copyright © 2020年 macgu. All rights reserved.
//

#pragma once

#include <mach-o/dyld.h>
#include <mach/mach.h>
#include "MemoryManager/CGuardMemory/CGPMemory.h"

#include <stdio.h>

#include <algorithm>

#include <vector>
#define JR_Search_Type_ULong 8
#define JR_Search_Type_Double 8
#define JR_Search_Type_SLong 8
#define JR_Search_Type_Float 4
#define JR_Search_Type_UInt 4
#define JR_Search_Type_SInt 4
#define JR_Search_Type_UShort 2
#define JR_Search_Type_SShort 2
#define JR_Search_Type_UByte 1
#define JR_Search_Type_SByte 1


using namespace std;
/*typedef struct _result_region{
    mach_vm_address_t region_base;
    vector<uint32_t>slide;
}result_region;

typedef struct _result{
    vector<result_region*>resultBuffer;
    int count;
}Result;

typedef struct _addrRange{
    uint64_t start;
    uint64_t end;
}AddrRange;

typedef struct _image{
    vector<uint64_t>base;
    vector<uint64_t>end;
}ImagePtr; */
class JRMemoryEngine
{
public:
    mach_port_t task;
    Result *result;
    JRMemoryEngine(mach_port_t task){
        this->task = task;
        Result *newResult = new Result;
        newResult->count = 0;
        this->result = newResult;
    }
    ~JRMemoryEngine(void){
        if(result->count != 0){
            for(int i =0;i<result->resultBuffer.size();i++){
                
                result->resultBuffer[i]->slide.clear();
                result->resultBuffer[i]->slide.shrink_to_fit();
                result_region *dealloc_1 = result->resultBuffer[i];
                delete dealloc_1;
                
            }
        }
        result->resultBuffer.clear();
        result->resultBuffer.shrink_to_fit();
        Result *dealloc_2 = result;
        delete dealloc_2;
    }
    
    
    void JRScanMemory(AddrRange range,void*target,size_t len);
    void JRNearBySearch(int range,void *target,size_t len);
    
    //void *JRReadMemory(unsigned long long address,size_t len);
    void JRWriteMemory(unsigned long long address,void *target,size_t len);
    
    vector<void*> getAllResults();
    vector<void*> getResults(int count);
    
    
};

void ResultDeallocate(Result *result);
Result* ResultAllocate(void);

