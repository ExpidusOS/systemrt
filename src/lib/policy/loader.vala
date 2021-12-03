namespace SystemRTPolicy {
	public errordomain LoaderError {
		INVALID_GROUP,
		INVALID_RULE,
		INVALID_TYPE,
		INVALID_REF,
		INVALID_VAR
	}

	public class Loader : GLib.Object, GLib.Initable, ContextualObject, SystemRTCommon.Serializable {
		private Context _context;
		private Table<Rule> _rules;
		private Table<Policy> _policies;

		public Context context {
			get {
				return this._context;
			}
		}

		public Rule[] rules {
			owned get {
				Rule[] values = {};
				foreach (var v in this._rules.get_values()) values += v;
				return values;
			}
		}

		public Policy[] policies {
			owned get {
				Policy[] values = {};
				foreach (var v in this._policies.get_values()) values += v;
				return values;
			}
		}

		public GLib.KeyFile key_file { get; construct; }
		
		construct {
			this._rules = new Table<Rule>("rules");
			this._policies = new Table<Policy>("policies");
			this.key_file.set_list_separator(',');
		}

		public Loader(GLib.KeyFile key_file) {
			Object(key_file: key_file);
		}

		public Loader.from_path(string str) throws GLib.KeyFileError, GLib.FileError {
			var kf = new GLib.KeyFile();
			kf.load_from_file(str, GLib.KeyFileFlags.KEEP_COMMENTS);
			Object(key_file: kf);
		}

		public Loader.from_string(string str) throws GLib.KeyFileError {
			var kf = new GLib.KeyFile();
			kf.load_from_data(str, str.length, GLib.KeyFileFlags.KEEP_COMMENTS);
			Object(key_file: kf);
		}

		public static Loader load_path(string str, GLib.Cancellable? cancellable = null) throws GLib.Error {
			var loader = new Loader.from_path(str);
			loader.init(cancellable);
			return loader;
		}

		public static Loader load_string(string str, GLib.Cancellable? cancellable = null) throws GLib.Error {
			var loader = new Loader.from_string(str);
			loader.init(cancellable);
			return loader;
		}

		private GLib.Type load_type(string name) {
			switch (name) {
				case "SystemRTPolicyApplicationProcess": return typeof (ApplicationProcess);
				case "SystemRTPolicyFileProcess": return typeof (FileProcess);
				case "SystemRTPolicyPolicy": return typeof (Policy);
				case "SystemRTPolicyRule": return typeof (Rule);
			}
			return GLib.Type.from_name(name);
		}

		private GLib.Object create_object_with_type(GLib.Type type, string group, string[] in_keys = {}, GLib.Value[] in_values = {}, string[] skip_keys = {}) throws GLib.KeyFileError, LoaderError {
			string[] keys = {};
			GLib.Value[] values = {};

			foreach (var k in in_keys) {
				keys += k;
			}

			foreach (var v in in_values) {
				values += v;
			}

			if (this.key_file.has_group(group)) {
				foreach (var key in this.key_file.get_keys(group)) {
					if (key in skip_keys || key.has_suffix("@type") || key.has_suffix("@vformat")) continue;

					string? key_type = null;
					if (this.key_file.has_key(group, key + "@type")) {
						key_type = this.key_file.get_string(group, key + "@type");
					} else {
						key_type = this.key_file.get_comment(group, key).strip();
					}

					switch (key_type) {
						case "string":
							keys += key;
							values += this.key_file.get_string(group, key);
							break;
						case "int64":
							keys += key;
							values += this.key_file.get_int64(group, key);
							break;
						case "uint64":
							keys += key;
							values += this.key_file.get_uint64(group, key);
							break;
						case "boolean":
						case "bool":
							keys += key;
							values += this.key_file.get_boolean(group, key);
							break;
						case "double":
							keys += key;
							values += this.key_file.get_double(group, key);
							break;
						case "integer":
						case "int":
							keys += key;
							values += this.key_file.get_integer(group, key);
							break;
						case "variant":
						case "var":
							string? vtype = null;
							if (this.key_file.has_key(group, key + "@vformat")) {
								vtype = this.key_file.get_string(group, key + "@vformat");
							} else {
								vtype = this.key_file.get_comment(group, key);
							}

							var str = this.key_file.get_string(group, key);
							try {
								var v = GLib.Variant.parse(new GLib.VariantType(vtype), str);
								keys += key;
								values += v;
							} catch (GLib.VariantParseError e) {
								throw new LoaderError.INVALID_VAR("Variant (fmt: \"%s\", str: \"%s\") in key \"%s\" group \"%s\" could not be loaded (%s:%d): %s", vtype, str, key, group, e.domain.to_string(), e.code, e.message);
							}
							break;
						case "reference":
						case "ref":
							var reference = this.key_file.get_string(group, key);
							var v = this.fetch_var(reference);
							if (v == null) throw new LoaderError.INVALID_REF("Reference \"%s\" in key \"%s\" group \"%s\" could not be fetched", reference, key, group);
							keys += key;
							values += v;
							break;
						case "reference:list":
						case "ref:list":
							GLib.List<GLib.Value?> list = new GLib.List<GLib.Value?>();
							var refs = this.key_file.get_string_list(group, key);
							foreach (var reference in refs) {
								var v = this.fetch_var(reference);
								if (v == null) throw new LoaderError.INVALID_REF("Reference \"%s\" in key \"%s\" group \"%s\" could not be fetched", reference, key, group);
								list.append(v);
							}
							keys += key;
							values += list;
							break;
						default:
							throw new LoaderError.INVALID_TYPE("Key \"%s\" for \"%s\" has an invalid type: %s", key, group, key_type);
					}
				}
			}

			return GLib.Object.new_with_properties(type, keys, values);
		}

		private T create_object<T>(string group, string[] in_keys = {}, GLib.Value[] in_values = {}, string[] in_skip_keys = {}) throws GLib.KeyFileError, LoaderError {
			var type = typeof (T);
			string[] skip_keys = {};
			foreach (var v in in_skip_keys) skip_keys += v;

			if (this.key_file.has_group(group)) {
				if (this.key_file.has_key(group, "gtype")) {
					var type_name = this.key_file.get_string(group, "gtype");
					type = this.load_type(type_name);
					skip_keys += "gtype";
				} else {
					var type_name = this.key_file.get_comment(group, null).strip();
					type = this.load_type(type_name);
				}
			}
			return this.create_object_with_type(type, group, in_keys, in_values, skip_keys);
		}

		public bool init(GLib.Cancellable? cancellable = null) throws GLib.Error {
			var ctx_proc = this.create_object<Process>("Context/Process");
			this._context = this.create_object<Context>("Context", { "proc" }, { ctx_proc });

			foreach (var group in this.key_file.get_groups()) {
				if (group == "Context/Process" || group == "Context") continue;

				var base_group = group.substring(0, group.index_of("/"));
				var id_group = group.substring(group.index_of("/") + 1);
				switch (base_group) {
					case "Policy":
						var policy = (Policy)this.create_object_with_type(typeof (Policy), group, { "name" }, { id_group }, { "rules" });
						var rule_refs = this.key_file.get_string_list(group, "rules");
						foreach (var rule_ref in rule_refs) {
							var rule = this._rules.get_value(rule_ref);
							if (rule == null) throw new LoaderError.INVALID_RULE("Rule \"%s\" does not exist in group \"%s\"", rule_ref, group);
							policy.rules.set_value(rule.name, rule);
						}
						this._policies.set_value(id_group, policy);
						break;
					case "Rule":
						this._rules.set_value(id_group, (Rule)this.create_object_with_type(typeof (Rule), group, { "name" }, { id_group }));
						break;
					default:
						throw new LoaderError.INVALID_GROUP("Invalid group called \"%s\"", group);
				}
			}
			return true;
		}

		public string get_namespace() {
			return "loader";
		}

		public GLib.Variant serialize_value() {
			return new GLib.Variant("(s)", this.key_file.to_data());
		}

		public void deserialize_value(GLib.Variant v) {
			string data;
			v.@get("(s)", out data);

			try {
				this.key_file.load_from_data(data, data.length, GLib.KeyFileFlags.NONE);
			} catch (GLib.Error e) {
				GLib.critical("Failed to deserialize the loader (%s:%d): %s", e.domain.to_string(), e.code, e.message);
			}
		}

		public GLib.HashTable<string, GLib.Value?> get_variables() {
			var tbl = new GLib.HashTable<string, GLib.Value?>(GLib.str_hash, GLib.str_equal);
			tbl.set("key_file", this.key_file);
			tbl.set("context", this.context);
			tbl.set("policies", this._policies);
			tbl.set("rules", this._rules);
			return tbl;
		}

		public bool has_policy(string name) {
			return this._policies.contains(name);
		}

		public bool has_rule(string name) {
			return this._rules.contains(name);
		}
	}
}