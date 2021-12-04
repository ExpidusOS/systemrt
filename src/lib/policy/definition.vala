namespace SystemRTPolicy {
	public abstract class Definition {
		public virtual string get_default_action() {
			return "deny";
		}

		public virtual string[] get_rule_types() {
			return {};
		}

		public virtual bool is_valid_rule_type(string rule_type) {
			return false;
		}
	}
}