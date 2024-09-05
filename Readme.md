# Titanox

`Titanox` is a hooking framework for dynamic libraries on iOS. It utilizes `fishhook` for symbol rebinding and `CGuardMemory` for advanced memory management. This library supports function hooking, method swizzling, memory patching etc. It does not have any external dependencies and can be used on **non-jailbroken/non-rooted** IOS devices with full functionailty!!!

## Features

- **Function Hooking**: Hook functions and rebind symbols.
- **Method Swizzling**: Replace methods in Objective-C classes.
- **Memory Patching**: Modify memory contents safely.
- **Bool-Hooking**: Toggle boolean values in memory, to the opposite of their original state.
- **Is Hooked**: Check if a function is already hooked. *This is done automatically.*
- **Base Address & VM Address Slide Get**: Get ``BaseAddress`` i.e header of the target library and the ``vm addr`` slide.

## APIs:~

- **fishhook**: A library for symbol rebinding used by @facebook. [fishhook](https://github.com/facebook/fishhook.git)
- **CGuardMemory**: A memory management library by @OPSphystech420. [CGuardProbe/CGuardMemory](https://github.com/OPSphystech420/CGuardProbe.git)

### Documentation:~
# Usage:~

**Initialize Memory Engine**
Before using any functions that require *memory operations*, initialize the **memory-engine**:

```objc
[TitanoxHook initializeMemoryEngine];
```

**Function Hooking**
Hook a function by symbol(Will hook in main task process):

```objc
[TitanoxHook hookStaticFunction:"symbolName" withReplacement:newFunction outOldFunction:&oldFunction];
```  

**Hook a function in a specific library:(Will hook in target library/Binary specified in 'inLibrary'. Full name is required.**

```objc
[TitanoxHook hookFunctionByName:"symbolName" inLibrary:"libName.dylib" withReplacement:newFunction outOldFunction:&oldFunction];
```

**Method Swizzling**
Swizzle a method in a class:

```objc
[TitanoxHook swizzleMethod:@selector(originalMethod) withMethod:@selector(swizzledMethod) inClass:[TargetClass class]];
```

**Method Overriding**
Override a method in a class with a new implementation:

```objc
[TitanoxHook overrideMethodInClass:[TargetClass class]
                          selector:@selector(methodToOverride)
                   withNewFunction:newFunction
                 oldFunctionPointer:&oldFunction];
```

**Memory Patching**
Patch memory at a specific address:

```objc
[TitanoxHook patchMemoryAtAddress:address withData:data length:length];
```

**Boolean Hooking**
Toggle a boolean value in a dynamic library:

```objc

[TitanoxHook hookBoolByName:"booleanSymbol" inLibrary:"libName.dylib"];
```

**Base Address & VM Address Slide**
Get the base address of a dynamic library:

```objc
uint64_t baseAddress = [TitanoxHook getBaseAddressOfLibrary:"libName.dylib"];
```

Get the VM address slide of a dynamic library:

```objc
intptr_t vmAddrSlide = [TitanoxHook getVmAddrSlideOfLibrary:"libName.dylib"];
```



## Compiling From Source:~

### Theos:~
[theos](https://theos.dev): A cross-platform build system for creating iOS, macOS, Linux, and Windows programs.
* Install theos based on your device.

**Prequisites:~**

For linux: ``sudo apt install bash curl sudo``. 
***Can vary depending on distribution. This is for kali/ubuntu/debian or other debian based distros.***

For macOS: Install [brew](https://brew.sh) & xcode-command-line utilities, aswell as xcode itself.

For Windows: Install WSL (Window's subsystem for Linux) and use any linux distribution. I recommend ``Ubuntu``.

Once that is done, copy paste this command:
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos)"
```
It will install theos for you. wait until installation is completed.

**For more detailed/well-explained steps, please head over to https://theos.dev/docs for installing theos on your platform**

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
* Link against ``libtitanox`` and include the headers.


# **Disclaimer: This is made solely for **NON-JAILBROKEN DEVICES**
            # This framework cannot R/W directly to segments or modify protected segments, unless there is a jailbreak or JIT.
            # But, this was made for non-jailbroken devices and it's intended use is within an application's sandbox. So runtime dissasembly, patching assembly instructions etc. is **NOT** feasible.

# TODO:
     * Add modifed substrate and libhooker APIs.
     * Incoporate ellekit's C & Objctive-C hooks.

### License:
You are free to use this code. I am not responsible for any illegal or malicious acts caused by the use of this code.
