/* seccomp.vapi generated by vapigen, do not modify. */

[CCode (cprefix = "seccomp", gir_namespace = "Seccomp", lower_case_cprefix = "seccomp_")]
namespace Seccomp {
	[CCode (cheader_filename = "seccomp.h", cname = "scmp_arg_cmp", has_type_id = false)]
	public struct _arg_cmp {
		public uint arg;
		public void* op;
		public Seccomp.datum_t datum_a;
		public Seccomp.datum_t datum_b;
	}
	[CCode (cheader_filename = "seccomp.h", cname = "scmp_datum_t")]
	[SimpleType]
	public struct datum_t : uint64 {
	}
	[CCode (cheader_filename = "seccomp.h", cname = "scmp_filter_ctx")]
	[SimpleType]
	public struct filter_ctx {
	}
	[CCode (cheader_filename = "seccomp.h", cname = "scmp_version", has_type_id = false)]
	public struct version {
		public uint major;
		public uint minor;
		public uint micro;
	}
	[CCode (cheader_filename = "seccomp.h", cname = "SCMP_ACT_ALLOW")]
	public const int ACT_ALLOW;
	[CCode (cheader_filename = "seccomp.h", cname = "SCMP_ACT_KILL_PROCESS")]
	public const int ACT_KILL_PROCESS;
	[CCode (cheader_filename = "seccomp.h", cname = "SCMP_ACT_KILL_THREAD")]
	public const int ACT_KILL_THREAD;
	[CCode (cheader_filename = "seccomp.h", cname = "SCMP_ACT_LOG")]
	public const int ACT_LOG;
	[CCode (cheader_filename = "seccomp.h", cname = "SCMP_ACT_TRAP")]
	public const int ACT_TRAP;
	[CCode (cheader_filename = "seccomp.h", cname = "SCMP_ARCH_NATIVE")]
	public const int ARCH_NATIVE;
	[CCode (cheader_filename = "seccomp.h", cname = "SCMP_ARCH_X32")]
	public const int ARCH_X32;
	[CCode (cheader_filename = "seccomp.h", cname = "SCMP_VER_MAJOR")]
	public const int VER_MAJOR;
	[CCode (cheader_filename = "seccomp.h", cname = "SCMP_VER_MICRO")]
	public const int VER_MICRO;
	[CCode (cheader_filename = "seccomp.h", cname = "SCMP_VER_MINOR")]
	public const int VER_MINOR;
	[CCode (cheader_filename = "seccomp.h")]
	public static uint api_get ();
	[CCode (cheader_filename = "seccomp.h")]
	public static int api_set (uint level);
	[CCode (cheader_filename = "seccomp.h")]
	public static int arch_add (Seccomp.filter_ctx ctx, uint32 arch_token);
	[CCode (cheader_filename = "seccomp.h")]
	public static int arch_exist (Seccomp.filter_ctx ctx, uint32 arch_token);
	[CCode (cheader_filename = "seccomp.h")]
	public static uint32 arch_native ();
	[CCode (cheader_filename = "seccomp.h")]
	public static int arch_remove (Seccomp.filter_ctx ctx, uint32 arch_token);
	[CCode (cheader_filename = "seccomp.h")]
	public static uint32 arch_resolve_name (string arch_name);
	[CCode (cheader_filename = "seccomp.h")]
	public static int attr_get (Seccomp.filter_ctx ctx, void* attr, uint32 value);
	[CCode (cheader_filename = "seccomp.h")]
	public static int attr_set (Seccomp.filter_ctx ctx, void* attr, uint32 value);
	[CCode (cheader_filename = "seccomp.h")]
	public static int export_bpf (Seccomp.filter_ctx ctx, int fd);
	[CCode (cheader_filename = "seccomp.h")]
	public static int export_pfc (Seccomp.filter_ctx ctx, int fd);
	[CCode (cheader_filename = "seccomp.h", cname = "seccomp_version")]
	public static unowned Seccomp.version? get_version ();
	[CCode (cheader_filename = "seccomp.h")]
	public static Seccomp.filter_ctx init (uint32 def_action);
	[CCode (cheader_filename = "seccomp.h")]
	public static int load (Seccomp.filter_ctx ctx);
	[CCode (cheader_filename = "seccomp.h")]
	public static int merge (Seccomp.filter_ctx ctx_dst, Seccomp.filter_ctx ctx_src);
	[CCode (cheader_filename = "seccomp.h")]
	public static void release (Seccomp.filter_ctx ctx);
	[CCode (cheader_filename = "seccomp.h")]
	public static int reset (Seccomp.filter_ctx ctx, uint32 def_action);
	[CCode (cheader_filename = "seccomp.h")]
	public static int rule_add_array (Seccomp.filter_ctx ctx, uint32 action, int syscall, uint arg_cnt, void* arg_array);
	[CCode (cheader_filename = "seccomp.h")]
	public static int rule_add_exact_array (Seccomp.filter_ctx ctx, uint32 action, int syscall, uint arg_cnt, void* arg_array);
	[CCode (cheader_filename = "seccomp.h")]
	public static int syscall_priority (Seccomp.filter_ctx ctx, int syscall, uint8 priority);
	[CCode (cheader_filename = "seccomp.h")]
	public static int syscall_resolve_name (string name);
	[CCode (cheader_filename = "seccomp.h")]
	public static int syscall_resolve_name_arch (uint32 arch_token, string name);
	[CCode (cheader_filename = "seccomp.h")]
	public static int syscall_resolve_name_rewrite (uint32 arch_token, string name);
	[CCode (cheader_filename = "seccomp.h")]
	public static string syscall_resolve_num_arch (uint32 arch_token, int num);
}
