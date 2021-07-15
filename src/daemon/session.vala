namespace SystemRT {
  public class Session : GLib.Object {
    private DaemonSystemRT _systemrt;
    private string _sess_path;
    private GLib.List<GLib.BusName> _clients;
    private uint32 _owner_pid = 0;
    private Gdk.Display? _disp = null;
    private string? _auth = null;

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

    public Session(DaemonSystemRT systemrt, string sess_path) {
      this._systemrt = systemrt;
      this._sess_path = sess_path;
      this._clients = new GLib.List<GLib.BusName>();
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

    public void add_client(GLib.BusName client) {
      if (this._clients.find(client) == null) {
        this._clients.append(client);
      }
    }

    public void remove_client(GLib.BusName client) {
      this._clients.remove(client);
    }
  }
}