public int main(string[] args) {
	GLib.Test.init(ref args);
	GLib.Test.add_func("/loader/simple/gtype", test_loader_simple_gtype);
	GLib.Test.add_func("/loader/simple/comment", test_loader_simple_comment);
	return GLib.Test.run();
}