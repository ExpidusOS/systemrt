namespace SystemRTPolicy {
	public enum RuleAction {
		DENY = 0,
		ALLOW,
		ASK,
		DEFAULT;

		public static RuleAction? parse_nick(string nick) {
			var enumc = (GLib.EnumClass)typeof (RuleAction).class_ref();
			unowned var eval = enumc.get_value_by_nick(nick);
			return_val_if_fail(eval != null, -1);
			if (eval == null) return null;
			return (RuleAction)eval.value;
		}

		public string to_nick() {
			var enumc = (GLib.EnumClass)typeof (RuleAction).class_ref();
			unowned var eval = enumc.get_value(this);
			return_val_if_fail(eval != null, null);
			return eval.value_nick;
		}
	}

	public class Rule : GLib.Object, ContextualObject, SystemRTCommon.Serializable {
		private string _name;
		private string _type;
		private RuleAction _action;
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

		public RuleAction action {
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

		public bool should_serialize() {
			return true;
		}

		public string get_namespace() {
			return this.name;
		}

		public GLib.Variant serialize_value() {
			return new GLib.Variant("(sssv)", this.name, this.rtype, this.action.to_nick(), this.data);
		}

		public void deserialize_value(GLib.Variant v) {
			string action_string;
			v.@get("(sssv)", out this._name, out this._type, out action_string, out this._data);

			this._action = RuleAction.parse_nick(action_string);
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