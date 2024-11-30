#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#include <mach/mach.h>
#include <mach/vm_map.h>
#import "../MemoryManager/CGuardMemory/CGPMemory.h"
#import "../fishhook/fishhook.h"
#import "../LH_jailed/libhooker-jailed.h"
#import "../brk_hook/breakpoint.h"
#import "../Frameworks/JRMemory.framework/Headers/MemScan.h"
#import "../mempatch/THPatchMem.h"


static CGPMemoryEngine *CGPmemoryEngine = nullptr;
static CGPMemoryEngine *memEngine = nullptr;
static JRMemoryEngine *JRengine = nullptr;

@interface TitanoxHook : NSObject

+ (void)initCGPMemEngine;
+ (void)initJRMemEngine;

// ...
+ (BOOL)JRwriteMemory:(uint64_t)address withData:(const void *)data length:(size_t)length;
+ (void *)ReadMemAtAddr:(unsigned long long)address size:(size_t)size;
+ (void)patchMemoryAtAddress:(void *)address withPatch:(const void *)patch size:(size_t)size;
+ (NSString *)findExecInBundle:(NSString *)libName;
+ (void)LHHookFunction:(void*)target_function hookFunction:(void*)hook_function inLibrary:(const char*)libName outHookRef:(LHHookRef*)out_hook_ref;
+ (void)hookStaticFunction:(const char *)symbol withReplacement:(void *)replacement inLibrary:(const char*)libName outOldFunction:(void **)oldFunction;
//+ (void)hookFunctionByName:(const char *)symbol inLibrary:(const char *)libName withReplacement:(void *)replacement outOldFunction:(void **)oldFunction;
+ (void)swizzleMethod:(SEL)originalSelector withMethod:(SEL)swizzledSelector inClass:(Class)targetClass;
+ (void)overrideMethodInClass:(Class)targetClass 
                     selector:(SEL)selector 
              withNewFunction:(IMP)newFunction
            oldFunctionPointer:(IMP *)oldFunctionPointer;
+ (void)CGPWriteMemoryAtAddress:(void *)address withData:(const void *)data length:(size_t)length;
+ (BOOL)isFunctionHooked:(const char *)symbol withOriginal:(void *)original inLibrary:(const char *)libName;
+ (void)hookBoolByName:(const char *)symbol inLibrary:(const char *)libName;
+ (uint64_t)getBaseAddressOfLibrary:(const char *)libName;
+ (intptr_t)getVmAddrSlideOfLibrary:(const char *)libName;
+ (void)initBrk;
+ (void)addBreakpointAtAddress:(void *)target replacement:(void *)replacement outOriginal:(void **)orig;

@end
