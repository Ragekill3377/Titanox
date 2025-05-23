#pragma once

#include <cstdint>
#include <cstring>
#include <cstdlib>
#include <vector>
#include <string>
#include <utility>
#include <unistd.h>
#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <sys/mman.h>
#include <Foundation/Foundation.h>

namespace MemX {
    inline uintptr_t GetImageBase(const std::string& imageName) {
        for (uint32_t i = 0; i < _dyld_image_count(); ++i) {
            const char* imgName = _dyld_get_image_name(i);
            if (imgName && strstr(imgName, imageName.c_str())) {
                return reinterpret_cast<uintptr_t>(_dyld_get_image_header(i));
            }
        }
        return 0;
    }

    inline bool IsValidPointer(uintptr_t address) {
        return address >= 0x100000000 && address < 0x3000000000;
    }

    inline bool _read(uintptr_t addr, void* buffer, size_t len) {
        return IsValidPointer(addr) && (std::memcpy(buffer, reinterpret_cast<void*>(addr), len), true);
    }

    template <typename T>
    inline T Read(uintptr_t address) {
        T data{};
        _read(address, &data, sizeof(T));
        return data;
    }

    inline std::string ReadString(void* address, size_t max_len) {
        if (!IsValidPointer(reinterpret_cast<uintptr_t>(address))) return "Invalid Pointer!!";
        std::vector<char> chars(max_len + 1, '\0');
        if (_read(reinterpret_cast<uintptr_t>(address), chars.data(), max_len)) {
            return std::string(chars.data(), strnlen(chars.data(), max_len));
        }
        return "";
    }

    template <typename T>
    inline void Write(uintptr_t address, const T& value) {
        if (IsValidPointer(address)) *reinterpret_cast<T*>(address) = value;
    }
}