namespace SystemRT {
  public class Session : GLib.Object {
    private DaemonSystemRT _systemrt;
    private string _sess_path;
    private GLib.HashTable<GLib.BusName, Client> _clients;
    private uint32 _owner_pid = 0;
    private Gdk.Display? _disp = null;
    private string? _auth = null;

    public DaemonSystemRT systemrt {
      get {
        return this._systemrt;
      }
    }

    public uint32 owner_pid {
      get {
        return this._owner_pid;
      }
    }

    public string session_path {
      get {
        return this._sess_path;
      }
    }

    public string? auth {
      get {
        return this._auth;
      }
    }

    public Gdk.Display? disp {
      get {
        return this._disp;
      }
    }

    public Session(DaemonSystemRT systemrt, string sess_path) {
      this._systemrt = systemrt;
      this._sess_path = sess_path;
      this._clients = new GLib.HashTable<GLib.BusName, Client>(str_hash, str_equal);
    }

    public void unown() {
      this._owner_pid = 0;
      this._auth = null;
      if (this._disp != null) this._disp.close();
    }

    public bool own(string disp, uint32 pid, string? auth = null) {
      if (this._owner_pid == 0 && this._disp == null) {
        // TODO: actually read the Xauthority file and connect that way
        if (auth != null) GLib.Environment.set_variable("XAUTHORITY", auth, true);
        this._disp = Gdk.Display.open(disp);
        if (auth != null) GLib.Environment.unset_variable("XAUTHORITY");
        if (this._disp == null) return false;

        this._auth = auth;
        this._owner_pid = pid;
        return true;
      }
      return false;
    }

    public Client? get_client_for_app_id(string id) throws GLib.Error {
      foreach (var item in this._clients.get_values()) {
        if (item.get_app_id() == id) return item;
      }
      return null;
    }

    public Client get_client(GLib.BusName sender) {
      Client client = this._clients.get(sender);
      if (client == null) {
        client = new Client(this, sender);
        this._clients.insert(sender, client);
      }
      return client;
    }

    public void remove_client(GLib.BusName client) {
      this._clients.remove(client);
    }

    public User? get_owner_user(out uint32 uid, out uint32 gid) {
      uid = gid = 0;
      if (this._owner_pid == 0) {
        return null;
      }

      Posix.Stat buf = {};
      if (Posix.stat("/proc/%lu".printf(this._owner_pid), out buf) < 0) return null;

      uid = (uint32)buf.st_uid;
      gid = (uint32)buf.st_gid;
      return this._systemrt.get_user(uid);
    }
  }
}