public void test_loader_simple_gtype() {
	GLib.Test.summary("Uses the policy loader to load a simple policy to test loading capabilities. It uses the \"gtype\" key to load any types.");
	try {
		var loader = SystemRTPolicy.Loader.load_string("""
[Context/Process]
gtype = SystemRTPolicyFileProcess
path = /usr/bin/bash
path@type = string

[Rule/shell_rule_1]
rtype = filesystem
rtype@type = string
action = allow
action@type = string
data = ('/etc/', true)
data@type = var
data@vformat = (sb)

[Policy/shell]
rules = shell_rule_1
""");

		if (!loader.has_rule("shell_rule_1")) {
			GLib.Test.message("The rule \"shell_rule_1\" did not get loaded correctly");
			GLib.Test.fail();
		}

		if (!loader.has_policy("shell")) {
			GLib.Test.message("The policy \"shell\" did not get loaded correctly");
			GLib.Test.fail();
		}
		
		GLib.Test.message("Serialized loader variables: %s", loader.get_serialized_variables().print(true));
	} catch (GLib.Error error) {
		GLib.Test.message("Failed to load from string (%s:%d): %s\n", error.domain.to_string(), error.code, error.message);
		GLib.Test.fail();
	}
}

public void test_loader_simple_comment() {
	GLib.Test.summary("Uses the policy loader to load a simple policy to test loading capabilities. It uses comments to load any types.");
	try {
		var loader = SystemRTPolicy.Loader.load_string("""
# SystemRTPolicyFileProcess
[Context/Process]
# string
path = /usr/bin/bash

[Rule/shell_rule_1]
# string
rtype = filesystem
# string
action = allow
# var
data = ('/etc/', true)
data@vformat = (sb)

[Policy/shell]
rules = shell_rule_1
""");

		if (!loader.has_rule("shell_rule_1")) {
			GLib.Test.message("The rule \"shell_rule_1\" did not get loaded correctly");
			GLib.Test.fail();
		}

		if (!loader.has_policy("shell")) {
			GLib.Test.message("The policy \"shell\" did not get loaded correctly");
			GLib.Test.fail();
		}
		
		GLib.Test.message("Serialized loader variables: %s", loader.get_serialized_variables().print(true));
	} catch (GLib.Error error) {
		GLib.Test.message("Failed to load from string (%s:%d): %s\n", error.domain.to_string(), error.code, error.message);
		GLib.Test.fail();
	}
}