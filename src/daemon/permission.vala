namespace SystemRT {
    public enum PermissionAction {
        ALLOW,
        DENY
    }

    public enum PermissionCategory {
        FS
    }
    
    public delegate PermissionAction PermissionDefault(Process proc);
    public delegate void PermissionAllow(Process proc);
    public delegate void PermissionDeny(Process proc);

    public class Permission {
        private string _id;
        private GLib.HashTable<string, string> _desc;
        private unowned PermissionAllow _allow;
        private unowned PermissionDeny _deny;
        private unowned PermissionDefault _default;

        public string id {
            get {
                return this._id;
            }
        }

        public Permission(string id, PermissionAllow allow, PermissionDeny deny, PermissionDefault def) {
            this._id = id;
            this._allow = allow;
            this._deny = deny;
            this._default = def;
            this._desc = new GLib.HashTable<string, string>(str_hash, str_equal);
        }

        public void set_desc(string lang, string val) {
            this._desc.set(lang, val);
        }

        public void allow(Process proc) {
            this._allow(proc);
        }

        public void deny(Process proc) {
            this._deny(proc);
        }

        public void @default(Process proc) {
            var act = this._default(proc);
            switch (act) {
                case PermissionAction.ALLOW:
                    this._allow(proc);
                    break;
                case PermissionAction.DENY:
                    this._deny(proc);
                    break;
            }
        }
    }

    public struct PermissionRule {
        public PermissionCategory category;
        public string? action;
        public GLib.Value[] values;
    }
}