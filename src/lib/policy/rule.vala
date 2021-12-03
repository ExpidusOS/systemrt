namespace SystemRTPolicy {
	public class Rule : GLib.Object, ContextualObject, SystemRTCommon.Serializable {
		private string _name;
		private string _type;
		private string _action;
		private GLib.Variant _data;

		public string name {
			get {
				return this._name;
			}
			construct {
				this._name = value;
			}
		}

		public string rtype {
			get {
				return this._type;
			}
			construct {
				this._type = value;
			}
		}

		public string action {
			get {
				return this._action;
			}
			construct {
				this._action = value;
			}
		}

		public GLib.Variant data {
			get {
				return this._data;
			}
			construct {
				this._data = value;
			}
		}

		public string get_namespace() {
			return this.name;
		}

		public GLib.Variant serialize() {
			return new GLib.Variant("(sssv)", this.name, this.rtype, this.action, this.data);
		}

		public void deserialize(GLib.Variant v) {
			v.@get("(sssv)", out this._name, out this._type, out this._action, out this._data);
		}

		public GLib.HashTable<string, GLib.Value?> get_variables() {
			var tbl = new GLib.HashTable<string, GLib.Value?>(GLib.str_hash, GLib.str_equal);
			tbl.set("name", this.name);
			tbl.set("type", this.rtype);
			tbl.set("action", this.action);
			return tbl;
		}
	}
}