#import "libtitanox.h"
#import <dlfcn.h>
#import <mach/mach.h>
#import <mach/vm_map.h>
#import <Foundation/Foundation.h>
#import "../MemoryManager/CGuardMemory/CGPMemory.h" 
#import "../fishhook/fishhook.h"
#import "../LH_jailed/libhooker-jailed.h"

// decl
static CGPMemoryEngine *memoryEngine = nullptr;

@implementation TitanoxHook

+ (void)initializeMemoryEngine {
    // Initialize the memory engine here. 
    mach_port_t task = mach_task_self();
    if (memoryEngine == nullptr) {
        memoryEngine = new CGPMemoryEngine(task);
    }
}

uint64_t GetBaseAddress(const char* dylibName) {
    for (uint32_t i = 0; i < _dyld_image_count(); ++i) {
        const char* DyldName = _dyld_get_image_name(i);
        if (DyldName && strstr(DyldName, dylibName)) {
            return (uint64_t)_dyld_get_image_header(i);
        }
    }
    return 0;
}

intptr_t GetVmAddrSlide(const char* dylibName) {
    for (uint32_t i = 0; i < _dyld_image_count(); ++i) {
        const char* DyldName = _dyld_get_image_name(i);
        if (DyldName && strstr(DyldName, dylibName)) {
            return _dyld_get_image_vmaddr_slide(i);
        }
    }
    return 0;
}

#pragma mark - LHHookFunction for jailed IOS.

+ (void)LHHookFunction:(void*)target_function hookFunction:(void*)hook_function inLibrary:(const char*)libName outHookRef:(LHHookRef*)out_hook_ref {

    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *libPath = [bundlePath stringByAppendingPathComponent:[NSString stringWithUTF8String:libName]];

    
    NSLog(@"[LHHookFunction] Hooking into lib at: %@", libPath);

    
    void *handle = dlopen([libPath UTF8String], RTLD_NOW | RTLD_NOLOAD);
    if (!handle) {
        NSLog(@"[LHHookFunction] Failed to open lib: %s", dlerror());
        return;
    }

    // HOOK
    NSLog(@"[LHHookFunction] Hooking target function at %p with hook function at %p", target_function, hook_function);
    LHHookFunction(target_function, hook_function, out_hook_ref);

    
    dlclose(handle);
    NSLog(@"[LHHookFunction] Hook Successful.");
}

#pragma mark - Static Function Hooking

+ (void)hookStaticFunction:(const char *)symbol withReplacement:(void *)replacement outOldFunction:(void **)oldFunction {
    if ([self isFunctionHooked:symbol withOriginal:*oldFunction inLibrary:NULL]) {
        NSLog(@"Warning: Function %s is already hooked.", symbol);
        return;
    }
    
    struct rebinding rebind;
    rebind.name = symbol;
    rebind.replacement = replacement;
    rebind.replaced = oldFunction;
    
    struct rebinding rebindings[] = { rebind };
    
    int result = rebind_symbols(rebindings, 1);
    if (result != 0) {
        NSLog(@"Failed to hook %s with error %d", symbol, result);
    } else {
        NSLog(@"Successfully hooked %s", symbol);
    }
}

#pragma mark - Inline Hooking

+ (void)hookFunctionByName:(const char *)symbol inLibrary:(const char *)libName withReplacement:(void *)replacement outOldFunction:(void **)oldFunction {
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *libPath = [bundlePath stringByAppendingPathComponent:[NSString stringWithUTF8String:libName]];
    void *handle = dlopen([libPath UTF8String], RTLD_NOW | RTLD_NOLOAD);
    
    if (!handle) {
        NSLog(@"Failed to open library: %s", libName);
        return;
    }

    void *originalFunction = dlsym(handle, symbol);
    if (!originalFunction) {
        NSLog(@"Failed to find symbol: %s", symbol);
        dlclose(handle);
        return;
    }

    if ([self isFunctionHooked:symbol withOriginal:originalFunction inLibrary:libName]) {
        NSLog(@"Warning: Function %s is already hooked.", symbol);
        dlclose(handle);
        return;
    }

    *oldFunction = originalFunction;

    // init mem-engine if not done yet.
    [self initializeMemoryEngine];

    // mem-write
    if (memoryEngine) {
        memoryEngine->CGPWriteMemory((long)originalFunction, &replacement, sizeof(replacement));
    }

    dlclose(handle);
    NSLog(@"Successfully hooked %s in library %s", symbol, libName);
}

#pragma mark - Method Swizzling

+ (void)swizzleMethod:(SEL)originalSelector withMethod:(SEL)swizzledSelector inClass:(Class)targetClass {
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

+ (void)patchMemoryAtAddress:(void *)address withData:(const void *)data length:(size_t)length {
    if (![self isSafeToPatchMemoryAtAddress:address length:length]) {
        NSLog(@"Memory patching aborted: unsafe memory region.");
        return;
    }

    // Init again!!!
    [self initializeMemoryEngine];

    if (memoryEngine) {
        memoryEngine->CGPWriteMemory((long)address, (void *)data, (int)length);
    }
}

#pragma mark - isHookedAlready?

+ (BOOL)isFunctionHooked:(const char *)symbol withOriginal:(void *)original inLibrary:(const char *)libName {
    Dl_info info;
    if (dladdr(original, &info)) {
        NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
        NSString *libPath = [bundlePath stringByAppendingPathComponent:[NSString stringWithUTF8String:libName]];
        
        if (strcmp(info.dli_sname, symbol) == 0 && (!libName || [libPath isEqualToString:[NSString stringWithUTF8String:info.dli_fname]])) {
            return NO; // Not hooked
        }
    }
    return YES; // Hooked
}

#pragma mark - BoolChange

+ (void)hookBoolByName:(const char *)symbol inLibrary:(const char *)libName {
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *libPath = [bundlePath stringByAppendingPathComponent:[NSString stringWithUTF8String:libName]];
    
    void *handle = dlopen([libPath UTF8String], RTLD_NOW | RTLD_NOLOAD);
    if (!handle) {
        NSLog(@"Failed to open library: %s", libName);
        return;
    }
    
    bool *boolAddress = (bool *)dlsym(handle, symbol);
    if (!boolAddress) {
        NSLog(@"Failed to find symbol: %s", symbol);
        dlclose(handle);
        return;
    }
    
    if (![self isSafeToPatchMemoryAtAddress:boolAddress length:sizeof(bool)]) {
        NSLog(@"Memory patching aborted: unsafe memory region.");
        dlclose(handle);
        return;
    }
    
    // True->False / False->True. for example let's say in libexample.dylib, a boolean var 'isvalid` is set to false. we can use this to set it to true by just the bool name and lib name.
    *boolAddress = !*boolAddress;
    NSLog(@"Successfully toggled boolean %s in library %s to %d", symbol, libName, *boolAddress);
    
    dlclose(handle);
}

#pragma mark - B.A & VM.ADDR.S

+ (uint64_t)getBaseAddressOfLibrary:(const char *)dylibName {
    return GetBaseAddress(dylibName); 
}

+ (intptr_t)getVmAddrSlideOfLibrary:(const char *)dylibName {
    return GetVmAddrSlide(dylibName); 
}

#pragma mark - Safety Checks

+ (BOOL)isSafeToPatchMemoryAtAddress:(void *)address length:(size_t)length {
    if (!address || length == 0) {
        NSLog(@"Error: Invalid memory address or length.");
        return NO;
    }

    vm_address_t regionStart = (vm_address_t)address;
    vm_size_t regionSize = 0;
    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t infoCount = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t objectName;
    
    if (vm_region_64(mach_task_self(), &regionStart, &regionSize, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&info, &infoCount, &objectName) != KERN_SUCCESS) {
        NSLog(@"Error: Failed to get memory region info.");
        return NO;
    }

    return info.protection & VM_PROT_WRITE;
}

@end
