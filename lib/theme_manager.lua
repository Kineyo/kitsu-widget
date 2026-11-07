----------------------------------------------------------------------
-- theme_manager.lua  –  Motor Central de Gestión y Resolución de Temas
--                       para Kitsu Desktop AI & Media Suite.
--                       Soporta Temas Oficiales, Temas de Usuario,
--                       Cascada de Fallbacks, CSS Dinámico y Cambio en Caliente.
----------------------------------------------------------------------
local lgi    = require("lgi")
local Gtk    = lgi.require("Gtk", "3.0")
local Gdk    = lgi.require("Gdk", "3.0")
local GLib   = lgi.GLib

local config = require("config")
local json   = require("json")

local M = {}

M.active_theme_id   = "default"
M.active_theme_data = {}
M.active_theme_dir  = nil

local current_css_provider = nil

--- Retorna la ruta al directorio de temas del usuario (~/.config/kitsu/themes)
function M.get_user_themes_dir()
    local home = os.getenv("HOME") or os.getenv("USERPROFILE") or "."
    return home .. "/.config/kitsu/themes"
end

--- Retorna la ruta al directorio de temas base del widget (themes/)
function M.get_builtin_themes_dir()
    local base = config.BASE_DIR or "/opt/kitsu"
    return base .. "/themes"
end

--- Localiza el directorio físico de un tema por ID
-- Prioridad: 1. ~/.config/kitsu/themes/<id>  2. <KITSU_DIR>/themes/<id>
function M.find_theme_dir(theme_id)
    if not theme_id or type(theme_id) ~= "string" or #theme_id == 0 then
        return nil
    end

    local user_dir = M.get_user_themes_dir() .. "/" .. theme_id
    local f_user = io.open(user_dir .. "/theme.json", "r")
    if f_user then
        f_user:close()
        return user_dir
    end

    local builtin_dir = M.get_builtin_themes_dir() .. "/" .. theme_id
    local f_builtin = io.open(builtin_dir .. "/theme.json", "r")
    if f_builtin then
        f_builtin:close()
        return builtin_dir
    end

    return nil
end

--- Lista todos los temas disponibles en el sistema y usuario
-- @return table: array de { id = "...", name = "...", description = "...", author = "...", path = "..." }
function M.list_themes()
    local list = {}
    local seen = {}

    local function scan_dir(dir_path, is_user)
        local ok_d, d = pcall(GLib.Dir.open, dir_path, 0)
        if not ok_d or not d then return end
        local name = d:read_name()
        while name do
            if name ~= "." and name ~= ".." and not seen[name] then
                local full = dir_path .. "/" .. name
                local f = io.open(full .. "/theme.json", "r")
                if f then
                    local content = f:read("*a")
                    f:close()
                    local ok_dec, data = pcall(json.decode, content)
                    if ok_dec and data and type(data) == "table" then
                        seen[name] = true
                        table.insert(list, {
                            id          = name,
                            name        = data.name or name,
                            description = data.description or "",
                            author      = data.author or "Anónimo",
                            version     = data.version or "1.0",
                            path        = full,
                            is_user     = is_user
                        })
                    end
                end
            end
            name = d:read_name()
        end
    end

    -- 1. Temas de usuario
    scan_dir(M.get_user_themes_dir(), true)
    -- 2. Temas empaquetados
    scan_dir(M.get_builtin_themes_dir(), false)

    -- Ordenar: default primero, luego alfabéticamente
    table.sort(list, function(a, b)
        if a.id == "default" then return true end
        if b.id == "default" then return false end
        return a.name:lower() < b.name:lower()
    end)

    return list
end

--- Resuelve la ruta absoluta de un recurso/asset con cascada de fallback
-- 1. Tema activo en ~/.config/kitsu/themes/<activo>/assets/<rel_path>
-- 2. Tema activo en themes/<activo>/assets/<rel_path>
-- 3. Tema default en themes/default/assets/<rel_path>
-- 4. Assets globales base en assets/<rel_path>
function M.get_asset(rel_path)
    if not rel_path or #rel_path == 0 then return nil end

    -- 1. Intentar en el tema activo
    if M.active_theme_dir then
        local p = M.active_theme_dir .. "/assets/" .. rel_path
        local f = io.open(p, "rb")
        if f then f:close(); return p end
    end

    -- 2. Fallback a tema default si el tema activo es otro
    if M.active_theme_id ~= "default" then
        local def_dir = M.find_theme_dir("default")
        if def_dir then
            local p = def_dir .. "/assets/" .. rel_path
            local f = io.open(p, "rb")
            if f then f:close(); return p end
        end
    end

    -- 3. Fallback a assets/ base del widget
    local base_assets = config.ASSETS_DIR or (config.BASE_DIR .. "/assets")
    local p_base = base_assets .. "/" .. rel_path
    local f_base = io.open(p_base, "rb")
    if f_base then f_base:close(); return p_base end

    return nil
end

--- Aplica los estilos CSS de un tema
local function apply_theme_css(theme_dir, palette)
    local css_file = theme_dir .. "/style.css"
    local f = io.open(css_file, "r")
    if not f then return end
    local css_content = f:read("*a")
    f:close()

    if not css_content or #css_content == 0 then return end

    -- Reemplazo de macros dinámicas si el CSS usa variables como @ACCENT@, @BG@, etc.
    if palette then
        if palette.ACCENT and type(palette.ACCENT) == "table" then
            local hex_accent = string.format("#%02X%02X%02X",
                math.floor((palette.ACCENT[1] or 0) * 255),
                math.floor((palette.ACCENT[2] or 0) * 255),
                math.floor((palette.ACCENT[3] or 0) * 255)
            )
            css_content = css_content:gsub("@ACCENT@", hex_accent)
        end
        if palette.BG and type(palette.BG) == "table" then
            local hex_bg = string.format("#%02X%02X%02X",
                math.floor((palette.BG[1] or 0) * 255),
                math.floor((palette.BG[2] or 0) * 255),
                math.floor((palette.BG[3] or 0) * 255)
            )
            css_content = css_content:gsub("@BG@", hex_bg)
        end
    end

    local provider = Gtk.CssProvider()
    local ok_load, err = pcall(function()
        provider:load_from_data(css_content, #css_content)
    end)

    if ok_load then
        local ok_screen, screen = pcall(Gdk.Screen.get_default)
        if ok_screen and screen then
            if current_css_provider then
                pcall(function()
                    Gtk.StyleContext.remove_provider_for_screen(screen, current_css_provider)
                end)
            end
            pcall(function()
                Gtk.StyleContext.add_provider_for_screen(
                    screen,
                    provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 10
                )
            end)
            current_css_provider = provider
        end
    else
        io.stderr:write("[theme_manager] ERROR al cargar style.css: " .. tostring(err) .. "\n")
    end
end

--- Aplica un tema por su ID en caliente
-- @param theme_id string: ID del tema a cargar
-- @return boolean, string: éxito y mensaje
function M.apply_theme(theme_id)
    if not theme_id or #theme_id == 0 then
        theme_id = "default"
    end

    local theme_dir = M.find_theme_dir(theme_id)
    if not theme_dir then
        if theme_id ~= "default" then
            io.stderr:write(string.format("[theme_manager] WARN: Tema '%s' no encontrado. Usando 'default'.\n", theme_id))
            return M.apply_theme("default")
        end
        return false, "Tema 'default' no encontrado"
    end

    local json_path = theme_dir .. "/theme.json"
    local f = io.open(json_path, "r")
    if not f then
        return false, "Archivo theme.json no accesible en " .. theme_dir
    end
    local raw = f:read("*a")
    f:close()

    local ok_dec, data = pcall(json.decode, raw)
    if not ok_dec or type(data) ~= "table" then
        return false, "Formato JSON inválido en " .. json_path
    end

    M.active_theme_id   = theme_id
    M.active_theme_data = data
    M.active_theme_dir  = theme_dir
    config.theme        = theme_id

    -- 1. Aplicar paleta de colores Cairo en config (con soporte Claro / Oscuro)
    local mode = config.theme_mode or "dark"
    local active_palette = data.palette
    local active_contrast = data.CONTRAST

    if mode == "light" and data.palette_light then
        active_palette = data.palette_light
    elseif mode == "dark" and data.palette_dark then
        active_palette = data.palette_dark
    end

    if mode == "light" and data.CONTRAST_light then
        active_contrast = data.CONTRAST_light
    elseif mode == "dark" and data.CONTRAST_dark then
        active_contrast = data.CONTRAST_dark
    end

    if active_palette and type(active_palette) == "table" then
        for k, v in pairs(active_palette) do
            config[k] = v
        end
    end

    -- 2. Aplicar variables de contraste
    if active_contrast and type(active_contrast) == "table" then
        config.CONTRAST = active_contrast
    end

    -- 3. Aplicar geometría y tipografías
    if data.geometry and type(data.geometry) == "table" then
        for k, v in pairs(data.geometry) do
            config[k] = v
        end
    end
    if data.fonts and type(data.fonts) == "table" then
        for k, v in pairs(data.fonts) do
            config[k] = v
        end
    end

    -- 4. Aplicar persona de IA (System Prompt y Header)
    if data.persona and type(data.persona) == "table" then
        if data.persona.system_prompt then
            config.system_prompt = data.persona.system_prompt
        end
        if data.persona.chat_header then
            config.chat_header = data.persona.chat_header
        end
        if data.persona.name then
            config.agent_name = data.persona.name
        end
    else
        config.system_prompt = nil
        config.chat_header = nil
    end

    -- 5. Aplicar presets de habilidades si vienen en el tema
    if data.skills and type(data.skills) == "table" then
        for k, v in pairs(data.skills) do
            config.skills[k] = (v == true)
        end
    end

    -- 6. Cargar y aplicar hoja de estilos GTK3 (style.css o style_light.css)
    apply_theme_css(theme_dir, active_palette)

    -- 7. Notificar a observadores de config para redibujar componentes
    config.notify_change("theme", theme_id)

    local ok_u, utils = pcall(require, "utils")
    if ok_u and utils and utils.clear_cache then
        utils.clear_cache()
    end

    local ok_w, widget = pcall(require, "widget")
    if ok_w and widget and widget.reload_avatar then
        widget.reload_avatar()
    end

    local ok_c, chat = pcall(require, "chat")
    if ok_c and chat then
        if chat.update_avatar then chat.update_avatar() end
        if chat.update_header then chat.update_header() end
        if chat.update_theme_mode then chat.update_theme_mode() end
        if chat.update_corners then chat.update_corners() end
        if chat.window then chat.window:queue_draw() end
    end

    local ok_p, player = pcall(require, "player")
    if ok_p and player then
        if player.update_corners then player.update_corners() end
        if player.window then player.window:queue_draw() end
    end

    return true, "Tema '" .. (data.name or theme_id) .. "' activado correctamente."
end

--- Cambia o conmuta el modo entre 'claro' y 'oscuro'
function M.set_theme_mode(mode)
    config.theme_mode = (mode == "light") and "light" or "dark"
    config.save()
    pcall(function()
        local s = Gtk.Settings.get_default()
        if s then
            s.gtk_application_prefer_dark_theme = (config.theme_mode ~= "light")
        end
    end)
    M.apply_theme(M.active_theme_id or config.theme or "default")
    return config.theme_mode
end

function M.toggle_theme_mode()
    local next_mode = (config.theme_mode == "light") and "dark" or "light"
    return M.set_theme_mode(next_mode)
end

return M
