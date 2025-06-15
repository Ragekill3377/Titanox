#include "sih.hpp"
#include "../utils/utils.h"
#include <mach-o/dyld.h>
#include <mach-o/fat.h>
#include <mach/vm_page_size.h>
#include <libgen.h>
#include <string>
#include <algorithm>

#define LOG(...) THLog(__VA_ARGS__)

using namespace SIH;

MachOHooker::MachOHooker(const std::string& macho_name) : macho_name_(macho_name) {
    if (macho_name_.empty()) {
        LOG(@"can't init, no name...");
        return;
    }
    load_macho_data();
}

bool MachOHooker::load_macho_data() {
    std::string save_path = [NSHomeDirectory() stringByAppendingPathComponent:
        [NSString stringWithFormat:@"Documents/titanox-hook/%s", macho_name_.c_str()]].UTF8String;

    THLog(@"checking from an already patched version @ : %s", save_path.c_str());
    macho_data_ = [NSMutableData dataWithContentsOfFile:@(save_path.c_str())];
    if (!macho_data_ && [[NSFileManager defaultManager] fileExistsAtPath:@(save_path.c_str())]) {
        THLog(@"failed to load patched Mach-O from: %s", save_path.c_str());
        return false;
    }

    if (!macho_data_) {
        THLog(@"Since it's not found, let's go for the real thing...");
        std::string path;
        NSString *targetName = [NSString stringWithUTF8String:macho_name_.c_str()];
        NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtPath:bundlePath];
        NSString *file;
        while ((file = [enumerator nextObject])) {
            if ([file.lastPathComponent isEqualToString:targetName]) {
            NSString *fullPath = [bundlePath stringByAppendingPathComponent:file];
            path = [fullPath UTF8String];
            THLog(@"Found at: %@", fullPath);
            break;
            }
        }
        if (path.empty()) {
            THLog(@"Not found: %@", targetName);
            return false;
        }

        macho_data_ = [NSMutableData dataWithContentsOfFile:@(path.c_str())];
        if (!macho_data_) {
        THLog(@"Couldn't load its data, can't even read?: %s", path.c_str());
        return false;
        }
    }
    THLog(@"loaded binary");
    return validate_macho();
}


bool MachOHooker::validate_macho() {
    if (macho_data_.length < sizeof(mach_header_64)) {
        LOG(@"invalid file: too small");
        return false;
    }

    header_ = static_cast<mach_header_64*>([macho_data_ mutableBytes]);
    uint32_t magic = header_->magic;

    if (magic == FAT_CIGAM) {
        struct fat_header* fat_header = static_cast<struct fat_header*>([macho_data_ mutableBytes]);
        uint32_t nfat_arch = NSSwapLong(fat_header->nfat_arch);
        if (nfat_arch != 1) {
            LOG(@"multiple archs not supported");
            return false;
        }

        struct fat_arch* arch = static_cast<struct fat_arch*>((void*)((uint64_t)fat_header + sizeof(*fat_header)));
        if (NSSwapLong(arch->cputype) != CPU_TYPE_ARM64 || arch->cpusubtype != 0) {
            LOG(@"Unsupported architecture");
            return false;
        }

        uint32_t offset = NSSwapLong(arch->offset);
        uint32_t size = NSSwapLong(arch->size);
        macho_data_ = [NSMutableData dataWithData:[macho_data_ subdataWithRange:NSMakeRange(offset, size)]];
        header_ = static_cast<mach_header_64*>([macho_data_ mutableBytes]);
    } else if (magic == FAT_CIGAM_64) {
        struct fat_header* fat_header = static_cast<struct fat_header*>([macho_data_ mutableBytes]);
        uint32_t nfat_arch = NSSwapLong(fat_header->nfat_arch);
        if (nfat_arch != 1) {
            LOG(@"Multiple architectures not supported");
            return false;
        }

        struct fat_arch_64* arch = static_cast<struct fat_arch_64*>((void*)((uint64_t)fat_header + sizeof(*fat_header)));
        if (NSSwapLong(arch->cputype) != CPU_TYPE_ARM64 || arch->cpusubtype != 0) {
            LOG(@"Unsupported architecture");
            return false;
        }

        uint32_t offset = NSSwapLongLong(arch->offset);
        uint32_t size = NSSwapLong(arch->size);
        macho_data_ = [NSMutableData dataWithData:[macho_data_ subdataWithRange:NSMakeRange(offset, size)]];
        header_ = static_cast<mach_header_64*>([macho_data_ mutableBytes]);
    }

    if (header_->magic != MH_MAGIC_64) {
        LOG(@"Invalid magic number, not a Mach-O apparently (64 bit atleast)");
        return false;
    }

    return true;
}

std::optional<MachOHooker::MachOInfo> MachOHooker::parse_macho_info() {
    MachOInfo info;
    auto* lc = (load_command*)((uint64_t)header_ + sizeof(*header_));

    for (uint32_t i = 0; i < header_->ncmds; ++i) {
        if (lc->cmd == LC_SEGMENT_64) {
            auto* seg = (segment_command_64*)lc;
            if (strcmp(seg->segname, SEG_LINKEDIT) == 0) {
                info.linkedit_seg = seg;
            } else if (seg->vmsize && info.vm_end < (seg->vmaddr + seg->vmsize)) {
                info.vm_end = seg->vmaddr + seg->vmsize;
            }

            auto* sec = (section_64*)((uint64_t)seg + sizeof(*seg));
            for (uint32_t j = 0; j < seg->nsects; ++j) {
                if (sec[j].offset > info.min_section_offset) {
                    info.min_section_offset = sec[j].offset;
                }
            }

            if (strcmp(seg->segname, HOOK_TEXT_SEGMENT) == 0) {
                text_segment_ = seg;
            }
            if (strcmp(seg->segname, HOOK_DATA_SEGMENT) == 0) {
                data_segment_ = seg;
            }
        } else if (lc->cmd == LC_ENCRYPTION_INFO_64) {
            auto* info_cmd = (encryption_info_command_64*)lc;
            cryptid_ = info_cmd->cryptid;
        }
        lc = (load_command*)((uint64_t)lc + lc->cmdsize);
    }

    if (!info.min_section_offset || !info.vm_end || !info.linkedit_seg) {
        LOG(@"Failed to parse Mach-O structure");
        return std::nullopt;
    }

    return info;
}

bool MachOHooker::add_hook_sections() {
    auto info_opt = parse_macho_info();
    if (!info_opt) {
        return false;
    }
    auto info = *info_opt;

    if (info.min_section_offset < sizeof(mach_header_64) + header_->sizeofcmds) {
        LOG(@"no space in header");
        return false;
    }

    NSRange linkedit_range = NSMakeRange(info.linkedit_seg->fileoff, info.linkedit_seg->filesize);
    NSData* linkedit_data = [macho_data_ subdataWithRange:linkedit_range];
    [macho_data_ replaceBytesInRange:linkedit_range withBytes:nil length:0];

    segment_command_64 text_seg = {
        .cmd = LC_SEGMENT_64,
        .cmdsize = sizeof(segment_command_64) + sizeof(section_64),
        .vmaddr = info.vm_end,
        .vmsize = CODE_PAGE_SIZE,
        .fileoff = (uint32_t)macho_data_.length,
        .filesize = CODE_PAGE_SIZE,
        .maxprot = VM_PROT_READ | VM_PROT_EXECUTE,
        .initprot = VM_PROT_READ | VM_PROT_EXECUTE,
        .nsects = 1
    };
    strncpy(text_seg.segname, HOOK_TEXT_SEGMENT, sizeof(text_seg.segname));

    section_64 text_sec = {
        .addr = text_seg.vmaddr,
        .size = text_seg.vmsize,
        .offset = static_cast<uint32_t>(text_seg.fileoff),
        .flags = S_ATTR_PURE_INSTRUCTIONS | S_ATTR_SOME_INSTRUCTIONS
    };
    strncpy(text_sec.segname, HOOK_TEXT_SEGMENT, sizeof(text_sec.segname));
    strncpy(text_sec.sectname, HOOK_TEXT_SECTION, sizeof(text_sec.sectname));

    segment_command_64 data_seg = {
        .cmd = LC_SEGMENT_64,
        .cmdsize = sizeof(segment_command_64) + sizeof(section_64),
        .vmaddr = text_seg.vmaddr + text_seg.vmsize,
        .vmsize = DATA_PAGE_SIZE,
        .fileoff = text_seg.fileoff + text_seg.filesize,
        .filesize = DATA_PAGE_SIZE,
        .maxprot = VM_PROT_READ | VM_PROT_WRITE,
        .initprot = VM_PROT_READ | VM_PROT_WRITE,
        .nsects = 1
    };
    strncpy(data_seg.segname, HOOK_DATA_SEGMENT, sizeof(data_seg.segname));

    section_64 data_sec = {
        .addr = data_seg.vmaddr,
        .size = data_seg.vmsize,
        .offset = static_cast<uint32_t>(data_seg.fileoff)
    };
    strncpy(data_sec.segname, HOOK_DATA_SEGMENT, sizeof(data_sec.segname));
    strncpy(data_sec.sectname, HOOK_DATA_SECTION, sizeof(data_sec.sectname));

    std::unique_ptr<uint8_t[]> cmds = std::make_unique<uint8_t[]>(header_->sizeofcmds);
    memcpy(cmds.get(), (uint8_t*)header_ + sizeof(*header_), header_->sizeofcmds);
    auto* patch = (uint8_t*)header_ + sizeof(*header_) + ((uint8_t*)info.linkedit_seg - ((uint8_t*)header_ + sizeof(*header_)));

    memcpy(patch, &text_seg, sizeof(text_seg));
    patch += sizeof(text_seg);
    memcpy(patch, &text_sec, sizeof(text_sec));
    patch += sizeof(text_sec);
    memcpy(patch, &data_seg, sizeof(data_seg));
    patch += sizeof(data_seg);
    memcpy(patch, &data_sec, sizeof(data_sec));
    patch += sizeof(data_sec);
    memcpy(patch, cmds.get() + ((uint8_t*)info.linkedit_seg - ((uint8_t*)header_ + sizeof(*header_))), header_->sizeofcmds - ((uint8_t*)info.linkedit_seg - ((uint8_t*)header_ + sizeof(*header_))));

    info.linkedit_seg = (segment_command_64*)patch;
    info.linkedit_seg->fileoff = macho_data_.length + text_seg.filesize + data_seg.filesize;
    info.linkedit_seg->vmaddr = info.vm_end + text_seg.vmsize + data_seg.vmsize;

    header_->ncmds += 2;
    header_->sizeofcmds += text_seg.cmdsize + data_seg.cmdsize;

    if (!update_linkedit_commands(text_seg.filesize + data_seg.filesize)) {
        return false;
    }

    auto code_page = std::make_unique<uint8_t[]>(CODE_PAGE_SIZE);
    std::fill_n(code_page.get(), CODE_PAGE_SIZE, 0xFF);
    [macho_data_ appendBytes:code_page.get() length:CODE_PAGE_SIZE];

    auto data_page = std::make_unique<uint8_t[]>(DATA_PAGE_SIZE);
    std::fill_n(data_page.get(), DATA_PAGE_SIZE, 0);
    [macho_data_ appendBytes:data_page.get() length:DATA_PAGE_SIZE];

    [macho_data_ appendData:linkedit_data];
    return save_patched_binary();
}

bool MachOHooker::update_linkedit_commands(uint64_t offset) {
    auto* lc = (load_command*)((uint64_t)header_ + sizeof(*header_));
    for (uint32_t i = 0; i < header_->ncmds; ++i) {
        switch (lc->cmd) {
            case LC_DYLD_INFO:
            case LC_DYLD_INFO_ONLY: {
                auto* cmd = (dyld_info_command*)lc;
                cmd->rebase_off += offset;
                cmd->bind_off += offset;
                if (cmd->weak_bind_off) cmd->weak_bind_off += offset;
                if (cmd->lazy_bind_off) cmd->lazy_bind_off += offset;
                if (cmd->export_off) cmd->export_off += offset;
                break;
            }
            case LC_SYMTAB: {
                auto* cmd = (symtab_command*)lc;
                if (cmd->symoff) cmd->symoff += offset;
                if (cmd->stroff) cmd->stroff += offset;
                break;
            }
            case LC_DYSYMTAB: {
                auto* cmd = (dysymtab_command*)lc;
                if (cmd->tocoff) cmd->tocoff += offset;
                if (cmd->modtaboff) cmd->modtaboff += offset;
                if (cmd->extrefsymoff) cmd->extrefsymoff += offset;
                if (cmd->indirectsymoff) cmd->indirectsymoff += offset;
                if (cmd->extreloff) cmd->extreloff += offset;
                if (cmd->locreloff) cmd->locreloff += offset;
                break;
            }
            case LC_FUNCTION_STARTS:
            case LC_DATA_IN_CODE:
            case LC_CODE_SIGNATURE:
            case LC_SEGMENT_SPLIT_INFO:
            case LC_DYLD_EXPORTS_TRIE:
            case LC_DYLD_CHAINED_FIXUPS: {
                auto* cmd = (linkedit_data_command*)lc;
                if (cmd->dataoff) cmd->dataoff += offset;
                break;
            }
        }
        lc = (load_command*)((uint64_t)lc + lc->cmdsize);
    }
    return true;
}

bool MachOHooker::save_patched_binary() {
    std::string save_path = [NSHomeDirectory() stringByAppendingPathComponent:
        [NSString stringWithFormat:@"Documents/titanox-hook/%s", macho_name_.c_str()]].UTF8String;
    
    [[NSFileManager defaultManager] createDirectoryAtPath:@([@(save_path.c_str()) stringByDeletingLastPathComponent].UTF8String)
                             withIntermediateDirectories:YES attributes:nil error:nil];
    
    if (![macho_data_ writeToFile:@(save_path.c_str()) atomically:NO]) {
        LOG(@"can't save patched binary to: %s", save_path.c_str());
        return false;
    }
    return true;
}

uint64_t MachOHooker::va_to_rva(uint64_t va) const {
    uint64_t header_vaddr = 0;
    auto* lc = (load_command*)((uint64_t)header_ + sizeof(*header_));

    for (uint32_t i = 0; i < header_->ncmds; ++i) {
        if (lc->cmd == LC_SEGMENT_64) {
            auto* seg = (segment_command_64*)lc;
            if (seg->fileoff == 0 && seg->filesize > 0) {
                if (header_vaddr != 0) {
                    LOG(@"Multiple header mappings detected, we're aborting");
                    return 0;
                }
                header_vaddr = seg->vmaddr;
            }
        }
        lc = (load_command*)((uint64_t)lc + lc->cmdsize);
    }

    return header_vaddr ? va - header_vaddr : va;
}

void* MachOHooker::rva_to_data(uint64_t rva) const {
    uint64_t header_vaddr = 0;
    auto* lc = (load_command*)((uint64_t)header_ + sizeof(*header_));

    for (uint32_t i = 0; i < header_->ncmds; ++i) {
        if (lc->cmd == LC_SEGMENT_64) {
            auto* seg = (segment_command_64*)lc;
            if (seg->fileoff == 0 && seg->filesize > 0) {
                if (header_vaddr != 0) {
                    LOG(@"Multiple header mappings detected, we're aborting");
                    return nullptr;
                }
                header_vaddr = seg->vmaddr;
            }
        }
        lc = (load_command*)((uint64_t)lc + lc->cmdsize);
    }

    rva += header_vaddr;
    lc = (load_command*)((uint64_t)header_ + sizeof(*header_));

    for (uint32_t i = 0; i < header_->ncmds; ++i) {
        if (lc->cmd == LC_SEGMENT_64) {
            auto* seg = (segment_command_64*)lc;
            uint64_t seg_start = seg->vmaddr;
            uint64_t seg_end = seg_start + seg->vmsize;
            if (rva >= seg_start && rva < seg_end) {
                uint64_t offset = rva - seg_start;
                if (offset > seg->filesize) {
                    LOG(@"invalid offset its not in range");
                    return nullptr;
                }
                return (void*)((uint64_t)header_ + seg->fileoff + offset);
            }
        }
        lc = (load_command*)((uint64_t)lc + lc->cmdsize);
    }
    return nullptr;
}

void* MachOHooker::find_module_base() const {
    for (uint32_t i = 0; i < _dyld_image_count(); ++i) {
        const char* image_name = _dyld_get_image_name(i);
        std::string image_path = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@(macho_name_.c_str())].UTF8String;
        if (image_path == image_name) {
            return (void*)_dyld_get_image_header(i);
        }
    }
    LOG(@"header of %s not found", macho_name_.c_str());
    return nullptr;
}

HookBlock* MachOHooker::find_hook_block(void* base, uint64_t vaddr) const {
    auto* header = (mach_header_64*)base;
    auto* lc = (load_command*)((uint64_t)header + sizeof(*header));
    segment_command_64* text_seg = nullptr;
    segment_command_64* data_seg = nullptr;

    for (uint32_t i = 0; i < header->ncmds; ++i) {
        if (lc->cmd == LC_SEGMENT_64) {
            auto* seg = (segment_command_64*)lc;
            if (strcmp(seg->segname, HOOK_TEXT_SEGMENT) == 0) text_seg = seg;
            if (strcmp(seg->segname, HOOK_DATA_SEGMENT) == 0) data_seg = seg;
        }
        lc = (load_command*)((uint64_t)lc + lc->cmdsize);
    }

    if (!text_seg || !data_seg) {
        LOG(@"Hook segments not found");
        return nullptr;
    }

    auto* hook_block = (HookBlock*)((uint64_t)header + va_to_rva(data_seg->vmaddr));
    for (size_t i = 0; i < DATA_PAGE_SIZE / sizeof(HookBlock); ++i) {
        if (hook_block[i].hook_vaddr == vaddr) {
            return &hook_block[i];
        }
    }
    return nullptr;
}

bool MachOHooker::hex_to_bytes(const std::string& hex, std::vector<uint8_t>& buffer) {
    if (hex.size() % 2 != 0) {
        LOG(@"Invalid hex string length");
        return false;
    }

    buffer.resize(hex.size() / 2);
    for (size_t i = 0; i < hex.size(); ++i) {
        char c = hex[i];
        uint8_t value;
        if (c >= '0' && c <= '9') {
            value = c - '0';
        } else if (c >= 'a' && c <= 'f') {
            value = c - 'a' + 10;
        } else if (c >= 'A' && c <= 'F') {
            value = c - 'A' + 10;
        } else {
            LOG(@"Invalid hex character: %c", c);
            return false;
        }
        buffer[i / 2] |= value << ((1 - (i % 2)) * 4);
    }
    return true;
}

uint64_t MachOHooker::calculate_patch_hash(uint64_t vaddr, const std::string& patch) {
    return std::hash<std::string>{}(patch) ^ vaddr;
}

bool MachOHooker::apply_inline_patch(HookBlock* block, uint64_t func_rva, void* func_data, uint64_t target_rva, void* target_data, const std::string& patch_bytes) {
    if (!block || !func_data || !target_data) {
        LOG(@"Invalid patch parameters");
        return false;
    }

    uint64_t code_size = 4; // Minimum instruction size for ARM64 branch
    uint8_t branch_code[] = {0x00, 0x00, 0x00, 0x14}; // B instruction
    memcpy(target_data, branch_code, sizeof(branch_code));

    block->hook_vaddr = func_rva;
    block->code_vaddr = target_rva;
    block->code_size = code_size;
    block->original_vaddr = func_rva;

    if (!patch_bytes.empty()) {
        std::vector<uint8_t> patch_data;
        if (!hex_to_bytes(patch_bytes, patch_data)) {
            LOG(@"Failed to convert patch bytes");
            return false;
        }
        block->patch_size = patch_data.size();
        block->patch_hash = calculate_patch_hash(func_rva, patch_bytes);
        memcpy(func_data, patch_data.data(), patch_data.size());
    }

    return true;
}

std::optional<std::string> MachOHooker::apply_patch(uint64_t vaddr, const std::string& patch_bytes) {
    if (vaddr % 4 != 0) {
        return "Offset not aligned to 4 bytes";
    }

    if (cryptid_ != 0) {
        return "Cannot patch encrypted binary";
    }

    if (!macho_data_ || !header_) {
        return "Failed to load Mach-O data";
    }

    if (!text_segment_ || !data_segment_) {
        if (!add_hook_sections()) {
            return "Failed to add hook sections";
        }
    }

    uint64_t func_rva = va_to_rva(vaddr);
    void* func_data = rva_to_data(func_rva);
    if (!func_data) {
        return "Invalid function offset";
    }

    uint64_t target_rva = va_to_rva(text_segment_->vmaddr);
    void* target_data = rva_to_data(target_rva);
    if (!target_data) {
        return "Invalid target offset";
    }

    auto* hook_block = (HookBlock*)rva_to_data(va_to_rva(data_segment_->vmaddr));
    HookBlock* free_block = nullptr;

    for (size_t i = 0; i < DATA_PAGE_SIZE / sizeof(HookBlock); ++i) {
        if (hook_block[i].hook_vaddr == func_rva) {
            if (!patch_bytes.empty() && hook_block[i].patch_hash != calculate_patch_hash(vaddr, patch_bytes)) {
                return "Patch bytes have changed";
            }
            return "Offset already patched";
        }
        if (hook_block[i].hook_vaddr == 0 && !free_block) {
            free_block = &hook_block[i];
        }
    }

    if (!free_block) {
        return "No free hook blocks available";
    }

    if (!apply_inline_patch(free_block, func_rva, func_data, target_rva, target_data, patch_bytes)) {
        return "Failed to apply inline patch";
    }

    if (!save_patched_binary()) {
        return "Failed to save patched binary";
    }

    return "Patch applied successfully. Replace the file in Documents/titanox-hook with the original in the app bundle and re-sign.";
}

void* MachOHooker::hook_function(uint64_t vaddr, void* replacement) {
    void* base = find_module_base();
    if (!base) {
        return nullptr;
    }
    HookBlock* block = find_hook_block(base, vaddr);
    if (!block) {
        LOG(@"Hook block not found for vaddr: %p", (void*)vaddr);
        return nullptr;
    }
    block->target_replace = replacement;
    return (void*)((uint64_t)base + block->original_vaddr);
}

bool MachOHooker::activate_patch(uint64_t vaddr, const std::string& patch_bytes) {
    void* base = find_module_base();
    if (!base) {
        LOG(@"Can't find module for vaddr: %p", (void*)vaddr);
        return false;
    }
    HookBlock* block = find_hook_block(base, vaddr & ~3);
    if (!block) {
        LOG(@"Hook block not found for vaddr: %p", (void*)vaddr);
        return false;
    }
    if (block->patch_hash != calculate_patch_hash(vaddr, patch_bytes)) {
        LOG(@"Patch hash mismatch for vaddr: %p", (void*)vaddr);
        return false;
    }
    block->target_replace = (void*)((uint64_t)base + block->patched_vaddr);
    return true;
}

bool MachOHooker::deactivate_patch(uint64_t vaddr, const std::string& patch_bytes) {
    void* base = find_module_base();
    if (!base) {
        LOG(@"Cannot find module for vaddr: %p", (void*)vaddr);
        return false;
    }

    HookBlock* block = find_hook_block(base, vaddr & ~3);
    if (!block) {
        LOG(@"Hook block not found for vaddr: %p", (void*)vaddr);
        return false;
    }
    if (block->patch_hash != calculate_patch_hash(vaddr, patch_bytes)) {
        LOG(@"Patch hash mismatch for vaddr: %p", (void*)vaddr);
        return false;
    }
    block->target_replace = nullptr;
    return true;
}