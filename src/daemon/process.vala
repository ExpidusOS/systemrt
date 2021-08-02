namespace SystemRT {
    public class Process {
        private DaemonSystemRT _daemon;
        private GLib.Subprocess _proc;
        private Seccomp.filter_ctx _seccomp;
        private Session _session;

        public uint32 pid {
            get {
                return int.parse(this._proc.get_identifier());
            }
        }

        public Process(DaemonSystemRT daemon, Session session, string[] argv) throws GLib.Error {
            this._daemon = daemon;
            this._session = session;

            var launcher = new GLib.SubprocessLauncher(GLib.SubprocessFlags.STDERR_SILENCE | GLib.SubprocessFlags.STDOUT_SILENCE);

            if (this._session.auth != null) launcher.setenv("XAUTHORITY", this._session.auth, true);
            if (this._session.disp != null) launcher.setenv("DISPLAY", this._session.disp.get_name(), true);

            launcher.unsetenv("DBUS_STARTER_ADDRESS");
            launcher.unsetenv("DBUS_STARTER_BUS_TYPE");
            launcher.unsetenv("SUDO_COMMAND");
            launcher.unsetenv("SUDO_GID");
            launcher.unsetenv("SUDO_UID");
            launcher.unsetenv("SUDO_USER");
            launcher.unsetenv("MAIL");

            uint32 uid;
            uint32 gid;
            var user = session.get_owner_user(out uid, out gid);
            if (user == null) throw new Error.INVALID_USER("Failed to get user for session");
            
            launcher.set_cwd(user.homedir);

            launcher.set_child_setup(() => {
                /* Load capabilities */
                try {
                    this.load_caps(uid, gid);
                } catch (GLib.Error e) {
                    stderr.printf("%s: (%s:%d) %s\n", argv[0], e.domain.to_string(), e.code, e.message);
                    GLib.Process.exit(1);
                }

                /* Initialize seccomp */
                this._seccomp = Seccomp.init(Seccomp.ACT_LOG);
                try {
                    this.load_seccomp();
                } catch (GLib.Error e) {
                    stderr.printf("%s: (%s:%d) %s\n", argv[0], e.domain.to_string(), e.code, e.message);
                    GLib.Process.exit(1);
                }
            });
            this._proc = launcher.spawnv(argv);

            /*if (!this._proc.get_if_exited()) {
                GLib.ChildWatch.add((GLib.Pid)this.pid, () => {
                    this.on_exit();
                });
            }*/
        }

        private void on_exit() {
            this.exit();
        }
    
        private extern bool load_caps(uint32 uid, uint32 gid) throws GLib.Error;
        private extern bool load_seccomp() throws GLib.Error;

        public void to_lua(Lua.LuaVM lvm) {
            lvm.new_table();

            lvm.push_string("__ptr");
            lvm.push_lightuserdata(this);
            lvm.raw_set(-3);

            lvm.push_string("pid");
            lvm.push_integer((int)this.pid);
            lvm.raw_set(-3);

            lvm.push_string("get_user");
            lvm.push_cfunction((lvm) => {
                if (lvm.get_top() != 1) {
                    lvm.push_literal("Expected 1 argument");
                    lvm.error();
                    return 0;
                }

                if (lvm.type(1) != Lua.Type.TABLE) {
                    lvm.push_literal("Invalid argument: expected an instance of process");
                    lvm.error();
                    return 0;
                }

                lvm.get_field(1, "__ptr");
                Process self = (Process)lvm.to_userdata(2);

                var user = self._session.get_owner_user(null, null);
                if (user == null) {
                    lvm.push_literal("failed to get user for session");
                    lvm.error();
                    return 0;
                }

                user.to_lua(lvm);
                return 1;
            });

            lvm.push_string("get_fs");
            lvm.push_cfunction((lvm) => {
                if (lvm.get_top() != 1) {
                    lvm.push_literal("Expected 1 argument");
                    lvm.error();
                    return 0;
                }

                if (lvm.type(1) != Lua.Type.TABLE) {
                    lvm.push_literal("Invalid argument: expected an instance of process");
                    lvm.error();
                    return 0;
                }

                lvm.get_field(1, "__ptr");
                Process self = (Process)lvm.to_userdata(2);

                lvm.new_table();

                lvm.push_string("__ptr");
                lvm.push_lightuserdata(self);
                lvm.raw_set(-3);

                lvm.push_string("set_mode");
                lvm.push_cfunction((lvm) => {
                    return 0;
                });
                lvm.raw_set(-3);

                lvm.push_string("bind");
                lvm.push_cfunction((lvm) => {
                    return 0;
                });
                lvm.raw_set(-3);

                lvm.push_string("unbind");
                lvm.push_cfunction((lvm) => {
                    return 0;
                });
                lvm.raw_set(-3);
                return 1;
            });
            lvm.raw_set(-3);
        }

        public signal void exit();
    }

}