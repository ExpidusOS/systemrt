namespace SystemRT {
    public class Process {
        private DaemonSystemRT _daemon;
        private GLib.Subprocess _proc;
        private Seccomp.filter_ctx _seccomp;

        public int pid {
            get {
                return int.parse(this._proc.get_identifier());
            }
        }

        public Process(DaemonSystemRT daemon, string[] argv) throws GLib.Error {
            this._daemon = daemon;

            var launcher = new GLib.SubprocessLauncher(GLib.SubprocessFlags.NONE /*STDERR_SILENCE | GLib.SubprocessFlags.STDOUT_SILENCE*/);
            launcher.set_child_setup(() => {
                this._seccomp = Seccomp.init(Seccomp.ACT_LOG);

                try {
                    this.load_seccomp();
                } catch (GLib.Error e) {
                    stderr.printf("%s: (%s:%d) %s\n", argv[0], e.domain.to_string(), e.code, e.message);
                    GLib.Process.exit(1);
                }
            });
            this._proc = launcher.spawnv(argv);

            GLib.ChildWatch.add(this.pid, () => {
                this.on_exit();
            });
        }

        private void on_exit() {
        }
    
        private extern bool load_seccomp() throws GLib.Error;

        public void to_lua(Lua.LuaVM lvm) {
            lvm.new_table();

            lvm.push_string("__ptr");
            lvm.push_lightuserdata(this);
            lvm.raw_set(-3);
        }
    }

}