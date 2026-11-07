----------------------------------------------------------------------
-- theme_downloader.lua  –  Descargador Asíncrono y Seguro de Temas
--                          Descarga paquetes de temas (.zip) y los
--                          descomprime en ~/.config/kitsu/themes/<id>
--                          sin bloquear el bucle de eventos de GTK3
--                          y sin interpolación de comandos shell.
----------------------------------------------------------------------
local lgi  = require("lgi")
local GLib = lgi.require("GLib", "2.0")
local Gio  = lgi.require("Gio", "2.0")

local M = {}

--- Obtiene el directorio base de temas del usuario
function M.get_user_themes_dir()
    local home = os.getenv("HOME") or os.getenv("USERPROFILE") or "."
    return home .. "/.config/kitsu/themes"
end

--- Descarga y descomprime un tema .zip de forma asíncrona y segura
-- @param theme_id string: Identificador único del tema (ej. "cyberpunk", "navi_lain")
-- @param zip_url string: URL directa al archivo .zip (ej. GitHub Releases o CDN)
-- @param callback function(success, message, dest_dir): Función ejecutada al finalizar
function M.download_and_install(theme_id, zip_url, callback)
    if not theme_id or type(theme_id) ~= "string" or #theme_id == 0 then
        if callback then callback(false, "ID de tema no válido") end
        return
    end

    if not zip_url or type(zip_url) ~= "string" or not zip_url:match("^https?://") then
        if callback then callback(false, "URL de descarga inválida: debe comenzar con http:// o https://") end
        return
    end

    -- Sanitizar estrictamente el ID del tema (solo alfanuméricos, guiones y guiones bajos)
    local safe_id = theme_id:gsub("[^%w%-_]", "")
    if #safe_id == 0 then safe_id = "custom_theme" end

    local user_themes_dir = M.get_user_themes_dir()
    local dest_dir = user_themes_dir .. "/" .. safe_id
    GLib.mkdir_with_parents(dest_dir, 493) -- 0755

    local tmp_dir = GLib.get_tmp_dir() or "/tmp"
    local tmp_zip = string.format("%s/kitsu_theme_%s_%d.zip", tmp_dir, safe_id, os.time())

    -- Paso 1: Descarga segura con curl usando argumentos directos (sin shell)
    local curl_argv = { "curl", "-fsSL", "--max-time", "60", zip_url, "-o", tmp_zip }
    local ok_c, curl_proc = pcall(Gio.Subprocess.new, curl_argv, Gio.SubprocessFlags.NONE)
    if not ok_c or not curl_proc then
        if callback then callback(false, "No se pudo iniciar el proceso de descarga curl") end
        return
    end

    curl_proc:wait_async(nil, function(p, res)
        local ok_wait = pcall(function() return p:wait_finish(res) end)
        local curl_success = pcall(function() return p:get_successful() end) and p:get_successful()

        if not curl_success then
            os.remove(tmp_zip)
            if callback then
                callback(false, "Error al descargar el paquete de tema desde " .. zip_url)
            end
            return
        end

        -- Paso 2: Descompresión segura con unzip usando argumentos directos
        local unzip_argv = { "unzip", "-qo", tmp_zip, "-d", dest_dir }
        local ok_u, unzip_proc = pcall(Gio.Subprocess.new, unzip_argv, Gio.SubprocessFlags.NONE)
        if not ok_u or not unzip_proc then
            os.remove(tmp_zip)
            if callback then callback(false, "No se pudo iniciar la descompresión unzip") end
            return
        end

        unzip_proc:wait_async(nil, function(u, u_res)
            local ok_u_wait = pcall(function() return u:wait_finish(u_res) end)
            local unzip_success = pcall(function() return u:get_successful() end) and u:get_successful()
            os.remove(tmp_zip)

            if unzip_success then
                if callback then
                    callback(true, "Tema '" .. safe_id .. "' instalado con éxito en " .. dest_dir, dest_dir)
                end
            else
                if callback then
                    callback(false, "Error al descomprimir el archivo de tema")
                end
            end
        end)
    end)
end

return M
