----------------------------------------------------------------------
-- avatar_customizer.lua  –  Módulo de personalización del avatar del widget
--                           Permite al usuario cambiar la imagen del widget,
--                           recortándola automáticamente al centro (1:1) y
--                           redimensionándola de forma óptima para ajustarla.
----------------------------------------------------------------------
local lgi = require("lgi")
local Gtk = lgi.require("Gtk", "3.0")
local GdkPixbuf = lgi.GdkPixbuf
local GLib = lgi.GLib

local config = require("config")
local utils  = require("utils")

local avatar_customizer = {}

-- Directorio base de almacenamiento para el avatar personalizado del usuario
local function get_custom_avatar_path()
    local config_dir = config.CONFIG_PATH:match("(.+)/[^/]+$") or ((os.getenv("HOME") or "/home/alex") .. "/.config/kitsu")
    return config_dir .. "/custom_avatar.png"
end

--- Procesa, recorta centrado a relación de aspecto 1:1 y redimensiona una imagen.
-- @param source_path string: Ruta al archivo de imagen de origen.
-- @param dest_path string: Ruta donde se guardará la imagen procesada en PNG.
-- @param target_size number: Tamaño en píxeles del lado (por defecto 256 para alta resolución).
-- @return boolean, string|GdkPixbuf: Éxito y la ruta final (o mensaje de error si falla).
function avatar_customizer.process_and_resize(source_path, dest_path, target_size)
    if not source_path or type(source_path) ~= "string" or #source_path == 0 then
        return false, "Ruta de imagen no especificada"
    end

    -- Verificar que el archivo existe
    local f = io.open(source_path, "rb")
    if not f then
        return false, "El archivo de imagen no existe o no se puede leer: " .. tostring(source_path)
    end
    f:close()

    -- Cargar imagen usando GdkPixbuf
    local ok_load, src_pb = pcall(GdkPixbuf.Pixbuf.new_from_file, source_path)
    if not ok_load or not src_pb then
        return false, "No se pudo decodificar la imagen (formato no soportado o archivo dañado)"
    end

    local orig_w = src_pb:get_width()
    local orig_h = src_pb:get_height()
    if orig_w <= 0 or orig_h <= 0 then
        return false, "Dimensiones de imagen inválidas: " .. orig_w .. "x" .. orig_h
    end

    -- 1. Recorte centrado a proporción cuadrada 1:1 para evitar deformaciones
    local side = math.min(orig_w, orig_h)
    local offset_x = math.floor((orig_w - side) / 2)
    local offset_y = math.floor((orig_h - side) / 2)

    local square_pb = GdkPixbuf.Pixbuf.new_subpixbuf(src_pb, offset_x, offset_y, side, side)
    if not square_pb then
        return false, "Error al recortar la imagen al centro"
    end

    -- 2. Redimensionado de alta calidad usando interpolación bilineal
    local sz = tonumber(target_size) or 256
    local scaled_pb = square_pb:scale_simple(sz, sz, GdkPixbuf.InterpType.BILINEAR)
    if not scaled_pb then
        return false, "Error al redimensionar la imagen a " .. sz .. "x" .. sz
    end

    -- 3. Asegurar que el directorio de destino exista
    local dest_dir = dest_path:match("(.+)/[^/]+$")
    if dest_dir then
        os.execute(string.format("mkdir -p '%s' 2>/dev/null", dest_dir))
    end

    -- 4. Guardar archivo en formato PNG optimizado
    local ok_save, err = pcall(function()
        return scaled_pb:savev(dest_path, "png", {}, {})
    end)

    if not ok_save or not err then
        return false, "Error al guardar la imagen procesada en: " .. dest_path
    end

    return true, dest_path, scaled_pb
end

--- Asigna una nueva imagen como avatar personalizado del widget.
-- @param source_path string: Ruta a la imagen elegida por el usuario.
-- @return boolean, string: Resultado y mensaje o ruta del archivo generado.
function avatar_customizer.set_avatar(source_path)
    local dest_path = get_custom_avatar_path()
    local ok, res, pb = avatar_customizer.process_and_resize(source_path, dest_path, 256)
    if not ok then
        return false, res
    end

    -- Actualizar configuración persistente
    config.custom_avatar = dest_path
    config.save()

    -- Refrescar cachés en memoria
    utils.clear_cache()

    -- Notificar al widget principal para que redibuje la burbuja
    local ok_w, widget = pcall(require, "widget")
    if ok_w and widget and widget.reload_avatar then
        pcall(widget.reload_avatar)
    end

    -- Notificar a la ventana de chat para actualizar el icono miniatura
    local ok_c, chat = pcall(require, "chat")
    if ok_c and chat and chat.update_avatar then
        pcall(chat.update_avatar)
    end

    -- Disparar listeners de configuración
    config.notify_change("custom_avatar", dest_path)

    return true, dest_path
end

--- Restablece el avatar a la ilustración predeterminada del proyecto.
-- @return boolean
function avatar_customizer.reset_default()
    config.custom_avatar = nil
    config.save()

    utils.clear_cache()

    local ok_w, widget = pcall(require, "widget")
    if ok_w and widget and widget.reload_avatar then
        pcall(widget.reload_avatar)
    end

    local ok_c, chat = pcall(require, "chat")
    if ok_c and chat and chat.update_avatar then
        pcall(chat.update_avatar)
    end

    config.notify_change("custom_avatar", nil)
    return true
end

--- Indica si el usuario tiene actualmente un avatar personalizado activo.
-- @return boolean
function avatar_customizer.has_custom_avatar()
    if config.custom_avatar and type(config.custom_avatar) == "string" and #config.custom_avatar > 0 then
        local f = io.open(config.custom_avatar, "rb")
        if f then
            f:close()
            return true
        end
    end
    return false
end

--- Devuelve la ruta absoluta al avatar en uso actual.
-- @return string
function avatar_customizer.get_current_avatar_path()
    if avatar_customizer.has_custom_avatar() then
        return config.custom_avatar
    end
    return config.AVATAR or (config.ASSETS_DIR .. "/avatar.jpg")
end

--- Abre un diálogo nativo GTK de selección de archivos para cambiar el avatar.
-- @param parent_window Gtk.Window|nil: Ventana padre para centrado modal.
-- @param callback function|nil: Función llamada con (success, path_or_error).
function avatar_customizer.open_dialog(parent_window, callback)
    local dialog = Gtk.FileChooserDialog {
        title = "Seleccionar Imagen de Avatar para el Widget",
        transient_for = parent_window,
        action = Gtk.FileChooserAction.OPEN,
    }

    dialog:add_button("Cancelar", Gtk.ResponseType.CANCEL)
    dialog:add_button("Seleccionar Imagen", Gtk.ResponseType.ACCEPT)

    -- Filtro de extensiones de imagen soportadas
    local filter_images = Gtk.FileFilter()
    filter_images:set_name("Imágenes soportadas (*.png, *.jpg, *.jpeg, *.webp, *.bmp)")
    filter_images:add_mime_type("image/png")
    filter_images:add_mime_type("image/jpeg")
    filter_images:add_mime_type("image/webp")
    filter_images:add_mime_type("image/bmp")
    filter_images:add_pattern("*.png")
    filter_images:add_pattern("*.jpg")
    filter_images:add_pattern("*.jpeg")
    filter_images:add_pattern("*.webp")
    filter_images:add_pattern("*.bmp")
    filter_images:add_pattern("*.PNG")
    filter_images:add_pattern("*.JPG")
    filter_images:add_pattern("*.JPEG")
    dialog:add_filter(filter_images)

    local filter_all = Gtk.FileFilter()
    filter_all:set_name("Todos los archivos")
    filter_all:add_pattern("*")
    dialog:add_filter(filter_all)

    dialog:set_default_response(Gtk.ResponseType.ACCEPT)

    dialog.on_response = function(self, response_id)
        if response_id == Gtk.ResponseType.ACCEPT then
            local filename = self:get_filename()
            self:destroy()
            if filename and #filename > 0 then
                local ok, res = avatar_customizer.set_avatar(filename)
                if callback then
                    callback(ok, res)
                end
            end
        else
            self:destroy()
            if callback then
                callback(false, "Operación cancelada")
            end
        end
    end

    dialog:show()
    return dialog
end

-- Ejecución directa desde línea de comandos
if arg and arg[0] and arg[0]:match("avatar_customizer%.lua$") then
    Gtk.init()
    if #arg == 0 or arg[1] == "--help" or arg[1] == "-h" then
        io.stdout:write("Uso: lua5.3 lib/avatar_customizer.lua <ruta-a-imagen> | --reset\n")
        os.exit(0)
    elseif arg[1] == "--reset" then
        avatar_customizer.reset_default()
        io.stdout:write("[OK] Avatar restablecido a la ilustración predeterminada.\n")
    else
        local ok, res = avatar_customizer.set_avatar(arg[1])
        if ok then
            io.stdout:write("[OK] Imagen actualizada con éxito y ajustada al widget: " .. res .. "\n")
        else
            io.stderr:write("[ERROR] " .. tostring(res) .. "\n")
            os.exit(1)
        end
    end
end

return avatar_customizer
