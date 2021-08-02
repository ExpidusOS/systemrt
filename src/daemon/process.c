#include <systemrt-daemon.h>
#include <seccomp.h>
#include <sys/capability.h>

/* Keep me in sync with the process Vala file */
struct _SystemRTProcessPrivate {
	SystemRTDaemonSystemRT* _daemon;
	GSubprocess* _proc;
	scmp_filter_ctx _seccomp;
};

G_DEFINE_QUARK(SystemRTProcess, systemrt_process);

#define add_rule(syscall_name, ...) rc = seccomp_rule_add_exact(self->priv->_seccomp, SCMP_ACT_ERRNO(EPERM), SCMP_SYS(syscall_name), __VA_ARGS__); \
    if (rc < 0) { \
        g_set_error(error, systemrt_process_quark(), -rc, "Failed to add rule \"" # syscall_name "\": %s", strerror(-rc)); \
        return FALSE; \
    }

gboolean system_rt_process_load_caps(SystemRTProcess* self, guint32 uid, guint32 gid, GError** error) {
    cap_t caps = cap_get_proc();
    if (caps == NULL) {
        g_set_error(error, systemrt_process_quark(), 0, "Failed to get capabilities");
        return FALSE;
    }

    const gid_t groups[] = { gid };
    if (cap_setgroups(gid, 1, groups) != 0) {
        g_set_error(error, systemrt_process_quark(), 1, "Failed to setgid: %s", strerror(errno));
        return FALSE;
    }

    if (cap_setuid(uid) != 0) {
        g_set_error(error, systemrt_process_quark(), 1, "Failed to setuid: %s", strerror(errno));
        return FALSE;
    }

    if (cap_set_mode(CAP_MODE_NOPRIV) != 0) {
        g_set_error(error, systemrt_process_quark(), 1, "Failed to drop priviledged mode: %s", strerror(errno));
        return FALSE;
    }
    return TRUE;
}

gboolean system_rt_process_load_seccomp(SystemRTProcess* self, GError** error) {
    int rc;

    /* System */
    add_rule(reboot, 0)
    add_rule(syslog, 0)
    add_rule(pivot_root, 0)
    add_rule(chroot, 0)
    add_rule(adjtimex, 0)
    add_rule(setrlimit, 0)
    add_rule(swapon, 0)
    add_rule(swapoff, 0)
    add_rule(sethostname, 0)
    add_rule(setdomainname, 0)
    add_rule(iopl, 0)
    add_rule(ioperm, 0)

    /* Process */
    add_rule(setuid, 0)
    add_rule(setgid, 0)
    add_rule(setpgid, 0)
    add_rule(setreuid, 0)
    add_rule(setregid, 0)
    add_rule(setresuid, 0)
    add_rule(setfsuid, 0)
    add_rule(personality, 0)
    add_rule(setpriority, 0)
    add_rule(modify_ldt, 0)

    /* Filesystem */
    add_rule(mknod, 0)
    add_rule(mount, 0)
    add_rule(umount2, 0)
    add_rule(quotactl, 0)

    /* Networking */
    add_rule(socket, 0)
    add_rule(connect, 0)
    add_rule(accept, 0)
    add_rule(sendmsg, 0)
    add_rule(recvmsg, 0)
    add_rule(shutdown, 0)
    add_rule(bind, 0)
    add_rule(listen, 0)
    add_rule(getsockname, 0)
    add_rule(getpeername, 0)
    add_rule(socketpair, 0)
    add_rule(setsockopt, 0)
    add_rule(getsockopt, 0)

    rc = seccomp_load(self->priv->_seccomp);
    if (rc < 0) {
        g_set_error(error, systemrt_process_quark(), 0, "Failed to load into kernel");
        return FALSE;
    }
    return TRUE;
}