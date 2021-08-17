namespace SystemRT {
  private bool arg_kill = false;
  private bool arg_no_daemon = false;

  private const GLib.OptionEntry[] options = {
    { "kill", 'k', GLib.OptionFlags.NONE, GLib.OptionArg.NONE, ref arg_kill, "Kills the current instance of the daemon", null },
    { "no-daemon", 'n', GLib.OptionFlags.NONE, GLib.OptionArg.NONE, ref arg_no_daemon, "Doesn't fork like a daemon", null },
    { null }
  };

  public delegate void PermissionIter(Permission perm);

  [DBus(name = "com.expidus.SystemRT")]
  public class DaemonSystemRT : GLib.Object {
    private GLib.HashTable<string, Application> _apps;
    private GLib.HashTable<string, Session> _sessions;
    protected GLib.HashTable<string, Permission> _perms;
    private GLib.List<Process> _procs;
    private GLib.List<User> _users;
    private GLib.MainLoop _loop;
    private GLib.DBusConnection _conn;
    private Lua.LuaVM _lvm;
    private uint _name_lost_id;

    [DBus(visible = false)]
    public GLib.DBusConnection conn {
      get {
        return this._conn;
      }
    }

    public DaemonSystemRT(GLib.MainLoop loop, GLib.DBusConnection conn) throws GLib.Error {
      Object();

      if (AppArmor.is_enabled() != 1) throw new Error.APPARMOR_ERROR("AppArmor is required for SystemRT to function, please enable it. (%s)", Posix.strerror(Posix.errno));

      GLib.DirUtils.create_with_parents(LOCALSTATEDIR + "/run/expidus/runtime", 292);
      GLib.DirUtils.create_with_parents(LOCALSTATEDIR + "/db/expidus/runtime", 292);

      this._loop = loop;
      this._conn = conn;
      this._apps = new GLib.HashTable<string, Application>(str_hash, str_equal);
      this._sessions = new GLib.HashTable<string, Session>(str_hash, str_equal);
      this._perms = new GLib.HashTable<string, Permission>(str_hash, str_equal);
      this._procs = new GLib.List<Process>();
      this._users = new GLib.List<User>();
      this._name_lost_id = this._conn.signal_subscribe("org.freedesktop.DBus", "org.freedesktop.DBus",
        "NameLost", "/org/freedesktop/DBus", null, GLib.DBusSignalFlags.NONE, (conn, sender_name, obj_path, iface_name, sig_name, prams) => {
          this._sessions.@foreach((k, v) => {
            v.remove_client(new GLib.BusName(prams.get_child_value(0).get_string()));
          });
        });
      
      this._lvm = new Lua.LuaVM.with_alloc_func((ptr, osize, nsize) => {
        if (nsize == 0) {
          GLib.free(ptr);
          return null;
        }

        return GLib.realloc(ptr, nsize);
      });
      this._lvm.open_libs();

      this._lvm.new_table();

      this._lvm.push_string("__ptr");
      this._lvm.push_lightuserdata(this);
      this._lvm.raw_set(-3);

      this._lvm.push_string("has_permission");
      this._lvm.push_cfunction((lvm) => {
        if (lvm.get_top() != 1) {
          lvm.push_literal("Expected 1 argument");
          lvm.error();
          return 0;
        }

        if (lvm.type(1) != Lua.Type.STRING) {
          lvm.push_literal("Invalid argument: expected a string");
          lvm.error();
          return 0;
        }

        var id = lvm.to_string(1);

        lvm.get_global("rt");
        lvm.get_field(2, "__ptr");
        var self = ((DaemonSystemRT)lvm.to_userdata(3));

        lvm.push_boolean((int)self.has_perm(id));
        return 1;
      });
      this._lvm.raw_set(-3);

      this._lvm.push_string("add_permission");
      this._lvm.push_cfunction((lvm) => {
        if (lvm.get_top() != 2) {
          lvm.push_literal("Expected 2 arguments");
          lvm.error();
          return 0;
        }

        if (lvm.type(1) != Lua.Type.STRING) {
          lvm.push_literal("Invalid argument: expected a string");
          lvm.error();
          return 0;
        }

        if (lvm.type(2) != Lua.Type.TABLE) {
          lvm.push_literal("Invalid argument: expected a table");
          lvm.error();
          return 0;
        }

        var id = lvm.to_string(1);

        lvm.get_global("rt");
        lvm.get_field(3, "__ptr");
        var self = ((DaemonSystemRT)lvm.to_userdata(4));
        
        if (self.has_perm(id)) {
          lvm.push_literal("Permission already exists");
          lvm.error();
          return 0;
        }

        lvm.get_field(2, "allow");
        if (lvm.type(5) != Lua.Type.FUNCTION) {
          lvm.push_literal("Invalid type for field \"allow\": expected a function");
          lvm.error();
          return 0;
        }
        lvm.push_value(5);
        var allow = lvm.reference(Lua.PseudoIndex.REGISTRY);

        lvm.get_field(2, "deny");
        if (lvm.type(6) != Lua.Type.FUNCTION) {
          lvm.push_literal("Invalid type for field \"deny\": expected a function");
          lvm.error();
          return 0;
        }
        lvm.push_value(6);
        var deny = lvm.reference(Lua.PseudoIndex.REGISTRY);

        lvm.get_field(2, "default");
        if (lvm.type(7) != Lua.Type.FUNCTION) {
          lvm.push_literal("Invalid type for field \"default\": expected a function");
          lvm.error();
          return 0;
        }
        lvm.push_value(7);
        var def = lvm.reference(Lua.PseudoIndex.REGISTRY);

        var perm = new LuaPermission(lvm, id, allow, deny, def);

        lvm.get_field(2, "description");
        if (lvm.type(8) != Lua.Type.TABLE) {
          lvm.push_literal("Invalid type for field \"description\": expected a table");
          lvm.error();
          return 0;
        }

        lvm.push_nil();
        while (lvm.next(8) != 0) {
          perm.set_desc(lvm.to_string(-2), lvm.to_string(-1));
          lvm.pop(1);
        }

        self.add_perm(perm);
        return 0;
      });
      this._lvm.raw_set(-3);

      this._lvm.push_string("version");
      this._lvm.push_string(VERSION);
      this._lvm.raw_set(-3);

      this._lvm.set_global("rt");

      try {
        var dir = GLib.Dir.open(SYSCONFDIR + "/expidus/sys/perms.d");
        string? dirent = null;
        while ((dirent = dir.read_name()) != null) {
          var path = SYSCONFDIR + "/expidus/sys/perms.d/%s".printf(dirent);
          if (!GLib.FileUtils.test(path, GLib.FileTest.IS_REGULAR)) continue;

          if (this._lvm.do_file(path)) {
            stderr.printf("systemrtd: failed to load permission \"%s\": %s\n", path, this._lvm.to_string(-1));
          }
        }
      } catch (GLib.FileError e) {
        stderr.printf("systemrtd: failed to read file/directory: (%s) %s\n", e.domain.to_string(), e.message);
      }
    }

    ~DaemonSystemRT() {
      this._conn.signal_unsubscribe(this._name_lost_id);
    }

    [DBus(visible = false)]
    public void iterate_permissions(PermissionIter cb) {
      this._perms.@foreach((key, perm) => cb(perm));
    }

    [DBus(visible = false)]
    public bool is_permission_valid(string id) {
      return this._perms.contains(id);
    }

    [DBus(visible = false)]
    public GLib.KeyFile get_config() throws GLib.FileError, GLib.KeyFileError {
      var kf = new GLib.KeyFile();

      var dir = GLib.Dir.open(SYSCONFDIR + "/expidus/sys/conf.d");
      string? dirent = null;
      while ((dirent = dir.read_name()) != null) {
        var path = SYSCONFDIR + "/expidus/sys/perms.d/%s".printf(dirent);
        var subkf = new GLib.KeyFile();

        subkf.load_from_file(path, GLib.KeyFileFlags.NONE);

        foreach (var group_name in subkf.get_groups()) {
          foreach (var key_name in subkf.get_keys(group_name)) {
            kf.set_value(group_name, key_name, subkf.get_value(group_name, key_name));
          }
        }
      }
      return kf;
    }

    [DBus(visible = false)]
    public uint32 get_pid_by_sender(GLib.BusName sender) throws GLib.Error {
      return this._conn.call_sync("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
        "GetConnectionUnixProcessID", new GLib.Variant("(s)", sender),
        null, GLib.DBusCallFlags.NONE, -1, null).get_child_value(0).get_uint32();
    }

    [DBus(visible = false)]
    public bool has_perm(string id) {
      return this._perms.contains(id);
    }

    [DBus(visible = false)]
    public void add_perm(Permission perm) {
      if (!this._perms.contains(perm.id)) {
        this._perms.insert(perm.id, perm);
      }
    }

    [DBus(visible = false)]
    public User? get_user(uint32 uid) {
      for (unowned var item = this._users.first(); item != null; item = item.next) {
        if (item.data.uid == uid) return item.data;
      }

      try {
        var user = new User(this, uid);
        this._users.append(user);
        return user;
      } catch (Error e) {
        return null;
      }
    }

    [DBus(visible = false)]
    public Process? get_process(uint32 pid) {
      for (unowned var item = this._procs.first(); item != null; item = item.next) {
        if (item.data.pid == pid) return item.data;
      }
      return null;
    }

    [DBus(visible = false)]
    public Application? get_application(string id) {
      var app = this._apps.get(id);
      if (app == null) {
        try {
          app = new Application(this, id);
          this._apps.insert(id, app);
        } catch (Error e) {
          return null;
        }
      }
      return app;
    }

    [DBus(visible = false)]
    public Session? get_session_by_sender(GLib.BusName sender) throws GLib.Error {
      var pid = this.get_pid_by_sender(sender);
      return this.get_session(pid);
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
      var pid = this.get_pid_by_sender(sender);
      var session = this.get_session(pid);
      if (session == null) throw new Error.FAILED_SESSION_OWN("No session exists for this process");

      if (!session.own(disp, pid, auth.length == 0 ? null : auth)) {
        throw new Error.FAILED_SESSION_OWN("Session is already owned or couldn't validate authentication");
      }
    }

    public uint32 spawn(string[] args, GLib.BusName sender) throws GLib.Error {
      var pid = this.get_pid_by_sender(sender);
      var session = this.get_session(pid);
      if (session == null) throw new Error.INVALID_SESSION("No session exists for this process");
      var proc = new Process(this, session, args);
      proc.exit.connect(() => {
        this._procs.remove(proc);
      });
      this._procs.append(proc);
      return proc.pid;
    }

    public void quit(GLib.BusName sender) throws GLib.Error {
      var pid = this.get_pid_by_sender(sender);
      var session = this.get_session(pid);
      if (session == null) throw new Error.INVALID_SESSION("No session exists for this process");
      if (session.owner_pid != pid) {
        var argv0 = get_cmdline(pid)[0];
        if (argv0 != GLib.Path.build_filename(BINDIR, "systemrtd") && argv0 != "systemrtd") throw new Error.INVALID_PERM("Cannot call SystemRT to quit, not a session owner");
      }
      this._loop.quit();
    }

    public void ask_permission(string id, GLib.BusName sender) throws GLib.Error {
      if (this.is_permission_valid(id)) throw new Error.INVALID_PERM("Invalid permission ID");
      var pid = this.get_pid_by_sender(sender);
      var session = this.get_session(pid);
      if (session == null) throw new Error.INVALID_SESSION("No session exists for this process");
      var client = session.get_client(sender);
      if (client == null) throw new Error.INVALID_CLIENT("Failed to get the client for this process");
      var app = this.get_application(client.get_app_id());
      if (app == null) throw new Error.INVALID_APP("Failed to get the application for this process");

      if (!app.has_permission(id)) {
        this.permission_asked(app.id, id);
      }
    }

    public void grant_permission(string app_id, string id, PermissionLevel level, GLib.BusName sender) throws GLib.Error {
      var pid = this.get_pid_by_sender(sender);
      var session = this.get_session(pid);
      if (session == null) throw new Error.INVALID_SESSION("No session exists for this process");
      if (session.owner_pid != pid) throw new Error.INVALID_PERM("Cannot call SystemRT to quit, not a session owner");

      var app = this.get_application(app_id);
      if (app == null) throw new Error.INVALID_APP("Failed to find the application using the ID (%s)".printf(app_id));

      app.set_permission(id, level);

      var client = session.get_client_for_app_id(app_id);
      if (client != null) client.permission_granted(id, level);
    }

    public signal void permission_granted(string id, PermissionLevel level);
    public signal void permission_asked(string app_id, string id);
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
        Daemon.log(Daemon.LogPriority.ERR, "Failed to register object: (%s:%d) %s", e.domain.to_string(), e.code, e.message);
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