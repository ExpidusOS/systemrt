namespace SystemRTPolicy {
	public class Table<V> : GLib.Object, SystemRTCommon.Serializable, ContextualObject {
		private string _name;
		private GLib.HashTable<string, V> _tbl;

		public string name {
			get {
				return this._name;
			}
			construct {
				this._name = value;
			}
		}

		construct {
			this._tbl = new GLib.HashTable<string, V>(GLib.str_hash, GLib.str_equal);
		}

		public Table(string name) {
			Object(name: name);
		}

		public void set_value(string key, V value) {
			this._tbl.set(key, value);
		}

		public V get_value(string key) {
			return this._tbl.get(key);
		}

		public bool contains(string key) {
			return this._tbl.contains(key);
		}

		public GLib.List<weak string> get_keys() {
			return this._tbl.get_keys();
		}

		public GLib.List<weak V> get_values() {
			return this._tbl.get_values();
		}

		public GLib.Variant serialize() {
			return new GLib.Variant("(sv)", this.name, this.get_serialized_variables());
		}

		public void deserialize(GLib.Variant v) {
		}

		public string get_namespace() {
			return this._name;
		}

		public virtual GLib.HashTable<string, GLib.Value?> get_variables() {
			var tbl = new GLib.HashTable<string, GLib.Value?>(GLib.str_hash, GLib.str_equal);
			foreach (var key in this.get_keys()) {
				var val = this.get_value(key);
				var vval = GLib.Value(typeof (V));
				vval.set_instance(val);
				tbl.set(key, vval);
			}
			return tbl;
		}
	}
}