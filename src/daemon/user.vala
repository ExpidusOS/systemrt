namespace SystemRT {
    public class User {
        private DaemonSystemRT _daemon;
        private int _uid;

        public int uid {
            get {
                return this._uid;
            }
        }

        public User(DaemonSystemRT daemon, int uid) {
            this._daemon = daemon;
            this._uid = uid;
        }

        public bool is_admin() throws GLib.Error {
            var kf = this._daemon.get_config();
            foreach (var val in kf.get_string_list("User/%d".printf(this._uid), "groups")) {
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
            lvm.push_integer(this._uid);
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