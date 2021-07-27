#pragma once

#include <linux/audit.h>
#include <linux/bpf.h>
#include <linux/filter.h>
#include <linux/prctl.h>
#include <linux/seccomp.h>

typedef struct sock_filter sock_filter;
typedef struct sock_fprog sock_fprog;

#ifndef SECCOMP_MODE_FILTER
#define SECCOMP_MODE_FILTER	2 /* uses user-supplied filter. */
#define SECCOMP_RET_KILL 0x00000000U /* kill the task immediately */
#define SECCOMP_RET_TRAP 0x00030000U /* disallow and force a SIGSYS */
#define SECCOMP_RET_ALLOW 0x7fff0000U /* allow */
struct seccomp_data {
    int nr;
    __u32 arch;
    __u64 instruction_pointer;
    __u64 args[6];
};
#endif
#ifndef SYS_SECCOMP
#define SYS_SECCOMP 1
#endif

#define syscall_nr (offsetof(struct seccomp_data, nr))
#define arch_nr (offsetof(struct seccomp_data, arch))

#if defined(__i386__)
#define REG_SYSCALL REG_EAX
#define ARCH_NR AUDIT_ARCH_I386
#elif defined(__x86_64__)
#define REG_SYSCALL REG_RAX
#define ARCH_NR AUDIT_ARCH_X86_64
#else
#warning "Platform does not support seccomp filter yet"
#define REG_SYSCALL	0
#define ARCH_NR	0
#endif