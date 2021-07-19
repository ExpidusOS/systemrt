namespace SystemRT {
  public class Application : GLib.Object {
    private string _id;
    private GLib.DesktopAppInfo _appinfo;
    private GLib.HashTable<string, PermissionLevel> _perms;

    public string id {
      get {
        return this._id;
      }
    }

    public Application(string id) throws Error {
      this._id = id;
      this._appinfo = new GLib.DesktopAppInfo("%s.desktop".printf(id));
      this._perms = new GLib.HashTable<string, PermissionLevel>(str_hash, str_equal);
      if (this._appinfo == null) throw new Error.INVALID_APP("Invalid application ID");
    }

    // TODO: check a registry of valid permission ID's
    public void set_permission(string id, PermissionLevel level) {
      this._perms.set(id, level);
    }

    // TODO: check a registry of valid permission ID's
    public PermissionLevel get_permission(string id) {
      return this._perms.get(id);
    }
  }
}