----------------------------------------------------------------------
-- lib/skills/notify.lua  –  Notificaciones de Escritorio (Cero Emojis)
----------------------------------------------------------------------
local lgi  = require("lgi")
local Gio  = lgi.Gio

local skill = {
    name = "notify",
    description = "Envia una notificacion emergente al escritorio.",
    params = { title = "titulo", message = "mensaje" },
}

function skill.run(args, callback)
    local title = "Qwen Desktop Widget"
    local msg = "Aviso del asistente"
    if type(args) == "table" then
        title = args.title or title
        msg = args.message or args.msg or msg
    elseif type(args) == "string" then
        msg = args
    end

    local ok, sub = pcall(Gio.Subprocess.new,
        { "notify-send", tostring(title), tostring(msg), "-i", "dialog-information" },
        Gio.SubprocessFlags.NONE)

    if ok and sub then
        sub:wait_async(nil, function(s, res)
            local ok_wait = pcall(function() return s:wait_finish(res) end)
            if callback then
                callback(ok_wait and s:get_successful(), string.format("[Notificacion] Enviada: **%s**", title))
            end
        end)
    else
        if callback then
            callback(false, "[Notificacion] Error al invocar notify-send")
        end
    end
end

return skill
