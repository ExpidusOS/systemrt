namespace SystemRT {
  public class Client : GLib.Object {
    public Session _session;
    public GLib.BusName _sender;

    public Client(Session session, GLib.BusName sender) {
      this._session = session;
      this._sender = sender;
    }

    public string? get_app_id() throws GLib.Error {
      var args = get_cmdline(get_pid_by_sender(this._session.systemrt.conn, this._sender));
      var argv0 = GLib.Path.get_basename(args[0]);
      if (argv0.contains("python")) argv0 = args[1];
      else argv0 = args[0];
      var apps = GLib.AppInfo.get_all();
      for (unowned var item = apps.first(); item != null; item = item.next) {
        var app = item.data;
        if (app.get_executable() != null) {
          if (app.get_executable().contains(argv0) || app.get_executable().contains(GLib.Path.get_basename(argv0))) {
            var id = app.get_id();
            return id.substring(0, id.length - 8);
          }
        }
      }
      return null;
    }
  }
}