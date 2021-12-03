namespace SystemRTPolicy {
	public class Policy : GLib.Object, ContextualObject, SystemRTCommon.Serializable {
		private string _name;
		private Table<Rule> _rules;

		public string name {
			get {
				return this._name;
			}
			construct {
				this._name = value;
			}
		}

		public Table<Rule> rules {
			get {
				return this._rules;
			}
			construct {
				this._rules = value;
			}
		}

		construct {
			if (this.rules == null) this._rules = new Table<Rule>("rules");
		}

		public virtual GLib.Variant serialize_value() {
			GLib.Variant[] rules = {};
			
			foreach (var rule in this._rules.get_values()) {
				rules += rule.serialize();
			}
			return new GLib.Variant("(sav)", this.name, rules);
		}

		public virtual void deserialize_value(GLib.Variant v) {
			this._rules = new Table<Rule>("rules");
			GLib.Variant[] rules;
			v.@get("(sav)", out this._name, out rules);

			foreach (var rule in rules) {
				var r = SystemRTCommon.Serializable.@new<Rule>(rule);
				this._rules.set(r.name, r);
			}
		}

		public string get_namespace() {
			return this.name;
		}

		public virtual GLib.HashTable<string, GLib.Value?> get_variables() {
			var tbl = new GLib.HashTable<string, GLib.Value?>(GLib.str_hash, GLib.str_equal);
			tbl.set("rules", this.rules);
			return tbl;
		}
	}
}