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
    default = function()
        if proc:get_user():is_admin() then
            return "allow"
        end
        return "deny"
    end,
    allow = function(proc)
        proc:get_fs():bind(proc:get_user():get_homedir())
    end,
    deny = function()
        proc:get_fs():unbind(proc:get_user():get_homedir())
    end
})