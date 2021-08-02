namespace SystemRT {
    public class User {
        private DaemonSystemRT _daemon;
        private unowned Posix.Passwd _passwd;

        public uint32 uid {
            get {
                return (uint32)this._passwd.pw_uid;
            }
        }

        public User(DaemonSystemRT daemon, uint32 uid) throws Error {
            this._daemon = daemon;

            unowned var passwd = Posix.getpwuid(uid);
            if (passwd == null) {
                throw new Error.INVALID_USER("Failed to get passwd for user with id of %lu", uid);
            }
            this._passwd = passwd;
        }

        public bool is_admin() throws GLib.Error {
            var kf = this._daemon.get_config();
            foreach (var val in kf.get_string_list("User/%lu".printf(this._passwd.pw_uid), "groups")) {
                if (val == "admin") return true;
            }
            return false;
        }

        public void to_lua(Lua.LuaVM lvm) {
            lvm.new_table();

            lvm.push_string("__ptr");
            lvm.push_lightuserdata(this);
            lvm.raw_set(-3);

            lvm.push_string("uid");
            lvm.push_integer((int)this._passwd.pw_uid);
            lvm.raw_set(-3);

            lvm.push_string("gid");
            lvm.push_integer((int)this._passwd.pw_gid);
            lvm.raw_set(-3);

            lvm.push_string("name");
            lvm.push_string(this._passwd.pw_name);
            lvm.raw_set(-3);

            lvm.push_string("homedir");
            lvm.push_string(this._passwd.pw_dir);
            lvm.raw_set(-3);

            lvm.push_string("is_admin");
            lvm.push_cfunction((lvm) => {
                if (lvm.get_top() != 1) {
                    lvm.push_literal("Expecting 1 argument");
                    lvm.error();
                    return 0;
                }

                if (lvm.type(1) != Lua.Type.TABLE) {
                    lvm.push_literal("Mismatch of self type");
                    lvm.error();
                    return 0;
                }

                lvm.get_field(1, "__ptr");
                var self = (User)(lvm.to_userdata(2));
                try {
                    lvm.push_boolean((int)self.is_admin());
                } catch (GLib.Error e) {
                    lvm.push_literal("Failed for an unknown reason");
                    stderr.printf("(%s) %s\n", e.domain.to_string(), e.message);
                    lvm.error();
                    return 0;
                }
                return 1;
            });
            lvm.raw_set(-3);
        }
    }
}