namespace SystemRTApplication {
	[DBus(name = "com.systemrt.application.Context")]
	public interface ContextProxy : GLib.Object {
		public abstract async PermissionState query_permission(string pname) throws GLib.DBusError, GLib.IOError;

		public signal void permission_changed(string pname, PermissionState state, bool removed, bool added);
	}

	public class Context : GLib.Object, GLib.Initable {
		private GLib.HashTable<string, PermissionState> _pstore;
		private ContextProxy _proxy;
		private ulong _pchanged_id;

		~Context() {
			if (this._pchanged_id > 0) {
				this._proxy.disconnect(this._pchanged_id);
				this._pchanged_id = 0;
			}
		}

		construct {
			this._pstore = new GLib.HashTable<string, PermissionState>(GLib.str_hash, GLib.str_equal);
		}

		public bool init(GLib.Cancellable? cancellable = null) throws GLib.Error {
			this._proxy = GLib.Bus.get_proxy_sync<ContextProxy>(GLib.BusType.SYSTEM, "com.expidus.SystemRT", "/com/expidus/SystemRT", GLib.DBusProxyFlags.NONE, cancellable);

			this._pchanged_id = this._proxy.permission_changed.connect((pname, state, removed, added) => {
				string tag = "updated";
				if (removed && !added) {
					tag = "removed";
					this._pstore.remove(pname);
				} else if (!removed && added) {
					tag = "added";
					this._pstore.insert(pname, state);
				} else {
					this._pstore.set(pname, state);
				}

				GLib.debug("Permission \"%s\" was %s: %s", pname, tag, state.to_string());
				this.permission_changed(pname, state, removed, added);
			});
			return true;
		}

		public async PermissionState query_permission(string pname) throws GLib.DBusError, GLib.IOError {
			if (this._pstore.contains(pname)) {
				return this._pstore.get(pname);
			}
			return yield this._proxy.query_permission(pname);
		}

		public signal void permission_changed(string pname, PermissionState state, bool removed, bool added);
	}
}