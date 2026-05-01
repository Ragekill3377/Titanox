// https://github.com/Aethereux/MemX
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

    struct AddrRange {
        uintptr_t start;
        uintptr_t end;
    };

    // https://developer.apple.com/documentation/kernel/mach_header/
    inline const std::vector<AddrRange>& GetFullAddr() {
        static std::vector<AddrRange> ranges;
        // we just need to get ranges once
        // calling over n over is redundant
        if (!ranges.empty()) {
            return ranges;
        }

        for (uint32_t i = 0; i < _dyld_image_count(); ++i) {
            const mach_header* header = _dyld_get_image_header(i);
            intptr_t slide = _dyld_get_image_vmaddr_slide(i);
            if (!header) continue;

            const uint8_t* ptr = reinterpret_cast<const uint8_t*>(header);
            const load_command* cmd = nullptr;
            uint32_t ncmds = 0;

            switch (header->magic) {
                // ncmds -> https://developer.apple.com/documentation/kernel/mach_header/1525650-ncmds
                //64-bit
                case MH_MAGIC_64: {
                    const auto* hdr = reinterpret_cast<const mach_header_64*>(ptr);
                    cmd = reinterpret_cast<const load_command*>(hdr + 1);
                    ncmds = hdr->ncmds;
                    break;
                }
                //32-bit
                case MH_MAGIC: {
                    const auto* hdr = reinterpret_cast<const mach_header*>(ptr);
                    cmd = reinterpret_cast<const load_command*>(hdr + 1);
                    ncmds = hdr->ncmds;
                    break;
                }
                default:
                    continue;
            }

            for (uint32_t j = 0; j < ncmds; ++j) {
                switch (cmd->cmd) {
                    // https://developer.apple.com/documentation/kernel/segment_command_64
                    // goes through the load commands
                    case LC_SEGMENT_64: {
                        const auto* seg = reinterpret_cast<const segment_command_64*>(cmd);
                        uintptr_t start = static_cast<uintptr_t>(seg->vmaddr + slide); // ASLR start
                        uintptr_t end = start + static_cast<uintptr_t>(seg->vmsize); // vmsize is end
                        ranges.push_back({start, end});
                        break;
                    }
                    default:
                        break;
                }
                cmd = reinterpret_cast<const load_command*>(
                    reinterpret_cast<const uint8_t*>(cmd) + cmd->cmdsize);
            }
        }
        return ranges;
    }
    
    // if in any case some action like closing or loading
    // new libs occurs in mem space, which messes with addr range
    // you can clear it to reset addr range
    // IsValidPointer automatically populates it anyways.
    inline void ClearAddrRange() {
        static std::vector<AddrRange>& ranges = const_cast<std::vector<AddrRange>&>(GetFullAddr());
        if (ranges.empty()) return;
        ranges.clear();
    }

    // better 'IsValidPointer'
    inline bool IsValidPointer(uintptr_t addr) {
        const auto& ranges = GetFullAddr();
        for (const auto& r : ranges) {
            if (addr >= r.start && addr < r.end) {
                return true;
            }
        }
        return false;
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
