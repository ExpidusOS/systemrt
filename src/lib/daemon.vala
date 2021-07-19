namespace SystemRT {
  public errordomain Error {
    FAILED_SESSION_OWN,
    INVALID_SESSION,
    INVALID_CLIENT,
    INVALID_APP,
    INVALID_PERM
  }

  [DBus(name = "com.expidus.SystemRT")]
  public interface SystemRT : GLib.Object {
    public abstract void own_session(string disp, string auth) throws GLib.Error;
    public abstract void quit() throws GLib.Error;
    public abstract void ask_permission(string id) throws GLib.Error;
    public abstract void grant_permission(string app_id, string id, PermissionLevel level) throws GLib.Error;

    public signal void permission_granted(string id, PermissionLevel level);
    public signal void permission_asked(string app_id, string id);
  }

  public enum PermissionLevel {
    NONE,
    ONCE,
    FG_ONLY,
    ALL
  }
}