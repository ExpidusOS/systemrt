rt.add_permission("com.expidus.storage.external", {
    description = {
        en = "Allow access to external drives"
    },
    default = function(proc)
        if proc:get_user():is_admin() then
            return "allow"
        end
        return "deny"
    end,
    allow = function(proc)
        proc:get_fs():set_mode("/mnt", {"read", "write"})
    end,
    deny = function(proc)
        proc:get_fs():set_mode("/mnt", {})
    end
})

rt.add_permission("com.expidus.storage.internal", {
    description = {
        en = "Allow access to interal (system) storage"
    },
    default = function(proc)
        if proc:get_user():is_admin() then
            return "allow"
        end
        return "deny"
    end,
    allow = function(proc)
        proc:get_fs():set_mode(proc:get_user().homedir, {"read"})
    end,
    deny = function(proc)
        proc:get_fs():set_mode(proc:get_user().homedir, {})
    end
})

rt.add_permission("com.epxidus.storage.system", {
    description = {
        en = "Allow access to system storage"
    },
    default = function(proc)
        if proc:get_user():is_admin() then
            return "allow"
        end
        return "deny"
    end,
    allow = function(proc)
        proc:get_fs():set_mode("/boot", {"read", "write"})
        proc:get_fs():set_mode("/var/log", {"read", "write"})
    end,
    deny = function(proc)
        proc:get_fs():set_mode("/boot", {"read"})
        proc:get_fs():set_mode("/var/log", {})
    end
})