namespace SystemRTApplication {
	public enum PermissionState {
		DENY = 0,
		ALLOW,
		ALLOW_RUNNING,
		ASK_FIRST
	}

	public class Permission : GLib.Permission {
		public Context context { get; construct; }
		public string name { get; construct; }

		public override async bool acquire_async(GLib.Cancellable? cancellable = null) throws GLib.Error {
			var state = yield this.context.query_permission(this.name);
			return state == PermissionState.ALLOW || state == PermissionState.ALLOW_RUNNING;
		}
	}
}