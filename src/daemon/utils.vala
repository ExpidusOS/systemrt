namespace SystemRT {
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