#import "libtitanox.h"
#import <dlfcn.h>
#import <mach/mach.h>
#import <mach/vm_map.h>
#import <Foundation/Foundation.h>
#import "../MemoryManager/CGuardMemory/CGPMemory.h"
#import "../fishhook/fishhook.h"
#import "../LH_jailed/libhooker-jailed.h"
#import "../brk_hook/breakpoint.h"
#import "../Frameworks/JRMemory.framework/Headers/MemScan.h"



@implementation TitanoxHook

+ (void)initJRMemEngine {
 if (JRengine == nullptr) {
     JRengine = new JRMemoryEngine(mach_task_self());
 }
}

+ (void)initCGPMemEngine {
    if (CGPmemoryEngine == nullptr) {
        CGPmemoryEngine = new CGPMemoryEngine(mach_task_self());
    }
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

+ (void)initBrk {

    init_breakpoints();
}

+ (void)addBreakpointAtAddress:(void *)target replacement:(void *)replacement outOriginal:(void **)orig {
    [self initBrk];
    NSLog(@"Adding a breakpoint...");
    add_breakpoint(target, replacement, orig);
    NSLog(@"Added brk hook for %p", target);
}


#pragma mark - LHHookFunction for Jailed iOS

+ (void)LHHookFunction:(void*)target_function 
         hookFunction:(void*)hook_function 
             inLibrary:(const char*)libName 
           outHookRef:(LHHookRef*)out_hook_ref {

    NSString *libNameString = [NSString stringWithUTF8String:libName];
    NSString *libPath = [self findExecInBundle:libNameString];
    
    NSLog(@"[LHHookFunction] Hooking into library at path: %@", libPath);

    void *handle = dlopen([libPath UTF8String], RTLD_NOW | RTLD_NOLOAD);
    if (!handle) {
        NSLog(@"[LHHookFunction] Failed to open library: %s", dlerror());
        return;
    }

    NSLog(@"[LHHookFunction] Hooking target function at %p with hook function at %p", target_function, hook_function);
    LHHookFunction(target_function, hook_function, out_hook_ref);

    dlclose(handle);
    NSLog(@"[LHHookFunction] Hooking complete and library closed");
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

#pragma mark - Static Function Hooking

+ (void)hookStaticFunction:(const char *)symbol 
         withReplacement:(void *)replacement 
          inLibrary:(const char *)libName 
        outOldFunction:(void **)oldFunction {

    NSString *libNameString = [NSString stringWithUTF8String:libName];
    NSString *libPath = [self findExecInBundle:libNameString];

    void *handle = dlopen([libPath UTF8String], RTLD_NOW | RTLD_NOLOAD);
    
    if (!handle) {
        NSLog(@"Failed to open library: %s", libName);
        return;
    }

    if ([self isFunctionHooked:symbol withOriginal:*oldFunction inLibrary:libName]) {
        NSLog(@"Warning: Function %s is already hooked.", symbol);
        dlclose(handle);
        return;
    }

    struct rebinding rebind;
    rebind.name = symbol;
    rebind.replacement = replacement;
    rebind.replaced = oldFunction;

    int result = rebind_symbols((struct rebinding[]){rebind}, 1);
    if (result != 0) {
        NSLog(@"Failed to hook %s with error %d", symbol, result);
    } else {
        NSLog(@"Successfully hooked %s", symbol);
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

+ (void *)ReadMemAtAddr:(unsigned long long)address size:(size_t)size {
    if (size == 0 || address == 0) {
        NSLog(@"Error: Invalid address or size.");
        return NULL;
    }

    
    void *buffer = malloc(size);
    if (buffer == NULL) {
        NSLog(@"Error: Failed to alloc mem for buffer.");
        return NULL;
    }

    
    vm_size_t bytesRead = 0;
    kern_return_t kr = vm_read_overwrite(mach_task_self(), address, size, (vm_address_t)buffer, &bytesRead);

    if (kr != KERN_SUCCESS || bytesRead != size) {
        NSLog(@"Error: vm_read_overwrite failed for address: 0x%llx, size: %zu. Error code: %d", address, size, kr);
        free(buffer);
        return NULL;
    }

    
    void *res = malloc(size);
    if (res == NULL) {
        NSLog(@"Error: Failed to allocate memory for buffer.");
        free(buffer);
        return NULL;
    }

    memcpy(res, buffer, size);
    free(buffer);
    return res;
}



+ (BOOL)JRwriteMemory:(uint64_t)address withData:(const void *)data length:(size_t)length {
    if (JRengine == nullptr) {
        NSLog(@"JRMemoryEngine is not initialized. Attempting to initialize...");
        [self initJRMemEngine];
    }

    if (JRengine == nullptr) {
        NSLog(@"Error: JRMemoryEngine failed to initialize.");
        return NO;
    }

    if (address == 0 || data == nullptr || length == 0) {
        NSLog(@"Error: Invalid address (0x%llx), data, or length.", address);
        return NO;
    }

    
    JRengine->JRWriteMemory(address, (void *)data, length);
    
    NSLog(@"Successfully wrote %zu bytes to address 0x%llx.", length, address);
    return YES;
}


+ (void)CGPWriteMemoryAtAddress:(void *)address 
                   withData:(const void *)data 
                     length:(size_t)length {

    if (![self isSafeToPatchMemoryAtAddress:address length:length]) {
        NSLog(@"Memory patching aborted: unsafe memory region.");
        return;
    }

    [self initCGPMemEngine];

    if (CGPmemoryEngine) {
        CGPmemoryEngine->WriteMemory((void*)address, (void*)data, (int)length);
        if (!address || !data) {
            NSLog(@"Address and/or data is invalid.");
            return;
        }
        //CGPmemoryEngine->CGPWriteMemory((long)address, (void *)data, (int)length);
    }
}

+ (void)patchMemoryAtAddress:(void *)address 
                   withPatch:(uint8_t*)patch 
                       size:(size_t)size {

    bool res = THPatchMem::PatchMemory(address, patch, size);
    if (!address || address == nullptr) {
        NSLog(@"Invalid address.");
        return;
    }

    
    if (res) {
        NSLog(@"Memory patch succeeded at address %p", address);
    } else {
        NSLog(@"Memory patch failed at address %p", address);
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
    return YES; // Hooked
}

#pragma mark - Bool Hooking

+ (void)hookBoolByName:(const char *)symbol 
             inLibrary:(const char *)libName {

    NSString *libNameString = [NSString stringWithUTF8String:libName];
    NSString *libPath = [self findExecInBundle:libNameString];
    
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
    
    *boolAddress = !*boolAddress;
    NSLog(@"Successfully toggled bool %s in library %s to %d", symbol, libName, *boolAddress);
    
    dlclose(handle);
}

#pragma mark - Safety Checks

+ (BOOL)isSafeToPatchMemoryAtAddress:(void *)address 
                              length:(size_t)length {

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

#pragma mark - B.A & VM.ADDR.SLIDE

+ (uint64_t)getBaseAddressOfLibrary:(const char *)libName {
    return GetBaseAddress(libName); 
}

+ (intptr_t)getVmAddrSlideOfLibrary:(const char *)libName {
    return GetVmAddrSlide(libName);
}

@end