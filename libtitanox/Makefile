TARGET := iphone:clang:latest:7.0
ARCHS = arm64
DEBUG = 0
FINALPACKAGE = 1
FOR_RELEASE = 1

IGNORE_WARNINGS = 1

THEOS = /home/rage/theos

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = libtitanox

# Srcs
MEMORY_MANAGER_FILES := $(wildcard MemoryManager/CGuardMemory/*.cpp)
FISHHOOK_FILES := $(wildcard fishhook/*.c)
MAIN_SRCS := $(wildcard libtitanox/*.mm)

$(LIBRARY_NAME)_FILES = $(FISHHOOK_FILES) $(MEMORY_MANAGER_FILES) $(MAIN_SRCS)
$(LIBRARY_NAME)_CFLAGS = -fobjc-arc -Wall -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-value -Wno-unused-function
$(LIBRARY_NAME)_CCFLAGS = -std=c++11 -fno-rtti -fno-exceptions -DNDEBUG -Wall -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-value -Wno-unused-function

# non-jb path. you could change this
$(LIBRARY_NAME)_INSTALL_PATH = @executable_path
$(LIBRARY_NAME)_FRAMEWORKS = Foundation

include $(THEOS_MAKE_PATH)/library.mk

after-package::
	@echo -e "\033[0;33m==> Copying libtitanox.dylib to packages directory...\033[0m"
	@timeout 2 cp /home/rage/theos/lib/libtitanox.dylib ./packages/
	@echo -e "\033[0;32m==> Copy complete.\033[0m"

	@echo -e "\033[0;33m==> Removing .deb file from packages...\033[0m"
	@rm -f packages/*.deb
	@echo -e "\033[0;32m==> .deb file removed.\033[0m"
