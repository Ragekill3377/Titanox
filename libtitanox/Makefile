TARGET := iphone:clang:13.7
ARCHS = arm64
DEBUG = 0
FINALPACKAGE = 1
FOR_RELEASE = 1

#IGNORE_WARNINGS = 1

# Change to your own $THEOS path, or remove if env is already set. I had a shell issue :/
THEOS = /home/rage/theos
SYSROOT = $(THEOS)/sdks/iPhoneOS13.7.sdk
# AGAIN i had fucking SDK issues...
# had to downgrade to 13.7
include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = libtitanox

# Srcs
Capstone_FILES = \
    decoder/capstone/cs.c \
    $(wildcard decoder/capstone/arch/AArch64/*.c) \
    $(filter-out decoder/capstone/cs.c, $(wildcard decoder/capstone/*.c))
	
FISHHOOK_FILES := $(wildcard fishhook/*.c)
LIBHOOKER_FILES := $(wildcard LH_jailed/*.mm)
BRK_HOOK_FILES := $(wildcard brk_hook/Hook/*.c)
MEMPATCH_FILES := $(wildcard mempatch/*.mm)
UTILS_FILES := $(wildcard utils/*.mm)
MAIN_SRCS := $(wildcard libtitanox/*.mm)
VM_FILES := $(wildcard vm_funcs/*.mm)
MEMX_FILES := $(wildcard MemX/*.mm)
DISASM_FILES := $(wildcard decoder/*.mm)

$(LIBRARY_NAME)_FILES = $(Capstone_FILES) $(DISASM_FILES) $(MEMX_FILES) $(BRK_HOOK_FILES) $(VM_FILES) $(UTILS_FILES) $(FISHHOOK_FILES) $(MAIN_SRCS) $(MEMPATCH_FILES)
$(LIBRARY_NAME)_CFLAGS = -fobjc-arc -Wall -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-value -Wno-unused-function -Idecoder/. -Idecoder/capstone -Idecoder/capstone/include

$(LIBRARY_NAME)_CCFLAGS = -std=c++17 -fno-rtti -fno-exceptions -DNDEBUG -Wall -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-value -Wno-unused-function -Idecoder/. -Idecoder/capstone -Idecoder/capstone/include

$(LIBRARY_NAME)_LDFLAGS = -L./Frameworks/capstone/

# you could change this to @rpath
$(LIBRARY_NAME)_INSTALL_PATH = @executable_path
$(LIBRARY_NAME)_FRAMEWORKS = Foundation CoreFoundation

include $(THEOS_MAKE_PATH)/library.mk

# Remove all this if you want. This basically just gives me my dylib extracted from the .deb.
after-package::
	@echo -e "\033[0;33m==> Copying libtitanox.dylib to packages directory...\033[0m"
	@timeout 2 cp /home/rage/theos/lib/libtitanox.dylib ./packages/
	@echo -e "\033[0;32m==> Copy complete.\033[0m"

	@echo -e "\033[0;33m==> Removing .deb file from packages...\033[0m"
	@rm -f packages/*.deb
	@echo -e "\033[0;32m==> .deb file removed.\033[0m"
