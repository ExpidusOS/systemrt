namespace SystemRT {
  private bool arg_kill = false;
  private bool arg_no_daemon = false;

  private const GLib.OptionEntry[] options = {
    { "kill", 'k', GLib.OptionFlags.NONE, GLib.OptionArg.NONE, ref arg_kill, "Kills the current instance of the daemon", null },
    { "no-daemon", 'n', GLib.OptionFlags.NONE, GLib.OptionArg.NONE, ref arg_no_daemon, "Doesn't fork like a daemon", null },
    { null }
  };

  [DBus(name = "com.expidus.SystemRT")]
  public class DaemonSystemRT : GLib.Object {
    private GLib.HashTable<string, Session> _sessions;
    private GLib.MainLoop _loop;
    private GLib.DBusConnection _conn;
    private uint _name_lost_id;

    [DBus(visible = false)]
    public GLib.DBusConnection conn {
      get {
        return this._conn;
      }
    }

    public DaemonSystemRT(GLib.MainLoop loop, GLib.DBusConnection conn) {
      this._loop = loop;
      this._conn = conn;
      this._sessions = new GLib.HashTable<string, Session>(str_hash, str_equal);
      this._name_lost_id = this._conn.signal_subscribe("org.freedesktop.DBus", "org.freedesktop.DBus",
        "NameLost", "/org/freedesktop/DBus", null, GLib.DBusSignalFlags.NONE, (conn, sender_name, obj_path, iface_name, sig_name, prams) => {
          this._sessions.@foreach((k, v) => {
            v.remove_client(new GLib.BusName(prams.get_child_value(0).get_string()));
          });
        });
    }

    ~DaemonSystemRT() {
      this._conn.signal_unsubscribe(this._name_lost_id);
    }

    [DBus(visible = false)]
    public Session? get_session_by_sender(GLib.BusName sender) throws GLib.Error {
      var pid = get_pid_by_sender(this._conn, sender);
      var sess = this.get_session(pid);
      if (sess != null) sess.add_client(sender);
      return sess;
    }

    [DBus(visible = false)]
    public Session? get_session(uint32 pid) throws GLib.Error {
      try {
        var sess_path = this._conn.call_sync("org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager",
          "GetSessionByPID", new GLib.Variant("(u)", pid),
          null, GLib.DBusCallFlags.NONE, -1, null).get_child_value(0).get_string();
      
        var sess = this._sessions.get(sess_path);
        if (sess == null) {
          sess = new Session(this, sess_path);
          this._sessions.insert(sess_path, sess);
        }
        return sess;
      } catch (GLib.Error e) {
        return null;
      }
    }

    // TODO: do not rely on the client to tell us the display name and Xauthority file
    public void own_session(string disp, string auth, GLib.BusName sender) throws GLib.Error {
      var pid = get_pid_by_sender(this._conn, sender);
      var session = this.get_session(pid);
      if (session == null) throw new Error.FAILED_SESSION_OWN("No session exists for this process");

      if (!session.own(disp, pid, auth.length == 0 ? null : auth)) {
        throw new Error.FAILED_SESSION_OWN("Session is already owned or couldn't validate authentication");
      }
    }

    public void quit(GLib.BusName sender) throws GLib.Error {
      var pid = get_pid_by_sender(this._conn, sender);
      var session = this.get_session(pid);
      if (session == null) throw new Error.FAILED_SESSION_OWN("No session exists for this process");
      if (session.owner_pid != pid) {
        var argv0 = get_cmdline(pid)[0];
        if (argv0 != GLib.Path.build_filename(BINDIR, "systemrtd") && argv0 != "systemrtd") throw new Error.INVALID_PERM("Cannot call SystemRT to quit, not a session owner");
      }
      this._loop.quit();
    }
  }

  private void finish() {
    Daemon.retval_send(255);
    Daemon.signal_done();
    Daemon.pid_file_remove();
  }

  private void run() {
    GLib.MainLoop loop = new GLib.MainLoop();

    GLib.Bus.own_name(GLib.BusType.SYSTEM, "com.expidus.SystemRT", GLib.BusNameOwnerFlags.NONE, (conn, name) => {
      try {
        conn.register_object("/com/expidus/SystemRT", new DaemonSystemRT(loop, conn));
      } catch (GLib.Error e) {
        Daemon.log(Daemon.LogPriority.ERR, "Failed to register object");
        loop.quit();
      }
    });

    loop.run();
  }

  public static int main(string[] args) {
    GLib.Environment.unset_variable("XAUTHORITY");
    GLib.Environment.unset_variable("DISPLAY");

    try {
      GLib.OptionContext opt_ctx = new GLib.OptionContext("- Device identification daemon");
      opt_ctx.set_help_enabled(true);
      opt_ctx.add_main_entries(options, null);
      opt_ctx.parse(ref args);
    } catch (GLib.OptionError e) {
      stderr.printf("%s (%s): %s\n", GLib.Path.get_basename(args[0]), e.domain.to_string(), e.message);
      return 1;
    }

    Daemon.log_ident = Daemon.pid_file_ident = Daemon.ident_from_argv0(args[0]);

    if (arg_kill) {
      try {
        var conn = GLib.Bus.get_sync(GLib.BusType.SYSTEM);
        var sysrt = conn.get_proxy_sync<SystemRT>("com.expidus.SystemRT", "/com/expidus/SystemRT");
        sysrt.quit();
        return 0;
      } catch (GLib.Error e) {
        Daemon.log(Daemon.LogPriority.WARNING, "Failed to kill daemon using DBus, falling back to PID file: (%s) %s", e.domain.to_string(), e.message);
      }
      int ret = Daemon.pid_file_kill_wait(Daemon.Sig.TERM, 5);
      if (ret < 0) {
        Daemon.log(Daemon.LogPriority.WARNING, "Failed to kill daemon using PID file.");
      }
      return ret < 0 ? 1 : 0;
    }

    if (arg_no_daemon) {
      run();
      return 0;
    }

    if (Daemon.reset_sigs(-1) < 0) {
      Daemon.log(Daemon.LogPriority.ERR, "Failed to reset signal handlers");
      return 1;
    }

    if (Daemon.unblock_sigs(-1) < 0) {
      Daemon.log(Daemon.LogPriority.ERR, "Failed to unblock signals");
      return 1;
    }

    var pid = Daemon.pid_file_is_running();
    if (pid >= 0) {
      Daemon.log(Daemon.LogPriority.ERR, "System Runtime is already running with PID file %u", pid);
      return 1;
    }

    if (Daemon.retval_init() < 0) {
      Daemon.log(Daemon.LogPriority.ERR, "Failed to create pipe");
      return 1;
    }

    if ((pid = Daemon.fork()) < 0) {
      Daemon.retval_done();
      return 0;
    } else if (pid > 0) {
      int ret = Daemon.retval_wait(20);
      if (ret < 0) {
        Daemon.log(Daemon.LogPriority.ERR, "Could not receive return value of daemon.");
        return 255;
      }
      
      Daemon.log(Daemon.LogPriority.ERR, "Received exit code %d", ret);
      return ret;
    } else {
      if (Daemon.close_all(-1) < 0) {
        Daemon.log(Daemon.LogPriority.ERR, "Failed to close all file descriptors");
        Daemon.retval_send(1);
        finish();
        return 1;
      }

      if (Daemon.pid_file_create() < 0) {
        Daemon.log(Daemon.LogPriority.ERR, "Failed to create PID file");
        Daemon.retval_send(2);
        finish();
        return 1;
      }

      if (Daemon.signal_init(Daemon.Sig.INT, Daemon.Sig.QUIT, 0) < 0) {
        Daemon.log(Daemon.LogPriority.ERR, "Could not register signal handlers");
        Daemon.retval_send(3);
        finish();
        return 1;
      }

      Daemon.retval_send(0);
      Daemon.log(Daemon.LogPriority.INFO, "Daemon is online");
      run();
      finish();
    }
    return 0;
  }
}