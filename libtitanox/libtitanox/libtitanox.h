#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#include <mach/mach.h>
#include <mach/vm_map.h>
#import "../MemoryManager/CGuardMemory/CGPMemory.h"
#import "../fishhook/fishhook.h"
#import "../LH_jailed/libhooker-jailed.h"

@interface TitanoxHook : NSObject


 /*

1. LHHookFunction (libhooker's FunctionHook reimplemented for non-jailbroken devices)
2. Function Hooking (fishhook rebinding)
3. Inline Function Hooking (CGuardProbe's API) -> need to init mem-engine
4. Method Swizzling
5. Memory Patching (CGuardProbe's API) -> need to init mem-engine
6. Bool state change (CGuardProbe's API) -> need to init mem-engine
7. Already Hooked?
8. BaseAddress & VM.Addr.Slide get

** INIT MEMORY ENGINE FOR MEMORY RELATED FUNCTIONS **
*/

+ (void)LHHookFunction:(void*)target_function hookFunction:(void*)hook_function inLibrary:(const char*)libName outHookRef:(LHHookRef*)out_hook_ref;

+ (void)initializeMemoryEngine;

+ (void)hookStaticFunction:(const char *)symbol withReplacement:(void *)replacement outOldFunction:(void **)oldFunction;

+ (void)hookFunctionByName:(const char *)symbol inLibrary:(const char *)libName withReplacement:(void *)replacement outOldFunction:(void **)oldFunction;

+ (void)swizzleMethod:(SEL)originalSelector withMethod:(SEL)swizzledSelector inClass:(Class)targetClass;

+ (void)overrideMethodInClass:(Class)targetClass 
                     selector:(SEL)selector 
              withNewFunction:(IMP)newFunction
            oldFunctionPointer:(IMP *)oldFunctionPointer;

+ (void)patchMemoryAtAddress:(void *)address withData:(const void *)data length:(size_t)length;

+ (BOOL)isFunctionHooked:(const char *)symbol withOriginal:(void *)original inLibrary:(const char *)libName;

+ (void)hookBoolByName:(const char *)symbol inLibrary:(const char *)libName;

+ (uint64_t)getBaseAddressOfLibrary:(const char *)dylibName;

+ (intptr_t)getVmAddrSlideOfLibrary:(const char *)dylibName;

@end
