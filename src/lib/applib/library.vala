namespace SystemRTApplib {
	public abstract class Library : GLib.Object {
		public abstract string name { get; }
		public abstract string[] extensions { get; }

		public virtual bool is_compatible(GLib.File file) throws GLib.Error {
			foreach (var ext in this.extensions) {
				if (file.get_basename().has_suffix(ext)) return true;
			}
			return false;
		}

		public abstract int run(GLib.File file) throws GLib.Error;
	}
}