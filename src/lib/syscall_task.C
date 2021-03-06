/* IBM_PROLOG_BEGIN_TAG                                                   */
/* This is an automatically generated prolog.                             */
/*                                                                        */
/* $Source: src/lib/syscall_task.C $                                      */
/*                                                                        */
/* OpenPOWER HostBoot Project                                             */
/*                                                                        */
/* Contributors Listed Below - COPYRIGHT 2010,2015                        */
/* [+] International Business Machines Corp.                              */
/*                                                                        */
/*                                                                        */
/* Licensed under the Apache License, Version 2.0 (the "License");        */
/* you may not use this file except in compliance with the License.       */
/* You may obtain a copy of the License at                                */
/*                                                                        */
/*     http://www.apache.org/licenses/LICENSE-2.0                         */
/*                                                                        */
/* Unless required by applicable law or agreed to in writing, software    */
/* distributed under the License is distributed on an "AS IS" BASIS,      */
/* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or        */
/* implied. See the License for the specific language governing           */
/* permissions and limitations under the License.                         */
/*                                                                        */
/* IBM_PROLOG_END_TAG                                                     */
#include <sys/task.h>
#include <sys/syscall.h>
#include <kernel/task.H>
#include <kernel/taskmgr.H>
#include <kernel/cpu.H>
#include <sys/vfs.h>
#include <sys/msg.h>
#include <errno.h>

using namespace Systemcalls;

void task_yield()
{
    _syscall0(TASK_YIELD);
    return;
}

tid_t task_create(void*(*fn)(void*), void* ptr)
{
    // Verify we have (memory) permissions to load the function pointer so
    // we don't load bad memory from kernel space.
    register uint64_t function = (uint64_t) fn;
    asm volatile("ld %0, 0(%1)" : "=b"(function) : "b" (function));

    return (tid_t)(uint64_t) _syscall2(TASK_START, (void*)fn, ptr);
}

extern "C" void task_end_stub(void*) NO_RETURN;

void task_end()
{
    task_end_stub(NULL);
}

void task_end2(void* retval)
{
    task_end_stub(retval);
}

tid_t task_gettid()
{
    register task_t* task = NULL;
    asm volatile("mr %0, 13" : "=r"(task));
    return task->tid;
}

cpuid_t task_getcpuid()
{
    register task_t* task = NULL;
    asm volatile("mr %0, 13" : "=r"(task));
    return task->cpu->cpu;
}

tid_t task_exec(const char* file, void* ptr)
{
    // The VFS process is responsible for finding the module and entry point
    // address, so we send a message over to that process.

    tid_t child = 0;
    int rc = 0;

    // Create message, send.
    msg_q_t vfsQ = (msg_q_t)_syscall1(MSGQ_RESOLVE_ROOT,
                                      reinterpret_cast<void*>(MSGQ_ROOT_VFS));
    msg_t* msg = msg_allocate();
    msg->type = VFS_MSG_EXEC;
    msg->data[0] = (uint64_t) file;
    if (vfsQ)
    {
        msg_sendrecv(vfsQ, msg);
    }
    else
    {
        // VFS process isn't fully up yet, return EAGAIN.
        rc = -EAGAIN;
    }

    if (0 == rc)
    {
        // Get fn ptr or error from message data 0.
        int64_t value = *reinterpret_cast<int64_t*>(&msg->data[0]);
        if (value < 0)
        {
            child = value;
        }
        else
        {
            child = task_create(reinterpret_cast<void*(*)(void*)>(msg->data[0]),
                                ptr);
        }
    }
    else
    {
        child = rc;
    }

    msg_free(msg);
    return child;
}

void task_affinity_pin()
{
    // Get task structure.
    register task_t* task = NULL;
    asm volatile("mr %0, 13" : "=r"(task));

    // Increment pin count.
    __sync_add_and_fetch(&task->affinity_pinned, 1);
}

void task_affinity_unpin()
{
    // Get task structure.
    register task_t* task = NULL;
    asm volatile("mr %0, 13" : "=r"(task));

    // Decrement pin count.
    __sync_sub_and_fetch(&task->affinity_pinned, 1);
}

void task_affinity_migrate_to_master()
{
    _syscall0(TASK_MIGRATE_TO_MASTER);
}

void task_detach()
{
    // Get task structure.
    register task_t* task = NULL;
    asm volatile("mr %0, 13" : "=r"(task));

    task->detached = true;
        // This does not need any sync instruction because the setting is
        // only used by the kernel and it requires a context-sync operation
        // to enter kernel mode.
}

tid_t task_wait_tid(tid_t tid, int* status, void** retval)
{
    return static_cast<tid_t>(
               reinterpret_cast<uint64_t>(
                   _syscall3(TASK_WAIT,
                        reinterpret_cast<void*>(static_cast<uint64_t>(tid)),
                        status,
                        retval)));
}

tid_t task_wait(int* status, void** retval)
{
    return static_cast<tid_t>(
               reinterpret_cast<uint64_t>(
                   _syscall3(TASK_WAIT,(void*)-1,status,retval)));
}

