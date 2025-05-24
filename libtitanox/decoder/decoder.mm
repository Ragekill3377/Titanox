// reworked by me to support more instructions instead of just one
#include "decoder.hpp"
#include "capstone/include/capstone/capstone.h"
#include <Foundation/Foundation.h>
#include <cstring>
#include <cstdint>
#include <string>
#include <vector>
#include <optional>
#include <iomanip>
#include <sstream>
#include "../MemX/MemX.hpp" // need bool MemX::_read(void* addr, void* buf, size_t len)
#include "../utils/utils.h"

namespace OpcodeDecoder {
    // addr must be baseAddress of target binary + the static target address you got
    // you can pair this with [TitanoxHook getBaseAddressOfLibrary:"TargetApp"];
    // assign that to a var, and add that and the target address, and pass it here to addr arg.
    std::string decode_from_addr(void* addr) {
        if (!addr) {
            THLog(@"ERR: Null addr/invalid ptr");
            return "null addr";
        }
        
        struct CapstoneHandle {
            csh handle;
            CapstoneHandle() : handle(0) {
                cs_err err = cs_open(CS_ARCH_ARM64, CS_MODE_LITTLE_ENDIAN, &handle);
                if (err != CS_ERR_OK) {
                    THLog(@"ERR: cs_open failed with error code %d", err);
                    handle = 0;
                } else {
                    cs_option(handle, CS_OPT_DETAIL, CS_OPT_ON);
                    THLog(@"... capstone arm64 init done (detailed output)");
                }
            }
            ~CapstoneHandle() { 
                if (handle) {
                    cs_close(&handle);
                    THLog(@".. closed Capstone handle");
                }
            }
            operator csh() const { return handle; }
            bool valid() const { return handle != 0; }
        } handle;

        if (!handle.valid()) {
            THLog(@"ERR: invalid csh handle");
            return "cs_open fail";
        }

        //max 16 ARM64 instructions
        constexpr size_t MAX_INSNS = 16;
        constexpr size_t BUF_SIZE = MAX_INSNS * 4; // 4 bytes per AArch64/arm64 instruction
        std::vector<uint8_t> buf(BUF_SIZE);
        
        // addr is void*, but memx expects a diff type
        if (!MemX::_read(reinterpret_cast<uintptr_t>(addr), buf.data(), BUF_SIZE)) {
            THLog(@"ERR: read %zu bytes from address %p failed", BUF_SIZE, addr);
            return "mem read fail";
        }
        THLog(@"... read %zu bytes from address %p", BUF_SIZE, addr);

        cs_insn* insns = nullptr;
        // pretty much all depends on cs_disasm
        const size_t count = cs_disasm(handle, buf.data(), BUF_SIZE, 
                                     reinterpret_cast<uint64_t>(addr), MAX_INSNS, &insns);
        
        // clean-up
        struct InstructionCleanup {
            cs_insn* insns;
            size_t count;
            InstructionCleanup(cs_insn* insns, size_t count) : insns(insns), count(count) {}
            ~InstructionCleanup() { 
                if (insns) {
                    cs_free(insns, count);
                    THLog(@"freed %zu instr from capstone", count);
                }
            }
        } cleanup(insns, count);

        if (count == 0) {
            THLog(@"ERR: disasm failed for address %p", addr);
            return "disasm fail";
        }

        THLog(@"... disassem -> %zu instructions @ address %p", count, addr);
        
        std::ostringstream out;
        // make it look good (idk)
        if (count > 1) {
            out << std::hex << std::setfill('0');
            for (size_t i = 0; i < count; ++i) {
                const cs_insn& insn = insns[i];
                
                THLog(@"csh -> Instruction %zu: addr=0x%llx, mnemonic=%s, opstr=%s",
                      i, insn.address, insn.mnemonic, insn.op_str);
                
                // addr column
                out << "0x" << std::setw(16) << insn.address << "    ";
                
                // target bytes
                for (size_t j = 0; j < insn.size; ++j) {
                    out << std::setw(2) << static_cast<int>(insn.bytes[j]);
                    if (j < insn.size - 1) out << " ";
                }
                out << std::string(12 - insn.size * 3, ' '); // align
                
                // mnemonic and operands
                out << insn.mnemonic << "    " << insn.op_str;
                
                // if there's any aarch64 extra details we add them
                if (insn.detail) {
                    cs_arm64* detail = &insn.detail->arm64;
                    if (detail->op_count > 0) {
                        out << "    // ";
                        std::ostringstream detail_log;
                        for (int j = 0; j < detail->op_count; ++j) {
                            const cs_arm64_op& op = detail->operands[j];
                            switch (op.type) {
                                // seems useless to me but i did it anyways
                                case ARM64_OP_REG:
                                    detail_log << "REG:" << cs_reg_name(handle, op.reg);
                                    break;
                                case ARM64_OP_IMM:
                                    detail_log << "IMM:0x" << std::hex << op.imm;
                                    break;
                                case ARM64_OP_MEM:
                                    detail_log << "MEM:[base=" << cs_reg_name(handle, op.mem.base)
                                               << ",index=" << cs_reg_name(handle, op.mem.index)
                                               << ",disp=0x" << std::hex << op.mem.disp << "]";
                                    break;
                                default:
                                    break;
                            }
                            if (j < detail->op_count - 1) detail_log << ", ";
                        }
                        out << detail_log.str();
                        THLog(@" (This is cs detail output) -> instruction %zu details: %s", i, detail_log.str().c_str());
                    }
                }
                out << "\n";
            }
        } else {
            // if its a single instruction just format it simply
            out << std::string(insns[0].mnemonic) << " " << insns[0].op_str;
            THLog(@"Small instruction disasm %s %s", insns[0].mnemonic, insns[0].op_str);
        }

        return out.str();
    }
}
