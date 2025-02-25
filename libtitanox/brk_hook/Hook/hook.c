#include "hook.h"
#include "mach_excServer.h"
#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <mach-o/dyld_images.h>
#include <mach-o/nlist.h>
#include <mach/mach.h>
#include <pthread.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/sysctl.h>

kern_return_t catch_mach_exception_raise(
    mach_port_t exception_port,
    mach_port_t thread,
    mach_port_t task,
    exception_type_t exception,
    mach_exception_data_t code,
    mach_msg_type_number_t codeCnt) {
    abort(); // will call only if not hooked
}

kern_return_t catch_mach_exception_raise_state_identity(
    mach_port_t exception_port,
    mach_port_t thread,
    mach_port_t task,
    exception_type_t exception,
    mach_exception_data_t code,
    mach_msg_type_number_t codeCnt,
    int *flavor,
    thread_state_t old_state,
    mach_msg_type_number_t old_stateCnt,
    thread_state_t new_state,
    mach_msg_type_number_t *new_stateCnt) {
    abort(); // will call only if not hooked
}

mach_port_t server;

struct hook {
    uintptr_t old;
    uintptr_t new;
};
static struct hook hooks[16];
static int active_hooks;

kern_return_t catch_mach_exception_raise_state(
    mach_port_t exception_port,
    exception_type_t exception,
    const mach_exception_data_t code,
    mach_msg_type_number_t codeCnt,
    int *flavor,
    const thread_state_t old_state,
    mach_msg_type_number_t old_stateCnt,
    thread_state_t new_state,
    mach_msg_type_number_t *new_stateCnt) {
    arm_thread_state64_t *old = (arm_thread_state64_t *)old_state;
    arm_thread_state64_t *new = (arm_thread_state64_t *)new_state;

    for (int i = 0; i < active_hooks; ++i) {
        if (hooks[i].old == arm_thread_state64_get_pc(*old)) {
            *new = *old;
            *new_stateCnt = old_stateCnt;
			
			// set our method to call after breakpoint trigger
            arm_thread_state64_set_pc_fptr(*new, hooks[i].new);
            return KERN_SUCCESS;
        }
    }

    return KERN_FAILURE;
}

void *exception_handler(void *unused) {
    mach_msg_server(mach_exc_server, sizeof(union __RequestUnion__catch_mach_exc_subsystem), server, MACH_MSG_OPTION_NONE);
    abort();
}

bool hook(void *old[], void *new[], int count) {
	if (count > 6) return false;
	
	static bool initialized;
	static int breakpoints;
    if (!initialized) {
		// get active breakpoints
		size_t size = sizeof(breakpoints);
		sysctlbyname("hw.optional.breakpoint", &breakpoints, &size, NULL, 0); // usually 6
		
		// enable exception handler
		mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &server) != KERN_SUCCESS;
		mach_port_insert_right(mach_task_self(), server, server, MACH_MSG_TYPE_MAKE_SEND) != KERN_SUCCESS;
		task_set_exception_ports(mach_task_self(), EXC_MASK_BREAKPOINT, server, EXCEPTION_STATE | MACH_EXCEPTION_CODES, ARM_THREAD_STATE64) != KERN_SUCCESS;
		
		pthread_t thread;
		pthread_create(&thread, NULL, exception_handler, NULL);

		initialized = true;
	}	
	
	if (count > breakpoints) return false;
	
	// add breakpoints
    arm_debug_state64_t state = {};
	for (int i = 0; i < count; i++) {
		// breakpoint address
		state.__bvr[i] = (uintptr_t)old[i];
		
		//enable breakpoint
		state.__bcr[i] = 0x1e5;
		
		hooks[i] = (struct hook){(uintptr_t)old[i], (uintptr_t)new[i]};
		active_hooks = count;
	}
	
	// setup debug mode with our breakpoints for task
    if (task_set_state(mach_task_self(), ARM_DEBUG_STATE64, (thread_state_t)&state, ARM_DEBUG_STATE64_COUNT) != KERN_SUCCESS) return false;
	
    thread_act_array_t threads;
    mach_msg_type_number_t thread_count = ARM_DEBUG_STATE64_COUNT;
    task_threads(mach_task_self(), &threads, &thread_count);
	bool success = true;
	
	// setup debug mode with our breakpoints for all threads
    for (int i = 0; i < thread_count; ++i) if (thread_set_state(threads[i], ARM_DEBUG_STATE64, (thread_state_t)&state, ARM_DEBUG_STATE64_COUNT) != KERN_SUCCESS) success = false;
	
	// clear
    for (int i = 0; i < thread_count; ++i) mach_port_deallocate(mach_task_self(), threads[i]);
    vm_deallocate(mach_task_self(), (vm_address_t)threads, thread_count * sizeof(*threads));
	
    return success;
}
