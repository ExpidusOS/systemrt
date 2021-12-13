namespace SystemRTServer {
	public interface Context : GLib.Object {
		public abstract void register_applib(SystemRTApplib.Library lib) throws GLib.Error;
		public abstract void register_policy(SystemRTPolicy.Policy policy) throws GLib.Error;

		public abstract void run(string path) throws GLib.Error;

		public abstract void load_policy_from_file(string path) throws GLib.Error;
		public abstract void load_policy(string str) throws GLib.Error;
	}
}