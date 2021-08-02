namespace SystemRT {
  public class Application : GLib.Object {
    private DaemonSystemRT _daemon;
    private string _id;
    private GLib.DesktopAppInfo _appinfo;
    private Sqlite.Database _db;

    public string id {
      get {
        return this._id;
      }
    }

    public Application(DaemonSystemRT daemon, string id) throws Error {
      this._daemon = daemon;
      this._id = id;
      this._appinfo = new GLib.DesktopAppInfo("%s.desktop".printf(id));
      if (this._appinfo == null) throw new Error.INVALID_APP("Invalid application ID");

      var rc = Sqlite.Database.open(LOCALSTATEDIR + "/db/expidus/runtime/%s.sqlite".printf(id), out this._db);
      if (rc != Sqlite.OK) {
        throw new Error.FAILED_DATABASE_ACTION("Failed to open database: (%d) %s", rc, this._db.errmsg());
      }

      string statement = """
CREATE TABLE IF NOT EXISTS permissions(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name STRING NONNULL,
  level INTEGER 
)
      """;
      string errmsg;
      rc = this._db.exec(statement, null, out errmsg);
      if (rc != Sqlite.OK) {
        throw new Error.FAILED_DATABASE_ACTION("Failed to initalize database: (%d) %s", rc, errmsg);
      }
    }

    public void set_permission(string id, PermissionLevel level) throws Error {
      if (!this._daemon.is_permission_valid(id)) throw new Error.INVALID_PERM("Permission is not registered");

      string errmsg;
      if (this.has_permission(id)) {
        var rc = this._db.exec("UPDATE permission SET level = %d WHERE name = '%s'".printf(level, id), null, out errmsg);
        if (rc != Sqlite.OK) {
          throw new Error.FAILED_DATABASE_ACTION("Failed to query database: (%d) %s", rc, errmsg);
        }
      } else {
        var rc = this._db.exec("INSERT INTO permission (name, level) VALUES (%s, %d)".printf(id, level), null, out errmsg);
        if (rc != Sqlite.OK) {
          throw new Error.FAILED_DATABASE_ACTION("Failed to query database: (%d) %s", rc, errmsg);
        }
      }
    }

    public bool has_permission(string id) throws Error {
      if (!this._daemon.is_permission_valid(id)) throw new Error.INVALID_PERM("Permission is not registered");

      Sqlite.Statement stmnt;
      string errmsg;
      var rc = this._db.prepare_v2("SELECT level FROM permissions WHERE (id = \"%s\");".printf(id), -1, out stmnt, out errmsg);
      if (rc != Sqlite.OK) {
        throw new Error.FAILED_DATABASE_ACTION("Failed to query database: (%d) %s", rc, errmsg);
      }
      
      return stmnt.column_count() != 0;
    }

    public PermissionLevel get_permission(string id) throws Error {
      if (!this._daemon.is_permission_valid(id)) throw new Error.INVALID_PERM("Permission is not registered");

      Sqlite.Statement stmnt;
      string errmsg;
      var rc = this._db.prepare_v2("SELECT level FROM permissions WHERE (id = \"%s\");".printf(id), -1, out stmnt, out errmsg);
      if (rc != Sqlite.OK) {
        throw new Error.FAILED_DATABASE_ACTION("Failed to query database: (%d) %s", rc, errmsg);
      }

      if (stmnt.column_count() != 0) {
        unowned var val = stmnt.column_value(0);
        switch (val.to_int()) {
          case 0: return PermissionLevel.NONE;
          case 1: return PermissionLevel.ONCE;
          case 2: return PermissionLevel.FG_ONLY;
          case 3: return PermissionLevel.ALL;
        }
      }

      return PermissionLevel.NONE;
    }
  }
}