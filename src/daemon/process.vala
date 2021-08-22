namespace SystemRT {
    public class Process {
        private DaemonSystemRT _daemon;
        private GLib.Subprocess _proc;
        private Seccomp.filter_ctx _seccomp;
        private Session _session;
        private GLib.List<PermissionRule?> _rules;
        private User _user;
        private string[] _argv;
        private uint32 _pid = 0;

        public uint32 pid {
            get {
                if (this._proc == null) return this._pid;
                if (this._proc.get_identifier() == null) return this._pid;
                return int.parse(this._proc.get_identifier());
            }
        }

        public Process(DaemonSystemRT daemon, Session session, string[] argv) throws GLib.Error {
            this._daemon = daemon;
            this._session = session;
            this._rules = new GLib.List<PermissionRule?>();
            this._argv = argv;

            var launcher = new GLib.SubprocessLauncher(GLib.SubprocessFlags.NONE /*STDERR_SILENCE | GLib.SubprocessFlags.STDOUT_SILENCE*/);

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
            this._user = this._session.get_owner_user(out uid, out gid);
            if (this._user == null) throw new Error.INVALID_USER("Failed to get user for session");
            
            launcher.set_cwd(this._user.homedir);

            launcher.set_child_setup(() => {
                this._pid = Posix.getpid();

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

                if (AppArmor.change_profile(argv[0] + "//" + this._user.name) != 0) {
                    stderr.printf("%s: failed to change profile: %s\n", argv[0], Posix.strerror(Posix.errno));
                    GLib.Process.exit(1);
                }
            });

            // TODO: read database
            this._daemon.iterate_permissions((perm) => {
                perm.def(this);
            });
            this.update_apparmor();

            this._proc = launcher.spawnv(argv);

            GLib.ChildWatch.add((GLib.Pid)this.pid, () => {
                this.on_exit();
            });
        }

        private void on_exit() {
            this.exit();
        }
    
        private extern bool load_caps(uint32 uid, uint32 gid) throws GLib.Error;
        private extern bool load_seccomp() throws GLib.Error;

        private void update_apparmor() throws GLib.FileError, GLib.SpawnError, Error {
            var apparmor_profile = """profile %s//%s {
  include <abstractions/base>
  include <abstractions/dbus>
  include <abstractions/fonts>
  include <abstractions/gnome>
  include <abstractions/mesa>
  include <abstractions/nvidia>
  include <abstractions/vulkan>
  include <abstractions/wayland>
  include <abstractions/X>

""".printf(this._argv[0], this._user.name);

            foreach (var rule in this._rules) {
                switch (rule.category) {
                    case PermissionCategory.FS:
                        switch (rule.action) {
                            case "mode":
                                var path = rule.values[0] as string;
                                var enforce = rule.values[1] as string;
                                var mode = "";
                                for (var i = 2; i < rule.values.length; i++) {
                                    var v = rule.values[i] as string;
                                    if (v == null) continue;
                                    switch (v) {
                                        case "read":
                                            mode += "r";
                                            break;
                                        case "write":
                                            mode += "w";
                                            break;
                                        case "exec":
                                            if (enforce == "allow") mode += "i";
                                            mode += "x";
                                            break;
                                        case "link":
                                            mode += "l";
                                            break;
                                    }
                                }

                                apparmor_profile += "  " + (enforce != "allow" ?  enforce + " " : "") + path + (mode.length > 0 ? " " + mode : "") + ",\n";
                                break;
                        }
                        break;
                    case PermissionCategory.CAPS:
                        switch (rule.action) {
                            case "set":
                                var cap_name = rule.values[0] as string;
                                var action = rule.values[1] as string;
                                apparmor_profile += "  " + (action != "allow" ? action + " " : "") + "capability " + cap_name + ",\n";
                                break;
                        }
                        break;
                    case PermissionCategory.NET:
                        switch (rule.action) {
                            case "set_access":
                                var mode = rule.values[0] as string;
                                var type = rule.values[1] as string;
                                var proto = rule.values[2] as string;
                                var perms = "";

                                if (proto.length > 0) proto = " " + proto;

                                for (var i = 3; i < rule.values.length; i++) {
                                    var p = rule.values[i] as string;

                                    if (i == 3) perms += "(";

                                    perms += p;

                                    if ((i + 1) != rule.values.length) perms += ", ";
                                }

                                if (perms.length > 0) perms += ") ";
                                
                                apparmor_profile += "  " + (mode != "allow" ? mode + " " : "") + "network " + perms + type + proto + ",\n";
                                break;
                            case "set_connect":
                                var mode = rule.values[0] as string;
                                var proto = rule.values[1] as string;
                                var src = rule.values[2] as string;
                                var dst = rule.values.length == 4 ? rule.values[3] as string : null;

                                apparmor_profile += "  " + (mode != "allow" ? mode + " " : "") + "network " + proto + " src " + src + (dst == null ? "" : " dst " + dst) + ",\n";
                                break;
                        }
                        break;
                }
            }

            apparmor_profile += """  include if exists "/etc/expidus/sys/profiles.d/%s"
  deny /etc/expidus rw,
  deny /etc/expidus/** rw,

  audit network,
  audit @{HOME}/.ssh rwmix,
}""".printf(this._argv[0].substring(1).replace("/", "."));

            GLib.DirUtils.create_with_parents(SYSCONFDIR + "/apparmor.d/systemrt/%s".printf(this._argv[0].substring(1).replace("/", ".")), 493);

            var path = SYSCONFDIR + "/apparmor.d/systemrt/%s/%lu".printf(this._argv[0].substring(1).replace("/", "."), this._user.uid);
            GLib.FileUtils.set_contents(path, apparmor_profile);

            apparmor_profile = """abi <abi/3.0>,
include <tunables/global>

%s {
  include <abstractions/base>
  include <abstractions/dbus>
  include <abstractions/fonts>
  include <abstractions/gnome>
  include <abstractions/mesa>
  include <abstractions/nvidia>
  include <abstractions/vulkan>
  include <abstractions/wayland>
  include <abstractions/X>

  include if exists "/etc/expidus/sys/profiles.d/%s"
  deny /etc/expidus rw,
  deny /etc/expidus/** rw,

  audit network,
  audit @{HOME}/.ssh rwmix,
}

include <systemrt/%s/>
""".printf(this._argv[0], this._argv[0].substring(1).replace("/", "."), this._argv[0].substring(1).replace("/", "."));

            path = SYSCONFDIR + "/apparmor.d/systemrt-%s".printf(this._argv[0].substring(1).replace("/", "."));
            GLib.FileUtils.set_contents(path, apparmor_profile);

            string err;
            int status;
            if (!GLib.Process.spawn_sync(null, {"aa-enforce", this._argv[0]}, GLib.Environ.get(), GLib.SpawnFlags.SEARCH_PATH | GLib.SpawnFlags.STDOUT_TO_DEV_NULL | GLib.SpawnFlags.STDERR_TO_DEV_NULL, null, null, out err, out status)) {
                throw new Error.APPARMOR_ERROR("Failed to reload profile: (%d) %s".printf(status, err));
            }
        }

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
            lvm.raw_set(-3);

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
                    if (lvm.get_top() < 3) {
                        lvm.push_literal("Expecting at least 3 arguments");
                        lvm.error();
                        return 0;
                    }

                    if (lvm.type(1) != Lua.Type.TABLE) {
                        lvm.push_literal("Invalid argument: expected an instance of process filesystem");
                        lvm.error();
                        return 0;
                    }

                    if (lvm.type(2) != Lua.Type.STRING) {
                        lvm.push_literal("Invalid argument: expected a string");
                        lvm.error();
                        return 0;
                    }

                    lvm.get_field(1, "__ptr");
                    Process s = (Process)lvm.to_userdata(lvm.get_top());

                    GLib.Value[] values = {};
                    values += lvm.to_string(2);

                    for (var i = 3; i < lvm.get_top(); i++) {
                        if (lvm.is_string(i)) {
                            var mode = lvm.to_string(i);
                            switch (mode) {
                                case "read":
                                case "write":
                                case "exec":
                                case "link":
                                    values += mode;
                                    break;
                                default:
                                    if (i == 3) {
                                        switch (mode) {
                                            case "deny":
                                            case "allow":
                                            case "audit":
                                                values += mode;
                                                break;
                                            default:
                                                lvm.pop(1);
                                                lvm.push_literal("Invalid enforce type");
                                                lvm.error();
                                                return 0;
                                        }
                                    } else {
                                        lvm.pop(1);
                                        lvm.push_literal("Invalid mode type");
                                        lvm.error();
                                        return 0;
                                    }
                                    break;
                            }
                        } else {
                            lvm.pop(1);
                            lvm.push_literal("Invalid type: excepted string");
                            lvm.error();
                            return 0;
                        }
                    }

                    PermissionRule rule = {
                        PermissionCategory.FS,
                        "mode",
                        values
                    };
                    s._rules.append(rule);
                    return 0;
                });
                lvm.raw_set(-3);
                return 1;
            });
            lvm.raw_set(-3);

            lvm.push_string("get_caps");
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

                lvm.push_string("set");
                lvm.push_cfunction((lvm) => {
                    if (lvm.get_top() != 3) {
                        lvm.push_literal("Expected 3 arguments");
                        lvm.error();
                        return 0;
                    }

                     if (lvm.type(1) != Lua.Type.TABLE) {
                        lvm.push_literal("Invalid argument: expected an instance of process capabilities");
                        lvm.error();
                        return 0;
                    }

                    if (lvm.type(2) != Lua.Type.STRING) {
                        lvm.push_literal("Invalid argument: expected a string");
                        lvm.error();
                        return 0;
                    }

                    if (lvm.type(3) != Lua.Type.STRING) {
                        lvm.push_literal("Invalid argument: expected a string");
                        lvm.error();
                        return 0;
                    }

                    lvm.get_field(1, "__ptr");
                    Process s = (Process)lvm.to_userdata(4);

                    var cap_name = lvm.to_string(2);
                    var action = lvm.to_string(3);

                    switch (action) {
                        case "deny":
                        case "kill":
                        case "allow":
                            break;
                        default:
                            lvm.push_literal("Invalid action");
                            lvm.error();
                            return 0;
                    }

                    GLib.Value[] values = {};
                    values += cap_name;
                    values += action;

                    PermissionRule rule = {
                        PermissionCategory.CAPS,
                        "set",
                        values
                    };
                    s._rules.append(rule);
                    return 0;
                });
                lvm.raw_set(-3);
                return 1;
            });
            lvm.raw_set(-3);

            lvm.push_string("get_net");
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

                lvm.push_string("set_access");
                lvm.push_cfunction((lvm) => {
                    if (lvm.get_top() < 3) {
                        lvm.push_literal("Expecting at least 3 arguments");
                        lvm.error();
                        return 0;
                    }

                    if (lvm.type(1) != Lua.Type.TABLE) {
                        lvm.push_literal("Invalid argument: expected an instance of process networking");
                        lvm.error();
                        return 0;
                    }

                    if (lvm.type(2) != Lua.Type.STRING) {
                        lvm.push_literal("Invalid argument: expected a string");
                        lvm.error();
                        return 0;
                    }

                    if (lvm.type(3) != Lua.Type.STRING) {
                        lvm.push_literal("Invalid argument: expected a string");
                        lvm.error();
                        return 0;
                    }

                    if (lvm.type(4) != Lua.Type.STRING) {
                        lvm.push_literal("Invalid argument: expected a string");
                        lvm.error();
                        return 0;
                    }

                    lvm.get_field(1, "__ptr");
                    Process s = (Process)lvm.to_userdata(lvm.get_top());

                    var mode = lvm.to_string(2);
                    var type = lvm.to_string(3);
                    var proto = lvm.to_string(4);

                    switch (mode) {
                        case "allow":
                        case "deny":
                            break;
                        default:
                            lvm.push_literal("Invalid mode");
                            lvm.error();
                            return 0;
                    }

                    GLib.Value[] values = {};
                    values += mode;
                    values += type;
                    values += proto;
                    for (var i = 5; i < lvm.get_top(); i++) {
                        var str = lvm.to_string(i);
                        values += str;
                    }

                    PermissionRule rule = {
                        PermissionCategory.NET,
                        "set_access",
                        values
                    };
                    s._rules.append(rule);
                    return 0;
                });
                lvm.raw_set(-3);

                lvm.push_string("set_connect");
                lvm.push_cfunction((lvm) => {
                    if (lvm.get_top() > 5 || lvm.get_top() < 4) {
                        lvm.push_literal("Expecting at least 3 arguments");
                        lvm.error();
                        return 0;
                    }

                    if (lvm.type(1) != Lua.Type.TABLE) {
                        lvm.push_literal("Invalid argument: expected an instance of process networking");
                        lvm.error();
                        return 0;
                    }

                    if (lvm.type(2) != Lua.Type.STRING) {
                        lvm.push_literal("Invalid argument: expected a string");
                        lvm.error();
                        return 0;
                    }

                    if (lvm.type(3) != Lua.Type.STRING) {
                        lvm.push_literal("Invalid argument: expected a string");
                        lvm.error();
                        return 0;
                    }

                    if (lvm.type(4) != Lua.Type.STRING) {
                        lvm.push_literal("Invalid argument: expected a string");
                        lvm.error();
                        return 0;
                    }

                    lvm.get_field(1, "__ptr");
                    Process s = (Process)lvm.to_userdata(lvm.get_top());

                    GLib.Value[] values = {};

                    values += lvm.to_string(2);
                    values += lvm.to_string(3);
                    values += lvm.to_string(4);

                    if (lvm.get_top() == 5) {
                        if (lvm.type(5) != Lua.Type.STRING) {
                            lvm.push_literal("Invalid argument: expected a string");
                            lvm.error();
                            return 0;
                        }

                        values += lvm.to_string(5);
                    }

                    PermissionRule rule = {
                        PermissionCategory.NET,
                        "set_connect",
                        values
                    };
                    s._rules.append(rule);
                    return 0;
                });
                lvm.raw_set(-3);
                return 1;
            });
            lvm.raw_set(-3);

            lvm.push_string("inject_rule");
            lvm.push_cfunction((lvm) => {
                if (lvm.get_top() < 3) {
                    lvm.push_literal("Expected at least 3 arguments");
                    lvm.error();
                    return 0;
                }

                if (lvm.type(1) != Lua.Type.TABLE) {
                    lvm.push_literal("Invalid argument: expected an instance of process");
                    lvm.error();
                    return 0;
                }
                
                if (lvm.type(2) != Lua.Type.STRING) {
                    lvm.push_literal("Invalid argument: expected a string");
                    lvm.error();
                    return 0;
                }

                if (lvm.type(3) != Lua.Type.STRING) {
                    lvm.push_literal("Invalid argument: expected a string");
                    lvm.error();
                    return 0;
                }

                lvm.get_field(1, "__ptr");
                Process self = (Process)lvm.to_userdata(lvm.get_top());

                var action = lvm.to_string(3);

                PermissionCategory cat;
                switch (lvm.to_string(2)) {
                    case "fs":
                        cat = PermissionCategory.FS;

                        switch (action) {
                            case "mode":
                                break;
                            default:
                                lvm.push_literal("Invalid action for \"fs\" category");
                                lvm.error();
                                return 0;
                        }
                        break;
                    case "caps":
                        cat = PermissionCategory.CAPS;

                        switch (action) {
                            case "mode":
                                break;
                            default:
                                lvm.push_literal("Invalid action for \"caps\" category");
                                lvm.error();
                                return 0;
                        }
                        break;
                    case "net":
                        cat = PermissionCategory.NET;

                        switch (action) {
                            case "set_access":
                                break;
                            case "set_connect":
                                break;
                            default:
                                lvm.push_literal("Invalid action for \"net\" category");
                                lvm.error();
                                return 0;
                        }
                        break;
                    default:
                        lvm.push_literal("Invalid permission category");
                        lvm.error();
                        return 0;
                }

                GLib.Value[] values = {};

                for (var i = 4; i < lvm.get_top(); i++) {
                    switch (lvm.type(i)) {
                        case Lua.Type.STRING:
                            values += lvm.to_string(i);
                            break;
                        case Lua.Type.BOOLEAN:
                            values += lvm.to_boolean(i);
                            break;
                        case Lua.Type.NUMBER:
                            values += lvm.to_integer(i);
                            break;
                        default:
                            lvm.push_literal("Argument type not supported");
                            lvm.error();
                            return 0;
                    }
                }

                PermissionRule rule = {
                    cat,
                    action,
                    values
                };
                self._rules.append(rule);
                return 0;
            });
            lvm.raw_set(-3);
        }

        public signal void exit();
    }

}