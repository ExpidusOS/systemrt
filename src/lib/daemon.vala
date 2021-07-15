namespace SystemRT {
  public errordomain Error {
    FAILED_SESSION_OWN,
    INVALID_PERM
  }

  [DBus(name = "com.expidus.SystemRT")]
  public interface SystemRT : GLib.Object {
    public abstract void own_session(string disp, string auth, GLib.BusName sender) throws GLib.Error;
    public abstract void quit(GLib.BusName sender) throws GLib.Error;
  }
}