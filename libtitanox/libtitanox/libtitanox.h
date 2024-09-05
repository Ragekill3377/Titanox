#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#include <mach/mach.h>
#include <mach/vm_map.h>
#import "../MemoryManager/CGuardMemory/CGPMemory.h"
#import "../fishhook/fishhook.h"

@interface TitanoxHook : NSObject


 /*
Function Hooking
Method Swizzling
Memory Patching
Bool state change
Already Hooked?
BaseAddress & VM.Addr.Slide get

** INIT MEMORY ENGINE FOR MEMORY RELATED FUNCTIONS **

*/

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
