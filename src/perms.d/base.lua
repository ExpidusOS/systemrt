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
        proc:get_fs():set_mode("/mnt", "allow", "read", "write")
    end,
    deny = function(proc)
        proc:get_fs():set_mode("/mnt", "deny", "read", "write", "exec")
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
        proc:get_fs():set_mode(proc:get_user().homedir, "allow", "read")
    end,
    deny = function(proc)
        proc:get_fs():set_mode(proc:get_user().homedir, "deny", "write", "exec")
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
        proc:get_fs():set_mode("/boot", "allow", "read", "write")
        proc:get_fs():set_mode("/var/log", "allow", "read", "write")
    end,
    deny = function(proc)
        proc:get_fs():set_mode("/boot", "deny", "read")
        proc:get_fs():set_mode("/var/log", "deny", "read", "write", "exec")
    end
})

rt.add_permission("com.expidus.devices.usb", {
    description = {
        en = "Allow access to USB devices"
    },
    default = function(proc)
        if proc:get_user():is_admin() then
            return "allow"
        end
        return "deny"
    end,
    allow = function(proc)
        proc:get_fs():set_mode("/sys/bus/usb", "allow", "read")
    end,
    deny = function(proc)
        proc:get_fs():set_mode("/sys/bus/usb", "deny", "read", "write", "exec")
    end
})

rt.add_permission("com.expidus.net.raw", {
    description = {
        en = "Allow raw packet broadcasting"
    },
    default = function(proc)
        return "deny"
    end,
    allow = function(proc)
        proc:get_caps():set("net_raw", "allow")
    end,
    deny = function(proc)
        proc:get_caps():set("net_raw", "deny")
    end
})

rt.add_permission("com.expidus.net.internet", {
    description = {
        en = "Allow access to the Internet"
    },
    default = function(proc)
        if proc:get_user():is_admin() then
            return "allow"
        end
        return "deny"
    end,
    allow = function(proc)
        proc:get_net():set_access("allow", "inet", "stream")
        proc:get_net():set_access("allow", "inet6", "stream")
    end,
    deny = function(proc)
        proc:get_net():set_access("deny", "inet", "stream")
        proc:get_net():set_access("deny", "inet6", "stream")
    end
})