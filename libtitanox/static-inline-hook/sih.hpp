#pragma once

#include <cstdint>
#include <string>
#include <memory>
#include <vector>
#include <optional>
#include <mach-o/loader.h>
#include <Foundation/Foundation.h>

namespace SIH {

struct HookBlock {
    uint64_t hook_vaddr{0};
    uint64_t original_vaddr{0};
    uint64_t patched_vaddr{0};
    uint64_t code_vaddr{0};
    uint64_t code_size{0};
    uint64_t patch_size{0};
    uint64_t patch_hash{0};
    
    void* target_replace{nullptr};
};

class MachOHooker {
public:
    explicit MachOHooker(const std::string& macho_name);
    ~MachOHooker() = default;

    std::optional<std::string> apply_patch(uint64_t vaddr, const std::string& patch_bytes);
    void* hook_function(uint64_t vaddr, void* replacement);
    bool activate_patch(uint64_t vaddr, const std::string& patch_bytes);
    bool deactivate_patch(uint64_t vaddr, const std::string& patch_bytes);

private:
    static constexpr size_t CODE_PAGE_SIZE = 4096; /* 4 KB */
    static constexpr size_t DATA_PAGE_SIZE = 4096; /* 4 KB */
    
    static constexpr const char* HOOK_TEXT_SEGMENT = "__TITANOX_HOOK";
    static constexpr const char* HOOK_DATA_SEGMENT = "__TITANOX_HOOK";
    
    static constexpr const char* HOOK_TEXT_SECTION = "__titanox_text";
    static constexpr const char* HOOK_DATA_SECTION = "__titanox_data";

    std::string macho_name_;
    NSMutableData* macho_data_{nullptr};
    mach_header_64* header_{nullptr};

    struct segment_command_64* text_segment_{nullptr};
    struct segment_command_64* data_segment_{nullptr};
    
    uint32_t cryptid_{0};

    struct MachOInfo {
        uint64_t vm_end{0};
        uint64_t min_section_offset{0};
        
        struct segment_command_64* linkedit_seg{nullptr};
    };

    bool load_macho_data();
    bool validate_macho();
    bool add_hook_sections();
    bool update_linkedit_commands(uint64_t offset);
    bool save_patched_binary();
    bool apply_inline_patch(HookBlock* block, uint64_t func_rva, void* func_data, uint64_t target_rva, void* target_data, const std::string& patch_bytes);
    static bool hex_to_bytes(const std::string& hex, std::vector<uint8_t>& buffer);
    std::optional<MachOInfo> parse_macho_info();
    uint64_t va_to_rva(uint64_t va) const;
    static uint64_t calculate_patch_hash(uint64_t vaddr, const std::string& patch);
    void* rva_to_data(uint64_t rva) const;
    void* find_module_base() const;
    HookBlock* find_hook_block(void* base, uint64_t vaddr) const;
};

}