namespace SystemRT {
  public static uint32 get_pid_by_sender(GLib.DBusConnection conn, GLib.BusName sender) throws GLib.Error {
    return conn.call_sync("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
      "GetConnectionUnixProcessID", new GLib.Variant("(s)", sender),
      null, GLib.DBusCallFlags.NONE, -1, null).get_child_value(0).get_uint32();
  }

  public static string[] get_cmdline(uint32 pid) throws GLib.Error {
    var proc = "";
    size_t proc_len = 0;
    GLib.FileUtils.get_contents("/proc/%lu/cmdline".printf(pid), out proc, out proc_len);
    var cmdline = "";
    for (var i = 0; i < proc_len; i++) {
      if (proc[i] == '\0') cmdline += " ";
      else cmdline += proc[i].to_string();
    }
    return cmdline.replace("\n", "").split(" ");
  }
}