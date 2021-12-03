namespace SystemRTPolicy {
	public abstract class Process : GLib.Object, SystemRTCommon.Serializable, ContextualObject {
		public abstract GLib.Variant serialize_value();
		public abstract void deserialize_value(GLib.Variant v);

		public bool should_serialize() {
			return true;
		}

		public string get_namespace() {
			return "process";
		}

		public virtual GLib.HashTable<string, GLib.Value?> get_variables() {
			return new GLib.HashTable<string, GLib.Value?>(GLib.str_hash, GLib.str_equal);
		}
	}

	public class FileProcess : Process {
		private string _path;

		public string path {
			get {
				return this._path;
			}
			construct {
				this._path = value;
			}
		}

		public FileProcess(string path) {
			Object(path: path);
		}

		public override GLib.Variant serialize_value() {
			return new GLib.Variant("(s)", this.path);
		}

		public override void deserialize_value(GLib.Variant v) {
			v.@get("(s)", out this._path);
		}

		public override GLib.HashTable<string, GLib.Value?> get_variables() {
			var tbl = base.get_variables();
			tbl.set("path", this.path);
			return tbl;
		}
	}

	public class ApplicationProcess : Process {
		private string _id;

		public string id {
			get {
				return this._id;
			}
			construct {
				this._id = value;
			}
		}

		public ApplicationProcess(string id) {
			Object(id: id);
		}

		public override GLib.Variant serialize_value() {
			return new GLib.Variant("(s)", this.id);
		}

		public override void deserialize_value(GLib.Variant v) {
			v.@get("(s)", out this._id);
		}

		public override GLib.HashTable<string, GLib.Value?> get_variables() {
			var tbl = base.get_variables();
			tbl.set("id", this.id);
			return tbl;
		}
	}
}