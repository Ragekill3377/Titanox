# My shell was fish and for some reason it couldn't recognize some stuff. for example I had to set the theos var here...Please change things according to your env. Besides the theos var set here, you shouldn't have to change other stuff.

TARGET := iphone:clang:latest:latest    # iphone:clang:latest:7.0
ARCHS = arm64 # Please don't compile for arm64e. only system apps on IOS are arm64e, those which support those archs.
DEBUG = 0
FINALPACKAGE = 1
FOR_RELEASE = 1

IGNORE_WARNINGS = 1

THEOS = /home/rage/theos # TODO: CHANGE THEOS HOME PATH TO YOUW OWN

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = libtitanox

# Srcs
MEMORY_MANAGER_FILES := $(wildcard MemoryManager/CGuardMemory/*.cpp)
FISHHOOK_FILES := $(wildcard fishhook/*.c)
LIBHOOKER_FILES := $(wildcard LH_jailed/*.mm)
MAIN_SRCS := $(wildcard libtitanox/*.mm)

$(LIBRARY_NAME)_FILES = $(FISHHOOK_FILES) $(MEMORY_MANAGER_FILES) $(MAIN_SRCS) $(LIBHOOKER_FILES)
$(LIBRARY_NAME)_CFLAGS = -fobjc-arc -Wall -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-value -Wno-unused-function
$(LIBRARY_NAME)_CCFLAGS = -std=c++11 -fno-rtti -fno-exceptions -DNDEBUG -Wall -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-value -Wno-unused-function

# non-jb path within an application's sandbox. you could change this, like to @rpath.
$(LIBRARY_NAME)_INSTALL_PATH = @executable_path
$(LIBRARY_NAME)_FRAMEWORKS = Foundation

include $(THEOS_MAKE_PATH)/library.mk
