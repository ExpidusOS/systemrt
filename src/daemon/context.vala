public static int main(string[] args) {
	GLib.MainContext ctx = new GLib.MainContext();
	GLib.MainLoop loop = new GLib.MainLoop(ctx);

	loop.run();
	return 0;
}