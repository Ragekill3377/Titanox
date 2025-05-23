#import "libtitanox.h"
#import <dlfcn.h>
#import <mach/mach.h>
#import <mach/vm_map.h>
#import <Foundation/Foundation.h>
#include <mach-o/dyld.h>
#include <mach/mach.h>
#import "../fishhook/fishhook.h"
#include "../brk_hook/Hook/hook_wrapper.hpp"
#import "../MemX/MemX.hpp"
#import "../MemX/VMTWrapper.h"
#import "../vm_funcs/vm.hpp"


@implementation TitanoxHook

#pragma mark - logging to TITANOX_LOGS.txt

+ (void)log:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    THLog(format, args);
    va_end(args);
}


#pragma mark - Base Address and VM Address Slide

uint64_t GetBaseAddress(const char* libName) {
    for (uint32_t i = 0; i < _dyld_image_count(); ++i) {
        const char* DyldName = _dyld_get_image_name(i);
        if (DyldName && strstr(DyldName, libName)) {
            return (uint64_t)_dyld_get_image_header(i);
        }
    }
    return 0;
}

intptr_t GetVmAddrSlide(const char* libName) {
    for (uint32_t i = 0; i < _dyld_image_count(); ++i) {
        const char* DyldName = _dyld_get_image_name(i);
        if (DyldName && strstr(DyldName, libName)) {
            return _dyld_get_image_vmaddr_slide(i);
        }
    }
    return 0;
}

#pragma mark - Breakpoint hook

// breakpoint hook with NO orig.
+ (BOOL)addBreakpointAtAddress:(void *)original withHook:(void *)hook {
    if (!original || !hook) {
        THLog(@"[ERROR] addBreakpointAtAddress: invalid params. original=%p, hook=%p", original, hook);
        return NO;
    }
    void *origArray[] = { original };
    void *hookArray[] = { hook };
    BOOL res = HookWrapper::callHook(origArray, hookArray, 1);
    if (res) {
        THLog(@"Added a breakpoint at address: %p", original);
    } else {
        THLog(@"Failed to add breakpoint at address: %p. Maybe your hooks exceeded limits or something else...", original);
    }
    return res;
}

#pragma mark - remove breakpoint (Only supports new method)

+ (BOOL)removeBreakpointAtAddress:(void *)original {
    if (!original) {
        THLog(@"[ERROR] invalid param. original=%p", original);
        return NO;
    }
    void *origArray[] = { original };
    BOOL res = HookWrapper::callUnHook(origArray, 1);
    if (res) {
        THLog(@"[HOOK] Removed breakpoint at address: %p", original);
    } else {
        THLog(@"[ERROR] Failed to remove breakpoint at address: %p", original);
    }
    return res;
}

+ (NSString *)findExecInBundle:(NSString *)libName {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *mainBundlePath = [[NSBundle mainBundle] bundlePath];
    NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtPath:mainBundlePath];
    
    for (NSString *filePath in enumerator) {
        
        if ([filePath.lastPathComponent isEqualToString:libName]) {
            return [mainBundlePath stringByAppendingPathComponent:filePath];
        }
    }
    
    return nil;
}

+ (uintptr_t)MemXgetImageBase:(NSString *)imageName {
    return MemX::GetImageBase([imageName UTF8String]);
}

+ (BOOL)MemXisValidPointer:(uintptr_t)address {
    return MemX::IsValidPointer(address);
}

+ (BOOL)MemXreadMemory:(uintptr_t)address buffer:(void *)buffer length:(size_t)len {
    return MemX::_read(address, buffer, len);
}

+ (NSString *)MemXreadString:(uintptr_t)address maxLength:(size_t)maxLen {
    return [NSString stringWithUTF8String:MemX::ReadString((void *)address, maxLen).c_str()];
}

+ (void)MemXwriteMemory:(uintptr_t)address value:(NSNumber *)value type:(NSString *)type {
    static NSDictionary<NSString *, NSNumber *> *typeMap;
    if (!typeMap) {
        typeMap = @{
            @"int"       : @0,
            @"long"      : @1,
            @"uintptr_t" : @2,
            @"uint32_t"  : @3,
            @"uint64_t"  : @4,
            @"uint8_t"   : @5
        };
    }

    switch (typeMap[type].intValue) {
        case 0: MemX::Write<int>(address, [value intValue]); break;
        case 1: MemX::Write<long>(address, [value longValue]); break;
        case 2: MemX::Write<uintptr_t>(address, (uintptr_t)[value unsignedLongLongValue]); break;
        case 3: MemX::Write<uint32_t>(address, [value unsignedIntValue]); break;
        case 4: MemX::Write<uint64_t>(address, [value unsignedLongLongValue]); break;
        case 5: MemX::Write<uint8_t>(address, [value unsignedCharValue]); break;
        default: THLog(@"[MemX] Unknown type: %@", type); break;
    }
}

#pragma mark - MemX Virtual Function hooking stuff
//from -> ../MemX/VMTWrapper.h"
+ (void *)vmthookCreateWithNewFunction:(void *)newFunc index:(int32_t)index {
    if (!newFunc) {
        THLog(@"[ERROR] vmthookCreateWithNewFunction: ERROR - newFunc is NULL");
        return NULL;
    }
    if (index < 0) {
        THLog(@"[ERROR] vmthookCreateWithNewFunction: ERROR - index (%d) is negative", index);
        return NULL;
    }
    THLog(@"[...] vmthookCreateWithNewFunction: Creating hook with newFunc=%p, index=%d", newFunc, index);
    void *makehook = VMTHook_Create(newFunc, index);
    if (!makehook) {
        THLog(@"[ERROR] vmthookCreateWithNewFunction: Failed to create hook");
    } else {
        THLog(@"[Success] vmthookCreateWithNewFunction: Hook created at %p", hook);
    }
    return makehook;
}

+ (void)vmthookSwap:(void *)hook instance:(void *)instance {
    if (!hook) {
        THLog(@"[ERROR] vmthookSwap: ERROR - hook pointer is NULL");
        return;
    }
    if (!instance) {
        THLog(@"[ERROR] vmthookSwap: ERROR - instance pointer is NULL");
        return;
    }
    THLog(@"[...] vmthookSwap: Swapping hook %p on instance %p", hook, instance);
    VMTHook_Swap(hook, instance);
    THLog(@"[Success] vmthookSwap: Swap complete");
}

+ (void)vmthookReset:(void *)hook instance:(void *)instance {
    if (!hook) {
        THLog(@"[ERROR] vmthookReset: ERROR - hook pointer is NULL");
        return;
    }
    if (!instance) {
        THLog(@"[ERROR] vmthookReset: ERROR - instance pointer is NULL");
        return;
    }
    THLog(@"[...] vmthookReset: Resetting hook %p on instance %p", hook, instance);
    VMTHook_Reset(hook, instance);
    THLog(@"[Success] vmthookReset: Reset complete");
}

+ (void)vmthookDestroy:(void *)hook {
    if (!hook) {
        THLog(@"[ERROR] vmthookDestroy: ERROR - hook pointer is NULL");
        return;
    }
    THLog(@"[...] vmthookDestroy: Destroying hook %p", hook);
    VMTHook_Destroy(hook);
    THLog(@"[Success] vmthookDestroy: Destroy complete");
}

+ (void *)vmtinvokerCreateWithInstance:(void *)instance index:(int32_t)index {
    if (!instance) {
        THLog(@"[ERROR] vmtinvokerCreateWithInstance: ERROR - instance pointer is NULL");
        return NULL;
    }
    if (index < 0) {
        THLog(@"[ERROR] vmtinvokerCreateWithInstance: ERROR - index (%d) is negative", index);
        return NULL;
    }
    THLog(@"[...] vmtinvokerCreateWithInstance: Creating invoker for instance %p, index %d", instance, index);
    void *callhookidk = VMTInvoker_Create(instance, index);
    if (!callhookidk) {
        THLog(@"[ERROR] vmtinvokerCreateWithInstance: Failed to create invoker");
    } else {
        THLog(@"[Success] vmtinvokerCreateWithInstance: Invoker created at %p", callhookidk);
    }
    return callhookidk;
}

+ (void)vmtinvokerDestroy:(void *)invoker {
    if (!invoker) {
        THLog(@"[ERROR] vmtinvokerDestroy: ERROR - invoker pointer is NULL");
        return;
    }
    THLog(@"[...] vmtinvokerDestroy: Destroying invoker %p", invoker);
    VMTInvoker_Destroy(invoker);
    THLog(@"[Success] vmtinvokerDestroy: Destroy complete");
}

#pragma mark - Static Function Hooking

+ (void)hookStaticFunction:(const char *)symbol 
         withReplacement:(void *)replacement 
          inLibrary:(const char *)libName 
        outOldFunction:(void **)oldFunction {

    NSString *libNameString = [NSString stringWithUTF8String:libName];
    NSString *libPath = [self findExecInBundle:libNameString];

    void *handle = dlopen([libPath UTF8String], RTLD_NOW | RTLD_NOLOAD);
    
    if (!handle) {
        THLog(@"Failed to open library: %s", libName);
        return;
    }

    if ([self isFunctionHooked:symbol withOriginal:*oldFunction inLibrary:libName]) {
        THLog(@"Warning: Function %s is already hooked.", symbol);
        dlclose(handle);
        return;
    }

    struct rebinding rebind;
    rebind.name = symbol;
    rebind.replacement = replacement;
    rebind.replaced = oldFunction;

    int result = rebind_symbols((struct rebinding[]){rebind}, 1);
    if (result != 0) {
        THLog(@"Failed to hook %s with error %d", symbol, result);
    } else {
        THLog(@"Successfully hooked %s", symbol);
    }
    dlclose(handle);
}

#pragma mark - Method Swizzling

+ (void)swizzleMethod:(SEL)originalSelector 
          withMethod:(SEL)swizzledSelector 
            inClass:(Class)targetClass {

    Method originalMethod = class_getInstanceMethod(targetClass, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(targetClass, swizzledSelector);
    
    BOOL didAddMethod = class_addMethod(targetClass,
                                        originalSelector,
                                        method_getImplementation(swizzledMethod),
                                        method_getTypeEncoding(swizzledMethod));
    
    if (didAddMethod) {
        class_replaceMethod(targetClass,
                            swizzledSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

#pragma mark - Method Overriding

+ (void)overrideMethodInClass:(Class)targetClass 
                     selector:(SEL)selector 
              withNewFunction:(IMP)newFunction 
            oldFunctionPointer:(IMP *)oldFunctionPointer {

    Method method = class_getInstanceMethod(targetClass, selector);
    
    if (oldFunctionPointer) {
        *oldFunctionPointer = method_getImplementation(method);
    }
    
    method_setImplementation(method, newFunction);
}

#pragma mark - Memory Patching



+ (BOOL)readMemoryAt:(mach_vm_address_t)address buffer:(void *)buffer size:(mach_vm_size_t)size {
    return vm_read_custom(address, buffer, size);
}

+ (BOOL)writeMemoryAt:(mach_vm_address_t)address data:(const void *)data size:(mach_vm_size_t)size {
    return vm_write_custom(address, data, size);
}

+ (void *)allocateMemoryWithSize:(mach_vm_size_t)size flags:(int)flags {
    return vm_allocate_custom(size, flags);
}

+ (BOOL)deallocateMemoryAt:(mach_vm_address_t)address size:(mach_vm_size_t)size {
    return vm_deallocate_custom(address, size);
}

+ (kern_return_t)protectMemoryAt:(mach_vm_address_t)address size:(mach_vm_size_t)size setMax:(BOOL)setMax protection:(vm_prot_t)newProt {
    return vm_protect_custom(address, size, setMax, newProt);
}

+ (void)patchMemoryAtAddress:(void *)address 
                   withPatch:(uint8_t*)patch 
                       size:(size_t)size {

    bool res = THPatchMem::PatchMemory(address, patch, size);
    if (!address || address == nullptr) {
        THLog(@"Invalid address.");
        return;
    }
    
    if (res) {
        THLog(@"Memory patch succeeded at address %p", address);
    } else {
        THLog(@"Memory patch failed at address %p", address);
    }
}

#pragma mark - isHooked

+ (BOOL)isFunctionHooked:(const char *)symbol 
           withOriginal:(void *)original 
             inLibrary:(const char *)libName {

    Dl_info info;
    if (dladdr(original, &info)) {
    NSString *libNameString = [NSString stringWithUTF8String:libName];
    NSString *libPath = [self findExecInBundle:libNameString];
        
        if (strcmp(info.dli_sname, symbol) == 0 && (!libName || [libPath isEqualToString:[NSString stringWithUTF8String:info.dli_fname]])) {
            return NO; // Not hooked
        }
    }
    return YES;
}

#pragma mark - Bool Hooking

+ (void)hookBoolByName:(const char *)symbol 
             inLibrary:(const char *)libName {

    NSString *libNameString = [NSString stringWithUTF8String:libName];
    NSString *libPath = [self findExecInBundle:libNameString];
    
    void *handle = dlopen([libPath UTF8String], RTLD_NOW | RTLD_NOLOAD);
    if (!handle) {
        THLog(@"Failed to open library: %s", libName);
        return;
    }
    
    bool *boolAddress = (bool *)dlsym(handle, symbol);
    if (!boolAddress) {
        THLog(@"Failed to find symbol: %s", symbol);
        dlclose(handle);
        return;
    }
    
    if (![self isSafeToPatchMemoryAtAddress:boolAddress length:sizeof(bool)]) {
        THLog(@"Memory patching aborted: unsafe memory region.");
        dlclose(handle);
        return;
    }
    
    *boolAddress = !*boolAddress;
    THLog(@"Successfully toggled bool %s in library %s to %d", symbol, libName, *boolAddress);
    
    dlclose(handle);
}

#pragma mark - Safety Checks

+ (BOOL)isSafeToPatchMemoryAtAddress:(void *)address 
                              length:(size_t)length {

    if (!address || length == 0) {
        THLog(@"Error: Invalid memory address or length.");
        return NO;
    }

    vm_address_t regionStart = (vm_address_t)address;
    vm_size_t regionSize = 0;
    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t infoCount = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t objectName;
    
    if (vm_region_64(mach_task_self(), &regionStart, &regionSize, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&info, &infoCount, &objectName) != KERN_SUCCESS) {
        THLog(@"Error: Failed to get memory region info.");
        return NO;
    }

    return info.protection & VM_PROT_WRITE;
}

#pragma mark - Capstone things

+ (NSString *)decodeOpcodeAtAddress:(void *)addr {
    if (!addr) {
        THLog(@"[ERROR] Null addr passed to decoder.");
        return @"<null addr>";
    }
    THLog(@"[...] Decoding instruction at addr: %p", addr);
    std::string res = OpcodeDecoder::decode_from_addr(addr);
    if (res.empty()) {
        THLog(@"[ERROR] Decoding failed or returned empty string.");
        return @"<invalid>";
    }
    NSString *decodedres = [NSString stringWithUTF8String:res.c_str()];
    if (!decodedres) {
        THLog(@"[ERROR] NSString conversion failed.");
        return @"<conversion error>";
    }
    THLog(@"[Success] Decoded instruction: %@", decodedres);
    return decodedres;
}


#pragma mark - B.A & VM.ADDR.SLIDE

+ (uint64_t)getBaseAddressOfLibrary:(const char *)libName {
    return GetBaseAddress(libName); 
}

+ (intptr_t)getVmAddrSlideOfLibrary:(const char *)libName {
    return GetVmAddrSlide(libName);
}

@end