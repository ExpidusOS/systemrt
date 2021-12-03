namespace SystemRTPolicy {
	public interface ContextualObject : GLib.Object {
		public abstract string get_namespace();

		public abstract GLib.HashTable<string, GLib.Value?> get_variables();

		public virtual bool should_serialize() {
			return false;
		}

		public virtual GLib.Variant? serialize_variable(string name) {
			return null;
		}

		public GLib.Variant get_serialized_variables() {
			var vb = new GLib.VariantBuilder(new GLib.VariantType("a{sv}"));

			var vars = this.get_variables();
			foreach (var vname in vars.get_keys()) {
				var vval = vars.get(vname);

				if (vval.type() == GLib.Type.VARIANT) {
					vb.add("{sv}", vname, vval.get_variant());
				} else if (vval.type() == GLib.Type.BOOLEAN) {
					vb.add("{sv}", vname, vval.get_boolean());
				} else if (vval.type() == GLib.Type.DOUBLE) {
					vb.add("{sv}", vname, vval.get_double());
				} else if (vval.type() == GLib.Type.FLOAT) {
					vb.add("{sv}", vname, vval.get_float());
				} else if (vval.type() == GLib.Type.INT) {
					vb.add("{sv}", vname, vval.get_int());
				} else if (vval.type() == GLib.Type.INT64) {
					vb.add("{sv}", vname, vval.get_int64());
				} else if (vval.type() == GLib.Type.LONG) {
					vb.add("{sv}", vname, vval.get_long());
				} else if (vval.type() == GLib.Type.STRING) {
					vb.add("{sv}", vname, new GLib.Variant.string(vval.get_string()));
				} else if (vval.type().is_object()) {
					var is_cobj = vval.get_object() is ContextualObject;
					var is_ser = vval.get_object() is SystemRTCommon.Serializable;
					if (is_cobj && !is_ser) {
						vb.add("{sv}", vname, ((ContextualObject)vval.get_object()).get_serialized_variables());
					} else if (!is_cobj && is_ser) {
						vb.add("{sv}", vname, ((SystemRTCommon.Serializable)vval.get_object()).serialize());
					} else if (is_cobj && is_ser) {
						if (((ContextualObject)vval.get_object()).should_serialize()) {
							vb.add("{sv}", vname, ((SystemRTCommon.Serializable)vval.get_object()).serialize());
						} else {
							vb.add("{sv}", vname, ((ContextualObject)vval.get_object()).get_serialized_variables());
						}
					}
				} else {
					var v = this.serialize_variable(vname);
					if (v != null) {
						vb.add("{sv}", vname, v);
					}
				}
			}
			return vb.end();
		}

		public GLib.Value? fetch_var(string nspace) {
			var curr = nspace.substring(0, this.get_namespace().length - 1);
			var next = nspace.substring(this.get_namespace().length);

			stdout.printf("nspace = %s, curr = %s, next = %s\n", nspace, curr, next);

			var vars = this.get_variables();
			foreach (var vname in vars.get_keys()) {
				var vval = vars.get(vname);
				if (vname == curr) {
					if (vval.type().is_object() && vval.get_object() is ContextualObject && nspace.index_of(".") > -1) {
						var cobj = vval as ContextualObject;
						return cobj.fetch_var(next.substring(cobj.get_namespace().length));
					} else {
						return vval;
					}
				}
			}
			return null;
		}
	}

	public class Context : GLib.Object, ContextualObject, SystemRTCommon.Serializable {
		private Process _proc;

		public virtual Process proc {
			get {
				return this._proc;
			}
			construct {
				this._proc = value;
			}
		}

		public bool should_serialize() {
			return true;
		}

		public virtual GLib.Variant serialize_value() {
			return new GLib.Variant("(v)", this.proc.serialize());
		}

		public virtual void deserialize_value(GLib.Variant v) {
			GLib.Variant proc;
			v.@get("(v)", out proc);
			this.proc.deserialize(proc);
		}

		public string get_namespace() {
			return "context";
		}

		public virtual GLib.HashTable<string, GLib.Value?> get_variables() {
			var tbl = new GLib.HashTable<string, GLib.Value?>(GLib.str_hash, GLib.str_equal);
			tbl.set("process", this.proc);
			return tbl;
		}
	}
}