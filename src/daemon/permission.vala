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

    public class LuaPermission : GLib.Object, Permission {
        private string _id;
        private unowned Lua.LuaVM _lvm;
        private GLib.HashTable<string, string> _desc;
        private int _allow;
        private int _deny;
        private int _def;

        public string id {
            get {
                return this._id;
            }
        }

        public LuaPermission(Lua.LuaVM lvm, string id, int allow, int deny, int def) {
            this._lvm = lvm;
            this._id = id;
            this._desc = new GLib.HashTable<string, string>(str_hash, str_equal);
            this._allow = allow;
            this._deny = deny;
            this._def = def;
        }

        public void set_desc(string lang, string val) {
            this._desc.set(lang, val);
        }

        public void allow(Process proc) {
            this._lvm.set_top(0);
            this._lvm.raw_geti(Lua.PseudoIndex.REGISTRY, this._allow);
            proc.to_lua(this._lvm);
            this._lvm.pcall(1, 0, 0);
        }

        public void deny(Process proc) {
            this._lvm.set_top(0);
            this._lvm.raw_geti(Lua.PseudoIndex.REGISTRY, this._deny);
            proc.to_lua(this._lvm);
            this._lvm.pcall(1, 0, 0);
        }

        public void def(Process proc) {
            this._lvm.set_top(0);
            this._lvm.raw_geti(Lua.PseudoIndex.REGISTRY, this._def);
            proc.to_lua(this._lvm);
            this._lvm.pcall(1, 1, 0);

            var r = this._lvm.to_string(2);
            switch (r) {
                case "allow":
                    this.allow(proc);
                    break;
                default:
                    this.deny(proc);
                    break;
            }
        }
    }

    public class BasePermission : GLib.Object, Permission {
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

        public BasePermission(string id, PermissionAllow allow, PermissionDeny deny, PermissionDefault def) {
            Object();
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

        public void def(Process proc) {
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

    public interface Permission : GLib.Object {
        public abstract string id { get; }
        public abstract void set_desc(string lang, string val);
        public abstract void allow(Process proc);
        public abstract void deny(Process proc);
        public abstract void def(Process proc);
    }

    public struct PermissionRule {
        public PermissionCategory category;
        public string? action;
        public GLib.Value[] values;
    }
}