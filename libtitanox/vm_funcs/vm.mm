#include "vm.h"
#include "utils/utils.h"
#include "mach/message.h"

kern_return_t TotallyNotVM::protect(mach_vm_address_t address, mach_vm_size_t size, boolean_t set_max, vm_prot_t new_prot) {
    if (size == 0) {
        THLog(@"protect failed: size is zero");
        return KERN_INVALID_ARGUMENT;
    }
    kern_return_t kr;
    mach_port_t self_task = mach_task_self();

    __Request__mach_vm_protect_t request = {};
    struct {
        mach_msg_header_t header;
        NDR_record_t ndr;
        kern_return_t ret_code;
    } reply = {};

    request.Head.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, MACH_MSG_TYPE_MAKE_SEND_ONCE);
    request.Head.msgh_size = sizeof(request);
    request.Head.msgh_remote_port = self_task;
    request.Head.msgh_local_port = mig_get_reply_port();
    if (request.Head.msgh_local_port == MACH_PORT_NULL) {
        THLog(@"protect failed: invalid reply port");
        return KERN_FAILURE;
    }
    request.Head.msgh_id = 4802;

    request.NDR = NDR_record;
    request.address = address;
    request.size = size;
    request.set_maximum = set_max;
    request.new_protection = new_prot;

    kr = mach_msg(&request.Head, MACH_SEND_MSG | MACH_RCV_MSG, request.Head.msgh_size, sizeof(reply),
                  request.Head.msgh_local_port, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
    if (kr != KERN_SUCCESS) {
        THLog(@"protect mach msg failed: %d", kr);
        return kr;
    }

    if (reply.ret_code != KERN_SUCCESS) {
        THLog(@"protect failed with ret_code: %d", reply.ret_code);
    }

    return reply.ret_code;
}

kern_return_t TotallyNotVM::allocate(mach_vm_address_t *address, mach_vm_size_t size, int flags) {
    if (!address) {
        THLog(@"allocate failed: null address pointer");
        return KERN_INVALID_ARGUMENT;
    }
    if (size == 0) {
        THLog(@"allocate failed: size is zero");
        return KERN_INVALID_ARGUMENT;
    }
    kern_return_t kr;
    mach_port_t self_task = mach_task_self();

    struct {
        mach_msg_header_t header;
        NDR_record_t ndr;
        kern_return_t ret_code;
        mach_vm_address_t allocated_address;
    } reply = {};

    __Request__mach_vm_allocate_t request = {};
    request.Head.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, MACH_MSG_TYPE_MAKE_SEND_ONCE);
    request.Head.msgh_size = sizeof(request);
    request.Head.msgh_remote_port = self_task;
    request.Head.msgh_local_port = mig_get_reply_port();
    if (request.Head.msgh_local_port == MACH_PORT_NULL) {
        THLog(@"allocate failed: invalid reply port");
        return KERN_FAILURE;
    }
    request.Head.msgh_id = 4800;

    request.NDR = NDR_record;
    request.address = 0;
    request.size = size;
    request.flags = flags;

    kr = mach_msg(&request.Head, MACH_SEND_MSG | MACH_RCV_MSG, request.Head.msgh_size, sizeof(reply),
                  request.Head.msgh_local_port, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);

    if (kr != KERN_SUCCESS) {
        THLog(@"allocate mach msg failed: %d", kr);
        return kr;
    }

    if (reply.ret_code != KERN_SUCCESS) {
        THLog(@"allocate failed with ret_code: %d", reply.ret_code);
        return reply.ret_code;
    }

    if (reply.allocated_address == 0) {
        THLog(@"allocate failed: allocated address is zero");
        return KERN_FAILURE;
    }

    *address = reply.allocated_address;

    return KERN_SUCCESS;
}

kern_return_t TotallyNotVM::deallocate(mach_vm_address_t address, mach_vm_size_t size) {
    if (size == 0) {
        THLog(@"deallocate failed: size is zero");
        return KERN_INVALID_ARGUMENT;
    }
    kern_return_t kr;
    mach_port_t self_task = mach_task_self();

    __Request__mach_vm_deallocate_t request = {};
    struct {
        mach_msg_header_t header;
        NDR_record_t ndr;
        kern_return_t ret_code;
    } reply = {};

    request.Head.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, MACH_MSG_TYPE_MAKE_SEND_ONCE);
    request.Head.msgh_size = sizeof(request);
    request.Head.msgh_remote_port = self_task;
    request.Head.msgh_local_port = mig_get_reply_port();
    if (request.Head.msgh_local_port == MACH_PORT_NULL) {
        THLog(@"deallocate failed: invalid reply port");
        return KERN_FAILURE;
    }
    request.Head.msgh_id = 4801;

    request.NDR = NDR_record;
    request.address = address;
    request.size = size;

    kr = mach_msg(&request.Head, MACH_SEND_MSG | MACH_RCV_MSG, request.Head.msgh_size, sizeof(reply),
                  request.Head.msgh_local_port, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);

    if (kr != KERN_SUCCESS) {
        THLog(@"deallocate mach msg failed: %d", kr);
        return kr;
    }

    if (reply.ret_code != KERN_SUCCESS) {
        THLog(@"deallocate failed with ret_code: %d", reply.ret_code);
    }

    return reply.ret_code;
}

kern_return_t TotallyNotVM::read(mach_vm_address_t address, void *buffer, mach_vm_size_t size) {
    if (!buffer) {
        THLog(@"read failed: null buffer");
        return KERN_INVALID_ARGUMENT;
    }
    if (size == 0) {
        THLog(@"read failed: size is zero");
        return KERN_INVALID_ARGUMENT;
    }
    kern_return_t kr;
    mach_port_t self_task = mach_task_self();

    __Request__mach_vm_read_t request = {};
    struct {
        mach_msg_header_t header;
        mach_msg_body_t body;
        mach_msg_ool_descriptor_t data;
        mach_msg_type_number_t dataCnt;
        kern_return_t ret_code;
    } reply = {};

    request.Head.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, MACH_MSG_TYPE_MAKE_SEND_ONCE);
    request.Head.msgh_size = sizeof(request);
    request.Head.msgh_remote_port = self_task;
    request.Head.msgh_local_port = mig_get_reply_port();
    if (request.Head.msgh_local_port == MACH_PORT_NULL) {
        THLog(@"read failed: invalid reply port");
        return KERN_FAILURE;
    }
    request.Head.msgh_id = 4804;

    request.NDR = NDR_record;
    request.address = address;
    request.size = size;

    kr = mach_msg(&request.Head, MACH_SEND_MSG | MACH_RCV_MSG, request.Head.msgh_size, sizeof(reply),
                  request.Head.msgh_local_port, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);

    if (kr != KERN_SUCCESS) {
        THLog(@"read mach msg failed: %d", kr);
        return kr;
    }

    if (reply.ret_code != KERN_SUCCESS) {
        THLog(@"read failed with ret_code: %d", reply.ret_code);
        return reply.ret_code;
    }

    if (reply.dataCnt > size) {
        THLog(@"read failed: buffer overflow risk, dataCnt=%u size=%llu", reply.dataCnt, size);
        return KERN_INVALID_ARGUMENT;
    }

    if (!reply.data.address) {
        THLog(@"read failed: reply data address null");
        return KERN_FAILURE;
    }

    memcpy(buffer, reply.data.address, reply.dataCnt);

    return KERN_SUCCESS;
}

kern_return_t TotallyNotVM::write(mach_vm_address_t address, const void *data, mach_vm_size_t size) {
    if (!data) {
        THLog(@"write failed: null data pointer");
        return KERN_INVALID_ARGUMENT;
    }
    if (size == 0) {
        THLog(@"write failed: size is zero");
        return KERN_INVALID_ARGUMENT;
    }
    kern_return_t kr;
    mach_port_t self_task = mach_task_self();

    __Request__mach_vm_write_t request = {};
    struct {
        mach_msg_header_t header;
        NDR_record_t ndr;
        kern_return_t ret_code;
    } reply = {};

    request.Head.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, MACH_MSG_TYPE_MAKE_SEND_ONCE);
    // size includes the ool descriptor so this is correct
    request.Head.msgh_size = sizeof(request);
    request.Head.msgh_remote_port = self_task;
    request.Head.msgh_local_port = mig_get_reply_port();
    if (request.Head.msgh_local_port == MACH_PORT_NULL) {
        THLog(@"write failed: invalid reply port");
        return KERN_FAILURE;
    }
    request.Head.msgh_id = 4806;

    request.msgh_body.msgh_descriptor_count = 1;
    request.data.address = (void *)data;
    request.data.size = (mach_msg_size_t)size;
    request.data.deallocate = FALSE;
    request.data.copy = MACH_MSG_VIRTUAL_COPY;
    request.data.type = MACH_MSG_OOL_DESCRIPTOR;

    request.NDR = NDR_record;
    request.address = address;
    request.dataCnt = (mach_msg_type_number_t)size;

    kr = mach_msg(&request.Head, MACH_SEND_MSG | MACH_RCV_MSG, request.Head.msgh_size, sizeof(reply),
                  request.Head.msgh_local_port, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);

    if (kr != KERN_SUCCESS) {
        THLog(@"write mach msg failed: %d", kr);
        return kr;
    }

    if (reply.ret_code != KERN_SUCCESS) {
        THLog(@"write failed with ret_code: %d", reply.ret_code);
    }

    return reply.ret_code;
}
