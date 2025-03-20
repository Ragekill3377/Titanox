# **Titanox**

## Overview

**`Titanox`** is an advanced hooking framework for iOS. It utilizes `fishhook` for symbol rebinding and `CGuardMemory` for enhanced memory management. Additionally, it has another known memory framework called ``JRMemory``, which is similar to CGuardMemory. It also contains a reimplemented version of ``libhooker`` by CoolStar (The creator of the Electra jailbreak for iOS 11.). This library supports function hooking, method swizzling, memory patching etc. It does not have any external dependencies and can be used on **non-jailbroken/non-rooted** iOS devices with ~full~ *some* functionality.

*Experimental*: This framework also uses ``breakpoint hooks``. Inspired from: [The Ellekit Team](https://github.com/tealbathingsuit/ellekit).

## Features
**Beta Function**: brk hooking.
- **Breakpoint hooks**: Apply upto maximum 6 hooks via breakpoints at runtime.
- **2 DIFFERENT BRK HOOKS**

-> You can use either the new or old, both are Ellekit-based.

-> The new one is recommended as it also supports ``unhooking``.

-> The new one is stable and supports a jailed environment.

**Use the new breakpoint hook.**
  
- **Inline Function hooking (by offset)**: Hooks functions utilising symbols. Under the hood, it is instruction patching.
- **Function Hooking (by symbol)**: Hook functions and rebind symbols (fishhook). FUNCTIONS MUST BE EXPORTED!
- **Method Swizzling**: Replace methods in Objective-C classes.
- **Memory Patching**: Modify memory contents safely.
-> Read (Uses direct mach vm, since I had some *issues*)
  
-> Write (CGP) // diff mem manager

-> Write (JRM) // diff mem framework

-> Patch (Insipred from Dobby's CodePatch, made to work on stock iOS)

- **Bool-Hooking**: Toggle boolean values in memory, to the opposite of their original state.
- **Is Hooked**: Check if a function is already hooked. *This is done automatically.*
- **Base Address & VM Address Slide Get**: Get ``BaseAddress`` i.e header of the target library and the ``vm addr`` slide.

**LOGS ARE SAVED TO DOCUMENT'S DIRECTORY AS ``TITANOX_LOGS.TXT``. NO NEED TO USE ``NSLog`` or ``Console`` app to view logs! You can take logging from ``utils/utils.mm``.** -> can be changed by modifying file name in ``utils/utils.mm``.

## APIs:~

- **fishhook**: A library for symbol rebinding used by @facebook. [fishhook](https://github.com/facebook/fishhook.git)

- **CGuardMemory**: A memory management library by @OPSphystech420. [CGuardProbe/CGuardMemory](https://github.com/OPSphystech420/CGuardProbe.git)

- **JRMemory**: A simple memory management library @x2niosvn. [JRMemory.framework](https://github.com/x2niosvn/iOS-Simple-IGG-Mod-Menu/tree/main/X2N/JRMemory.framework)

- **libhooker**: A hooking framework for jailbroken devices, which was reimplemented in ``Titanox`` for non-jailbroken usage. by @coolstar. [libhooker OSS](https://github.com/coolstar/libhooker.git)
**LIBHOOKER JAILED IS REPLACED BY BRK HOOKS. WILL BE REMOVED ENTIRELY NEXT UPDATE**
# Usage/Documentation:~

**Initialize Memory Engine**
Before using any functions that require *memory operations*, initialize the **memory-engine**:

```objc
[TitanoxHook initCGPMemEngine]; // cgp memory engine
[TitanoxHook initJRMemEngine];  // JRMemory engine
```
P.S: You do NOT have to initialize the engine. it will automatically be initialized in the memory related functions such as the mem write function. However if you'd like to make your own usages globally, then you should.

**BRK Hook (Aarch64/arm64)**
**BRK 1 (Old):**
```objc
void* targetFunction = (void*)dlsym(RTLD_DEFAULT, "_exit"); // example.
void* replacementFunction = (void*)replacementFunction;
void* originalFunction = NULL; // just an example, but please store orig  func pointer of target func pointer, and use that!

[TitanoxHook addBreakpointAtAddress:targetFunction replacement:replacementFunction outOriginal:&originalFunction];
```
**BRK 2 (NEW + RECOMMENDED):**
```objc
static void (*original_exit)(int) = NULL;

void hooked_exit(int status) {
    NSLog(@"[HOOK] _exit called with status: %d", status);

    if (original_exit) {
        original_exit(status);
    }
}

void hook_exit() {
    original_exit = (void (*)(int)) dlsym(RTLD_DEFAULT, "_exit");

    if (!original_exit) {
        NSLog(@"[ERROR] Failed to find _exit symbol");
        return;
    }

    if ([TitanoxHook addBreakpointAtAddressNew:(void *)original_exit withHook:(void *)hooked_exit]) {
        NSLog(@"[HOOK] _exit hooked successfully");
    } else {
        NSLog(@"[ERROR] Failed to hook _exit");
    }
}

void unhook_exit() {
    if (!original_exit) {
        NSLog(@"[ERROR] Cannot unhook _exit: original_exit is NULL");
        return;
    }

    if ([TitanoxHook removeBreakpointAtAddress:(void *)original_exit]) {
        NSLog(@"[HOOK] _exit unhooked successfully");
    } else {
        NSLog(@"[ERROR] Failed to unhook _exit");
    }
}
```
**Difference between BRK 1 & 2?**
-> 1 requires an orig back, that makes 3 parameters
-> 2 doesn't need an orig, so 2 paramters.
-> 1 can't remove hooks, 2 can.
-> **NEW(2)**: You can use a debugger and use brk hooks without any interference.

**BOTH have a limit to 6 in total (you cannot exceed the limit of 6 hooks combined.)**


**LHHookFunction for jailed IOS**
**Inline Function hooking**

Hook a function via the trampoline hook, using the reimplemented libhooker API.
* This patches instructions in the binary at runtime, and changes the branch instructions to your own hooks. It may require JIT.
* If fails, fallback to a breakpoint hook!
```objc
LHHookRef hookRef;
[TitanoxHook LHHookFunction:targetFunction hookFunction:yourhook inLibrary:"libexample" outHookRef:&hookRef];

if (hookRef.trampoline) {
NSLog(@"Success.");
} else {
NSLog(@"Failed.");
}
```

**Function Hooking by fishhook (static)**
Hook a function by symbol using fishhook (Will hook in main task process):
* Function must be exported as a symbol. it cannot work without symbol.

```objc
[TitanoxHook hookStaticFunction:"symbolName" withReplacement:newFunction outOldFunction:&oldFunction];
```  

**Hook a function in a specific library**:
(Will hook in target library/Binary specified in 'inLibrary'.) Full name is required. i.e extension if any e.g .dylib. **It auto loads in the target if not loaded in!**
Can be the main executable or a loaded library in the application.**
* this is same as static function hook, but it automatically loads in the target executable.

```objc
[TitanoxHook hookFunctionByName:"symbolName" inLibrary:"libName" withReplacement:newFunction outOldFunction:&oldFunction];
```

**Method Swizzling**
Swizzle a method in a class:
* exchange implementation

```objc
[TitanoxHook swizzleMethod:@selector(originalMethod) withMethod:@selector(swizzledMethod) inClass:[TargetClass class]];
```

**Method Overriding**
Override a method in a class with a new implementation:
* set new implementation

```objc
[TitanoxHook overrideMethodInClass:[TargetClass class]
                          selector:@selector(methodToOverride)
                   withNewFunction:newFunction
                 oldFunctionPointer:&oldFunction];
```

**Memory Patching**
R/W memory at a specific address:
**Read**
```objc

long baseAddr = [TitanoxHook getBaseAddressOfLibrary:"ShooterGame"];


unsigned long long targetAddr = baseAddr + 0x740;

// read 4 bytes as an example
size_t dataSize = sizeof(int);
void *data = [TitanoxHook ReadMemAtAddr:targetAddr size:dataSize];

if (data != NULL) {
    int *intValue = (int *)data;
    NSLog(@"Read value: %d from address: 0x%llx", *intValue, targetAddr);
    free(data);
} else {
    NSLog(@"Failed to read memory from address: 0x%llx", targetAddr);
}

```
**Write (JRM)**:
```objc
unsigned long long targetAddr = baseAddr + 0x740;
uint8_t dataToWrite = 0x9A;
BOOL success = [TitanoxHook JRwriteMemory:targetAddr withData:&dataToWrite length:sizeof(dataToWrite)];

if (success) {
    NSLog(@"Successfully wrote data to address: 0x%llx", targetAddr);
} else {
    NSLog(@"Failed to write data to address: 0x%llx", targetAddr);
}
```

**Write (CGP)**:
```objc
void *targetAddr = (void *)(baseAddr + 0x740); // cast to void* since it expects a void ptr

uint8_t dataToPatch = 0x9A;

[TitanoxHook CGPpatchMemoryAtAddress:targetAddr withData:&dataToPatch length:sizeof(dataToPatch)];

NSLog(@"Memory written to address: %p", targetAddr);
```

**Patch Memory**(it may require JIT):
```objc
    // ARM64 NOP instruction (4-byte)
    uint32_t nop[] = {0x1F2003D5};  // ARM64 NOP instruction
    void *addr = (void *)0x1000;    // mem addr
    size_t len = sizeof(patch);       // size

    // This will NOP the fun/data at specified address. this makes it target address do nothing/have nothing as an example.
    [TitanoxHook patchMemoryAtAddress:addr withPatch:nop size:len];
```

**Boolean Hooking**
Toggle a bool value in a dynamic library (add .dylib ext) / executable:
* this must also have symbol.
  
```objc

[TitanoxHook hookBoolByName:"bool-symbol" inLibrary:"libName"];
```

**Base Address & VM Address Slide**
Get the base address of a dynamic library (add .dylib ext) / executable:

```objc
uint64_t baseAddress = [TitanoxHook getBaseAddressOfLibrary:"ShooterGame"]; // change name
```

Get the VM address slide of a dynamic library (add .dylib ext) / executable:

```objc
intptr_t vmAddrSlide = [TitanoxHook getVmAddrSlideOfLibrary:"ShooterGame"]; // change name
```



## Compiling From Source:~

### Theos:~
[theos](https://theos.dev): A cross-platform build system for creating iOS, macOS, Linux, and Windows programs.
* Install theos based on your device.

**Prequisites:~**

For linux: ``sudo apt install bash curl sudo``. 
***Can vary depending on distribution. This is for kali/ubuntu/debian or other debian based distros.***

For macOS: Install [brew](https://brew.sh) & xcode-command-line utilities, aswell as xcode itself.
P.S: You do not need to code in xcode itself, but the installation for it is mandatory.

For Windows: Install WSL (Window's subsystem for Linux) and use any linux distribution. I recommend ``Ubuntu``.

Once that is done, copy paste this command:
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos)"
```
It will install theos for you. wait until installation is completed.

**For more detailed/well-explained steps, please head over to [theos's official documentation](https://theos.dev/docs) for installing theos on your platform**

## Compiling:~
* You can use **Theos** to build your own jailbroken or jailed/non-jailbroken IOS tweaks, frameworks, libraries etc.
* For this, git clone this repo:
```bash
git clone https://github.com/Ragekill3377/Titanox.git
```
* cd into the directory:
```bash
cd Titanox
```

* Open ``Makefile`` in any editor.
* remove `theos` variable set in ``Makefile`` as ``/home/rage/theos``, or just replace that path with the path to your own theos.
* save the Makefile.
* Run ``build`` to compile the titanox library:
```bash
./build
```

You will get a .deb file in your output directory i.e ``packages``. Also, it will move the *.dylib* to your $THEOS/lib directory as **libtitanox.dylib** (Unless you changed TWEAK_NAME in ``Makefile``).
You can use this to link against your own code, or even you could merge Titanox's sources with your own.

### Using release builds:~
* Navigate to releases
* Download the latest ``libtitanox.dylib``.
* Put ``libtitanox.dylib`` in **theos/lib**.
* Link against ``libtitanox`` and include the header.

**In a Theos Makefile:**
```make
$(TWEAK_NAME)_LDFLAGS = -L$(THEOS)/lib -ltitanox -Wl,-rpath,@executable_path # TODO: Change tweak name if needed.
```

This will link *libtitanox.dylib*. From there, you can inject your own library or binary which uses Titanox, & Titanox itself.

**Will optimise memory managers or replace them entirely soon.**
this includes:
* CGuardMemory
* JRMemory

# **DISCLAIMER**
**Titanox is in no way a JAILBREAK or a TWEAK INJECTION LIBRARY.**  
It is a **HOOKING framework for IN-APP.**

This is used to, say, make modifications to processes **within a sandbox** however you'd like—giving you more freedom while still respecting iOS constraints.

The **libhooker functionality DID NOT make jailbroken tweaks work without a jailbreak.**  
This was **removed** because it did not function properly outside of a jailbreak.  

**Please do not spread misinformation without consulting the developer or contributors first on what can be said about Titanox.**

Titanox **can** be used for what was mentioned—**IF** you have a jailbreak! But you guys don't.  
Maybe you want **mods for apps,** maybe you want to **patch things in apps,** maybe you want to **hook functions in apps.**
That's what **Titanox is for.**

Titanox is meant for **developers** to create tools like that for users.

Titanox is **still being tested and developed.** Expect bugs. Report them.
Don't expect everything to be working well. For bug reports, you must test multiple cases and see if the issue is a bug with Titanox or something you're doing wrong.

  
### License:
You are free to modify and utilise this code. However, We are not responsible for any damages, legal issues or malicious use resulting from this code.

# Credits:
**Ragekill3377** -> Owner + Main Developer

**Aethereux** -> developer

**timi2506** -> developer

**WhySooooFurious** -> developer

**UnrealSrcZ** -> developer

**Speedyfriend67** -> developer
