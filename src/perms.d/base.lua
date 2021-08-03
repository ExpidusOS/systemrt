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
        proc:get_fs():set_mode("/mnt", 36)
    end,
    deny = function(proc)
        proc:get_fs():set_mode("/mnt", 0)
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