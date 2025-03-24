#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#include <mach/mach.h>
#include <mach/vm_map.h>

#import "../fishhook/fishhook.h"
#import "../mempatch/THPatchMem.h"
#import "../brk_hook/Hook/hook_wrapper.hpp"
#import "../utils/utils.h"
#import "../MemX/MemX.hpp"

@interface TitanoxHook : NSObject

// custom vm funcs (auto bypasses processes hooking and logging them)
+ (void)patchMemoryAtAddress:(void *)address withPatch:(uint8_t *)patch size:(size_t)size;
+ (BOOL)readMemoryAt:(mach_vm_address_t)address buffer:(void *)buffer size:(mach_vm_size_t)size;
+ (BOOL)writeMemoryAt:(mach_vm_address_t)address data:(const void *)data size:(mach_vm_size_t)size;
+ (void *)allocateMemoryWithSize:(mach_vm_size_t)size flags:(int)flags;
+ (BOOL)deallocateMemoryAt:(mach_vm_address_t)address size:(mach_vm_size_t)size;
+ (kern_return_t)protectMemoryAt:(mach_vm_address_t)address size:(mach_vm_size_t)size setMax:(BOOL)setMax protection:(vm_prot_t)newProt;

// Hooking & swizzling (set & exchange impl)
+ (void)hookStaticFunction:(const char *)symbol withReplacement:(void *)replacement inLibrary:(const char *)libName outOldFunction:(void **)oldFunction;
+ (void)swizzleMethod:(SEL)originalSelector withMethod:(SEL)swizzledSelector inClass:(Class)targetClass;
+ (void)overrideMethodInClass:(Class)targetClass 
                     selector:(SEL)selector 
              withNewFunction:(IMP)newFunction
            oldFunctionPointer:(IMP *)oldFunctionPointer;
+ (BOOL)isFunctionHooked:(const char *)symbol withOriginal:(void *)original inLibrary:(const char *)libName;
+ (void)hookBoolByName:(const char *)symbol inLibrary:(const char *)libName;

// Brk hook & unhook
+ (BOOL)addBreakpointAtAddress:(void *)original withHook:(void *)hook;
+ (BOOL)removeBreakpointAtAddress:(void *)original;

// Binary utils
+ (uint64_t)getBaseAddressOfLibrary:(const char *)libName;
+ (intptr_t)getVmAddrSlideOfLibrary:(const char *)libName;
+ (NSString *)findExecInBundle:(NSString *)libName;

// Logging
+ (void)log:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);

// MemX Wrappers
+ (uintptr_t)MemXgetImageBase:(NSString *)imageName;
+ (BOOL)MemXisValidPointer:(uintptr_t)address;
+ (BOOL)MemXreadMemory:(uintptr_t)address buffer:(void *)buffer length:(size_t)len;
+ (NSString *)MemXreadString:(uintptr_t)address maxLength:(size_t)maxLen;
+ (void)MemXwriteMemory:(uintptr_t)address value:(NSNumber *)value type:(NSString *)type;

@end
