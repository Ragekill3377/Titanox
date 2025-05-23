#include "decoder.hpp"
#include "capstone/include/capstone/capstone.h"
#include <cstring>
#include <cstdint>
#include "../MemX/MemX.hpp"  // need bool MemX::_read(void* addr, void* buf, size_t len)

namespace OpcodeDecoder {
    std::string decode_from_addr(void* addr) {
        if (!addr) return "null addr";
        csh handle;
        cs_insn* insn;
        size_t count;
        if (cs_open(CS_ARCH_ARM64, CS_MODE_LITTLE_ENDIAN, &handle) != CS_ERR_OK)
            return "cs_open fail";
        uint8_t buf[4];
        if (!MemX::_read((uintptr_t)addr, buf, 4)) {
            cs_close(&handle);
            return "mem read fail";
        }
        count = cs_disasm(handle, buf, 4, reinterpret_cast<uint64_t>(addr), 1, &insn);
        std::string out;

        if (count > 0) {
            out = std::string(insn[0].mnemonic) + " " + insn[0].op_str;
            cs_free(insn, count);
        } else {
            out = "disasm fail";
        }
        cs_close(&handle);
        return out;
    }
}
