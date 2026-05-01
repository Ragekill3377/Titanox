#pragma once

#include <mach/mach.h>
//#include <mach/mach_vm.h>
#include <mach/message.h>
#include <Foundation/Foundation.h>

class TotallyNotVM {
public:
    static kern_return_t protect(mach_vm_address_t address, mach_vm_size_t size, boolean_t set_max, vm_prot_t new_prot);
    static kern_return_t allocate(mach_vm_address_t *address, mach_vm_size_t size, int flags);
    static kern_return_t deallocate(mach_vm_address_t address, mach_vm_size_t size);
    static kern_return_t read(mach_vm_address_t address, void *buffer, mach_vm_size_t size);
    static kern_return_t write(mach_vm_address_t address, const void *data, mach_vm_size_t size);
};

typedef struct {
    mach_msg_header_t Head;
    NDR_record_t NDR;
    mach_vm_address_t address;
    mach_vm_size_t size;
    boolean_t set_maximum;
    vm_prot_t new_protection;
} __Request__mach_vm_protect_t;

typedef struct {
    mach_msg_header_t Head;
    NDR_record_t NDR;
    mach_vm_address_t address;
    mach_vm_size_t size;
    int flags;
} __Request__mach_vm_allocate_t;

typedef struct {
    mach_msg_header_t Head;
    NDR_record_t NDR;
    mach_vm_address_t address;
    mach_vm_size_t size;
} __Request__mach_vm_deallocate_t;

typedef struct {
    mach_msg_header_t Head;
    NDR_record_t NDR;
    mach_vm_address_t address;
    mach_vm_size_t size;
} __Request__mach_vm_read_t;

typedef struct {
    mach_msg_header_t Head;
    mach_msg_body_t msgh_body;
    mach_msg_ool_descriptor_t data;
    NDR_record_t NDR;
    mach_vm_address_t address;
    mach_msg_type_number_t dataCnt;
} __Request__mach_vm_write_t;

/*typedef struct {
    mach_msg_header_t Head;
    mach_msg_body_t msgh_body;
    mach_msg_port_descriptor_t src_task;
    NDR_record_t NDR;
    mach_vm_address_t target_address;
    mach_vm_size_t size;
    mach_vm_address_t src_address;
    boolean_t copy;
    vm_inherit_t inheritance;
} __Request__mach_vm_remap_t;
*/

